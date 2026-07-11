extends SceneTree

## Small CI/local entry point for the lightweight MCP test suites.  It keeps
## flow/rules tests runnable without an open editor or an MCP connection:
##
##   godot --headless --path . --script res://tests/headless_runner.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var suites: Array = []
	var load_errors: Array[String] = []
	var dir := DirAccess.open("res://tests")
	if dir == null:
		push_error("Cannot open res://tests")
		quit(1)
		return
	for file_name in dir.get_files():
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
			continue
		var path := "res://tests/%s" % file_name
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null or not script.can_instantiate():
			load_errors.append(file_name)
			continue
		var suite = script.new()
		if suite is McpTestSuite:
			suites.append(suite)
		else:
			load_errors.append(file_name)
	suites.sort_custom(func(a: McpTestSuite, b: McpTestSuite) -> bool:
		return a.suite_name() < b.suite_name()
	)
	var runner := McpTestRunner.new()
	var result := runner.run_suites(suites, "", "", {}, true)
	if not load_errors.is_empty():
		result["load_errors"] = load_errors
	print("MCP_TEST_RESULT=" + JSON.stringify(result))
	quit(1 if int(result.get("failed", 0)) > 0 or not load_errors.is_empty() else 0)

