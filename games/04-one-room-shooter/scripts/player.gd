extends CharacterBody2D

signal health_changed(current_health: int)
signal died
signal projectile_requested(spawn_position: Vector2, direction: Vector2)

@export var speed: float = 300.0
@export var half_size: float = 17.0
@export var max_health: int = 5
@export var shoot_cooldown: float = 0.25

var current_health := max_health
var last_shoot_direction := Vector2.RIGHT
var shoot_cooldown_left := 0.0
var is_alive := true


func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity = Vector2.ZERO
		return

	shoot_cooldown_left = maxf(0.0, shoot_cooldown_left - delta)
	_move_player()
	_try_shoot()


func take_damage(amount: int) -> void:
	if not is_alive:
		return

	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health)

	if current_health <= 0:
		is_alive = false
		died.emit()


func _move_player() -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	_clamp_to_viewport()


func _try_shoot() -> void:
	var shoot_direction := Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")
	if shoot_direction.length() > 0.0:
		last_shoot_direction = shoot_direction.normalized()

	if shoot_direction.length() == 0.0 or shoot_cooldown_left > 0.0:
		return

	shoot_cooldown_left = shoot_cooldown
	projectile_requested.emit(position + last_shoot_direction * 24.0, last_shoot_direction)


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position.x = clampf(position.x, half_size, viewport_size.x - half_size)
	position.y = clampf(position.y, half_size, viewport_size.y - half_size)
