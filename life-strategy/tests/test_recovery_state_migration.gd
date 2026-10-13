@tool
extends McpTestSuite

const MigrationScript := preload("res://scripts/systems/RecoveryStateMigration.gd")
const StateScript := preload("res://scripts/systems/RecoveryStateService.gd")


func suite_name() -> String:
	return "recovery_state_migration"


func test_new_run_round_trip_is_a_recovery_only_envelope() -> void:
	var original: Dictionary = StateScript.new_run()
	var encoded: Dictionary = MigrationScript.encode(original)
	assert_true(bool(encoded["valid"]), str(encoded))
	assert_true((encoded["errors"] as Array).is_empty())
	var data: Dictionary = encoded["data"]
	assert_eq(data.size(), 3)
	assert_eq(data["kind"], "gameplay_recovery")
	assert_eq(data["gameplay_state_version"], 2)
	assert_false(data.has("state"))
	assert_false(data.has("snapshots"))
	var loaded: Dictionary = MigrationScript.load_data(JSON.parse_string(JSON.stringify(data)))
	assert_eq(loaded["status"], "known", str(loaded))
	assert_eq(loaded["recovery_state"], original)
	assert_eq(loaded["recovery_state"]["origin"], "new_run_default")
	assert_eq(loaded["recovery_state"]["evaluated_day"], null)
	assert_eq(typeof(loaded["gameplay_state_version"]), TYPE_INT)
	assert_eq(typeof(loaded["recovery_state"]["schema_version"]), TYPE_INT)


func test_settled_json_round_trip_keeps_actual_sleep_and_trace() -> void:
	var record := _settled_record()
	var result: Dictionary = MigrationScript.encode(record)
	assert_true(bool(result["valid"]), str(result))
	var parsed: Variant = JSON.parse_string(JSON.stringify(result["data"]))
	var loaded: Dictionary = MigrationScript.load_data(parsed)
	assert_eq(loaded["status"], "known", str(loaded))
	if loaded["status"] != "known":
		return
	assert_eq(loaded["recovery_state"], record)
	# This snapshot intentionally differs from today's XML. Loading preserves it.
	assert_eq(loaded["recovery_state"]["sleep_snapshot"]["energy"], 11)
	assert_eq(loaded["recovery_state"]["sleep_snapshot"]["mood"], 9)
	assert_eq(typeof(loaded["recovery_state"]["evaluated_day"]), TYPE_INT)
	assert_eq(typeof(loaded["recovery_state"]["inputs"]["energy"]), TYPE_INT)
	assert_eq(typeof(loaded["recovery_state"]["inputs"]["action_counts"]["study"]), TYPE_INT)


func test_loaded_and_encoded_records_do_not_share_nested_state() -> void:
	var original := _settled_record()
	var expected := original.duplicate(true)
	var envelope := _envelope(original)
	var loaded: Dictionary = MigrationScript.load_data(envelope)
	var encoded: Dictionary = MigrationScript.encode(original)
	assert_true(bool(encoded["valid"]), str(encoded))
	original["inputs"]["action_counts"]["study"] = 3
	original["sleep_snapshot"]["energy"] = 999
	(original["reason_ids"] as Array).clear()
	assert_eq(loaded["recovery_state"], expected)
	assert_eq(encoded["data"]["recovery_state"], expected)
	loaded["recovery_state"]["inputs"]["action_counts"]["study"] = 0
	(encoded["data"]["recovery_state"]["reason_ids"] as Array).clear()
	assert_eq(original["inputs"]["action_counts"]["study"], 3)
	assert_eq(loaded["recovery_state"]["reason_ids"], expected["reason_ids"])
	assert_eq(encoded["data"]["recovery_state"]["inputs"], expected["inputs"])


