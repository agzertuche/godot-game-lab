extends SceneTree

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")
const RushPassenger := preload("res://scripts/passenger.gd")
const HallRequestManager := preload("res://scripts/simulation/hall_request_manager.gd")
const HALL_REQUEST_PATH := "res://scripts/simulation/hall_request.gd"
const ELEVATOR_CONTROLLER_PATH := "res://scripts/simulation/elevator_controller.gd"
const ELEVATOR_DISPATCHER_PATH := "res://scripts/simulation/elevator_dispatcher.gd"

var _failures: Array[String] = []
var _completed_request_count := 0


func _init() -> void:
	_test_shared_simulation_enums()
	_test_matching_floor_and_direction_share_one_hall_request()
	_test_opposite_directions_create_separate_hall_requests()
	_test_impossible_boundary_requests_are_rejected()
	_test_request_remains_active_until_last_passenger_leaves()
	_test_upward_collective_control_orders_compatible_stops()
	_test_downward_collective_control_orders_compatible_stops()
	_test_idle_controller_travels_to_pickup_before_adopting_request_direction()
	_test_terminal_turnaround_adopts_opposite_direction_at_current_floor()
	_test_destination_requests_are_deduplicated()
	_test_controller_owns_movement_state_transitions()
	_test_dispatcher_prefers_lower_cost_compatible_controller()
	_test_dispatcher_prioritizes_aged_request()
	_test_dispatcher_assigns_all_shared_waiters()
	_test_late_shared_waiter_inherits_existing_assignment()
	_test_dispatcher_breaks_ties_by_elevator_id()
	if _failures.is_empty():
		print("collective_control_test: PASS")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("collective_control_test: FAIL (%d assertions)" % _failures.size())
	quit(1)


func _test_shared_simulation_enums() -> void:
	_expect(SimulationTypes.Direction.DOWN == -1, "DOWN direction should be -1")
	_expect(SimulationTypes.Direction.IDLE == 0, "IDLE direction should be 0")
	_expect(SimulationTypes.Direction.UP == 1, "UP direction should be 1")
	_expect(SimulationTypes.PassengerState.COMPLETED == 5, "completed passenger state should be available")
	_expect(SimulationTypes.MovementState.STOPPED == 2, "stopped movement state should be available")
	_expect(SimulationTypes.DoorState.OPEN == 2, "open door state should be available")


func _test_matching_floor_and_direction_share_one_hall_request() -> void:
	var manager := HallRequestManager.new(10)
	var first := _passenger(5, 8, 4.0)
	var second := _passenger(5, 9, 7.0)

	var first_request = manager.register_waiting_passenger(first, 12.0)
	var second_request = manager.register_waiting_passenger(second, 14.0)

	_expect(first_request != null, "a valid passenger should create a hall request")
	_expect(first_request == second_request, "Floor 5 UP passengers should share one request")
	_expect(manager.get_active_requests().size() == 1, "matching demand should be consolidated")
	_expect(first_request.waiting_passengers.size() == 2, "shared request should hold both passengers")
	_expect(first_request.created_at == 12.0, "request creation should use simulation time")


func _test_opposite_directions_create_separate_hall_requests() -> void:
	var manager := HallRequestManager.new(10)
	var up_request = manager.register_waiting_passenger(_passenger(5, 8, 1.0), 1.0)
	var down_request = manager.register_waiting_passenger(_passenger(5, 2, 2.0), 2.0)

	_expect(up_request != null and down_request != null, "valid opposite calls should create requests")
	_expect(up_request != down_request, "Floor 5 UP and DOWN must remain separate requests")
	_expect(manager.get_active_requests().size() == 2, "opposite demand should produce two requests")


func _test_impossible_boundary_requests_are_rejected() -> void:
	var manager := HallRequestManager.new(10)
	var invalid_bottom := _passenger(1, 0, 1.0)
	var invalid_top := _passenger(10, 11, 1.0)

	_expect(manager.register_waiting_passenger(invalid_bottom, 1.0) == null, "Floor 1 DOWN should be rejected")
	_expect(manager.register_waiting_passenger(invalid_top, 1.0) == null, "Floor 10 UP should be rejected")
	_expect(manager.get_active_requests().is_empty(), "invalid boundary calls must not become active demand")


func _test_request_remains_active_until_last_passenger_leaves() -> void:
	var manager := HallRequestManager.new(10)
	var first := _passenger(5, 8, 1.0)
	var second := _passenger(5, 9, 2.0)
	manager.hall_request_completed.connect(_record_request_completion)
	_completed_request_count = 0

	manager.register_waiting_passenger(first, 3.0)
	manager.register_waiting_passenger(second, 3.0)
	manager.remove_passenger_from_request(first)

	_expect(manager.get_active_requests().size() == 1, "a partially boarded call must remain active")
	_expect(_completed_request_count == 0, "partial removal must not complete a hall request")
	manager.remove_passenger_from_request(second)
	_expect(manager.get_active_requests().is_empty(), "the final passenger removal should clear the request")
	_expect(_completed_request_count == 1, "final removal should emit hall_request_completed once")


