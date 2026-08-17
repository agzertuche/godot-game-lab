class_name ElevatorStageDefinition
extends RefCounted

## Immutable description of one deterministic traffic challenge.
## Demand generation belongs to RunManager; this object only describes its rules.

const PATTERN_LOBBY_UP := "lobby_up"
const PATTERN_MIXED_RUSH := "mixed_rush"
const PATTERN_UPPER_RETURN := "upper_return"
const PATTERN_SPLIT_RETURN_STRESS := "split_return_stress"

var stage_number: int
var floor_count: int
var passenger_count: int
var spawn_duration: float
var pattern: String
var max_active_waiting: int
var max_oldest_wait_seconds: float
var seed: int


func _init(
	stage: int,
	floors: int,
	passengers_to_spawn: int,
	duration: float,
	demand_pattern: String,
	backlog_threshold: int,
	wait_threshold: float,
	deterministic_seed: int,
) -> void:
	stage_number = stage
	floor_count = floors
	passenger_count = passengers_to_spawn
	spawn_duration = duration
	pattern = demand_pattern
	max_active_waiting = backlog_threshold
	max_oldest_wait_seconds = wait_threshold
	seed = deterministic_seed
