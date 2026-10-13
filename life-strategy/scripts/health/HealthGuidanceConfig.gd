class_name HealthGuidanceConfig
extends RefCounted

## G4A1: composition only. Default editorial/model approval is still pending.
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const SCHEMA_VERSION := 1
const MODEL_VERSION := "diet-pattern-v2.0"
const RULES_VERSION := "meal-composition-v1"
const ROLE_BY_GROUP := {
	"grains_tubers": "staple", "vegetables": "vegetable",
	"eggs": "protein_source", "soy_products": "protein_source",
	"poultry_livestock": "protein_source", "fish_seafood": "protein_source",
}
const SEPARATE_GROUPS := ["fruits", "dairy", "nuts_seeds", "beverages"]
const BANDS := {"unknown": 0, "trace": 1, "small": 2, "material": 3, "dominant": 4}
const CONFIDENCE := {"unknown": 0, "low": 1, "medium": 2, "high": 3}
const REQUIRED_CAPABILITIES := ["MEAL_DIVERSITY_EDUCATION"]


static func defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "model_version": MODEL_VERSION,
		"rules_version": RULES_VERSION, "scope": "meal_composition",
		"review_status": "draft", "reviewed_by": "", "reviewed_at": "",
		"evidence_refs": ["CDG-2022-DIVERSITY"],
		"role_by_group": ROLE_BY_GROUP.duplicate(true),
		"separate_groups": SEPARATE_GROUPS.duplicate(),
	}


static func validate(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not value is Dictionary:
		return {"valid": false, "errors": ["config_not_dictionary"]}
	var data: Dictionary = value
	var expected := defaults().keys()
	if data.size() != expected.size():
		errors.append("config_keys_invalid")
	for key in data:
		if not expected.has(key):
			errors.append("config_unknown_key")
	for key in expected:
		if not data.has(key):
			errors.append("config_field_missing:" + key)
	if not errors.is_empty():
		return {"valid": false, "errors": errors}
	if typeof(data["schema_version"]) != TYPE_INT or data["schema_version"] != SCHEMA_VERSION:
		errors.append("config_schema_unsupported")
	for pair in [["model_version", MODEL_VERSION], ["rules_version", RULES_VERSION], ["scope", "meal_composition"]]:
		if data[pair[0]] != pair[1]:
			errors.append("config_version_or_scope_unsupported")
	if data["role_by_group"] != ROLE_BY_GROUP or data["separate_groups"] != SEPARATE_GROUPS:
		errors.append("config_mapping_requires_new_rules_version")
	if data["review_status"] not in ["draft", "expert_reviewed", "needs_update"]:
		errors.append("config_review_status_invalid")
	for key in ["reviewed_by", "reviewed_at"]:
		if not data[key] is String:
			errors.append("config_review_field_invalid")
	if not string_ids(data["evidence_refs"]):
		errors.append("config_evidence_refs_invalid")
	return {"valid": errors.is_empty(), "errors": errors}


static func approval(data: Dictionary, registry: Evidence, date: String, capabilities: Array) -> Dictionary:
	var reasons: Array[String] = []
	if data.get("review_status") != "expert_reviewed":
		reasons.append("review_pending")
	if not data.get("reviewed_by") is String or String(data.get("reviewed_by", "")).strip_edges().is_empty():
		reasons.append("reviewer_missing")
	var reviewed: Variant = data.get("reviewed_at")
	if not reviewed is String or not Evidence._is_valid_iso_date(reviewed) or reviewed > date:
		reasons.append("review_date_invalid")
	if registry == null or not Evidence._is_valid_iso_date(date):
		reasons.append("evidence_context_invalid")
		return {"allowed": false, "reason_ids": reasons, "evidence_check": {}}
	var refs: Variant = data.get("evidence_refs")
	if not string_ids(refs) or capabilities.is_empty():
		reasons.append("evidence_requirements_missing")
		return {"allowed": false, "reason_ids": reasons, "evidence_check": {}}
	var check := registry.check_references(refs, date, capabilities)
	if not check["valid"]:
		reasons.append("evidence_unusable_or_unsupported")
	return {"allowed": reasons.is_empty(), "reason_ids": reasons, "evidence_check": check}


static func string_ids(value: Variant) -> bool:
	if not value is Array or value.is_empty():
		return false
	var seen := {}
	for entry in value:
		if not entry is String or entry.strip_edges().is_empty() or seen.has(entry):
			return false
		seen[entry] = true
	return true
