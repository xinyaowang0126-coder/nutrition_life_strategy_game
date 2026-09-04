@tool
extends McpTestSuite

const HealthDataStoreScript := preload("res://scripts/health/HealthDataStore.gd")
const HealthDataValidatorScript := preload("res://scripts/health/HealthDataValidator.gd")
const FIXTURE_ROOT := "res://tests/fixtures/health_data_store"


func suite_name() -> String:
	return "health_data_validator"


func test_supported_fixture_has_no_blocking_errors_and_precise_warnings() -> void:
	var store := HealthDataStoreScript.new()
	var catalog: Dictionary = store.load_catalog("%s/normal.xml" % FIXTURE_ROOT)
	var report: Dictionary = HealthDataValidatorScript.validate(catalog, {
		"known_food_ids": ["fixture_meal"],
	})
	assert_true(bool(report["valid"]))
	assert_eq(int(report["error_count"]), 0)
	assert_true(_codes(report["warnings"]).has("profile_draft"))
	assert_true(_codes(report["warnings"]).has("confidence_limited"))
	for issue_value in report["warnings"]:
		var issue: Dictionary = issue_value
		assert_false(String(issue["food_id"]).is_empty())
		assert_false(String(issue["field"]).is_empty())
		assert_contains(String(issue["path"]), "profile[fixture_meal]")


func test_duplicate_and_unknown_food_ids_are_blocking_and_located() -> void:
	var first := _valid_profile("known_food")
	var duplicate := _valid_profile("known_food")
	var missing_card := _valid_profile("not_in_cards")
	var report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([first, duplicate, missing_card]),
		{"known_food_ids": ["known_food"]}
	)
	assert_false(bool(report["valid"]))
	var duplicate_issue := _first_issue(report["errors"], "food_id_duplicate")
	var unknown_issue := _first_issue(report["errors"], "food_id_unknown")
	assert_eq(String(duplicate_issue["food_id"]), "known_food")
	assert_eq(String(duplicate_issue["field"]), "food_id")
	assert_eq(String(unknown_issue["food_id"]), "not_in_cards")
	assert_eq(String(unknown_issue["field"]), "food_id")


func test_invalid_enums_negative_amounts_and_missing_units_are_blocking() -> void:
	var profile := _valid_profile("bad_fields")
	profile["basis_type"] = "invented_basis"
	var portion: Dictionary = profile["portion"]
	portion["status"] = "maybe"
	portion["value"] = -12.0
	portion.erase("unit")
	profile["components"] = [_valid_component()]
	(profile["components"][0] as Dictionary)["food_group"] = "not_a_group"
	profile["factors"] = [_valid_factor("sodium", "unknown")]
	(profile["factors"][0] as Dictionary)["band"] = "sometimes"
	profile["cooking_methods"] = ["microwaved_by_magic"]
	profile["caffeine"] = {
		"status": "plenty",
		"band": "unknown",
		"serving_time_relevance": "unknown",
	}

	var report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([profile]),
		{"known_food_ids": ["bad_fields"]}
	)
	assert_false(bool(report["valid"]))
	var error_codes := _codes(report["errors"])
	assert_true(error_codes.has("invalid_enum"))
	assert_true(error_codes.has("positive_number_required"))
	assert_true(error_codes.has("amount_unit_missing"))
	var invalid_fields := _fields_for_code(report["errors"], "invalid_enum")
	for expected_field in [
		"basis_type",
		"portion.status",
		"components[0].food_group",
		"factors[0].band",
		"cooking_methods[0]",
		"caffeine.status",
	]:
		assert_true(invalid_fields.has(expected_field), "missing invalid enum: %s" % expected_field)


