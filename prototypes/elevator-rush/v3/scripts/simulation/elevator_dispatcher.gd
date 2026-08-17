class_name ElevatorDispatcher
extends RefCounted

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

## Deliberately simple scoring seam. Future dispatch policies only replace this
## class or calculate_assignment_cost; controllers never make global decisions.
const PICKUP_TIME_PER_FLOOR := 1.0
const INTERMEDIATE_STOP_PENALTY := 1.5
const DIRECTION_MISMATCH_PENALTY := 8.0
const LOAD_PENALTY := 4.0
const WAITING_TIME_PRIORITY := 0.25

signal hall_request_assigned(request: ElevatorHallRequest, controller: ElevatorController)

var intermediate_stop_penalty := INTERMEDIATE_STOP_PENALTY
var waiting_time_priority := WAITING_TIME_PRIORITY
var direction_match_bonus := 0.0


## Explicit policy seams for run-only upgrades. The dispatch loop stays stable
## while its scoring policy can evolve independently.
func set_intermediate_stop_penalty_multiplier(multiplier: float) -> void:
	intermediate_stop_penalty = INTERMEDIATE_STOP_PENALTY * maxf(0.0, multiplier)


func set_waiting_time_priority_multiplier(multiplier: float) -> void:
	waiting_time_priority = WAITING_TIME_PRIORITY * maxf(0.0, multiplier)


func set_direction_match_bonus(bonus: float) -> void:
	direction_match_bonus = maxf(0.0, bonus)


func calculate_assignment_cost(
	controller: ElevatorController,
	request: ElevatorHallRequest,
	now: float,
) -> float:
	var pickup_eta := float(absi(request.floor - controller.current_floor)) * PICKUP_TIME_PER_FLOOR
	var intermediate_stops := float(_intermediate_stop_count(controller, request)) * intermediate_stop_penalty
	var direction_penalty := DIRECTION_MISMATCH_PENALTY if _requires_turnaround(controller, request) else 0.0
	var load_penalty := _load_ratio(controller) * LOAD_PENALTY
	var age_priority := request.waiting_time(now) * waiting_time_priority
	var direction_bonus := direction_match_bonus if controller.service_direction == request.direction else 0.0
	return pickup_eta + intermediate_stops + direction_penalty + load_penalty - age_priority - direction_bonus


func assign_unassigned_requests(
	controllers: Array[ElevatorController],
	requests: Array[ElevatorHallRequest],
	now: float,
) -> void:
	var ordered := requests.duplicate()
	ordered.sort_custom(_oldest_request_first)
	for request: ElevatorHallRequest in ordered:
		if not request.is_active() or request.assigned_elevator_id != 0:
			continue
		var selected: ElevatorController = null
		var selected_cost := INF
		for controller: ElevatorController in controllers:
			if not controller.can_reserve_request(request):
				continue
			var cost := calculate_assignment_cost(controller, request, now)
			if selected == null or cost < selected_cost or (is_equal_approx(cost, selected_cost) and controller.elevator_id < selected.elevator_id):
				selected = controller
				selected_cost = cost
		if selected != null:
			selected.assign_hall_request(request)
			hall_request_assigned.emit(request, selected)


func _intermediate_stop_count(controller: ElevatorController, request: ElevatorHallRequest) -> int:
	var count := 0
	for floor_value: int in controller.destination_requests:
		if _is_between(controller.current_floor, floor_value, request.floor):
			count += 1
	for assigned: ElevatorHallRequest in controller.assigned_hall_requests:
		if assigned.is_active() and _is_between(controller.current_floor, assigned.floor, request.floor):
			count += 1
	return count


func _requires_turnaround(controller: ElevatorController, request: ElevatorHallRequest) -> bool:
	if controller.service_direction == SimulationTypes.Direction.IDLE:
		return false
	return request.direction != controller.service_direction


func _load_ratio(controller: ElevatorController) -> float:
	if controller.capacity <= 0:
		return 1.0
	return float(controller.passengers.size() + controller.reserved_pickup_count()) / float(controller.capacity)


func _is_between(start_floor: int, candidate: int, end_floor: int) -> bool:
	return candidate > start_floor and candidate < end_floor if end_floor > start_floor else candidate < start_floor and candidate > end_floor


func _oldest_request_first(left: ElevatorHallRequest, right: ElevatorHallRequest) -> bool:
	if not is_equal_approx(left.created_at, right.created_at):
		return left.created_at < right.created_at
	if left.floor != right.floor:
		return left.floor < right.floor
	return left.direction < right.direction
