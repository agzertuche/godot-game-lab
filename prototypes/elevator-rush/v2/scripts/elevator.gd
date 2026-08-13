class_name RushElevator
extends Node2D

const ElevatorController := preload("res://scripts/simulation/elevator_controller.gd")
const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

## Presentation adapter for ElevatorController. This node renders and animates
## state supplied by simulation; it never assigns passenger demand or chooses a
## route from the global waiting-passenger list.

enum State { IDLE, MOVING, BOARDING }
enum Behavior { NORMAL, UP_BIAS, DOWN_BIAS, UP_ONLY, DOWN_ONLY }

const STRATEGY_COOLDOWN_SECONDS := 8.0

var elevator_id := 1
var current_floor := 1
var direction := 0
var last_travel_direction := 1
var target_floor := 1
var state := State.IDLE
var allowed_min := 1
var allowed_max := 10
var staging_floor := 1
var behavior_rule := Behavior.NORMAL
var pending_strategy: Dictionary = {}
var strategy_cooldown_left := 0.0
var strategy_change_count := 0

## Presentation metrics and mirrors. The authoritative passenger and route
## state is ElevatorController; Main owns the simulation tick.
var passengers: Array[RushPassenger] = []
var busy_time := 0.0
var transported_count := 0
var stop_count := 0
var floor_y_positions: Array[float] = []
var controller: ElevatorController


func configure(identifier: int, floor_positions: Array[float]) -> void:
	elevator_id = identifier
	floor_y_positions = floor_positions.duplicate()
	bind_controller(ElevatorController.new(identifier, current_floor))
	position.y = _floor_y(current_floor)
	queue_redraw()


func bind_controller(value: ElevatorController) -> void:
	controller = value
	sync_presentation()


func set_strategy(min_floor: int, max_floor: int, stage_floor: int, behavior: int = Behavior.NORMAL) -> void:
	allowed_min = mini(min_floor, max_floor)
	allowed_max = maxi(min_floor, max_floor)
	staging_floor = clampi(stage_floor, allowed_min, allowed_max)
	behavior_rule = behavior
	queue_redraw()


func request_strategy(min_floor: int, max_floor: int, stage_floor: int, behavior: int) -> void:
	pending_strategy = _make_strategy(min_floor, max_floor, stage_floor, behavior)
	strategy_cooldown_left = STRATEGY_COOLDOWN_SECONDS
	strategy_change_count += 1
	queue_redraw()


func clear_live_strategy_state() -> void:
	pending_strategy.clear()
	strategy_cooldown_left = 0.0
	strategy_change_count = 0
	queue_redraw()


func can_serve(passenger: RushPassenger) -> bool:
	return controller != null and passenger.origin_floor >= controller.allowed_min and passenger.origin_floor <= controller.allowed_max and passenger.destination_floor >= controller.allowed_min and passenger.destination_floor <= controller.allowed_max


func has_capacity() -> bool:
	return controller == null or controller.has_capacity()


func tick_strategy_cooldown(delta: float) -> void:
	strategy_cooldown_left = maxf(0.0, strategy_cooldown_left - delta)


func behavior_name(rule: int = -1) -> String:
	if rule == -1:
		rule = behavior_rule
	match rule:
		Behavior.UP_BIAS:
			return "UP BIAS"
		Behavior.DOWN_BIAS:
			return "DOWN BIAS"
		Behavior.UP_ONLY:
			return "UP ONLY"
		Behavior.DOWN_ONLY:
			return "DOWN ONLY"
	return "NORMAL"


func strategy_summary() -> String:
	return "%d–%d F%d %s" % [allowed_min, allowed_max, staging_floor, behavior_name()]


func pending_strategy_summary() -> String:
	if pending_strategy.is_empty():
		return ""
	return "%d–%d F%d %s" % [pending_strategy["min"], pending_strategy["max"], pending_strategy["stage"], behavior_name(int(pending_strategy["behavior"]))]


func _make_strategy(min_floor: int, max_floor: int, stage_floor: int, behavior: int) -> Dictionary:
	var minimum := mini(min_floor, max_floor)
	var maximum := maxi(min_floor, max_floor)
	return {"min": minimum, "max": maximum, "stage": clampi(stage_floor, minimum, maximum), "behavior": behavior}


func sync_presentation() -> void:
	if controller == null:
		return
	current_floor = controller.current_floor
	target_floor = controller.target_floor
	direction = signi(target_floor - current_floor) if target_floor != 0 else 0
	if direction != 0:
		last_travel_direction = direction
	if controller.door_state == SimulationTypes.DoorState.OPEN:
		state = State.BOARDING
	elif controller.movement_state == SimulationTypes.MovementState.MOVING:
		state = State.MOVING
	else:
		state = State.IDLE
	passengers = controller.passengers
	position.y = _floor_y_for_travel_position(controller.travel_floor)
	queue_redraw()


func _floor_y(floor: int) -> float:
	return floor_y_positions[floor - 1]


func _floor_y_for_travel_position(floor_position: float) -> float:
	var lower_floor := clampi(floori(floor_position), 1, floor_y_positions.size())
	var upper_floor := clampi(ceili(floor_position), 1, floor_y_positions.size())
	return lerpf(_floor_y(lower_floor), _floor_y(upper_floor), floor_position - float(lower_floor))


func _draw() -> void:
	var color := Color("38bdf8") if state != State.IDLE else Color("60a5fa")
	draw_rect(Rect2(-25.0, -22.0, 50.0, 44.0), color, true)
	draw_rect(Rect2(-25.0, -22.0, 50.0, 44.0), Color("e0f2fe"), false, 2.0)
	var rider_positions := [Vector2(-11.0, -10.0), Vector2(11.0, -10.0), Vector2(-11.0, 10.0), Vector2(11.0, 10.0)]
	for index in range(passengers.size()):
		var rider_position: Vector2 = rider_positions[index]
		draw_circle(rider_position, 9.0, Color("facc15"))
		draw_circle(rider_position, 9.0, Color("fff7d6"), false, 1.5)
		draw_string(ThemeDB.fallback_font, rider_position + Vector2(-9.0, 3.5), str(passengers[index].destination_floor), HORIZONTAL_ALIGNMENT_CENTER, 18.0, 10, Color("172554"))
	var live_label := behavior_name()
	if not pending_strategy.is_empty():
		live_label = "PENDING\n" + behavior_name(int(pending_strategy["behavior"]))
	draw_rect(Rect2(-34.0, 27.0, 68.0, 23.0), Color("020617d9"), true)
	draw_string(ThemeDB.fallback_font, Vector2(-32.0, 36.0), live_label, HORIZONTAL_ALIGNMENT_CENTER, 64.0, 8, Color("f8fafc"))