func test_legacy_mixed_values_never_infer_recovery_or_next_day_effects() -> void:
	var expected: Dictionary = MigrationScript.load_data({"diet_burden": 0})
	_assert_unavailable(expected, "legacy_unknown")
	assert_true((expected["errors"] as Array).is_empty())
	assert_eq(expected["recovery_state"]["reason_ids"], ["LEGACY_RECOVERY_NOT_RECORDED"])
	for stats in [
		{"diet_burden": 100}, {"burden": 99}, {"character_health": 100},
		{"energy": 100, "stress": 0, "quality": 100},
		{"energy": 1, "stress": 100, "quality": 0},
	]:
		assert_eq(MigrationScript.load_data(stats), expected)
	for learning_id in ["clear_focus", "steady", "fatigued", "brain_fog"]:
		var day_record := {
			"day": 3, "start_state": {"diet_burden": 0}, "end_state": {"diet_burden": 100},
			"learning_state": {"id": learning_id}, "next_learning_state": {"id": learning_id},
			"meals": [{"food_ids": ["apple"], "quality": 99}],
		}
		var before := day_record.duplicate(true)
		assert_eq(MigrationScript.load_data(day_record), expected)
		assert_eq(day_record, before)


func test_explicit_v1_and_legacy_unknown_can_round_trip_without_defaulting() -> void:
	for old_record in [
		{"gameplay_state_version": 1, "energy": 52, "diet_burden": 24},
		{"gameplay_state_version": 1.0, "state": {"energy": 52.0, "diet_burden": 24.0}},
		{
			"kind": "gameplay_recovery", "gameplay_state_version": 1,
			"start_state": {"energy": 52}, "end_state": {"energy": 40},
		},
	]:
		var loaded: Dictionary = MigrationScript.load_data(old_record)
		_assert_unavailable(loaded, "legacy_unknown")
		var encoded: Dictionary = MigrationScript.encode(loaded["recovery_state"])
		assert_true(bool(encoded["valid"]), str(encoded))
		var reloaded: Dictionary = MigrationScript.load_data(
			JSON.parse_string(JSON.stringify(encoded["data"]))
		)
		assert_eq(reloaded, loaded)
		assert_eq(reloaded["recovery_state"]["condition"], null)


func test_empty_unknown_and_health_archive_inputs_are_not_legacy_gameplay() -> void:
	for data in [
		null, [], "gameplay", 1, true, {}, {"unrecognized": 1},
		{"learning_state": {"id": "clear_focus"}}, {"quality": 99},
		{"energy": "52"}, {"energy": true}, {"energy": 1.5},
		{"energy": NAN}, {"energy": INF}, {"energy": 52, "unrecognized": 1},
		{"energy": 9007199254740992}, {"energy": 9007199254740992.0},
		{"energy": -9007199254740992}, {"energy": 1.0e40},
		{"gameplay_state_version": 1}, {"gameplay_state_version": 1, "unrecognized": 1},
		{"gameplay_state_version": 1, "energy": 52, "unrecognized": 1},
		{"gameplay_state_version": 1, "state": {"energy": 52}, "unrecognized": 1},
		{"gameplay_state_version": 1, "state": {"energy": 9007199254740992}},
		{"gameplay_state_version": 1, "start_state": {"energy": 52}},
		{"gameplay_state_version": 1, "end_state": {"energy": 52}},
		{"start_state": {"energy": 52}}, {"end_state": {"energy": 52}},
		{"start_state": [], "end_state": {"energy": 52}},
		{"start_state": {}, "end_state": {}},
		{"schema_version": 1, "kind": "meal_health_archive", "snapshots": []},
		{"schema_version": 1, "kind": "meal_health_archive", "snapshots": [], "energy": 52},
		{"gameplay_state_version": 1, "kind": "meal_health_archive", "snapshots": []},
	]:
		_assert_unavailable(MigrationScript.load_data(data), "invalid")


func test_versions_are_validated_before_legacy_fallback() -> void:
	for version in [
		null, "1", "2", true, false, 0, -1, 1.5, 2.5, INF, NAN,
		9007199254740992, 9007199254740992.0, 1.0e40,
	]:
		_assert_unavailable(MigrationScript.load_data({
			"gameplay_state_version": version, "energy": 52, "diet_burden": 24,
		}), "invalid")
	for version in [3, 3.0, 999]:
		var result: Dictionary = MigrationScript.load_data({
			"gameplay_state_version": version, "energy": 52, "diet_burden": 24,
		})
		_assert_unavailable(result, "unsupported_version")
		assert_eq(result["errors"], ["UNSUPPORTED_GAMEPLAY_STATE_VERSION"])


