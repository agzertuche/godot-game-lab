class_name ElevatorController
extends RefCounted

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

## Owns one car's logical state. It has no Node, tween, sprite, or UI dependency.
signal elevator_arrived(floor: int)
signal doors_opened(floor: int)
signal passenger_boarded(passenger: ElevatorPassenger, floor: int)
signal passenger_exited(passenger: ElevatorPassenger, floor: int)
signal elevator_direction_changed(previous_direction: int, next_direction: int)

const DEFAULT_CAPACITY := 4
const DEFAULT_TRAVEL_FLOORS_PER_SECOND := 2.0
const DEFAULT_DOOR_DWELL_SECONDS := 0.8
const DEFAULT_TRANSFER_SECONDS := 0.35

var elevator_id: int
var current_floor: int
var movement_state := SimulationTypes.MovementState.IDLE
var service_direction := SimulationTypes.Direction.IDLE
var passengers: Array[ElevatorPassenger] = []
var capacity := DEFAULT_CAPACITY
var assigned_hall_requests: Array[ElevatorHallRequest] = []
var destination_requests: Dictionary = {}
var door_state := SimulationTypes.DoorState.CLOSED
var target_floor := 0
var staging_floor: int
var allowed_min_floor := 1
var allowed_max_floor: int
var building_floor_count: int
var travel_floor := 1.0
var door_dwell_remaining := 0.0
var travel_floors_per_second := DEFAULT_TRAVEL_FLOORS_PER_SECOND
var door_dwell_seconds := DEFAULT_DOOR_DWELL_SECONDS
var transfer_seconds := DEFAULT_TRANSFER_SECONDS
var express_service_enabled := false


func _init(identifier: int, starting_floor: int, floor_count: int) -> void:
	elevator_id = identifier
	current_floor = starting_floor
	staging_floor = starting_floor
	allowed_max_floor = floor_count
	building_floor_count = floor_count
	travel_floor = float(starting_floor)


func configure_service(min_floor: int, max_floor: int, idle_staging_floor: int) -> void:
	allowed_min_floor = mini(min_floor, max_floor)
	allowed_max_floor = maxi(min_floor, max_floor)
	staging_floor = clampi(idle_staging_floor, allowed_min_floor, allowed_max_floor)


## Named simulation tuning seams used by run-only upgrades. Presentation never
## mutates these fields directly.
func set_travel_speed_multiplier(multiplier: float) -> void:
	travel_floors_per_second = DEFAULT_TRAVEL_FLOORS_PER_SECOND * maxf(0.1, multiplier)


func set_capacity_bonus(bonus: int) -> void:
	capacity = maxi(1, DEFAULT_CAPACITY + bonus)


func set_door_dwell_multiplier(multiplier: float) -> void:
	door_dwell_seconds = DEFAULT_DOOR_DWELL_SECONDS * maxf(0.05, multiplier)


func set_transfer_time_multiplier(multiplier: float) -> void:
	transfer_seconds = DEFAULT_TRANSFER_SECONDS * maxf(0.05, multiplier)


func set_idle_staging_floor(floor_value: int) -> void:
	staging_floor = clampi(floor_value, 1, building_floor_count)


func set_express_service_enabled(enabled: bool) -> void:
	express_service_enabled = enabled


func has_capacity() -> bool:
	return passengers.size() < capacity


func can_accept_request(request: ElevatorHallRequest) -> bool:
	if request.floor < allowed_min_floor or request.floor > allowed_max_floor:
		return false
	return compatible_waiting_count(request) > 0


func compatible_waiting_count(request: ElevatorHallRequest) -> int:
	var count := 0
	for passenger: ElevatorPassenger in request.waiting_passengers:
		if passenger.destination_floor >= allowed_min_floor and passenger.destination_floor <= allowed_max_floor:
			count += 1
	return count


func available_reservation_slots() -> int:
	return maxi(0, capacity - passengers.size() - reserved_pickup_count())


func reserved_pickup_count() -> int:
	var remaining := maxi(0, capacity - passengers.size())
	var reserved := 0
	for request: ElevatorHallRequest in assigned_hall_requests:
		if not request.is_active() or remaining == 0:
			continue
		var request_count := mini(remaining, compatible_waiting_count(request))
		reserved += request_count
		remaining -= request_count
	return reserved


func can_reserve_request(request: ElevatorHallRequest) -> bool:
	return available_reservation_slots() > 0 and can_accept_request(request)


func assign_hall_request(request: ElevatorHallRequest) -> void:
	if request.assigned_elevator_id != 0 and request.assigned_elevator_id != elevator_id:
		return
	if request not in assigned_hall_requests:
		assigned_hall_requests.append(request)
	request.assigned_elevator_id = elevator_id
	for passenger: ElevatorPassenger in request.waiting_passengers:
		passenger.assigned_elevator_id = elevator_id
		passenger.state = SimulationTypes.PassengerState.ASSIGNED


func next_stop() -> int:
	if service_direction == SimulationTypes.Direction.IDLE:
		return _nearest_assigned_pickup()

	var current_floor_request := _request_at_current_floor(service_direction)
	if current_floor_request != null:
		return current_floor
	var ahead := _nearest_stop_in_direction(service_direction)
	if ahead != 0:
		return ahead

	_set_service_direction(-service_direction)
	var reversed_stop := _nearest_stop_in_direction(service_direction)
	if reversed_stop != 0:
		return reversed_stop
	_set_service_direction(SimulationTypes.Direction.IDLE)
	return staging_floor if staging_floor != current_floor else 0


