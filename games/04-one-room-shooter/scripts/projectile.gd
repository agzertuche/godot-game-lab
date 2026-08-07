extends Area2D

@export var speed: float = 520.0
@export var damage: int = 1

var direction := Vector2.RIGHT
var has_hit := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(spawn_position: Vector2, travel_direction: Vector2) -> void:
	position = spawn_position
	direction = travel_direction.normalized()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	if not get_viewport_rect().grow(80.0).has_point(position):
		queue_free()


func _on_body_entered(body: Node) -> void:
	if has_hit:
		return

	if body.has_method("take_damage"):
		has_hit = true
		body.take_damage(damage)
		queue_free()
