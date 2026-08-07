extends StaticBody2D

signal hit(block: StaticBody2D)

var is_destroyed := false


func _ready() -> void:
	add_to_group("blocks")


func break_block() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	hit.emit(self)
	queue_free()
