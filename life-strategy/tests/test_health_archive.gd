@tool
extends McpTestSuite

const ArchiveScript := preload("res://scripts/health/MealHealthArchive.gd")
const SnapshotScript := preload("res://scripts/health/MealHealthSnapshot.gd")
const StoreScript := preload("res://scripts/health/HealthDataStore.gd")

var _test_directory := ""


func suite_name() -> String:
	return "health_archive"


func setup() -> void:
	_test_directory = ProjectSettings.globalize_path(
		"res://.godot/health-archive-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	assert_eq(DirAccess.make_dir_recursive_absolute(_test_directory), OK)


func teardown() -> void:
	var directory := DirAccess.open(_test_directory)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(_test_directory.path_join(file_name))
	for directory_name in directory.get_directories():
		DirAccess.remove_absolute(_test_directory.path_join(directory_name))
	DirAccess.remove_absolute(_test_directory)


func test_append_get_and_save_data_do_not_share_mutable_arrays_or_profiles() -> void:
	var archive := ArchiveScript.new()
	var snapshot := _snapshot()
	assert_true(bool(archive.append_snapshot(snapshot)["ok"]))
	var expected := snapshot.duplicate(true)
	(snapshot["food_ids"] as Array).clear()
	(snapshot["profile_snapshots"] as Dictionary).clear()
	var first_read: Array[Dictionary] = archive.get_snapshots()
	var read_profile: Dictionary = first_read[0]["profile_snapshots"]["fixture_meal"]
	(read_profile["components"] as Array).clear()
	var save_data: Dictionary = archive.to_save_data()
	(save_data["snapshots"] as Array).clear()
	assert_eq(archive.get_snapshots(), [expected])
	archive.clear()
	assert_true(archive.get_snapshots().is_empty())
	assert_eq(first_read.size(), 1)


func test_current_archive_json_round_trip_preserves_original_profile_versions() -> void:
	var original := ArchiveScript.new()
	assert_true(bool(original.append_snapshot(_snapshot())["ok"]))
	var encoded := JSON.stringify(original.to_save_data())
	var loaded := ArchiveScript.new()
	var parsed: Variant = JSON.parse_string(encoded)
	var result: Dictionary = loaded.load_data(parsed)
	assert_true(bool(result["ok"]), str(result))
	assert_eq(String(result["status"]), "ready")
	assert_eq(loaded.get_snapshots(), original.get_snapshots())
	(parsed["snapshots"] as Array).clear()
	assert_eq(loaded.get_snapshots().size(), 1)


func test_legacy_quality_tags_and_current_food_id_never_infer_health() -> void:
	var archive := ArchiveScript.new()
	var result: Dictionary = archive.load_data([{
		"phase": "lunch", "source_id": "cafeteria", "food_ids": ["apple"],
		"quality": 95, "tags": ["healthy"], "food_groups": ["fruits"],
		"skipped": false,
	}])
	assert_true(bool(result["ok"]), str(result))
	assert_eq(String(result["status"]), "migrated_legacy")
	var migrated: Dictionary = archive.get_snapshots()[0]
	assert_eq(String(migrated["status"]), "legacy_unknown")
	assert_eq(migrated["day"], null)
	assert_eq(migrated["food_ids"], ["apple"])
	assert_true((migrated["profile_snapshots"] as Dictionary).is_empty())
	assert_true((migrated["component_snapshot"] as Array).is_empty())
	assert_true((migrated["factor_snapshot"] as Array).is_empty())
	assert_eq(String(migrated["confidence"]), "unknown")
	assert_eq(String(migrated["guidance_status"]), "not_evaluated")
	assert_false(migrated.has("quality"))


func test_legacy_existing_snapshot_is_kept_without_rebuilding_from_record() -> void:
	var archive := ArchiveScript.new()
	var snapshot := _snapshot()
	var result: Dictionary = archive.load_data({"day": 7, "meal_records": [{
		"phase": "dinner", "food_ids": ["a_different_food"], "quality": 0,
		"health_snapshot": snapshot,
	}]})
	assert_true(bool(result["ok"]), str(result))
	assert_eq(archive.get_snapshots(), [snapshot])
	(snapshot["profile_snapshots"] as Dictionary).clear()
	assert_false((archive.get_snapshots()[0]["profile_snapshots"] as Dictionary).is_empty())


func test_legacy_day_uses_record_then_envelope_and_never_invents_missing_day() -> void:
	var archive := ArchiveScript.new()
	var result: Dictionary = archive.load_data({"day": 3, "meal_records": [
		{"day": 2, "phase": "breakfast", "skipped": true},
		{"phase": "dinner"},
	]})
	assert_true(bool(result["ok"]), str(result))
	var records: Array[Dictionary] = archive.get_snapshots()
	assert_eq(int(records[0]["day"]), 2)
	assert_eq(int(records[1]["day"]), 3)
	assert_eq(String(records[0]["status"]), "legacy_unknown")
	assert_true(bool(archive.load_data([{}])["ok"]))
	assert_eq(archive.get_snapshots()[0]["day"], null)
	assert_eq(String(archive.get_snapshots()[0]["phase"]), "unknown")


func test_failed_record_validation_cannot_partially_replace_archive() -> void:
	var archive := _archive_with_snapshot()
	var before: Dictionary = archive.to_save_data()
	var invalid := _snapshot()
	invalid["profile_snapshots"] = []
	var result: Dictionary = archive.load_data({
		"schema_version": 1, "kind": "meal_health_archive", "snapshots": [_snapshot(), invalid],
	})
	assert_false(bool(result["ok"]))
	assert_eq(archive.to_save_data(), before)
	assert_false(bool(archive.append_snapshot(invalid)["ok"]))
	assert_eq(archive.to_save_data(), before)


func test_future_archive_and_snapshot_versions_fail_closed() -> void:
	var archive := _archive_with_snapshot()
	var before: Dictionary = archive.to_save_data()
	var future := before.duplicate(true)
	future["schema_version"] = 99
	var result: Dictionary = archive.load_data(future)
	assert_false(bool(result["ok"]))
	assert_eq(String(result["status"]), "unsupported_future_schema")
	assert_eq(archive.to_save_data(), before)
	future = before.duplicate(true)
	future["snapshots"][0]["snapshot_schema_version"] = 99
	assert_false(bool(archive.load_data(future)["ok"]))
	assert_eq(archive.to_save_data(), before)
	assert_false(bool(archive.load_data([{"health_snapshot": future["snapshots"][0]}])["ok"]))
	assert_eq(archive.to_save_data(), before)


func test_direct_snapshot_arrays_keep_current_data_and_reject_future_schemas() -> void:
	var archive := ArchiveScript.new()
	var snapshot := _snapshot()
	assert_true(bool(archive.load_data([snapshot])["ok"]))
	assert_eq(archive.get_snapshots(), [snapshot])
	var before: Dictionary = archive.to_save_data()
	var future := snapshot.duplicate(true)
	future["snapshot_schema_version"] = 99
	assert_false(bool(archive.load_data([snapshot, future])["ok"]))
	assert_eq(archive.to_save_data(), before)
	assert_false(bool(archive.load_data([{"schema_version": 99, "food_ids": ["apple"]}])["ok"]))
	assert_eq(archive.to_save_data(), before)


func test_wrong_shapes_and_fractional_versions_preserve_archive() -> void:
	var archive := _archive_with_snapshot()
	var before: Dictionary = archive.to_save_data()
	var invalid_inputs: Array = [
		null, "not an archive", 5, {}, {"meal_records": "bad"},
		{"day": "3", "meal_records": []}, [{"day": -1}], [{"day": 1.5}], [42],
		[{"day": 9007199254740992}], [{"day": 1.0e40}],
		{"day": 9007199254740992, "meal_records": []},
		{"schema_version": 1.5, "kind": "meal_health_archive", "snapshots": []},
		{"schema_version": true, "kind": "meal_health_archive", "snapshots": []},
		{"schema_version": "1", "kind": "meal_health_archive", "snapshots": []},
		{"schema_version": 0, "kind": "meal_health_archive", "snapshots": []},
		{"schema_version": 1, "kind": "other", "snapshots": []},
		{"schema_version": 1, "kind": "meal_health_archive", "snapshots": {}},
	]
	for data in invalid_inputs:
		assert_false(bool(archive.load_data(data)["ok"]), str(data))
		assert_eq(archive.to_save_data(), before)


func test_non_json_snapshot_values_are_rejected_before_storage() -> void:
	var archive := _archive_with_snapshot()
	var before: Dictionary = archive.to_save_data()
	var snapshot := _snapshot()
	snapshot["not_serializable"] = Vector2.ONE
	assert_false(bool(archive.append_snapshot(snapshot)["ok"]))
	snapshot["not_serializable"] = NAN
	assert_false(bool(archive.append_snapshot(snapshot)["ok"]))
	snapshot["not_serializable"] = {1: "non-string key"}
	assert_false(bool(archive.append_snapshot(snapshot)["ok"]))
	assert_eq(archive.to_save_data(), before)


func test_missing_and_bad_json_files_do_not_clear_loaded_archive() -> void:
	var archive := _archive_with_snapshot()
	var before: Dictionary = archive.to_save_data()
	var path := _test_directory.path_join("broken.json")
	var result: Dictionary = archive.load_file(path)
	assert_false(bool(result["ok"]))
	assert_eq(String(result["status"]), "missing_file")
	_write_text(path, "{\"schema_version\": 1,")
	result = archive.load_file(path)
	assert_false(bool(result["ok"]))
	assert_eq(String(result["status"]), "invalid_json")
	assert_eq(archive.to_save_data(), before)


func test_file_round_trip_and_replacement_leave_no_temporary_files() -> void:
	var archive := _archive_with_snapshot()
	var path := _test_directory.path_join("archive.json")
	assert_true(bool(archive.save_file(path)["ok"]))
	var loaded := ArchiveScript.new()
	assert_true(bool(loaded.load_file(path)["ok"]))
	assert_eq(loaded.to_save_data(), archive.to_save_data())
	assert_true(bool(archive.append_snapshot(SnapshotScript.legacy(3, {}))["ok"]))
	var result: Dictionary = archive.save_file(path)
	assert_true(bool(result["ok"]), str(result))
	assert_true(bool(loaded.load_file(path)["ok"]))
	assert_eq(loaded.get_snapshots().size(), 2)
	assert_eq(loaded.to_save_data(), archive.to_save_data())
	assert_eq(DirAccess.open(_test_directory).get_files(), PackedStringArray(["archive.json"]))


func test_write_failures_report_errors_and_keep_previous_file_and_memory() -> void:
	var archive := _archive_with_snapshot()
	var path := _test_directory.path_join("archive.json")
	assert_true(bool(archive.save_file(path)["ok"]))
	var previous_file := FileAccess.get_file_as_string(path)
	var before: Dictionary = archive.to_save_data()
	var result: Dictionary = archive.save_file(_test_directory.path_join("missing/archive.json"))
	assert_false(bool(result["ok"]))
	assert_eq(String(result["status"]), "write_failed")
	assert_false(String(result["error"]).is_empty())
	assert_false(bool(archive.save_file("")["ok"]))
	assert_false(bool(archive.save_file(_test_directory)["ok"]))
	assert_eq(FileAccess.get_file_as_string(path), previous_file)
	assert_eq(archive.to_save_data(), before)
	assert_eq(DirAccess.open(_test_directory).get_files(), PackedStringArray(["archive.json"]))


func _snapshot() -> Dictionary:
	var store := StoreScript.new()
	var catalog: Dictionary = store.load_catalog("res://tests/fixtures/health_data_store/normal.xml")
	return SnapshotScript.build(2, {
		"phase": "lunch", "source_id": "cafeteria", "food_ids": ["fixture_meal"], "skipped": false,
	}, catalog)


func _archive_with_snapshot() -> ArchiveScript:
	var archive := ArchiveScript.new()
	assert_true(bool(archive.append_snapshot(_snapshot())["ok"]))
	return archive


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null)
	if file != null:
		file.store_string(content)
		file.close()
