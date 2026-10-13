@tool
extends McpTestSuite

const GameDataScript := preload("res://scripts/GameData.gd")
const GameRootV2Script := preload("res://scripts/ui_v2/GameRootV2.gd")
const MealDeckServiceScript := preload("res://scripts/systems/MealDeckService.gd")
const MealHealthSnapshotScript := preload("res://scripts/health/MealHealthSnapshot.gd")

var _test_directory := ""


func suite_name() -> String:
	return "health_snapshot_flow"


func suite_setup(_ctx: Dictionary) -> void:
	GameDataScript.ensure_loaded()


func setup() -> void:
	_test_directory = "res://.godot/health-snapshot-flow-%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_recursive_absolute(_test_directory), OK)


func teardown() -> void:
	var directory := DirAccess.open(_test_directory)
	if directory != null:
		for file_name in directory.get_files():
			DirAccess.remove_absolute(_test_directory.path_join(file_name))
		DirAccess.remove_absolute(_test_directory)


func test_disabled_data_keeps_records_and_disk_untouched() -> void:
	var game := _new_controller(false)
	game.health_profiles_path = _test_directory.path_join("absent-profiles.xml")
	game.health_history_path = _test_directory.path_join("must-not-exist.json")
	game._choose_meal_source("cafeteria")
	game._confirm_food(["rice_plain"])
	game._skip_action()
	game._skip_meal()
	assert_eq(game.today_meal_records.size(), 2)
	for record in game.today_meal_records:
		assert_false(record.has("health_snapshot"))
	assert_true(game.get_health_snapshots().is_empty())
	assert_false(game._health_catalog_loaded)
	assert_eq(game._health_archive, null)
	assert_false(FileAccess.file_exists(game.health_history_path))
	assert_false(bool(game.save_health_history(game.health_history_path)["ok"]))
	assert_false(bool(game.load_health_history(game.health_history_path)["ok"]))
	assert_false(FileAccess.file_exists(game.health_history_path))
	assert_true(game.health_history_diagnostics.is_empty())


func test_data_on_preserves_the_seven_day_gameplay_and_captures_twenty_one_meals() -> void:
	var enabled_game := _new_controller(true)
	var disabled_game := _new_controller(false)
	for day_index in range(1, 8):
		assert_eq(enabled_game.day, day_index)
		assert_eq(disabled_game.day, day_index)
		_play_affordable_study_day(enabled_game)
		_play_affordable_study_day(disabled_game)
		assert_eq(enabled_game.state, disabled_game.state)
		assert_eq(enabled_game.dorm_inventory, disabled_game.dorm_inventory)
		assert_eq(enabled_game.phase, disabled_game.phase)
		assert_eq(enabled_game.combos_today, disabled_game.combos_today)
		assert_eq(_without_snapshots(enabled_game.today_meal_records), disabled_game.today_meal_records)
		assert_eq(enabled_game.get_health_snapshots().size(), day_index * 3)
		if day_index < 7:
			enabled_game._on_summary_advanced()
			disabled_game._on_summary_advanced()
	assert_eq(enabled_game.phase, "ending")
	assert_eq(enabled_game.ending_id, disabled_game.ending_id)
	assert_eq(enabled_game.run_history.size(), 7)
	assert_eq(enabled_game.get_health_snapshots().size(), 21)
	assert_eq(disabled_game.get_health_snapshots().size(), 0)
	var snapshots := enabled_game.get_health_snapshots()
	for index in range(snapshots.size()):
		var snapshot: Dictionary = snapshots[index]
		assert_true(bool(MealHealthSnapshotScript.validate(snapshot)["valid"]))
		assert_eq(int(snapshot["day"]), int(index / 3) + 1)
		assert_eq(String(snapshot["phase"]), ["breakfast", "lunch", "dinner"][index % 3])


