class_name MealHealthSnapshot
extends RefCounted

## Captures historical inputs, not health judgments. Returned data never shares
## containers with the live catalog or gameplay record. The archive owns another
## deep copy and never reloads current profiles when reading historical records.

const ValidatorScript := preload("res://scripts/health/HealthDataValidator.gd")
const SCHEMA_VERSION := 1
const MAX_JSON_INTEGER := 9007199254740991
const MEAL_PHASES := ["breakfast", "lunch", "dinner"]
const CONFIDENCES := ["unknown", "low", "medium", "high"]
const PROFILE_FIELDS := [
	"food_id", "profile_version", "model_version", "portion", "basis_type",
	"composition_status", "components", "cooking_methods", "factors", "caffeine",
	"allergens", "food_safety", "confidence", "review_status", "evidence_refs",
	"reviewed_by", "reviewed_at",
]
const FORBIDDEN_FIELDS := [
	"quality", "average_quality", "nutrition_score", "health_score", "cost",
	"total_cost", "mood", "energy", "burden", "diet_burden", "stat_delta",
	"tags", "food_groups", "nutrient_tags", "limit_tags",
]


static func build(day: int, record: Dictionary, catalog: Dictionary = {}) -> Dictionary:
	var phase := _text(record.get("phase", ""))
	if day < 1 or not MEAL_PHASES.has(phase):
		return {}
	var skipped: bool = record.get("skipped", false) is bool and record.get("skipped", false)
	var ids := _food_ids(record.get("food_ids", []))
	var snapshot := _base(day, phase, "skipped" if skipped else "eaten")
	if skipped:
		snapshot["data_status"] = "not_applicable"
		return snapshot
	if ids.is_empty():
		return {}
	snapshot["source_id"] = _text(record.get("source_id", ""))
	snapshot["food_ids"] = ids
	var checked := _check_catalog(catalog)
	if not bool(checked["available"]):
		snapshot["missing_food_ids"] = ids.duplicate()
		return snapshot
	snapshot["model_version"] = _text(catalog.get("model_version", ""))
	snapshot["catalog_reviewed_at"] = _text(catalog.get("reviewed_at", ""))
	var profiles := catalog.get("profiles", {}) as Dictionary
	for food_id in ids:
		if (checked["invalid_ids"] as Array).has(food_id):
			(snapshot["invalid_food_ids"] as Array).append(food_id)
		elif not profiles.has(food_id):
			(snapshot["missing_food_ids"] as Array).append(food_id)
		else:
			_append_profile(snapshot, food_id, _copy_profile(profiles[food_id]))
	var complete := (snapshot["missing_food_ids"] as Array).is_empty()
	complete = complete and (snapshot["invalid_food_ids"] as Array).is_empty()
	snapshot["data_status"] = "ready" if complete else "partial"
	snapshot["confidence"] = _confidence(snapshot) if complete else "unknown"
	return snapshot


static func legacy(day: int, record: Dictionary) -> Dictionary:
	var phase := _text(record.get("phase", "unknown"))
	if not MEAL_PHASES.has(phase):
		phase = "unknown"
	var snapshot := _base(maxi(day, 0), phase, "legacy_unknown")
	if day <= 0:
		snapshot["day"] = null
	snapshot["data_status"] = "legacy_unknown"
	snapshot["source_id"] = _text(record.get("source_id", ""))
	snapshot["food_ids"] = _food_ids(record.get("food_ids", []))
	# Preserve an explicit historical skip flag without inventing a new healthy
	# meal assessment. Empty foods or a legacy score do not establish a skip.
	if record.get("skipped") is bool:
		snapshot["legacy_skipped"] = record["skipped"]
	return snapshot


static func _base(day: int, phase: String, status: String) -> Dictionary:
	return {
		"snapshot_schema_version": SCHEMA_VERSION,
		"day": day, "phase": phase, "status": status, "source_id": "",
		"food_ids": [], "model_version": "", "profile_versions": {},
		"profile_snapshots": {}, "component_snapshot": [], "factor_snapshot": [],
		"confidence": "unknown", "data_status": "unavailable",
		"missing_food_ids": [], "invalid_food_ids": [],
		"guidance_status": "not_evaluated", "catalog_reviewed_at": "",
	}


static func _check_catalog(catalog: Dictionary) -> Dictionary:
	var result := {"available": false, "invalid_ids": []}
	if not catalog.get("available", false) is bool or not catalog.get("available", false):
		return result
	if not catalog.get("profiles") is Dictionary:
		return result
	if not _integer(catalog.get("schema_version"), 1):
		return result
	var report: Dictionary = ValidatorScript.validate(catalog)
	# The loader exposes both entries and an ID map. Validate the actual map too
	# so callers cannot mutate a profile while leaving old entries unchanged.
	var mapped_catalog := catalog.duplicate()
	mapped_catalog["profile_entries"] = catalog["profiles"].values()
	var mapped_report: Dictionary = ValidatorScript.validate(mapped_catalog)
	report["errors"].append_array(mapped_report["errors"])
	for issue in report["errors"]:
		var food_id := _text(issue.get("food_id", ""))
		if food_id.is_empty():
			return result
		if not (result["invalid_ids"] as Array).has(food_id):
			(result["invalid_ids"] as Array).append(food_id)
	for food_id in catalog["profiles"]:
		var profile: Variant = catalog["profiles"][food_id]
		if not profile is Dictionary:
			(result["invalid_ids"] as Array).append(food_id)
		elif (
			profile.get("food_id") != food_id
			or profile.get("model_version") != catalog.get("model_version")
		):
			(result["invalid_ids"] as Array).append(food_id)
	result["available"] = true
	return result


