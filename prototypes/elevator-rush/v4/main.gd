extends Control

const RunScript = preload("res://run.gd")
const StrategyScript = preload("res://strategy.gd")
const UpgradeScript = preload("res://upgrades.gd")
const BuildingViewScript = preload("res://building_view.gd")
const PHASE_PREPARATION := 0
const PHASE_RUNNING := 1
const PHASE_REPORT := 2
const PHASE_UPGRADE := 3
const PHASE_FAILED := 4
var run = RunScript.new(20260929)
var title_label: Label
var phase_label: Label
var forecast_label: Label
var status_label: Label
var building_label: Label
var building_view
var action_box: VBoxContainer
var offer_box: VBoxContainer
var start_button: Button
var report_button: Button
var new_run_button: Button
var retry_button: Button
var offer_buttons: Array[Button] = []
var strategy_panel: VBoxContainer
var pending_upgrade_id := ""
var confirm_upgrade_button: Button
var strategy_rows: Array[Dictionary] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()

func _process(delta: float) -> void:
	if run.phase == PHASE_RUNNING:
		run.advance(delta)
		_refresh()

func _label(text: String, size: int = 18) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func _button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, 44)
	result.pressed.connect(callback)
	return result

func _upgrade_card(text: String, callback: Callable) -> Button:
	var result := _button(text, callback)
	result.custom_minimum_size = Vector2(0, 76)
	result.add_theme_font_size_override("font_size", 17)
	result.add_theme_color_override("font_color", Color("f5fbff"))
	result.add_theme_stylebox_override("normal", _card_style(Color("173553"), Color("65b8e8")))
	result.add_theme_stylebox_override("hover", _card_style(Color("28577e"), Color("ffe47a")))
	result.add_theme_stylebox_override("pressed", _card_style(Color("406f96"), Color("fff1a8")))
	return result

func _card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	scroll.add_child(column)
	title_label = _label("ELEVATOR RUSH · V4", 26)
	column.add_child(title_label)
	phase_label = _label("", 20)
	column.add_child(phase_label)
	forecast_label = _label("", 17)
	column.add_child(forecast_label)
	building_view = BuildingViewScript.new()
	building_view.custom_minimum_size = Vector2(0, 250)
	building_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	building_view.set_run(run)
	column.add_child(building_view)
	building_label = _label("", 16)
	building_label.custom_minimum_size = Vector2(0, 112)
	column.add_child(building_label)
	status_label = _label("", 16)
	column.add_child(status_label)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 8)
	column.add_child(action_box)
	start_button = _button("START RUSH", _start_wave)
	action_box.add_child(start_button)
	report_button = _button("VIEW REPORT / UPGRADES", _open_upgrade)
	action_box.add_child(report_button)
	new_run_button = _button("NEW RUN", _new_run)
	action_box.add_child(new_run_button)
	retry_button = _button("RETRY SAME RUN", _retry)
	action_box.add_child(retry_button)
	_build_strategy_editor(action_box)
	offer_box = VBoxContainer.new()
	offer_box.add_theme_constant_override("separation", 8)
	column.add_child(offer_box)
	confirm_upgrade_button = _button("CONFIRM SELECTED UPGRADE", _confirm_upgrade)
	confirm_upgrade_button.add_theme_font_size_override("font_size", 18)
	confirm_upgrade_button.visible = false
	offer_box.add_child(confirm_upgrade_button)

func _build_strategy_editor(parent: VBoxContainer) -> void:
	strategy_panel = VBoxContainer.new()
	strategy_panel.add_theme_constant_override("separation", 6)
	parent.add_child(strategy_panel)
	strategy_panel.add_child(_label("ELEVATOR STRATEGY · RULES ONLY", 18))
	strategy_panel.add_child(_label("Edit staging, coverage, and soft direction priority. No direct movement commands.", 14))
	for car_id in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var caption := _label("E%d" % (car_id + 1), 17)
		caption.custom_minimum_size.x = 34
		row.add_child(caption)
		var staging := SpinBox.new()
		staging.min_value = 1; staging.max_value = 5; staging.step = 1; staging.custom_minimum_size = Vector2(72, 44)
		row.add_child(staging)
		var max_floor := SpinBox.new()
		max_floor.min_value = 1; max_floor.max_value = 5; max_floor.step = 1; max_floor.custom_minimum_size = Vector2(72, 44)
		row.add_child(max_floor)
		var preference := OptionButton.new()
		preference.add_item("Normal", 0); preference.add_item("Favor Up", 1); preference.add_item("Favor Down", -1)
		preference.custom_minimum_size = Vector2(120, 44)
		row.add_child(preference)
		var apply := _button("APPLY", func(): _apply_strategy(car_id + 1, staging, max_floor, preference))
		row.add_child(apply)
		strategy_panel.add_child(row)
		strategy_rows.append({"staging": staging, "max": max_floor, "preference": preference})

