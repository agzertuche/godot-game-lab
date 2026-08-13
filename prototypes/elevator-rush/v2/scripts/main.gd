extends Node2D

const FLOOR_COUNT := 10
const ELEVATOR_COUNT := 3
const HallRequestManager := preload("res://scripts/simulation/hall_request_manager.gd")
const ElevatorDispatcher := preload("res://scripts/simulation/elevator_dispatcher.gd")
const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")
const WAVE_SECONDS := 60.0
const PASS_GRADE := 8.0
const ELEVATOR_ACCENTS := [Color("38bdf8"), Color("a78bfa"), Color("2dd4bf")]
const LEVELS := [
	{"name": "MORNING RUSH", "forecast": "Lobby-heavy upward traffic: Floor 1 → Floors 4–10.", "passengers": 50, "seed": 20260811, "pattern": "morning"},
	{"name": "MIDDAY EXCHANGE", "forecast": "Mixed traffic: lobby arrivals and office-to-lobby returns.", "passengers": 54, "seed": 20260812, "pattern": "midday"},
	{"name": "EVENING EXIT", "forecast": "Upper-floor-heavy downward traffic: Floors 4–10 → Floor 1.", "passengers": 58, "seed": 20260813, "pattern": "evening"},
	{"name": "ADAPTIVE CHAOS", "forecast": "Unpredictable mixed traffic. Watch the wave and adjust your strategy.", "passengers": 60, "pattern": "adaptive"},
]

enum Phase { PREPARATION, RUNNING, RESULTS }

@export var elevator_script: Script
@export var passenger_script: Script

# Keep the building above the persistent strategy cards in the 600x960 portrait viewport.
var floor_y_positions: Array[float] = [480.0, 440.0, 400.0, 360.0, 320.0, 280.0, 240.0, 200.0, 160.0, 120.0]
var phase := Phase.PREPARATION
var wave_time := 0.0
var spawn_index := 0
var passenger_schedule: Array[Dictionary] = []
var passengers: Array[RushPassenger] = []
var elevators: Array[RushElevator] = []
var hall_request_manager: HallRequestManager
var elevator_dispatcher: ElevatorDispatcher
var delivered_count := 0
var total_wait_time := 0.0
var longest_wait_time := 0.0
var current_level_index := 0
var last_grade := 0.0
var adaptive_chaos_schedule: Array[Dictionary] = []

@onready var elevators_root: Node2D = $Building/Elevators
@onready var passengers_root: Node2D = $Building/Passengers
@onready var phase_label: Label = $UI/PhaseLabel
@onready var simulation_hud: Label = $UI/SimulationHUD
@onready var dispatch_debug: Label = $UI/DispatchDebug
@onready var preparation_panel: ColorRect = $UI/PreparationPanel
@onready var level_label: Label = $UI/PreparationPanel/LevelLabel
@onready var preparation_help: Label = $UI/PreparationPanel/Help
@onready var results_panel: ColorRect = $UI/ResultsPanel
@onready var results_title: Label = $UI/ResultsPanel/Title
@onready var results_metrics: Label = $UI/ResultsPanel/Metrics
@onready var start_button: Button = $UI/PreparationPanel/StartButton
@onready var restart_button: Button = $UI/RestartButton
@onready var replay_button: Button = $UI/ResultsPanel/ReplayButton
@onready var new_challenge_button: Button = $UI/ResultsPanel/NewChallengeButton
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
	new_challenge_button.pressed.connect(_on_new_challenge_button_pressed)
	for index in range(ELEVATOR_COUNT):
		_apply_behavior_options(behavior_boxes[index])
		apply_buttons[index].pressed.connect(_request_live_strategy.bind(index))
		min_boxes[index].value_changed.connect(_update_strategy_panel)
		max_boxes[index].value_changed.connect(_update_strategy_panel)
		staging_boxes[index].value_changed.connect(_update_strategy_panel)
		behavior_boxes[index].item_selected.connect(_update_strategy_panel)
	_create_elevators()
	hall_request_manager = HallRequestManager.new(FLOOR_COUNT)
	elevator_dispatcher = ElevatorDispatcher.new()
	_apply_ui_contrast($UI)
	_apply_strategy_card_styles()
	_update_ui()
	queue_redraw()


