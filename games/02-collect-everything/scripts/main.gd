extends Node2D

const TARGET_COLLECTIBLES := 10
const SPAWN_MARGIN := 36.0

@export var collectible_scene: PackedScene

var collected_count := 0
var game_over := false
var current_collectible: Area2D

@onready var player: CharacterBody2D = $Player
@onready var game_timer: Timer = $GameTimer
@onready var count_label: Label = $CanvasLayer/CountLabel
@onready var time_label: Label = $CanvasLayer/TimeLabel
@onready var status_label: Label = $CanvasLayer/StatusLabel


func _ready() -> void:
	randomize()
	game_timer.timeout.connect(_lose_game)
	_spawn_collectible()
	_update_labels()


func _process(_delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return

	_update_labels()


func _spawn_collectible() -> void:
	if game_over or collectible_scene == null:
		return

	current_collectible = collectible_scene.instantiate() as Area2D
	current_collectible.position = _random_collectible_position()
	current_collectible.collected.connect(_on_collectible_collected)
	add_child(current_collectible)


func _random_collectible_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var spawn_x := randf_range(SPAWN_MARGIN, viewport_size.x - SPAWN_MARGIN)
	var spawn_y := randf_range(SPAWN_MARGIN + 70.0, viewport_size.y - SPAWN_MARGIN)
	var candidate := Vector2(spawn_x, spawn_y)

	if candidate.distance_to(player.position) < 80.0:
		candidate.x = viewport_size.x - candidate.x

	return candidate


func _on_collectible_collected() -> void:
	if game_over:
		return

	collected_count += 1
	_update_labels()

	if collected_count >= TARGET_COLLECTIBLES:
		_win_game()
	else:
		_spawn_collectible()


func _win_game() -> void:
	_end_game("You collected everything! Press R to restart.")


func _lose_game() -> void:
	_end_game("Time is up. Press R to restart.")


func _end_game(message: String) -> void:
	if game_over:
		return

	game_over = true
	game_timer.stop()
	status_label.text = message

	if current_collectible != null and is_instance_valid(current_collectible):
		current_collectible.queue_free()


func _update_labels() -> void:
	count_label.text = "Collected: %d/%d" % [collected_count, TARGET_COLLECTIBLES]

	var remaining_time := game_timer.time_left
	if game_over:
		remaining_time = 0.0

	time_label.text = "Time: %02d" % ceili(remaining_time)