func _apply_strategy(car_id: int, staging: SpinBox, max_floor: SpinBox, preference: OptionButton) -> void:
	var draft = StrategyScript.new()
	draft.staging = int(staging.value)
	draft.max_floor = int(max_floor.value)
	draft.preference = int(preference.get_selected_id())
	var prep: bool = run.phase == PHASE_PREPARATION
	status_label.text = "E%d strategy %s" % [car_id, "updated" if run.simulation.set_strategy(car_id, draft, prep) else "pending/cooldown"]
	_refresh()

func _start_wave() -> void:
	run.start_wave()
	_refresh()

func _open_upgrade() -> void:
	if run.phase == PHASE_REPORT:
		run.continue_report()
		_refresh()

func _choose_upgrade(id: String) -> void:
	if run.phase != PHASE_UPGRADE:
		return
	pending_upgrade_id = id
	_refresh()

func _confirm_upgrade() -> void:
	if pending_upgrade_id.is_empty() or run.phase != PHASE_UPGRADE:
		return
	var target := 0 if pending_upgrade_id == "patience" or pending_upgrade_id == "aging" else 1
	if UpgradeScript.apply(pending_upgrade_id, target, run.simulation):
		run.confirm_upgrade(pending_upgrade_id, target)
		pending_upgrade_id = ""
		_refresh()

func _new_run() -> void:
	run.new_run(Time.get_ticks_msec())
	_refresh()

func _retry() -> void:
	run.retry_same_run()
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(phase_label):
		return
	phase_label.text = "Wave %d · %s · Misses %d / 5" % [run.wave_number, ["PREPARATION", "RUNNING", "REPORT", "UPGRADE", "FAILED"][run.phase], run.misses]
	forecast_label.text = "Forecast: %s · %d passengers · %d floors" % [run.wave_definition.pattern, run.wave_definition.passengers, run.wave_definition.floors]
	if run.phase == PHASE_RUNNING:
		forecast_label.text += "\nAUTONOMOUS SIMULATION · %.1fs" % run.elapsed
	var lines: Array[String] = ["BUILDING STATUS"]
	for car in run.simulation.cars:
		var next_stop: int = car.target if car.target > 0 else car.active_strategy.staging
		lines.append("E%d  F%.1f  %s  riders %d/%d  next F%d  stops %d" % [car.id, car.floor_position, "UP" if car.direction > 0 else "DOWN" if car.direction < 0 else "IDLE", car.riders.size(), car.capacity, next_stop, car.stops])
	building_label.text = "\n".join(lines)
	status_label.text = _status_text()
	start_button.visible = run.phase == PHASE_PREPARATION
	report_button.visible = run.phase == PHASE_REPORT
	new_run_button.visible = run.phase == PHASE_FAILED
	retry_button.visible = run.phase == PHASE_FAILED
	strategy_panel.visible = run.phase != PHASE_UPGRADE
	for button in offer_buttons:
		button.queue_free()
	offer_buttons.clear()
	for child in offer_box.get_children():
		if child != confirm_upgrade_button:
			child.queue_free()
	if run.phase == PHASE_UPGRADE:
		offer_box.add_child(_label("CHOOSE ONE UPGRADE", 19))
		for id in UpgradeScript.offer(run.root_seed, run.wave_number, run.simulation.cars, run.simulation.patience, run.simulation.dispatcher.aging_protection):
			var card := _upgrade_card(("✓ " if id == pending_upgrade_id else "") + UpgradeScript.descriptions()[id], func(): _choose_upgrade(id))
			offer_box.add_child(card)
			offer_buttons.append(card)
		confirm_upgrade_button.visible = not pending_upgrade_id.is_empty()
		if not pending_upgrade_id.is_empty():
			offer_box.add_child(_label("Selected: %s · press confirm to apply" % UpgradeScript.descriptions()[pending_upgrade_id], 16))
	else:
		confirm_upgrade_button.visible = false

func _status_text() -> String:
	if run.phase == PHASE_REPORT:
		var report: Dictionary = run.last_report
		return "REPORT · Delivered %d/%d · Avg wait %.1fs · Longest %.1fs" % [report.delivered, report.total, report.average_wait, report.longest_wait]
	if run.phase == PHASE_FAILED:
		return "RUN FAILED: five passengers waited too long. Retry to test a new strategy."
	return "Configure ranges, staging, and soft direction preferences. Elevators choose every trip autonomously."