func test_not_applicable_is_a_valid_cooking_method_for_packaged_foods() -> void:
	var profile := _valid_profile("packaged_food")
	profile["basis_type"] = "package_label"
	profile["cooking_methods"] = ["not_applicable"]
	var report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([profile]),
		{"known_food_ids": ["packaged_food"]}
	)
	assert_true(bool(report["valid"]))
	assert_false(_fields_for_code(report["errors"], "invalid_enum").has(
		"cooking_methods[0]"
	))

	profile["cooking_methods"] = ["not_applicable", "baked"]
	var conflict_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([profile]),
		{"known_food_ids": ["packaged_food"]}
	)
	assert_false(bool(conflict_report["valid"]))
	assert_true(_codes(conflict_report["errors"]).has(
		"not_applicable_method_conflict"
	))


func test_not_applicable_caffeine_requires_none_states_and_no_dose() -> void:
	var profile := _valid_profile("non_caffeinated_product")
	profile["caffeine"] = {
		"status": "not_applicable",
		"band": "none",
		"serving_time_relevance": "none",
	}
	var valid_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([profile]),
		{"known_food_ids": ["non_caffeinated_product"]}
	)
	assert_true(bool(valid_report["valid"]))

	var with_dose := profile.duplicate(true)
	with_dose["caffeine"]["mg"] = 10.0
	var dose_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([with_dose]),
		{"known_food_ids": ["non_caffeinated_product"]}
	)
	assert_true(_codes(dose_report["errors"]).has(
		"caffeine_not_applicable_mg_present"
	))

	var with_band := profile.duplicate(true)
	with_band["caffeine"]["band"] = "high"
	var band_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([with_band]),
		{"known_food_ids": ["non_caffeinated_product"]}
	)
	assert_true(_codes(band_report["errors"]).has(
		"caffeine_not_applicable_band_mismatch"
	))

	var with_timing := profile.duplicate(true)
	with_timing["caffeine"]["serving_time_relevance"] = "evening_attention"
	var timing_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([with_timing]),
		{"known_food_ids": ["non_caffeinated_product"]}
	)
	assert_true(_codes(timing_report["errors"]).has(
		"caffeine_not_applicable_time_mismatch"
	))


func test_expert_review_requires_evidence_date_and_reviewer() -> void:
	var profile := _valid_profile("expert_missing_signoff")
	profile["review_status"] = "expert_reviewed"
	profile["evidence_refs"] = []
	profile["reviewed_at"] = ""
	profile["reviewed_by"] = ""
	var report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([profile]),
		{"known_food_ids": ["expert_missing_signoff"]}
	)
	var codes := _codes(report["errors"])
	assert_true(codes.has("expert_review_evidence_missing"))
	assert_true(codes.has("expert_review_date_missing"))
	assert_true(codes.has("expert_reviewer_missing"))
	for issue_value in report["errors"]:
		var issue: Dictionary = issue_value
		assert_eq(String(issue["food_id"]), "expert_missing_signoff")
		assert_false(String(issue["field"]).is_empty())


func test_none_and_high_factor_bands_require_evidence() -> void:
	var profile := _valid_profile("factor_evidence")
	var none_factor := _valid_factor("added_sugar", "none")
	var high_factor := _valid_factor("sodium", "high")
	none_factor["evidence_refs"] = []
	high_factor["evidence_refs"] = []
	profile["factors"] = [none_factor, high_factor]
	var report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([profile]),
		{"known_food_ids": ["factor_evidence"]}
	)
	var evidence_issues := _issues_with_code(report["errors"], "factor_band_evidence_missing")
	assert_eq(evidence_issues.size(), 2)
	assert_eq(String(evidence_issues[0]["field"]), "factors[0].evidence_refs")
	assert_eq(String(evidence_issues[1]["field"]), "factors[1].evidence_refs")


