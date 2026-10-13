@tool
extends McpTestSuite

const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Evaluator := preload("res://scripts/health/DietPatternEvaluator.gd")
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Store := preload("res://scripts/health/HealthDataStore.gd")
const Validator := preload("res://scripts/health/HealthDataValidator.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const DATE := "2026-10-08"
const ROOT := "res://tests/fixtures/g4_meal/"


func suite_name() -> String:
	return "g4_meal"


func test_isolated_fixtures_are_valid_and_production_stays_unapproved() -> void:
	assert_true(Validator.validate(_catalog())["valid"])
	assert_true(_registry().audit(DATE)["registry_available"])
	var catalog := Store.new().load_catalog()
	for profile in catalog["profiles"].values():
		assert_eq(profile["review_status"], "draft")
	var production_registry := Evidence.new()
	production_registry.load_registry()
	assert_false(production_registry.has_evidence("FIXTURE-EDUCATION"))
	var copy := Composer.load_catalog()
	assert_true(copy["valid"], str(copy["errors"]))
	assert_eq(copy["copies"]["MEAL_COMPOSITION_RECORDED"]["review_status"], "draft")


func test_known_roles_do_not_claim_portion_adequacy() -> void:
	var result := _evaluate(["fixture_rice", "fixture_egg", "fixture_vegetable"])
	assert_true(result["valid"], str(result["errors"]))
	var structure: Dictionary = result["dimensions"]["plate_structure"]
	assert_eq(structure["status"], "supported")
	assert_eq(structure["roles"]["staple"]["presence"], "dominant")
	assert_eq(structure["roles"]["vegetable"]["presence"], "material")
	assert_eq(structure["roles"]["protein_source"]["presence"], "material")
	assert_eq(result["data_quality"]["status"], "partial")
	assert_eq(result["data_quality"]["unknown_portion_food_ids"].size(), 3)
	assert_eq(result["primary_suggestion"], null)
	_assert_no_prohibited_output(result)


func test_composite_and_single_cards_share_ingredient_identities() -> void:
	var combined := _evaluate(["fixture_mixed", "fixture_rice", "fixture_egg", "fixture_vegetable"])
	var single := _evaluate(["fixture_rice", "fixture_egg", "fixture_vegetable"])
	assert_eq(combined["dimensions"]["plate_structure"], single["dimensions"]["plate_structure"])
	assert_eq(combined["ingredients"].size(), 4)
	var rice := _ingredient(combined, "shared_rice")
	assert_eq(rice["food_ids"], ["fixture_mixed", "fixture_rice"])
	assert_eq(combined["dimensions"]["diversity"]["status"], "not_evaluated")


func test_order_independence_and_input_output_deep_copy() -> void:
	var snapshot := _snapshot(["fixture_mixed", "fixture_rice"])
	var original := snapshot.duplicate(true)
	var cfg := _config()
	var original_config := cfg.duplicate(true)
	var first := Evaluator.evaluate(snapshot, cfg, _registry(), DATE)
	var reversed_snapshot := _snapshot(["fixture_rice", "fixture_mixed"])
	var second := Evaluator.evaluate(reversed_snapshot, cfg, _registry(), DATE)
	assert_eq(first["ingredients"], second["ingredients"])
	assert_eq(first["dimensions"], second["dimensions"])
	first["ingredients"][0]["food_ids"].append("changed")
	assert_eq(snapshot, original)
	assert_eq(cfg, original_config)


func test_fruit_dairy_and_beverages_do_not_fill_core_roles_or_hydration() -> void:
	var result := _evaluate(["fixture_fruit", "fixture_dairy"])
	for role in result["dimensions"]["plate_structure"]["roles"].values():
		assert_eq(role["presence"], "not_recorded")
	assert_eq(result["separate_food_groups"]["fruits"], ["fixture_apple"])
	assert_eq(result["separate_food_groups"]["dairy"], ["fixture_milk"])
	assert_false(result.has("hydration"))


func test_trace_small_and_material_are_distinct_and_known_addition_is_monotonic() -> void:
	var small := _evaluate(["fixture_rice", "fixture_small_vegetable"])
	assert_eq(small["dimensions"]["plate_structure"]["roles"]["vegetable"]["presence"], "small")
	var more := _evaluate(["fixture_rice", "fixture_small_vegetable", "fixture_vegetable"])
	assert_eq(more["dimensions"]["plate_structure"]["roles"]["vegetable"]["presence"], "material")
	var catalog := _catalog()
	catalog["profiles"]["fixture_vegetable"]["components"][0]["contribution_band"] = "trace"
	var trace := Evaluator.evaluate(_snapshot(["fixture_rice", "fixture_vegetable"], catalog), _config(), _registry(), DATE)
	assert_true(trace["valid"])
	assert_eq(trace["dimensions"]["plate_structure"]["roles"]["vegetable"]["presence"], "not_recorded")


func test_missing_and_low_confidence_keep_known_clues_and_unknown_absences() -> void:
	var missing := _evaluate(["fixture_rice", "missing_food"])
	assert_eq(missing["dimensions"]["plate_structure"]["status"], "partial")
	assert_eq(missing["dimensions"]["plate_structure"]["roles"]["staple"]["presence"], "dominant")
	assert_eq(missing["dimensions"]["plate_structure"]["roles"]["vegetable"]["presence"], "unknown")
	assert_eq(missing["data_quality"]["unknown_food_ids"], ["missing_food"])
	var low := _evaluate(["fixture_rice", "fixture_low"])
	assert_eq(low["dimensions"]["plate_structure"]["status"], "partial")
	assert_eq(low["food_group_ids"], ["grains_tubers"])
	assert_eq(low["data_quality"]["unknown_food_ids"], ["fixture_low"])


func test_draft_profile_and_missing_reviewer_cannot_become_positive_records() -> void:
	for key in ["review_status", "reviewed_by", "reviewed_at"]:
		var catalog := _catalog()
		catalog["profiles"]["fixture_egg"][key] = "draft" if key == "review_status" else ""
		var result := Evaluator.evaluate(_snapshot(["fixture_rice", "fixture_egg"], catalog), _config(), _registry(), DATE)
		assert_eq(result["dimensions"]["plate_structure"]["status"], "partial")
		assert_eq(result["dimensions"]["plate_structure"]["roles"]["protein_source"]["presence"], "unknown")
		if result["provenance"]["profiles"].has("fixture_egg"):
			assert_false(result["provenance"]["profiles"]["fixture_egg"]["allowed"])
		else:
			assert_true(result["data_quality"]["unknown_food_ids"].has("fixture_egg"))


func test_config_draft_future_version_and_bad_mapping_are_blocked() -> void:
	var snapshot := _snapshot(["fixture_mixed"])
	var pending := Evaluator.evaluate(snapshot, Config.defaults(), _registry(), DATE)
	assert_true(pending["valid"])
	assert_eq(pending["dimensions"]["plate_structure"]["status"], "unknown")
	for pair in [["schema_version", 2], ["rules_version", "future-v2"], ["model_version", "future-model-v3"]]:
		var cfg := _config()
		cfg[pair[0]] = pair[1]
		assert_false(Evaluator.evaluate(snapshot, cfg, _registry(), DATE)["valid"])
	var mapping := _config()
	mapping["role_by_group"]["fruits"] = "vegetable"
	assert_false(Config.validate(mapping)["valid"])


func test_expired_invalid_date_or_wrong_capability_blocks_composition() -> void:
	var snapshot := _snapshot(["fixture_mixed"])
	for date in ["2027-01-01", "2026-02-30", "not-a-date"]:
		assert_eq(Evaluator.evaluate(snapshot, _config(), _registry(), date)["dimensions"]["plate_structure"]["status"], "unknown")
	var cfg := _config()
	cfg["evidence_refs"] = ["FIXTURE-RECIPE"]
	var result := Evaluator.evaluate(snapshot, cfg, _registry(), DATE)
	assert_eq(result["dimensions"]["plate_structure"]["status"], "unknown")
	assert_contains(str(result["provenance"]["config_evidence"]["unsupported_capabilities"]), "MEAL_DIVERSITY_EDUCATION")


func test_skipped_legacy_unavailable_and_future_snapshots_have_distinct_states() -> void:
	var skipped := Snapshot.build(1, {"phase": "breakfast", "skipped": true})
	var result := Evaluator.evaluate(skipped, _config(), _registry(), DATE)
	assert_eq(result["dimensions"]["regularity"]["status"], "attention")
	assert_eq(result["dimensions"]["plate_structure"]["status"], "not_applicable")
	var legacy := Evaluator.evaluate(Snapshot.legacy(1, {"phase": "breakfast", "quality": 86}), _config(), _registry(), DATE)
	assert_eq(legacy["copy_id"], "MEAL_LEGACY_UNKNOWN")
	var unavailable := Evaluator.evaluate(_snapshot(["missing_food"]), _config(), _registry(), DATE)
	assert_eq(unavailable["copy_id"], "MEAL_COMPOSITION_UNKNOWN")
	var future := _snapshot(["fixture_rice"])
	future["snapshot_schema_version"] = 2
	assert_false(Evaluator.evaluate(future, _config(), _registry(), DATE)["valid"])


func test_frozen_model_and_profile_inputs_do_not_reload_current_data() -> void:
	var catalog := _catalog()
	var snapshot := _snapshot(["fixture_mixed"], catalog)
	var before := Evaluator.evaluate(snapshot, _config(), _registry(), DATE)
	catalog["profiles"]["fixture_mixed"]["components"].clear()
	catalog["profiles"]["fixture_mixed"]["profile_version"] = 99
	assert_eq(Evaluator.evaluate(snapshot, _config(), _registry(), DATE), before)
	snapshot["model_version"] = "future-model-v3"
	assert_false(Evaluator.evaluate(snapshot, _config(), _registry(), DATE)["valid"])


func test_gameplay_or_score_inputs_are_rejected_and_no_factor_threshold_is_invented() -> void:
	for key in ["energy", "stress", "cost", "quality", "grade", "recovery_state", "character_health"]:
		var snapshot := _snapshot(["fixture_mixed"])
		snapshot[key] = 50
		assert_false(Evaluator.evaluate(snapshot, _config(), _registry(), DATE)["valid"], key)
	var result := _evaluate(["fixture_mixed"])
	assert_eq(result["dimensions"]["attention_factors"]["status"], "not_evaluated")
	_assert_no_prohibited_output(result)


func test_composer_only_uses_reviewed_copy_with_explicit_player_capability() -> void:
	var snapshot := _snapshot(["fixture_rice", "fixture_egg", "fixture_vegetable"])
	var blocked := Composer.compose_meal(snapshot, _config(), _registry(), DATE, Composer.load_catalog())
	assert_eq(blocked["primary"]["kind"], "boundary")
	assert_false(blocked["copy_allowed"])
	var approved := Composer.compose_meal(snapshot, _config(), _registry(), DATE, _copy())
	assert_true(approved["copy_allowed"], str(approved["reason_ids"]))
	assert_contains(approved["primary"]["text"], "主食、蔬菜、蛋类")
	assert_false(approved["primary"]["text"].contains("足够"))
	var only_internal := _copy()
	for id in Composer.NUTRITION_IDS:
		only_internal["copies"][id]["evidence_refs"] = "FIXTURE-RECIPE"
	var rejected := Composer.compose_meal(snapshot, _config(), _registry(), DATE, only_internal)
	assert_false(rejected["copy_allowed"])
	assert_contains(str(rejected["copy_evidence"]["unsupported_capabilities"]), "PLAYER_GUIDANCE")


func test_partial_and_unknown_composer_paths_do_not_guess_missing_roles() -> void:
	var partial := Composer.compose_meal(_snapshot(["fixture_rice", "missing_food"]), _config(), _registry(), DATE, _copy())
	assert_contains(partial["primary"]["text"], "主食")
	assert_contains(partial["primary"]["text"], "其他配料没写全")
	assert_false(partial["primary"]["text"].contains("没有蔬菜"))
	var draft := Composer.compose_meal(_snapshot(["fixture_mixed"]), Config.defaults(), _registry(), DATE, _copy())
	assert_eq(draft["primary"]["kind"], "boundary")
	assert_false(draft["primary"]["text"].contains("主食"))
	assert_eq(draft["primary_suggestion"], null)


func test_copy_variables_versions_and_catalog_claimed_validity_cannot_bypass_checks() -> void:
	for change in ["unknown_variable", "wrong_type", "missing_copy", "wrong_model"]:
		var copy := _copy()
		match change:
			"unknown_variable": copy["copies"]["MEAL_COMPOSITION_RECORDED"]["text"] = "{energy}"
			"wrong_type": copy["copies"]["MEAL_COMPOSITION_UNKNOWN"]["type"] = "nutrition_observation"
			"missing_copy": copy["copies"].erase("MEAL_LEGACY_UNKNOWN")
			"wrong_model": copy["model_version"] = "future-model-v3"
		copy["valid"] = true
		var result := Composer.compose_meal(_snapshot(["fixture_mixed"]), _config(), _registry(), DATE, copy)
		assert_false(result["valid"], change)
		assert_eq(result["primary"]["kind"], "boundary")


func test_production_draft_profiles_and_defaults_never_emit_affirmative_copy() -> void:
	var catalog := Store.new().load_catalog()
	var registry := Evidence.new()
	registry.load_registry()
	var snapshot := _snapshot(["rice_plain", "egg", "tomato", "chicken_vegetable_rice"], catalog)
	var result := Composer.compose_meal(snapshot, Config.defaults(), registry, DATE, Composer.load_catalog())
	assert_true(result["valid"])
	assert_eq(result["primary"]["id"], "MEAL_COMPOSITION_UNKNOWN")
	assert_eq(result["evaluation"]["observations"], [])
	assert_false(result["primary"]["text"].contains("均衡"))


func test_boundary_templates_cannot_be_relabelled_to_bypass_nutrition_approval() -> void:
	var copy := _copy()
	copy["copies"]["MEAL_COMPOSITION_UNKNOWN"]["text"] = "营养均衡，份量足够。"
	copy["valid"] = true
	var result := Composer.compose_meal(_snapshot(["fixture_rice"]), Config.defaults(), _registry(), DATE, copy)
	assert_false(result["valid"])
	assert_eq(result["primary"]["text"], Composer.FALLBACK)
	assert_false(result["copy_allowed"])


func test_future_or_missing_copy_review_metadata_and_expiry_cannot_authorize_text() -> void:
	for field in ["reviewed_at", "reviewed_by", "review_status"]:
		var copy := _copy()
		for id in Composer.NUTRITION_IDS:
			copy["copies"][id][field] = "2026-12-01" if field == "reviewed_at" else ("needs_update" if field == "review_status" else "")
		var result := Composer.compose_meal(_snapshot(["fixture_mixed"]), _config(), _registry(), DATE, copy)
		assert_eq(result["primary"]["kind"], "boundary")
		assert_false(result["copy_allowed"])


func test_approved_evidence_missing_or_superseded_references_do_not_get_substituted() -> void:
	var catalog := _catalog()
	catalog["profiles"]["fixture_rice"]["evidence_refs"] = ["MISSING-REFERENCE"]
	var result := Evaluator.evaluate(_snapshot(["fixture_rice"], catalog), _config(), _registry(), DATE)
	assert_eq(result["copy_id"], "MEAL_COMPOSITION_UNKNOWN")
	assert_contains(str(result["provenance"]["profiles"]["fixture_rice"]["evidence_check"]["missing_ids"]), "MISSING-REFERENCE")
	catalog = _catalog()
	catalog["profiles"]["fixture_rice"]["evidence_refs"] = ["FIXTURE-OLD"]
	result = Evaluator.evaluate(_snapshot(["fixture_rice"], catalog), _config(), _registry(), DATE)
	assert_eq(result["copy_id"], "MEAL_COMPOSITION_UNKNOWN")
	assert_eq(result["provenance"]["profiles"]["fixture_rice"]["evidence_check"]["replacement_ids"]["FIXTURE-OLD"], "FIXTURE-RECIPE")
	assert_false(result["provenance"]["profiles"]["fixture_rice"]["allowed"])


func test_copy_file_parser_rejects_duplicate_ids_and_unsupported_schema() -> void:
	var contents := FileAccess.get_file_as_string(Composer.DEFAULT_PATH)
	var path := "res://.godot/g4-copy-invalid.xml"
	for mutation in [contents.replace("MEAL_COMPOSITION_PARTIAL", "MEAL_COMPOSITION_RECORDED"), contents.replace('schema_version="1"', 'schema_version="2"'), "<guidance_copy><copy>"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(mutation)
		file.close()
		assert_false(Composer.load_catalog(path)["valid"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_parsed_copy_errors_cannot_be_hidden_by_changing_the_valid_flag() -> void:
	var copy := _copy()
	copy["errors"].append("copy_element_unexpected")
	copy["valid"] = true
	assert_false(Composer.compose_meal(_snapshot(["fixture_mixed"]), _config(), _registry(), DATE, copy)["valid"])
	copy = _copy()
	copy["schema_version"] = 2
	copy["valid"] = true
	assert_false(Composer.compose_meal(_snapshot(["fixture_mixed"]), _config(), _registry(), DATE, copy)["valid"])


func test_reliable_trace_in_another_dish_cannot_erase_material_composition() -> void:
	var catalog := _catalog()
	catalog["profiles"]["fixture_vegetable"]["confidence"] = "medium"
	catalog["profiles"]["fixture_vegetable"]["components"][0]["confidence"] = "medium"
	catalog["profiles"]["fixture_small_vegetable"]["components"][0]["contribution_band"] = "trace"
	var before := Evaluator.evaluate(_snapshot(["fixture_vegetable"], catalog), _config(), _registry(), DATE)
	var after := Evaluator.evaluate(_snapshot(["fixture_vegetable", "fixture_small_vegetable"], catalog), _config(), _registry(), DATE)
	assert_true(before["valid"] and after["valid"])
	assert_eq(after["dimensions"]["plate_structure"], before["dimensions"]["plate_structure"])
	assert_eq(after["dimensions"]["plate_structure"]["roles"]["vegetable"]["presence"], "material")
	assert_eq(_ingredient(after, "shared_tomato")["selected_food_id"], "fixture_vegetable")


func _catalog() -> Dictionary:
	return Store.new().load_catalog(ROOT + "profiles.xml")


func _registry() -> Evidence:
	var registry := Evidence.new()
	registry.load_registry(ROOT + "evidence.xml")
	return registry


func _config() -> Dictionary:
	var cfg := Config.defaults()
	cfg.merge({"review_status": "expert_reviewed", "reviewed_by": "fixture-only", "reviewed_at": "2026-10-01", "evidence_refs": ["FIXTURE-EDUCATION"]}, true)
	return cfg


func _copy() -> Dictionary:
	var catalog := Composer.load_catalog()
	for id in Composer.NUTRITION_IDS:
		catalog["copies"][id].merge({"review_status": "expert_reviewed", "reviewed_by": "fixture-only", "reviewed_at": "2026-10-01", "evidence_refs": "FIXTURE-EDUCATION"}, true)
	return catalog


func _snapshot(ids: Array, catalog: Dictionary = {}) -> Dictionary:
	if catalog.is_empty():
		catalog = _catalog()
	return Snapshot.build(1, {"phase": "lunch", "food_ids": ids, "source_id": "fixture_source"}, catalog)


func _evaluate(ids: Array) -> Dictionary:
	return Evaluator.evaluate(_snapshot(ids), _config(), _registry(), DATE)


func _ingredient(result: Dictionary, id: String) -> Dictionary:
	for ingredient in result["ingredients"]:
		if ingredient["ingredient_id"] == id:
			return ingredient
	return {}


func _assert_no_prohibited_output(value: Variant) -> void:
	if value is Dictionary:
		for key in value:
			assert_false(["total_score", "quality", "grade", "diagnosis", "deficiency", "disease_risk", "healthy", "unhealthy"].has(key))
			_assert_no_prohibited_output(value[key])
	elif value is Array:
		for child in value:
			_assert_no_prohibited_output(child)
