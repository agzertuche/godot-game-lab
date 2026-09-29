extends SceneTree

func _initialize() -> void:
	call_deferred("check_scene")

func check_scene() -> void:
	var scene := load("res://main.tscn")
	if scene == null:
		push_error("Main scene failed to load")
		quit(1)
		return
	var node: Node = scene.instantiate()
	root.add_child(node)
	await process_frame
	node.call("_start_wave")
	var model = node.get("run")
	if model.phase != 1:
		push_error("Start did not enter running phase")
		quit(1)
		return
	model.phase = 3
	node.call("_refresh")
	if bool(node.get("strategy_panel").visible) or node.get("offer_box").get_child_count() < 2:
		push_error("Upgrade section or strategy visibility is incorrect")
		quit(1)
		return
	node.call("_choose_upgrade", "motor")
	if String(node.get("pending_upgrade_id")) != "motor":
		push_error("Upgrade card did not select")
		quit(1)
		return
	node.call("_confirm_upgrade")
	if model.phase != 0 or not String(node.get("pending_upgrade_id")).is_empty():
		push_error("Upgrade confirmation did not advance to preparation")
		quit(1)
		return
	if node.get_node_or_null("MissingNode") != null:
		push_error("Unexpected node")
		quit(1)
		return
	print("V4 UI smoke: main scene instantiated")
	quit(0)
