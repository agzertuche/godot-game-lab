extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func run_tests() -> void:
	var suite = load("res://tests/test_service.gd").new()
	suite.run(self)
	print("V4: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
