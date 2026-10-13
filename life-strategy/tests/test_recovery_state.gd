@tool
extends McpTestSuite

const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Data := preload("res://scripts/GameData.gd")
const HealthStore := preload("res://scripts/health/HealthDataStore.gd")
const HealthSnapshot := preload("res://scripts/health/MealHealthSnapshot.gd")


func suite_name() -> String:
	return "recovery_state"


func _sleep(id: String = "sleep_early") -> Dictionary:
	# Fixed historical deltas deliberately differ from the current XML.
	var card: Dictionary = {
		"sleep_early": {"energy": 26, "mood": 3, "stress": -9, "study": 0, "satiety": -12},
		"night_study": {"energy": -22, "mood": -5, "stress": 12, "study": 16, "satiety": -11},
		"scroll_phone": {"energy": -10, "mood": 8, "stress": -2, "study": 0, "satiety": -8},
	}[id]
	var snapshot := {"id": id}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		snapshot[key] = card[key]
	return snapshot


func _day() -> Dictionary:
	return Recovery.settle(
		1, {"energy": 40, "stress": 50}, _sleep(), {"study": 2, "walk": 1},
		[{"source_id": "legacy_quality_bonus", "requested_delta": {"energy": 4, "mood": 4}}]
	)["recovery_state"]


func test_new_run_is_neutral_explicit_and_independent() -> void:
	var first := Recovery.new_run()
	assert_true(Recovery.validate(first)["valid"])
	assert_eq(first["condition"], "steady")
	assert_eq(first["origin"], "new_run_default")
	assert_eq(first["evaluated_day"], null)
	assert_eq(first["sleep_snapshot"], null)
	assert_eq(first["next_day_effect"], {"study_modifier": 0, "opening_delta": {}})
	first["next_day_effect"]["opening_delta"]["energy"] = 40
	(first["reason_ids"] as Array).append("invented")
	assert_false(Recovery.validate(first)["valid"])
	assert_eq(Recovery.new_run()["next_day_effect"]["opening_delta"], {})
	assert_eq(Recovery.new_run()["reason_ids"], ["NEW_RUN_DEFAULT"])


func test_sleep_effects_and_late_clamp_have_separate_provenance() -> void:
	var effects := [{"source_id": "legacy_quality_bonus", "requested_delta": {"energy": 4}}]
	var result := Recovery.settle(2, {"energy": 95, "stress": 5}, _sleep(), {}, effects)
	assert_true(result["valid"], str(result["errors"]))
	var record: Dictionary = result["recovery_state"]
	assert_eq(record["after_sleep"], {"energy": 121, "stress": -4})
	assert_eq(record["end_of_day"], {"energy": 100, "stress": 0})
	assert_eq(record["clamp_delta"], {"energy": -25, "stress": 4})
	assert_eq(record["condition"], "rested")
	assert_true(Recovery.validate(record)["valid"], str(Recovery.validate(record)["errors"]))
	assert_eq(record["settlement_effects"], effects)


func test_phone_uses_actual_state_and_early_sleep_cannot_override_severe_state() -> void:
	var phone := Recovery.settle(1, {"energy": 70, "stress": 42}, _sleep("scroll_phone"), {"study": 2})
	assert_true(phone["valid"])
	assert_eq(phone["recovery_state"]["condition"], "steady")
	assert_contains(phone["recovery_state"]["reason_ids"], "PHONE_AT_NIGHT")
	assert_false(phone["recovery_state"]["matched_rule_ids"].has("PHONE_AT_NIGHT"))
	var tired := Recovery.settle(1, {"energy": 45, "stress": 42}, _sleep("scroll_phone"), {})
	assert_eq(tired["recovery_state"]["condition"], "strained")
	var early := Recovery.settle(1, {"energy": 0, "stress": 95}, _sleep(), {})
	assert_eq(early["recovery_state"]["condition"], "depleted")


func test_records_freeze_inputs_effects_and_outputs_without_shared_references() -> void:
	var before := {"energy": 40, "stress": 50}
	var sleep := _sleep()
	var counts := {"study": 2, "walk": 1}
	var effects := [{"source_id": "legacy_quality_bonus", "requested_delta": {"energy": 4}}]
	var original := [before.duplicate(true), sleep.duplicate(true), counts.duplicate(true), effects.duplicate(true)]
	var result := Recovery.settle(1, before, sleep, counts, effects)
	assert_eq([before, sleep, counts, effects], original)
	var record: Dictionary = result["recovery_state"]
	sleep["energy"] = -99
	counts["study"] = 0
	effects[0]["requested_delta"]["energy"] = -100
	before["energy"] = 0
	assert_eq(record["sleep_snapshot"]["energy"], 26)
	assert_eq(record["inputs"]["action_counts"]["study"], 2)
	assert_eq(record["end_of_day"]["energy"], 70)
	assert_true(Recovery.validate(record)["valid"])
	var copy := Recovery.normalize(record)
	copy["next_day_effect"]["opening_delta"]["energy"] = 99
	assert_eq(record["next_day_effect"]["opening_delta"]["energy"], 3)


