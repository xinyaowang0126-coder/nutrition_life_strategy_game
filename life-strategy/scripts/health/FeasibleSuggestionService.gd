class_name FeasibleSuggestionService
extends RefCounted

## Supported current choices only; one primary and one folded alternative.
## Plans never claim future cards, prices or stock are already executable.
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const GameData := preload("res://scripts/GameData.gd")
const Memory := preload("res://scripts/health/SuggestionMemory.gd")
const Preferences := preload("res://scripts/systems/FoodPreferenceService.gd")
const ROLE_ORDER := ["vegetable", "protein_source", "staple"]
const RULES_VERSION := "feasible-options-v2"


static func find_option(context: Variant, config: Dictionary, registry: Evidence, date: String, copies: Dictionary, policy_input: Variant = {}) -> Dictionary:
	var none := {"verified": false, "action": null, "alternative": null, "plan": null, "reason": "no_option"}
	if not _valid_context(context):
		none["reason"] = "context_invalid"
		return none
	var current := Composer.compose_meal(context["current_snapshot"], config, registry, date, copies)
	if not current["valid"] or not current["copy_allowed"] or current["primary"]["kind"] != "nutrition_observation":
		none["reason"] = "information_insufficient"
		return none
	var day: int = context["current_snapshot"]["day"]
	var policy := Memory.normalize(policy_input, day, context["phase"])
	if not policy["valid"]:
		none["reason"] = "policy_invalid"
		return none
	var roles: Dictionary = current["evaluation"]["dimensions"]["plate_structure"]["roles"]
	var targets: Array[String] = []
	for role in ROLE_ORDER:
		if roles[role]["presence"] == "not_recorded":
			targets.append(role)
	if targets.is_empty():
		return none
	var selected: Array = context["selected_ids"]
	var choices: Array[Dictionary] = []
	for row in context["options"]:
		if not row["available"] or selected.has(row["id"]) or (context["payment_mode"] == "stock" and row["stock"] <= 0):
			continue
		var removals: Array = [""] if selected.size() < context["selection_limit"] else []
		removals.append_array(selected)
		for remove_id in removals:
			var ids := selected.duplicate()
			if remove_id != "":
				ids.erase(remove_id)
			ids.append(row["id"])
			var price := int(context["fee"])
			if context["payment_mode"] == "cash":
				for id in ids:
					price += _option(context, id)["cost"]
			if price > context["balance"]:
				continue
			var snapshot_value: Variant = row["candidate_snapshots"].get(String(remove_id), {})
			if not snapshot_value is Dictionary:
				continue
			var snapshot: Dictionary = snapshot_value
			# The adapter must freeze the exact proposed selection, not a guessed
			# dish assembled from an ID or a stale standalone candidate snapshot.
			if snapshot.get("food_ids", []) != ids or snapshot.get("phase") != context["phase"] or snapshot.get("source_id") != context["source_id"] or snapshot.get("day") != context["current_snapshot"].get("day"):
				continue
			var proposed := Composer.compose_meal(snapshot, config, registry, date, copies)
			if not proposed["valid"] or not proposed["copy_allowed"] or proposed["primary"]["kind"] != "nutrition_observation":
				continue
			var next_roles: Dictionary = proposed["evaluation"]["dimensions"]["plate_structure"]["roles"]
			var target := ""
			for role in targets:
				if Config.BANDS.get(next_roles[role]["presence"], 0) >= 2:
					target = role
					break
			if target.is_empty():
				continue
			var retains_known := true
			for role in roles:
				if Config.BANDS.get(next_roles[role]["presence"], 0) < Config.BANDS.get(roles[role]["presence"], 0):
					retains_known = false
			if not retains_known:
				continue
			var action := {"kind": "add_food" if remove_id == "" else "replace_food", "food_id": row["id"], "food_name": row["name"], "remove_food_id": remove_id, "remove_food_name": "" if remove_id == "" else _option(context, remove_id)["name"], "selection": ids, "total_cost": price, "revision": context["revision"], "source_id": context["source_id"], "phase": context["phase"], "day": snapshot["day"], "context_token": context.get("context_token", ""), "target_role": target, "policy_token": policy["token"], "suggestion_rules_version": RULES_VERSION}
			# Dismissing one food also dismisses its add/swap variants, rather
			# than immediately recommending the same food with a new removal.
			action["suggestion_key"] = "%s:%s:%s" % [target, row["id"], context["source_id"]]
			choices.append(action)
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["kind"] != b["kind"]:
			return a["kind"] == "add_food"
		if a["target_role"] != b["target_role"]:
			return ROLE_ORDER.find(a["target_role"]) < ROLE_ORDER.find(b["target_role"])
		if a["total_cost"] != b["total_cost"]:
			return a["total_cost"] < b["total_cost"]
		var a_taste := Preferences.reaction(a["food_id"], policy["preferences"])
		var b_taste := Preferences.reaction(b["food_id"], policy["preferences"])
		if a_taste["mood_delta"] != b_taste["mood_delta"]:
			return a_taste["mood_delta"] > b_taste["mood_delta"]
		return String(a["food_id"]) + String(a["remove_food_id"]) < String(b["food_id"]) + String(b["remove_food_id"])
	)
	var available: Array[Dictionary] = []
	for action in choices:
		if not Memory.is_cooled(action, policy):
			available.append(action)
	if available.is_empty() and not choices.is_empty():
		for action in choices:
			if _pattern_persists(policy, action["target_role"], day, context["phase"], config, registry, date, copies):
				available.append(action)
	if available.is_empty():
		none["plan"] = _next_meal_plan(day, context["phase"], targets[0])
		none["reason"] = "cooldown_active" if not choices.is_empty() else "no_current_option"
		return none
	var primary: Dictionary = available[0]
	var alternative: Variant = null
	for action in available.slice(1):
		if action["food_id"] != primary["food_id"] or action["kind"] != primary["kind"]:
			alternative = action.duplicate(true)
			break
	return {"verified": true, "action": primary.duplicate(true), "alternative": alternative, "plan": null, "reason": "current_hand_option"}


