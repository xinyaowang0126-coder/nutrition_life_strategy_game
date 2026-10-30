extends RefCounted

## An observation of the existing action settlement, never another settlement.
const Balance := preload("res://scripts/systems/GameplayBalanceRules.gd")
const KEYS := ["energy", "mood", "stress", "satiety", "balance", "progress"]
const PARTS := ["base", "event", "recovery", "current", "floor"]
const PERIODS := ["breakfast_action", "lunch_action", "dinner_action"]


static func snapshot(state: Dictionary, goal_key: String) -> Dictionary:
	var result := {}
	for key in KEYS:
		result[key] = int(state.get(goal_key if key == "progress" else key, 0))
	return result


static func requested(row: Dictionary) -> Dictionary:
	var result := {}
	var delta: Dictionary = row.get("stat_delta", {})
	for key in KEYS:
		result[key] = -int(row.get("cost", 0)) if key == "balance" else int(delta.get("study_progress" if key == "progress" else key, 0))
	return result


static func capture(before: Dictionary, after: Dictionary, row: Dictionary, day: int, phase: String, sequence: int, components: Dictionary) -> Dictionary:
	var actual := {}
	for key in KEYS:
		actual[key] = int(after[key]) - int(before[key])
	return {"version": 1, "rules_version": Balance.VERSION, "day": day, "phase": phase,
		"sequence": sequence, "action_id": row["id"], "before": before.duplicate(true),
		"requested": requested(row), "after": after.duplicate(true), "actual": actual,
		"goal_components": components.duplicate(true), "recovery_day": day - 1}


static func valid(value: Variant, row: Dictionary, day: int, sequence: int, learning: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 12: return false
	if typeof(value.get("version")) != TYPE_INT or value["version"] != 1 or value.get("rules_version") != Balance.VERSION: return false
	if typeof(value.get("day")) != TYPE_INT or value["day"] != day or day not in range(1, 8): return false
	if typeof(value.get("sequence")) != TYPE_INT or value["sequence"] != sequence or sequence not in range(1, 17): return false
	if value.get("phase") not in PERIODS or value.get("action_id") != row.get("id"): return false
	if typeof(value.get("recovery_day")) != TYPE_INT or value["recovery_day"] != day - 1: return false
	if typeof(row.get("cost")) != TYPE_INT or row["cost"] < 0 or row["cost"] > 999: return false
	for field in ["before", "requested", "after", "actual"]:
		if not value.get(field) is Dictionary or value[field].size() != KEYS.size(): return false
		for key in KEYS:
			if typeof(value[field].get(key)) != TYPE_INT: return false
	if value["requested"] != requested(row): return false
	for key in KEYS:
		var maximum := 999 if key == "balance" else 100
		var before: int = value["before"][key]
		var after: int = value["after"][key]
		if before < 0 or before > maximum or after < 0 or after > maximum: return false
		if after != clampi(before + int(value["requested"][key]), 0, maximum): return false
		if int(value["actual"][key]) != after - before: return false
	var parts: Variant = value.get("goal_components")
	if not parts is Dictionary: return false
	if row.get("id") not in ["study", "rehearse", "group_rehearsal"]: return parts.is_empty()
	if parts.size() != PARTS.size(): return false
	var total := 0
	for key in PARTS:
		if typeof(parts.get(key)) != TYPE_INT or absi(parts[key]) > 100: return false
		total += int(parts[key])
	if parts["base"] < 0 or parts["floor"] < 0 or parts["current"] > 0: return false
	if not learning.has("study_modifier") or parts["recovery"] != learning["study_modifier"]: return false
	if total != value["requested"]["progress"] or total < 1: return false
	return parts["floor"] == maxi(0, 1 - (total - int(parts["floor"])))


static func receipt(row: Dictionary, goal_label: String) -> String:
	var trace: Dictionary = row.get("feedback_trace", {})
	if trace.is_empty(): return String(row.get("name", ""))
	var actual: Dictionary = trace["actual"]
	var pieces: Array[String] = []
	if int(actual["progress"]) > 0: pieces.append("%s +%d" % [goal_label, actual["progress"]])
	if int(actual["energy"]) > 0: pieces.append("精力 +%d" % actual["energy"])
	if int(actual["stress"]) < 0: pieces.append("压力 %d" % actual["stress"])
	return String(row.get("name", "")) + (" · " + "，".join(pieces) if not pieces.is_empty() else "")
