class_name ElevatorController
extends RefCounted

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

## Simulation-only collective controller. It owns elevator routing state but
## intentionally knows nothing about Nodes, tweening, sprites, or UI controls.

signal elevator_arrived(floor: int)
signal doors_opened(floor: int)
signal passenger_boarded(passenger: RushPassenger, floor: int)
signal passenger_exited(passenger: RushPassenger, floor: int)
signal elevator_direction_changed(previous_direction: int, new_direction: int)

const CAPACITY := 4

var elevator_id := 0
var current_floor := 1
var movement_state := SimulationTypes.MovementState.IDLE
var service_direction := SimulationTypes.Direction.IDLE
var passengers: Array[RushPassenger] = []
var capacity := CAPACITY
var assigned_hall_requests: Array[HallRequest] = []
var destination_requests: Dictionary = {}
var door_state := SimulationTypes.DoorState.CLOSED
var target_floor := 0


func _init(identifier: int = 0, starting_floor: int = 1) -> void:
	elevator_id = identifier
	current_floor = starting_floor


func has_capacity() -> bool:
	return passengers.size() < capacity


func assign_hall_request(request: HallRequest) -> void:
	if request.assigned_elevator_id != 0 and request.assigned_elevator_id != elevator_id:
		return
	if request not in assigned_hall_requests:
		assigned_hall_requests.append(request)
	request.assigned_elevator_id = elevator_id
	for passenger: RushPassenger in request.waiting_passengers:
		passenger.assigned_elevator_id = elevator_id
		if passenger.state == SimulationTypes.PassengerState.WAITING:
			passenger.state = SimulationTypes.PassengerState.ASSIGNED


func remove_hall_request(request: HallRequest) -> void:
	assigned_hall_requests.erase(request)


func add_destination_request(floor: int) -> void:
	if floor > 0:
		destination_requests[floor] = true


func remove_destination_request(floor: int) -> void:
	destination_requests.erase(floor)


func is_request_compatible(request: HallRequest) -> bool:
	if service_direction == SimulationTypes.Direction.UP:
		return request.direction == SimulationTypes.Direction.UP and request.floor >= current_floor
	if service_direction == SimulationTypes.Direction.DOWN:
		return request.direction == SimulationTypes.Direction.DOWN and request.floor <= current_floor
	return true


func next_stop() -> int:
	if service_direction == SimulationTypes.Direction.IDLE:
		target_floor = _nearest_assigned_pickup_floor()
		return target_floor

	var current_request := _request_at_floor_for_direction(service_direction)
	if current_request != null:
		target_floor = current_floor
		return target_floor

	var next := _nearest_stop_ahead(service_direction)
	if next != 0:
		target_floor = next
		return target_floor

	recalculate_service_direction()
	if service_direction == SimulationTypes.Direction.IDLE:
		target_floor = _nearest_assigned_pickup_floor()
		return target_floor

	current_request = _request_at_floor_for_direction(service_direction)
	if current_request != null:
		target_floor = current_floor
		return target_floor

	target_floor = _nearest_stop_ahead(service_direction)
	return target_floor


func begin_moving_to(floor: int) -> void:
	if floor == current_floor or floor <= 0:
		return
	target_floor = floor
	movement_state = SimulationTypes.MovementState.MOVING


func recalculate_service_direction() -> void:
	if service_direction == SimulationTypes.Direction.IDLE:
		var request_at_current_floor := _request_at_current_floor()
		if request_at_current_floor != null:
			_set_service_direction(request_at_current_floor.direction)
			return
		if not passengers.is_empty():
			_set_service_direction(_direction_toward(_nearest_destination_floor()))
		return

	if _nearest_stop_ahead(service_direction) != 0:
		return

	var reversed_direction := -service_direction
	if _request_at_floor_for_direction(reversed_direction) != null:
		_set_service_direction(reversed_direction)
		return
	if _nearest_stop_ahead(reversed_direction) != 0:
		_set_service_direction(reversed_direction)
		return

	_set_service_direction(SimulationTypes.Direction.IDLE)


func arrive_at(floor: int) -> void:
	current_floor = floor
	target_floor = 0
	movement_state = SimulationTypes.MovementState.STOPPED
	elevator_arrived.emit(current_floor)


func complete_stop() -> void:
	movement_state = SimulationTypes.MovementState.IDLE
	door_state = SimulationTypes.DoorState.CLOSED


func open_doors() -> void:
	door_state = SimulationTypes.DoorState.OPEN
	doors_opened.emit(current_floor)


## Completes one simulation stop without relying on animation callbacks.
##
## The lifecycle intentionally mirrors collective elevator operation: riders
## leave first, then compatible assigned landing passengers enter. A partially
## served hall request is released to the dispatcher so another car can serve
## the remaining demand rather than waiting on a full elevator indefinitely.
func process_stop(request_manager: HallRequestManager, now: float) -> Dictionary:
	assert(movement_state == SimulationTypes.MovementState.STOPPED, "process_stop requires arrive_at before transfers")
	open_doors()

	var exited: Array[RushPassenger] = _exit_passengers_at_current_floor()
	var boarded: Array[RushPassenger] = _board_compatible_passengers(request_manager)

	door_state = SimulationTypes.DoorState.CLOSED
	movement_state = SimulationTypes.MovementState.IDLE
	recalculate_service_direction()
	var following_stop := next_stop()
	return {
		"floor": current_floor,
		"exited": exited,
		"boarded": boarded,
		"next_stop": following_stop,
	}


