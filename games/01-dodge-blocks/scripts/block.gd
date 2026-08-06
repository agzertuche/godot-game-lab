extends Area2D

@export var fall_speed: float = 240.0


func _ready() -> void:
	add_to_group("blocks")


func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta

	if position.y > get_viewport_rect().size.y + 80.0:
		queue_free()
