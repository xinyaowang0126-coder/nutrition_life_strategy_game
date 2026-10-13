class_name DietPatternLedger
extends RefCounted

## Owns frozen, confirmed snapshots and their as-of composition facts. Reads
## never reload a catalog, re-evaluate history, write saves or alter gameplay.
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const Evaluator := preload("res://scripts/health/DietPatternEvaluator.gd")
const AGGREGATION_VERSION := "diet-period-v1"
const PHASES := ["breakfast", "lunch", "dinner"]
const ROLES := ["staple", "vegetable", "protein_source"]
var _entries: Array[Dictionary] = []


func append_snapshot(snapshot: Variant, config: Dictionary, registry: Evidence, date: String, copies: Dictionary) -> Dictionary:
	if _entries.size() >= 42:
		return _failure("entry_limit")
	var prepared := _prepare(snapshot, config, registry, date, copies)
	if not prepared["valid"]:
		return prepared
	var entry: Dictionary = prepared["entry"]
	if entry["placed"]:
		for current in _entries:
			if current["placed"] and current["meal_key"] == entry["meal_key"]:
				return _failure("duplicate_meal")
	_entries.append(entry.duplicate(true))
	return {"valid": true, "errors": [], "entry_count": _entries.size()}


func replace_snapshots(snapshots: Variant, config: Dictionary, registry: Evidence, date: String, copies: Dictionary) -> Dictionary:
	if not snapshots is Array or snapshots.size() > 42:
		return _failure("snapshot_list_invalid")
	var pending := DietPatternLedger.new()
	for snapshot in snapshots:
		var result := pending.append_snapshot(snapshot, config, registry, date, copies)
		if not result["valid"]:
			return result
	_entries = pending.get_entries()
	return {"valid": true, "errors": [], "entry_count": _entries.size()}


func clear() -> void:
	_entries.clear()


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func get_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		result.append(entry["snapshot"].duplicate(true))
	return result


func day_view(day: int) -> Dictionary:
	if day < 1 or day > 7:
		return _failure("day_invalid")
	return _period(day, day, "day")


func week_view(through_day: int = 7) -> Dictionary:
	if through_day < 1 or through_day > 7:
		return _failure("day_invalid")
	return _period(1, through_day, "week")


static func _prepare(value: Variant, config: Dictionary, registry: Evidence, date: String, copies: Dictionary) -> Dictionary:
	# Unsupported models are valid historical records; gameplay values and
	# score/diagnosis fields are not, even when the snapshot schema permits
	# extension keys. Keep the evaluator's stricter boundary at ingestion.
	if Evaluator._has_forbidden(value):
		return _failure("gameplay_or_score_field_present")
	var checked := Snapshot.validate(value)
	if not checked["valid"]:
		return {"valid": false, "errors": checked["errors"].duplicate()}
	var ingredient_groups := {}
	for profile in value["profile_snapshots"].values():
		for component in profile["components"]:
			var group: String = component["food_group"]
			if group == "unknown":
				continue
			var id: String = component["ingredient_id"]
			if ingredient_groups.has(id) and ingredient_groups[id] != group:
				return _failure("ingredient_group_conflict")
			ingredient_groups[id] = group
	if not Config.validate(config)["valid"] or not Evidence._is_valid_iso_date(date):
		return _failure("assessment_context_invalid")
	var snapshot: Dictionary = value.duplicate(true)
	var day: Variant = snapshot["day"]
	if day != null and (int(day) < 1 or int(day) > 7):
		return _failure("day_invalid")
	var phase: String = snapshot["phase"]
	var placed: bool = day != null and phase in PHASES
	var composed := Composer.compose_meal(snapshot, config, registry, date, copies)
	var allowed: bool = composed["valid"] and composed["copy_allowed"] and composed["primary"]["kind"] == "nutrition_observation"
	var evaluation: Dictionary = composed["evaluation"]
	var roles := {}
	for role in ROLES:
		roles[role] = evaluation["dimensions"]["plate_structure"]["roles"][role].duplicate(true) if allowed else {"presence": "unknown", "confidence": "unknown", "ingredient_ids": []}
	var ingredients: Array[Dictionary] = []
	if allowed:
		for item in evaluation["ingredients"]:
			if Config.CONFIDENCE.get(item["confidence"], 0) < 2 or Config.BANDS.get(item["contribution_band"], 0) < 2 or item["food_group"] in ["other", "unknown"]:
				continue
			var name := ""
			for component in snapshot["profile_snapshots"][item["selected_food_id"]]["components"]:
				if component["ingredient_id"] == item["ingredient_id"]:
					name = String(component["name"])
					break
			ingredients.append({"id": item["ingredient_id"], "name": name, "food_group": item["food_group"]})
	var status := "unknown"
	if snapshot["status"] == "skipped":
		status = "not_applicable"
	elif snapshot["status"] == "legacy_unknown":
		status = "legacy_unknown"
	elif not composed["valid"]:
		status = "unsupported_model" if evaluation["errors"].has("snapshot_model_unsupported") else "unknown"
	elif allowed:
		status = evaluation["dimensions"]["plate_structure"]["status"]
	var entry := {
		"placed": placed, "day": null if day == null else int(day), "phase": phase,
		"meal_key": "%d:%s" % [int(day), phase] if placed else "",
		"snapshot": snapshot, "model_version": snapshot["model_version"],
		"rules_version": config["rules_version"], "as_of_date": date,
		"record_status": snapshot["status"], "composition_status": status,
		"nutrition_allowed": allowed, "roles": roles, "ingredients": ingredients,
		"unknown_portion": allowed and not evaluation["data_quality"]["unknown_portion_food_ids"].is_empty(),
		"assessment_errors": evaluation["errors"].duplicate(),
	}
	return {"valid": true, "errors": [], "entry": entry}


