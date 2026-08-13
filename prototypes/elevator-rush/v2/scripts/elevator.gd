class_name RushElevator
extends Node2D

enum State { IDLE, MOVING, BOARDING }
enum Behavior { NORMAL, UP_BIAS, DOWN_BIAS, UP_ONLY, DOWN_ONLY }

const CAPACITY := 4
const SPEED := 115.0
const DOOR_SECONDS := 0.5
const TRANSFER_SECONDS_PER_PASSENGER := 0.4
const STRATEGY_COOLDOWN_SECONDS := 8.0
const WAIT_OVERRIDE_SECONDS := 20.0

var elevator_id := 1
var current_floor := 1
var direction := 0
var last_travel_direction := 1
var target_floor := 1
var state := State.IDLE
var allowed_min := 1
var allowed_max := 10
var staging_floor := 1
var behavior_rule := Behavior.NORMAL
var pending_strategy: Dictionary = {}
var strategy_cooldown_left := 0.0
var strategy_change_count := 0
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


func set_strategy(min_floor: int, max_floor: int, stage_floor: int, behavior: int = Behavior.NORMAL) -> void:
	allowed_min = mini(min_floor, max_floor)
	allowed_max = maxi(min_floor, max_floor)
	staging_floor = clampi(stage_floor, allowed_min, allowed_max)
	behavior_rule = behavior
	queue_redraw()


func request_strategy(min_floor: int, max_floor: int, stage_floor: int, behavior: int) -> void:
	pending_strategy = _make_strategy(min_floor, max_floor, stage_floor, behavior)
	strategy_cooldown_left = STRATEGY_COOLDOWN_SECONDS
	strategy_change_count += 1
	queue_redraw()


func clear_live_strategy_state() -> void:
	pending_strategy.clear()
	strategy_cooldown_left = 0.0
	strategy_change_count = 0
	queue_redraw()


func can_serve(passenger: RushPassenger) -> bool:
	return passenger.origin_floor >= allowed_min and passenger.origin_floor <= allowed_max and passenger.destination_floor >= allowed_min and passenger.destination_floor <= allowed_max


func has_capacity() -> bool:
	return passengers.size() < CAPACITY


func update_simulation(delta: float, waiting_passengers: Array[RushPassenger]) -> Array[RushPassenger]:
	strategy_cooldown_left = maxf(0.0, strategy_cooldown_left - delta)
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

	_try_apply_pending_strategy(waiting_passengers)
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
			and signi(passenger.destination_floor - passenger.origin_floor) == continuing_direction \
			and _can_claim_direction(continuing_direction, passenger.wait_time)
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
	var oldest_passenger := _find_claimable_request(waiting_passengers)
	if oldest_passenger == null:
		return null

	var claim_direction := _travel_direction(oldest_passenger)
	var claimed_count := 0
	for passenger in waiting_passengers:
		if claimed_count >= CAPACITY - passengers.size():
			break
		if passenger.assigned_elevator_id == 0 and passenger.origin_floor == oldest_passenger.origin_floor and can_serve(passenger) and _travel_direction(passenger) == claim_direction and _can_claim_direction(claim_direction, passenger.wait_time):
			passenger.assigned_elevator_id = elevator_id
			claimed_count += 1
	return oldest_passenger


func _claim_en_route_pickup_floor(next_destination: int, waiting_passengers: Array[RushPassenger]) -> int:
	var travel_direction := signi(next_destination - current_floor)
	if travel_direction == 0 or not has_capacity():
		return 0

	var nearest_floor := 0
	for passenger in waiting_passengers:
		var is_compatible := passenger.assigned_elevator_id == 0 \
			and can_serve(passenger) \
			and signi(passenger.destination_floor - passenger.origin_floor) == travel_direction \
			and _can_claim_direction(travel_direction, passenger.wait_time) \
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
		if passenger.assigned_elevator_id == 0 and passenger.origin_floor == nearest_floor and can_serve(passenger) and signi(passenger.destination_floor - passenger.origin_floor) == travel_direction and _can_claim_direction(travel_direction, passenger.wait_time):
			passenger.assigned_elevator_id = elevator_id
			claimed_count += 1
	return nearest_floor


