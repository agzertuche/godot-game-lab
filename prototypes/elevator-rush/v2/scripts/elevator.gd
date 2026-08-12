class_name RushElevator
extends Node2D

enum State { IDLE, MOVING, BOARDING }

const CAPACITY := 4
const SPEED := 115.0
const DOOR_SECONDS := 0.5
const TRANSFER_SECONDS_PER_PASSENGER := 0.4

var elevator_id := 1
var current_floor := 1
var direction := 0
var last_travel_direction := 1
var target_floor := 1
var state := State.IDLE
var allowed_min := 1
var allowed_max := 10
var staging_floor := 1
var passengers: Array[RushPassenger] = []
var busy_time := 0.0
var transported_count := 0
var stop_count := 0
var boarding_time_left := 0.0
var floor_y_positions: Array[float] = []


func configure(identifier: int, floor_positions: Array[float]) -> void:
	elevator_id = identifier
	floor_y_positions = floor_positions.duplicate()
	position.y = _floor_y(current_floor)
	queue_redraw()


func set_strategy(min_floor: int, max_floor: int, stage_floor: int) -> void:
	allowed_min = mini(min_floor, max_floor)
	allowed_max = maxi(min_floor, max_floor)
	staging_floor = clampi(stage_floor, allowed_min, allowed_max)


func can_serve(passenger: RushPassenger) -> bool:
	return passenger.origin_floor >= allowed_min and passenger.origin_floor <= allowed_max and passenger.destination_floor >= allowed_min and passenger.destination_floor <= allowed_max


func has_capacity() -> bool:
	return passengers.size() < CAPACITY


func update_simulation(delta: float, waiting_passengers: Array[RushPassenger]) -> Array[RushPassenger]:
	if state != State.IDLE:
		busy_time += delta

	if state == State.MOVING:
		_move(delta)
	elif state == State.BOARDING:
		boarding_time_left -= delta
		if boarding_time_left <= 0.0:
			state = State.IDLE

	if state != State.IDLE:
		return []

	return _choose_next_action(waiting_passengers)


func _choose_next_action(waiting_passengers: Array[RushPassenger]) -> Array[RushPassenger]:
	var arrived := _drop_off_current_floor()
	if not arrived.is_empty():
		var continuing_boarders := _board_current_floor(waiting_passengers, true)
		_finish_stop(arrived.size() + continuing_boarders.size())
		return arrived

	var boarded := _board_current_floor(waiting_passengers)
	if not boarded.is_empty():
		_finish_stop(boarded.size())
		return []

	var next_destination := _next_rider_destination()
	if next_destination > 0:
		var pickup_floor := _claim_en_route_pickup_floor(next_destination, waiting_passengers)
		_move_to(pickup_floor if pickup_floor > 0 else next_destination)
		return []

	var next_request := _claim_oldest_valid_request(waiting_passengers)
	if next_request != null:
		_move_to(next_request.origin_floor)
	elif current_floor != staging_floor:
		_move_to(staging_floor)
	return []


func _drop_off_current_floor() -> Array[RushPassenger]:
	var arrived: Array[RushPassenger] = []
	for passenger in passengers.duplicate():
		if passenger.destination_floor == current_floor:
			passengers.erase(passenger)
			passenger.state = RushPassenger.State.ARRIVED
			arrived.append(passenger)
	queue_redraw()
	return arrived


func _board_current_floor(waiting_passengers: Array[RushPassenger], allow_continuing_direction: bool = false) -> Array[RushPassenger]:
	var boarded: Array[RushPassenger] = []
	var continuing_direction := 0
	if allow_continuing_direction:
		var next_destination := _next_rider_destination()
		continuing_direction = signi(next_destination - current_floor)

	for passenger in waiting_passengers:
		if not has_capacity():
			break
		var is_assigned_pickup := passenger.assigned_elevator_id == elevator_id
		var is_matching_continuation := allow_continuing_direction \
			and passenger.assigned_elevator_id == 0 \
			and continuing_direction != 0 \
			and signi(passenger.destination_floor - passenger.origin_floor) == continuing_direction
		if passenger.origin_floor == current_floor and can_serve(passenger) and (is_assigned_pickup or is_matching_continuation):
			passenger.state = RushPassenger.State.RIDING
			passenger.visible = false
			passengers.append(passenger)
			boarded.append(passenger)
	queue_redraw()
	return boarded


