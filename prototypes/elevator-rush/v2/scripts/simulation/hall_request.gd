class_name HallRequest
extends RefCounted

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

## A shared hall call. All passengers on one floor travelling in the same
## direction belong to exactly one request until each has boarded or left.
var floor: int
var direction: int
var created_at: float
var waiting_passengers: Array[RushPassenger] = []
var assigned_elevator_id := 0


func _init(request_floor: int, request_direction: int, time_created: float) -> void:
	floor = request_floor
	direction = request_direction
	created_at = time_created


func waiting_time(now: float) -> float:
	return maxf(0.0, now - created_at)


func add_passenger(passenger: RushPassenger) -> void:
	if passenger not in waiting_passengers:
		waiting_passengers.append(passenger)
	if assigned_elevator_id != 0:
		passenger.assigned_elevator_id = assigned_elevator_id
		if passenger.state == SimulationTypes.PassengerState.WAITING:
			passenger.state = SimulationTypes.PassengerState.ASSIGNED


func remove_passenger(passenger: RushPassenger) -> void:
	waiting_passengers.erase(passenger)


func is_active() -> bool:
	return not waiting_passengers.is_empty()


func matches(request_floor: int, request_direction: int) -> bool:
	return floor == request_floor and direction == request_direction
