class_name ElevatorDispatcher
extends RefCounted

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

## These weights make the initial dispatcher deterministic and easy to tune.
## They intentionally live only here so a future dispatch algorithm can replace
## this scorer without changing hall-request or controller ownership.
const ESTIMATED_PICKUP_TIME_PER_FLOOR := 1.0
const INTERMEDIATE_STOP_PENALTY := 1.5
const DIRECTION_MISMATCH_PENALTY := 8.0
const LOAD_PENALTY := 4.0
const WAITING_TIME_PRIORITY := 0.25

signal hall_request_assigned(request: HallRequest, controller: ElevatorController)


func calculate_assignment_cost(
	controller: ElevatorController,
	request: HallRequest,
	now: float,
) -> float:
	var estimated_pickup_time := float(absi(request.floor - controller.current_floor)) * ESTIMATED_PICKUP_TIME_PER_FLOOR
	var intermediate_stop_penalty := float(_count_intermediate_stops(controller, request)) * INTERMEDIATE_STOP_PENALTY
	var direction_mismatch_penalty := DIRECTION_MISMATCH_PENALTY if _requires_direction_change(controller, request) else 0.0
	var load_penalty := _load_ratio(controller) * LOAD_PENALTY
	var waiting_time_priority := request.waiting_time(now) * WAITING_TIME_PRIORITY
	return estimated_pickup_time + intermediate_stop_penalty + direction_mismatch_penalty + load_penalty - waiting_time_priority


func assign_unassigned_requests(
	controllers: Array[ElevatorController],
	requests: Array[HallRequest],
	now: float,
) -> void:
	var ordered_requests := requests.duplicate()
	ordered_requests.sort_custom(_sort_requests)
	for request: HallRequest in ordered_requests:
		if not request.is_active() or request.assigned_elevator_id != 0:
			continue

		var selected_controller: ElevatorController = null
		var selected_cost := INF
		for controller: ElevatorController in controllers:
			if not controller.has_capacity():
				continue
			var cost := calculate_assignment_cost(controller, request, now)
			if _should_select(controller, cost, selected_controller, selected_cost):
				selected_controller = controller
				selected_cost = cost

		if selected_controller == null:
			continue

		selected_controller.assign_hall_request(request)
		hall_request_assigned.emit(request, selected_controller)


func _count_intermediate_stops(controller: ElevatorController, request: HallRequest) -> int:
	var stops := 0
	for destination_floor: int in controller.destination_requests:
		if _is_between(controller.current_floor, destination_floor, request.floor):
			stops += 1
	for assigned_request: HallRequest in controller.assigned_hall_requests:
		if assigned_request.is_active() and _is_between(controller.current_floor, assigned_request.floor, request.floor):
			stops += 1
	return stops


func _requires_direction_change(controller: ElevatorController, request: HallRequest) -> bool:
	if controller.service_direction == SimulationTypes.Direction.IDLE:
		return false
	if controller.service_direction == SimulationTypes.Direction.UP:
		return request.direction != SimulationTypes.Direction.UP or request.floor < controller.current_floor
	return request.direction != SimulationTypes.Direction.DOWN or request.floor > controller.current_floor


func _load_ratio(controller: ElevatorController) -> float:
	if controller.capacity <= 0:
		return 1.0
	return float(controller.passengers.size()) / float(controller.capacity)


func _is_between(origin_floor: int, candidate_floor: int, target_floor: int) -> bool:
	if target_floor > origin_floor:
		return candidate_floor > origin_floor and candidate_floor < target_floor
	return candidate_floor < origin_floor and candidate_floor > target_floor


func _should_select(
	candidate: ElevatorController,
	candidate_cost: float,
	current_selection: ElevatorController,
	current_cost: float,
) -> bool:
	if current_selection == null or candidate_cost < current_cost:
		return true
	if not is_equal_approx(candidate_cost, current_cost):
		return false
	return candidate.elevator_id < current_selection.elevator_id


func _sort_requests(left: HallRequest, right: HallRequest) -> bool:
	if not is_equal_approx(left.created_at, right.created_at):
		return left.created_at < right.created_at
	if left.floor != right.floor:
		return left.floor < right.floor
	return left.direction < right.direction