static func _copy_profile(profile: Dictionary) -> Dictionary:
	var result := {}
	for key in PROFILE_FIELDS:
		if profile.has(key):
			result[key] = profile[key]
	return result.duplicate(true)


static func _append_profile(snapshot: Dictionary, food_id: String, profile: Dictionary) -> void:
	snapshot["profile_snapshots"][food_id] = profile.duplicate(true)
	snapshot["profile_versions"][food_id] = profile["profile_version"]
	for pair in [["components", "component_snapshot"], ["factors", "factor_snapshot"]]:
		for entry in profile.get(pair[0], []):
			var captured: Dictionary = entry.duplicate(true)
			captured["food_id"] = food_id
			captured["profile_version"] = profile["profile_version"]
			(snapshot[pair[1]] as Array).append(captured)


static func _confidence(snapshot: Dictionary) -> String:
	var rank := CONFIDENCES.size() - 1
	for profile in (snapshot["profile_snapshots"] as Dictionary).values():
		rank = mini(rank, CONFIDENCES.find(profile.get("confidence", "unknown")))
	return CONFIDENCES[maxi(rank, 0)]


static func validate(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not value is Dictionary:
		return {"valid": false, "errors": ["snapshot_not_dictionary"]}
	var snapshot := value as Dictionary
	_validate_envelope(snapshot, errors)
	if not errors.is_empty():
		return {"valid": false, "errors": errors}
	_validate_contents(snapshot, errors)
	return {"valid": errors.is_empty(), "errors": errors}


static func _validate_envelope(snapshot: Dictionary, errors: Array[String]) -> void:
	if not _integer(snapshot.get("snapshot_schema_version"), 1):
		errors.append("snapshot_schema_invalid")
	elif int(snapshot["snapshot_schema_version"]) != SCHEMA_VERSION:
		errors.append("snapshot_schema_unsupported")
	for key in ["phase", "status", "source_id", "model_version", "confidence", "data_status"]:
		if not snapshot.get(key) is String:
			errors.append("string_field_invalid:%s" % key)
	for key in ["food_ids", "missing_food_ids", "invalid_food_ids"]:
		if not _string_list(snapshot.get(key)):
			errors.append("id_list_invalid:%s" % key)
	for key in ["profile_versions", "profile_snapshots"]:
		if not snapshot.get(key) is Dictionary:
			errors.append("dictionary_field_invalid:%s" % key)
	for key in ["component_snapshot", "factor_snapshot"]:
		if not snapshot.get(key) is Array:
			errors.append("array_field_invalid:%s" % key)
	if snapshot.get("guidance_status") != "not_evaluated":
		errors.append("guidance_status_invalid")
	if not CONFIDENCES.has(snapshot.get("confidence")):
		errors.append("confidence_invalid")
	var is_legacy: bool = snapshot.get("status") == "legacy_unknown"
	if not snapshot.has("day"):
		errors.append("day_missing")
	if not (is_legacy and snapshot.get("day") == null) and not _integer(snapshot.get("day"), 1):
		errors.append("day_invalid")
	if not MEAL_PHASES.has(snapshot.get("phase")) and not (
		is_legacy and snapshot.get("phase") == "unknown"
	):
		errors.append("phase_invalid")
	if snapshot.has("legacy_skipped") and (not is_legacy or not snapshot["legacy_skipped"] is bool):
		errors.append("legacy_skip_invalid")
	if _contains_forbidden_field(snapshot):
		errors.append("gameplay_or_score_field_present")


static func _validate_contents(snapshot: Dictionary, errors: Array[String]) -> void:
	var status: String = snapshot["status"]
	if status not in ["eaten", "skipped", "legacy_unknown"]:
		errors.append("status_invalid")
		return
	if status != "eaten":
		_validate_empty_data(snapshot, errors)
		var expected := "not_applicable" if status == "skipped" else "legacy_unknown"
		if snapshot["data_status"] != expected:
			errors.append("non_eaten_data_status_invalid")
		if status == "skipped" and (
			not snapshot["food_ids"].is_empty() or snapshot["source_id"] != ""
		):
			errors.append("skipped_foods_present")
		return
	if snapshot["food_ids"].is_empty():
		errors.append("eaten_food_ids_missing")
	if snapshot["data_status"] not in ["ready", "partial", "unavailable"]:
		errors.append("data_status_invalid")
		return
	if snapshot["data_status"] == "unavailable":
		_validate_empty_data(snapshot, errors, true)
		if snapshot["missing_food_ids"] != snapshot["food_ids"]:
			errors.append("unavailable_missing_ids_invalid")
		return
	if snapshot["model_version"].is_empty():
		errors.append("model_version_missing")
	_validate_profiles(snapshot, errors)


static func _validate_empty_data(
	snapshot: Dictionary, errors: Array[String], unavailable: bool = false
) -> void:
	for key in ["profile_versions", "profile_snapshots", "component_snapshot", "factor_snapshot"]:
		if not snapshot[key].is_empty():
			errors.append("unexpected_historical_data:%s" % key)
	if not snapshot["invalid_food_ids"].is_empty():
		errors.append("unexpected_invalid_ids")
	if not unavailable and not snapshot["missing_food_ids"].is_empty():
		errors.append("unexpected_missing_ids")
	if snapshot["model_version"] != "" or snapshot["confidence"] != "unknown":
		errors.append("unexpected_model_or_confidence")


static func _validate_profiles(snapshot: Dictionary, errors: Array[String]) -> void:
	var profiles: Dictionary = snapshot["profile_snapshots"]
	var versions: Dictionary = snapshot["profile_versions"]
	if profiles.size() != versions.size():
		errors.append("profile_version_count_mismatch")
	var expected := _base(int(snapshot["day"]), snapshot["phase"], "eaten")
	var covered: Array = []
	for food_id in snapshot["food_ids"]:
		if not profiles.has(food_id):
			continue
		covered.append(food_id)
		if not _stored_profile_valid(profiles[food_id], food_id, snapshot["model_version"]):
			errors.append("stored_profile_invalid:%s" % food_id)
			continue
		if versions.get(food_id) != profiles[food_id]["profile_version"]:
			errors.append("profile_version_mismatch:%s" % food_id)
		_append_profile(expected, food_id, profiles[food_id])
	for food_id in profiles:
		if not (snapshot["food_ids"] as Array).has(food_id):
			errors.append("unexpected_profile:%s" % food_id)
	for key in ["missing_food_ids", "invalid_food_ids"]:
		for food_id in snapshot[key]:
			if covered.has(food_id) or not snapshot["food_ids"].has(food_id):
				errors.append("coverage_conflict:%s" % food_id)
			covered.append(food_id)
	if covered.size() != snapshot["food_ids"].size():
		errors.append("food_coverage_incomplete")
	for key in ["component_snapshot", "factor_snapshot"]:
		if expected[key] != snapshot[key]:
			errors.append("derived_snapshot_mismatch:%s" % key)
	var ready: bool = snapshot["missing_food_ids"].is_empty() and snapshot["invalid_food_ids"].is_empty()
	if (snapshot["data_status"] == "ready") != ready:
		errors.append("data_completeness_mismatch")
	var confidence := _confidence(expected) if ready else "unknown"
	if snapshot["confidence"] != confidence:
		errors.append("confidence_mismatch")


static func _stored_profile_valid(profile: Variant, food_id: String, model: String) -> bool:
	if not profile is Dictionary:
		return false
	if profile.get("food_id") != food_id or profile.get("model_version") != model:
		return false
	if not _integer(profile.get("profile_version"), 1):
		return false
	for key in ["portion", "caffeine", "food_safety"]:
		if not profile.get(key) is Dictionary:
			return false
	for key in ["cooking_methods", "allergens", "evidence_refs"]:
		if not _string_list(profile.get(key), false):
			return false
	var normalized: Dictionary = profile.duplicate(true)
	# JSON numbers may be floats. Normalize only after proving integrality.
	normalized["profile_version"] = int(profile["profile_version"])
	var historical_catalog := {
		"schema_version": 1, "available": true, "model_version": model,
		"locale": "snapshot", "reviewed_at": "snapshot",
		"profile_entries": [normalized], "profiles": {food_id: normalized},
	}
	return bool(ValidatorScript.validate(historical_catalog)["valid"])


static func _integer(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and (
		float(value) == floorf(float(value)) and float(value) >= minimum
		and float(value) <= MAX_JSON_INTEGER
	)


static func _string_list(value: Variant, unique: bool = true) -> bool:
	if not value is Array:
		return false
	var seen := {}
	for entry in value:
		if not entry is String or entry.is_empty() or (unique and seen.has(entry)):
			return false
		seen[entry] = true
	return true


static func _food_ids(value: Variant) -> Array[String]:
	var ids: Array[String] = []
	if not value is Array:
		return ids
	for entry in value:
		if entry is String and not entry.is_empty() and not ids.has(entry):
			ids.append(entry)
	return ids


static func _text(value: Variant) -> String:
	return value if value is String else ""


static func _contains_forbidden_field(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if FORBIDDEN_FIELDS.has(key) or _contains_forbidden_field(value[key]):
				return true
	elif value is Array:
		for entry in value:
			if _contains_forbidden_field(entry):
				return true
	return false
