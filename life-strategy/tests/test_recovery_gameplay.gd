@tool
extends McpTestSuite

const Gameplay := preload("res://scripts/systems/RecoveryGameplayService.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Data := preload("res://scripts/GameData.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")


func suite_name() -> String:
	return "recovery_gameplay"


func test_prepare_consumes_frozen_effect_and_binds_the_correct_day() -> void:
	for condition in Gameplay.CONTRIBUTIONS:
		var record := _record(condition, 3)
		var prepared := Gameplay.prepare_day(record, 3)
		assert_true(prepared["valid"], str(prepared["errors"]))
		assert_eq(prepared["learning_state"]["study_modifier"], record["next_day_effect"]["study_modifier"])
		assert_eq(prepared["learning_state"]["opening_delta"], record["next_day_effect"]["opening_delta"])
		assert_false(Gameplay.prepare_day(record, 2)["valid"])
		assert_false(Gameplay.prepare_day(record, 0)["valid"])
		prepared["recovery_state"]["sleep_snapshot"]["energy"] = -999
		prepared["learning_state"]["opening_delta"]["energy"] = -999
		assert_true(Recovery.validate(record)["valid"])
	assert_true(Gameplay.prepare_day(Recovery.new_run(), 0)["valid"])
	assert_false(Gameplay.prepare_day(Recovery.new_run(), 1)["valid"])


func test_unavailable_corrupt_and_future_records_have_no_consumable_effect() -> void:
	var future := _record("rested")
	future["schema_version"] = 99
	var corrupt := _record("rested")
	corrupt["next_day_effect"]["study_modifier"] = 999
	for record in [null, {}, [], future, corrupt, Recovery.unavailable("invalid", "INVALID"), Recovery.unavailable("unsupported_version", "FUTURE"), Recovery.unavailable("legacy_unknown", "LEGACY_RECOVERY_NOT_RECORDED")]:
		var prepared := Gameplay.prepare_day(record, 1)
		assert_false(prepared["valid"])
		assert_eq(prepared["recovery_state"], null)
		assert_false(prepared["learning_state"].has("study_modifier"))
		assert_false(prepared["learning_state"].has("opening_delta"))
		var stability := Gameplay.calculate_stability(_stats(), 70, 7, 7, record)
		assert_false(stability["valid"])
		assert_eq(stability["stability"], null)


func test_stability_uses_four_r2_contributions_and_ignores_legacy_burden() -> void:
	# All other final-day terms sum to 55 with this controlled state.
	var expected := {"rested": 65, "steady": 62, "strained": 59, "depleted": 56}
	for condition in expected:
		var record := _record(condition, 6)
		for burden in [0, 24, 60, 100, 999]:
			var state := _stats()
			state["diet_burden"] = burden
			var result := Gameplay.calculate_stability(state, 70, 7, 7, record)
			assert_true(result["valid"])
			assert_eq(result["stability"], expected[condition])
		var no_burden := _stats()
		no_burden.erase("diet_burden")
		assert_eq(Gameplay.calculate_stability(no_burden, 70, 7, 7, record)["stability"], expected[condition])


func test_stability_keeps_rounding_clamping_penalties_and_final_day_budget() -> void:
	var record := _record("steady", 6)
	var state := _stats()
	assert_eq(Gameplay.calculate_stability(state, 73, 7, 7, record)["stability"], 62)
	state["balance"] = 0
	var final_broke: int = Gameplay.calculate_stability(state, 70, 7, 7, record)["stability"]
	var penultimate_broke: int = Gameplay.calculate_stability(state, 70, 6, 7, record)["stability"]
	state["balance"] = 120
	assert_eq(Gameplay.calculate_stability(state, 70, 7, 7, record)["stability"], final_broke)
	assert_gt(Gameplay.calculate_stability(state, 70, 6, 7, record)["stability"], penultimate_broke)
	state.merge({"energy": 0, "mood": 0, "stress": 100, "satiety": 0, "study_progress": 0, "balance": 0}, true)
	assert_eq(Gameplay.calculate_stability(state, 0, 6, 7, record)["stability"], 0)
	state.merge({"energy": 100, "mood": 100, "stress": 0, "satiety": 100, "study_progress": 100}, true)
	assert_eq(Gameplay.calculate_stability(state, 100, 7, 7, _record("rested", 6))["stability"], 100)


func test_invalid_gameplay_numbers_do_not_produce_a_stability_score() -> void:
	for value in [null, false, "60", -1, 101, 60.5, NAN, INF]:
		var state := _stats()
		state["energy"] = value
		assert_false(Gameplay.calculate_stability(state, 70, 7, 7, _record("steady"))["valid"])
	for value in [null, false, "70", -1, 101, NAN, INF]:
		assert_false(Gameplay.calculate_stability(_stats(), value, 7, 7, _record("steady"))["valid"])


func test_r2_ending_boundaries_ignore_recovery_and_old_burden_gates() -> void:
	var cases := [
		[15, 100, "collapsed"], [16, 49, "study_shortfall"], [24, 50, "collapsed"],
		[25, 50, "barely_survived"], [60, 69, "barely_survived"],
		[59, 70, "barely_survived"], [60, 70, "stable_endurance"],
	]
	for condition in Gameplay.CONTRIBUTIONS:
		for item in cases:
			var state := _stats()
			state["stability"] = item[0]
			state["study_progress"] = item[1]
			state["diet_burden"] = 100
			assert_eq(Resolver.select_ending(state, true), item[2])
			state.erase("diet_burden")
			assert_eq(Resolver.select_ending(state, true), item[2])
	# Both controllers now share the R2 boundary, even for legacy-shaped input.
	var legacy := _stats()
	legacy.merge({"stability": 60, "study_progress": 70, "diet_burden": 61}, true)
	assert_eq(Resolver.select_ending(legacy), "stable_endurance")


func test_day_opening_applies_recovery_then_event_then_one_clamp() -> void:
	var game := _game()
	var record := _record("rested", 4, {"energy": 100, "stress": 0})
	game.run_history.append({"day": 4, "recovery_state": record})
	game.state.merge({"energy": 100, "stress": 0, "mood": 99}, true)
	game.day = 5
	assert_true(game._start_day())
	assert_eq(game.state["stress"], 2, "-2 recovery +4 event must be clamped after both")
	assert_eq(game.state["energy"], 100)
	assert_eq(game.state["mood"], 100)
	assert_eq(game.current_event["id"], "mock_exam_notice")
	assert_eq(game.current_learning_state["id"], "clear_focus")
	assert_eq(game._effective_action("study")["study"], 14, "base8 + recovery3 + event3")


func test_start_day_retry_does_not_reset_actions_or_apply_any_opening_twice() -> void:
	var game := _game()
	game.run_history.append({"day": 4, "recovery_state": _record("rested", 4)})
	game.day = 5
	assert_true(game._start_day())
	game.phase = "breakfast_action"
	game._apply_action("study")
	var state := game.state.duplicate(true)
	var records := game.today_action_records.duplicate(true)
	var phase := game.phase
	game._start_day()
	game._start_day()
	assert_eq(game.state, state)
	assert_eq(game.today_action_records, records)
	assert_eq(game.phase, phase)


func test_next_day_uses_the_frozen_journal_not_mutable_pending_or_display() -> void:
	var game := _controlled_game()
	game.state["diet_burden"] = 95
	game._choose_sleep("sleep_early")
	var record: Dictionary = game.run_history[0]["recovery_state"].duplicate(true)
	var end := game.state.duplicate(true)
	game.pending_recovery_state = Recovery.unavailable("invalid", "INJECTED")
	game.pending_learning_state = {"id": "brain_fog", "study_modifier": -999, "opening_delta": {"energy": -999}}
	game._on_summary_advanced()
	assert_eq(game.day, 2)
	assert_eq(game.get_current_recovery_state(), record)
	assert_eq(game.state["energy"], mini(100, int(end["energy"]) + 3))
	game.current_learning_state["study_modifier"] = -999
	assert_eq(game._effective_action("study")["study"], 11)
	var state := game.state.duplicate(true)
	game._next_day()
	assert_eq(game.day, 2)
	assert_eq(game.state, state)


func test_missing_wrong_day_future_and_corrupt_records_block_advancement() -> void:
	for kind in ["missing", "wrong_day", "future", "corrupt", "unknown"]:
		var game := _controlled_game()
		game._choose_sleep("sleep_early")
		var state := game.state.duplicate(true)
		match kind:
			"missing": game.run_history[0].erase("recovery_state")
			"wrong_day": game.run_history[0]["recovery_state"] = _record("rested", 2)
			"future": game.run_history[0]["recovery_state"]["schema_version"] = 99
			"corrupt": game.run_history[0]["recovery_state"]["next_day_effect"]["study_modifier"] = 999
			"unknown": game.run_history[0]["recovery_state"] = Recovery.unavailable("legacy_unknown", "LEGACY_RECOVERY_NOT_RECORDED")
		game._next_day()
		game._next_day()
		assert_eq(game.day, 1)
		assert_eq(game.phase, "summary")
		assert_eq(game.state, state)
		assert_eq(game.recovery_diagnostics.size(), 1)
		assert_eq(game.recovery_diagnostics[0]["code"], "recovery_opening_invalid")


func test_daytime_uses_previous_recovery_and_day_end_uses_new_recovery() -> void:
	var game := _controlled_game()
	game.current_recovery_state = _record("depleted")
	assert_true(game._update_stability())
	var tired_stability: int = game.state["stability"]
	game.current_recovery_state = _record("rested")
	assert_true(game._update_stability())
	assert_eq(game.state["stability"], int(tired_stability) + 9)
	game.current_recovery_state = _record("depleted")
	game._choose_sleep("sleep_early")
	assert_eq(game.pending_recovery_state["condition"], "rested")
	var expected := Gameplay.calculate_stability(game.state, 86, 1, 7, game.pending_recovery_state)
	assert_eq(game.state["stability"], expected["stability"])


func test_invalid_day_settlement_cannot_trigger_an_ending_or_neutral_next_day() -> void:
	var game := _controlled_game()
	game.day = 7
	game.state["stability"] = 100
	game._finish_day() # Missing actual sleep snapshot must stay invalid.
	assert_eq(game.phase, "summary")
	assert_eq(game.ending_id, "")
	assert_false(game.pending_learning_state.has("study_modifier"))
	assert_false(game.pending_learning_state.has("opening_delta"))
	game._on_summary_advanced()
	assert_eq(game.day, 7)


func test_new_day_end_recovery_prevents_a_stale_low_stability_collapse() -> void:
	var game := _controlled_game()
	game.current_recovery_state = _record("depleted")
	game.low_stability_days = 1
	game.state.merge({"energy": 52, "stress": 40, "mood": 0, "satiety": 30, "study_progress": 0}, true)
	for meal in game.today_meal_records:
		meal["quality"] = 25
	game._choose_sleep("sleep_early")
	assert_eq(game.pending_recovery_state["condition"], "rested")
	assert_gt(game.state["stability"], 15)
	assert_eq(game.low_stability_days, 0)
	assert_eq(game.phase, "summary")


func test_all_four_endings_are_reached_through_real_sleep_and_day_settlement() -> void:
	for ending in ["stable_endurance", "study_shortfall", "barely_survived", "collapsed"]:
		var game := _controlled_game()
		game.day = 7
		var sleep_id := "sleep_early"
		match ending:
			"study_shortfall": game.state["study_progress"] = 0
			"barely_survived": game.state["study_progress"] = 55
			"collapsed":
				game.state.merge({"energy": 0, "stress": 98, "mood": 0, "satiety": 0}, true)
				sleep_id = "night_study"
		game._choose_sleep(sleep_id)
		assert_eq(game.phase, "ending")
		assert_eq(game.ending_id, ending)
		assert_eq(game.run_history.size(), 1)
		assert_true(Recovery.validate(game.pending_recovery_state)["valid"])


func test_reopening_real_new_day_popup_does_not_reapply_opening_effects() -> void:
	var game := GameScene.instantiate() as GameRootV2
	track(game)
	game.health_history_path = ""
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	_fill_meals(game)
	game.phase = "sleep"
	game._choose_sleep("sleep_early")
	game._on_summary_advanced()
	var state := game.state.duplicate(true)
	var history := game.run_history.duplicate(true)
	game._show_new_day_popup()
	game._show_new_day_popup()
	game._on_new_day_continue()
	game._on_new_day_continue()
	assert_eq(game.state, state)
	assert_eq(game.run_history, history)


func test_restart_resets_the_applied_day_and_current_frozen_effect() -> void:
	var game := _controlled_game()
	game._choose_sleep("sleep_early")
	game._on_summary_advanced()
	assert_eq(game._started_day, 2)
	game.start_new_run()
	assert_eq(game._started_day, 1)
	assert_eq(game.get_current_recovery_state()["origin"], "new_run_default")
	assert_eq(game._current_recovery_effect, {"study_modifier": 0, "opening_delta": {}})
	assert_eq(game.state, Data.get_starting_stats())
	assert_true(game.run_history.is_empty())


func _record(condition: String, day: int = 1, end: Dictionary = {}) -> Dictionary:
	var sleep_id: String = {"rested": "sleep_early", "steady": "scroll_phone", "strained": "night_study", "depleted": "scroll_phone"}[condition]
	var sleep_card := Data.get_sleep_option(sleep_id)
	var snapshot := {"id": sleep_id}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		snapshot[key] = sleep_card[key]
	var target: Dictionary = {"rested": {"energy": 70, "stress": 40}, "steady": {"energy": 50, "stress": 40}, "strained": {"energy": 60, "stress": 40}, "depleted": {"energy": 10, "stress": 95}}[condition]
	if not end.is_empty():
		target = end
	var before := {"energy": clampi(int(target["energy"]) - int(snapshot["energy"]), 0, 100), "stress": clampi(int(target["stress"]) - int(snapshot["stress"]), 0, 100)}
	var result := Recovery.settle(day, before, snapshot, {})
	return result["recovery_state"]


func _stats() -> Dictionary:
	return {"energy": 60, "mood": 60, "stress": 40, "satiety": 50, "study_progress": 70, "balance": 120}


func _game() -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game._deck_service = Deck.new(20260711)
	game.start_new_run()
	return game


func _controlled_game() -> GameRootV2:
	var game := _game()
	game.state.merge({"balance": 120, "energy": 60, "mood": 60, "stress": 40, "satiety": 50, "diet_burden": 50, "study_progress": 70}, true)
	_fill_meals(game)
	game.phase = "sleep"
	return game


func _fill_meals(game: GameRootV2) -> void:
	game.today_meal_records.clear()
	for phase in ["breakfast", "lunch", "dinner"]:
		var foods: Array[Dictionary] = [Data.get_food("rice_plain"), Data.get_food("egg"), Data.get_food("tomato")]
		game.today_meal_records.append(Resolver.build_record(phase, Data.get_meal_source("cafeteria"), foods))