func test_only_successful_confirmations_and_skips_capture_once() -> void:
	var game := _new_controller(true)
	game._choose_meal_source("takeout")
	game._confirm_food(["rice_plain"])
	assert_true(game.get_health_snapshots().is_empty())
	game._choose_meal_source("cafeteria")
	game._confirm_food([])
	game._confirm_food(["not_a_food"])
	game.state["balance"] = 0
	game._confirm_food(["rice_plain"])
	assert_eq(game.phase, "breakfast")
	assert_true(game.get_health_snapshots().is_empty())
	assert_false(game._health_catalog_loaded, "rejected submissions must not load profiles")
	game.state["balance"] = 120
	game._confirm_food(["rice_plain"])
	game._confirm_food(["rice_plain"])
	game._skip_meal()
	assert_eq(game.phase, "breakfast_action")
	assert_eq(game.get_health_snapshots().size(), 1)
	game._skip_action()
	game._skip_meal()
	game._skip_meal()
	assert_eq(game.phase, "lunch_action")
	assert_eq(game.get_health_snapshots().size(), 2)
	assert_true(bool(game.today_meal_records[1]["skipped"]))
	assert_true(game.today_meal_records[1].has("health_snapshot"))
	assert_eq(game.today_meal_records[1]["health_snapshot"], game.get_health_snapshots()[1])
	assert_eq(String(game.get_health_snapshots()[1]["status"]), "skipped")


func test_snapshots_survive_day_changes_and_restart_clears_the_archive() -> void:
	var game := _new_controller(true)
	_play_affordable_study_day(game)
	var first_day := game.get_health_snapshots()
	game._on_summary_advanced()
	assert_eq(game.day, 2)
	assert_eq(game.today_meal_records.size(), 0)
	assert_eq(game.get_health_snapshots(), first_day)
	game._choose_meal_source("cafeteria")
	game._confirm_food(["rice_plain"])
	assert_eq(game.get_health_snapshots().size(), 4)
	var returned := game.get_health_snapshots()
	returned[0]["test_mutation"] = true
	assert_false(game.get_health_snapshots()[0].has("test_mutation"))
	game.today_meal_records[0]["health_snapshot"]["test_mutation"] = true
	assert_false(game.get_health_snapshots()[3].has("test_mutation"))
	game.start_new_run()
	assert_eq(game.day, 1)
	assert_eq(game.phase, "breakfast_source")
	assert_true(game.get_health_snapshots().is_empty())
	assert_false(game._health_catalog_loaded)
	assert_true(game.health_history_diagnostics.is_empty())


func test_missing_and_invalid_profiles_degrade_without_blocking_the_meal() -> void:
	for profile_path in [
		_test_directory.path_join("missing.xml"),
		"res://tests/fixtures/health_data_store/future_schema.xml",
		"res://tests/fixtures/health_data_store/normal.xml",
	]:
		var game := _new_controller(true)
		game.health_profiles_path = profile_path
		game._choose_meal_source("cafeteria")
		game._confirm_food(["rice_plain"])
		assert_eq(game.phase, "breakfast_action")
		assert_eq(game.get_health_snapshots().size(), 1)
		assert_true(game._health_catalog_loaded)
		assert_true(game._health_catalog.is_empty())
		assert_eq(game.health_history_diagnostics.size(), 1)
		assert_eq(String(game.health_history_diagnostics[0]["code"]), "health_catalog_unavailable")
		assert_eq(String(game.get_health_snapshots()[0]["data_status"]), "unavailable")
		var expected := MealHealthSnapshotScript.build(1, game.today_meal_records[0], {})
		assert_eq(game.get_health_snapshots()[0], expected)
		game._skip_action()
		game._skip_meal()
		assert_eq(game.get_health_snapshots().size(), 2)
		assert_eq(game.health_history_diagnostics.size(), 1, "bad profiles are diagnosed once per run")


