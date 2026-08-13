extends Node2D

const FLOOR_COUNT := 10
const ELEVATOR_COUNT := 3
const WAVE_SECONDS := 60.0
const PASS_GRADE := 8.0
const LEVELS := [
	{"name": "MORNING RUSH", "forecast": "Lobby-heavy upward traffic: Floor 1 → Floors 4–10.", "passengers": 50, "seed": 20260811, "pattern": "morning"},
	{"name": "MIDDAY EXCHANGE", "forecast": "Mixed traffic: lobby arrivals and office-to-lobby returns.", "passengers": 54, "seed": 20260812, "pattern": "midday"},
	{"name": "EVENING EXIT", "forecast": "Upper-floor-heavy downward traffic: Floors 4–10 → Floor 1.", "passengers": 58, "seed": 20260813, "pattern": "evening"},
]

enum Phase { PREPARATION, RUNNING, RESULTS }

@export var elevator_script: Script
@export var passenger_script: Script

var floor_y_positions: Array[float] = [650.0, 594.0, 538.0, 482.0, 426.0, 370.0, 314.0, 258.0, 202.0, 146.0]
var phase := Phase.PREPARATION
var wave_time := 0.0
var spawn_index := 0
var passenger_schedule: Array[Dictionary] = []
var passengers: Array[RushPassenger] = []
var elevators: Array[RushElevator] = []
var delivered_count := 0
var total_wait_time := 0.0
var longest_wait_time := 0.0
var current_level_index := 0
var last_grade := 0.0

@onready var elevators_root: Node2D = $Building/Elevators
@onready var passengers_root: Node2D = $Building/Passengers
@onready var phase_label: Label = $UI/PhaseLabel
@onready var simulation_hud: Label = $UI/SimulationHUD
@onready var preparation_panel: ColorRect = $UI/PreparationPanel
@onready var level_label: Label = $UI/PreparationPanel/LevelLabel
@onready var preparation_help: Label = $UI/PreparationPanel/Help
@onready var results_panel: ColorRect = $UI/ResultsPanel
@onready var results_title: Label = $UI/ResultsPanel/Title
@onready var results_metrics: Label = $UI/ResultsPanel/Metrics
@onready var start_button: Button = $UI/PreparationPanel/StartButton
@onready var restart_button: Button = $UI/RestartButton
@onready var replay_button: Button = $UI/ResultsPanel/ReplayButton
@onready var min_boxes: Array[SpinBox] = [$UI/PreparationPanel/E1Min, $UI/PreparationPanel/E2Min, $UI/PreparationPanel/E3Min]
@onready var max_boxes: Array[SpinBox] = [$UI/PreparationPanel/E1Max, $UI/PreparationPanel/E2Max, $UI/PreparationPanel/E3Max]
@onready var staging_boxes: Array[SpinBox] = [$UI/PreparationPanel/E1Stage, $UI/PreparationPanel/E2Stage, $UI/PreparationPanel/E3Stage]
@onready var behavior_boxes: Array[OptionButton] = [$UI/PreparationPanel/E1Mode, $UI/PreparationPanel/E2Mode, $UI/PreparationPanel/E3Mode]
@onready var apply_buttons: Array[Button] = [$UI/PreparationPanel/E1Apply, $UI/PreparationPanel/E2Apply, $UI/PreparationPanel/E3Apply]
@onready var strategy_statuses: Array[Label] = [$UI/PreparationPanel/E1Status, $UI/PreparationPanel/E2Status, $UI/PreparationPanel/E3Status]


func _ready() -> void:
	start_button.pressed.connect(_start_wave)
	restart_button.pressed.connect(_restart_level)
	replay_button.pressed.connect(_on_results_button_pressed)
	for index in range(ELEVATOR_COUNT):
		_apply_behavior_options(behavior_boxes[index])
		apply_buttons[index].pressed.connect(_request_live_strategy.bind(index))
	_create_elevators()
	_apply_ui_contrast($UI)
	_update_ui()
	queue_redraw()


