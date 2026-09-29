class_name V4HallRequests
extends RefCounted

signal request_created(key: String)
signal request_completed(key: String)
var groups: Dictionary = {}
var passengers: Dictionary = {}

func register(p: V4Passenger) -> void:
	passengers[p.id] = p
	var key := "%d:%d" % [p.origin, p.direction]
	if not groups.has(key):
		groups[key] = []
		request_created.emit(key)
	groups[key].append(p)

func remove(p: V4Passenger) -> void:
	var key := "%d:%d" % [p.origin, p.direction]
	if not groups.has(key):
		return
	groups[key].erase(p)
	if groups[key].is_empty():
		groups.erase(key)
		request_completed.emit(key)

func reserve(passenger_id: int, car_id: int) -> bool:
	var p: V4Passenger = passengers.get(passenger_id)
	if p == null or not p.waiting() or p.owner != 0:
		return false
	p.owner = car_id
	p.state = V4Passenger.State.ASSIGNED
	return true

func release(passenger_id: int) -> void:
	var p: V4Passenger = passengers.get(passenger_id)
	if p != null and p.waiting():
		p.owner = 0
		p.state = V4Passenger.State.WAITING

func assigned(car_id: int) -> Array[V4Passenger]:
	var result: Array[V4Passenger] = []
	for p: V4Passenger in passengers.values():
		if p.owner == car_id and p.waiting():
			result.append(p)
	return result
