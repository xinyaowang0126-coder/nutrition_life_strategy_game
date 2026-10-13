@tool
extends McpTestSuite

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Data := preload("res://scripts/GameData.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Migration := preload("res://scripts/systems/RecoveryStateMigration.gd")


class DriftController:
	extends "res://scripts/ui_v2/GameRootV2.gd"

	func _apply_day_settlement_effect(source_id: String, delta: Dictionary) -> void:
		super._apply_day_settlement_effect(source_id, delta)
		if source_id == "study_on_pace":
			state["energy"] = int(state["energy"]) + 1


func suite_name() -> String:
	return "recovery_flow"


func test_new_run_has_explicit_neutral_record_and_no_sleep_history() -> void:
	var game := _game()
	var record := game.get_pending_recovery_state()
	assert_true(Recovery.validate(record)["valid"])
	assert_eq(record["origin"], "new_run_default")
	assert_eq(record["condition"], "steady")
	assert_eq(record["evaluated_day"], null)
	assert_eq(record["sleep_snapshot"], null)
	assert_true(game.run_history.is_empty())
	assert_true(game.recovery_diagnostics.is_empty())


func test_three_live_sleep_choices_freeze_actual_trace_and_r2_result() -> void:
	var expected := {
		"sleep_early": {"after": {"energy": 82, "stress": 32}, "end": {"energy": 82, "stress": 32}, "condition": "rested"},
		"night_study": {"after": {"energy": 66, "stress": 46}, "end": {"energy": 66, "stress": 46}, "condition": "strained"},
		"scroll_phone": {"after": {"energy": 72, "stress": 37}, "end": {"energy": 72, "stress": 37}, "condition": "steady"},
	}
	for sleep_id in expected:
		var game := _controlled_game()
		game._choose_sleep(sleep_id)
		var record := game.get_pending_recovery_state()
		assert_true(Recovery.validate(record)["valid"], str(game.recovery_diagnostics))
		assert_eq(record["evaluated_day"], 1)
		assert_eq(record["before_sleep"], {"energy": 60, "stress": 40})
		assert_eq(record["after_sleep"], expected[sleep_id]["after"])
		assert_eq(record["end_of_day"], expected[sleep_id]["end"])
		assert_eq(record["condition"], expected[sleep_id]["condition"])
		assert_eq(record["sleep_snapshot"]["id"], sleep_id)
		assert_eq(record["sleep_snapshot"].size(), 6)
		assert_eq(record["inputs"].size(), 4)
		assert_false(record["sleep_snapshot"].has("burden"))
		assert_eq(record["end_of_day"], {"energy": game.state["energy"], "stress": game.state["stress"]})
		assert_eq(game.run_history[0]["recovery_state"], record)
		assert_true(game.recovery_diagnostics.is_empty())


func test_late_clamp_and_non_sleep_effects_keep_their_provenance() -> void:
	var game := _controlled_game()
	game.state.merge({"energy": 95, "stress": 5, "satiety": 5, "balance": 0, "study_progress": 0}, true)
	game._choose_sleep("sleep_early")
	var record := game.get_pending_recovery_state()
	assert_true(Recovery.validate(record)["valid"])
	assert_eq(record["after_sleep"], {"energy": 117, "stress": -3})
	assert_eq(record["end_of_day"], {"energy": 100, "stress": 13})
	assert_eq(record["clamp_delta"], {"energy": -9, "stress": 0})
	var sources: Array[String] = []
	for effect in record["settlement_effects"]:
		sources.append(effect["source_id"])
		assert_false(effect["requested_delta"].has("diet_burden"))
		assert_false(effect["requested_delta"].has("quality"))
	assert_eq(sources, ["low_satiety", "tight_budget", "study_behind"])
	assert_eq(record["settlement_effects"][0]["requested_delta"], {"energy": -8, "mood": -5, "stress": 8})
	assert_eq(record["settlement_effects"].back()["requested_delta"], {"stress": 3})


func test_negative_energy_and_high_stress_are_clamped_only_at_day_end() -> void:
	var game := _controlled_game(20)
	game.state.merge({"energy": 5, "stress": 98}, true)
	game._choose_sleep("night_study")
	var record := game.get_pending_recovery_state()
	assert_true(Recovery.validate(record)["valid"])
	assert_eq(record["after_sleep"], {"energy": 11, "stress": 104})
	assert_eq(record["end_of_day"], {"energy": 11, "stress": 100})
	assert_eq(record["clamp_delta"], {"energy": 0, "stress": -4})
	assert_eq(record["condition"], "depleted")
	assert_false(record["settlement_effects"].any(func(effect: Dictionary) -> bool: return String(effect["source_id"]).begins_with("legacy_quality")))


func test_counts_include_only_executed_actions_and_exclude_night_study() -> void:
	var game := _controlled_game()
	game.phase = "breakfast_action"
	game.state["energy"] = 0
	game._apply_action("study")
	assert_true(game.today_action_records.is_empty())
	game._apply_action("unknown_action")
	game.state["energy"] = 80
	game._apply_action("study")
	game._apply_action("study") # Already left the action phase.
	game.phase = "lunch_action"
	game._apply_action("drink_water")
	game._skip_action()
	game.phase = "dinner_action"
	game._apply_action("drink_water")
	game._apply_action("drink_water")
	game._skip_action()
	game._choose_sleep("night_study")
	var record := game.get_pending_recovery_state()
	assert_true(Recovery.validate(record)["valid"])
	assert_eq(record["inputs"]["action_counts"], {"study": 1, "drink_water": 2})
	assert_eq(record["inputs"]["sleep_id"], "night_study")
	assert_false(record["inputs"]["action_counts"].has("night_study"))


func test_three_studies_cannot_be_hidden_by_early_sleep() -> void:
	var game := _controlled_game()
	game.state["energy"] = 95
	for action_phase in ["breakfast_action", "lunch_action", "dinner_action"]:
		game.phase = action_phase
		game._apply_action("study")
	game._choose_sleep("sleep_early")
	var record := game.get_pending_recovery_state()
	assert_eq(record["inputs"]["action_counts"], {"study": 3})
	assert_eq(record["condition"], "strained")
	assert_contains(record["matched_rule_ids"], "OVERWORKED")


func test_rainy_day_actions_use_their_executed_effects_before_sleep() -> void:
	var game := _controlled_game()
	game.day = 6
	game.run_history.append({"day": 5, "recovery_state": Recovery.settle(5, {"energy": 40, "stress": 50}, _sleep_snapshot("sleep_early"), {})["recovery_state"]})
	game._start_day()
	game.state.merge({"energy": 80, "stress": 40, "study_progress": 70}, true)
	_fill_meals(game)
	game.phase = "breakfast_action"
	game._apply_action("walk")
	assert_eq(game.today_action_records[0]["stat_delta"]["energy"], -4)
	assert_eq(game.today_action_records[0]["stat_delta"]["stress"], -7)
	game.phase = "lunch_action"
	game._apply_action("nap")
	game.phase = "dinner_action"
	game._skip_action()
	game._choose_sleep("scroll_phone")
	var record := game.get_pending_recovery_state()
	assert_true(Recovery.validate(record)["valid"])
	assert_eq(record["before_sleep"], {"energy": 66, "stress": 35})
	assert_eq(record["inputs"]["action_counts"], {"walk": 1, "nap": 1})
	assert_eq(record["end_of_day"], {"energy": 70, "stress": 40})


func test_duplicate_sleep_or_finish_does_not_settle_any_effect_twice() -> void:
	var game := _controlled_game()
	game._choose_sleep("sleep_early")
	var state := game.state.duplicate(true)
	var history := game.run_history.duplicate(true)
	var pending := game.get_pending_recovery_state()
	var summary := game.summary_payload.duplicate(true)
	game._finish_day()
	game._choose_sleep("night_study")
	game.phase = "sleep" # Even stale callbacks with a restored phase are guarded.
	game._choose_sleep("scroll_phone")
	game._finish_day()
	assert_eq(game.state, state)
	assert_eq(game.run_history, history)
	assert_eq(game.get_pending_recovery_state(), pending)
	assert_eq(game.summary_payload, summary)
	assert_eq(game.chosen_sleep_id, "sleep_early")


func test_records_are_deep_copies_and_reset_between_days_and_runs() -> void:
	var game := _controlled_game()
	game._choose_sleep("sleep_early")
	var frozen: Dictionary = game.run_history[0]["recovery_state"].duplicate(true)
	var copy := game.get_pending_recovery_state()
	copy["sleep_snapshot"]["energy"] = -99
	game._recovery_sleep_snapshot["energy"] = -88
	game._day_settlement_effects[0]["requested_delta"]["energy"] = -77
	assert_eq(game.get_pending_recovery_state(), frozen)
	game._on_summary_advanced()
	assert_true(game._recovery_sleep_snapshot.is_empty())
	assert_true(game._day_settlement_effects.is_empty())
	assert_false(game._day_settled)
	assert_eq(game.run_history[0]["recovery_state"], frozen)
	_fill_meals(game)
	game.phase = "sleep"
	game._choose_sleep("scroll_phone")
	assert_eq(game.run_history.size(), 2)
	assert_eq(game.run_history[1]["recovery_state"]["evaluated_day"], 2)
	assert_eq(game.run_history[0]["recovery_state"], frozen)
	game.start_new_run()
	assert_true(game.run_history.is_empty())
	assert_eq(game.get_pending_recovery_state()["origin"], "new_run_default")
	assert_true(game.recovery_diagnostics.is_empty())
	assert_false(game._day_settled)


func test_missing_sleep_and_trace_drift_fail_closed_without_neutral_fallback() -> void:
	var missing := _controlled_game()
	missing._finish_day()
	_assert_invalid_record(missing)
	var drift := _game(false, true)
	_control(drift)
	drift._choose_sleep("sleep_early")
	_assert_invalid_record(drift)
	assert_eq(drift.get_pending_recovery_state()["reason_ids"], ["RECOVERY_TRACE_MISMATCH"])


func test_rejected_sleep_leaves_the_default_and_day_untouched() -> void:
	var game := _controlled_game()
	var state := game.state.duplicate(true)
	game._choose_sleep("unknown_sleep")
	assert_eq(game.state, state)
	assert_true(game.run_history.is_empty())
	assert_eq(game.get_pending_recovery_state()["evaluated_day"], null)
	assert_false(game._day_settled)


func test_health_flags_and_frozen_snapshots_are_independent_of_recovery() -> void:
	var enabled := _game(true)
	var disabled := _game()
	for game in [enabled, disabled]:
		for meal_phase in ["breakfast", "lunch", "dinner"]:
			game._choose_meal_source("cafeteria")
			game._confirm_food(["rice_plain", "egg", "tomato"])
			game._skip_action()
	var health_before := enabled.get_health_snapshots()
	assert_eq(health_before.size(), 3)
	for game in [enabled, disabled]:
		game._choose_sleep("sleep_early")
		assert_true(game.recovery_diagnostics.is_empty())
	assert_eq(enabled.state, disabled.state)
	assert_eq(enabled.get_pending_recovery_state(), disabled.get_pending_recovery_state())
	assert_eq(enabled.get_health_snapshots(), health_before)
	assert_true(disabled.get_health_snapshots().is_empty())
	for snapshot in enabled.get_health_snapshots():
		for key in ["recovery_state", "sleep_snapshot", "next_day_effect", "gameplay_state_version"]:
			assert_false(snapshot.has(key))


func test_c2_consumes_recovery_without_legacy_burden_and_serializes_only_the_record() -> void:
	var game := _controlled_game()
	# High legacy burden blocks the old boost, but is not an R2 input.
	game.state["diet_burden"] = 95
	game._choose_sleep("sleep_early")
	var record := game.get_pending_recovery_state()
	assert_eq(record["condition"], "rested")
	assert_eq(record["next_day_effect"]["study_modifier"], 3)
	assert_eq(game.pending_learning_state["id"], "clear_focus")
	var encoded := Migration.encode(record)
	assert_true(encoded["valid"])
	assert_eq(Migration.load_data(encoded["data"])["status"], "known")
	assert_false(game.run_history[0].has("gameplay_state_version"))
	assert_eq(Migration.load_data(game.run_history[0])["status"], "invalid")
	var end_state := game.state.duplicate(true)
	game._on_summary_advanced()
	assert_eq(game.current_learning_state["id"], "clear_focus")
	assert_eq(game.state["energy"], mini(100, int(end_state["energy"]) + 3))


func test_rebalanced_sleep_choices_keep_frozen_r2_records_and_separate_legacy_quality() -> void:
	var expected := {
		"sleep_early": [82, 64, 32, 70, 69, "clear_focus"],
		"night_study": [66, 60, 46, 80, 57, "fatigued"],
		"scroll_phone": [72, 66, 37, 70, 63, "steady"],
	}
	for sleep_id in expected:
		var game := _controlled_game()
		game._choose_sleep(sleep_id)
		var row: Array = expected[sleep_id]
		assert_eq(game.state["energy"], row[0])
		assert_eq(game.state["mood"], row[1])
		assert_eq(game.state["stress"], row[2])
		assert_eq(game.state["study_progress"], row[3])
		assert_eq(game.state["stability"], row[4])
		assert_eq(game.pending_learning_state["id"], row[5])
		assert_true(Recovery.validate(game.get_pending_recovery_state())["valid"])


func _game(data_enabled: bool = false, drift: bool = false) -> GameRootV2:
	var game: GameRootV2 = DriftController.new() if drift else Controller.new()
	track(game)
	game.health_guidance_flags = {"data": data_enabled, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game._deck_service = Deck.new(20260711)
	game.start_new_run()
	return game


func _controlled_game(quality: int = 86) -> GameRootV2:
	var game := _game()
	_control(game, quality)
	return game


func _control(game: GameRootV2, quality: int = 86) -> void:
	game.state.merge({"balance": 120, "energy": 60, "mood": 60, "stress": 40, "satiety": 50, "diet_burden": 50, "study_progress": 70}, true)
	_fill_meals(game, quality)
	game.phase = "sleep"


func _fill_meals(game: GameRootV2, quality: int = 86) -> void:
	game.today_meal_records.clear()
	for meal_phase in ["breakfast", "lunch", "dinner"]:
		var foods: Array[Dictionary] = [Data.get_food("rice_plain"), Data.get_food("egg"), Data.get_food("tomato")]
		var record := Resolver.build_record(meal_phase, Data.get_meal_source("cafeteria"), foods)
		record["quality"] = quality
		game.today_meal_records.append(record)


func _sleep_snapshot(id: String) -> Dictionary:
	var card := Data.get_sleep_option(id)
	var result := {"id": id}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		result[key] = card[key]
	return result


func _assert_invalid_record(game: GameRootV2) -> void:
	var record := game.get_pending_recovery_state()
	assert_eq(record["status"], "invalid")
	assert_eq(record["condition"], null)
	assert_eq(record["next_day_effect"], null)
	assert_false(Recovery.validate(record)["valid"])
	assert_false(Migration.encode(record)["valid"])
	assert_true(game.recovery_diagnostics.size() >= 1)
	assert_false(game.recovery_diagnostics[0]["errors"].is_empty())
