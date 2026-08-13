extends SceneTree

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_shared_simulation_enums()
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
