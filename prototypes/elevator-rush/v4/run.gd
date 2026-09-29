class_name V4Run
extends RefCounted

enum Phase { PREPARATION, RUNNING, REPORT, UPGRADE, FAILED }
var root_seed := 1
var wave_number := 1
var phase := Phase.PREPARATION
var simulation := V4Simulation.new()
var wave_definition: Dictionary = {}
var elapsed := 0.0
var accumulator := 0.0
var schedule_index := 0
var last_report: Dictionary = {}
var misses := 0
var waves_cleared := 0
var base_capacity := 4
var build: Array[Dictionary] = []

func _init(seed_value: int = 1) -> void:
	root_seed = seed_value
	_prepare_wave()

func _prepare_wave() -> void:
	wave_definition = V4Waves.definition(root_seed, wave_number)
	simulation.configure(wave_definition.floors, 3)
	for car in simulation.cars:
		car.capacity = base_capacity
		car.active_strategy.max_floor = wave_definition.floors
		car.active_strategy.staging = 1
	for choice in build:
		V4Upgrades.apply(String(choice.id), int(choice.target), simulation)
	phase = Phase.PREPARATION
	elapsed = 0.0
	accumulator = 0.0
	schedule_index = 0

func start_wave() -> bool:
	if phase != Phase.PREPARATION:
		return false
	phase = Phase.RUNNING
	return true

func advance(real_delta: float) -> void:
	if phase != Phase.RUNNING:
		return
	elapsed += maxf(0.0, real_delta)
	while schedule_index < wave_definition.schedule.size() and float(wave_definition.schedule[schedule_index]["at"]) <= elapsed:
		var item: Dictionary = wave_definition.schedule[schedule_index]
		simulation.spawn(int(item.origin), int(item.destination))
		schedule_index += 1
	accumulator += maxf(0.0, real_delta)
	while accumulator >= V4Simulation.STEP_SECONDS:
		simulation.step()
		accumulator -= V4Simulation.STEP_SECONDS
		if simulation.failed:
			break
	if simulation.failed:
		misses = simulation.misses
		phase = Phase.FAILED
		return
	if schedule_index >= wave_definition.schedule.size() and simulation.is_drained():
		misses = simulation.misses
		last_report = V4Report.snapshot(simulation, wave_number)
		waves_cleared += 1
		phase = Phase.REPORT

func continue_report() -> void:
	if phase == Phase.REPORT:
		phase = Phase.UPGRADE

func confirm_upgrade(upgrade_id: String, target_id: int) -> bool:
	if phase != Phase.UPGRADE:
		return false
	build.append({"id": upgrade_id, "target": target_id})
	wave_number += 1
	_prepare_wave()
	return true

func retry_same_run() -> void:
	wave_number = 1
	waves_cleared = 0
	misses = 0
	build.clear()
	_prepare_wave()

func new_run(seed_value: int) -> void:
	root_seed = seed_value
	retry_same_run()
