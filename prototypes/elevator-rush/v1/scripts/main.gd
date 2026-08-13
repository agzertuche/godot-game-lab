extends Node2D

const FLOOR_COUNT := 6
const SESSION_SECONDS := 300.0
const ROUTE_LIMIT := 4
const PASSENGER_PATIENCE := 18.0
const DELIVERY_SCORE := 100
const PATIENCE_BONUS_MAX := 50
const MISS_PENALTY := 100
const RUSH_START_SECONDS := 200.0
const RUSH_END_SECONDS := 260.0

@export var elevator_scene: PackedScene
@export var passenger_scene: PackedScene

var floor_y_positions: Array[float] = [710.0, 600.0, 490.0, 380.0, 270.0, 160.0]
var elevators: Array[Elevator] = []
var selected_elevator_index := 0
var drafted_route: Array[int] = []
var session_time_left := SESSION_SECONDS
var spawn_time_left := 3.0
var score := 0
var delivered_count := 0
var missed_count := 0
var total_wait_time := 0.0
var session_active := true
var rush_announced := false
var rush_message_time := 0.0

@onready var elevators_root: Node2D = $Elevators
@onready var passengers_root: Node2D = $Passengers
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var delivered_label: Label = $CanvasLayer/DeliveredLabel
@onready var missed_label: Label = $CanvasLayer/MissedLabel
@onready var time_label: Label = $CanvasLayer/TimeLabel
@onready var status_label: Label = $CanvasLayer/StatusLabel
@onready var rush_label: Label = $CanvasLayer/RushLabel
@onready var route_label: Label = $CanvasLayer/RouteLabel
@onready var onboard_label: Label = $CanvasLayer/OnboardLabel
@onready var elevator_a_button: Button = $CanvasLayer/ElevatorAButton
@onready var elevator_b_button: Button = $CanvasLayer/ElevatorBButton
@onready var undo_button: Button = $CanvasLayer/UndoButton
@onready var clear_button: Button = $CanvasLayer/ClearButton
@onready var start_button: Button = $CanvasLayer/StartButton
@onready var results_panel: ColorRect = $CanvasLayer/ResultsPanel
@onready var results_label: Label = $CanvasLayer/ResultsPanel/ResultsLabel
@onready var play_again_button: Button = $CanvasLayer/ResultsPanel/PlayAgainButton
@onready var floor_buttons: Array[Button] = [
	$CanvasLayer/Floor1Button,
	$CanvasLayer/Floor2Button,
	$CanvasLayer/Floor3Button,
	$CanvasLayer/Floor4Button,
	$CanvasLayer/Floor5Button,
	$CanvasLayer/Floor6Button,
]


func _ready() -> void:
	randomize()
	_create_elevators()
	_apply_ui_contrast()
	_connect_controls()
	_reset_spawn_timer()
	_update_ui()
	queue_redraw()


func _process(delta: float) -> void:
	if not session_active:
		return

	session_time_left = maxf(0.0, session_time_left - delta)
	if session_time_left <= 0.0:
		_end_session()
		return

	_update_waiting_passengers(delta)
	spawn_time_left -= delta
	if spawn_time_left <= 0.0:
		_spawn_passenger()
		_reset_spawn_timer()

	var elapsed := SESSION_SECONDS - session_time_left
	if not rush_announced and elapsed >= RUSH_START_SECONDS:
		rush_announced = true
		rush_message_time = 4.0
		status_label.text = "Rush hour: passengers arrive much faster."

	if rush_message_time > 0.0:
		rush_message_time = maxf(0.0, rush_message_time - delta)

	_update_ui()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(540.0, 960.0)), Color("182033"))
	draw_rect(Rect2(0.0, 0.0, 540.0, 112.0), Color("0b1220"), true)
	draw_rect(Rect2(0.0, 736.0, 540.0, 224.0), Color("0b1220"), true)
	draw_rect(Rect2(78.0, 135.0, 236.0, 600.0), Color("263550"), true)
	draw_rect(Rect2(132.0, 135.0, 70.0, 600.0), Color("111827"), true)
	draw_rect(Rect2(216.0, 135.0, 70.0, 600.0), Color("111827"), true)

	for floor in range(FLOOR_COUNT):
		var y := floor_y_positions[floor] + 35.0
		draw_line(Vector2(78.0, y), Vector2(510.0, y), Color("5d718f"), 2.0)

	draw_string(ThemeDB.fallback_font, Vector2(135.0, 128.0), "A", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("b9d6ff"))
	draw_string(ThemeDB.fallback_font, Vector2(219.0, 128.0), "B", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("b9d6ff"))


