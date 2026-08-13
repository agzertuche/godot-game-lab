class_name RushPassenger
extends Node2D

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

## Compatibility aliases kept while the presentation scene is migrated to the
## request-driven controller. Simulation state itself uses SimulationTypes.
enum State {
	WAITING = SimulationTypes.PassengerState.WAITING,
	RIDING = SimulationTypes.PassengerState.RIDING,
	ARRIVED = SimulationTypes.PassengerState.COMPLETED,
}

var origin_floor := 1
var destination_floor := 4
var requested_direction := SimulationTypes.Direction.UP
var request_time := 0.0
var wait_time := 0.0
var state := SimulationTypes.PassengerState.WAITING
var assigned_elevator_id := 0

## Temporary presentation compatibility. New simulation code should use
## request_time, while existing views may still read spawned_at.
var spawned_at := 0.0


func configure(origin: int, destination: int, spawn_time: float) -> void:
	origin_floor = origin
	destination_floor = destination
	requested_direction = _direction_for_trip(origin_floor, destination_floor)
	request_time = spawn_time
	spawned_at = spawn_time
	state = SimulationTypes.PassengerState.WAITING
	assigned_elevator_id = 0
	queue_redraw()


func is_waiting() -> bool:
	return state == SimulationTypes.PassengerState.WAITING \
		or state == SimulationTypes.PassengerState.ASSIGNED


func _direction_for_trip(origin: int, destination: int) -> int:
	if destination > origin:
		return SimulationTypes.Direction.UP
	if destination < origin:
		return SimulationTypes.Direction.DOWN
	return SimulationTypes.Direction.IDLE


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color("facc15"))
	draw_circle(Vector2.ZERO, 12.0, Color("fff7d6"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-10.0, 4.0), str(destination_floor), HORIZONTAL_ALIGNMENT_CENTER, 20.0, 12, Color("172554"))
