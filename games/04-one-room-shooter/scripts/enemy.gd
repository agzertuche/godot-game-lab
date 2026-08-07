extends CharacterBody2D

signal died(enemy: CharacterBody2D)

@export var speed: float = 115.0
@export var max_health: int = 2
@export var contact_damage: int = 1
@export var damage_cooldown: float = 0.8

var target: CharacterBody2D
var current_health := max_health
var damage_cooldown_left := 0.0
var is_alive := true

@onready var damage_area: Area2D = $DamageArea


func _ready() -> void:
	add_to_group("enemies")


func setup(new_target: CharacterBody2D) -> void:
	target = new_target


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	damage_cooldown_left = maxf(0.0, damage_cooldown_left - delta)
	_chase_target()
	_try_damage_target()


func take_damage(amount: int) -> void:
	if not is_alive:
		return

	current_health -= amount
	if current_health <= 0:
		is_alive = false
		died.emit(self)
		queue_free()


func _chase_target() -> void:
	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	velocity = global_position.direction_to(target.global_position) * speed
	move_and_slide()


func _try_damage_target() -> void:
	if damage_cooldown_left > 0.0:
		return

	for body in damage_area.get_overlapping_bodies():
		if body == target and body.has_method("take_damage"):
			damage_cooldown_left = damage_cooldown
			body.take_damage(contact_damage)
			return