func _create_elevators() -> void:
	var shafts := [167.0, 251.0]
	for index in range(shafts.size()):
		var elevator := elevator_scene.instantiate() as Elevator
		elevators_root.add_child(elevator)
		elevator.configure("A" if index == 0 else "B", floor_y_positions, shafts[index])
		elevator.stopped_at_floor.connect(_on_elevator_stopped.bind(elevator))
		elevator.route_finished.connect(_on_elevator_route_finished.bind(elevator))
		elevators.append(elevator)


func _connect_controls() -> void:
	elevator_a_button.pressed.connect(_select_elevator.bind(0))
	elevator_b_button.pressed.connect(_select_elevator.bind(1))
	undo_button.pressed.connect(_undo_route)
	clear_button.pressed.connect(_clear_route)
	start_button.pressed.connect(_start_route)
	play_again_button.pressed.connect(_play_again)

	for floor in range(1, FLOOR_COUNT + 1):
		floor_buttons[floor - 1].pressed.connect(_add_floor_to_route.bind(floor))


func _apply_ui_contrast() -> void:
	_apply_contrast_to($CanvasLayer)


func _apply_contrast_to(node: Node) -> void:
	if node is Label or node is Button:
		var control := node as Control
		control.add_theme_color_override("font_color", Color("f8fbff"))
		control.add_theme_color_override("font_outline_color", Color("08101e"))
		control.add_theme_constant_override("outline_size", 3)

	for child in node.get_children():
		_apply_contrast_to(child)


func _select_elevator(index: int) -> void:
	if not session_active:
		return

	selected_elevator_index = index
	drafted_route.clear()
	status_label.text = "Elevator %s selected." % elevators[index].elevator_name
	_update_ui()


func _add_floor_to_route(floor: int) -> void:
	if not session_active:
		return

	var route_limit := _selected_route_limit()
	if drafted_route.size() >= route_limit:
		if route_limit == 1:
			status_label.text = "Choose one pickup floor, then press GO TO PICKUP FLOOR."
		else:
			status_label.text = "A delivery route can hold at most %d stops." % ROUTE_LIMIT
		return

	drafted_route.append(floor)
	_update_ui()


func _undo_route() -> void:
	if not session_active or drafted_route.is_empty():
		return

	drafted_route.pop_back()
	_update_ui()


func _clear_route() -> void:
	if not session_active:
		return

	drafted_route.clear()
	_update_ui()


func _start_route() -> void:
	if not session_active or drafted_route.is_empty():
		return

	var elevator := elevators[selected_elevator_index]
	var is_pickup_trip := not elevator.has_riders()
	elevator.submit_route(drafted_route, is_pickup_trip)
	if elevator.has_riders():
		status_label.text = "Delivery route confirmed for Elevator %s." % elevator.elevator_name
	else:
		status_label.text = "Elevator %s is heading to the pickup floor." % elevator.elevator_name
	drafted_route.clear()
	_update_ui()


func _on_elevator_stopped(floor: int, is_pickup_stop: bool, elevator: Elevator) -> void:
	for passenger in elevator.drop_off_at(floor):
		_deliver_passenger(passenger)

	var boarded_count := 0
	if is_pickup_stop:
		for passenger in _waiting_passengers_on_floor(floor):
			if not elevator.can_board():
				break
			passenger.board()
			elevator.board(passenger)
			boarded_count += 1

	_reposition_waiting_passengers()
	if boarded_count > 0:
		status_label.text = "%d passengers boarded Elevator %s. Enter their delivery floors." % [boarded_count, elevator.elevator_name]
	elif elevator.has_riders():
		status_label.text = "Elevator %s stopped at floor %d with riders still onboard." % [elevator.elevator_name, floor]
	else:
		status_label.text = "Elevator %s stopped at floor %d. No passengers waiting." % [elevator.elevator_name, floor]
	_update_ui()


func _on_elevator_route_finished(elevator: Elevator) -> void:
	if session_active:
		if elevator.has_riders():
			status_label.text = "Elevator %s has riders. Select it and enter delivery floors." % elevator.elevator_name
		else:
			status_label.text = "Elevator %s is ready. Choose one pickup floor." % elevator.elevator_name
		_update_ui()


func _spawn_passenger() -> void:
	var spawn_floor := randi_range(1, FLOOR_COUNT)
	var destination_floor := randi_range(1, FLOOR_COUNT)
	while destination_floor == spawn_floor:
		destination_floor = randi_range(1, FLOOR_COUNT)

	var passenger := passenger_scene.instantiate() as Passenger
	passengers_root.add_child(passenger)
	passenger.configure(spawn_floor, destination_floor, PASSENGER_PATIENCE)
	_reposition_waiting_passengers()


