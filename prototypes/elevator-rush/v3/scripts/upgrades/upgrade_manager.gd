class_name ElevatorUpgradeManager
extends RefCounted

const UpgradeDefinition := preload("res://scripts/upgrades/upgrade_definition.gd")

## The pool intentionally has no rarity, rerolls, levels, shop, or persistent
## unlocks. One unique upgrade is retained after each cleared stage.
const OFFER_SIZE := 3

const DEFAULT_TRAVEL_SPEED_MULTIPLIER := 1.0
const DEFAULT_CAPACITY_BONUS := 0
const DEFAULT_DOOR_DWELL_MULTIPLIER := 1.0
const DEFAULT_PATIENCE_MULTIPLIER := 1.0
const DEFAULT_TRANSFER_TIME_MULTIPLIER := 1.0
const DEFAULT_INTERMEDIATE_STOP_PENALTY_MULTIPLIER := 1.0

var offer_seed: int
var build: Array[ElevatorUpgradeDefinition] = []
var current_offer: Array[ElevatorUpgradeDefinition] = []
var travel_speed_multiplier := DEFAULT_TRAVEL_SPEED_MULTIPLIER
var capacity_bonus := DEFAULT_CAPACITY_BONUS
var door_dwell_multiplier := DEFAULT_DOOR_DWELL_MULTIPLIER
var patience_multiplier := DEFAULT_PATIENCE_MULTIPLIER
var lobby_parking_enabled := false
var direction_match_bonus := 0.0
var express_service_enabled := false
var waiting_time_priority_multiplier := 1.0
var traffic_preview_unlocked := false
var transfer_time_multiplier := DEFAULT_TRANSFER_TIME_MULTIPLIER
var intermediate_stop_penalty_multiplier := DEFAULT_INTERMEDIATE_STOP_PENALTY_MULTIPLIER
var wide_service_enabled := false


func _init(seed: int = 20260817) -> void:
	offer_seed = seed


func definitions() -> Array[ElevatorUpgradeDefinition]:
	return [
		UpgradeDefinition.new("motor_tune", "Motor Tune", "+30% elevator travel speed.", {"travel_speed_multiplier": 1.3}),
		UpgradeDefinition.new("cabin_expansion", "Cabin Expansion", "+1 passenger capacity in every cabin.", {"capacity_bonus": 1}),
		UpgradeDefinition.new("door_actuators", "Door Actuators", "Doors spend 35% less time open.", {"door_dwell_multiplier": 0.65}),
		UpgradeDefinition.new("patient_crowd", "Patient Crowd", "Passengers tolerate 35% longer waits.", {"patience_multiplier": 1.35}),
		UpgradeDefinition.new("lobby_parking", "Lobby Parking", "Idle elevators stage at Floor 1.", {"lobby_parking": true}),
		UpgradeDefinition.new("directional_bias", "Directional Bias", "Favor cars already moving in the requested direction.", {"direction_match_bonus": 4.0}),
		UpgradeDefinition.new("express_service", "Express Service", "Loaded cars prioritize cabin destinations and defer hall pickups until empty.", {"express_service": true}),
		UpgradeDefinition.new("priority_routing", "Priority Routing", "Much stronger priority for old hall requests.", {"waiting_time_priority_multiplier": 2.5}),
		UpgradeDefinition.new("traffic_preview", "Traffic Preview", "Reveal the next traffic stage before it begins.", {"traffic_preview": true}),
		UpgradeDefinition.new("quick_boarding", "Quick Boarding", "Passengers transfer 45% faster at stops.", {"transfer_time_multiplier": 0.55}),
		UpgradeDefinition.new("dispatch_relay", "Dispatch Relay", "Reduce the cost of intermediate stops.", {"intermediate_stop_penalty_multiplier": 0.5}),
		UpgradeDefinition.new("wide_service", "Wide Service", "Every car serves all floors unlocked by the stage.", {"wide_service": true}),
	]


func create_offer(stage_number: int) -> Array[ElevatorUpgradeDefinition]:
	var candidates := _available_definitions()
	var rng := RandomNumberGenerator.new()
	rng.seed = offer_seed + stage_number * 7919
	for index: int in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: ElevatorUpgradeDefinition = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary
	current_offer.clear()
	for definition: ElevatorUpgradeDefinition in candidates:
		if current_offer.size() >= OFFER_SIZE:
			break
		current_offer.append(definition)
	return current_offer.duplicate()


func choose_upgrade(upgrade_id: String) -> ElevatorUpgradeDefinition:
	for definition: ElevatorUpgradeDefinition in current_offer:
		if definition.id == upgrade_id:
			build.append(definition)
			current_offer.clear()
			return definition
	return null


