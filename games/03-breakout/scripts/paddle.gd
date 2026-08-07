extends CharacterBody2D

@export var speed: float = 420.0
@export var half_width: float = 52.0


func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity = Vector2(direction * speed, 0.0)
	move_and_slide()
	_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	var viewport_width := get_viewport_rect().size.x
	position.x = clampf(position.x, half_width, viewport_width - half_width)