func _next_rider_destination() -> int:
	if passengers.is_empty():
		return 0

	var preferred_floor := 0
	if last_travel_direction >= 0:
		for passenger in passengers:
			if passenger.destination_floor > current_floor and (preferred_floor == 0 or passenger.destination_floor < preferred_floor):
				preferred_floor = passenger.destination_floor
	else:
		for passenger in passengers:
			if passenger.destination_floor < current_floor and passenger.destination_floor > preferred_floor:
				preferred_floor = passenger.destination_floor

	if preferred_floor != 0:
		return preferred_floor

	var reverse_floor := passengers[0].destination_floor
	for passenger in passengers:
		if last_travel_direction >= 0:
			reverse_floor = maxi(reverse_floor, passenger.destination_floor)
		else:
			reverse_floor = mini(reverse_floor, passenger.destination_floor)
	return reverse_floor


func _claim_oldest_valid_request(waiting_passengers: Array[RushPassenger]) -> RushPassenger:
	for oldest_passenger in waiting_passengers:
		if oldest_passenger.assigned_elevator_id != 0 or not can_serve(oldest_passenger):
			continue

		var claimed_count := 0
		for passenger in waiting_passengers:
			if claimed_count >= CAPACITY - passengers.size():
				break
			if passenger.assigned_elevator_id == 0 and passenger.origin_floor == oldest_passenger.origin_floor and can_serve(passenger):
				passenger.assigned_elevator_id = elevator_id
				claimed_count += 1
		return oldest_passenger
	return null


func _claim_en_route_pickup_floor(next_destination: int, waiting_passengers: Array[RushPassenger]) -> int:
	var travel_direction := signi(next_destination - current_floor)
	if travel_direction == 0 or not has_capacity():
		return 0

	var nearest_floor := 0
	for passenger in waiting_passengers:
		var is_compatible := passenger.assigned_elevator_id == 0 \
			and can_serve(passenger) \
			and signi(passenger.destination_floor - passenger.origin_floor) == travel_direction \
			and _is_floor_between(passenger.origin_floor, next_destination, travel_direction)
		if not is_compatible:
			continue
		if nearest_floor == 0 or (travel_direction > 0 and passenger.origin_floor < nearest_floor) or (travel_direction < 0 and passenger.origin_floor > nearest_floor):
			nearest_floor = passenger.origin_floor

	if nearest_floor == 0:
		return 0

	var claimed_count := 0
	for passenger in waiting_passengers:
		if claimed_count >= CAPACITY - passengers.size():
			break
		if passenger.assigned_elevator_id == 0 and passenger.origin_floor == nearest_floor and can_serve(passenger) and signi(passenger.destination_floor - passenger.origin_floor) == travel_direction:
			passenger.assigned_elevator_id = elevator_id
			claimed_count += 1
	return nearest_floor


func _is_floor_between(floor: int, destination: int, travel_direction: int) -> bool:
	if travel_direction > 0:
		return floor > current_floor and floor < destination
	return floor < current_floor and floor > destination


func _move_to(floor: int) -> void:
	if floor == current_floor:
		return
	target_floor = floor
	direction = signi(target_floor - current_floor)
	last_travel_direction = direction
	state = State.MOVING
	queue_redraw()


func _move(delta: float) -> void:
	var target_y := _floor_y(target_floor)
	position.y = move_toward(position.y, target_y, SPEED * delta)
	if is_equal_approx(position.y, target_y):
		current_floor = target_floor
		direction = 0
		stop_count += 1
		state = State.IDLE
		queue_redraw()


func _finish_stop(passenger_count: int) -> void:
	boarding_time_left = DOOR_SECONDS + passenger_count * TRANSFER_SECONDS_PER_PASSENGER
	state = State.BOARDING
	queue_redraw()


func _floor_y(floor: int) -> float:
	return floor_y_positions[floor - 1]


func _draw() -> void:
	var color := Color("38bdf8") if state != State.IDLE else Color("60a5fa")
	draw_rect(Rect2(-25.0, -22.0, 50.0, 44.0), color, true)
	draw_rect(Rect2(-25.0, -22.0, 50.0, 44.0), Color("e0f2fe"), false, 2.0)
	var rider_positions := [Vector2(-11.0, -10.0), Vector2(11.0, -10.0), Vector2(-11.0, 10.0), Vector2(11.0, 10.0)]
	for index in range(passengers.size()):
		var rider_position: Vector2 = rider_positions[index]
		draw_circle(rider_position, 9.0, Color("facc15"))
		draw_circle(rider_position, 9.0, Color("fff7d6"), false, 1.5)
		draw_string(ThemeDB.fallback_font, rider_position + Vector2(-9.0, 3.5), str(passengers[index].destination_floor), HORIZONTAL_ALIGNMENT_CENTER, 18.0, 10, Color("172554"))
