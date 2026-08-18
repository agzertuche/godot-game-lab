class_name ElevatorRushV3Main
extends Control

## Presentation coordinator only. ElevatorRunManager owns traffic, dispatch,
## routing, passenger state, capacity, and stage outcomes.

const RunManager := preload("res://scripts/run/run_manager.gd")

enum RunPhase {
	START,
	RUNNING,
	UPGRADE,
	RESULT,
}

var phase: RunPhase = RunPhase.START
var run_manager: ElevatorRunManager
var result_reason := ""

@onready var phase_label: Label = %PhaseLabel
@onready var stage_hud: PanelContainer = %StageHUD
@onready var stage_header: Label = %StageHeader
@onready var stage_stats: Label = %StageStats
@onready var simulation_view: ElevatorRunSimulationView = %SimulationView
@onready var upgrade_choice_panel: PanelContainer = %UpgradeChoicePanel
@onready var upgrade_help: Label = %Help
@onready var run_result_panel: PanelContainer = %RunResultPanel
@onready var result_header: Label = %ResultHeader
@onready var result_summary: Label = %Summary
@onready var start_button: Button = %StartButton
@onready var choice_buttons: Array[Button] = [%ChoiceOne, %ChoiceTwo, %ChoiceThree]
@onready var restart_button: Button = %Restart


func _ready() -> void:
	start_button.pressed.connect(_start_new_run)
	restart_button.pressed.connect(_start_new_run)
	for button_index: int in choice_buttons.size():
		choice_buttons[button_index].pressed.connect(_choose_upgrade.bind(button_index))
	_set_phase(RunPhase.START)


func _process(delta: float) -> void:
	if run_manager == null:
		return
	if phase == RunPhase.RUNNING:
		run_manager.tick(delta)
	_update_stage_hud()


func _start_new_run() -> void:
	run_manager = RunManager.new()
	run_manager.stage_started.connect(_on_stage_started)
	run_manager.stage_completed.connect(_on_stage_completed)
	run_manager.stage_failed.connect(_on_stage_failed)
	run_manager.run_won.connect(_on_run_won)
	simulation_view.set_run_manager(run_manager)
	result_reason = ""
	run_manager.start_run()
	_set_phase(RunPhase.RUNNING)
	_update_stage_hud()


func _choose_upgrade(button_index: int) -> void:
	if run_manager == null:
		return
	var offer := run_manager.current_upgrade_offer()
	if button_index < 0 or button_index >= offer.size():
		return
	var selected: ElevatorUpgradeDefinition = offer[button_index]
	if not run_manager.choose_upgrade(selected.id):
		return
	if selected.id == "traffic_preview":
		_show_preview_then_start()
		return
	run_manager.start_current_stage()
	_set_phase(RunPhase.RUNNING)
	_update_stage_hud()


func _show_preview_then_start() -> void:
	if run_manager == null:
		return
	var manager := run_manager
	var preview := manager.current_stage_definition()
	_set_phase(RunPhase.RUNNING)
	phase_label.text = "TRAFFIC PREVIEW — STAGE %d: %d FLOORS • %d PASSENGERS • %s" % [
		preview.stage_number,
		preview.floor_count,
		preview.passenger_count,
		_pattern_label(preview.pattern),
	]
	_update_stage_hud()
	await get_tree().create_timer(1.8).timeout
	if manager != run_manager or manager.phase != ElevatorRunManager.RunPhase.STAGE_INTRO:
		return
	manager.start_current_stage()


func _on_stage_started(_definition: ElevatorStageDefinition) -> void:
	_set_phase(RunPhase.RUNNING)


func _on_stage_completed(_definition: ElevatorStageDefinition) -> void:
	# RunManager emits this transition before it exposes the next upgrade offer.
	# Deferring keeps phase ownership in RunManager while the UI reacts after it.
	call_deferred("_show_upgrade_choices")


func _on_stage_failed(_definition: ElevatorStageDefinition, reason: String) -> void:
	result_reason = reason
	_show_result(false)


func _on_run_won() -> void:
	result_reason = "All five escalating traffic stages were cleared."
	_show_result(true)


