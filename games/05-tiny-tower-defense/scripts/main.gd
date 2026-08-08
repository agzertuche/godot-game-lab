extends Node2D

const PATH_POINTS := [
	Vector2(24, 260),
	Vector2(160, 260),
	Vector2(160, 150),
	Vector2(330, 150),
	Vector2(330, 350),
	Vector2(560, 350),
	Vector2(620, 260),
]
const WAVES := [4, 6, 8]
const CLICK_RADIUS := 24.0

@export var enemy_scene: PackedScene
@export var tower_scene: PackedScene
@export var tower_cost: int = 5
@export var starting_currency: int = 10
@export var starting_base_health: int = 8

var base_health := starting_base_health
var currency := starting_currency
var current_wave_index := -1
var enemies_left_to_spawn := 0
var active_enemies: Array[Node] = []
var occupied_spots: Dictionary = {}
var game_over := false

@onready var enemy_path: Path2D = $EnemyPath
@onready var path_line: Line2D = $EnemyPath/PathLine
@onready var towers: Node2D = $Towers
@onready var build_spots: Node2D = $BuildSpots
@onready var spawn_timer: Timer = $SpawnTimer
@onready var health_label: Label = $CanvasLayer/HealthLabel
@onready var currency_label: Label = $CanvasLayer/CurrencyLabel
@onready var wave_label: Label = $CanvasLayer/WaveLabel
@onready var enemies_label: Label = $CanvasLayer/EnemiesLabel
@onready var status_label: Label = $CanvasLayer/StatusLabel


func _ready() -> void:
	_setup_path()
	spawn_timer.timeout.connect(_spawn_enemy)
	_start_next_wave()
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and game_over:
		get_tree().reload_current_scene()
		return

	if game_over:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_try_place_tower(mouse_event.position)


func _setup_path() -> void:
	var curve := Curve2D.new()
	for point in PATH_POINTS:
		curve.add_point(point)

	enemy_path.curve = curve
	path_line.points = PackedVector2Array(PATH_POINTS)


func _try_place_tower(click_position: Vector2) -> void:
	var spot := _find_build_spot(click_position)
	if spot == null:
		_set_status("Click a marked build spot.")
		return
	if occupied_spots.has(spot):
		_set_status("That spot already has a tower.")
		return
	if currency < tower_cost:
		_set_status("Not enough currency.")
		return
	if tower_scene == null:
		return

	var tower := tower_scene.instantiate() as Node2D
	if tower == null:
		return

	tower.global_position = spot.global_position
	tower.call("set_enemy_provider", Callable(self, "_get_active_enemies"))
	towers.add_child(tower)

	occupied_spots[spot] = tower
	currency -= tower_cost
	_set_status("Tower placed.")
	_update_ui()


func _find_build_spot(click_position: Vector2) -> Node2D:
	var nearest_spot: Node2D = null
	var nearest_distance := CLICK_RADIUS

	for child in build_spots.get_children():
		if not child is Node2D:
			continue

		var distance := click_position.distance_to(child.global_position)
		if distance <= nearest_distance:
			nearest_spot = child
			nearest_distance = distance

	return nearest_spot


func _start_next_wave() -> void:
	current_wave_index += 1
	if current_wave_index >= WAVES.size():
		_win_game()
		return

	enemies_left_to_spawn = WAVES[current_wave_index]
	_set_status("Wave %d started." % (current_wave_index + 1))
	spawn_timer.start()
	_update_ui()


func _spawn_enemy() -> void:
	if game_over or enemy_scene == null:
		spawn_timer.stop()
		return

	if enemies_left_to_spawn <= 0:
		spawn_timer.stop()
		return

	var enemy := enemy_scene.instantiate() as PathFollow2D
	if enemy == null:
		return

	enemy.connect("died", Callable(self, "_on_enemy_died"))
	enemy.connect("reached_base", Callable(self, "_on_enemy_reached_base"))
	enemy_path.add_child(enemy)
	active_enemies.append(enemy)

	enemies_left_to_spawn -= 1
	if enemies_left_to_spawn <= 0:
		spawn_timer.stop()

	_update_ui()


func _on_enemy_died(enemy: Node) -> void:
	if active_enemies.has(enemy):
		active_enemies.erase(enemy)

	currency += int(enemy.get("currency_reward"))

	_set_status("Enemy destroyed.")
	_check_wave_complete()
	_update_ui()


func _on_enemy_reached_base(enemy: Node) -> void:
	if active_enemies.has(enemy):
		active_enemies.erase(enemy)

	base_health -= int(enemy.get("base_damage"))

	if base_health <= 0:
		_lose_game()
	else:
		_set_status("The base took damage.")
		_check_wave_complete()
		_update_ui()


func _check_wave_complete() -> void:
	if game_over:
		return

	if enemies_left_to_spawn == 0 and active_enemies.is_empty():
		_start_next_wave()


func _get_active_enemies() -> Array[Node]:
	var valid_enemies: Array[Node] = []
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)

	active_enemies = valid_enemies
	return active_enemies


func _win_game() -> void:
	_end_game("All waves cleared! Press R to restart.")


func _lose_game() -> void:
	_end_game("Base destroyed. Press R to restart.")


func _end_game(message: String) -> void:
	if game_over:
		return

	game_over = true
	spawn_timer.stop()
	status_label.text = message


func _set_status(message: String) -> void:
	if not game_over:
		status_label.text = message


func _update_ui() -> void:
	health_label.text = "Base: %d" % max(base_health, 0)
	currency_label.text = "Currency: %d" % currency
	wave_label.text = "Wave: %d / %d" % [min(current_wave_index + 1, WAVES.size()), WAVES.size()]
	enemies_label.text = "Enemies: %d" % (active_enemies.size() + enemies_left_to_spawn)
