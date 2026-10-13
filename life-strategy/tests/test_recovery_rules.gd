@tool
extends McpTestSuite

const RulesScript := preload("res://scripts/systems/RecoveryRules.gd")
const CardsScript := preload("res://scripts/CardDataStore.gd")


func suite_name() -> String:
	return "recovery_rules"


func test_declared_inputs_match_current_action_and_sleep_catalogs() -> void:
	CardsScript.ensure_loaded()
	assert_eq(RulesScript.ACTION_IDS.size(), CardsScript.action_ids.size())
	for action_id in CardsScript.action_ids:
		assert_contains(RulesScript.ACTION_IDS, action_id)
	assert_eq(RulesScript.SLEEP_IDS.size(), CardsScript.sleep_option_ids.size())
	for sleep_id in CardsScript.sleep_option_ids:
		assert_contains(RulesScript.SLEEP_IDS, sleep_id)
	assert_eq(RulesScript.RULES_VERSION, "recovery-gameplay-v1")
	assert_eq(RulesScript.SCHEMA_VERSION, 1)


func test_energy_and_stress_thresholds_at_nearby_integers() -> void:
	# Independently listed expected outcomes include every requested boundary.
	var cases := [
		[21, 40, "depleted"], [22, 40, "depleted"], [23, 40, "strained"],
		[34, 40, "strained"], [35, 40, "strained"], [41, 40, "strained"],
		[42, 40, "steady"], [57, 40, "steady"], [58, 40, "rested"],
		[60, 51, "rested"], [60, 52, "rested"], [60, 53, "steady"],
		[60, 65, "steady"], [60, 66, "strained"], [60, 74, "strained"],
		[60, 75, "strained"], [60, 81, "strained"], [60, 82, "depleted"],
		[0, 0, "depleted"], [100, 0, "rested"], [100, 100, "depleted"],
	]
	for sample in cases:
		_assert_condition(_input(sample[0], sample[1]), sample[2])


func test_early_sleep_requires_both_ready_thresholds_and_no_overwork() -> void:
	_assert_condition(_input(58, 52, "sleep_early", {"study": 2}), "rested")
	_assert_condition(_input(57, 52, "sleep_early", {"study": 2}), "steady")
	_assert_condition(_input(58, 53, "sleep_early", {"study": 2}), "steady")
	_assert_condition(_input(60, 40, "sleep_early", {"study": 3}), "strained")
	for recovery_action in ["nap", "walk", "allow_imperfection"]:
		_assert_condition(_input(60, 40, "sleep_early", {"study": 2, recovery_action: 1}), "rested")
	_assert_condition(_input(22, 40, "sleep_early", {"walk": 1}), "depleted")
	_assert_condition(_input(70, 82, "sleep_early", {"nap": 1}), "depleted")


func test_phone_is_explanation_only_and_uses_actual_end_state() -> void:
	var normal := RulesScript.evaluate(_input(60, 40, "scroll_phone"))
	assert_eq(normal["condition"], "steady")
	assert_contains(normal["reason_ids"], "PHONE_AT_NIGHT")
	assert_eq(normal["matched_rule_ids"], ["STEADY_FALLBACK"])
	assert_false(RulesScript.RULE_IDS.has("PHONE_AT_NIGHT"))
	_assert_condition(_input(41, 40, "scroll_phone"), "strained")
	_assert_condition(_input(60, 66, "scroll_phone"), "strained")
	_assert_condition(_input(22, 40, "scroll_phone"), "depleted")
	_assert_condition(_input(60, 82, "scroll_phone"), "depleted")


func test_sleep_ids_remain_distinct_without_reapplying_sleep_deltas() -> void:
	_assert_condition(_input(60, 40, "sleep_early"), "rested")
	_assert_condition(_input(60, 40, "night_study"), "strained")
	_assert_condition(_input(60, 40, "scroll_phone"), "steady")
	# An early-sleep input of 23 is already the post-settlement value.
	_assert_condition(_input(23, 40, "sleep_early"), "strained")


