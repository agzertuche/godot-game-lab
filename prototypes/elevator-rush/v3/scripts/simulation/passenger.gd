class_name ElevatorPassenger
extends RefCounted

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

## Demand data only. Passengers do not decide where elevators travel.
var origin_floor: int
var destination_floor: int
var requested_direction: int
var request_time: float
var assigned_elevator_id := 0
var state := SimulationTypes.PassengerState.WAITING


func _init(origin: int, destination: int, created_at: float) -> void:
	origin_floor = origin
	destination_floor = destination
	request_time = created_at
	requested_direction = _direction_for_trip(origin, destination)


func waiting_time(now: float) -> float:
	return maxf(0.0, now - request_time)


func is_waiting() -> bool:
	return state == SimulationTypes.PassengerState.WAITING \
		or state == SimulationTypes.PassengerState.ASSIGNED


func _direction_for_trip(origin: int, destination: int) -> int:
	if destination > origin:
		return SimulationTypes.Direction.UP
	if destination < origin:
		return SimulationTypes.Direction.DOWN
	return SimulationTypes.Direction.IDLE