func _process(delta: float) -> void:
	if phase != Phase.RUNNING:
		return

	wave_time += delta
	_spawn_due_passengers()
	_update_wait_times(delta)
	_dispatch_unassigned_requests()
	for elevator in elevators:
		elevator.tick_strategy_cooldown(delta)
		_apply_pending_strategy_if_ready(elevator)
		_tick_elevator(elevator, delta)
	_dispatch_unassigned_requests()

	_reposition_waiting_passengers()
	_update_ui()
	_update_dispatch_debug()
	if wave_time >= WAVE_SECONDS and _wave_demand_is_drained():
		_finish_wave()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(600.0, 960.0)), Color("111827"))
	draw_rect(Rect2(72.0, 100.0, 330.0, 410.0), Color("25344b"), true)
	for index in range(FLOOR_COUNT):
		var y := floor_y_positions[index] + 18.0
		draw_line(Vector2(62.0, y), Vector2(566.0, y), Color("64748b"), 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(18.0, floor_y_positions[index] + 4.0), "F%02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("e2e8f0"))

	for shaft in range(ELEVATOR_COUNT):
		var x := 142.0 + shaft * 88.0
		draw_rect(Rect2(x - 31.0, 100.0, 62.0, 410.0), Color("0b1220"), true)
		draw_string(ThemeDB.fallback_font, Vector2(x - 18.0, 94.0), "E%d" % (shaft + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("bae6fd"))

	draw_string(ThemeDB.fallback_font, Vector2(420.0, 108.0), "WAITING", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("fde68a"))


func _create_elevators() -> void:
	for identifier in range(1, ELEVATOR_COUNT + 1):
		var elevator := elevator_script.new() as RushElevator
		elevators_root.add_child(elevator)
		elevator.position.x = 142.0 + (identifier - 1) * 88.0
		elevator.configure(identifier, floor_y_positions)
		elevators.append(elevator)


func _start_wave() -> void:
	_reset_wave_state()
	_apply_strategies()
	phase = Phase.RUNNING
	preparation_panel.visible = true
	results_panel.visible = false
	_update_ui()


func _restart_level() -> void:
	if phase != Phase.RUNNING:
		return
	_reset_wave_state()
	_apply_strategies()
	_update_ui()


func _apply_strategies() -> void:
	for index in range(ELEVATOR_COUNT):
		var minimum := roundi(min_boxes[index].value)
		var maximum := roundi(max_boxes[index].value)
		var staging := roundi(staging_boxes[index].value)
		var behavior := behavior_boxes[index].selected
		elevators[index].set_strategy(minimum, maximum, staging, behavior)
		var controller := elevators[index].controller
		controller.configure_strategy(minimum, maximum, staging, behavior)
		controller.reset(controller.staging_floor, controller.staging_floor)
		elevators[index].position.y = floor_y_positions[controller.staging_floor - 1]
		elevators[index].sync_presentation()


func _reset_wave_state() -> void:
	for passenger in passengers:
		if is_instance_valid(passenger):
			passenger.queue_free()
	passengers.clear()

	hall_request_manager = HallRequestManager.new(FLOOR_COUNT)
	elevator_dispatcher = ElevatorDispatcher.new()
	for elevator in elevators:
		elevator.controller.reset(elevator.staging_floor, elevator.staging_floor)
		elevator.busy_time = 0.0
		elevator.transported_count = 0
		elevator.stop_count = 0
		elevator.clear_live_strategy_state()
		elevator.sync_presentation()

	wave_time = 0.0
	spawn_index = 0
	delivered_count = 0
	total_wait_time = 0.0
	longest_wait_time = 0.0
	passenger_schedule = _build_schedule()


func _build_schedule() -> Array[Dictionary]:
	var level := _current_level()
	if str(level["pattern"]) == "adaptive":
		return _get_adaptive_chaos_schedule()

	var rng := RandomNumberGenerator.new()
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


func _get_adaptive_chaos_schedule() -> Array[Dictionary]:
	if adaptive_chaos_schedule.is_empty():
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()

		var rng := RandomNumberGenerator.new()
		rng.seed = seed_rng.randi()
		var schedule: Array[Dictionary] = []
		for index in range(int(_current_level()["passengers"])):
			var demand := _create_level_demand(index, "adaptive", rng)
			schedule.append({
				"time": rng.randf_range(1.0, WAVE_SECONDS - 6.0),
				"origin": demand["origin"],
				"destination": demand["destination"],
			})
		schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
		adaptive_chaos_schedule = schedule

	return adaptive_chaos_schedule.duplicate(true)


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
		"adaptive":
			# Level 4 always contains an even mix; schedule timing randomizes their order.
			match index % 3:
				0:
					origin = 1
					destination = rng.randi_range(4, 10)
				1:
					origin = rng.randi_range(4, 10)
					destination = 1
				_:
					origin = rng.randi_range(2, 10)
					destination = rng.randi_range(1, 10)

	while destination == origin:
		destination = rng.randi_range(1, 10)
	return {"origin": origin, "destination": destination}


func _spawn_due_passengers() -> void:
	while spawn_index < passenger_schedule.size() and passenger_schedule[spawn_index].time <= wave_time:
		var demand := passenger_schedule[spawn_index]
		var passenger := passenger_script.new() as RushPassenger
		passengers_root.add_child(passenger)
		passenger.configure(int(demand["origin"]), int(demand["destination"]), wave_time)
		passengers.append(passenger)
		hall_request_manager.register_waiting_passenger(passenger, wave_time)
		spawn_index += 1


func _update_wait_times(delta: float) -> void:
	for passenger in passengers:
		if passenger.is_waiting():
			passenger.wait_time += delta


func _waiting_passengers() -> Array[RushPassenger]:
	var waiting: Array[RushPassenger] = []
	for passenger in passengers:
		if passenger.is_waiting():
			waiting.append(passenger)
	return waiting


func _record_arrival(passenger: RushPassenger, elevator: RushElevator) -> void:
	if passenger.state != SimulationTypes.PassengerState.COMPLETED:
		return
	delivered_count += 1
	total_wait_time += passenger.wait_time
	longest_wait_time = maxf(longest_wait_time, passenger.wait_time)
	elevator.transported_count += 1
	passenger.visible = false


func _wave_demand_is_drained() -> bool:
	if spawn_index < passenger_schedule.size() or not hall_request_manager.get_active_requests().is_empty():
		return false
	for elevator in elevators:
		if not elevator.controller.passengers.is_empty():
			return false
	return true


func _dispatch_unassigned_requests() -> void:
	var controllers: Array[ElevatorController] = []
	for elevator in elevators:
		controllers.append(elevator.controller)
	elevator_dispatcher.assign_unassigned_requests(controllers, hall_request_manager.get_unassigned_requests(), wave_time)


func _tick_elevator(elevator: RushElevator, delta: float) -> void:
	var controller := elevator.controller
	if controller.movement_state == SimulationTypes.MovementState.MOVING:
		controller.advance_travel(delta)
		elevator.busy_time += delta
		elevator.sync_presentation()
		if controller.movement_state == SimulationTypes.MovementState.STOPPED:
			_handle_logical_arrival(elevator)
		return

	if controller.movement_state == SimulationTypes.MovementState.STOPPED:
		elevator.busy_time += delta
		if controller.advance_service_dwell(delta):
			_process_controller_stop(elevator)
		elevator.sync_presentation()
		return

	var next_stop := controller.next_stop()
	if next_stop == 0:
		elevator.sync_presentation()
		return
	if next_stop == controller.current_floor:
		controller.arrive_at(next_stop)
		_handle_logical_arrival(elevator)
		return
	controller.begin_moving_to(next_stop)
	elevator.sync_presentation()


func _handle_logical_arrival(elevator: RushElevator) -> void:
	var controller := elevator.controller
	if not controller.arrived_service_stop:
		controller.complete_stop()
		elevator.sync_presentation()
		return
	elevator.stop_count += 1
	controller.begin_service_dwell()
	elevator.sync_presentation()


func _process_controller_stop(elevator: RushElevator) -> void:
	var result := elevator.controller.process_stop(hall_request_manager, wave_time)
	for passenger: RushPassenger in result["boarded"]:
		passenger.visible = false
	for passenger: RushPassenger in result["exited"]:
		_record_arrival(passenger, elevator)
	elevator.sync_presentation()


func _apply_pending_strategy_if_ready(elevator: RushElevator) -> void:
	if elevator.pending_strategy.is_empty() or elevator.strategy_cooldown_left > 0.0:
		return
	if elevator.controller.movement_state != SimulationTypes.MovementState.IDLE:
		return
	var pending := elevator.pending_strategy
	elevator.set_strategy(int(pending["min"]), int(pending["max"]), int(pending["stage"]), int(pending["behavior"]))
	elevator.controller.configure_strategy(elevator.allowed_min, elevator.allowed_max, elevator.staging_floor, elevator.behavior_rule)
	for request: HallRequest in elevator.controller.assigned_hall_requests.duplicate():
		if not elevator.controller.can_accept_hall_request(request):
			elevator.controller.remove_hall_request(request)
			hall_request_manager.release_request_assignment(request)
	elevator.pending_strategy.clear()
	elevator.sync_presentation()


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
	if last_grade < PASS_GRADE:
		_return_to_preparation()
	elif current_level_index < LEVELS.size() - 1:
		current_level_index += 1
		_return_to_preparation()
	else:
		_return_to_preparation()


func _on_new_challenge_button_pressed() -> void:
	if phase != Phase.RESULTS or last_grade < PASS_GRADE:
		return
	if current_level_index != LEVELS.size() - 1:
		return
	adaptive_chaos_schedule.clear()
	_get_adaptive_chaos_schedule()
	_return_to_preparation()


func _return_to_preparation() -> void:
	phase = Phase.PREPARATION
	results_panel.visible = false
	preparation_panel.visible = true
	phase_label.text = "PREPARATION — configure strategy for Level %d." % (current_level_index + 1)
	if str(_current_level()["pattern"]) == "adaptive":
		_get_adaptive_chaos_schedule()
		simulation_hud.text = "Wave: ready — generated challenge is ready to replay."
	else:
		simulation_hud.text = "Wave: ready — fixed seed %d" % _current_level()["seed"]
	_update_ui()


func _update_ui() -> void:
	if phase == Phase.PREPARATION:
		level_label.text = "LEVEL %d / %d — %s" % [current_level_index + 1, LEVELS.size(), _current_level()["name"]]
		preparation_help.text = "Forecast: %s" % _current_level()["forecast"]
		start_button.text = "START LEVEL %d — %d PASSENGERS" % [current_level_index + 1, _current_level()["passengers"]]
		phase_label.text = "PREPARATION — configure coverage, staging, and behavior."
		if str(_current_level()["pattern"]) == "adaptive":
			simulation_hud.text = "Wave: %d passengers over 60 seconds. Same generated challenge every replay." % _current_level()["passengers"]
		else:
			simulation_hud.text = "Wave: %d passengers over 60 seconds. Same demand every replay." % _current_level()["passengers"]
		restart_button.visible = false
	elif phase == Phase.RUNNING:
		phase_label.text = "AUTOMATIC SIMULATION — update strategy between elevator jobs."
		var wave_status := "DRAINING" if wave_time >= WAVE_SECONDS else "%02d / %02d" % [roundi(wave_time), roundi(WAVE_SECONDS)]
		simulation_hud.text = "Level %d: %s   Spawned: %d / %d   Delivered: %d" % [current_level_index + 1, wave_status, spawn_index, _current_level()["passengers"], delivered_count]
		preparation_help.text = "Apply queues a change. It takes effect at idle; each elevator then cools down for 8 seconds."
		restart_button.visible = true
	else:
		phase_label.text = "RESULTS — compare throughput, waits, and elevator utilization."
		simulation_hud.text = "Wave complete. Score 8.0+ to unlock the next level."
		restart_button.visible = false
	_update_strategy_panel()
	_update_dispatch_debug()


func _update_dispatch_debug() -> void:
	if dispatch_debug == null:
		return
	var lines: Array[String] = []
	for elevator in elevators:
		var controller := elevator.controller
		var direction := "↑" if controller.service_direction == SimulationTypes.Direction.UP else "↓" if controller.service_direction == SimulationTypes.Direction.DOWN else "•"
		var hall_floors: Array[String] = []
		for request: HallRequest in controller.assigned_hall_requests:
			hall_floors.append("%d%s" % [request.floor, "↑" if request.direction == SimulationTypes.Direction.UP else "↓"])
		var destinations: Array[String] = []
		for floor: int in controller.destination_requests:
			destinations.append(str(floor))
		lines.append("E%d F%d %s %d/%d  H[%s] D[%s] →%d" % [controller.elevator_id, controller.current_floor, direction, controller.passengers.size(), controller.capacity, ",".join(hall_floors), ",".join(destinations), controller.target_floor])
	var shown_waiters := 0
	for passenger in passengers:
		if not passenger.is_waiting() or shown_waiters >= 1:
			continue
		lines.append("P F%d→F%d %s %.0fs E%d" % [passenger.origin_floor, passenger.destination_floor, _passenger_state_name(passenger.state), passenger.wait_time, passenger.assigned_elevator_id])
		shown_waiters += 1
	dispatch_debug.text = "\n".join(lines)


func _passenger_state_name(passenger_state: int) -> String:
	match passenger_state:
		SimulationTypes.PassengerState.ASSIGNED:
			return "ASSIGNED"
		SimulationTypes.PassengerState.WAITING:
			return "WAITING"
	return "ACTIVE"


func _update_results_actions() -> void:
	new_challenge_button.visible = false
	if last_grade < PASS_GRADE:
		results_title.text = "LEVEL %d RESULTS" % (current_level_index + 1)
		replay_button.text = "ADJUST STRATEGY & REPLAY"
	elif current_level_index < LEVELS.size() - 1:
		results_title.text = "LEVEL %d CLEARED!" % (current_level_index + 1)
		replay_button.text = "UNLOCK LEVEL %d" % (current_level_index + 2)
	else:
		results_title.text = "CONGRATULATIONS!"
		results_metrics.text = "YOU BEAT ALL %d LEVELS!\n\n" % LEVELS.size() + results_metrics.text
		replay_button.text = "REPLAY SAME CHALLENGE"
		new_challenge_button.visible = true


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


func _update_strategy_panel(_changed_value: Variant = null) -> void:
	var is_preparation := phase == Phase.PREPARATION
	start_button.visible = is_preparation
	for index in range(ELEVATOR_COUNT):
		var elevator := elevators[index]
		var can_edit := is_preparation or (phase == Phase.RUNNING and elevator.strategy_cooldown_left <= 0.0)
		min_boxes[index].editable = can_edit
		max_boxes[index].editable = can_edit
		staging_boxes[index].editable = can_edit
		behavior_boxes[index].disabled = not can_edit
		apply_buttons[index].visible = true
		apply_buttons[index].disabled = is_preparation or not can_edit
		if is_preparation:
			strategy_statuses[index].text = "E%d READY  •  SERVES F%d–F%d  •  STAGES F%d  •  %s" % [
				elevator.elevator_id,
				roundi(min_boxes[index].value),
				roundi(max_boxes[index].value),
				roundi(staging_boxes[index].value),
				behavior_boxes[index].get_item_text(behavior_boxes[index].selected),
			]
			apply_buttons[index].text = "APPLIES ON START"
		elif phase == Phase.RUNNING:
			var pending := elevator.pending_strategy_summary()
			var status_text := "ACTIVE: " + elevator.strategy_summary()
			if not pending.is_empty():
				status_text += "  →  QUEUED: " + pending
			strategy_statuses[index].text = "E%d  %s" % [elevator.elevator_id, status_text]
			apply_buttons[index].text = "COOLDOWN %.0fs" % ceilf(elevator.strategy_cooldown_left) if elevator.strategy_cooldown_left > 0.0 else "APPLY TO E%d" % elevator.elevator_id
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
	if node is Label:
		var label := node as Label
		if not label.has_theme_color_override("font_color"):
			label.add_theme_color_override("font_color", Color("f8fafc"))
		if not label.has_theme_color_override("font_outline_color"):
			label.add_theme_color_override("font_outline_color", Color("020617"))
		if not label.has_theme_constant_override("outline_size"):
			label.add_theme_constant_override("outline_size", 2)
	elif node is Button:
		var button := node as Button
		button.add_theme_color_override("font_color", Color("f8fafc"))
		button.add_theme_color_override("font_outline_color", Color("020617"))
		button.add_theme_constant_override("outline_size", 2)
	if node is SpinBox:
		var spin_box := node as SpinBox
		spin_box.get_line_edit().add_theme_color_override("font_color", Color("0f172a"))
		spin_box.get_line_edit().add_theme_color_override("font_placeholder_color", Color("475569"))
		spin_box.get_line_edit().add_theme_constant_override("outline_size", 0)
	if node is OptionButton:
		var option_button := node as OptionButton
		option_button.add_theme_color_override("font_color", Color("0f172a"))
		option_button.add_theme_constant_override("outline_size", 0)
	for child in node.get_children():
		_apply_ui_contrast(child)


func _apply_strategy_card_styles() -> void:
	for index in range(ELEVATOR_COUNT):
		var accent: Color = ELEVATOR_ACCENTS[index]
		var input_normal := _flat_style(Color("e0f2fe"), Color("93c5fd"), 2)
		var input_focus := _flat_style(Color("f8fafc"), accent, 3)
		var line_edit := min_boxes[index].get_line_edit()
		line_edit.add_theme_stylebox_override("normal", input_normal)
		line_edit.add_theme_stylebox_override("focus", input_focus)
		line_edit.add_theme_font_size_override("font_size", 17)
		line_edit = max_boxes[index].get_line_edit()
		line_edit.add_theme_stylebox_override("normal", input_normal)
		line_edit.add_theme_stylebox_override("focus", input_focus)
		line_edit.add_theme_font_size_override("font_size", 17)
		line_edit = staging_boxes[index].get_line_edit()
		line_edit.add_theme_stylebox_override("normal", input_normal)
		line_edit.add_theme_stylebox_override("focus", input_focus)
		line_edit.add_theme_font_size_override("font_size", 17)

		behavior_boxes[index].add_theme_stylebox_override("normal", input_normal)
		behavior_boxes[index].add_theme_stylebox_override("hover", input_focus)
		behavior_boxes[index].add_theme_stylebox_override("focus", input_focus)
		behavior_boxes[index].add_theme_font_size_override("font_size", 14)

		var apply_button := apply_buttons[index]
		apply_button.add_theme_stylebox_override("normal", _flat_style(accent, accent.lightened(0.28), 2))
		apply_button.add_theme_stylebox_override("hover", _flat_style(accent.lightened(0.12), Color("ffffff"), 2))
		apply_button.add_theme_stylebox_override("pressed", _flat_style(accent.darkened(0.18), Color("ffffff"), 2))
		apply_button.add_theme_stylebox_override("disabled", _flat_style(Color("334155"), Color("475569"), 2))

	start_button.add_theme_stylebox_override("normal", _flat_style(Color("f59e0b"), Color("fef3c7"), 2))
	start_button.add_theme_stylebox_override("hover", _flat_style(Color("fbbf24"), Color("ffffff"), 2))
	start_button.add_theme_stylebox_override("pressed", _flat_style(Color("d97706"), Color("ffffff"), 2))


func _flat_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	return style
