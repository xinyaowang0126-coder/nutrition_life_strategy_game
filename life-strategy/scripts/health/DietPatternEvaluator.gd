class_name DietPatternEvaluator
extends RefCounted

## Pure snapshot -> narrow meal observations. No live catalog, tags, scores,
## stats, save writes, suggestions, factor thresholds, or day/week aggregation.
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const EXTRA_FORBIDDEN := ["stress", "satiety", "study", "study_progress", "stability", "balance", "character_health", "total_score", "grade", "percentile", "diagnosis", "deficiency", "disease_risk", "healthy", "unhealthy"]


static func evaluate(snapshot: Variant, config: Variant, registry: Evidence, as_of_date: String) -> Dictionary:
	var result := _empty()
	var checked := Snapshot.validate(snapshot)
	var config_check := Config.validate(config)
	if not checked["valid"] or not config_check["valid"] or _has_forbidden(snapshot):
		result["valid"] = false
		result["errors"].append_array(checked["errors"])
		result["errors"].append_array(config_check["errors"])
		if _has_forbidden(snapshot):
			result["errors"].append("gameplay_or_score_field_present")
		result["copy_id"] = "MEAL_DATA_UNAVAILABLE"
		return result
	result["valid"] = true
	result["day"] = snapshot["day"]
	result["phase"] = snapshot["phase"]
	var status: String = snapshot["status"]
	result["dimensions"]["regularity"] = {"status": "supported" if status == "eaten" else ("attention" if status == "skipped" else "unknown"), "record_status": status}
	if status == "skipped":
		result["dimensions"]["plate_structure"]["status"] = "not_applicable"
		result["data_quality"]["status"] = "not_applicable"
		result["copy_id"] = "MEAL_SKIPPED_RECORD"
		return result
	if status == "legacy_unknown":
		result["copy_id"] = "MEAL_LEGACY_UNKNOWN"
		return result
	if snapshot["data_status"] != "unavailable" and snapshot["model_version"] != Config.MODEL_VERSION:
		result["valid"] = false
		result["errors"].append("snapshot_model_unsupported")
		result["copy_id"] = "MEAL_DATA_UNAVAILABLE"
		return result
	var model_approval := Config.approval(config, registry, as_of_date, Config.REQUIRED_CAPABILITIES)
	result["provenance"]["config_evidence"] = model_approval["evidence_check"]
	if not model_approval["allowed"]:
		result["data_quality"]["reason_ids"] = model_approval["reason_ids"].duplicate()
		result["data_quality"]["unknown_food_ids"] = snapshot["food_ids"].duplicate()
		return result
	var merged := {}
	var uncertain: bool = not snapshot["missing_food_ids"].is_empty() or not snapshot["invalid_food_ids"].is_empty()
	var unknown_portion_ids: Array[String] = []
	var unknown_ids: Array[String] = []
	unknown_ids.append_array(snapshot["missing_food_ids"])
	unknown_ids.append_array(snapshot["invalid_food_ids"])
	for food_id in snapshot["food_ids"]:
		if not snapshot["profile_snapshots"].has(food_id):
			continue
		var profile: Dictionary = snapshot["profile_snapshots"][food_id]
		var caps := ["MEAL_DIVERSITY_EDUCATION"]
		if profile["basis_type"] == "menu_recipe":
			caps = ["SIMULATED_INGREDIENT_COMPOSITION"]
		elif profile["basis_type"] == "package_label":
			caps = ["SIMULATED_PACKAGE_LABEL"]
		var approval := Config.approval(profile, registry, as_of_date, caps)
		result["provenance"]["profiles"][food_id] = {"profile_version": profile["profile_version"], "evidence_check": approval["evidence_check"], "allowed": approval["allowed"], "reason_ids": approval["reason_ids"]}
		if not approval["allowed"] or profile["composition_status"] == "unknown" or profile["basis_type"] == "unknown":
			uncertain = true
			unknown_ids.append(food_id)
			continue
		if profile["portion"]["status"] != "known":
			unknown_portion_ids.append(food_id)
		if profile["composition_status"] != "known" or Config.CONFIDENCE[profile["confidence"]] < 2:
			uncertain = true
			unknown_ids.append(food_id)
		for component in profile["components"]:
			if component["food_group"] == "unknown" or component["contribution_band"] == "unknown" or Config.CONFIDENCE[component["confidence"]] < 2:
				uncertain = true
			_merge(merged, component, food_id, profile["confidence"])
	var ingredients: Array = merged.keys()
	ingredients.sort()
	var group_ids: Array[String] = []
	for ingredient_id in ingredients:
		var component: Dictionary = merged[ingredient_id]
		result["ingredients"].append(component.duplicate(true))
		var group: String = component["food_group"]
		var band: String = component["contribution_band"]
		if Config.CONFIDENCE[component["confidence"]] < 2 or Config.BANDS[band] < 2 or group == "unknown":
			continue
		if not group_ids.has(group) and group != "other":
			group_ids.append(group)
		if Config.ROLE_BY_GROUP.has(group):
			var role: Dictionary = result["dimensions"]["plate_structure"]["roles"][Config.ROLE_BY_GROUP[group]]
			if Config.BANDS.get(role["presence"], 0) < Config.BANDS[band]:
				role["presence"] = band
			if role["confidence"] == "unknown" or Config.CONFIDENCE[role["confidence"]] > Config.CONFIDENCE[component["confidence"]]:
				role["confidence"] = component["confidence"]
			role["ingredient_ids"].append(ingredient_id)
		elif Config.SEPARATE_GROUPS.has(group):
			result["separate_food_groups"][group].append(ingredient_id)
	group_ids.sort()
	unknown_ids.sort()
	unknown_portion_ids.sort()
	var has_records := not group_ids.is_empty()
	var structure: Dictionary = result["dimensions"]["plate_structure"]
	structure["status"] = ("partial" if uncertain else "supported") if has_records else "unknown"
	for role in structure["roles"].values():
		if role["ingredient_ids"].is_empty():
			role["presence"] = "unknown" if uncertain or not has_records else "not_recorded"
	result["food_group_ids"] = group_ids
	result["data_quality"] = {"status": "unknown" if not has_records else ("partial" if uncertain or not unknown_portion_ids.is_empty() else "supported"), "unknown_food_ids": unknown_ids, "unknown_portion_food_ids": unknown_portion_ids, "reason_ids": []}
	if has_records:
		result["copy_id"] = "MEAL_COMPOSITION_PARTIAL" if uncertain else "MEAL_COMPOSITION_RECORDED"
		result["observations"].append({"copy_id": result["copy_id"], "status": structure["status"], "food_group_ids": group_ids.duplicate(), "rules_version": Config.RULES_VERSION})
	return result


