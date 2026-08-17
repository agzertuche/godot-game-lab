class_name ElevatorRunManager
extends RefCounted

const Passenger := preload("res://scripts/simulation/passenger.gd")
const HallRequestManager := preload("res://scripts/simulation/hall_request_manager.gd")
const ElevatorControllerScript := preload("res://scripts/simulation/elevator_controller.gd")
const ElevatorDispatcherScript := preload("res://scripts/simulation/elevator_dispatcher.gd")
const StageDefinition := preload("res://scripts/run/stage_definition.gd")
const UpgradeManagerScript := preload("res://scripts/upgrades/upgrade_manager.gd")

const DEFAULT_UPGRADE_SEED := 20260817

## Standalone coordinator for escalating traffic and run phases. A future Main
## node drives it through this public API; it has no Node or UI dependency and
## never chooses an individual elevator route or stop.
enum RunPhase {
	STAGE_INTRO,
	RUNNING,
	UPGRADE_CHOICE,
	FAILED,
	WON,
}

signal stage_started(definition: ElevatorStageDefinition)
signal stage_completed(definition: ElevatorStageDefinition)
signal stage_failed(definition: ElevatorStageDefinition, reason: String)
signal run_won()

var phase := RunPhase.STAGE_INTRO
var stage_definitions: Array[ElevatorStageDefinition] = []
var current_stage_index := -1
var simulation_time := 0.0
var stage_elapsed := 0.0
var request_manager: ElevatorHallRequestManager
var dispatcher: ElevatorDispatcher
var controllers: Array[ElevatorController] = []
var upgrade_manager: ElevatorUpgradeManager
var traffic_preview_unlocked := false

var _travel_speed_multiplier := 1.0
var _capacity_bonus := 0
var _door_dwell_multiplier := 1.0
var _patience_multiplier := 1.0
var _lobby_parking_enabled := false
var _direction_match_bonus := 0.0
var _express_service_enabled := false
var _waiting_time_priority_multiplier := 1.0
var _transfer_time_multiplier := 1.0
var _intermediate_stop_penalty_multiplier := 1.0
var _wide_service_enabled := false

var _demand_schedule: Array[Dictionary] = []
var _next_demand_index := 0
var _spawned_passengers: Array[ElevatorPassenger] = []


func _init(definitions: Array[ElevatorStageDefinition] = []) -> void:
	stage_definitions = definitions.duplicate() if not definitions.is_empty() else default_stage_definitions()
	upgrade_manager = UpgradeManagerScript.new(DEFAULT_UPGRADE_SEED)


static func default_stage_definitions() -> Array[ElevatorStageDefinition]:
	return [
		StageDefinition.new(1, 3, 9, 14.0, StageDefinition.PATTERN_LOBBY_UP, 6, 22.0, 1101),
		StageDefinition.new(2, 4, 15, 17.0, StageDefinition.PATTERN_LOBBY_UP, 8, 20.0, 2202),
		StageDefinition.new(3, 4, 21, 19.0, StageDefinition.PATTERN_MIXED_RUSH, 9, 18.0, 3303),
		StageDefinition.new(4, 5, 27, 22.0, StageDefinition.PATTERN_UPPER_RETURN, 10, 16.0, 4404),
		StageDefinition.new(5, 5, 34, 24.0, StageDefinition.PATTERN_SPLIT_RETURN_STRESS, 11, 14.0, 5505),
	]


func start_run() -> void:
	_reset_run_upgrades()
	current_stage_index = 0
	_prepare_current_stage()
	start_current_stage()


func prepare_next_stage() -> bool:
	if phase != RunPhase.UPGRADE_CHOICE:
		return false
	if not upgrade_manager.current_offer.is_empty():
		return false
	current_stage_index += 1
	if current_stage_index >= stage_definitions.size():
		phase = RunPhase.WON
		run_won.emit()
		return false
	_prepare_current_stage()
	return true


func current_upgrade_offer() -> Array[ElevatorUpgradeDefinition]:
	if phase != RunPhase.UPGRADE_CHOICE:
		return []
	return upgrade_manager.current_offer.duplicate()


## The only mutation point for the run build. It is intentionally unavailable
## while a stage is running.
func choose_upgrade(upgrade_id: String) -> bool:
	if phase != RunPhase.UPGRADE_CHOICE:
		return false
	var definition := upgrade_manager.choose_upgrade(upgrade_id)
	if definition == null:
		return false
	_apply_upgrade_effect(definition)
	return prepare_next_stage()


func next_stage_preview() -> ElevatorStageDefinition:
	if not traffic_preview_unlocked:
		return null
	var next_index := current_stage_index + 1
	if next_index < 0 or next_index >= stage_definitions.size():
		return null
	return stage_definitions[next_index]


func start_current_stage() -> bool:
	if phase != RunPhase.STAGE_INTRO or current_stage_definition() == null:
		return false
	phase = RunPhase.RUNNING
	stage_started.emit(current_stage_definition())
	return true


func current_stage_definition() -> ElevatorStageDefinition:
	if current_stage_index < 0 or current_stage_index >= stage_definitions.size():
		return null
	return stage_definitions[current_stage_index]


