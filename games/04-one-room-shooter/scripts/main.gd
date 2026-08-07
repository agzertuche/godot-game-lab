extends Node2D

const SPAWN_MARGIN := 32.0

@export var projectile_scene: PackedScene
@export var enemy_scene: PackedScene

var game_over := false

@onready var player: CharacterBody2D = $Player
@onready var enemy_root: Node2D = $EnemyRoot
@onready var projectile_root: Node2D = $ProjectileRoot
@onready var enemy_spawn_timer: Timer = $EnemySpawnTimer
@onready var survival_timer: Timer = $SurvivalTimer
@onready var health_label: Label = $CanvasLayer/HealthLabel
@onready var time_label: Label = $CanvasLayer/TimeLabel
@onready var status_label: Label = $CanvasLayer/StatusLabel


func _ready() -> void:
	randomize()
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_lose_game)
	player.projectile_requested.connect(_spawn_projectile)
	enemy_spawn_timer.timeout.connect(_spawn_enemy)
	survival_timer.timeout.connect(_win_game)
	_on_player_health_changed(player.current_health)
	_update_time_label()


func _process(_delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return

	_update_time_label()


func _spawn_projectile(spawn_position: Vector2, direction: Vector2) -> void:
	if game_over or projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	projectile.setup(spawn_position, direction)
	projectile_root.add_child(projectile)


func _spawn_enemy() -> void:
	if game_over or enemy_scene == null:
		return

	var enemy := enemy_scene.instantiate()
	enemy.setup(player)
	enemy.position = _random_edge_position()
	enemy_root.add_child(enemy)


func _random_edge_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var side := randi_range(0, 3)

	match side:
		0:
			return Vector2(randf_range(SPAWN_MARGIN, viewport_size.x - SPAWN_MARGIN), -SPAWN_MARGIN)
		1:
			return Vector2(viewport_size.x + SPAWN_MARGIN, randf_range(SPAWN_MARGIN, viewport_size.y - SPAWN_MARGIN))
		2:
			return Vector2(randf_range(SPAWN_MARGIN, viewport_size.x - SPAWN_MARGIN), viewport_size.y + SPAWN_MARGIN)
		_:
			return Vector2(-SPAWN_MARGIN, randf_range(SPAWN_MARGIN, viewport_size.y - SPAWN_MARGIN))


func _on_player_health_changed(current_health: int) -> void:
	health_label.text = "Health: %d" % current_health


func _win_game() -> void:
	_end_game("You survived! Press R to restart.")


func _lose_game() -> void:
	_end_game("You were defeated. Press R to restart.")


func _end_game(message: String) -> void:
	if game_over:
		return

	game_over = true
	enemy_spawn_timer.stop()
	survival_timer.stop()
	status_label.text = message

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()


func _update_time_label() -> void:
	var remaining_time := survival_timer.time_left
	if game_over:
		remaining_time = 0.0

	time_label.text = "Time: %02d" % ceili(remaining_time)
