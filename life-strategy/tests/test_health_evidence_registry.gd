@tool
extends McpTestSuite

const HealthEvidenceRegistryScript := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const FIXTURE_ROOT := "res://tests/fixtures/health_evidence_registry"


func suite_name() -> String:
	return "health_evidence_registry"


func test_production_registry_loads_official_sources_and_explicit_boundaries() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	var result: Dictionary = registry.load_registry()
	assert_eq(String(result["status"]), HealthEvidenceRegistryScript.STATUS_READY)
	assert_true(bool(result["available"]))
	assert_eq(int(result["schema_version"]), 1)
	assert_eq(String(result["registry_version"]), "2026.07.20")
	assert_eq(int(result["unique_evidence_count"]), 13)
	for evidence_id in [
		"CDG-2022-DIVERSITY",
		"CDG-2022-03",
		"CDG-2022-05",
		"CDG-2022-06",
		"CDG-2022-07",
		"WHO-HD-2026",
		"CDC-SLEEP",
		"GB28050-2025-QA",
		"GB28050-2025-ANN",
		"GAME-SPEC-204B-V1",
		"GAME-SPEC-204C-V1",
		"GAME-SPEC-204D-V1",
		"PRODUCT-RECIPE-PENDING",
	]:
		assert_true(registry.has_evidence(evidence_id), "missing evidence: %s" % evidence_id)

	var label_qa: Dictionary = registry.get_evidence("GB28050-2025-QA")
	assert_eq(String(label_qa["effective_at"]), "2027-03-16")
	assert_true(String(label_qa["url"]).begins_with("https://www.nhc.gov.cn/"))
	assert_true((label_qa["does_not_support"] as Array).has(
		"GB28050_2025_CURRENT_FULL_ENFORCEMENT_BEFORE_2027_03_16"
	))
	var sleep: Dictionary = registry.get_evidence("CDC-SLEEP")
	assert_eq(String(sleep["status"]), "needs_review")
	assert_true((sleep["does_not_support"] as Array).has(
		"TARGET_AGE_SLEEP_DURATION_UNTIL_DECIDED"
	))
	var game_spec: Dictionary = registry.get_evidence("GAME-SPEC-204B-V1")
	assert_eq(String(game_spec["source_type"]), "internal_game_spec")
	assert_eq(String(game_spec["url"]), "")
	assert_true((game_spec["supports"] as Array).has("SIMULATED_MENU_RECIPE"))
	assert_true((game_spec["does_not_support"] as Array).has("PLAYER_GUIDANCE"))
	assert_true((game_spec["does_not_support"] as Array).has("EXPERT_REVIEW"))
	var composite_spec: Dictionary = registry.get_evidence("GAME-SPEC-204C-V1")
	assert_eq(String(composite_spec["source_type"]), "internal_game_spec")
	assert_eq(String(composite_spec["url"]), "")
	assert_true((composite_spec["supports"] as Array).has(
		"SIMULATED_INGREDIENT_COMPOSITION"
	))
	assert_true((composite_spec["does_not_support"] as Array).has(
		"ALLERGEN_COMPLETENESS"
	))
	var composition_check: Dictionary = registry.check_references(
		["GAME-SPEC-204C-V1"],
		"2026-07-20",
		["SIMULATED_INGREDIENT_COMPOSITION"]
	)
	assert_true(bool(composition_check["valid"]))
	var guidance_check: Dictionary = registry.check_references(
		["GAME-SPEC-204C-V1"],
		"2026-07-20",
		["PLAYER_GUIDANCE"]
	)
	assert_false(bool(guidance_check["valid"]))
	assert_eq(guidance_check["unsupported_capabilities"], ["PLAYER_GUIDANCE"])
	assert_eq(
		(guidance_check["explicitly_unsupported_ids_by_capability"] as Dictionary)[
			"PLAYER_GUIDANCE"
		],
		["GAME-SPEC-204C-V1"]
	)


