extends Node
## Combined test runner — loads core/extended/integration tests in-process.

var passed := 0
var failed := 0
var exit_code := 0
var core_passed := [0]
var core_failed := [0]
var core_exit := [0]

func _ready() -> void:
	# Core + extended
	var core = load("res://tests/test_runner.gd").new()
	core.tree_exited.connect(func():
		if is_instance_valid(core):
			core_passed[0] = core.passed
			core_failed[0] = core.failed
			core_exit[0] = core.exit_code)
	add_child(core)

	await _wait_for_node(core)
	passed += core_passed[0]
	failed += core_failed[0]
	if core_exit[0] != 0:
		exit_code = core_exit[0]

	# Integration
	var integ_passed := [0]
	var integ_failed := [0]
	var integ_exit := [0]
	var integ = load("res://tests/test_integration.gd").new()
	integ.tree_exited.connect(func():
		if is_instance_valid(integ):
			integ_passed[0] = integ.passed
			integ_failed[0] = integ.failed
			integ_exit[0] = integ.exit_code)
	add_child(integ)
	await _wait_for_node(integ)
	passed += integ_passed[0]
	failed += integ_failed[0]
	if integ_exit[0] != 0:
		exit_code = integ_exit[0]

	print("\n═══════════════════════════════")
	print("TOTAL (core+extended+integration): %d passed, %d failed" % [passed, failed])
	print("═══════════════════════════════")
	get_tree().quit(exit_code)

func _wait_for_node(n: Node) -> void:
	# Wait up to 60s for the node to exit the tree (means it finished)
	var deadline := Time.get_ticks_msec() + 60000
	while is_instance_valid(n) and n.is_inside_tree():
		if Time.get_ticks_msec() > deadline:
			push_error("Node %s timeout" % n.name)
			break
		await get_tree().process_frame
	# Give a frame for tree_exited to fire
	await get_tree().process_frame

func _on_core_done(_c: Node) -> void:
	pass

func _on_integ_done(_i: Node) -> void:
	pass