static func _merge(merged: Dictionary, component: Dictionary, food_id: String, profile_confidence: String) -> void:
	var id: String = component["ingredient_id"]
	var confidence: String = component["confidence"] if Config.CONFIDENCE[component["confidence"]] <= Config.CONFIDENCE[profile_confidence] else profile_confidence
	var candidate := {"ingredient_id": id, "food_group": component["food_group"], "contribution_band": component["contribution_band"], "confidence": confidence, "selected_food_id": food_id, "food_ids": [food_id]}
	if not merged.has(id):
		merged[id] = candidate
		return
	var old: Dictionary = merged[id]
	var sources: Array = old["food_ids"].duplicate()
	if not sources.has(food_id):
		sources.append(food_id)
	sources.sort()
	var candidate_usable: bool = Config.CONFIDENCE[candidate["confidence"]] >= 2
	var old_usable: bool = Config.CONFIDENCE[old["confidence"]] >= 2
	var confidence_delta: int = Config.CONFIDENCE[candidate["confidence"]] - Config.CONFIDENCE[old["confidence"]]
	var band_delta: int = Config.BANDS[candidate["contribution_band"]] - Config.BANDS[old["contribution_band"]]
	# Different dishes can record different amounts of the same ingredient.
	# A reliable trace in another dish must not erase an existing material clue.
	# Never sum amounts; prefer the strongest supported presence, then confidence.
	var replace := candidate_usable and not old_usable
	if candidate_usable and old_usable:
		replace = band_delta > 0 or (band_delta == 0 and confidence_delta > 0)
	elif not candidate_usable and not old_usable:
		replace = confidence_delta > 0 or (confidence_delta == 0 and band_delta > 0)
	if confidence_delta == 0 and band_delta == 0 and food_id < String(old["selected_food_id"]):
		replace = true
	if replace:
		merged[id] = candidate
	merged[id]["food_ids"] = sources


static func _empty() -> Dictionary:
	var roles := {}
	for id in ["staple", "vegetable", "protein_source"]:
		roles[id] = {"presence": "unknown", "confidence": "unknown", "ingredient_ids": []}
	var separate := {}
	for group in Config.SEPARATE_GROUPS:
		separate[group] = []
	return {"valid": false, "errors": [], "scope": "meal", "day": null, "phase": "unknown", "model_version": Config.MODEL_VERSION, "rules_version": Config.RULES_VERSION, "dimensions": {"regularity": {"status": "unknown"}, "plate_structure": {"status": "unknown", "roles": roles}, "diversity": {"status": "not_evaluated"}, "attention_factors": {"status": "not_evaluated"}}, "ingredients": [], "food_group_ids": [], "separate_food_groups": separate, "observations": [], "primary_suggestion": null, "fallback_suggestion": null, "copy_id": "MEAL_COMPOSITION_UNKNOWN", "data_quality": {"status": "unknown", "unknown_food_ids": [], "unknown_portion_food_ids": [], "reason_ids": []}, "provenance": {"config_evidence": {}, "profiles": {}}, "scope_notice_id": "GENERAL_EDUCATION_NOT_MEDICAL"}


static func _has_forbidden(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if Snapshot.FORBIDDEN_FIELDS.has(key) or EXTRA_FORBIDDEN.has(key) or _has_forbidden(value[key]):
				return true
	elif value is Array:
		for child in value:
			if _has_forbidden(child):
				return true
	return false
