class_name V4BuildingView
extends Control

var run

func set_run(value) -> void:
	run = value
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	if run == null:
		draw_string(font, Vector2(20, 34), "BUILDING READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("dcecff"))
		return
	var floors: int = run.wave_definition.floors
	var rect := Rect2(Vector2(56, 18), Vector2(maxf(260, size.x - 78), maxf(220, size.y - 36)))
	var spacing := rect.size.y / float(maxi(1, floors - 1))
	for floor_number in range(1, floors + 1):
		var y := _floor_y(floor_number, floors, rect, spacing)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("31516c"), 2)
		draw_string(font, Vector2(10, y + 5), "F%d" % floor_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dcecff"))
	var shaft_width := 58.0
	var gap := 18.0
	var left := rect.get_center().x - (shaft_width * 3 + gap * 2) * 0.5
	for index in 3:
		var x := left + index * (shaft_width + gap)
		draw_rect(Rect2(x, rect.position.y - 6, shaft_width, rect.size.y + 12), Color("0c1725"), true)
		draw_rect(Rect2(x, rect.position.y - 6, shaft_width, rect.size.y + 12), _car_color(index).darkened(0.2), false, 2)
		if index < run.simulation.cars.size():
			_draw_car(run.simulation.cars[index], x, shaft_width, rect, floors, spacing, index)
	_draw_waiting(rect, floors, spacing)

func _draw_car(car, x: float, shaft_width: float, rect: Rect2, floors: int, spacing: float, index: int) -> void:
	var y := _floor_y_position(car.floor_position, rect, spacing)
	var cabin := Rect2(x + 5, y - 25, shaft_width - 10, 48)
	draw_rect(cabin, _car_color(index), true)
	draw_rect(cabin, Color("eff8ff"), false, 2)
	var font := ThemeDB.fallback_font
	var arrow := "↑" if car.direction > 0 else "↓" if car.direction < 0 else "•"
	draw_string(font, Vector2(x + 5, y - 29), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, _car_color(index))
	for passenger_index in car.riders.size():
		var p = car.riders[passenger_index]
		var px: float = cabin.position.x + 12 + (passenger_index % 3) * 14
		var py: float = cabin.position.y + 15 + (passenger_index / 3) * 14
		draw_circle(Vector2(px, py), 8, Color("ffec83"))
		draw_string(font, Vector2(px - 4, py + 4), str(p.destination), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("101827"))
	draw_string(font, Vector2(x + 8, cabin.end.y - 4), "%d/%d" % [car.riders.size(), car.capacity], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("07111f"))

func _draw_waiting(rect: Rect2, floors: int, spacing: float) -> void:
	if run.simulation == null:
		return
	var slots: Dictionary = {}
	for passenger in run.simulation.passengers:
		if not passenger.waiting():
			continue
		var key: int = passenger.origin
		var index: int = slots.get(key, 0)
		slots[key] = index + 1
		var y := _floor_y(key, floors, rect, spacing)
		var x := rect.position.x - 24 - (index % 4) * 17
		var row := index / 4
		draw_circle(Vector2(x, y - 10 - row * 16), 8, Color("59d6ff") if passenger.direction > 0 else Color("ff9d6b"))
		draw_string(ThemeDB.fallback_font, Vector2(x - 4, y - 6 - row * 16), str(passenger.destination), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("07111f"))

func _floor_y(floor_number: int, floors: int, rect: Rect2, spacing: float) -> float:
	return rect.end.y - float(floor_number - 1) * spacing

func _floor_y_position(position: float, rect: Rect2, spacing: float) -> float:
	return rect.end.y - (position - 1.0) * spacing

func _car_color(index: int) -> Color:
	return [Color("57c7ff"), Color("ad8cff"), Color("70e0a0")][index % 3]
