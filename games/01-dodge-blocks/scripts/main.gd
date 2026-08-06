extends Node2D

const GAME_DURATION := 30.0
const BLOCK_START_Y := -40.0
const BLOCK_MARGIN := 24.0

@export var block_scene: PackedScene

var game_over := false

@onready var player: CharacterBody2D = $Player
@onready var block_spawn_timer: Timer = $BlockSpawnTimer
@onready var survival_timer: Timer = $SurvivalTimer
@onready var time_label: Label = $CanvasLayer/TimeLabel
@onready var status_label: Label = $CanvasLayer/StatusLabel


func _ready() -> void:
	randomize()
	block_spawn_timer.timeout.connect(_spawn_block)
	survival_timer.timeout.connect(_win_game)
	_update_time_label()


func _process(_delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return

	_update_time_label()


func _spawn_block() -> void:
	if game_over or block_scene == null:
		return

	var block := block_scene.instantiate() as Area2D
	var viewport_width := get_viewport_rect().size.x
	var spawn_x := randf_range(BLOCK_MARGIN, viewport_width - BLOCK_MARGIN)

	block.position = Vector2(spawn_x, BLOCK_START_Y)
	block.body_entered.connect(_on_block_body_entered)
	add_child(block)


func _on_block_body_entered(body: Node) -> void:
	if body == player:
		_lose_game()


func _win_game() -> void:
	_end_game("You survived! Press R to restart.")


func _lose_game() -> void:
	_end_game("You were hit. Press R to restart.")


func _end_game(message: String) -> void:
	if game_over:
		return

	game_over = true
	block_spawn_timer.stop()
	survival_timer.stop()
	status_label.text = message

	for block in get_tree().get_nodes_in_group("blocks"):
		block.queue_free()


func _update_time_label() -> void:
	var remaining_time := survival_timer.time_left

	if game_over:
		remaining_time = 0.0

	time_label.text = "Time: %02d" % ceili(remaining_time)
