extends Area2D

signal collected

var is_collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if is_collected or not body is CharacterBody2D:
		return

	is_collected = true
	collected.emit()
	queue_free()
