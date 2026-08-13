class_name ElevatorController
extends RefCounted

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

## Simulation-only collective controller. It owns elevator routing state but
## intentionally knows nothing about Nodes, tweening, sprites, or UI controls.

signal elevator_arrived(floor: int)
signal doors_opened(floor: int)
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


func add_hall_request(request: HallRequest) -> void:
	if request not in assigned_hall_requests:
		assigned_hall_requests.append(request)
	if elevator_id != 0:
		request.assigned_elevator_id = elevator_id


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

	var next := _nearest_stop_ahead(service_direction)
	if next != 0:
		target_floor = next
		return target_floor

	recalculate_service_direction()
	if service_direction == SimulationTypes.Direction.IDLE:
		target_floor = _nearest_assigned_pickup_floor()
		return target_floor

	target_floor = _nearest_stop_ahead(service_direction)
	return target_floor


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
	if _nearest_stop_ahead(reversed_direction) != 0:
		_set_service_direction(reversed_direction)
		return

	_set_service_direction(SimulationTypes.Direction.IDLE)


func arrive_at(floor: int) -> void:
	current_floor = floor
	target_floor = 0
	movement_state = SimulationTypes.MovementState.STOPPED
	elevator_arrived.emit(current_floor)


func open_doors() -> void:
	door_state = SimulationTypes.DoorState.OPEN
	doors_opened.emit(current_floor)


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