func _show_upgrade_choices() -> void:
	if run_manager == null or run_manager.phase != ElevatorRunManager.RunPhase.UPGRADE_CHOICE:
		return
	var offer := run_manager.current_upgrade_offer()
	for button_index: int in choice_buttons.size():
		var button := choice_buttons[button_index]
		if button_index >= offer.size():
			button.visible = false
			continue
		var upgrade: ElevatorUpgradeDefinition = offer[button_index]
		button.visible = true
		button.text = "%s\n%s" % [upgrade.title.to_upper(), upgrade.description]
	var preview := run_manager.next_stage_preview()
	if preview == null:
		upgrade_help.text = "Choose one improvement for the next stage."
	else:
		upgrade_help.text = "NEXT STAGE: %d FLOORS • %d PASSENGERS • %s" % [
			preview.floor_count,
			preview.passenger_count,
			_pattern_label(preview.pattern),
		]
	_set_phase(RunPhase.UPGRADE)
	_update_stage_hud()


func _show_result(won: bool) -> void:
	if run_manager == null:
		return
	result_header.text = "SYSTEM STABLE" if won else "SYSTEM OVERWHELMED"
	result_header.add_theme_color_override("font_color", Color("7cf0a8") if won else Color("ff9585"))
	result_summary.text = "%s\nSTAGE REACHED: %d / %d\nDELIVERED: %d / %d\nCURRENT BUILD: %s" % [
		result_reason,
		run_manager.current_stage_index + 1,
		run_manager.stage_definitions.size(),
		_completed_passenger_count(),
		run_manager.spawned_passenger_count(),
		_build_summary(),
	]
	_set_phase(RunPhase.RESULT)


func _update_stage_hud() -> void:
	if run_manager == null or run_manager.current_stage_definition() == null:
		return
	var definition := run_manager.current_stage_definition()
	var wait_limit := run_manager.upgrade_manager.failure_wait_limit(definition.max_oldest_wait_seconds)
	stage_header.text = "STAGE %d  •  %d FLOORS  •  %s" % [
		definition.stage_number,
		definition.floor_count,
		_pattern_label(definition.pattern),
	]
	stage_stats.text = "BACKLOG %d / %d     OLDEST WAIT %.1f / %.1fs\nPRESSURE: %s\nBUILD: %s" % [
		run_manager.active_waiting_count(),
		definition.max_active_waiting,
		run_manager.oldest_waiting_time(),
		wait_limit,
		_pressure_label(definition.max_active_waiting, wait_limit),
		_build_summary(),
	]


func _pressure_label(backlog_limit: int, wait_limit: float) -> String:
	if run_manager == null:
		return "--"
	var backlog_ratio := float(run_manager.active_waiting_count()) / float(maxi(1, backlog_limit))
	var wait_ratio := run_manager.oldest_waiting_time() / maxf(0.1, wait_limit)
	var ratio := maxf(backlog_ratio, wait_ratio)
	if ratio >= 0.85:
		return "CRITICAL"
	if ratio >= 0.55:
		return "RISING"
	return "STABLE"


func _build_summary() -> String:
	if run_manager == null or run_manager.upgrade_manager.build.is_empty():
		return "BASE SYSTEM"
	var titles: Array[String] = []
	for upgrade: ElevatorUpgradeDefinition in run_manager.upgrade_manager.build:
		titles.append(upgrade.title)
	return ", ".join(titles)


func _completed_passenger_count() -> int:
	if run_manager == null:
		return 0
	return run_manager.completed_passenger_count()


func _pattern_label(pattern: String) -> String:
	match pattern:
		"lobby_up":
			return "LOBBY RISE"
		"mixed_rush":
			return "MIXED RUSH"
		"upper_return":
			return "UPPER RETURN"
		"split_return_stress":
			return "SPLIT STRESS"
	return pattern.to_upper()


func _set_phase(next_phase: RunPhase) -> void:
	phase = next_phase
	stage_hud.visible = phase != RunPhase.START
	simulation_view.visible = phase == RunPhase.RUNNING or phase == RunPhase.UPGRADE
	upgrade_choice_panel.visible = phase == RunPhase.UPGRADE
	run_result_panel.visible = phase == RunPhase.RESULT
	start_button.visible = phase == RunPhase.START

	match phase:
		RunPhase.START:
			phase_label.text = "READY — start an autonomous elevator build."
		RunPhase.RUNNING:
			phase_label.text = "RUNNING — watch demand, backlog, and system pressure."
		RunPhase.UPGRADE:
			phase_label.text = "STAGE CLEAR — choose one system improvement."
		RunPhase.RESULT:
			phase_label.text = "RUN COMPLETE — start again with the same seeded traffic."
