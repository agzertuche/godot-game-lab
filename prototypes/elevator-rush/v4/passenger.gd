class_name V4Passenger
extends RefCounted

enum State { WAITING, ASSIGNED, BOARDING, RIDING, EXITING, COMPLETED, MISSED }
var id: int
var origin: int
var destination: int
var direction: int
var request_time: float
var patience := 25.0
var owner := 0
var state := State.WAITING
var pickup_wait := 0.0

func _init(identifier: int, from: int, to: int, now: float) -> void:
	id = identifier
	origin = from
	destination = to
	direction = signi(to - from)
	request_time = now

func waiting() -> bool:
	return state == State.WAITING or state == State.ASSIGNED

func remaining(now: float) -> float:
	return maxf(0.0, patience - (now - request_time))
