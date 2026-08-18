class_name ElevatorRunSimulationView
extends Control

## Read-only presentation for the autonomous run. It deliberately does not
## issue dispatch, routing, or passenger-state commands.

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

var run_manager: ElevatorRunManager


func set_run_manager(manager: ElevatorRunManager) -> void:
	run_manager = manager
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run_manager == null or run_manager.current_stage_definition() == null:
		_draw_empty_state()
		return

	var definition := run_manager.current_stage_definition()
	var floor_count := definition.floor_count
	var drawing_rect := Rect2(Vector2(48.0, 12.0), Vector2(size.x - 62.0, size.y - 24.0))
	var floor_spacing := drawing_rect.size.y / float(maxi(1, floor_count - 1))
	var shaft_width := 56.0
	var shaft_gap := 16.0
	var shafts_width := shaft_width * 3.0 + shaft_gap * 2.0
	var shafts_left := drawing_rect.get_center().x - shafts_width * 0.5 + 28.0
	var floor_font := ThemeDB.fallback_font

	for floor_value: int in range(1, floor_count + 1):
		var y := _floor_y(floor_value, floor_count, drawing_rect, floor_spacing)
		draw_line(Vector2(drawing_rect.position.x, y), Vector2(drawing_rect.end.x, y), Color("31516c"), 2.0)
		draw_string(floor_font, Vector2(6.0, y + 6.0), "F%d" % floor_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("dcecff"))

	for index: int in 3:
		var x := shafts_left + float(index) * (shaft_width + shaft_gap)
		var shaft := Rect2(x, drawing_rect.position.y - 8.0, shaft_width, drawing_rect.size.y + 16.0)
		draw_rect(shaft, Color("0c1725"), true)
		draw_rect(shaft, _elevator_color(index).darkened(0.25), false, 2.0)

	_draw_waiting_passengers(drawing_rect, floor_count, floor_spacing)
	for index: int in run_manager.controllers.size():
		var controller: ElevatorController = run_manager.controllers[index]
		var cabin_x := shafts_left + float(index) * (shaft_width + shaft_gap)
		_draw_elevator(controller, cabin_x, shaft_width, drawing_rect, floor_count, floor_spacing, index)


func _draw_empty_state() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(24.0, 48.0), "BUILDING READY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("dcecff"))
	draw_string(font, Vector2(24.0, 76.0), "Start a run to observe the autonomous system.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("93b8d5"))


func _draw_waiting_passengers(drawing_rect: Rect2, floor_count: int, floor_spacing: float) -> void:
	if run_manager.request_manager == null:
		return
	var queues: Dictionary = {}
	for request: ElevatorHallRequest in run_manager.request_manager.get_active_requests():
		for passenger: ElevatorPassenger in request.waiting_passengers:
			if not queues.has(passenger.origin_floor):
				queues[passenger.origin_floor] = []
			queues[passenger.origin_floor].append(passenger)
	var font := ThemeDB.fallback_font
	for floor_key: Variant in queues:
		var floor_value := int(floor_key)
		var y := _floor_y(floor_value, floor_count, drawing_rect, floor_spacing)
		var queue: Array = queues[floor_key]
		for queue_index: int in queue.size():
			var passenger: ElevatorPassenger = queue[queue_index]
			var x := drawing_rect.position.x + 20.0 + float(queue_index % 5) * 18.0
			var row_offset := float(queue_index / 5) * 16.0
			var color := Color("59d6ff") if passenger.requested_direction == SimulationTypes.Direction.UP else Color("ff9d6b")
			draw_circle(Vector2(x, y - 10.0 - row_offset), 7.5, color)
			draw_string(font, Vector2(x - 4.0, y - 6.0 - row_offset), str(passenger.destination_floor), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("07111f"))


func _draw_elevator(
	controller: ElevatorController,
	x: float,
	shaft_width: float,
	drawing_rect: Rect2,
	floor_count: int,
	floor_spacing: float,
	index: int,
) -> void:
	var y := _floor_y_from_position(controller.travel_floor, floor_count, drawing_rect, floor_spacing)
	var cabin := Rect2(x + 4.0, y - 27.0, shaft_width - 8.0, 50.0)
	var color := _elevator_color(index)
	draw_rect(cabin, color, true)
	draw_rect(cabin, Color("eff8ff"), false, 2.0)
	var font := ThemeDB.fallback_font
	var direction := "↑" if controller.service_direction == SimulationTypes.Direction.UP else "↓" if controller.service_direction == SimulationTypes.Direction.DOWN else "•"
	draw_string(font, Vector2(x + 6.0, y - 31.0), direction, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, color)
	for passenger_index: int in controller.passengers.size():
		var passenger: ElevatorPassenger = controller.passengers[passenger_index]
		var passenger_x := cabin.position.x + 10.0 + float(passenger_index % 3) * 13.0
		var passenger_y := cabin.position.y + 16.0 + float(passenger_index / 3) * 15.0
		draw_circle(Vector2(passenger_x, passenger_y), 6.5, Color("ffec83"))
		draw_string(font, Vector2(passenger_x - 3.5, passenger_y + 3.5), str(passenger.destination_floor), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("101827"))
	draw_string(font, Vector2(x + 7.0, cabin.end.y - 5.0), "%d/%d" % [controller.passengers.size(), controller.capacity], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color("07111f"))


func _floor_y(floor_value: int, floor_count: int, drawing_rect: Rect2, floor_spacing: float) -> float:
	return drawing_rect.end.y - float(floor_value - 1) * floor_spacing


func _floor_y_from_position(position: float, floor_count: int, drawing_rect: Rect2, floor_spacing: float) -> float:
	return drawing_rect.end.y - (position - 1.0) * floor_spacing


func _elevator_color(index: int) -> Color:
	var colors := [Color("57c7ff"), Color("ad8cff"), Color("70e0a0")]
	return colors[index % colors.size()]
