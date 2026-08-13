extends SceneTree

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")
const RushPassenger := preload("res://scripts/passenger.gd")
const HallRequestManager := preload("res://scripts/simulation/hall_request_manager.gd")
const HALL_REQUEST_PATH := "res://scripts/simulation/hall_request.gd"
const ELEVATOR_CONTROLLER_PATH := "res://scripts/simulation/elevator_controller.gd"
const ELEVATOR_DISPATCHER_PATH := "res://scripts/simulation/elevator_dispatcher.gd"

var _failures: Array[String] = []
var _completed_request_count := 0
var _request_completed_event_count := 0
var _arrival_signal_count := 0


func _init() -> void:
	_test_shared_simulation_enums()
	_test_matching_floor_and_direction_share_one_hall_request()
	_test_opposite_directions_create_separate_hall_requests()
	_test_impossible_boundary_requests_are_rejected()
	_test_request_remains_active_until_last_passenger_leaves()
	_test_request_completed_event_is_exposed()
	_test_upward_collective_control_orders_compatible_stops()
	_test_downward_collective_control_orders_compatible_stops()
	_test_idle_controller_travels_to_pickup_before_adopting_request_direction()
	_test_terminal_turnaround_adopts_opposite_direction_at_current_floor()
	_test_destination_requests_are_deduplicated()
	_test_controller_owns_movement_state_transitions()
	_test_service_dwell_and_staging_arrivals()
	_test_dispatcher_prefers_lower_cost_compatible_controller()
	_test_dispatcher_prioritizes_aged_request()
	_test_dispatcher_assigns_all_shared_waiters()
	_test_late_shared_waiter_inherits_existing_assignment()
	_test_dispatcher_breaks_ties_by_elevator_id()
	_test_dispatcher_sorts_requests_before_costs_can_change()
	_test_dispatcher_skips_full_controller()
	_test_stop_exits_before_boarding_when_car_is_full()
	_test_stop_reoffers_excess_capacity_demand()
	_test_stop_deduplicates_boarded_destinations()
	_test_stop_leaves_incompatible_direction_waiting()
	_test_arrival_signal_is_emitted_once_per_stop_lifecycle()
	_test_deterministic_two_car_collective_scenario()
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


func _test_request_completed_event_is_exposed() -> void:
	var manager := HallRequestManager.new(10)
	var passenger := _passenger(4, 8, 0.0)
	_request_completed_event_count = 0
	manager.request_completed.connect(_record_request_completed)
	manager.register_waiting_passenger(passenger, 0.0)
	manager.remove_passenger_from_request(passenger)
	_expect(_request_completed_event_count == 1, "request_completed should be available for simulation observers")


func _test_upward_collective_control_orders_compatible_stops() -> void:
	var controller = _new_controller(2, SimulationTypes.Direction.UP)
	controller.assign_hall_request(_request(3, SimulationTypes.Direction.UP))
	controller.assign_hall_request(_request(4, SimulationTypes.Direction.DOWN))
	controller.assign_hall_request(_request(6, SimulationTypes.Direction.UP))
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
	controller.assign_hall_request(_request(8, SimulationTypes.Direction.DOWN))
	controller.assign_hall_request(_request(7, SimulationTypes.Direction.UP))
	controller.assign_hall_request(_request(4, SimulationTypes.Direction.DOWN))
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
	controller.assign_hall_request(_request(8, SimulationTypes.Direction.DOWN))

	_expect(controller.next_stop() == 8, "idle controller should choose its assigned pickup floor")
	_expect(controller.service_direction == SimulationTypes.Direction.IDLE, "idle controller should not adopt passenger direction before pickup")
	controller.current_floor = 8
	controller.recalculate_service_direction()
	_expect(controller.service_direction == SimulationTypes.Direction.DOWN, "controller should adopt DOWN service direction at the pickup floor")


func _test_terminal_turnaround_adopts_opposite_direction_at_current_floor() -> void:
	var controller = _new_controller(7, SimulationTypes.Direction.UP)
	controller.assign_hall_request(_request(7, SimulationTypes.Direction.DOWN))

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
	_expect(not controller.advance_travel(0.25), "logical travel should not arrive before reaching the target")
	_expect(controller.current_floor == 2, "current floor should remain discrete while travelling")
	_expect(controller.advance_travel(2.0), "controller should report a logical arrival without a visual callback")
	_expect(controller.movement_state == SimulationTypes.MovementState.STOPPED, "controller should enter STOPPED when it arrives")
	_expect(controller.current_floor == 5, "logical travel should update the current floor on arrival")
	controller.complete_stop()
	_expect(controller.movement_state == SimulationTypes.MovementState.IDLE, "controller should return to IDLE after stop processing")