static func _pattern_persists(policy: Dictionary, target: String, day: int, phase: String, config: Dictionary, registry: Evidence, date: String, copies: Dictionary) -> bool:
	var now := Memory.tick(day, phase)
	var confirmed := {}
	for snapshot in policy["meal_history"]:
		var at := Memory.tick(snapshot["day"], snapshot["phase"])
		if at not in [now - 1, now - 2] or snapshot["status"] != "eaten":
			continue
		var prior := Composer.compose_meal(snapshot, config, registry, date, copies)
		if prior["valid"] and prior["copy_allowed"] and prior["primary"]["kind"] == "nutrition_observation" and prior["evaluation"]["dimensions"]["plate_structure"]["roles"][target]["presence"] == "not_recorded":
			confirmed[at] = true
	return confirmed.size() == 2


static func _next_meal_plan(day: int, phase: String, target: String) -> Variant:
	var next := Memory.tick(day, phase) + 1
	if next >= GameData.TOTAL_DAYS * 3:
		return null
	return {"kind": "plan_next_meal", "target_day": int(next / 3.0) + 1, "target_phase": ["breakfast", "lunch", "dinner"][next % 3], "target_role": target, "requires_recheck": true, "executable_now": false, "source_id": "", "food_ids": [], "suggestion_rules_version": RULES_VERSION}


static func _option(context: Dictionary, id: String) -> Dictionary:
	for row in context["options"]:
		if row["id"] == id:
			return row
	return {}


static func _valid_context(value: Variant) -> bool:
	if not value is Dictionary or value.get("stage") != "selecting" or value.get("phase") not in ["breakfast", "lunch", "dinner"]:
		return false
	for key in ["balance", "fee", "selection_limit", "revision"]:
		if typeof(value.get(key)) != TYPE_INT or value[key] < 0:
			return false
	if value["balance"] > 999 or value["fee"] > 999 or value["selection_limit"] < 1 or value["selection_limit"] > 3:
		return false
	if not value.get("source_id") is String or value["source_id"].is_empty() or value.get("payment_mode") not in ["cash", "stock"]:
		return false
	if not GameData.is_meal_source_available(value["source_id"], value["phase"]):
		return false
	var source := GameData.get_meal_source(value["source_id"])
	if value["payment_mode"] != source.get("payment_mode") or value["selection_limit"] > int(source.get("selection_limit", 0)):
		return false
	if not value.get("selected_ids") is Array or value["selected_ids"].is_empty() or value["selected_ids"].size() > value["selection_limit"] or not value.get("options") is Array:
		return false
	var ids := {}
	for row in value["options"]:
		if not row is Dictionary or not row.get("id") is String or row["id"].is_empty() or ids.has(row["id"]):
			return false
		ids[row["id"]] = true
		if not row.get("name") is String or row["name"].is_empty() or not row.get("available") is bool:
			return false
		for key in ["cost", "stock"]:
			if typeof(row.get(key)) != TYPE_INT or row[key] < 0 or row[key] > 999:
				return false
		if not row.get("candidate_snapshots") is Dictionary:
			return false
	var seen := {}
	for id in value["selected_ids"]:
		if not id is String or seen.has(id) or not ids.has(id):
			return false
		seen[id] = true
		var option := _option(value, id)
		if not option["available"] or (value["payment_mode"] == "stock" and option["stock"] <= 0):
			return false
	return value.get("current_snapshot") is Dictionary and typeof(value["current_snapshot"].get("day")) == TYPE_INT and value["current_snapshot"]["day"] >= 1 and value["current_snapshot"]["day"] <= 7 and value["current_snapshot"].get("food_ids", []) == value["selected_ids"] and value["current_snapshot"].get("phase") == value["phase"] and value["current_snapshot"].get("source_id") == value["source_id"]
