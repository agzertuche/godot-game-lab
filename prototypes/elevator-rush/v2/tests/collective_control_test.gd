extends SceneTree

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")


func _init() -> void:
	_test_shared_simulation_enums()
	print("collective_control_test: PASS")
	quit(0)


func _test_shared_simulation_enums() -> void:
	_expect(SimulationTypes.Direction.DOWN == -1, "DOWN direction should be -1")
	_expect(SimulationTypes.Direction.IDLE == 0, "IDLE direction should be 0")
	_expect(SimulationTypes.Direction.UP == 1, "UP direction should be 1")
	_expect(SimulationTypes.PassengerState.COMPLETED == 5, "completed passenger state should be available")
	_expect(SimulationTypes.MovementState.STOPPED == 2, "stopped movement state should be available")
	_expect(SimulationTypes.DoorState.OPEN == 2, "open door state should be available")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
