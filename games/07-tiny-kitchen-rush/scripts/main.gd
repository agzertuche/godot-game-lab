extends Node2D

const INGREDIENTS := ["Bun", "Patty", "Lettuce"]
const WIN_SERVED := 8
const MAX_MISSES := 3
const SHIFT_TIME := 60.0
const ORDER_PATIENCE := 10.0
const MAX_PLATE_ITEMS := 3

var active_order: Array[String] = []
var plate: Array[String] = []
var served := 0
var misses := 0
var shift_time_left := SHIFT_TIME
var patience_left := ORDER_PATIENCE
var game_over := false

@onready var order_label: Label = $CanvasLayer/OrderLabel
@onready var plate_label: Label = $CanvasLayer/PlateLabel
@onready var served_label: Label = $CanvasLayer/ServedLabel
@onready var misses_label: Label = $CanvasLayer/MissesLabel
@onready var shift_label: Label = $CanvasLayer/ShiftLabel
@onready var patience_label: Label = $CanvasLayer/PatienceLabel
@onready var status_label: Label = $CanvasLayer/StatusLabel
@onready var bun_button: Button = $CanvasLayer/BunButton
@onready var patty_button: Button = $CanvasLayer/PattyButton
@onready var lettuce_button: Button = $CanvasLayer/LettuceButton
@onready var serve_button: Button = $CanvasLayer/ServeButton
@onready var clear_button: Button = $CanvasLayer/ClearButton


func _ready() -> void:
	randomize()
	bun_button.pressed.connect(_on_bun_pressed)
	patty_button.pressed.connect(_on_patty_pressed)
	lettuce_button.pressed.connect(_on_lettuce_pressed)
	serve_button.pressed.connect(_on_serve_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	_new_order()
	_update_ui()


func _process(delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return

	shift_time_left = maxf(0.0, shift_time_left - delta)
	patience_left = maxf(0.0, patience_left - delta)

	if shift_time_left <= 0.0:
		_lose_game("Shift ended before enough orders were served.")
		return

	if patience_left <= 0.0:
		_miss_order("Order expired.")
		return

	_update_ui()


func _on_bun_pressed() -> void:
	_add_ingredient("Bun")


func _on_patty_pressed() -> void:
	_add_ingredient("Patty")


func _on_lettuce_pressed() -> void:
	_add_ingredient("Lettuce")


func _on_clear_pressed() -> void:
	if game_over:
		return

	plate.clear()
	status_label.text = "Plate cleared."
	_update_ui()


func _on_serve_pressed() -> void:
	if game_over:
		return

	if _plates_match():
		served += 1
		plate.clear()
		if served >= WIN_SERVED:
			_win_game()
		else:
			status_label.text = "Correct order served."
			_new_order()
	else:
		_miss_order("Wrong plate.")

	_update_ui()


func _add_ingredient(ingredient: String) -> void:
	if game_over:
		return
	if plate.size() >= MAX_PLATE_ITEMS:
		status_label.text = "Plate is full."
		return

	plate.append(ingredient)
	status_label.text = "%s added." % ingredient
	_update_ui()


func _new_order() -> void:
	active_order.clear()
	var order_size := randi_range(1, MAX_PLATE_ITEMS)
	for index in range(order_size):
		active_order.append(INGREDIENTS[randi_range(0, INGREDIENTS.size() - 1)])

	active_order.sort()
	patience_left = ORDER_PATIENCE


func _plates_match() -> bool:
	var sorted_plate := plate.duplicate()
	sorted_plate.sort()
	return sorted_plate == active_order


func _miss_order(message: String) -> void:
	misses += 1
	plate.clear()

	if misses >= MAX_MISSES:
		_lose_game("%s Too many misses." % message)
	else:
		status_label.text = "%s New order up." % message
		_new_order()
		_update_ui()


func _win_game() -> void:
	_end_game("Shift won! Press R to restart.")


func _lose_game(message: String) -> void:
	_end_game("%s Press R to restart." % message)


func _end_game(message: String) -> void:
	game_over = true
	status_label.text = message
	_update_ui()


func _format_items(items: Array[String]) -> String:
	if items.is_empty():
		return "-"

	return " + ".join(items)


func _update_ui() -> void:
	order_label.text = "Order: %s" % _format_items(active_order)
	plate_label.text = "Plate: %s" % _format_items(plate)
	served_label.text = "Served: %d / %d" % [served, WIN_SERVED]
	misses_label.text = "Misses: %d / %d" % [misses, MAX_MISSES]
	shift_label.text = "Shift: %02d" % ceili(shift_time_left)
	patience_label.text = "Patience: %02d" % ceili(patience_left)

	var plate_full := plate.size() >= MAX_PLATE_ITEMS
	bun_button.disabled = game_over or plate_full
	patty_button.disabled = game_over or plate_full
	lettuce_button.disabled = game_over or plate_full
	serve_button.disabled = game_over or plate.is_empty()
	clear_button.disabled = game_over or plate.is_empty()