func _process(delta: float) -> void:
	if phase != Phase.RUNNING:
		return

	wave_time += delta
	_spawn_due_passengers()
	_update_wait_times(delta)
	var waiting := _waiting_passengers()
	for elevator in elevators:
		var arrived := elevator.update_simulation(delta, waiting)
		for passenger in arrived:
			_record_arrival(passenger, elevator)
		waiting = _waiting_passengers()

	_reposition_waiting_passengers()
	_update_ui()
	if wave_time >= WAVE_SECONDS:
		_finish_wave()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(600.0, 960.0)), Color("111827"))
	draw_rect(Rect2(72.0, 116.0, 330.0, 562.0), Color("25344b"), true)
	for index in range(FLOOR_COUNT):
		var y := floor_y_positions[index] + 26.0
		draw_line(Vector2(62.0, y), Vector2(566.0, y), Color("64748b"), 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(18.0, floor_y_positions[index] + 4.0), "F%02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("e2e8f0"))

	for shaft in range(ELEVATOR_COUNT):
		var x := 142.0 + shaft * 88.0
		draw_rect(Rect2(x - 31.0, 116.0, 62.0, 562.0), Color("0b1220"), true)
		draw_string(ThemeDB.fallback_font, Vector2(x - 18.0, 110.0), "E%d" % (shaft + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("bae6fd"))

	draw_string(ThemeDB.fallback_font, Vector2(420.0, 126.0), "WAITING", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("fde68a"))


func _create_elevators() -> void:
	for identifier in range(1, ELEVATOR_COUNT + 1):
		var elevator := elevator_script.new() as RushElevator
		elevators_root.add_child(elevator)
		elevator.position.x = 142.0 + (identifier - 1) * 88.0
		elevator.configure(identifier, floor_y_positions)
		elevators.append(elevator)


func _start_wave() -> void:
	_apply_strategies()
	_reset_wave_state()
	phase = Phase.RUNNING
	preparation_panel.visible = true
	results_panel.visible = false
	_update_ui()


func _restart_level() -> void:
	if phase != Phase.RUNNING:
		return
	_apply_strategies()
	_reset_wave_state()
	_update_ui()


func _apply_strategies() -> void:
	for index in range(ELEVATOR_COUNT):
		var minimum := roundi(min_boxes[index].value)
		var maximum := roundi(max_boxes[index].value)
		var staging := roundi(staging_boxes[index].value)
		var behavior := behavior_boxes[index].selected
		elevators[index].set_strategy(minimum, maximum, staging, behavior)
		elevators[index].current_floor = elevators[index].staging_floor
		elevators[index].target_floor = elevators[index].staging_floor
		elevators[index].position.y = floor_y_positions[elevators[index].staging_floor - 1]
		elevators[index].queue_redraw()


func _reset_wave_state() -> void:
	for passenger in passengers:
		if is_instance_valid(passenger):
			passenger.queue_free()
	passengers.clear()

	for elevator in elevators:
		elevator.passengers.clear()
		elevator.state = RushElevator.State.IDLE
		elevator.direction = 0
		elevator.last_travel_direction = 1
		elevator.busy_time = 0.0
		elevator.transported_count = 0
		elevator.stop_count = 0
		elevator.clear_live_strategy_state()
		elevator.queue_redraw()

	wave_time = 0.0
	spawn_index = 0
	delivered_count = 0
	total_wait_time = 0.0
	longest_wait_time = 0.0
	passenger_schedule = _build_fixed_schedule()


func _build_fixed_schedule() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	var level := _current_level()
	rng.seed = int(level["seed"])
	var schedule: Array[Dictionary] = []
	for index in range(int(level["passengers"])):
		var demand := _create_level_demand(index, str(level["pattern"]), rng)
		schedule.append({
			"time": rng.randf_range(1.0, WAVE_SECONDS - 6.0),
			"origin": demand["origin"],
			"destination": demand["destination"],
		})
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return schedule


func _create_level_demand(index: int, pattern: String, rng: RandomNumberGenerator) -> Dictionary:
	var origin := 1
	var destination := 4
	match pattern:
		"morning":
			origin = 1 if index < 40 else rng.randi_range(2, 5)
			destination = rng.randi_range(4, 10)
		"midday":
			if index < 22:
				origin = 1
				destination = rng.randi_range(4, 10)
			elif index < 42:
				origin = rng.randi_range(4, 10)
				destination = 1
			else:
				origin = rng.randi_range(2, 9)
				destination = rng.randi_range(1, 10)
		"evening":
			if index < 48:
				origin = rng.randi_range(4, 10)
				destination = 1
			else:
				origin = rng.randi_range(5, 10)
				destination = rng.randi_range(1, 4)

	while destination == origin:
		destination = rng.randi_range(1, 10)
	return {"origin": origin, "destination": destination}


func _spawn_due_passengers() -> void:
	while spawn_index < passenger_schedule.size() and passenger_schedule[spawn_index].time <= wave_time:
		var demand := passenger_schedule[spawn_index]
		var passenger := passenger_script.new() as RushPassenger
		passengers_root.add_child(passenger)
		passenger.configure(int(demand["origin"]), int(demand["destination"]), float(demand["time"]))
		passengers.append(passenger)
		spawn_index += 1


func _update_wait_times(delta: float) -> void:
	for passenger in passengers:
		if passenger.state == RushPassenger.State.WAITING:
			passenger.wait_time += delta


func _waiting_passengers() -> Array[RushPassenger]:
	var waiting: Array[RushPassenger] = []
	for passenger in passengers:
		if passenger.state == RushPassenger.State.WAITING:
			waiting.append(passenger)
	return waiting


func _record_arrival(passenger: RushPassenger, elevator: RushElevator) -> void:
	delivered_count += 1
	total_wait_time += passenger.wait_time
	longest_wait_time = maxf(longest_wait_time, passenger.wait_time)
	elevator.transported_count += 1
	passenger.visible = false


func _reposition_waiting_passengers() -> void:
	for floor in range(1, FLOOR_COUNT + 1):
		var position_index := 0
		for passenger in _waiting_passengers():
			if passenger.origin_floor == floor:
				passenger.position = Vector2(428.0 + (position_index % 4) * 40.0, floor_y_positions[floor - 1])
				position_index += 1


func _finish_wave() -> void:
	phase = Phase.RESULTS
	var average_wait := total_wait_time / delivered_count if delivered_count > 0 else 0.0
	last_grade = float(_calculate_grade(average_wait)["total"])
	results_metrics.text = _results_text()
	_update_results_actions()
	results_panel.visible = true
	preparation_panel.visible = false
	_update_ui()


func _results_text() -> String:
	var average_wait := total_wait_time / delivered_count if delivered_count > 0 else 0.0
	var grade := _calculate_grade(average_wait)
	var text := "RUN GRADE: %.1f / 10\n%s\n%s\n\nGLOBAL\nTotal passengers: %d\nDelivered: %d / %d\nAverage wait: %.1f s\nLongest wait: %.1f s\n\nPER ELEVATOR" % [
		grade["total"],
		"Delivery %.1f/4  •  Average wait %.1f/2  •  Longest wait %.1f/1.25" % [grade["delivery"], grade["average_wait"], grade["longest_wait"]],
		"Utilization %.1f/1  •  Balance %.1f/.75  •  Stops %.1f/1" % [grade["utilization"], grade["balance"], grade["stops"]],
		_current_level()["passengers"],
		delivered_count,
		_current_level()["passengers"],
		average_wait,
		longest_wait_time,
	]
	for elevator in elevators:
		var utilization := elevator.busy_time / WAVE_SECONDS * 100.0
		text += "\nE%d  Utilization: %.0f%%  Transported: %d  Stops: %d" % [
			elevator.elevator_id,
			utilization,
			elevator.transported_count,
			elevator.stop_count,
		]
		text += "\n    Final: %s  •  Live changes: %d" % [elevator.strategy_summary(), elevator.strategy_change_count]
	return text


func _calculate_grade(average_wait: float) -> Dictionary:
	var delivery_score := float(delivered_count) / float(_current_level()["passengers"]) * 4.0
	var average_wait_score := maxf(0.0, 1.0 - average_wait / 30.0) * 2.0
	var longest_wait_score := maxf(0.0, 1.0 - longest_wait_time / 60.0) * 1.25

	var total_utilization := 0.0
	var total_transported := 0.0
	var total_stops := 0.0
	for elevator in elevators:
		total_utilization += elevator.busy_time / WAVE_SECONDS
		total_transported += elevator.transported_count
		total_stops += elevator.stop_count

	var average_utilization := total_utilization / ELEVATOR_COUNT
	var utilization_score := minf(average_utilization / 0.7, 1.0)
	var average_transported := total_transported / ELEVATOR_COUNT
	var passenger_spread := 0.0
	for elevator in elevators:
		passenger_spread += absf(elevator.transported_count - average_transported)
	passenger_spread /= ELEVATOR_COUNT
	var balance_score := (1.0 - minf(passenger_spread / maxf(average_transported, 1.0), 1.0)) * 0.75
	var stops_per_delivery := total_stops / delivered_count if delivered_count > 0 else 4.0
	var stops_score := maxf(0.0, 1.0 - maxf(0.0, stops_per_delivery - 1.5) / 2.5)

	return {
		"total": delivery_score + average_wait_score + longest_wait_score + utilization_score + balance_score + stops_score,
		"delivery": delivery_score,
		"average_wait": average_wait_score,
		"longest_wait": longest_wait_score,
		"utilization": utilization_score,
		"balance": balance_score,
		"stops": stops_score,
	}


func _on_results_button_pressed() -> void:
	if last_grade >= PASS_GRADE and current_level_index < LEVELS.size() - 1:
		current_level_index += 1
	_return_to_preparation()


func _return_to_preparation() -> void:
	phase = Phase.PREPARATION
	results_panel.visible = false
	preparation_panel.visible = true
	phase_label.text = "PREPARATION — configure strategy for Level %d." % (current_level_index + 1)
	simulation_hud.text = "Wave: ready — fixed seed %d" % _current_level()["seed"]


func _update_ui() -> void:
	if phase == Phase.PREPARATION:
		level_label.text = "LEVEL %d / %d — %s" % [current_level_index + 1, LEVELS.size(), _current_level()["name"]]
		preparation_help.text = "Forecast: %s" % _current_level()["forecast"]
		start_button.text = "START LEVEL %d — %d PASSENGERS" % [current_level_index + 1, _current_level()["passengers"]]
		phase_label.text = "PREPARATION — configure coverage, staging, and behavior."
		simulation_hud.text = "Wave: %d passengers over 60 seconds. Same demand every replay." % _current_level()["passengers"]
		restart_button.visible = false
	elif phase == Phase.RUNNING:
		phase_label.text = "AUTOMATIC SIMULATION — update strategy between elevator jobs."
		simulation_hud.text = "Level %d: %02d / %02d   Spawned: %d / %d   Delivered: %d" % [current_level_index + 1, roundi(wave_time), roundi(WAVE_SECONDS), spawn_index, _current_level()["passengers"], delivered_count]
		preparation_help.text = "Apply queues a change. It takes effect at idle; each elevator then cools down for 8 seconds."
		restart_button.visible = true
	else:
		phase_label.text = "RESULTS — compare throughput, waits, and elevator utilization."
		simulation_hud.text = "Wave complete. Score 8.0+ to unlock the next level."
		restart_button.visible = false
	_update_strategy_panel()


func _update_results_actions() -> void:
	if last_grade < PASS_GRADE:
		results_title.text = "LEVEL %d RESULTS" % (current_level_index + 1)
		replay_button.text = "ADJUST STRATEGY & REPLAY"
	elif current_level_index < LEVELS.size() - 1:
		results_title.text = "LEVEL %d CLEARED!" % (current_level_index + 1)
		replay_button.text = "UNLOCK LEVEL %d" % (current_level_index + 2)
	else:
		results_title.text = "CONGRATULATIONS!"
		results_metrics.text = "YOU BEAT ALL 3 LEVELS!\n\n" + results_metrics.text
		replay_button.text = "PLAY AGAIN"


func _current_level() -> Dictionary:
	return LEVELS[current_level_index]


func _request_live_strategy(index: int) -> void:
	if phase != Phase.RUNNING or elevators[index].strategy_cooldown_left > 0.0:
		return
	elevators[index].request_strategy(
		roundi(min_boxes[index].value),
		roundi(max_boxes[index].value),
		roundi(staging_boxes[index].value),
		behavior_boxes[index].selected
	)
	_update_strategy_panel()


func _update_strategy_panel() -> void:
	var is_preparation := phase == Phase.PREPARATION
	start_button.visible = is_preparation
	for index in range(ELEVATOR_COUNT):
		var elevator := elevators[index]
		var can_edit := is_preparation or (phase == Phase.RUNNING and elevator.strategy_cooldown_left <= 0.0)
		min_boxes[index].editable = can_edit
		max_boxes[index].editable = can_edit
		staging_boxes[index].editable = can_edit
		behavior_boxes[index].disabled = not can_edit
		apply_buttons[index].visible = phase == Phase.RUNNING
		apply_buttons[index].disabled = not can_edit
		if is_preparation:
			strategy_statuses[index].text = "E%d  SETUP" % elevator.elevator_id
		elif phase == Phase.RUNNING:
			var pending := elevator.pending_strategy_summary()
			var status_text := "NOW: " + elevator.strategy_summary()
			if not pending.is_empty():
				status_text += "  →  PENDING: " + pending
			strategy_statuses[index].text = "E%d  %s" % [elevator.elevator_id, status_text]
			apply_buttons[index].text = "COOLDOWN %.0fs" % ceilf(elevator.strategy_cooldown_left) if elevator.strategy_cooldown_left > 0.0 else "APPLY"
		else:
			strategy_statuses[index].text = "E%d  FINAL: %s" % [elevator.elevator_id, elevator.strategy_summary()]


func _apply_behavior_options(box: OptionButton) -> void:
	box.clear()
	box.add_item("NORMAL", RushElevator.Behavior.NORMAL)
	box.add_item("UP BIAS", RushElevator.Behavior.UP_BIAS)
	box.add_item("DOWN BIAS", RushElevator.Behavior.DOWN_BIAS)
	box.add_item("UP ONLY", RushElevator.Behavior.UP_ONLY)
	box.add_item("DOWN ONLY", RushElevator.Behavior.DOWN_ONLY)


func _apply_ui_contrast(node: Node) -> void:
	if node is Label or node is Button or node is SpinBox or node is OptionButton:
		var control := node as Control
		control.add_theme_color_override("font_color", Color("f8fafc"))
		control.add_theme_color_override("font_outline_color", Color("020617"))
		control.add_theme_constant_override("outline_size", 2)
	if node is SpinBox:
		var spin_box := node as SpinBox
		spin_box.get_line_edit().add_theme_color_override("font_color", Color("f8fafc"))
		spin_box.get_line_edit().add_theme_color_override("font_placeholder_color", Color("cbd5e1"))
	for child in node.get_children():
		_apply_ui_contrast(child)