func _test_service_dwell_and_staging_arrivals() -> void:
	var service_controller = _new_controller(1, SimulationTypes.Direction.IDLE)
	service_controller.target_is_service_stop = true
	service_controller.arrive_at(1)
	service_controller.begin_service_dwell()
	_expect(service_controller.door_state == SimulationTypes.DoorState.OPEN, "service arrival should open doors before transfers")
	_expect(not service_controller.advance_service_dwell(0.4), "service dwell should remain active before its timer expires")
	_expect(service_controller.advance_service_dwell(1.0), "service dwell should complete through controller time")

	var staging_controller = _new_controller(1, SimulationTypes.Direction.IDLE)
	staging_controller.configure_strategy(1, 10, 5, 0)
	_expect(staging_controller.next_stop() == 5, "idle controller should choose its staging floor when no service demand exists")
	_expect(not staging_controller.target_is_service_stop, "staging should not be classified as a service stop")
	staging_controller.begin_moving_to(5)
	staging_controller.advance_travel(3.0)
	_expect(not staging_controller.arrived_service_stop, "staging arrival should not begin a service stop")
	_expect(staging_controller.door_state == SimulationTypes.DoorState.CLOSED, "staging arrival should not open doors")
	staging_controller.complete_stop()


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


func _test_dispatcher_sorts_requests_before_costs_can_change() -> void:
	var dispatcher = _new_dispatcher()
	var lower_controller := _new_controller(1, SimulationTypes.Direction.IDLE, 1)
	var upper_controller := _new_controller(10, SimulationTypes.Direction.IDLE, 2)
	var earlier_request = _request(4, SimulationTypes.Direction.UP, 0.0)
	var later_request = _request(5, SimulationTypes.Direction.UP, 1.0)
	var controllers: Array[ElevatorController] = [lower_controller, upper_controller]
	var reversed_requests: Array[HallRequest] = [later_request, earlier_request]

	# The floor 4 call creates an intermediate-stop penalty for floor 5. Sorting
	# by created_at must make this result independent from source/map iteration.
	dispatcher.assign_unassigned_requests(controllers, reversed_requests, 2.0)
	_expect(earlier_request.assigned_elevator_id == 1, "the oldest request should be assigned before a later request")
	_expect(later_request.assigned_elevator_id == 2, "later assignment should see the earlier controller stop regardless of input order")


func _test_dispatcher_skips_full_controller() -> void:
	var dispatcher = _new_dispatcher()
	var full_nearby_controller := _new_controller(4, SimulationTypes.Direction.IDLE, 1)
	full_nearby_controller.capacity = 1
	full_nearby_controller.passengers.append(_passenger(1, 2, 0.0))
	var available_controller := _new_controller(9, SimulationTypes.Direction.IDLE, 2)
	var request = _request(5, SimulationTypes.Direction.UP)
	var controllers: Array[ElevatorController] = [full_nearby_controller, available_controller]
	var requests: Array[HallRequest] = [request]

	dispatcher.assign_unassigned_requests(controllers, requests, 1.0)
	_expect(request.assigned_elevator_id == 2, "a full controller must be skipped even when it has the lower travel cost")


func _test_stop_exits_before_boarding_when_car_is_full() -> void:
	var manager := HallRequestManager.new(10)
	var controller := _new_controller(5, SimulationTypes.Direction.UP, 1)
	controller.capacity = 1
	var exiting_passenger := _passenger(2, 5, 0.0)
	exiting_passenger.state = SimulationTypes.PassengerState.RIDING
	exiting_passenger.assigned_elevator_id = 1
	controller.passengers.append(exiting_passenger)
	controller.add_destination_request(5)
	var waiting_passenger := _passenger(5, 8, 0.0)
	var request = manager.register_waiting_passenger(waiting_passenger, 0.0)
	controller.assign_hall_request(request)

	_arrive_for_service(controller, 5)
	var events: Dictionary = controller.process_stop(manager, 10.0)
	_expect(events["exited"].size() == 1, "a rider should exit before pickup processing")
	_expect(events["boarded"].size() == 1, "dropoff capacity should permit a waiting passenger to board")
	_expect(exiting_passenger.state == SimulationTypes.PassengerState.COMPLETED, "exiting rider should complete at the stop")
	_expect(waiting_passenger.state == SimulationTypes.PassengerState.RIDING, "waiting passenger should ride after capacity is freed")


