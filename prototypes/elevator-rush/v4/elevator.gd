class_name V4Elevator
extends RefCounted

signal elevator_arrived(floor_number: int)
signal doors_opened(floor_number: int)
signal passenger_boarded(passenger: V4Passenger)
signal passenger_exited(passenger: V4Passenger)
signal direction_changed(direction: int)

enum Motion { IDLE, MOVING, SERVICE }
enum Door { CLOSED, OPENING, OPEN, CLOSING }
var id: int
var floor_position := 1.0
var target := 0
var direction := 0
var motion := Motion.IDLE
var door := Door.CLOSED
var active_strategy := V4Strategy.new()
var riders: Array[V4Passenger] = []
var capacity := 4
var speed := 1.0
var door_seconds := 0.4
var transfer_seconds := 0.35
var timer := 0.0
var transferring: V4Passenger
var parking := false
var stops := 0
var transported := 0
var full_seconds := 0.0
var idle_seconds := 0.0
var express_owned := false

func _init(identifier: int = 1, floors: int = 4) -> void:
	id = identifier
	active_strategy.max_floor = floors

func free_seats(hall: V4HallRequests) -> int:
	return maxi(0, capacity - riders.size() - hall.assigned(id).size())

func destinations() -> Array[int]:
	var result: Array[int] = []
	for p in riders:
		if not result.has(p.destination):
			result.append(p.destination)
	result.sort()
	return result

func set_direction(value: int) -> void:
	if direction != value:
		direction = value
		direction_changed.emit(value)

func choose_stop(hall: V4HallRequests) -> int:
	var calls := hall.assigned(id)
	var stops_ahead: Array[int] = destinations()
	if not (active_strategy.express and not riders.is_empty()):
		for p in calls:
			if p.direction == direction:
				stops_ahead.append(p.origin)
	if direction != 0:
		var best := 0
		for floor_number in stops_ahead:
			if (floor_number - floor_position) * direction >= -0.001:
				if best == 0 or absf(floor_number - floor_position) < absf(best - floor_position):
					best = floor_number
		if best != 0:
			return best
	# No useful work ahead. Deliver remaining cabin destinations before seeking a call.
	if not riders.is_empty():
		var dest := riders[0].destination
		for p in riders:
			if absf(p.destination - floor_position) < absf(dest - floor_position):
				dest = p.destination
		set_direction(signi(dest - roundi(floor_position)))
		return dest
	if not calls.is_empty():
		var selected := calls[0]
		for p in calls:
			if absf(p.origin - floor_position) < absf(selected.origin - floor_position):
				selected = p
		# Empty approach travel is independent from service direction.
		set_direction(selected.direction)
		return selected.origin
	set_direction(0)
	return 0

func step(delta: float, hall: V4HallRequests, now: float) -> void:
	if riders.size() >= capacity:
		full_seconds += delta
	if riders.is_empty() and hall.assigned(id).is_empty():
		idle_seconds += delta
	if motion == Motion.SERVICE:
		advance_service(delta, hall, now)
		return
	if motion == Motion.IDLE:
		target = choose_stop(hall)
		parking = target == 0
		if parking:
			target = active_strategy.staging
			if is_equal_approx(floor_position, float(target)):
				return
		motion = Motion.MOVING
	if motion == Motion.MOVING:
		# Selective service can insert a newly assigned compatible stop ahead.
		if not parking:
			var revised := choose_stop(hall)
			if revised != 0:
				target = revised
			elif riders.is_empty():
				motion = Motion.IDLE
				return
		floor_position = move_toward(floor_position, target, speed * delta)
		if is_equal_approx(floor_position, float(target)):
			if parking:
				motion = Motion.IDLE
				return
			motion = Motion.SERVICE
			door = Door.OPENING
			timer = door_seconds
			stops += 1
			elevator_arrived.emit(target)

func advance_service(delta: float, hall: V4HallRequests, now: float) -> void:
	timer = maxf(0.0, timer - delta)
	if timer > 0.000001:
		return
	if door == Door.CLOSING:
		door = Door.CLOSED
		motion = Motion.IDLE
		return
	if door == Door.OPENING:
		door = Door.OPEN
		doors_opened.emit(roundi(floor_position))
	if transferring != null:
		var p := transferring
		transferring = null
		if p.state == V4Passenger.State.EXITING:
			riders.erase(p)
			p.state = V4Passenger.State.COMPLETED
			p.owner = 0
			transported += 1
			passenger_exited.emit(p)
		else:
			p.state = V4Passenger.State.RIDING
			passenger_boarded.emit(p)
	for p in riders:
		if p.destination == roundi(floor_position):
			p.state = V4Passenger.State.EXITING
			transferring = p
			timer = transfer_seconds
			return
	# Reverse at terminal stops before boarding an opposite-direction request.
	if riders.is_empty():
		var next := choose_stop(hall)
		if next != roundi(floor_position):
			begin_closing()
			return
	if not (active_strategy.express and not riders.is_empty()):
		for p in hall.assigned(id):
			if p.origin == roundi(floor_position) and p.direction == direction and riders.size() < capacity:
				p.state = V4Passenger.State.BOARDING
				p.pickup_wait = now - p.request_time
				hall.remove(p)
				riders.append(p)
				transferring = p
				timer = transfer_seconds
				return
	begin_closing()

func begin_closing() -> void:
	door = Door.CLOSING
	timer = door_seconds