func demand_schedule() -> Array[Dictionary]:
	return _demand_schedule.duplicate(true)


func spawned_passenger_count() -> int:
	return _spawned_passengers.size()


func active_waiting_count() -> int:
	if request_manager == null:
		return 0
	var count := 0
	for request: ElevatorHallRequest in request_manager.get_active_requests():
		count += request.waiting_passengers.size()
	return count


func oldest_waiting_time() -> float:
	if request_manager == null:
		return 0.0
	var oldest := 0.0
	for request: ElevatorHallRequest in request_manager.get_active_requests():
		for passenger: ElevatorPassenger in request.waiting_passengers:
			oldest = maxf(oldest, passenger.waiting_time(simulation_time))
	return oldest


func tick(delta: float) -> void:
	if phase != RunPhase.RUNNING:
		return
	var step_delta := maxf(0.0, delta)
	simulation_time += step_delta
	stage_elapsed += step_delta
	_spawn_due_passengers()
	dispatcher.assign_unassigned_requests(controllers, request_manager.get_active_requests(), simulation_time)
	for controller: ElevatorController in controllers:
		controller.step(step_delta, request_manager)
	# Stop processing can reoffer a partially boarded request during this tick.
	dispatcher.assign_unassigned_requests(controllers, request_manager.get_active_requests(), simulation_time)
	if _has_failed_current_stage():
		_fail_current_stage()
		return
	if _is_current_stage_drained():
		_complete_current_stage()


func _prepare_current_stage() -> void:
	var definition := current_stage_definition()
	if definition == null:
		return
	phase = RunPhase.STAGE_INTRO
	simulation_time = 0.0
	stage_elapsed = 0.0
	_next_demand_index = 0
	_spawned_passengers.clear()
	_demand_schedule = _build_demand_schedule(definition)
	request_manager = HallRequestManager.new(definition.floor_count)
	dispatcher = ElevatorDispatcherScript.new()
	controllers.clear()
	for elevator_index: int in 3:
		var starting_floor := _starting_floor(elevator_index, definition.floor_count)
		var controller: ElevatorController = ElevatorControllerScript.new(elevator_index + 1, starting_floor, definition.floor_count)
		controller.configure_service(1, definition.floor_count, starting_floor)
		_apply_controller_tunables(controller, definition)
		controllers.append(controller)
	_apply_dispatcher_tunables()


func _starting_floor(elevator_index: int, floor_count: int) -> int:
	if elevator_index == 0:
		return 1
	if elevator_index == 1:
		return clampi(2, 1, floor_count)
	return floor_count


func _spawn_due_passengers() -> void:
	while _next_demand_index < _demand_schedule.size():
		var entry := _demand_schedule[_next_demand_index]
		if float(entry["at_time"]) > stage_elapsed:
			return
		var passenger: ElevatorPassenger = Passenger.new(
			int(entry["origin_floor"]),
			int(entry["destination_floor"]),
			simulation_time,
		)
		_spawned_passengers.append(passenger)
		request_manager.register_waiting_passenger(passenger, simulation_time)
		_next_demand_index += 1


func _is_current_stage_drained() -> bool:
	if _next_demand_index < _demand_schedule.size():
		return false
	if not request_manager.get_active_requests().is_empty():
		return false
	for controller: ElevatorController in controllers:
		if not controller.passengers.is_empty():
			return false
	return true


func _has_failed_current_stage() -> bool:
	var definition := current_stage_definition()
	if active_waiting_count() > definition.max_active_waiting:
		return true
	return oldest_waiting_time() > definition.max_oldest_wait_seconds * _patience_multiplier


func _fail_current_stage() -> void:
	var definition := current_stage_definition()
	var reason := "Backlog %d exceeded limit %d" % [active_waiting_count(), definition.max_active_waiting]
	var wait_limit := definition.max_oldest_wait_seconds * _patience_multiplier
	if oldest_waiting_time() > wait_limit:
		reason = "Oldest wait %.1fs exceeded limit %.1fs" % [oldest_waiting_time(), wait_limit]
	phase = RunPhase.FAILED
	stage_failed.emit(definition, reason)


func _complete_current_stage() -> void:
	var definition := current_stage_definition()
	stage_completed.emit(definition)
	if current_stage_index == stage_definitions.size() - 1:
		phase = RunPhase.WON
		run_won.emit()
		return
	upgrade_manager.create_offer(current_stage_definition().stage_number)
	phase = RunPhase.UPGRADE_CHOICE


func _build_demand_schedule(definition: ElevatorStageDefinition) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = definition.seed
	var schedule: Array[Dictionary] = []
	for passenger_index: int in definition.passenger_count:
		var progress := float(passenger_index) / float(maxi(1, definition.passenger_count - 1))
		var jitter := rng.randf_range(-0.15, 0.15)
		var at_time := clampf((progress + jitter) * definition.spawn_duration, 0.0, definition.spawn_duration)
		var trip := _trip_for_pattern(definition, passenger_index, rng)
		schedule.append({
			"at_time": at_time,
			"origin_floor": trip["origin_floor"],
			"destination_floor": trip["destination_floor"],
		})
	schedule.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if not is_equal_approx(float(left["at_time"]), float(right["at_time"])):
			return float(left["at_time"]) < float(right["at_time"])
		if int(left["origin_floor"]) != int(right["origin_floor"]):
			return int(left["origin_floor"]) < int(right["origin_floor"])
		return int(left["destination_floor"]) < int(right["destination_floor"])
	)
	return schedule


