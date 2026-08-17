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


func calculate_assignment_cost(
	controller: ElevatorController,
	request: ElevatorHallRequest,
	now: float,
) -> float:
	var pickup_eta := float(absi(request.floor - controller.current_floor)) * PICKUP_TIME_PER_FLOOR
	var intermediate_stops := float(_intermediate_stop_count(controller, request)) * INTERMEDIATE_STOP_PENALTY
	var direction_penalty := DIRECTION_MISMATCH_PENALTY if _requires_turnaround(controller, request) else 0.0
	var load_penalty := _load_ratio(controller) * LOAD_PENALTY
	var age_priority := request.waiting_time(now) * WAITING_TIME_PRIORITY
	return pickup_eta + intermediate_stops + direction_penalty + load_penalty - age_priority


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
