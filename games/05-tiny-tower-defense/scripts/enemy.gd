extends PathFollow2D

signal died(enemy: PathFollow2D)
signal reached_base(enemy: PathFollow2D)

@export var speed: float = 70.0
@export var max_health: int = 3
@export var base_damage: int = 1
@export var currency_reward: int = 2

var current_health := max_health
var is_alive := true
var has_reached_base := false


func _ready() -> void:
	add_to_group("tower_defense_enemies")


func _process(delta: float) -> void:
	if not is_alive or has_reached_base:
		return

	progress += speed * delta
	if progress_ratio >= 1.0:
		has_reached_base = true
		reached_base.emit(self)
		queue_free()


func take_damage(amount: int) -> void:
	if not is_alive or has_reached_base:
		return

	current_health -= amount
	if current_health <= 0:
		is_alive = false
		died.emit(self)
		queue_free()