func test_new_fields_without_current_version_never_fall_back_to_legacy() -> void:
	for data in [
		{"recovery_state": StateScript.new_run()},
		{"energy": 52, "recovery_state": StateScript.new_run()},
		{"energy": 52, "rules_version": "recovery-gameplay-v1"},
		{"energy": 52, "condition": "rested"},
		{"gameplay_state_version": 1, "recovery_state": StateScript.new_run()},
		{"gameplay_state_version": 1, "state": {"energy": 52, "recovery_state": {}}},
		{"start_state": {"energy": 52}, "end_state": {"energy": 52, "recovery_state": {}}},
	]:
		_assert_unavailable(MigrationScript.load_data(data), "invalid")


func test_v2_requires_exact_envelope_and_whole_record() -> void:
	for data in [
		{"gameplay_state_version": 2},
		{"gameplay_state_version": 2, "kind": "gameplay_recovery"},
		{"gameplay_state_version": 2, "recovery_state": StateScript.new_run()},
		{"gameplay_state_version": 2, "kind": "other", "recovery_state": StateScript.new_run()},
		_envelope(null), _envelope([]), _envelope({}), _envelope("steady"),
	]:
		_assert_unavailable(MigrationScript.load_data(data), "invalid")
	for key in ["state", "start_state", "end_state", "health_archive", "unknown", "burden", "diet_burden", "character_health"]:
		var envelope := _envelope(StateScript.new_run())
		envelope[key] = 0
		_assert_unavailable(MigrationScript.load_data(envelope), "invalid")
	for key in ["burden", "diet_burden", "character_health", "food_ids", "quality"]:
		var record: Dictionary = StateScript.new_run()
		record[key] = 0
		_assert_unavailable(MigrationScript.load_data(_envelope(record)), "invalid")


func test_future_recovery_versions_fail_closed_and_are_not_rewritten() -> void:
	for version in [2, 2.0, 99]:
		var record: Dictionary = StateScript.new_run()
		record["schema_version"] = version
		var before := record.duplicate(true)
		_assert_unavailable(MigrationScript.load_data(_envelope(record)), "unsupported_version")
		assert_eq(record, before)
	var other_rules: Dictionary = StateScript.new_run()
	other_rules["rules_version"] = "recovery-gameplay-v99"
	_assert_unavailable(MigrationScript.load_data(_envelope(other_rules)), "unsupported_version")
	for version in [
		null, "1", true, 0, -1, 1.5, INF, NAN,
		9007199254740992, 9007199254740992.0, 1.0e40,
	]:
		var record: Dictionary = StateScript.new_run()
		record["schema_version"] = version
		_assert_unavailable(MigrationScript.load_data(_envelope(record)), "invalid")
	for version in [null, true, 1, ""]:
		var record: Dictionary = StateScript.new_run()
		record["rules_version"] = version
		_assert_unavailable(MigrationScript.load_data(_envelope(record)), "invalid")


func test_malformed_record_discards_all_result_and_effect_fields() -> void:
	for patch in [
		{"condition": "unknown"}, {"inputs": []}, {"evaluated_day": "3"},
		{"next_day_effect": {"study_modifier": 999, "opening_delta": {"energy": 999}}},
		{"reason_ids": [1]}, {"sleep_snapshot": {}}, {"schema_version": false},
	]:
		var record := _settled_record()
		record.merge(patch, true)
		var before := record.duplicate(true)
		_assert_unavailable(MigrationScript.load_data(_envelope(record)), "invalid")
		assert_eq(record, before)


func test_encode_refuses_invalid_and_unsupported_records_instead_of_faking_state() -> void:
	var future: Dictionary = StateScript.new_run()
	future["rules_version"] = "recovery-gameplay-v99"
	for record in [
		null, {}, [], {"energy": 52}, future,
		StateScript.unavailable("invalid", "INVALID_RECOVERY_INPUT"),
		StateScript.unavailable("unsupported_version", "UNSUPPORTED_RECOVERY_SCHEMA_VERSION"),
	]:
		var result: Dictionary = MigrationScript.encode(record)
		assert_false(bool(result["valid"]), str(record))
		assert_eq(result["data"], null)
		assert_false((result["errors"] as Array).is_empty())