func test_nut_204d_game_spec_supports_simulated_labels_but_not_release_claims() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry()
	var evidence_id := "GAME-SPEC-204D-V1"
	var game_spec: Dictionary = registry.get_evidence(evidence_id)
	assert_eq(String(game_spec["source_type"]), "internal_game_spec")
	assert_eq(String(game_spec["url"]), "")
	var simulated_capabilities := [
		"SHARED_INGREDIENT_IDENTITY",
		"SIMULATED_COOKING_METHOD",
		"SIMULATED_FACTOR_INPUT",
		"SIMULATED_INGREDIENT_COMPOSITION",
		"SIMULATED_PACKAGE_LABEL",
		"SIMULATED_PORTION",
	]
	for capability in simulated_capabilities:
		assert_true((game_spec["supports"] as Array).has(capability))
	var simulated_check: Dictionary = registry.check_references(
		[evidence_id],
		"2026-07-20",
		simulated_capabilities
	)
	assert_true(bool(simulated_check["valid"]))

	for unsupported_capability in [
		"REAL_PRODUCT_COMPOSITION",
		"REAL_PRODUCT_LABEL",
		"HEALTH_THRESHOLD",
		"PLAYER_GUIDANCE",
		"EXPERT_REVIEW",
		"ALLERGEN_COMPLETENESS",
		"FOOD_SAFETY",
		"REGULATORY_LABEL_COMPLIANCE",
		"MEDICAL_OUTCOME",
	]:
		assert_true((game_spec["does_not_support"] as Array).has(unsupported_capability))
		var unsupported_check: Dictionary = registry.check_references(
			[evidence_id],
			"2026-07-20",
			[unsupported_capability]
		)
		assert_false(bool(unsupported_check["valid"]))
		assert_eq(unsupported_check["unsupported_capabilities"], [unsupported_capability])
		assert_eq(
			(unsupported_check["explicitly_unsupported_ids_by_capability"] as Dictionary)[
				unsupported_capability
			],
			[evidence_id]
		)


func test_production_registry_audit_reports_review_due_at_without_overdue_sources() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry()
	var report: Dictionary = registry.audit("2026-07-20")
	assert_true(bool(report["valid"]))
	assert_eq(int(report["error_count"]), 0)
	assert_true((report["review_due_ids"] as Array).is_empty())
	assert_eq(String(report["next_review_due_at"]), "2026-08-15")
	assert_eq(
		String((report["review_due_at_by_id"] as Dictionary)["CDG-2022-DIVERSITY"]),
		"2026-10-15"
	)
	assert_true((report["needs_review_ids"] as Array).has("CDC-SLEEP"))
	assert_true((report["needs_review_ids"] as Array).has("PRODUCT-RECIPE-PENDING"))


func test_reference_check_detects_missing_due_and_needs_review_records() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry("%s/lifecycle.xml" % FIXTURE_ROOT)
	var report: Dictionary = registry.check_references(
		["ACTIVE", "DUE", "NEEDS", "DOES-NOT-EXIST"],
		"2026-07-15"
	)
	assert_false(bool(report["valid"]))
	assert_eq(report["usable_ids"], ["ACTIVE"])
	assert_eq(report["review_due_ids"], ["DUE"])
	assert_eq(report["needs_review_ids"], ["NEEDS"])
	assert_eq(report["missing_ids"], ["DOES-NOT-EXIST"])
	assert_eq(
		report["unusable_ids"],
		["DOES-NOT-EXIST", "DUE", "NEEDS"]
	)


func test_reference_check_requires_positive_capability_support() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry("%s/lifecycle.xml" % FIXTURE_ROOT)
	var supported: Dictionary = registry.check_references(
		["ACTIVE"],
		"2026-07-15",
		["FIXTURE_ACTIVE"]
	)
	assert_true(bool(supported["valid"]))
	assert_eq(
		(supported["supporting_ids_by_capability"] as Dictionary)["FIXTURE_ACTIVE"],
		["ACTIVE"]
	)

	var unsupported: Dictionary = registry.check_references(
		["ACTIVE"],
		"2026-07-15",
		["FIXTURE_LIMIT"]
	)
	assert_false(bool(unsupported["valid"]))
	assert_eq(unsupported["required_capabilities"], ["FIXTURE_LIMIT"])
	assert_eq(unsupported["unsupported_capabilities"], ["FIXTURE_LIMIT"])
	assert_eq(
		(unsupported["explicitly_unsupported_ids_by_capability"] as Dictionary)[
			"FIXTURE_LIMIT"
		],
		["ACTIVE"]
	)

	var union_support: Dictionary = registry.check_references(
		["ACTIVE", "CURRENT"],
		"2026-07-15",
		["FIXTURE_CURRENT"]
	)
	assert_true(bool(union_support["valid"]))
	assert_eq(
		(union_support["supporting_ids_by_capability"] as Dictionary)["FIXTURE_CURRENT"],
		["CURRENT"]
	)


