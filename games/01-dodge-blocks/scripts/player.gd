extends CharacterBody2D

@export var speed: float = 320.0
@export var half_size: float = 18.0


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position.x = clampf(position.x, half_size, viewport_size.x - half_size)
	position.y = clampf(position.y, half_size, viewport_size.y - half_size)