func _trip_for_pattern(definition: ElevatorStageDefinition, passenger_index: int, rng: RandomNumberGenerator) -> Dictionary:
	var top_floor := definition.floor_count
	match definition.pattern:
		StageDefinition.PATTERN_LOBBY_UP:
			return {"origin_floor": 1, "destination_floor": rng.randi_range(2, top_floor)}
		StageDefinition.PATTERN_MIXED_RUSH:
			if passenger_index % 3 != 2:
				return {"origin_floor": 1, "destination_floor": rng.randi_range(2, top_floor)}
			return _random_non_matching_trip(2, top_floor, rng)
		StageDefinition.PATTERN_UPPER_RETURN:
			return {"origin_floor": rng.randi_range(2, top_floor), "destination_floor": 1}
		StageDefinition.PATTERN_SPLIT_RETURN_STRESS:
			if passenger_index % 3 == 0:
				return {"origin_floor": 1, "destination_floor": top_floor}
			if passenger_index % 3 == 1:
				return {"origin_floor": top_floor, "destination_floor": 1}
			return _random_non_matching_trip(2, top_floor - 1, rng)
	return {"origin_floor": 1, "destination_floor": 2}


func _random_non_matching_trip(min_floor: int, max_floor: int, rng: RandomNumberGenerator) -> Dictionary:
	var origin := rng.randi_range(min_floor, max_floor)
	var destination := rng.randi_range(1, max_floor)
	while destination == origin:
		destination = rng.randi_range(1, max_floor)
	return {"origin_floor": origin, "destination_floor": destination}


func _reset_run_upgrades() -> void:
	upgrade_manager = UpgradeManagerScript.new(DEFAULT_UPGRADE_SEED)
	traffic_preview_unlocked = false
	_travel_speed_multiplier = 1.0
	_capacity_bonus = 0
	_door_dwell_multiplier = 1.0
	_patience_multiplier = 1.0
	_lobby_parking_enabled = false
	_direction_match_bonus = 0.0
	_express_service_enabled = false
	_waiting_time_priority_multiplier = 1.0
	_transfer_time_multiplier = 1.0
	_intermediate_stop_penalty_multiplier = 1.0
	_wide_service_enabled = false


func _apply_upgrade_effect(definition: ElevatorUpgradeDefinition) -> void:
	var effect := definition.effect
	if effect.has("travel_speed_multiplier"):
		_travel_speed_multiplier *= float(effect["travel_speed_multiplier"])
	if effect.has("capacity_bonus"):
		_capacity_bonus += int(effect["capacity_bonus"])
	if effect.has("door_dwell_multiplier"):
		_door_dwell_multiplier *= float(effect["door_dwell_multiplier"])
	if effect.has("patience_multiplier"):
		_patience_multiplier *= float(effect["patience_multiplier"])
	if effect.has("lobby_parking"):
		_lobby_parking_enabled = bool(effect["lobby_parking"])
	if effect.has("direction_match_bonus"):
		_direction_match_bonus += float(effect["direction_match_bonus"])
	if effect.has("express_service"):
		_express_service_enabled = bool(effect["express_service"])
	if effect.has("waiting_time_priority_multiplier"):
		_waiting_time_priority_multiplier *= float(effect["waiting_time_priority_multiplier"])
	if effect.has("traffic_preview"):
		traffic_preview_unlocked = bool(effect["traffic_preview"])
	if effect.has("transfer_time_multiplier"):
		_transfer_time_multiplier *= float(effect["transfer_time_multiplier"])
	if effect.has("intermediate_stop_penalty_multiplier"):
		_intermediate_stop_penalty_multiplier *= float(effect["intermediate_stop_penalty_multiplier"])
	if effect.has("wide_service"):
		_wide_service_enabled = bool(effect["wide_service"])


func _apply_controller_tunables(controller: ElevatorController, definition: ElevatorStageDefinition) -> void:
	controller.set_travel_speed_multiplier(_travel_speed_multiplier)
	controller.set_capacity_bonus(_capacity_bonus)
	controller.set_door_dwell_multiplier(_door_dwell_multiplier)
	controller.set_transfer_time_multiplier(_transfer_time_multiplier)
	controller.set_express_service_enabled(_express_service_enabled)
	if _lobby_parking_enabled:
		controller.set_idle_staging_floor(1)
	if _wide_service_enabled:
		controller.configure_service(1, definition.floor_count, controller.staging_floor)


func _apply_dispatcher_tunables() -> void:
	dispatcher.set_direction_match_bonus(_direction_match_bonus)
	dispatcher.set_waiting_time_priority_multiplier(_waiting_time_priority_multiplier)
	dispatcher.set_intermediate_stop_penalty_multiplier(_intermediate_stop_penalty_multiplier)