func test_present_factor_band_is_reserved_for_a_matching_deep_fried_method() -> void:
	var valid_profile := _valid_profile("fried_with_method")
	valid_profile["cooking_methods"] = ["deep_fried"]
	valid_profile["factors"] = [_valid_factor("deep_fried", "present")]
	var valid_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([valid_profile]),
		{"known_food_ids": ["fried_with_method"]}
	)
	assert_true(bool(valid_report["valid"]))
	assert_false(_codes(valid_report["warnings"]).has("deep_fried_factor_missing"))

	var wrong_factor := _valid_profile("sodium_present")
	wrong_factor["factors"] = [_valid_factor("sodium", "present")]
	var wrong_factor_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([wrong_factor]),
		{"known_food_ids": ["sodium_present"]}
	)
	assert_true(_codes(wrong_factor_report["errors"]).has("factor_present_not_applicable"))

	var missing_method := _valid_profile("fried_without_method")
	missing_method["factors"] = [_valid_factor("deep_fried", "present")]
	var missing_method_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([missing_method]),
		{"known_food_ids": ["fried_without_method"]}
	)
	assert_true(_codes(missing_method_report["errors"]).has("deep_fried_method_missing"))

	var missing_factor := _valid_profile("fried_without_factor")
	missing_factor["cooking_methods"] = ["deep_fried"]
	var missing_factor_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([missing_factor]),
		{"known_food_ids": ["fried_without_factor"]}
	)
	assert_false(bool(missing_factor_report["valid"]))
	assert_true(_codes(missing_factor_report["errors"]).has("deep_fried_factor_missing"))

	var graded_fried := _valid_profile("graded_fried")
	graded_fried["cooking_methods"] = ["deep_fried"]
	graded_fried["factors"] = [_valid_factor("deep_fried", "moderate")]
	var graded_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([graded_fried]),
		{"known_food_ids": ["graded_fried"]}
	)
	assert_false(bool(graded_report["valid"]))
	assert_true(_codes(graded_report["errors"]).has("deep_fried_band_invalid"))


func test_known_composition_requires_components_without_composite_context() -> void:
	var profile := _valid_profile("empty_known_recipe")
	profile["composition_status"] = "known"
	profile["components"] = []
	var report: Dictionary = HealthDataValidatorScript.validate(_catalog([profile]))
	assert_false(bool(report["valid"]))
	var issue := _first_issue(report["errors"], "known_components_missing")
	assert_eq(issue.get("food_id"), "empty_known_recipe")
	assert_eq(issue.get("field"), "components")
	profile["composition_status"] = "unknown"
	assert_true(HealthDataValidatorScript.validate(_catalog([profile]))["valid"])


func test_known_same_unit_components_must_sum_to_the_portion() -> void:
	var exact := _valid_profile("exact_recipe")
	exact["composition_status"] = "known"
	exact["portion"] = {
		"status": "known",
		"label": "一份固定配方",
		"band": "medium",
		"value": 100.0,
		"unit": "g",
	}
	var component_a := _valid_component()
	component_a["amount_value"] = 60.0
	component_a["amount_unit"] = "g"
	var component_b := _valid_component()
	component_b["ingredient_id"] = "fixture_ingredient_b"
	component_b["amount_value"] = 40.0
	component_b["amount_unit"] = "g"
	exact["components"] = [component_a, component_b]
	var exact_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([exact]),
		{"known_food_ids": ["exact_recipe"]}
	)
	assert_true(bool(exact_report["valid"]))

	var mismatch := exact.duplicate(true)
	mismatch["food_id"] = "mismatched_recipe"
	(mismatch["components"][1] as Dictionary)["amount_value"] = 30.0
	var mismatch_report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([mismatch]),
		{"known_food_ids": ["mismatched_recipe"]}
	)
	assert_false(bool(mismatch_report["valid"]))
	assert_true(_codes(mismatch_report["errors"]).has("known_component_total_mismatch"))


