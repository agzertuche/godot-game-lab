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
const ElevatorUpgradeManager := preload("res://scripts/upgrades/upgrade_manager.gd")
const ElevatorUpgradeDefinition := preload("res://scripts/upgrades/upgrade_definition.gd")

var _failures: Array[String] = []
var _arrival_count := 0
var _doors_opened_count := 0
var _stage_started_count := 0
var _stage_completed_count := 0
var _stage_failed_count := 0
var _run_won_count := 0


func _init() -> void:
	_test_shared_up_request_is_assigned_and_completed()
	_test_autonomous_step_moves_dwells_and_delivers()
	_test_collective_control_skips_opposite_direction_call()
	_test_capacity_releases_remaining_shared_demand()
	_test_stage_one_starts_with_three_floors()
	_test_exact_default_stage_definitions()
	_test_successful_stage_enters_upgrade_choice()
	_test_upgrade_choice_prepares_stage_two()
	_test_final_stage_completion_wins_run()
	_test_backlog_failure_ends_run()
	_test_oldest_wait_failure_ends_run()
	_test_run_manager_emits_stage_and_failure_events()
	_test_demand_patterns_are_fixed_and_distinct()
	_test_upgrade_pool_has_twelve_typed_definitions()
	_test_upgrade_offers_are_seeded_and_unique()
	_test_upgrade_build_retains_exactly_one_choice()
	_test_upgrade_effects_change_named_simulation_tunables()

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


func _test_exact_default_stage_definitions() -> void:
	var definitions := ElevatorRunManager.default_stage_definitions()
	_expect(definitions.size() == 5, "the MVP must define exactly five traffic stages")
	_expect_stage_definition(definitions[0], 3, ElevatorStageDefinition.PATTERN_LOBBY_UP, 1101)
	_expect_stage_definition(definitions[1], 4, ElevatorStageDefinition.PATTERN_LOBBY_UP, 2202)
	_expect_stage_definition(definitions[2], 4, ElevatorStageDefinition.PATTERN_MIXED_RUSH, 3303)
	_expect_stage_definition(definitions[3], 5, ElevatorStageDefinition.PATTERN_UPPER_RETURN, 4404)
	_expect_stage_definition(definitions[4], 5, ElevatorStageDefinition.PATTERN_SPLIT_RETURN_STRESS, 5505)


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


func _test_upgrade_choice_prepares_stage_two() -> void:
	var definitions := _two_easy_stages()
	var run := ElevatorRunManager.new(definitions)
	run.start_run()
	_run_manager_until_not_running(run)
	_expect(run.phase == ElevatorRunManager.RunPhase.UPGRADE_CHOICE, "stage 1 should reach the upgrade placeholder before stage 2")
	var offer := run.current_upgrade_offer()
	_expect(offer.size() == 3, "a cleared stage should produce three upgrade choices")
	_expect(not run.prepare_next_stage(), "a stage cannot advance before exactly one upgrade is chosen")
	_expect(run.choose_upgrade(offer[0].id), "choosing one offered upgrade should prepare the next stage")
	_expect(run.phase == ElevatorRunManager.RunPhase.STAGE_INTRO, "stage 2 should enter the stage-intro phase before it begins")
	_expect(run.current_stage_definition().stage_number == 2, "prepare_next_stage should advance to stage 2")
	_expect(run.start_current_stage(), "the prepared stage should be able to start")
	_expect(run.phase == ElevatorRunManager.RunPhase.RUNNING, "starting the prepared stage should resume simulation")


func _test_final_stage_completion_wins_run() -> void:
	var final_stage := ElevatorStageDefinition.new(
		1, 3, 1, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 10, 60.0, 73,
	)
	var definitions: Array[ElevatorStageDefinition] = [final_stage]
	var run := ElevatorRunManager.new(definitions)
	run.start_run()
	_run_manager_until_not_running(run)
	_expect(run.phase == ElevatorRunManager.RunPhase.WON, "draining the final stage should win the run")


func _test_backlog_failure_ends_run() -> void:
	var stress_stage := ElevatorStageDefinition.new(
		1, 3, 3, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 0, 60.0, 81,
	)
	var definitions: Array[ElevatorStageDefinition] = [stress_stage]
	var run := ElevatorRunManager.new(definitions)
	run.start_run()
	run.tick(0.1)
	_expect(run.phase == ElevatorRunManager.RunPhase.FAILED, "a waiting backlog above the stage threshold should fail the run")