func test_json_roundtrip_preserves_frozen_noncurrent_sleep_values() -> void:
	var sleep := _sleep()
	sleep["energy"] = 11
	var result := Recovery.settle(3, {"energy": 42, "stress": 50}, sleep, {})
	assert_true(result["valid"])
	var record: Dictionary = result["recovery_state"]
	assert_eq(record["condition"], "steady")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(record))
	assert_true(Recovery.validate(decoded)["valid"])
	var normalized := Recovery.normalize(decoded)
	assert_eq(normalized, record)
	assert_true(normalized["schema_version"] is int)
	assert_true(normalized["sleep_snapshot"]["energy"] is int)
	assert_eq(normalized["sleep_snapshot"]["energy"], 11, "must not reload current sleep XML")
	assert_eq(Data.get_sleep_option("sleep_early")["energy"], 22)


func test_trace_mismatches_and_invalid_outcome_are_rejected() -> void:
	var valid := _day()
	assert_true(Recovery.validate(valid)["valid"])
	for key in ["before_sleep", "after_sleep", "end_of_day", "clamp_delta"]:
		var record := valid.duplicate(true)
		record[key]["energy"] += 1
		assert_false(Recovery.validate(record)["valid"], key)
	var mismatched := valid.duplicate(true)
	mismatched["inputs"]["sleep_id"] = "scroll_phone"
	assert_false(Recovery.validate(mismatched)["valid"])
	for patch in [
		{"next_day_effect": {"study_modifier": true, "opening_delta": {}}},
		{"next_day_effect": {"study_modifier": 3, "opening_delta": {"energy": 3, "mood": 1, "stress": -2, "burden": -1}}},
		{"reason_ids": ["INVENTED"]}, {"reason_ids": ["PHONE_AT_NIGHT"]},
		{"matched_rule_ids": ["STEADY_FALLBACK"]},
		{"condition": "healthy"}, {"diet_burden": 0}, {"inputs": []},
		{"sleep_snapshot": null}, {"settlement_effects": [null]},
	]:
		var record := valid.duplicate(true)
		record.merge(patch, true)
		assert_false(Recovery.validate(record)["valid"], str(patch))
		assert_eq(Recovery.normalize(record), {})


func test_invalid_trace_input_never_becomes_normal_recovery() -> void:
	for day in [null, true, "1", 1.5, 0, 8, NAN, INF]:
		_assert_invalid(Recovery.settle(day, {"energy": 50, "stress": 50}, _sleep(), {}))
	for before in [null, [], {}, {"energy": 101, "stress": 0}, {"energy": false, "stress": 0}]:
		_assert_invalid(Recovery.settle(1, before, _sleep(), {}))
	for counts in [null, {"study": 3, "walk": 1}, {"drink_water": 3}]:
		_assert_invalid(Recovery.settle(1, {"energy": 50, "stress": 50}, _sleep(), counts))
	for effects in [null, {}, [null], [{"source_id": "legacy", "requested_delta": {"burden": -3}}]]:
		_assert_invalid(Recovery.settle(1, {"energy": 50, "stress": 50}, _sleep(), {}, effects))
	var sleep := _sleep()
	sleep["energy"] = 9007199254740991
	_assert_invalid(Recovery.settle(1, {"energy": 50, "stress": 50}, sleep, {}))


func test_legacy_unknown_carries_no_effect_and_invalid_status_is_unusable() -> void:
	var unknown := Recovery.unavailable("legacy_unknown", "LEGACY_RECOVERY_NOT_RECORDED")
	assert_true(Recovery.validate(unknown)["valid"])
	assert_eq(unknown["condition"], null)
	assert_eq(unknown["next_day_effect"], null)
	unknown["next_day_effect"] = {"study_modifier": 0, "opening_delta": {}}
	assert_false(Recovery.validate(unknown)["valid"], "unknown must not become consumable neutral")
	for status in ["invalid", "unsupported_version"]:
		var record := Recovery.unavailable(status, "NO_RECOVERY")
		assert_false(Recovery.validate(record)["valid"])
		assert_eq(record["next_day_effect"], null)
	assert_false(Recovery.validate(null)["valid"])
	assert_false(Recovery.validate([])["valid"])


func test_recovery_records_do_not_leak_into_health_snapshots() -> void:
	var catalog: Dictionary = HealthStore.new().load_catalog()
	var meal := {"phase": "lunch", "source_id": "takeout", "food_ids": ["fried_chicken", "bubble_tea"]}
	var original := HealthSnapshot.build(1, meal, catalog)
	assert_true(HealthSnapshot.validate(original)["valid"])
	assert_false(original["factor_snapshot"].is_empty())
	var frozen := original.duplicate(true)
	for sleep_id in ["sleep_early", "night_study", "scroll_phone"]:
		var result := Recovery.settle(1, {"energy": 60, "stress": 40}, _sleep(sleep_id), {"drink_water": 1, "walk": 1})
		assert_true(result["valid"])
		var enriched := meal.duplicate(true)
		enriched["recovery_state"] = result["recovery_state"]
		enriched["gameplay_state_version"] = 2
		assert_eq(HealthSnapshot.build(1, enriched, catalog), original)
		assert_eq(original, frozen)
	for key in ["recovery_state", "gameplay_state_version", "sleep_snapshot", "next_day_effect"]:
		var polluted := original.duplicate(true)
		polluted[key] = Recovery.new_run() if key == "recovery_state" else null
		assert_false(HealthSnapshot.validate(polluted)["valid"], key)


func _assert_invalid(result: Dictionary) -> void:
	assert_false(result["valid"])
	assert_false(result["errors"].is_empty())
	assert_eq(result["recovery_state"]["status"], "invalid")
	assert_eq(result["recovery_state"]["condition"], null)
	assert_eq(result["recovery_state"]["next_day_effect"], null)
