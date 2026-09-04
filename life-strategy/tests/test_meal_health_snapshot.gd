@tool
extends McpTestSuite

const SnapshotScript := preload("res://scripts/health/MealHealthSnapshot.gd")
const StoreScript := preload("res://scripts/health/HealthDataStore.gd")
const FIXTURE_PATH := "res://tests/fixtures/health_data_store/normal.xml"


func suite_name() -> String:
	return "meal_health_snapshot"


func test_fixed_product_preserves_version_portion_evidence_and_draft_independently() -> void:
	var store := StoreScript.new()
	var catalog: Dictionary = store.load_catalog()
	var snapshot: Dictionary = SnapshotScript.build(2, _meal(["milk"]), catalog)
	assert_true(SnapshotScript.validate(snapshot)["valid"])
	assert_eq(snapshot["status"], "eaten")
	assert_eq(snapshot["data_status"], "ready")
	assert_eq(snapshot["confidence"], "high")
	assert_eq(snapshot["guidance_status"], "not_evaluated")
	assert_eq(snapshot["model_version"], catalog["model_version"])
	var captured: Dictionary = snapshot["profile_snapshots"]["milk"]
	assert_eq(captured, store.get_profile("milk"))
	assert_eq(snapshot["profile_versions"]["milk"], captured["profile_version"])
	assert_eq(captured["review_status"], "draft")
	assert_eq(captured["portion"]["value"], 250.0)
	assert_true(captured["evidence_refs"].has("GAME-SPEC-204D-V1"))
	assert_eq(snapshot["factor_snapshot"][0]["band"], "none")
	assert_eq(snapshot["factor_snapshot"][0]["food_id"], "milk")


func test_snapshot_does_not_change_after_catalog_or_record_changes() -> void:
	var catalog: Dictionary = StoreScript.new().load_catalog(FIXTURE_PATH)
	var record := _meal(["fixture_meal"])
	var first: Dictionary = SnapshotScript.build(1, record, catalog)
	var original: Dictionary = first.duplicate(true)
	catalog["model_version"] = "future-model-v3.0"
	catalog["profiles"]["fixture_meal"]["profile_version"] = 4
	catalog["profiles"]["fixture_meal"]["model_version"] = "future-model-v3.0"
	catalog["profiles"]["fixture_meal"]["portion"]["value"] = 450.0
	catalog["profiles"]["fixture_meal"]["components"][0]["amount_value"] = 300.0
	record["food_ids"].clear()
	assert_eq(first, original)
	assert_true(SnapshotScript.validate(first)["valid"])
	var later: Dictionary = SnapshotScript.build(2, _meal(["fixture_meal"]), catalog)
	assert_eq(later["profile_versions"]["fixture_meal"], 4)
	assert_eq(later["model_version"], "future-model-v3.0")
	assert_eq(first["profile_versions"]["fixture_meal"], 3)
	assert_eq(first["profile_snapshots"]["fixture_meal"]["portion"]["value"], 320.0)


func test_shared_ingredients_keep_food_provenance_without_early_deduplication() -> void:
	var catalog: Dictionary = StoreScript.new().load_catalog()
	var snapshot: Dictionary = SnapshotScript.build(3, _meal(["milk", "bubble_tea"]), catalog)
	assert_true(SnapshotScript.validate(snapshot)["valid"])
	var sources: Array[String] = []
	var amounts: Array[float] = []
	for component in snapshot["component_snapshot"]:
		if component["ingredient_id"] == "simulated_whole_milk":
			sources.append(component["food_id"])
			amounts.append(component["amount_value"])
	assert_eq(sources, ["milk", "bubble_tea"])
	assert_eq(amounts, [250.0, 100.0])
	assert_eq(snapshot["profile_snapshots"]["bubble_tea"]["caffeine"]["mg"], 50.0)


func test_missing_or_invalid_profiles_keep_eaten_fact_and_explicit_data_gaps() -> void:
	var catalog: Dictionary = StoreScript.new().load_catalog()
	var missing: Dictionary = SnapshotScript.build(1, _meal(["milk", "missing_food"]), catalog)
	assert_true(SnapshotScript.validate(missing)["valid"])
	assert_eq(missing["status"], "eaten")
	assert_eq(missing["data_status"], "partial")
	assert_eq(missing["confidence"], "unknown")
	assert_eq(missing["missing_food_ids"], ["missing_food"])
	assert_eq(missing["profile_snapshots"].keys(), ["milk"])
	catalog["profiles"]["milk"]["portion"]["value"] = -5
	var invalid: Dictionary = SnapshotScript.build(1, _meal(["milk", "apple"]), catalog)
	assert_true(SnapshotScript.validate(invalid)["valid"])
	assert_eq(invalid["invalid_food_ids"], ["milk"])
	assert_eq(invalid["profile_snapshots"].keys(), ["apple"])
	assert_eq(invalid["data_status"], "partial")
	assert_eq(invalid["status"], "eaten")


func test_known_empty_composition_is_rejected_during_capture_and_history_validation() -> void:
	var catalog: Dictionary = StoreScript.new().load_catalog()
	var snapshot: Dictionary = SnapshotScript.build(1, _meal(["chicken_vegetable_rice"]), catalog)
	assert_true(SnapshotScript.validate(snapshot)["valid"])
	catalog["profiles"]["chicken_vegetable_rice"]["components"] = []
	var captured: Dictionary = SnapshotScript.build(1, _meal(["chicken_vegetable_rice"]), catalog)
	assert_true(SnapshotScript.validate(captured)["valid"])
	assert_eq(captured["status"], "eaten")
	assert_eq(captured["data_status"], "partial")
	assert_eq(captured["confidence"], "unknown")
	assert_eq(captured["invalid_food_ids"], ["chicken_vegetable_rice"])
	assert_true(captured["profile_snapshots"].is_empty())
	# Corrupt both copies to verify profile validation, not only flattened equality.
	snapshot["profile_snapshots"]["chicken_vegetable_rice"]["components"] = []
	snapshot["component_snapshot"] = []
	assert_false(SnapshotScript.validate(snapshot)["valid"])