func _test_oldest_wait_failure_ends_run() -> void:
	var patience_stage := ElevatorStageDefinition.new(
		1, 3, 1, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 10, 0.05, 82,
	)
	var definitions: Array[ElevatorStageDefinition] = [patience_stage]
	var run := ElevatorRunManager.new(definitions)
	run.start_run()
	run.tick(0.1)
	run.tick(0.1)
	_expect(run.phase == ElevatorRunManager.RunPhase.FAILED, "an old active request should fail the run even below backlog capacity")


func _test_run_manager_emits_stage_and_failure_events() -> void:
	_stage_started_count = 0
	_stage_completed_count = 0
	_stage_failed_count = 0
	_run_won_count = 0
	var final_stage := ElevatorStageDefinition.new(
		1, 3, 1, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 10, 60.0, 83,
	)
	var success_run := ElevatorRunManager.new([final_stage])
	success_run.stage_started.connect(_record_stage_started)
	success_run.stage_completed.connect(_record_stage_completed)
	success_run.run_won.connect(_record_run_won)
	success_run.start_run()
	_run_manager_until_not_running(success_run)
	_expect(_stage_started_count == 1, "starting a stage should emit stage_started once")
	_expect(_stage_completed_count == 1, "draining a stage should emit stage_completed once")
	_expect(_run_won_count == 1, "the final stage should emit run_won once")

	var failure_stage := ElevatorStageDefinition.new(
		1, 3, 2, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 0, 60.0, 84,
	)
	var failed_run := ElevatorRunManager.new([failure_stage])
	failed_run.stage_failed.connect(_record_stage_failed)
	failed_run.start_run()
	failed_run.tick(0.1)
	_expect(_stage_failed_count == 1, "a threshold failure should emit stage_failed once")


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


func _test_upgrade_pool_has_twelve_typed_definitions() -> void:
	var manager := ElevatorUpgradeManager.new(100)
	var definitions := manager.definitions()
	_expect(definitions.size() == 12, "the MVP upgrade pool should contain exactly 12 definitions")
	var ids: Dictionary = {}
	for definition: ElevatorUpgradeDefinition in definitions:
		_expect(not definition.id.is_empty(), "each upgrade needs an id")
		_expect(not definition.title.is_empty(), "each upgrade needs a title")
		_expect(not definition.description.is_empty(), "each upgrade needs a description")
		_expect(not definition.effect.is_empty(), "each upgrade needs an effect payload")
		ids[definition.id] = true
	_expect(ids.size() == 12, "upgrade ids must be unique")
	_expect(ids.has("motor_tune") and ids.has("wide_service"), "the documented upgrade endpoints should exist")


func _test_upgrade_offers_are_seeded_and_unique() -> void:
	var first := ElevatorUpgradeManager.new(221)
	var replay := ElevatorUpgradeManager.new(221)
	var first_offer := first.create_offer(2)
	var replay_offer := replay.create_offer(2)
	_expect(first_offer.size() == 3, "each upgrade offer should contain exactly three choices")
	var offer_ids: Array[String] = []
	var replay_ids: Array[String] = []
	for definition: ElevatorUpgradeDefinition in first_offer:
		offer_ids.append(definition.id)
	for definition: ElevatorUpgradeDefinition in replay_offer:
		replay_ids.append(definition.id)
	_expect(offer_ids == replay_ids, "the same seed and stage should produce the same offer")
	var unique_ids: Dictionary = {}
	for upgrade_id: String in offer_ids:
		unique_ids[upgrade_id] = true
	_expect(unique_ids.size() == 3, "upgrade choices in an offer must be unique")


func _test_upgrade_build_retains_exactly_one_choice() -> void:
	var manager := ElevatorUpgradeManager.new(331)
	var offer := manager.create_offer(1)
	var chosen: ElevatorUpgradeDefinition = manager.choose_upgrade(offer[1].id)
	_expect(chosen != null, "an offered upgrade should be selectable")
	_expect(manager.build.size() == 1, "one upgrade choice should be retained in the build")
	_expect(manager.build[0].id == offer[1].id, "the selected upgrade should be retained")
	_expect(manager.current_offer.is_empty(), "selecting an upgrade should clear the current offer")
	_expect(manager.choose_upgrade(offer[0].id) == null, "only one choice may be applied from each offer")