func test_compound_severe_rules_have_independent_boundaries() -> void:
	var cases := [
		[_input(34, 40, "night_study"), "depleted", "LATE_STUDY_LOW_ENERGY"],
		[_input(35, 40, "night_study"), "strained", "LATE_STUDY"],
		[_input(60, 74, "night_study"), "strained", "LATE_STUDY"],
		[_input(60, 75, "night_study"), "depleted", "LATE_STUDY_HIGH_STRESS"],
		[_input(34, 40, "sleep_early", {"study": 3}), "depleted", "OVERWORKED_LOW_ENERGY"],
		[_input(35, 40, "sleep_early", {"study": 3}), "strained", "OVERWORKED"],
		[_input(34, 74), "strained", "LOW_ENERGY"],
		[_input(34, 75), "depleted", "HIGH_STRESS_LOW_ENERGY"],
		[_input(35, 75), "strained", "HIGH_STRESS"],
	]
	for sample in cases:
		var result := RulesScript.evaluate(sample[0])
		assert_eq(result["condition"], sample[1])
		assert_contains(result["matched_rule_ids"], sample[2])


func test_reason_facts_are_complete_but_winning_rules_have_one_priority() -> void:
	var result := RulesScript.evaluate(_input(22, 82, "night_study", {"study": 3}))
	assert_eq(result["condition"], "depleted")
	assert_eq(result["matched_rule_ids"], [
		"LOW_ENERGY_SEVERE", "HIGH_STRESS_SEVERE", "LATE_STUDY_LOW_ENERGY",
		"LATE_STUDY_HIGH_STRESS", "OVERWORKED_LOW_ENERGY", "HIGH_STRESS_LOW_ENERGY",
	])
	for reason in ["LATE_STUDY", "LOW_ENERGY", "HIGH_STRESS", "OVERWORKED"]:
		assert_contains(result["reason_ids"], reason)
		assert_false((result["matched_rule_ids"] as Array).has(reason))
	for condition in RulesScript.CONDITIONS:
		for rule_id in RulesScript.RULE_IDS_BY_CONDITION[condition]:
			assert_contains(RulesScript.RULE_IDS, rule_id)
			assert_contains(RulesScript.REASON_IDS, rule_id)


func test_each_condition_freezes_expected_next_day_effect() -> void:
	var cases := [
		[_input(60, 40), "rested", 3, {"energy": 3, "mood": 1, "stress": -2}],
		[_input(50, 40), "steady", 0, {}],
		[_input(40, 40), "strained", -2, {"energy": -2, "stress": 2}],
		[_input(20, 40), "depleted", -4, {"energy": -3, "mood": -2, "stress": 3}],
	]
	for sample in cases:
		var result := RulesScript.evaluate(sample[0])
		assert_eq(result["condition"], sample[1])
		assert_eq(result["next_day_effect"], {"study_modifier": sample[2], "opening_delta": sample[3]})
		for rule_id in result["matched_rule_ids"]:
			assert_contains(RulesScript.RULE_IDS_BY_CONDITION[sample[1]], rule_id)
	assert_eq(RulesScript.effect_for("not_a_condition"), {})


func test_valid_sparse_actions_and_json_integer_numbers_are_normalized_copies() -> void:
	var original := _input(58.0, 52.0, "sleep_early", {"study": 2.0, "walk": 1.0})
	var normalized := RulesScript.normalize_inputs(original)
	assert_eq(typeof(normalized["energy"]), TYPE_INT)
	assert_eq(typeof(normalized["stress"]), TYPE_INT)
	assert_eq(typeof(normalized["action_counts"]["study"]), TYPE_INT)
	normalized["action_counts"]["study"] = 3
	assert_eq(original["action_counts"]["study"], 2.0)
	assert_eq(typeof(original["action_counts"]["study"]), TYPE_FLOAT)
	_assert_condition(original, "rested")
	_assert_condition(_input(60, 40, "sleep_early", {}), "rested")
	_assert_condition(_input(60, 40, "sleep_early", {"drink_water": 2, "restock_pantry": 1}), "rested")
	var parsed: Variant = JSON.parse_string(JSON.stringify(original))
	assert_eq(RulesScript.evaluate(parsed), RulesScript.evaluate(original))


