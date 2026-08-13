class_name Elevator
extends Node2D

signal stopped_at_floor(floor: int, is_pickup_stop: bool)
signal route_finished

const CAPACITY := 4
const MOVE_SPEED := 260.0

var elevator_name := "A"
var current_floor := 1
var floor_y_positions: Array[float] = []
var active_route: Array[int] = []
var pending_route: Array[int] = []
var active_route_is_pickup := false
var pending_route_is_pickup := false
var riders: Array[Passenger] = []
var is_moving := false
var is_operational := true

@onready var cabin: ColorRect = $Cabin
@onready var name_label: Label = $NameLabel
@onready var load_label: Label = $LoadLabel


func configure(identifier: String, floors: Array[float], shaft_x: float) -> void:
	elevator_name = identifier
	floor_y_positions = floors.duplicate()
	position = Vector2(shaft_x, _floor_y(current_floor))
	_update_visuals()


func submit_route(stops: Array[int], is_pickup_trip: bool) -> void:
	if stops.is_empty():
		return

	if is_moving or not active_route.is_empty() or not pending_route.is_empty():
		pending_route = stops.duplicate()
		pending_route_is_pickup = is_pickup_trip
	else:
		active_route = stops.duplicate()
		active_route_is_pickup = is_pickup_trip
		_begin_next_stop()


func can_board() -> bool:
	return riders.size() < CAPACITY


func board(passenger: Passenger) -> void:
	if can_board():
		riders.append(passenger)


func drop_off_at(floor: int) -> Array[Passenger]:
	var delivered: Array[Passenger] = []
	for passenger in riders.duplicate():
		if passenger.destination_floor == floor:
			riders.erase(passenger)
			delivered.append(passenger)
	_update_visuals()
	return delivered


func set_selected(selected: bool) -> void:
	if selected:
		cabin.color = Color(0.35, 0.82, 0.58, 1.0)
	else:
		cabin.color = Color(0.31, 0.47, 0.67, 1.0)


func set_operational(enabled: bool) -> void:
	is_operational = enabled


func has_riders() -> bool:
	return not riders.is_empty()


func rider_destinations() -> String:
	if riders.is_empty():
		return "none"

	var destinations: Array[String] = []
	for passenger in riders:
		destinations.append("F%d" % passenger.destination_floor)
	return " → ".join(destinations)


func route_summary() -> String:
	var stops: Array[String] = []
	for floor in active_route:
		stops.append(str(floor))
	for floor in pending_route:
		stops.append("[%d]" % floor)
	return " → ".join(stops)


func _ready() -> void:
	name_label.add_theme_color_override("font_color", Color("f8fbff"))
	name_label.add_theme_color_override("font_outline_color", Color("08101e"))
	name_label.add_theme_constant_override("outline_size", 2)
	load_label.add_theme_color_override("font_color", Color("f8fbff"))
	load_label.add_theme_color_override("font_outline_color", Color("08101e"))
	load_label.add_theme_constant_override("outline_size", 2)
	_update_visuals()


func _process(delta: float) -> void:
	if not is_operational or not is_moving:
		return

	var target_y := _floor_y(active_route[0])
	position.y = move_toward(position.y, target_y, MOVE_SPEED * delta)
	if is_equal_approx(position.y, target_y):
		_arrive_at_current_stop()


func _begin_next_stop() -> void:
	if not is_operational:
		return

	if active_route.is_empty():
		if pending_route.is_empty():
			route_finished.emit()
			return
		active_route = pending_route.duplicate()
		active_route_is_pickup = pending_route_is_pickup
		pending_route.clear()
		pending_route_is_pickup = false

	if active_route[0] == current_floor:
		call_deferred("_arrive_at_current_stop")
		return

	is_moving = true


func _arrive_at_current_stop() -> void:
	if active_route.is_empty():
		return

	is_moving = false
	var is_pickup_stop := active_route_is_pickup
	current_floor = active_route.pop_front()
	position.y = _floor_y(current_floor)
	_update_visuals()
	stopped_at_floor.emit(current_floor, is_pickup_stop)
	call_deferred("_begin_next_stop")


func _floor_y(floor: int) -> float:
	return floor_y_positions[floor - 1]


func _update_visuals() -> void:
	if not is_instance_valid(name_label):
		return

	name_label.text = elevator_name
	load_label.text = "%d / %d" % [riders.size(), CAPACITY]