func _period(first_day: int, last_day: int, scope: String) -> Dictionary:
	var lookup := {}
	var unplaced := 0
	for entry in _entries:
		if not entry["placed"]:
			if entry["day"] == null or (entry["day"] >= first_day and entry["day"] <= last_day):
				unplaced += 1
		elif entry["day"] >= first_day and entry["day"] <= last_day:
			lookup[entry["meal_key"]] = entry
	var rows: Array[Dictionary] = []
	var counts := {"eaten": 0, "skipped": 0, "legacy_unknown": 0, "unrecorded": 0}
	var groups := {}
	var unknown_keys: Array[String] = []
	var portion_keys: Array[String] = []
	for day in range(first_day, last_day + 1):
		for phase in PHASES:
			var key := "%d:%s" % [day, phase]
			if not lookup.has(key):
				counts["unrecorded"] += 1
				rows.append({"day": day, "phase": phase, "meal_key": key, "status": "unrecorded", "composition_status": "unknown", "food_ids": [], "ingredients": [], "roles": _unknown_roles(), "as_of_date": "", "model_version": ""})
				unknown_keys.append(key)
				continue
			var entry: Dictionary = lookup[key]
			var status: String = entry["record_status"]
			counts[status] += 1
			rows.append({"day": day, "phase": phase, "meal_key": key, "status": status, "composition_status": entry["composition_status"], "food_ids": entry["snapshot"]["food_ids"].duplicate(), "ingredients": entry["ingredients"].duplicate(true), "roles": entry["roles"].duplicate(true), "as_of_date": entry["as_of_date"], "model_version": entry["model_version"]})
			if status == "skipped":
				continue
			if status == "legacy_unknown":
				unknown_keys.append(key)
				continue
			if entry["unknown_portion"]:
				portion_keys.append(key)
			if entry["composition_status"] in ["unknown", "unsupported_model"]:
				unknown_keys.append(key)
			var version: String = entry["model_version"]
			if version.is_empty():
				continue
			var group_key := "%s|%s" % [version, entry["rules_version"]]
			if not groups.has(group_key):
				groups[group_key] = {"model_version": version, "rules_version": entry["rules_version"], "entries": []}
			groups[group_key]["entries"].append(entry)
	var segments: Array[Dictionary] = []
	var group_keys := groups.keys()
	group_keys.sort()
	for key in group_keys:
		segments.append(_segment(groups[key]))
	var diversity := {"status": "unknown", "unique_ingredient_count": null, "count_is_recorded_only": true, "segments": segments, "unknown_meal_keys": unknown_keys, "unknown_portion_meal_keys": portion_keys}
	if segments.size() > 1:
		diversity["status"] = "segmented"
	elif segments.size() == 1:
		diversity["unique_ingredient_count"] = segments[0]["unique_ingredient_count"]
		diversity["status"] = segments[0]["status"]
		if not unknown_keys.is_empty() or unplaced > 0:
			diversity["status"] = "partial" if diversity["unique_ingredient_count"] != null else "unknown"
	elif counts["eaten"] == 0 and counts["legacy_unknown"] == 0 and counts["unrecorded"] == 0 and unplaced == 0:
		diversity["status"] = "not_applicable"
		diversity["unique_ingredient_count"] = 0
	return {"valid": true, "errors": [], "scope": scope, "first_day": first_day, "last_day": last_day, "aggregation_version": AGGREGATION_VERSION, "regularity": counts, "meals": rows, "diversity": diversity, "unplaced_legacy_count": unplaced, "attention_factors": {"status": "not_evaluated"}, "primary_suggestion": null}


static func _segment(group: Dictionary) -> Dictionary:
	var merged := {}
	var unknown: Array[String] = []
	var conflicts: Array[String] = []
	var supported_meals := 0
	var meal_keys: Array[String] = []
	for entry in group["entries"]:
		var key: String = entry["meal_key"]
		meal_keys.append(key)
		if entry["nutrition_allowed"]:
			supported_meals += 1
		if entry["composition_status"] != "supported":
			unknown.append(key)
		for ingredient in entry["ingredients"]:
			var id: String = ingredient["id"]
			if not merged.has(id):
				merged[id] = {"id": id, "name": ingredient["name"], "food_group": ingredient["food_group"], "meal_keys": [], "days": []}
			elif merged[id]["food_group"] != ingredient["food_group"] and not conflicts.has(id):
				conflicts.append(id)
			if not merged[id]["meal_keys"].has(key):
				merged[id]["meal_keys"].append(key)
			if not merged[id]["days"].has(entry["day"]):
				merged[id]["days"].append(entry["day"])
	var ingredients: Array[Dictionary] = []
	var ids := merged.keys()
	ids.sort()
	for id in ids:
		if conflicts.has(id):
			continue
		ingredients.append(merged[id].duplicate(true))
	conflicts.sort()
	var state := "supported" if unknown.is_empty() and conflicts.is_empty() else "partial"
	if supported_meals == 0:
		state = "unknown"
	return {"model_version": group["model_version"], "rules_version": group["rules_version"], "status": state, "meal_keys": meal_keys, "ingredients": ingredients, "unique_ingredient_count": ingredients.size() if supported_meals > 0 else null, "unknown_meal_keys": unknown, "conflicting_ingredient_ids": conflicts}


static func _unknown_roles() -> Dictionary:
	var roles := {}
	for role in ROLES:
		roles[role] = {"presence": "unknown", "confidence": "unknown", "ingredient_ids": []}
	return roles


static func _failure(reason: String) -> Dictionary:
	return {"valid": false, "errors": [reason]}
