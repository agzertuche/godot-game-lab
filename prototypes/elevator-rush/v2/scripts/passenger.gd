class_name RushPassenger
extends Node2D

enum State { WAITING, RIDING, ARRIVED }

var origin_floor := 1
var destination_floor := 4
var spawned_at := 0.0
var wait_time := 0.0
var state := State.WAITING
var assigned_elevator_id := 0


func configure(origin: int, destination: int, spawn_time: float) -> void:
	origin_floor = origin
	destination_floor = destination
	spawned_at = spawn_time
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color("facc15"))
	draw_circle(Vector2.ZERO, 12.0, Color("fff7d6"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-10.0, 4.0), str(destination_floor), HORIZONTAL_ALIGNMENT_CENTER, 20.0, 12, Color("172554"))