func test_unavailable_and_future_catalogs_never_turn_an_eaten_meal_into_a_skip() -> void:
	var unavailable: Dictionary = SnapshotScript.build(1, _meal(["milk"]), {})
	assert_true(SnapshotScript.validate(unavailable)["valid"])
	assert_eq(unavailable["status"], "eaten")
	assert_eq(unavailable["data_status"], "unavailable")
	assert_eq(unavailable["missing_food_ids"], ["milk"])
	assert_true(unavailable["profile_versions"].is_empty())
	var catalog: Dictionary = StoreScript.new().load_catalog()
	catalog["schema_version"] = 99
	var future: Dictionary = SnapshotScript.build(1, _meal(["milk"]), catalog)
	assert_eq(future, unavailable)


func test_skipped_snapshot_never_copies_foods_source_or_legacy_score() -> void:
	var record := _meal(["milk"])
	record["skipped"] = true
	var snapshot: Dictionary = SnapshotScript.build(1, record, StoreScript.new().load_catalog())
	assert_true(SnapshotScript.validate(snapshot)["valid"])
	assert_eq(snapshot["status"], "skipped")
	assert_eq(snapshot["data_status"], "not_applicable")
	assert_eq(snapshot["source_id"], "")
	assert_true(snapshot["food_ids"].is_empty())
	assert_true(snapshot["profile_snapshots"].is_empty())
	assert_false(snapshot.has("quality"))
	assert_false(snapshot.has("stat_delta"))


func test_legacy_records_preserve_only_recorded_facts_and_unknown_dates() -> void:
	var old: Dictionary = SnapshotScript.legacy(0, {
		"phase": "lunch", "food_ids": ["rice_plain"], "quality": 86, "skipped": false,
		"nutrient_tags": ["high_quality_protein_source"], "burden": 0,
	})
	assert_true(SnapshotScript.validate(old)["valid"])
	assert_eq(old["status"], "legacy_unknown")
	assert_eq(old["day"], null)
	assert_eq(old["food_ids"], ["rice_plain"])
	assert_eq(old["legacy_skipped"], false)
	assert_true(old["profile_snapshots"].is_empty())
	assert_true(old["component_snapshot"].is_empty())
	var score_only: Dictionary = SnapshotScript.legacy(0, {"quality": 25, "food_ids": []})
	assert_true(SnapshotScript.validate(score_only)["valid"])
	assert_eq(score_only["phase"], "unknown")
	assert_false(score_only.has("legacy_skipped"))
	var skipped: Dictionary = SnapshotScript.legacy(2, {"phase": "dinner", "skipped": true})
	assert_eq(skipped["status"], "legacy_unknown")
	assert_eq(skipped["legacy_skipped"], true)


func test_validation_rejects_future_schema_bad_numbers_and_forged_derived_data() -> void:
	var snapshot: Dictionary = SnapshotScript.build(1, _meal(["milk"]), StoreScript.new().load_catalog())
	for bad_version in [2, 1.5, true, "1", null]:
		var invalid: Dictionary = snapshot.duplicate(true)
		invalid["snapshot_schema_version"] = bad_version
		assert_false(SnapshotScript.validate(invalid)["valid"])
	for invalid_day in [0, -1, 1.5, true, "1", null, 1.0e30]:
		var invalid: Dictionary = snapshot.duplicate(true)
		invalid["day"] = invalid_day
		assert_false(SnapshotScript.validate(invalid)["valid"])
	var forged: Dictionary = snapshot.duplicate(true)
	forged["component_snapshot"][0]["amount_value"] = 900
	assert_false(SnapshotScript.validate(forged)["valid"])
	forged = snapshot.duplicate(true)
	forged["profile_snapshots"]["milk"]["portion"] = {}
	assert_false(SnapshotScript.validate(forged)["valid"])
	forged = snapshot.duplicate(true)
	forged["quality"] = 95
	assert_false(SnapshotScript.validate(forged)["valid"])
	var round_trip: Variant = JSON.parse_string(JSON.stringify(snapshot))
	assert_true(SnapshotScript.validate(round_trip)["valid"])


func test_gameplay_changes_cannot_change_captured_health_inputs() -> void:
	var catalog: Dictionary = StoreScript.new().load_catalog()
	var record := _meal(["apple", "oatmeal"])
	var before: Dictionary = SnapshotScript.build(2, record, catalog)
	record["quality"] = 95
	record["stat_delta"] = {"mood": -100, "burden": 100, "energy": 99}
	record["total_cost"] = 1000
	record["nutrient_tags"] = ["high_quality_protein_source"]
	var after: Dictionary = SnapshotScript.build(2, record, catalog)
	assert_eq(after, before)
	assert_eq(after["confidence"], "low")
	assert_eq(after["profile_snapshots"]["oatmeal"]["portion"]["status"], "unknown")


func _meal(ids: Array) -> Dictionary:
	return {
		"phase": "lunch", "source_id": "cafeteria", "food_ids": ids.duplicate(),
		"skipped": false, "quality": 86, "total_cost": 7,
		"stat_delta": {"energy": 10, "diet_burden": -2},
	}