func test_same_capability_cannot_be_supported_and_denied_by_one_record() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry("%s/capability_conflict.xml" % FIXTURE_ROOT)
	var report: Dictionary = registry.audit("2026-07-20")
	assert_false(bool(report["valid"]))
	assert_eq(int(report["error_count"]), 1)
	var issue := (report["errors"] as Array)[0] as Dictionary
	assert_eq(String(issue["code"]), "support_boundary_conflict")
	assert_eq(String(issue["evidence_id"]), "CONFLICT")


func test_superseded_reference_reports_full_replacement_chain_and_current_id() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry("%s/lifecycle.xml" % FIXTURE_ROOT)
	var report: Dictionary = registry.check_references(["OLD"], "2026-07-15")
	assert_false(bool(report["valid"]))
	assert_eq(report["superseded_ids"], ["OLD"])
	assert_eq(
		(report["replacement_chains"] as Dictionary)["OLD"],
		["OLD", "MIDDLE", "CURRENT"]
	)
	assert_eq(String((report["replacement_ids"] as Dictionary)["OLD"]), "CURRENT")
	assert_eq(registry.get_replacement_chain("OLD"), ["OLD", "MIDDLE", "CURRENT"])


func test_due_date_is_inclusive_and_next_review_is_reported() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry("%s/lifecycle.xml" % FIXTURE_ROOT)
	var before_due: Dictionary = registry.check_references(["DUE"], "2026-07-14")
	assert_true(bool(before_due["valid"]))
	var on_due: Dictionary = registry.check_references(["DUE"], "2026-07-15")
	assert_false(bool(on_due["valid"]))
	assert_eq(on_due["review_due_ids"], ["DUE"])
	var audit_report: Dictionary = registry.audit("2026-07-15")
	assert_eq(String(audit_report["earliest_review_due_at"]), "2026-07-15")
	assert_eq(String(audit_report["next_review_due_at"]), "2026-08-15")


func test_future_schema_fails_closed_without_partial_records() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	var result: Dictionary = registry.load_registry("%s/future_schema.xml" % FIXTURE_ROOT)
	assert_eq(
		String(result["status"]),
		HealthEvidenceRegistryScript.STATUS_UNSUPPORTED_FUTURE_SCHEMA
	)
	assert_false(bool(result["available"]))
	assert_true(bool(result["degraded"]))
	assert_eq(int(result["unique_evidence_count"]), 0)
	assert_false(registry.has_evidence("MUST_NOT_LOAD"))
	var audit_report: Dictionary = registry.audit("2026-07-15")
	assert_false(bool(audit_report["valid"]))
	assert_eq(String((audit_report["errors"] as Array)[0]["code"]), "registry_unavailable")


func test_invalid_as_of_date_fails_safely() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry("%s/lifecycle.xml" % FIXTURE_ROOT)
	var audit_report: Dictionary = registry.audit("2026-02-30")
	assert_false(bool(audit_report["valid"]))
	assert_false(bool(audit_report["as_of_date_valid"]))
	assert_eq(String((audit_report["errors"] as Array)[0]["code"]), "as_of_date_invalid")
	var reference_report: Dictionary = registry.check_references(["ACTIVE"], "not-a-date")
	assert_false(bool(reference_report["valid"]))
	assert_true((reference_report["usable_ids"] as Array).is_empty())


func test_public_records_and_reports_are_deep_copies() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	var loaded: Dictionary = registry.load_registry("%s/lifecycle.xml" % FIXTURE_ROOT)
	var record: Dictionary = registry.get_evidence("ACTIVE")
	(record["supports"] as Array).clear()
	(loaded["evidence"] as Dictionary).clear()
	var audit_report: Dictionary = registry.audit("2026-07-15")
	(audit_report["review_due_at_by_id"] as Dictionary).clear()
	assert_eq((registry.get_evidence("ACTIVE")["supports"] as Array).size(), 1)
	assert_eq(int(registry.get_registry()["unique_evidence_count"]), 6)
	assert_false((registry.audit("2026-07-15")["review_due_at_by_id"] as Dictionary).is_empty())
