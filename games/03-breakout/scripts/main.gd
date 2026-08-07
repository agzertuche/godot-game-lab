extends Node2D

const BLOCK_COLUMNS := 7
const BLOCK_ROWS := 4
const BLOCK_SPACING := Vector2(78, 30)
const BLOCK_START := Vector2(86, 82)

@export var block_scene: PackedScene

var remaining_blocks := 0
var game_over := false

@onready var ball: CharacterBody2D = $Ball
@onready var block_root: Node2D = $BlockRoot
@onready var blocks_label: Label = $CanvasLayer/BlocksLabel
@onready var status_label: Label = $CanvasLayer/StatusLabel


func _ready() -> void:
	ball.ball_lost.connect(_lose_game)
	ball.block_hit.connect(_on_ball_block_hit)
	_create_blocks()
	_update_blocks_label()


func _process(_delta: float) -> void:
	if game_over and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()


func _create_blocks() -> void:
	if block_scene == null:
		return

	for row in BLOCK_ROWS:
		for column in BLOCK_COLUMNS:
			var block := block_scene.instantiate() as StaticBody2D
			block.position = BLOCK_START + Vector2(column * BLOCK_SPACING.x, row * BLOCK_SPACING.y)
			block_root.add_child(block)
			remaining_blocks += 1


func _on_ball_block_hit(_block: StaticBody2D) -> void:
	if game_over:
		return

	remaining_blocks -= 1
	_update_blocks_label()

	if remaining_blocks <= 0:
		_win_game()


func _win_game() -> void:
	_end_game("All blocks cleared! Press R to restart.")


func _lose_game() -> void:
	_end_game("Ball lost. Press R to restart.")


func _end_game(message: String) -> void:
	if game_over:
		return

	game_over = true
	ball.stop()
	status_label.text = message


func _update_blocks_label() -> void:
	blocks_label.text = "Blocks: %d" % remaining_blocks
