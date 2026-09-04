@tool
extends McpTestSuite

const HealthDataStoreScript := preload("res://scripts/health/HealthDataStore.gd")
const FIXTURE_ROOT := "res://tests/fixtures/health_data_store"


func suite_name() -> String:
	return "health_data_store"


func test_supported_catalog_loads_root_profile_components_and_factors() -> void:
	var store := HealthDataStoreScript.new()
	var result: Dictionary = store.load_catalog("%s/normal.xml" % FIXTURE_ROOT)
	assert_eq(String(result["status"]), HealthDataStoreScript.STATUS_READY)
	assert_true(bool(result["available"]))
	assert_false(bool(result["degraded"]))
	assert_eq(int(result["schema_version"]), 1)
	assert_eq(String(result["model_version"]), "fixture-model-v1.0")
	assert_eq(String(result["locale"]), "zh-CN")
	assert_eq(String(result["reviewed_at"]), "2026-07-15")
	assert_eq(int(result["profile_count"]), 1)
	assert_eq(store.get_profile_ids(), ["fixture_meal"])

	var profile: Dictionary = store.get_profile("fixture_meal")
	assert_eq(int(profile["profile_version"]), 3)
	assert_eq(String(profile["model_version"]), "fixture-model-v1.0")
	assert_eq(String(profile["composition_status"]), "estimated")
	assert_eq(String(profile["confidence"]), "low")
	assert_eq(String(profile["review_status"]), "draft")
	assert_eq(profile["evidence_refs"], ["FIXTURE-EVIDENCE", "FIXTURE-RECIPE-PENDING"])

	var portion: Dictionary = profile["portion"]
	assert_eq(String(portion["status"]), "estimated")
	assert_eq(String(portion["label"]), "一份测试餐")
	assert_eq(float(portion["value"]), 320.0)
	assert_eq(String(portion["unit"]), "g")

	var components: Array = profile["components"]
	assert_eq(components.size(), 1)
	assert_eq(String((components[0] as Dictionary)["food_group"]), "grains_tubers")
	assert_eq(String((components[0] as Dictionary)["confidence"]), "low")
	assert_eq(float((components[0] as Dictionary)["amount_value"]), 200.0)

	var factors: Array = profile["factors"]
	assert_eq(factors.size(), 1)
	assert_eq(String((factors[0] as Dictionary)["factor_id"]), "sodium")
	assert_eq(String((factors[0] as Dictionary)["band"]), "unknown")
	assert_eq(String((factors[0] as Dictionary)["confidence"]), "unknown")
	assert_eq(profile["cooking_methods"], ["mixed"])
	var caffeine: Dictionary = profile["caffeine"]
	assert_eq(String(caffeine["status"]), "not_applicable")
	assert_eq(String(caffeine["band"]), "none")
	assert_eq(String(caffeine["serving_time_relevance"]), "none")


func test_public_results_are_deep_copies() -> void:
	var store := HealthDataStoreScript.new()
	var loaded: Dictionary = store.load_catalog("%s/normal.xml" % FIXTURE_ROOT)
	var profile: Dictionary = store.get_profile("fixture_meal")
	(profile["components"] as Array).clear()
	(loaded["profiles"] as Dictionary).clear()
	assert_eq((store.get_profile("fixture_meal")["components"] as Array).size(), 1)
	assert_eq(int(store.get_catalog()["profile_count"]), 1)


func test_supported_empty_catalog_is_available_without_invented_profiles() -> void:
	var store := HealthDataStoreScript.new()
	var result: Dictionary = store.load_catalog("%s/empty_catalog.xml" % FIXTURE_ROOT)
	assert_eq(String(result["status"]), HealthDataStoreScript.STATUS_READY_EMPTY)
	assert_true(bool(result["available"]))
	assert_eq(int(result["profile_count"]), 0)
	assert_true(store.get_profile("not_listed").is_empty())
	var lookup: Dictionary = store.lookup_profile("not_listed")
	assert_eq(String(lookup["status"]), "information_insufficient")
	assert_eq(String(lookup["reason"]), "profile_missing")
	assert_true((lookup["profile"] as Dictionary).is_empty())


func test_empty_and_missing_files_have_distinct_degraded_states() -> void:
	var store := HealthDataStoreScript.new()
	var empty_result: Dictionary = store.load_catalog("%s/empty_file.xml" % FIXTURE_ROOT)
	assert_eq(String(empty_result["status"]), HealthDataStoreScript.STATUS_EMPTY_FILE)
	assert_false(bool(empty_result["available"]))
	assert_true(bool(empty_result["degraded"]))

	var missing_result: Dictionary = store.load_catalog("%s/does_not_exist.xml" % FIXTURE_ROOT)
	assert_eq(String(missing_result["status"]), HealthDataStoreScript.STATUS_MISSING)
	assert_false(bool(missing_result["available"]))
	assert_true(bool(missing_result["degraded"]))
	assert_eq(int(missing_result["profile_count"]), 0)
	var lookup: Dictionary = store.lookup_profile("fixture_meal")
	assert_eq(String(lookup["status"]), "data_unavailable")
	assert_eq(String(lookup["reason"]), HealthDataStoreScript.STATUS_MISSING)


func test_legacy_schema_fails_closed_instead_of_guessing_profiles() -> void:
	var store := HealthDataStoreScript.new()
	var result: Dictionary = store.load_catalog("%s/legacy_schema.xml" % FIXTURE_ROOT)
	assert_eq(
		String(result["status"]),
		HealthDataStoreScript.STATUS_UNSUPPORTED_LEGACY_SCHEMA
	)
	assert_eq(int(result["schema_version"]), 0)
	assert_false(bool(result["available"]))
	assert_true(bool(result["degraded"]))
	assert_eq(int(result["profile_count"]), 0)
	assert_false(store.has_profile("must_not_be_inferred"))
	assert_false((result["errors"] as Array).is_empty())


func test_future_schema_fails_closed_instead_of_partially_loading() -> void:
	var store := HealthDataStoreScript.new()
	var result: Dictionary = store.load_catalog("%s/future_schema.xml" % FIXTURE_ROOT)
	assert_eq(
		String(result["status"]),
		HealthDataStoreScript.STATUS_UNSUPPORTED_FUTURE_SCHEMA
	)
	assert_eq(int(result["schema_version"]), 99)
	assert_false(bool(result["available"]))
	assert_true(bool(result["degraded"]))
	assert_eq(int(result["profile_count"]), 0)
	assert_false(store.has_profile("must_not_be_inferred"))
	assert_false((result["errors"] as Array).is_empty())
