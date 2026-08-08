extends Node2D

@export var range: float = 115.0
@export var damage: int = 1
@export var fire_cooldown: float = 0.45

var enemy_provider: Callable
var cooldown_left := 0.0


func set_enemy_provider(provider: Callable) -> void:
	enemy_provider = provider


func _process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if cooldown_left > 0.0 or not enemy_provider.is_valid():
		return

	var target := _find_target()
	if target == null:
		return

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