func _test_upward_collective_control_orders_compatible_stops() -> void:
	var controller = _new_controller(2, SimulationTypes.Direction.UP)
	controller.add_hall_request(_request(3, SimulationTypes.Direction.UP))
	controller.add_hall_request(_request(4, SimulationTypes.Direction.DOWN))
	controller.add_hall_request(_request(6, SimulationTypes.Direction.UP))
	controller.add_destination_request(7)

	_expect(controller.next_stop() == 3, "UP controller should stop first at compatible UP call on floor 3")
	controller.current_floor = 3
	_expect(controller.next_stop() == 6, "UP controller should ignore DOWN floor 4 and continue to floor 6")
	controller.current_floor = 6
	_expect(controller.next_stop() == 7, "UP controller should serve rider destination floor 7 after compatible hall calls")
	controller.current_floor = 7
	_expect(controller.next_stop() == 4, "UP controller should reverse only after upward work is exhausted")


func _test_downward_collective_control_orders_compatible_stops() -> void:
	var controller = _new_controller(9, SimulationTypes.Direction.DOWN)
	controller.add_hall_request(_request(8, SimulationTypes.Direction.DOWN))
	controller.add_hall_request(_request(7, SimulationTypes.Direction.UP))
	controller.add_hall_request(_request(4, SimulationTypes.Direction.DOWN))
	controller.add_destination_request(2)

	_expect(controller.next_stop() == 8, "DOWN controller should stop first at compatible DOWN call on floor 8")
	controller.current_floor = 8
	_expect(controller.next_stop() == 4, "DOWN controller should ignore UP floor 7 and continue to floor 4")
	controller.current_floor = 4
	_expect(controller.next_stop() == 2, "DOWN controller should serve rider destination floor 2 after compatible hall calls")
	controller.current_floor = 2
	_expect(controller.next_stop() == 7, "DOWN controller should reverse only after downward work is exhausted")


func _test_idle_controller_travels_to_pickup_before_adopting_request_direction() -> void:
	var controller = _new_controller(4, SimulationTypes.Direction.IDLE)
	controller.add_hall_request(_request(8, SimulationTypes.Direction.DOWN))

	_expect(controller.next_stop() == 8, "idle controller should choose its assigned pickup floor")
	_expect(controller.service_direction == SimulationTypes.Direction.IDLE, "idle controller should not adopt passenger direction before pickup")
	controller.current_floor = 8
	controller.recalculate_service_direction()
	_expect(controller.service_direction == SimulationTypes.Direction.DOWN, "controller should adopt DOWN service direction at the pickup floor")


func _test_terminal_turnaround_adopts_opposite_direction_at_current_floor() -> void:
	var controller = _new_controller(7, SimulationTypes.Direction.UP)
	controller.add_hall_request(_request(7, SimulationTypes.Direction.DOWN))

	controller.recalculate_service_direction()
	_expect(controller.service_direction == SimulationTypes.Direction.DOWN, "terminal UP controller should adopt current-floor DOWN request instead of becoming idle")
	_expect(controller.next_stop() == 7, "current-floor turnaround should retain the DOWN hall request as the next service")


func _test_destination_requests_are_deduplicated() -> void:
	var controller = _new_controller(2, SimulationTypes.Direction.UP)
	controller.add_destination_request(7)
	controller.add_destination_request(7)

	_expect(controller.destination_requests.size() == 1, "matching passenger destinations should produce one physical stop")


func _test_controller_owns_movement_state_transitions() -> void:
	var controller = _new_controller(2, SimulationTypes.Direction.IDLE)
	controller.begin_moving_to(5)
	_expect(controller.movement_state == SimulationTypes.MovementState.MOVING, "controller should enter MOVING when it accepts a target")
	_expect(controller.target_floor == 5, "controller should own the active target floor")
	controller.arrive_at(5)
	_expect(controller.movement_state == SimulationTypes.MovementState.STOPPED, "controller should enter STOPPED when it arrives")
	controller.complete_stop()
	_expect(controller.movement_state == SimulationTypes.MovementState.IDLE, "controller should return to IDLE after stop processing")


func _test_dispatcher_prefers_lower_cost_compatible_controller() -> void:
	var dispatcher = _new_dispatcher()
	var near_up := _new_controller(4, SimulationTypes.Direction.UP, 1)
	var far_down := _new_controller(9, SimulationTypes.Direction.DOWN, 2)
	var request = _request(5, SimulationTypes.Direction.UP)
	var controllers: Array[ElevatorController] = [far_down, near_up]
	var requests: Array[HallRequest] = [request]

	_expect(dispatcher.calculate_assignment_cost(near_up, request, 10.0) < dispatcher.calculate_assignment_cost(far_down, request, 10.0), "compatible controller with lower pickup ETA should score lower")
	dispatcher.assign_unassigned_requests(controllers, requests, 10.0)
	_expect(request.assigned_elevator_id == 1, "dispatcher should assign the lower-cost compatible controller")