## Interprets data definitions in one place. RunManager only owns phase flow;
## controller and dispatcher tuning is applied by this run-scoped build.
func apply_selected_upgrade(definition: ElevatorUpgradeDefinition) -> void:
	var effect := definition.effect
	if effect.has("travel_speed_multiplier"):
		travel_speed_multiplier *= float(effect["travel_speed_multiplier"])
	if effect.has("capacity_bonus"):
		capacity_bonus += int(effect["capacity_bonus"])
	if effect.has("door_dwell_multiplier"):
		door_dwell_multiplier *= float(effect["door_dwell_multiplier"])
	if effect.has("patience_multiplier"):
		patience_multiplier *= float(effect["patience_multiplier"])
	if effect.has("lobby_parking"):
		lobby_parking_enabled = bool(effect["lobby_parking"])
	if effect.has("direction_match_bonus"):
		direction_match_bonus += float(effect["direction_match_bonus"])
	if effect.has("express_service"):
		express_service_enabled = bool(effect["express_service"])
	if effect.has("waiting_time_priority_multiplier"):
		waiting_time_priority_multiplier *= float(effect["waiting_time_priority_multiplier"])
	if effect.has("traffic_preview"):
		traffic_preview_unlocked = bool(effect["traffic_preview"])
	if effect.has("transfer_time_multiplier"):
		transfer_time_multiplier *= float(effect["transfer_time_multiplier"])
	if effect.has("intermediate_stop_penalty_multiplier"):
		intermediate_stop_penalty_multiplier *= float(effect["intermediate_stop_penalty_multiplier"])
	if effect.has("wide_service"):
		wide_service_enabled = bool(effect["wide_service"])


func reset_build() -> void:
	build.clear()
	current_offer.clear()
	travel_speed_multiplier = DEFAULT_TRAVEL_SPEED_MULTIPLIER
	capacity_bonus = DEFAULT_CAPACITY_BONUS
	door_dwell_multiplier = DEFAULT_DOOR_DWELL_MULTIPLIER
	patience_multiplier = DEFAULT_PATIENCE_MULTIPLIER
	lobby_parking_enabled = false
	direction_match_bonus = 0.0
	express_service_enabled = false
	waiting_time_priority_multiplier = 1.0
	traffic_preview_unlocked = false
	transfer_time_multiplier = DEFAULT_TRANSFER_TIME_MULTIPLIER
	intermediate_stop_penalty_multiplier = DEFAULT_INTERMEDIATE_STOP_PENALTY_MULTIPLIER
	wide_service_enabled = false


func configure_controller_for_stage(
	controller: ElevatorController,
	elevator_index: int,
	floor_count: int,
) -> void:
	var service_min := 1
	var service_max := floor_count
	# Keep the introductory three-floor stage broadly serviceable. Later stages
	# establish the baseline coverage tradeoff that Wide Service removes.
	if not wide_service_enabled and floor_count >= 4:
		var midpoint := maxi(2, ceili(float(floor_count) / 2.0))
		if elevator_index == 0:
			service_max = midpoint
		elif elevator_index == 2:
			service_min = midpoint
	controller.configure_service(service_min, service_max, controller.staging_floor)
	controller.set_travel_speed_multiplier(travel_speed_multiplier)
	controller.set_capacity_bonus(capacity_bonus)
	controller.set_door_dwell_multiplier(door_dwell_multiplier)
	controller.set_transfer_time_multiplier(transfer_time_multiplier)
	controller.set_express_service_enabled(express_service_enabled)
	if lobby_parking_enabled:
		controller.set_idle_staging_floor(1)


func configure_dispatcher(dispatcher: ElevatorDispatcher) -> void:
	dispatcher.set_direction_match_bonus(direction_match_bonus)
	dispatcher.set_waiting_time_priority_multiplier(waiting_time_priority_multiplier)
	dispatcher.set_intermediate_stop_penalty_multiplier(intermediate_stop_penalty_multiplier)


func failure_wait_limit(base_wait_limit: float) -> float:
	return base_wait_limit * patience_multiplier


func has_upgrade(upgrade_id: String) -> bool:
	for definition: ElevatorUpgradeDefinition in build:
		if definition.id == upgrade_id:
			return true
	return false


func _available_definitions() -> Array[ElevatorUpgradeDefinition]:
	var available: Array[ElevatorUpgradeDefinition] = []
	for definition: ElevatorUpgradeDefinition in definitions():
		if not has_upgrade(definition.id):
			available.append(definition)
	return available