func test_mixed_legacy_history_stays_independent_from_health_information() -> void:
	var health_snapshot := {
		"snapshot_schema_version": 1, "day": 3, "food_ids": ["apple"],
		"status": "legacy_unknown", "profile_snapshots": {},
	}
	var day_record := {
		"day": 3, "start_state": {"energy": 52, "diet_burden": 24},
		"end_state": {"energy": 80, "diet_burden": 0},
		"meals": [{"health_snapshot": health_snapshot}],
	}
	var before := day_record.duplicate(true)
	var loaded: Dictionary = MigrationScript.load_data(day_record)
	_assert_unavailable(loaded, "legacy_unknown")
	assert_eq(day_record, before)
	assert_eq(health_snapshot["profile_snapshots"], {})
	assert_false(loaded.has("meals"))
	assert_false(loaded["recovery_state"].has("health_snapshot"))
	assert_false(health_snapshot.has("recovery_state"))
	loaded["recovery_state"]["reason_ids"].clear()
	assert_eq(day_record, before)


func test_frozen_seven_day_and_early_collapse_records_remain_unknown() -> void:
	const BASELINE_PATH := "res://tests/fixtures/recovery_v1_baseline/legacy_baseline.json"
	var baseline_text := FileAccess.get_file_as_string(BASELINE_PATH)
	assert_false(baseline_text.is_empty())
	var baseline: Variant = JSON.parse_string(baseline_text)
	assert_true(baseline is Dictionary)
	if not baseline is Dictionary:
		return
	var migrated_count := 0
	for flow_id in ["seven_day_flow", "early_collapse_flow"]:
		var days: Array = baseline[flow_id]["days"]
		assert_eq(days.size(), 7 if flow_id == "seven_day_flow" else 2)
		for day in days:
			var record: Dictionary = day["day_record"] if flow_id == "seven_day_flow" else day
			var before := record.duplicate(true)
			var loaded: Dictionary = MigrationScript.load_data(record)
			_assert_unavailable(loaded, "legacy_unknown")
			assert_eq(record, before)
			assert_eq(loaded["recovery_state"]["reason_ids"], ["LEGACY_RECOVERY_NOT_RECORDED"])
			assert_eq(loaded["recovery_state"]["sleep_snapshot"], null)
			assert_false(loaded["recovery_state"].has("learning_state"))
			assert_false(loaded["recovery_state"].has("next_learning_state"))
			migrated_count += 1
	assert_eq(migrated_count, 9)
	assert_eq(FileAccess.get_file_as_string(BASELINE_PATH), baseline_text)


func _envelope(record: Variant) -> Dictionary:
	return {"kind": "gameplay_recovery", "gameplay_state_version": 2, "recovery_state": record}


func _settled_record() -> Dictionary:
	var result: Dictionary = StateScript.settle(3, {"energy": 60, "stress": 40}, {
		"id": "sleep_early", "energy": 11, "mood": 9, "stress": -2, "study": 0, "satiety": -8,
	}, {"study": 2, "walk": 1})
	assert_true(bool(result["valid"]), str(result))
	return result["recovery_state"]


func _assert_unavailable(result: Dictionary, expected_status: String) -> void:
	assert_eq(result["status"], expected_status, str(result))
	assert_eq(result["gameplay_state_version"], 2)
	var record: Dictionary = result["recovery_state"]
	assert_eq(record["status"], expected_status)
	assert_eq(record["condition"], null)
	assert_eq(record["next_day_effect"], null)
	assert_eq(record["inputs"], null)
	assert_eq(record["evaluated_day"], null)
	assert_eq(record["sleep_snapshot"], null)
	assert_eq(record["origin"], "legacy_record")
	if expected_status != "legacy_unknown":
		assert_false((result["errors"] as Array).is_empty())