func test_successful_meals_auto_save_and_explicit_load_does_not_restore_game_state() -> void:
	var game := _new_controller(true)
	var path := _test_directory.path_join("latest.json")
	game.health_history_path = path
	game._choose_meal_source("cafeteria")
	game._confirm_food(["rice_plain"])
	assert_true(FileAccess.file_exists(path))
	game._skip_action()
	game._skip_meal()
	var expected := game.get_health_snapshots()
	var reader := _new_controller(true)
	reader.health_history_path = path
	var initial_state := reader.state.duplicate(true)
	assert_true(reader.get_health_snapshots().is_empty(), "a new run never loads a previous archive")
	var loaded: Dictionary = reader.load_health_history(path)
	assert_true(bool(loaded["ok"]))
	assert_eq(loaded["snapshots"], expected)
	assert_true(reader.get_health_snapshots().is_empty(), "loading history must not mix old meals into this run")
	assert_eq(reader.state, initial_state)
	assert_eq(reader.day, 1)
	assert_eq(reader.phase, "breakfast_source")
	assert_true(reader.today_meal_records.is_empty())
	assert_false(reader._health_catalog_loaded, "loading old snapshots must not reload current profiles")
	reader._skip_meal()
	assert_eq(reader.get_health_snapshots().size(), 1)
	var second_path := _test_directory.path_join("explicit.json")
	assert_true(bool(reader.save_health_history(second_path)["ok"]))
	var second_reader := _new_controller(true)
	var second_loaded: Dictionary = second_reader.load_health_history(second_path)
	assert_true(bool(second_loaded["ok"]))
	assert_eq(second_loaded["snapshots"], reader.get_health_snapshots())
	reader.start_new_run()
	assert_true(reader.get_health_snapshots().is_empty())
	reader._skip_meal()
	var fresh_reader := _new_controller(true)
	var fresh_loaded: Dictionary = fresh_reader.load_health_history(path)
	assert_true(bool(fresh_loaded["ok"]))
	assert_eq(fresh_loaded["snapshots"].size(), 1, "a new run replaces the old disk archive")


func test_auto_save_failure_is_diagnostic_and_does_not_undo_the_meal() -> void:
	var game := _new_controller(true)
	game.health_history_path = _test_directory.path_join("uncreated/latest.json")
	game._choose_meal_source("cafeteria")
	game._confirm_food(["rice_plain"])
	assert_eq(game.phase, "breakfast_action")
	assert_eq(game.today_meal_records.size(), 1)
	assert_eq(game.get_health_snapshots().size(), 1)
	assert_eq(game.health_history_diagnostics.size(), 1)
	assert_eq(String(game.health_history_diagnostics[0]["code"]), "history_save_failed")
	assert_false(DirAccess.dir_exists_absolute(_test_directory.path_join("uncreated")))


func _new_controller(data_enabled: bool) -> GameRootV2:
	var game := GameRootV2Script.new() as GameRootV2
	track(game)
	game.health_guidance_flags = {"data": data_enabled}
	game.health_history_path = ""
	game._deck_service = MealDeckServiceScript.new(20260711)
	game.start_new_run()
	return game


func _without_snapshots(records: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = records.duplicate(true)
	for record in result:
		record.erase("health_snapshot")
	return result


func _play_affordable_study_day(game: GameRootV2) -> void:
	for meal in ["breakfast", "lunch", "dinner"]:
		assert_eq(game.phase, "%s_source" % meal)
		game._choose_meal_source("cafeteria")
		var preferred := ["rice_plain", "egg", "tomato", "mixed_grain_rice"] if meal == "breakfast" else ["rice_plain", "tofu", "greens", "tomato", "mixed_grain_rice"]
		var plate: Array[String] = []
		var cost := 0
		for food_id in preferred:
			if game.hand.has(food_id):
				var next_cost := int(GameDataScript.get_food(food_id)["cost"])
				if cost + next_cost <= int(game.state["balance"]):
					plate.append(food_id)
					cost += next_cost
			if plate.size() >= 2:
				break
		assert_false(plate.is_empty())
		game._confirm_food(plate)
		assert_eq(game.phase, "%s_action" % meal)
		game._apply_action({"breakfast": "study", "lunch": "walk", "dinner": "nap"}[meal])
	assert_eq(game.phase, "sleep")
	game._choose_sleep("sleep_early")
