class_name ElevatorRushV3Main
extends Control

## Temporary run-flow shell. Simulation, stages, and upgrade data arrive in later tasks.
enum RunPhase {
	START,
	RUNNING,
	UPGRADE,
	RESULT,
}

var phase: RunPhase = RunPhase.START

@onready var phase_label: Label = %PhaseLabel
@onready var stage_hud: PanelContainer = %StageHUD
@onready var upgrade_choice_panel: PanelContainer = %UpgradeChoicePanel
@onready var run_result_panel: PanelContainer = %RunResultPanel
@onready var start_button: Button = %StartButton


func _ready() -> void:
	start_button.pressed.connect(_show_running_shell)
	_set_phase(RunPhase.START)


func _show_running_shell() -> void:
	_set_phase(RunPhase.RUNNING)


func _set_phase(next_phase: RunPhase) -> void:
	phase = next_phase
	stage_hud.visible = phase == RunPhase.RUNNING
	upgrade_choice_panel.visible = phase == RunPhase.UPGRADE
	run_result_panel.visible = phase == RunPhase.RESULT
	start_button.visible = phase == RunPhase.START

	match phase:
		RunPhase.START:
			phase_label.text = "READY — build a system, then start the first traffic stage."
		RunPhase.RUNNING:
			phase_label.text = "RUNNING — autonomous simulation will appear here."
		RunPhase.UPGRADE:
			phase_label.text = "SYSTEM UPGRADE — choose one improvement."
		RunPhase.RESULT:
			phase_label.text = "RUN OVER — review the system result."