func test_shared_ingredient_ids_must_keep_one_food_group() -> void:
	var first := _valid_profile("first_recipe")
	var first_component := _valid_component()
	first_component["ingredient_id"] = "shared_tomato"
	first_component["food_group"] = "vegetables"
	first["components"] = [first_component]
	var second := _valid_profile("second_recipe")
	var second_component := _valid_component()
	second_component["ingredient_id"] = "shared_tomato"
	second_component["food_group"] = "fruits"
	second["components"] = [second_component]
	var report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([first, second]),
		{"known_food_ids": ["first_recipe", "second_recipe"]}
	)
	assert_false(bool(report["valid"]))
	var conflicts := _issues_with_code(report["errors"], "ingredient_food_group_conflict")
	assert_eq(conflicts.size(), 1)
	assert_eq(String(conflicts[0]["field"]), "components[0].food_group")


func test_composite_food_requires_components_or_explicit_unknown() -> void:
	var profile := _valid_profile("composite_meal")
	profile["composition_status"] = "estimated"
	profile["components"] = []
	var context := {
		"known_food_ids": ["composite_meal"],
		"composite_food_ids": ["composite_meal"],
	}
	var blocked: Dictionary = HealthDataValidatorScript.validate(_catalog([profile]), context)
	assert_true(_codes(blocked["errors"]).has("composite_components_missing"))

	profile["composition_status"] = "unknown"
	var explicit_unknown: Dictionary = HealthDataValidatorScript.validate(
		_catalog([profile]),
		context
	)
	assert_true(bool(explicit_unknown["valid"]))
	assert_false(_codes(explicit_unknown["errors"]).has("composite_components_missing"))


func test_future_schema_is_a_blocking_catalog_error() -> void:
	var store := HealthDataStoreScript.new()
	var catalog: Dictionary = store.load_catalog("%s/future_schema.xml" % FIXTURE_ROOT)
	var report: Dictionary = HealthDataValidatorScript.validate(catalog)
	assert_false(bool(report["valid"]))
	assert_eq(int(report["error_count"]), 1)
	var issue: Dictionary = report["errors"][0]
	assert_eq(String(issue["code"]), "schema_version_future")
	assert_eq(String(issue["field"]), "schema_version")
	assert_eq(String(issue["path"]), "schema_version")


func test_warning_matrix_covers_unknown_composition_caffeine_product_and_evidence() -> void:
	var profile := _valid_profile("coffee_product")
	profile["composition_status"] = "estimated"
	var unknown_component := _valid_component()
	unknown_component["food_group"] = "unknown"
	unknown_component["contribution_band"] = "unknown"
	profile["components"] = [unknown_component]
	profile["cooking_methods"] = []
	profile["factors"] = []
	profile["evidence_refs"] = ["DEPRECATED-FIXTURE"]
	profile["caffeine"] = {
		"status": "",
		"band": "",
		"serving_time_relevance": "",
	}
	var report: Dictionary = HealthDataValidatorScript.validate(_catalog([profile]), {
		"known_food_ids": ["coffee_product"],
		"composite_food_ids": ["coffee_product"],
		"product_food_ids": ["coffee_product"],
		"display_names": {"coffee_product": "瓶装咖啡茶饮"},
		"deprecated_evidence_ids": ["DEPRECATED-FIXTURE"],
	})
	assert_true(bool(report["valid"]))
	var warning_codes := _codes(report["warnings"])
	for expected_code in [
		"profile_draft",
		"composite_components_all_unknown",
		"caffeine_status_missing",
		"product_label_or_recipe_pending_missing",
		"deprecated_evidence_reference",
	]:
		assert_true(warning_codes.has(expected_code), "missing warning: %s" % expected_code)


func test_missing_required_root_fields_are_blocking_and_located() -> void:
	var catalog := _catalog([])
	catalog["model_version"] = ""
	catalog["locale"] = ""
	catalog["reviewed_at"] = ""
	var report: Dictionary = HealthDataValidatorScript.validate(catalog)
	assert_false(bool(report["valid"]))
	assert_eq(_issues_with_code(report["errors"], "root_field_missing").size(), 3)
	assert_eq(
		_fields_for_code(report["errors"], "root_field_missing"),
		["model_version", "locale", "reviewed_at"]
	)