func _update_waiting_passengers(delta: float) -> void:
	for node in passengers_root.get_children():
		var passenger := node as Passenger
		if passenger == null or not passenger.is_waiting:
			continue

		passenger.tick_waiting(delta)
		if passenger.is_expired():
			_miss_passenger(passenger)


func _waiting_passengers_on_floor(floor: int) -> Array[Passenger]:
	var waiting: Array[Passenger] = []
	for node in passengers_root.get_children():
		var passenger := node as Passenger
		if passenger != null and passenger.is_waiting and passenger.current_floor == floor:
			waiting.append(passenger)
	return waiting


func _reposition_waiting_passengers() -> void:
	for floor in range(1, FLOOR_COUNT + 1):
		var waiting := _waiting_passengers_on_floor(floor)
		for index in range(waiting.size()):
			waiting[index].position = Vector2(326.0 + index * 44.0, floor_y_positions[floor - 1] - 34.0)


func _deliver_passenger(passenger: Passenger) -> void:
	var patience_bonus := roundi(passenger.remaining_patience_ratio() * PATIENCE_BONUS_MAX)
	score += DELIVERY_SCORE + patience_bonus
	delivered_count += 1
	total_wait_time += passenger.wait_time
	passenger.queue_free()


func _miss_passenger(passenger: Passenger) -> void:
	missed_count += 1
	score -= MISS_PENALTY
	passenger.queue_free()
	_reposition_waiting_passengers()
	status_label.text = "A passenger left. -%d points." % MISS_PENALTY


func _reset_spawn_timer() -> void:
	var elapsed := SESSION_SECONDS - session_time_left
	if elapsed < 100.0:
		spawn_time_left = randf_range(5.0, 7.0)
	elif elapsed < RUSH_START_SECONDS:
		spawn_time_left = randf_range(3.0, 5.0)
	elif elapsed < RUSH_END_SECONDS:
		spawn_time_left = randf_range(1.0, 3.0)
	else:
		spawn_time_left = randf_range(3.0, 4.0)


func _end_session() -> void:
	session_active = false
	for elevator in elevators:
		elevator.set_operational(false)

	results_label.text = "Final score: %d\nDelivered: %d\nMissed: %d\nAverage wait: %.1f seconds" % [
		score,
		delivered_count,
		missed_count,
		_average_wait_time(),
	]
	results_panel.visible = true
	_update_ui()


func _average_wait_time() -> float:
	if delivered_count == 0:
		return 0.0
	return total_wait_time / delivered_count


func _play_again() -> void:
	get_tree().reload_current_scene()


func _update_ui() -> void:
	var selected_elevator := elevators[selected_elevator_index]
	var drafted_text := _route_text(drafted_route)
	var running_text := selected_elevator.route_summary()
	var route_mode := "DELIVERY" if selected_elevator.has_riders() else "PICKUP"
	var route_limit := _selected_route_limit()
	score_label.text = "Score: %d" % score
	delivered_label.text = "Delivered: %d" % delivered_count
	missed_label.text = "Missed: %d" % missed_count
	time_label.text = "Time: %d:%02d" % [floori(session_time_left / 60.0), floori(fmod(session_time_left, 60.0))]
	route_label.text = "Elevator %s %s route: %s    Active: %s" % [
		selected_elevator.elevator_name,
		route_mode,
		drafted_text,
		running_text if not running_text.is_empty() else "-",
	]
	onboard_label.text = "Onboard %s: %s" % [selected_elevator.elevator_name, selected_elevator.rider_destinations()]
	rush_label.visible = rush_message_time > 0.0

	for index in range(elevators.size()):
		elevators[index].set_selected(index == selected_elevator_index)

	for button in floor_buttons:
		button.disabled = not session_active or drafted_route.size() >= route_limit
	undo_button.disabled = not session_active or drafted_route.is_empty()
	clear_button.disabled = not session_active or drafted_route.is_empty()
	start_button.disabled = not session_active or drafted_route.is_empty()
	start_button.text = "START DELIVERY" if selected_elevator.has_riders() else "GO TO PICKUP FLOOR"
	elevator_a_button.disabled = not session_active
	elevator_b_button.disabled = not session_active


func _route_text(route: Array[int]) -> String:
	if route.is_empty():
		return "-"

	var stops: Array[String] = []
	for floor in route:
		stops.append(str(floor))
	return " → ".join(stops)


func _selected_route_limit() -> int:
	if elevators[selected_elevator_index].has_riders():
		return ROUTE_LIMIT
	return 1
