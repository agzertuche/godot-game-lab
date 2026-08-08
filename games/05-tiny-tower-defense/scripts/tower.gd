extends Node2D

@export var range: float = 115.0
@export var damage: int = 1
@export var fire_cooldown: float = 0.45
@export var shot_visible_time: float = 0.08

var enemy_provider: Callable
var cooldown_left := 0.0
var shot_time_left := 0.0

@onready var shot_line: Line2D = $ShotLine


func set_enemy_provider(provider: Callable) -> void:
	enemy_provider = provider


func _process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	_update_shot_line(delta)

	if cooldown_left > 0.0 or not enemy_provider.is_valid():
		return

	var target := _find_target()
	if target == null:
		return

	_show_shot(target.global_position)
	target.call("take_damage", damage)
	cooldown_left = fire_cooldown


func _find_target() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance := range

	for enemy in enemy_provider.call():
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if not enemy.has_method("take_damage"):
			continue

		var enemy_node := enemy as Node2D
		var distance := global_position.distance_to(enemy_node.global_position)
		if distance <= nearest_distance:
			nearest_enemy = enemy_node
			nearest_distance = distance

	return nearest_enemy


func _show_shot(target_position: Vector2) -> void:
	shot_line.points = PackedVector2Array([Vector2.ZERO, to_local(target_position)])
	shot_line.visible = true
	shot_time_left = shot_visible_time


func _update_shot_line(delta: float) -> void:
	if shot_time_left <= 0.0:
		shot_line.visible = false
		return

	shot_time_left -= delta
