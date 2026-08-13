class_name HallRequestManager
extends RefCounted

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")
const HallRequest := preload("res://scripts/simulation/hall_request.gd")

signal hall_request_created(request: HallRequest)
signal hall_request_completed(request: HallRequest)
signal request_completed(request: HallRequest)

var _floor_count: int
var _requests_by_key: Dictionary = {}


func _init(floor_count: int) -> void:
	_floor_count = floor_count


func register_waiting_passenger(passenger: RushPassenger, now: float) -> HallRequest:
	if not passenger.is_waiting() or not _is_valid_hall_call(passenger.origin_floor, passenger.requested_direction):
		return null

	var key := _request_key(passenger.origin_floor, passenger.requested_direction)
	var request: HallRequest = _requests_by_key.get(key)
	if request == null:
		request = HallRequest.new(passenger.origin_floor, passenger.requested_direction, now)
		_requests_by_key[key] = request
		hall_request_created.emit(request)

	request.add_passenger(passenger)
	return request


func remove_passenger_from_request(passenger: RushPassenger) -> void:
	var key := _request_key(passenger.origin_floor, passenger.requested_direction)
	var request: HallRequest = _requests_by_key.get(key)
	if request == null:
		return

	request.remove_passenger(passenger)
	if request.is_active():
		return

	_requests_by_key.erase(key)
	hall_request_completed.emit(request)
	request_completed.emit(request)


func remove_passenger(passenger: RushPassenger) -> void:
	remove_passenger_from_request(passenger)


func get_active_requests() -> Array[HallRequest]:
	var active: Array[HallRequest] = []
	for request: HallRequest in _requests_by_key.values():
		if request.is_active():
			active.append(request)
	return active


func get_unassigned_requests() -> Array[HallRequest]:
	var unassigned: Array[HallRequest] = []
	for request: HallRequest in get_active_requests():
		if request.assigned_elevator_id == 0:
			unassigned.append(request)
	return unassigned


## Releases a partially served shared call so its remaining passengers can be
## considered by the dispatcher again. Riders are removed before this is called,
## therefore every passenger here is still waiting at the landing.
func release_request_assignment(request: HallRequest) -> void:
	if not request.is_active():
		return

	request.assigned_elevator_id = 0
	for passenger: RushPassenger in request.waiting_passengers:
		passenger.assigned_elevator_id = 0
		if passenger.state == SimulationTypes.PassengerState.ASSIGNED:
			passenger.state = SimulationTypes.PassengerState.WAITING


func _is_valid_hall_call(floor: int, direction: int) -> bool:
	if floor < 1 or floor > _floor_count:
		return false
	if direction == SimulationTypes.Direction.IDLE:
		return false
	if floor == 1 and direction == SimulationTypes.Direction.DOWN:
		return false
	if floor == _floor_count and direction == SimulationTypes.Direction.UP:
		return false
	return true


func _request_key(floor: int, direction: int) -> String:
	return "%d:%d" % [floor, direction]
