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
	var requested_suite := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			requested_suite = argument.trim_prefix("--suite=")
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
			if requested_suite.is_empty() or suite.suite_name() == requested_suite:
				suites.append(suite)
		else:
			load_errors.append(file_name)
	suites.sort_custom(func(a: McpTestSuite, b: McpTestSuite) -> bool:
		return a.suite_name() < b.suite_name()
	)
	if not requested_suite.is_empty() and suites.is_empty():
		push_error("Requested test suite does not exist: %s" % requested_suite)
		print("MCP_TEST_RESULT=" + JSON.stringify({
			"passed": 0,
			"failed": 1,
			"skipped": 0,
			"total": 0,
			"suite_count": 0,
			"requested_suite": requested_suite,
			"error": "requested_suite_not_found",
		}))
		quit(1)
		return
	var runner := McpTestRunner.new()
	var result := runner.run_suites(suites, "", "", {}, true)
	if not load_errors.is_empty():
		result["load_errors"] = load_errors
	if int(result.get("total", 0)) <= 0:
		result["error"] = "no_tests_executed"
	print("MCP_TEST_RESULT=" + JSON.stringify(result))
	quit(1 if (
		int(result.get("failed", 0)) > 0
		or int(result.get("total", 0)) <= 0
		or not load_errors.is_empty()
	) else 0)
