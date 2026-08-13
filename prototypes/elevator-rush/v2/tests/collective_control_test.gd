extends SceneTree

const SimulationTypes := preload("res://scripts/simulation/simulation_types.gd")
const RushPassenger := preload("res://scripts/passenger.gd")
const HallRequestManager := preload("res://scripts/simulation/hall_request_manager.gd")

var _failures: Array[String] = []
var _completed_request_count := 0


func _init() -> void:
	_test_shared_simulation_enums()
	_test_matching_floor_and_direction_share_one_hall_request()
	_test_opposite_directions_create_separate_hall_requests()
	_test_impossible_boundary_requests_are_rejected()
	_test_request_remains_active_until_last_passenger_leaves()
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


func _test_matching_floor_and_direction_share_one_hall_request() -> void:
	var manager := HallRequestManager.new(10)
	var first := _passenger(5, 8, 4.0)
	var second := _passenger(5, 9, 7.0)

	var first_request = manager.register_waiting_passenger(first, 12.0)
	var second_request = manager.register_waiting_passenger(second, 14.0)

	_expect(first_request != null, "a valid passenger should create a hall request")
	_expect(first_request == second_request, "Floor 5 UP passengers should share one request")
	_expect(manager.get_active_requests().size() == 1, "matching demand should be consolidated")
	_expect(first_request.waiting_passengers.size() == 2, "shared request should hold both passengers")
	_expect(first_request.created_at == 12.0, "request creation should use simulation time")


func _test_opposite_directions_create_separate_hall_requests() -> void:
	var manager := HallRequestManager.new(10)
	var up_request = manager.register_waiting_passenger(_passenger(5, 8, 1.0), 1.0)
	var down_request = manager.register_waiting_passenger(_passenger(5, 2, 2.0), 2.0)

	_expect(up_request != null and down_request != null, "valid opposite calls should create requests")
	_expect(up_request != down_request, "Floor 5 UP and DOWN must remain separate requests")
	_expect(manager.get_active_requests().size() == 2, "opposite demand should produce two requests")


func _test_impossible_boundary_requests_are_rejected() -> void:
	var manager := HallRequestManager.new(10)
	var invalid_bottom := _passenger(1, 0, 1.0)
	var invalid_top := _passenger(10, 11, 1.0)

	_expect(manager.register_waiting_passenger(invalid_bottom, 1.0) == null, "Floor 1 DOWN should be rejected")
	_expect(manager.register_waiting_passenger(invalid_top, 1.0) == null, "Floor 10 UP should be rejected")
	_expect(manager.get_active_requests().is_empty(), "invalid boundary calls must not become active demand")


func _test_request_remains_active_until_last_passenger_leaves() -> void:
	var manager := HallRequestManager.new(10)
	var first := _passenger(5, 8, 1.0)
	var second := _passenger(5, 9, 2.0)
	manager.hall_request_completed.connect(_record_request_completion)
	_completed_request_count = 0

	manager.register_waiting_passenger(first, 3.0)
	manager.register_waiting_passenger(second, 3.0)
	manager.remove_passenger_from_request(first)

	_expect(manager.get_active_requests().size() == 1, "a partially boarded call must remain active")
	_expect(_completed_request_count == 0, "partial removal must not complete a hall request")
	manager.remove_passenger_from_request(second)
	_expect(manager.get_active_requests().is_empty(), "the final passenger removal should clear the request")
	_expect(_completed_request_count == 1, "final removal should emit hall_request_completed once")


func _passenger(origin: int, destination: int, request_time: float) -> RushPassenger:
	var passenger := RushPassenger.new()
	passenger.configure(origin, destination, request_time)
	return passenger


func _record_request_completion(_request) -> void:
	_completed_request_count += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
