extends CharacterBody2D

signal ball_lost
signal block_hit(block: StaticBody2D)

@export var speed: float = 300.0
@export var half_size: float = 9.0

var direction := Vector2(0.6, -1.0).normalized()
var is_active := true


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	var collision := move_and_collide(direction * speed * delta)
	if collision != null:
		_handle_collision(collision)

	_bounce_off_walls()
	_check_loss()


func stop() -> void:
	is_active = false


func _handle_collision(collision: KinematicCollision2D) -> void:
	var collider := collision.get_collider()

	if collider != null and collider.is_in_group("blocks") and collider.has_method("break_block"):
		collider.break_block()
		block_hit.emit(collider)

	if collider is CharacterBody2D and collider.name == "Paddle":
		_bounce_from_paddle(collider)
	else:
		direction = direction.bounce(collision.get_normal()).normalized()


func _bounce_from_paddle(paddle: CharacterBody2D) -> void:
	var paddle_half_width := 52.0
	var offset := clampf((position.x - paddle.position.x) / paddle_half_width, -1.0, 1.0)
	direction = Vector2(offset, -1.0).normalized()


func _bounce_off_walls() -> void:
	var viewport_size := get_viewport_rect().size

	if position.x <= half_size:
		position.x = half_size
		direction.x = absf(direction.x)
	elif position.x >= viewport_size.x - half_size:
		position.x = viewport_size.x - half_size
		direction.x = -absf(direction.x)

	if position.y <= half_size:
		position.y = half_size
		direction.y = absf(direction.y)


func _check_loss() -> void:
	if position.y > get_viewport_rect().size.y + half_size:
		is_active = false
		ball_lost.emit()