func _test_upgrade_effects_change_named_simulation_tunables() -> void:
	var manager := ElevatorUpgradeManager.new(441)
	var definitions: Dictionary = {}
	for definition: ElevatorUpgradeDefinition in manager.definitions():
		definitions[definition.id] = definition

	var motor_run := _run_with_effect(definitions["motor_tune"])
	_expect(motor_run.controllers[0].travel_floors_per_second > ElevatorController.DEFAULT_TRAVEL_FLOORS_PER_SECOND, "Motor Tune should increase travel speed")
	var capacity_run := _run_with_effect(definitions["cabin_expansion"])
	_expect(capacity_run.controllers[0].capacity > ElevatorController.DEFAULT_CAPACITY, "Cabin Expansion should increase capacity")
	var doors_run := _run_with_effect(definitions["door_actuators"])
	_expect(doors_run.controllers[0].door_dwell_seconds < ElevatorController.DEFAULT_DOOR_DWELL_SECONDS, "Door Actuators should reduce door dwell")
	var patience_run := _run_with_effect(definitions["patient_crowd"])
	_expect(patience_run._patience_multiplier > 1.0, "Patient Crowd should increase the failure wait threshold")
	var lobby_run := _run_with_effect(definitions["lobby_parking"])
	_expect(lobby_run.controllers[2].staging_floor == 1, "Lobby Parking should stage every car at floor 1")
	var bias_run := _run_with_effect(definitions["directional_bias"])
	_expect(bias_run.dispatcher.direction_match_bonus > 0.0, "Directional Bias should adjust dispatcher matching cost")
	var express_run := _run_with_effect(definitions["express_service"])
	_expect(express_run.controllers[0].express_service_enabled, "Express Service should enable loaded-car hall-call skipping")
	var priority_run := _run_with_effect(definitions["priority_routing"])
	_expect(priority_run.dispatcher.waiting_time_priority > ElevatorDispatcher.WAITING_TIME_PRIORITY, "Priority Routing should strengthen request aging")
	var preview_run := _run_with_effect(definitions["traffic_preview"])
	_expect(preview_run.traffic_preview_unlocked, "Traffic Preview should unlock next-stage visibility")
	var boarding_run := _run_with_effect(definitions["quick_boarding"])
	_expect(boarding_run.controllers[0].transfer_seconds < ElevatorController.DEFAULT_TRANSFER_SECONDS, "Quick Boarding should shorten transfer time")
	var relay_run := _run_with_effect(definitions["dispatch_relay"])
	_expect(relay_run.dispatcher.intermediate_stop_penalty < ElevatorDispatcher.INTERMEDIATE_STOP_PENALTY, "Dispatch Relay should lower intermediate-stop penalty")
	var service_run := _run_with_effect(definitions["wide_service"])
	_expect(service_run._wide_service_enabled, "Wide Service should enable full unlocked-floor coverage")


func _run_with_effect(definition: ElevatorUpgradeDefinition) -> ElevatorRunManager:
	var stage := ElevatorStageDefinition.new(
		1, 3, 1, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 10, 60.0, 711,
	)
	var run := ElevatorRunManager.new([stage])
	run.current_stage_index = 0
	run._apply_upgrade_effect(definition)
	run._prepare_current_stage()
	return run


func _two_easy_stages() -> Array[ElevatorStageDefinition]:
	return [
		ElevatorStageDefinition.new(1, 3, 1, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 10, 60.0, 91),
		ElevatorStageDefinition.new(2, 4, 1, 0.0, ElevatorStageDefinition.PATTERN_LOBBY_UP, 10, 60.0, 92),
	]


func _run_manager_until_not_running(run: ElevatorRunManager) -> void:
	for _step: int in 80:
		run.tick(0.25)
		if run.phase != ElevatorRunManager.RunPhase.RUNNING:
			return


func _expect_stage_definition(
	definition: ElevatorStageDefinition,
	expected_floors: int,
	expected_pattern: String,
	expected_seed: int,
) -> void:
	_expect(definition.floor_count == expected_floors, "stage %d should use %d floors" % [definition.stage_number, expected_floors])
	_expect(definition.pattern == expected_pattern, "stage %d should use its defined demand pattern" % definition.stage_number)
	_expect(definition.seed == expected_seed, "stage %d should keep its fixed replay seed" % definition.stage_number)


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


func _record_stage_started(_definition: ElevatorStageDefinition) -> void:
	_stage_started_count += 1


func _record_stage_completed(_definition: ElevatorStageDefinition) -> void:
	_stage_completed_count += 1


func _record_stage_failed(_definition: ElevatorStageDefinition, _reason: String) -> void:
	_stage_failed_count += 1


func _record_run_won() -> void:
	_run_won_count += 1