func step(delta: float, request_manager: ElevatorHallRequestManager) -> void:
	if movement_state == SimulationTypes.MovementState.STOPPED:
		door_dwell_remaining = maxf(0.0, door_dwell_remaining - delta)
		if is_zero_approx(door_dwell_remaining):
			process_current_floor(request_manager)
		return
	if movement_state == SimulationTypes.MovementState.IDLE:
		var next := next_stop()
		if next == current_floor:
			_arrive_at_current_floor()
		elif next != 0:
			target_floor = next
			movement_state = SimulationTypes.MovementState.MOVING
		return
	travel_floor = move_toward(travel_floor, float(target_floor), travel_floors_per_second * delta)
	if is_equal_approx(travel_floor, float(target_floor)):
		current_floor = target_floor
		target_floor = 0
		_arrive_at_current_floor()


## Runs the ordered stop lifecycle: dropoffs, then capacity-releasing pickups.
func process_current_floor(request_manager: ElevatorHallRequestManager) -> void:
	movement_state = SimulationTypes.MovementState.STOPPED
	door_state = SimulationTypes.DoorState.OPEN
	var exiting := _exit_passengers()
	_ = exiting
	_adopt_pickup_direction_if_needed()
	_board_compatible_passengers(request_manager)
	door_state = SimulationTypes.DoorState.CLOSED
	movement_state = SimulationTypes.MovementState.IDLE


func _arrive_at_current_floor() -> void:
	movement_state = SimulationTypes.MovementState.STOPPED
	door_state = SimulationTypes.DoorState.OPEN
	door_dwell_remaining = door_dwell_seconds + transfer_seconds
	elevator_arrived.emit(current_floor)
	doors_opened.emit(current_floor)


func _exit_passengers() -> Array[ElevatorPassenger]:
	var exiting: Array[ElevatorPassenger] = []
	for passenger: ElevatorPassenger in passengers.duplicate():
		if passenger.destination_floor != current_floor:
			continue
		passenger.state = SimulationTypes.PassengerState.EXITING
		passengers.erase(passenger)
		passenger.assigned_elevator_id = 0
		passenger.state = SimulationTypes.PassengerState.COMPLETED
		exiting.append(passenger)
		passenger_exited.emit(passenger, current_floor)
	if not _has_destination(current_floor):
		destination_requests.erase(current_floor)
	return exiting


func _board_compatible_passengers(request_manager: ElevatorHallRequestManager) -> void:
	if service_direction == SimulationTypes.Direction.IDLE:
		return
	for request: ElevatorHallRequest in assigned_hall_requests.duplicate():
		if request.floor != current_floor or request.direction != service_direction:
			continue
		for passenger: ElevatorPassenger in request.waiting_passengers.duplicate():
			if not has_capacity():
				break
			if not _passenger_is_compatible(passenger):
				continue
			passenger.state = SimulationTypes.PassengerState.BOARDING
			request_manager.remove_passenger_from_request(passenger)
			passenger.assigned_elevator_id = elevator_id
			passenger.state = SimulationTypes.PassengerState.RIDING
			passengers.append(passenger)
			destination_requests[passenger.destination_floor] = true
			passenger_boarded.emit(passenger, current_floor)
		assigned_hall_requests.erase(request)
		if request.is_active():
			request_manager.release_assignment(request)


func _nearest_assigned_pickup() -> int:
	var result := 0
	var distance := INF
	for request: ElevatorHallRequest in assigned_hall_requests:
		if not request.is_active():
			continue
		var request_distance := absi(request.floor - current_floor)
		if request_distance < distance or (request_distance == distance and request.floor < result):
			result = request.floor
			distance = request_distance
	return result


func _nearest_stop_in_direction(direction: int) -> int:
	var result := 0
	for floor_value: int in destination_requests:
		if _is_ahead(floor_value, direction) and (result == 0 or _is_nearer_in_direction(floor_value, result, direction)):
			result = floor_value
	for request: ElevatorHallRequest in assigned_hall_requests:
		if not request.is_active() or not _is_ahead(request.floor, direction):
			continue
		if not _can_serve_hall_request(request, direction):
			continue
		if request.direction == direction:
			if result == 0 or _is_nearer_in_direction(request.floor, result, direction):
				result = request.floor
	return result


func _request_at_current_floor(direction: int) -> ElevatorHallRequest:
	for request: ElevatorHallRequest in assigned_hall_requests:
		if request.is_active() and request.floor == current_floor and _can_serve_hall_request(request, direction):
			return request
	return null


func _can_serve_hall_request(request: ElevatorHallRequest, direction: int) -> bool:
	if request.direction != direction:
		return false
	# Express Service still permits compatible, same-direction pickups. It only
	# explicitly rejects work outside the current directional service sweep.
	if express_service_enabled and not passengers.is_empty():
		return request.direction == service_direction
	return true


func _adopt_pickup_direction_if_needed() -> void:
	if service_direction != SimulationTypes.Direction.IDLE:
		return
	for request: ElevatorHallRequest in assigned_hall_requests:
		if request.is_active() and request.floor == current_floor:
			_set_service_direction(request.direction)
			return


func _set_service_direction(next_direction: int) -> void:
	if service_direction == next_direction:
		return
	var previous := service_direction
	service_direction = next_direction
	elevator_direction_changed.emit(previous, next_direction)


func _passenger_is_compatible(passenger: ElevatorPassenger) -> bool:
	return passenger.destination_floor >= allowed_min_floor and passenger.destination_floor <= allowed_max_floor


func _has_destination(floor_value: int) -> bool:
	for passenger: ElevatorPassenger in passengers:
		if passenger.destination_floor == floor_value:
			return true
	return false


func _is_ahead(floor_value: int, direction: int) -> bool:
	return floor_value >= current_floor if direction == SimulationTypes.Direction.UP else floor_value <= current_floor


func _is_nearer_in_direction(candidate: int, current: int, direction: int) -> bool:
	return candidate < current if direction == SimulationTypes.Direction.UP else candidate > current