func test_malformed_container_fields_report_errors_without_crashing() -> void:
	var profile := _valid_profile("bad_containers")
	profile["portion"] = "not_a_dictionary"
	profile["components"] = "not_an_array"
	profile["factors"] = ["not_a_factor"]
	profile["cooking_methods"] = "not_an_array"
	profile["caffeine"] = "not_a_dictionary"
	var report: Dictionary = HealthDataValidatorScript.validate(
		_catalog([profile]),
		{"known_food_ids": ["bad_containers"]}
	)
	assert_false(bool(report["valid"]))
	var type_issues := _issues_with_code(report["errors"], "field_type_invalid")
	assert_eq(type_issues.size(), 5)
	assert_eq(
		_fields_for_code(report["errors"], "field_type_invalid"),
		["portion", "components", "factors[0]", "cooking_methods", "caffeine"]
	)


func _catalog(profiles: Array) -> Dictionary:
	var by_id := {}
	for profile_value in profiles:
		var profile: Dictionary = profile_value
		var food_id := String(profile.get("food_id", ""))
		if not food_id.is_empty() and not by_id.has(food_id):
			by_id[food_id] = profile.duplicate(true)
	return {
		"path": "fixture://validator",
		"status": "ready" if not profiles.is_empty() else "ready_empty",
		"available": true,
		"degraded": false,
		"schema_version": 1,
		"supported_schema_version": 1,
		"model_version": "fixture-validator-v1.0",
		"locale": "zh-CN",
		"reviewed_at": "2026-07-15",
		"profile_count": profiles.size(),
		"profile_entries": profiles.duplicate(true),
		"profiles": by_id,
		"warnings": [],
		"errors": [],
	}


func _valid_profile(food_id: String) -> Dictionary:
	return {
		"food_id": food_id,
		"profile_version": 1,
		"model_version": "fixture-validator-v1.0",
		"portion": {
			"status": "unknown",
			"label": "一份测试条目",
			"band": "unknown",
		},
		"basis_type": "unknown",
		"composition_status": "unknown",
		"components": [],
		"cooking_methods": [],
		"factors": [],
		"caffeine": {
			"status": "",
			"band": "",
			"serving_time_relevance": "",
		},
		"allergens": [],
		"food_safety": {},
		"confidence": "medium",
		"review_status": "draft",
		"evidence_refs": ["FIXTURE-EVIDENCE"],
		"reviewed_by": "",
		"reviewed_at": "",
	}


func _valid_component() -> Dictionary:
	return {
		"ingredient_id": "fixture_ingredient",
		"name": "测试原料",
		"food_group": "grains_tubers",
		"contribution_band": "material",
		"basis_type": "unknown",
		"confidence": "medium",
	}


func _valid_factor(factor_id: String, band: String) -> Dictionary:
	return {
		"factor_id": factor_id,
		"band": band,
		"basis_type": "unknown",
		"confidence": "medium",
		"evidence_refs": ["FIXTURE-EVIDENCE"],
	}


func _codes(issues: Array) -> Array[String]:
	var result: Array[String] = []
	for issue_value in issues:
		var code := String((issue_value as Dictionary).get("code", ""))
		if not result.has(code):
			result.append(code)
	return result


func _issues_with_code(issues: Array, code: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue_value in issues:
		var issue := issue_value as Dictionary
		if String(issue.get("code", "")) == code:
			result.append(issue)
	return result


func _first_issue(issues: Array, code: String) -> Dictionary:
	var matches := _issues_with_code(issues, code)
	return matches[0] if not matches.is_empty() else {}


func _fields_for_code(issues: Array, code: String) -> Array[String]:
	var result: Array[String] = []
	for issue in _issues_with_code(issues, code):
		result.append(String(issue.get("field", "")))
	return result
