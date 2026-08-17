class_name ElevatorUpgradeManager
extends RefCounted

const UpgradeDefinition := preload("res://scripts/upgrades/upgrade_definition.gd")

## The pool intentionally has no rarity, rerolls, levels, shop, or persistent
## unlocks. One unique upgrade is retained after each cleared stage.
const OFFER_SIZE := 3

var offer_seed: int
var build: Array[ElevatorUpgradeDefinition] = []
var current_offer: Array[ElevatorUpgradeDefinition] = []


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
		UpgradeDefinition.new("express_service", "Express Service", "Loaded cars skip hall calls until their riders are delivered.", {"express_service": true}),
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
