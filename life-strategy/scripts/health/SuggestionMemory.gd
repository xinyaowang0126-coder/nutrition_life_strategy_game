class_name SuggestionMemory
extends RefCounted

## Per-run, detached display receipts. They never establish dietary patterns;
## only confirmed MealHealthSnapshots can support persistence checks.
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Preferences := preload("res://scripts/systems/FoodPreferenceService.gd")
const ROLES := ["vegetable", "protein_source", "staple"]
const EVENTS := ["shown", "dismissed"]


static func tick(day: int, phase: String) -> int:
	return (day - 1) * 3 + Snapshot.MEAL_PHASES.find(phase)


static func normalize(value: Variant, day: int, phase: String) -> Dictionary:
	if not value is Dictionary:
		return {"valid": false}
	for key in value:
		if key not in ["preferences", "history", "meal_history"]:
			return {"valid": false}
	var preferences: Variant = value.get("preferences", {})
	var history: Variant = value.get("history", [])
	var meals: Variant = value.get("meal_history", [])
	if not preferences is Dictionary or not history is Array or not meals is Array or history.size() > 63 or meals.size() > 21:
		return {"valid": false}
	if not preferences.is_empty() and Preferences.reaction("", preferences)["profile_id"].is_empty():
		return {"valid": false}
	var now := tick(day, phase)
	var previous := -1
	for receipt in history:
		if not _valid_receipt(receipt):
			return {"valid": false}
		var at := tick(receipt["day"], receipt["phase"])
		if at < previous or at > now:
			return {"valid": false}
		previous = at
	var seen := {}
	for meal in meals:
		if not Snapshot.validate(meal)["valid"] or typeof(meal.get("day")) != TYPE_INT or meal["day"] < 1 or meal["day"] > 7 or meal.get("phase") not in Snapshot.MEAL_PHASES:
			return {"valid": false}
		var at := tick(meal["day"], meal["phase"])
		if at >= now or seen.has(at):
			return {"valid": false}
		seen[at] = true
	var result := {"valid": true, "preferences": preferences.duplicate(true), "history": history.duplicate(true), "meal_history": meals.duplicate(true)}
	result["token"] = JSON.stringify(result).sha256_text()
	return result


static func record(history: Variant, action: Variant, event: String = "shown") -> Dictionary:
	if not history is Array or history.size() > 63 or not action is Dictionary or event not in EVENTS:
		return {"valid": false, "history": []}
	var receipt := {"day": action.get("day"), "phase": action.get("phase"), "suggestion_key": action.get("suggestion_key"), "target_role": action.get("target_role"), "event": event}
	if not _valid_receipt(receipt):
		return {"valid": false, "history": []}
	var normalized := normalize({"history": history}, receipt["day"], receipt["phase"])
	if not normalized["valid"]:
		return {"valid": false, "history": []}
	var result: Array = history.duplicate(true)
	if not result.has(receipt):
		result.append(receipt.duplicate(true))
	if result.size() > 63:
		result = result.slice(result.size() - 63)
	return {"valid": true, "history": result}


static func is_cooled(action: Dictionary, policy: Dictionary) -> bool:
	var now := tick(action["day"], action["phase"])
	for receipt in policy["history"]:
		var age := now - tick(receipt["day"], receipt["phase"])
		if age >= 0 and age <= 2 and receipt["suggestion_key"] == action["suggestion_key"] and (age > 0 or receipt["event"] == "dismissed"):
			return true
	return false


static func _valid_receipt(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5:
		return false
	return typeof(value.get("day")) == TYPE_INT and value["day"] >= 1 and value["day"] <= 7 and value.get("phase") in Snapshot.MEAL_PHASES and value.get("target_role") in ROLES and value.get("event") in EVENTS and value.get("suggestion_key") is String and not value["suggestion_key"].is_empty()