func _find_claimable_request(waiting_passengers: Array[RushPassenger]) -> RushPassenger:
	var priority_direction := _priority_direction()
	var oldest_fallback: RushPassenger = null
	var oldest_preferred: RushPassenger = null
	for passenger in waiting_passengers:
		if passenger.assigned_elevator_id != 0 or not can_serve(passenger):
			continue
		var passenger_direction := _travel_direction(passenger)
		if not _can_claim_direction(passenger_direction, passenger.wait_time):
			continue
		if priority_direction == 0:
			return passenger
		if passenger_direction == priority_direction:
			if oldest_preferred == null:
				oldest_preferred = passenger
		elif behavior_rule == Behavior.UP_BIAS or behavior_rule == Behavior.DOWN_BIAS:
			if passenger.wait_time >= WAIT_OVERRIDE_SECONDS and oldest_fallback == null:
				oldest_fallback = passenger
	return oldest_fallback if oldest_fallback != null else oldest_preferred


func _can_claim_direction(travel_direction: int, wait_time: float) -> bool:
	match behavior_rule:
		Behavior.UP_ONLY:
			return travel_direction > 0
		Behavior.DOWN_ONLY:
			return travel_direction < 0
		Behavior.UP_BIAS:
			return travel_direction > 0 or wait_time >= WAIT_OVERRIDE_SECONDS
		Behavior.DOWN_BIAS:
			return travel_direction < 0 or wait_time >= WAIT_OVERRIDE_SECONDS
	return true


func _priority_direction() -> int:
	if behavior_rule == Behavior.UP_BIAS or behavior_rule == Behavior.UP_ONLY:
		return 1
	if behavior_rule == Behavior.DOWN_BIAS or behavior_rule == Behavior.DOWN_ONLY:
		return -1
	return 0


func _travel_direction(passenger: RushPassenger) -> int:
	return signi(passenger.destination_floor - passenger.origin_floor)


func _try_apply_pending_strategy(waiting_passengers: Array[RushPassenger]) -> void:
	if pending_strategy.is_empty() or strategy_cooldown_left > 0.0 or not passengers.is_empty():
		return
	for passenger in waiting_passengers:
		if passenger.assigned_elevator_id == elevator_id:
			return
	set_strategy(int(pending_strategy["min"]), int(pending_strategy["max"]), int(pending_strategy["stage"]), int(pending_strategy["behavior"]))
	pending_strategy.clear()


func _make_strategy(min_floor: int, max_floor: int, stage_floor: int, behavior: int) -> Dictionary:
	var minimum := mini(min_floor, max_floor)
	var maximum := maxi(min_floor, max_floor)
	return {
		"min": minimum,
		"max": maximum,
		"stage": clampi(stage_floor, minimum, maximum),
		"behavior": behavior,
	}


func behavior_name(rule: int = -1) -> String:
	if rule == -1:
		rule = behavior_rule
	match rule:
		Behavior.UP_BIAS:
			return "UP BIAS"
		Behavior.DOWN_BIAS:
			return "DOWN BIAS"
		Behavior.UP_ONLY:
			return "UP ONLY"
		Behavior.DOWN_ONLY:
			return "DOWN ONLY"
	return "NORMAL"


func strategy_summary() -> String:
	return "%d–%d F%d %s" % [allowed_min, allowed_max, staging_floor, behavior_name()]


func pending_strategy_summary() -> String:
	if pending_strategy.is_empty():
		return ""
	return "%d–%d F%d %s" % [pending_strategy["min"], pending_strategy["max"], pending_strategy["stage"], behavior_name(int(pending_strategy["behavior"]))]


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
	var live_label := behavior_name()
	if not pending_strategy.is_empty():
		live_label = "PENDING\n" + behavior_name(int(pending_strategy["behavior"]))
	draw_rect(Rect2(-34.0, 27.0, 68.0, 23.0), Color("020617d9"), true)
	draw_string(ThemeDB.fallback_font, Vector2(-32.0, 36.0), live_label, HORIZONTAL_ALIGNMENT_CENTER, 64.0, 8, Color("f8fafc"))