func test_invalid_actions_limits_or_unperformed_metadata_never_coerce() -> void:
	var invalid_counts: Array = [
		null, [], "study", {"unknown": 1}, {"study": -1}, {"study": 1.5},
		{"study": true}, {"study": "2"}, {"study": 4}, {"drink_water": 3},
		{"restock_pantry": 2}, {"study": 3, "walk": 1},
		{"study": 3, "walk": 1, "drink_water": 2}, {"nap": INF}, {"study": NAN},
		{"study": 9007199254740991}, {1: 1}, {"completed": true},
	]
	for counts in invalid_counts:
		_assert_invalid(_input(60, 40, "sleep_early", counts))
	# A rejected/unfinished action is a collector concern, never a recognized ID.
	_assert_invalid(_input(60, 40, "sleep_early", {"skipped": 1}))


func test_missing_unknown_and_wrong_input_containers_are_invalid() -> void:
	for invalid in [null, [], "state", 1, true, {}]:
		_assert_invalid(invalid)
	for key in RulesScript.INPUT_KEYS:
		var missing := _input(60, 40)
		missing.erase(key)
		_assert_invalid(missing)
	for sleep_id in [null, "", "sleep", true, 1, ["sleep_early"]]:
		var invalid := _input(60, 40)
		invalid["sleep_id"] = sleep_id
		_assert_invalid(invalid)
	var unknown := _input(60, 40)
	unknown[1] = 0
	_assert_invalid(unknown)
	assert_eq(RulesScript.normalize_inputs({}), {})


func test_invalid_numeric_values_are_rejected_without_coercion() -> void:
	for key in ["energy", "stress"]:
		for invalid in [null, true, false, "60", 0.5, -1, 101, INF, -INF, NAN, {}, []]:
			var inputs := _input(60, 40)
			inputs[key] = invalid
			_assert_invalid(inputs)
	for valid in [0, -1, 100, 58.0, -2.0, 9007199254740991, -9007199254740991]:
		assert_true(RulesScript.is_integer(valid))
	for invalid in [null, true, "1", 0.1, INF, -INF, NAN, 9007199254740992, -9007199254740992, 9007199254740992.0]:
		assert_false(RulesScript.is_integer(invalid))


func test_nutrition_old_health_and_other_stats_are_outside_the_api() -> void:
	var inputs := _input(60, 40)
	var baseline := RulesScript.evaluate(inputs)
	for key in ["food_id", "profile", "nutrition_summary", "action_records", "quality", "burden", "diet_burden", "character_health", "mood", "satiety", "sleep_snapshot"]:
		var widened := inputs.duplicate(true)
		widened[key] = 0
		_assert_invalid(widened)
		widened[key] = {"high_sugar": true, "skipped_meals": 3}
		_assert_invalid(widened)
		widened.erase(key)
		assert_eq(RulesScript.evaluate(widened), baseline)


func test_evaluation_is_deterministic_and_results_have_no_shared_mutable_data() -> void:
	var inputs := _input(60, 40, "sleep_early", {"study": 2})
	var original := inputs.duplicate(true)
	var first := RulesScript.evaluate(inputs)
	var second := RulesScript.evaluate(inputs)
	assert_eq(first, second)
	assert_eq(inputs, original)
	first["next_day_effect"]["opening_delta"]["energy"] = 99
	(first["reason_ids"] as Array).clear()
	(first["matched_rule_ids"] as Array).clear()
	assert_eq(RulesScript.evaluate(inputs), second)
	var effect := RulesScript.effect_for("rested")
	effect["opening_delta"]["energy"] = -99
	assert_eq(RulesScript.effect_for("rested")["opening_delta"]["energy"], 3)


func _input(energy: Variant, stress: Variant, sleep_id: String = "sleep_early", counts: Variant = {}) -> Dictionary:
	return {"energy": energy, "stress": stress, "action_counts": counts, "sleep_id": sleep_id}


func _assert_condition(inputs: Dictionary, condition: String) -> void:
	var result := RulesScript.evaluate(inputs)
	assert_true(result["valid"], str(inputs))
	assert_eq(result["errors"], [])
	assert_eq(result["condition"], condition, str(inputs))
	assert_false((result["matched_rule_ids"] as Array).is_empty())


func _assert_invalid(inputs: Variant) -> void:
	var result := RulesScript.evaluate(inputs)
	assert_false(result["valid"], str(inputs))
	assert_false((result["errors"] as Array).is_empty())
	assert_eq(result["condition"], null)
	assert_eq(result["next_day_effect"], null)
	assert_eq(result["reason_ids"], [])
	assert_eq(result["matched_rule_ids"], [])