func _test_stop_reoffers_excess_capacity_demand() -> void:
	var manager := HallRequestManager.new(10)
	var controller := _new_controller(5, SimulationTypes.Direction.UP, 1)
	controller.capacity = 1
	var first := _passenger(5, 8, 0.0)
	var second := _passenger(5, 9, 0.0)
	var request = manager.register_waiting_passenger(first, 0.0)
	manager.register_waiting_passenger(second, 0.0)
	controller.assign_hall_request(request)

	_arrive_for_service(controller, 5)
	controller.process_stop(manager, 10.0)
	_expect(first.state == SimulationTypes.PassengerState.RIDING, "the first compatible passenger should board")
	_expect(second.state == SimulationTypes.PassengerState.WAITING, "excess passenger should become unassigned waiting demand")
	_expect(second.assigned_elevator_id == 0, "excess passenger should not remain assigned to the full car")
	_expect(request.is_active(), "partial boarding must keep the shared hall request active")
	_expect(request.assigned_elevator_id == 0, "partial boarding should reoffer the remaining hall request")
	_expect(request not in controller.assigned_hall_requests, "full car should release its incomplete pickup request")
	_expect(manager.get_unassigned_requests().has(request), "dispatcher should see remaining demand on its next pass")
	var dispatcher := _new_dispatcher()
	var available_controller := _new_controller(1, SimulationTypes.Direction.IDLE, 2)
	var controllers: Array[ElevatorController] = [controller, available_controller]
	dispatcher.assign_unassigned_requests(controllers, manager.get_unassigned_requests(), 11.0)
	_expect(request.assigned_elevator_id == 2, "reoffered partial demand should be assignable to another available car")


func _test_stop_deduplicates_boarded_destinations() -> void:
	var manager := HallRequestManager.new(10)
	var controller := _new_controller(5, SimulationTypes.Direction.UP, 1)
	var first := _passenger(5, 8, 0.0)
	var second := _passenger(5, 8, 0.0)
	var request = manager.register_waiting_passenger(first, 0.0)
	manager.register_waiting_passenger(second, 0.0)
	controller.assign_hall_request(request)

	_arrive_for_service(controller, 5)
	controller.process_stop(manager, 10.0)
	_expect(controller.passengers.size() == 2, "both compatible passengers should board when capacity permits")
	_expect(controller.destination_requests.size() == 1 and controller.destination_requests.has(8), "matching rider destinations should remain one physical stop")


func _test_stop_leaves_incompatible_direction_waiting() -> void:
	var manager := HallRequestManager.new(10)
	var controller := _new_controller(5, SimulationTypes.Direction.UP, 1)
	var down_passenger := _passenger(5, 2, 0.0)
	var request = manager.register_waiting_passenger(down_passenger, 0.0)
	controller.assign_hall_request(request)

	_arrive_for_service(controller, 5)
	controller.process_stop(manager, 10.0)
	_expect(controller.passengers.is_empty(), "UP service must not board a DOWN passenger")
	_expect(down_passenger.state == SimulationTypes.PassengerState.ASSIGNED, "incompatible passenger should remain assigned for a later reverse")
	_expect(request.is_active(), "incompatible hall request must remain active")


func _test_arrival_signal_is_emitted_once_per_stop_lifecycle() -> void:
	var manager := HallRequestManager.new(10)
	var controller := _new_controller(1, SimulationTypes.Direction.IDLE, 1)
	_arrival_signal_count = 0
	controller.elevator_arrived.connect(_record_elevator_arrival)

	controller.begin_moving_to(5)
	_arrive_for_service(controller, 5)
	controller.process_stop(manager, 10.0)
	_expect(_arrival_signal_count == 1, "arrive_at followed by process_stop must emit one arrival event")


