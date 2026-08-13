class_name Passenger
extends Node2D

var current_floor := 1
var destination_floor := 2
var patience_max := 18.0
var patience_left := 18.0
var wait_time := 0.0
var is_waiting := true

@onready var destination_label: Label = $DestinationLabel
@onready var patience_bar: ProgressBar = $PatienceBar


func configure(spawn_floor: int, target_floor: int, maximum_patience: float) -> void:
	current_floor = spawn_floor
	destination_floor = target_floor
	patience_max = maximum_patience
	patience_left = maximum_patience
	_update_visuals()


func tick_waiting(delta: float) -> void:
	if not is_waiting:
		return

	wait_time += delta
	patience_left = maxf(0.0, patience_left - delta)
	_update_visuals()


func is_expired() -> bool:
	return is_waiting and patience_left <= 0.0


func board() -> void:
	is_waiting = false
	visible = false


func remaining_patience_ratio() -> float:
	if patience_max <= 0.0:
		return 0.0
	return patience_left / patience_max


func _ready() -> void:
	destination_label.add_theme_color_override("font_color", Color("14213d"))
	destination_label.add_theme_color_override("font_outline_color", Color("fff7e6"))
	destination_label.add_theme_constant_override("outline_size", 1)
	_update_visuals()


func _update_visuals() -> void:
	if not is_instance_valid(destination_label):
		return

	destination_label.text = "→ %d" % destination_floor
	patience_bar.value = remaining_patience_ratio() * 100.0
