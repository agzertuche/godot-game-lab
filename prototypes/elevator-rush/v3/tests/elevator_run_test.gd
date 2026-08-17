extends SceneTree

## Headless deterministic acceptance test for the simulation-only foundation.
## Run with: godot --headless --path prototypes/elevator-rush/v3 -s res://tests/elevator_run_test.gd

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")
const ElevatorPassenger := preload("res://scripts/simulation/passenger.gd")
const HallRequestManager := preload("res://scripts/simulation/hall_request_manager.gd")
const ElevatorController := preload("res://scripts/simulation/elevator_controller.gd")
const ElevatorDispatcher := preload("res://scripts/simulation/elevator_dispatcher.gd")
const ElevatorRunManager := preload("res://scripts/run/run_manager.gd")
const ElevatorStageDefinition := preload("res://scripts/run/stage_definition.gd")

var _failures: Array[String] = []
var _arrival_count := 0
var _doors_opened_count := 0


func _init() -> void:
	_test_shared_up_request_is_assigned_and_completed()
	_test_autonomous_step_moves_dwells_and_delivers()
	_test_collective_control_skips_opposite_direction_call()
	_test_capacity_releases_remaining_shared_demand()
	_test_stage_one_starts_with_three_floors()
	_test_successful_stage_enters_upgrade_choice()
	_test_backlog_failure_ends_run()
	_test_demand_patterns_are_fixed_and_distinct()

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


func _test_autonomous_step_moves_dwells_and_delivers() -> void:
	var manager := HallRequestManager.new(3)
	var dispatcher := ElevatorDispatcher.new()
	var elevator := ElevatorController.new(1, 1, 3)
	var passenger := ElevatorPassenger.new(1, 3, 0.0)
	manager.register_waiting_passenger(passenger, 0.0)
	var controllers: Array[ElevatorController] = [elevator]
	dispatcher.assign_unassigned_requests(controllers, manager.get_active_requests(), 0.0)
	_arrival_count = 0
	_doors_opened_count = 0
	elevator.elevator_arrived.connect(_record_arrival)
	elevator.doors_opened.connect(_record_doors_opened)

	for _step: int in 20:
		elevator.step(0.5, manager)
		if passenger.state == SimulationTypes.PassengerState.COMPLETED:
			break

	_expect(_arrival_count == 2, "autonomous step should arrive at pickup and destination")
	_expect(_doors_opened_count == 2, "each autonomous service stop should open logical doors")
	_expect(passenger.state == SimulationTypes.PassengerState.COMPLETED, "autonomous step should finish the full passenger trip")
	_expect(elevator.door_state == SimulationTypes.DoorState.CLOSED, "doors should close after logical dwell and transfer")


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


func _test_stage_one_starts_with_three_floors() -> void:
	var run := ElevatorRunManager.new()
	run.start_run()
	_expect(run.current_stage_definition().floor_count == 3, "stage 1 should use a three-floor building")
	_expect(run.controllers.size() == 3, "every stage should coordinate three independent controllers")
	_expect(run.phase == ElevatorRunManager.RunPhase.RUNNING, "starting a run should begin stage 1")


func _test_successful_stage_enters_upgrade_choice() -> void:
	var easy_stage := ElevatorStageDefinition.new(
		1, 3, 1, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 10, 60.0, 71,
	)
	var final_stage := ElevatorStageDefinition.new(
		2, 3, 1, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 10, 60.0, 72,
	)
	var definitions: Array[ElevatorStageDefinition] = [easy_stage, final_stage]
	var run := ElevatorRunManager.new(definitions)
	run.start_run()
	for _step: int in 80:
		run.tick(0.25)
		if run.phase != ElevatorRunManager.RunPhase.RUNNING:
			break
	_expect(run.phase == ElevatorRunManager.RunPhase.UPGRADE_CHOICE, "a drained non-final stage should offer an upgrade choice")


func _test_backlog_failure_ends_run() -> void:
	var stress_stage := ElevatorStageDefinition.new(
		1, 3, 3, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 0, 60.0, 81,
	)
	var definitions: Array[ElevatorStageDefinition] = [stress_stage]
	var run := ElevatorRunManager.new(definitions)
	run.start_run()
	run.tick(0.1)
	_expect(run.phase == ElevatorRunManager.RunPhase.FAILED, "a waiting backlog above the stage threshold should fail the run")


func _test_demand_patterns_are_fixed_and_distinct() -> void:
	var definitions := ElevatorRunManager.default_stage_definitions()
	var first_run := ElevatorRunManager.new(definitions)
	var replay_run := ElevatorRunManager.new(definitions)
	first_run.start_run()
	replay_run.start_run()
	var lobby_schedule := first_run.demand_schedule()
	_expect(lobby_schedule == replay_run.demand_schedule(), "a stage demand schedule should replay exactly from its seed")
	for entry: Dictionary in lobby_schedule:
		_expect(int(entry.origin_floor) == 1, "lobby-up traffic should originate at floor 1")

	var mixed_definition: ElevatorStageDefinition = definitions[2]
	var mixed_run := ElevatorRunManager.new([mixed_definition])
	mixed_run.start_run()
	var has_non_lobby_origin := false
	for entry: Dictionary in mixed_run.demand_schedule():
		if int(entry.origin_floor) != 1:
			has_non_lobby_origin = true
	_expect(has_non_lobby_origin, "mixed-rush traffic should differ from pure lobby-up demand")


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


func _record_arrival(_floor: int) -> void:
	_arrival_count += 1


func _record_doors_opened(_floor: int) -> void:
	_doors_opened_count += 1
