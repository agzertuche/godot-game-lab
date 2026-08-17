class_name ElevatorHallRequestManager
extends RefCounted

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")
const HallRequest := preload("res://scripts/simulation/hall_request.gd")

signal hall_request_created(request: ElevatorHallRequest)
signal request_completed(request: ElevatorHallRequest)

var _floor_count: int
var _requests_by_key: Dictionary = {}


func _init(floor_count: int) -> void:
	_floor_count = floor_count


func register_waiting_passenger(passenger: ElevatorPassenger, now: float) -> ElevatorHallRequest:
	if not passenger.is_waiting() or not _is_valid_hall_call(passenger.origin_floor, passenger.requested_direction):
		return null

	var key := _request_key(passenger.origin_floor, passenger.requested_direction)
	var request: ElevatorHallRequest = _requests_by_key.get(key)
	if request == null:
		request = HallRequest.new(passenger.origin_floor, passenger.requested_direction, now)
		_requests_by_key[key] = request
		hall_request_created.emit(request)
	request.add_passenger(passenger)
	return request


func remove_passenger_from_request(passenger: ElevatorPassenger) -> void:
	var key := _request_key(passenger.origin_floor, passenger.requested_direction)
	var request: ElevatorHallRequest = _requests_by_key.get(key)
	if request == null:
		return
	request.remove_passenger(passenger)
	if request.is_active():
		return
	_requests_by_key.erase(key)
	request_completed.emit(request)


func release_assignment(request: ElevatorHallRequest) -> void:
	if not request.is_active():
		return
	request.assigned_elevator_id = 0
	for passenger: ElevatorPassenger in request.waiting_passengers:
		passenger.assigned_elevator_id = 0
		passenger.state = SimulationTypes.PassengerState.WAITING


func get_active_requests() -> Array[ElevatorHallRequest]:
	var active: Array[ElevatorHallRequest] = []
	for request: ElevatorHallRequest in _requests_by_key.values():
		if request.is_active():
			active.append(request)
	return active


func _is_valid_hall_call(floor: int, direction: int) -> bool:
	if floor < 1 or floor > _floor_count or direction == SimulationTypes.Direction.IDLE:
		return false
	return not (floor == 1 and direction == SimulationTypes.Direction.DOWN) \
		and not (floor == _floor_count and direction == SimulationTypes.Direction.UP)


func _request_key(floor: int, direction: int) -> String:
	return "%d:%d" % [floor, direction]
