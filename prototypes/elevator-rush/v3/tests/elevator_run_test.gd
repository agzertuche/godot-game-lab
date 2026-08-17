extends SceneTree

## Headless deterministic acceptance test for the simulation-only foundation.
## Run with: godot --headless --path prototypes/elevator-rush/v3 -s res://tests/elevator_run_test.gd

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")
const ElevatorPassenger := preload("res://scripts/simulation/passenger.gd")
const HallRequestManager := preload("res://scripts/simulation/hall_request_manager.gd")
const ElevatorController := preload("res://scripts/simulation/elevator_controller.gd")
const ElevatorDispatcher := preload("res://scripts/simulation/elevator_dispatcher.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_shared_up_request_is_assigned_and_completed()
	_test_collective_control_skips_opposite_direction_call()
	_test_capacity_releases_remaining_shared_demand()

	if _failures.is_empty():
		print("elevator_run_test: PASS")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("elevator_run_test: FAIL (%d assertions)" % _failures.size())
	quit(1)


func _test_shared_up_request_is_assigned_and_completed() -> void:
	var manager := HallRequestManager.new(3)
	var dispatcher := ElevatorDispatcher.new()
	var elevator := ElevatorController.new(1, 1, 3)
	var passenger := ElevatorPassenger.new(1, 3, 0.0)
	var request = manager.register_waiting_passenger(passenger, 0.0)

	_expect(request != null, "a 1 -> 3 trip should create a hall request")
	_expect(request.direction == SimulationTypes.Direction.UP, "1 -> 3 should request UP")
	var controllers: Array[ElevatorController] = [elevator]
	dispatcher.assign_unassigned_requests(controllers, manager.get_active_requests(), 0.0)
	_expect(request.assigned_elevator_id == 1, "dispatcher should assign the hall request")

	_run_until_complete(elevator, manager, 0.0)
	_expect(passenger.state == SimulationTypes.PassengerState.COMPLETED, "passenger should finish after pickup and dropoff")
	_expect(passenger.destination_floor == 3, "destination should remain intact through ride")


func _test_collective_control_skips_opposite_direction_call() -> void:
	var manager := HallRequestManager.new(5)
	var dispatcher := ElevatorDispatcher.new()
	var elevator := ElevatorController.new(1, 1, 5)
	var up := ElevatorPassenger.new(2, 5, 0.0)
	var down := ElevatorPassenger.new(4, 1, 0.0)
	manager.register_waiting_passenger(up, 0.0)
	manager.register_waiting_passenger(down, 0.0)
	var controllers: Array[ElevatorController] = [elevator]
	dispatcher.assign_unassigned_requests(controllers, manager.get_active_requests(), 0.0)

	_expect(elevator.next_stop() == 2, "first assigned pickup should be floor 2")
	elevator.current_floor = 2
	elevator.process_current_floor(manager)
	_expect(elevator.next_stop() == 5, "UP car should deliver its rider before reversing for DOWN call")


func _test_capacity_releases_remaining_shared_demand() -> void:
	var manager := HallRequestManager.new(3)
	var dispatcher := ElevatorDispatcher.new()
	var elevator := ElevatorController.new(1, 1, 3)
	elevator.capacity = 1
	var first := ElevatorPassenger.new(1, 3, 0.0)
	var second := ElevatorPassenger.new(1, 2, 0.0)
	var request = manager.register_waiting_passenger(first, 0.0)
	manager.register_waiting_passenger(second, 0.0)
	var controllers: Array[ElevatorController] = [elevator]
	dispatcher.assign_unassigned_requests(controllers, manager.get_active_requests(), 0.0)
	elevator.process_current_floor(manager)

	_expect(elevator.passengers.size() == 1, "capacity should cap boarding")
	_expect(request.is_active(), "unboarded shared demand must stay active")
	_expect(request.assigned_elevator_id == 0, "remaining demand should be reoffered")


func _run_until_complete(
	elevator: ElevatorController,
	manager: HallRequestManager,
	_now: float,
) -> void:
	for _step: int in 20:
		if elevator.passengers.is_empty() and manager.get_active_requests().is_empty():
			return
		var stop := elevator.next_stop()
		if stop == 0:
			return
		elevator.current_floor = stop
		elevator.process_current_floor(manager)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