func _test_dispatcher_prioritizes_aged_request() -> void:
	var dispatcher = _new_dispatcher()
	var controller := _new_controller(1, SimulationTypes.Direction.IDLE, 1)
	var new_request = _request(5, SimulationTypes.Direction.UP, 18.0)
	var aged_request = _request(5, SimulationTypes.Direction.UP, 0.0)

	_expect(dispatcher.calculate_assignment_cost(controller, aged_request, 20.0) < dispatcher.calculate_assignment_cost(controller, new_request, 20.0), "an otherwise equal aged request should score lower")


func _test_dispatcher_assigns_all_shared_waiters() -> void:
	var dispatcher = _new_dispatcher()
	var manager := HallRequestManager.new(10)
	var first := _passenger(3, 7, 0.0)
	var second := _passenger(3, 9, 1.0)
	var request = manager.register_waiting_passenger(first, 0.0)
	manager.register_waiting_passenger(second, 1.0)
	var controller := _new_controller(1, SimulationTypes.Direction.IDLE, 3)
	var controllers: Array[ElevatorController] = [controller]
	var requests: Array[HallRequest] = [request]

	dispatcher.assign_unassigned_requests(controllers, requests, 2.0)
	_expect(first.assigned_elevator_id == 3 and second.assigned_elevator_id == 3, "every passenger in an assigned shared request should inherit its elevator")
	_expect(first.state == SimulationTypes.PassengerState.ASSIGNED and second.state == SimulationTypes.PassengerState.ASSIGNED, "shared waiters should transition from WAITING to ASSIGNED")


func _test_late_shared_waiter_inherits_existing_assignment() -> void:
	var dispatcher = _new_dispatcher()
	var manager := HallRequestManager.new(10)
	var first := _passenger(3, 7, 0.0)
	var request = manager.register_waiting_passenger(first, 0.0)
	var controller := _new_controller(1, SimulationTypes.Direction.IDLE, 3)
	var controllers: Array[ElevatorController] = [controller]
	var requests: Array[HallRequest] = [request]

	dispatcher.assign_unassigned_requests(controllers, requests, 1.0)
	var late_passenger := _passenger(3, 8, 2.0)
	manager.register_waiting_passenger(late_passenger, 2.0)
	_expect(late_passenger.assigned_elevator_id == 3, "a later passenger on an assigned request should inherit its elevator")
	_expect(late_passenger.state == SimulationTypes.PassengerState.ASSIGNED, "a later passenger on an assigned request should inherit ASSIGNED state")


func _test_dispatcher_breaks_ties_by_elevator_id() -> void:
	var dispatcher = _new_dispatcher()
	var higher_id := _new_controller(4, SimulationTypes.Direction.IDLE, 2)
	var lower_id := _new_controller(4, SimulationTypes.Direction.IDLE, 1)
	var request = _request(5, SimulationTypes.Direction.UP)
	var controllers: Array[ElevatorController] = [higher_id, lower_id]
	var requests: Array[HallRequest] = [request]

	dispatcher.assign_unassigned_requests(controllers, requests, 5.0)
	_expect(request.assigned_elevator_id == 1, "equal dispatcher costs should choose the lower elevator id deterministically")


func _new_controller(floor: int, service_direction: int, identifier: int = 0):
	var controller_script = load(ELEVATOR_CONTROLLER_PATH)
	_expect(controller_script != null, "elevator controller script should exist")
	if controller_script == null:
		return _MissingController.new()
	var controller = controller_script.new(identifier, floor)
	controller.current_floor = floor
	controller.service_direction = service_direction
	return controller


func _new_dispatcher():
	var dispatcher_script = load(ELEVATOR_DISPATCHER_PATH)
	_expect(dispatcher_script != null, "elevator dispatcher script should exist")
	if dispatcher_script == null:
		return _MissingDispatcher.new()
	return dispatcher_script.new()


func _request(floor: int, direction: int, created_at: float = 0.0):
	var request_script = load(HALL_REQUEST_PATH)
	var request = request_script.new(floor, direction, created_at)
	var passenger := RushPassenger.new()
	passenger.configure(floor, floor + direction, 0.0)
	request.add_passenger(passenger)
	return request


func _passenger(origin: int, destination: int, request_time: float) -> RushPassenger:
	var passenger := RushPassenger.new()
	passenger.configure(origin, destination, request_time)
	return passenger


func _record_request_completion(_request) -> void:
	_completed_request_count += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class _MissingController:
	var current_floor := 0
	var service_direction := SimulationTypes.Direction.IDLE

	func add_hall_request(_request) -> void:
		pass

	func add_destination_request(_floor: int) -> void:
		pass

	func next_stop() -> int:
		return 0

	func recalculate_service_direction() -> void:
		pass


class _MissingDispatcher:
	func calculate_assignment_cost(_controller, _request, _now: float) -> float:
		return 0.0

	func assign_unassigned_requests(_controllers, _requests, _now: float) -> void:
		pass