func _exit_passengers_at_current_floor() -> Array[RushPassenger]:
	var exited: Array[RushPassenger] = []
	for passenger: RushPassenger in passengers.duplicate():
		if passenger.destination_floor != current_floor:
			continue

		passenger.state = SimulationTypes.PassengerState.EXITING
		passengers.erase(passenger)
		passenger.assigned_elevator_id = 0
		passenger.state = SimulationTypes.PassengerState.COMPLETED
		exited.append(passenger)
		passenger_exited.emit(passenger, current_floor)

	if not _has_passenger_destination(current_floor):
		remove_destination_request(current_floor)
	return exited


func _board_compatible_passengers(request_manager: HallRequestManager) -> Array[RushPassenger]:
	var boarded: Array[RushPassenger] = []
	_adopt_pickup_direction_if_idle()
	var boarding_direction := service_direction
	if boarding_direction == SimulationTypes.Direction.IDLE:
		return boarded

	for request: HallRequest in assigned_hall_requests.duplicate():
		if request.floor != current_floor or request.direction != boarding_direction:
			continue
		if not request.is_active():
			remove_hall_request(request)
			continue

		for passenger: RushPassenger in request.waiting_passengers.duplicate():
			if not has_capacity():
				break
			if passenger.requested_direction != boarding_direction:
				continue

			passenger.state = SimulationTypes.PassengerState.BOARDING
			request_manager.remove_passenger_from_request(passenger)
			passenger.assigned_elevator_id = elevator_id
			passenger.state = SimulationTypes.PassengerState.RIDING
			passengers.append(passenger)
			add_destination_request(passenger.destination_floor)
			boarded.append(passenger)
			passenger_boarded.emit(passenger, current_floor)

		if not request.is_active():
			remove_hall_request(request)
		elif not has_capacity():
			remove_hall_request(request)
			request_manager.release_request_assignment(request)

	return boarded


func _adopt_pickup_direction_if_idle() -> void:
	if service_direction != SimulationTypes.Direction.IDLE:
		return
	var request := _request_at_current_floor()
	if request != null:
		_set_service_direction(request.direction)


func _has_passenger_destination(floor: int) -> bool:
	for passenger: RushPassenger in passengers:
		if passenger.destination_floor == floor:
			return true
	return false


func _nearest_stop_ahead(direction: int) -> int:
	var nearest := 0
	for destination_floor: int in destination_requests:
		if _is_ahead(destination_floor, direction):
			nearest = _closer_floor(nearest, destination_floor, direction)
	for request: HallRequest in assigned_hall_requests:
		if request.is_active() and request.direction == direction and _is_ahead(request.floor, direction):
			nearest = _closer_floor(nearest, request.floor, direction)
	return nearest


func _nearest_assigned_pickup_floor() -> int:
	var nearest := 0
	for request: HallRequest in assigned_hall_requests:
		if request.is_active():
			var distance := absi(request.floor - current_floor)
			var nearest_distance := absi(nearest - current_floor)
			if nearest == 0 or distance < nearest_distance or (distance == nearest_distance and request.floor < nearest):
				nearest = request.floor
	return nearest


func _nearest_destination_floor() -> int:
	var nearest := 0
	for destination_floor: int in destination_requests:
		var distance := absi(destination_floor - current_floor)
		var nearest_distance := absi(nearest - current_floor)
		if nearest == 0 or distance < nearest_distance or (distance == nearest_distance and destination_floor < nearest):
			nearest = destination_floor
	return nearest


func _request_at_current_floor() -> HallRequest:
	for request: HallRequest in assigned_hall_requests:
		if request.is_active() and request.floor == current_floor:
			return request
	return null


func _request_at_floor_for_direction(direction: int) -> HallRequest:
	for request: HallRequest in assigned_hall_requests:
		if request.is_active() and request.floor == current_floor and request.direction == direction:
			return request
	return null


func _is_ahead(floor: int, direction: int) -> bool:
	return floor > current_floor if direction == SimulationTypes.Direction.UP else floor < current_floor


func _closer_floor(current_nearest: int, candidate: int, direction: int) -> int:
	if current_nearest == 0:
		return candidate
	if direction == SimulationTypes.Direction.UP:
		return mini(current_nearest, candidate)
	return maxi(current_nearest, candidate)


func _direction_toward(floor: int) -> int:
	if floor > current_floor:
		return SimulationTypes.Direction.UP
	if floor < current_floor:
		return SimulationTypes.Direction.DOWN
	return SimulationTypes.Direction.IDLE


func _set_service_direction(new_direction: int) -> void:
	if service_direction == new_direction:
		return
	var previous_direction := service_direction
	service_direction = new_direction
	elevator_direction_changed.emit(previous_direction, service_direction)