## End-to-end, fixed-timestep specification for the request-driven simulation.
## This deliberately talks only to the public HallRequestManager,
## ElevatorDispatcher, and ElevatorController APIs. It is not a Main/UI test.
func _test_deterministic_two_car_collective_scenario() -> void:
	var manager := HallRequestManager.new(10)
	var dispatcher := _new_dispatcher()
	var elevator_a := _new_controller(1, SimulationTypes.Direction.IDLE, 1)
	var elevator_b := _new_controller(8, SimulationTypes.Direction.IDLE, 2)
	# Keep B available for P4's Floor 8 -> 3 trip while deliberately leaving
	# the two trips ending below Floor 3 to A. That creates a real UP-to-DOWN
	# turnaround after A clears its upward car calls.
	elevator_b.configure_strategy(3, 10, 8, ElevatorController.Behavior.NORMAL)
	var controllers: Array[ElevatorController] = [elevator_a, elevator_b]
	var passengers: Array[RushPassenger] = [
		_passenger(2, 7, 0.0), # P1
		_passenger(4, 9, 0.0), # P2
		_passenger(6, 1, 0.0), # P3
		_passenger(8, 3, 0.0), # P4
		_passenger(3, 10, 0.0), # P5
	]
	# An additional same-floor UP passenger proves consolidation in the complete
	# flow, rather than only in the focused HallRequestManager unit test.
	var shared_up_waiter := _passenger(2, 8, 0.0)
	passengers.append(shared_up_waiter)
	var turnaround_waiter := _passenger(5, 2, 0.0)
	passengers.append(turnaround_waiter)

	for passenger: RushPassenger in passengers:
		manager.register_waiting_passenger(passenger, 0.0)
	_expect(manager.get_active_requests().size() == 6, "two Floor 2 UP riders should consolidate into one of six active hall requests")
	var initial_floor_two_request := _find_request(manager, 2, SimulationTypes.Direction.UP)
	var floor_eight_down_request := _find_request(manager, 8, SimulationTypes.Direction.DOWN)
	dispatcher.assign_unassigned_requests(controllers, manager.get_unassigned_requests(), 0.0)
	_expect(floor_eight_down_request.assigned_elevator_id == elevator_b.elevator_id, "the dispatcher should give the Floor 8 DOWN call to the already-staged nearby elevator")

	var now := 0.0
	var max_load := 0
	var saw_upward_car_pass_down_call := false
	var saw_reversal := false
	var previous_directions := {
		elevator_a.elevator_id: elevator_a.service_direction,
		elevator_b.elevator_id: elevator_b.service_direction,
	}

	# Fixed 0.1 s logical ticks keep this scenario deterministic and ensure no
	# simulation transition is driven by visual timing or an animation callback.
	for step: int in 1800:
		dispatcher.assign_unassigned_requests(controllers, manager.get_unassigned_requests(), now)
		for controller: ElevatorController in controllers:
			if controller.movement_state == SimulationTypes.MovementState.MOVING:
				controller.advance_travel(0.1)
			elif controller.movement_state == SimulationTypes.MovementState.STOPPED:
				if controller.arrived_service_stop and controller.door_state == SimulationTypes.DoorState.CLOSED:
					controller.begin_service_dwell()
				elif controller.arrived_service_stop and controller.advance_service_dwell(0.1):
					var transfer_events: Dictionary = controller.process_stop(manager, now)
					for boarded: RushPassenger in transfer_events["boarded"]:
						if controller.service_direction == SimulationTypes.Direction.UP and boarded.requested_direction == SimulationTypes.Direction.DOWN:
							saw_upward_car_pass_down_call = true
				elif not controller.arrived_service_stop:
					controller.complete_stop()
			else:
				var next := controller.next_stop()
				if next == controller.current_floor and controller.target_is_service_stop:
					controller.arrive_at(next)
				elif next != 0:
					controller.begin_moving_to(next)

			max_load = maxi(max_load, controller.passengers.size())
			var previous_direction: int = previous_directions[controller.elevator_id]
			if previous_direction != SimulationTypes.Direction.IDLE \
				and controller.service_direction == -previous_direction:
				saw_reversal = true
			previous_directions[controller.elevator_id] = controller.service_direction

		now += 0.1
		if _all_completed(passengers):
			break

	_expect(initial_floor_two_request.waiting_passengers.is_empty(), "the consolidated Floor 2 UP request should clear only after both riders board")
	_expect(_all_completed(passengers), "all fixed-scenario passengers should complete within the bounded simulation time")
	_expect(max_load <= ElevatorController.CAPACITY, "the controller must never exceed its passenger capacity")
	_expect(not saw_upward_car_pass_down_call, "UP collection must not board a DOWN hall passenger en route")
	_expect(saw_reversal, "a controller should reverse only after its current-direction work is exhausted")
	_expect(elevator_a.destination_requests.is_empty() and elevator_b.destination_requests.is_empty(), "all boarded passenger destinations should be respected and cleared after dropoff")
	_expect(manager.get_active_requests().is_empty(), "completed passengers should leave no active hall demand")


func _all_completed(passengers: Array[RushPassenger]) -> bool:
	for passenger: RushPassenger in passengers:
		if passenger.state != SimulationTypes.PassengerState.COMPLETED:
			return false
	return true


func _find_request(manager: HallRequestManager, floor: int, direction: int) -> HallRequest:
	for request: HallRequest in manager.get_active_requests():
		if request.floor == floor and request.direction == direction:
			return request
	return null


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


func _arrive_for_service(controller, floor: int) -> void:
	controller.target_is_service_stop = true
	controller.arrive_at(floor)
	controller.begin_service_dwell()
	controller.advance_service_dwell(10.0)


func _record_request_completion(_request) -> void:
	_completed_request_count += 1


func _record_request_completed(_request) -> void:
	_request_completed_event_count += 1


func _record_elevator_arrival(_floor: int) -> void:
	_arrival_signal_count += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class _MissingController:
	var current_floor := 0
	var service_direction := SimulationTypes.Direction.IDLE

	func assign_hall_request(_request) -> void:
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
