class_name RecoveryRules
extends RefCounted

## Versioned gameplay rules, independent of nutrition records and live XML.
## Inputs are the clamped end-of-day values, after sleep and settlement.
## reason_ids retain all applicable facts; matched_rule_ids contain only rules
## in the winning condition. PHONE_AT_NIGHT explains a choice, never a penalty.

const RULES_VERSION := "recovery-gameplay-v1"
const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9007199254740991
const INPUT_KEYS := ["energy", "stress", "action_counts", "sleep_id"]
const CONDITIONS := ["rested", "steady", "strained", "depleted"]
const ACTION_IDS := ["study", "nap", "walk", "drink_water", "allow_imperfection", "restock_pantry"]
const SLEEP_IDS := ["sleep_early", "night_study", "scroll_phone"]
const RULE_IDS_BY_CONDITION := {
	"depleted": [
		"LOW_ENERGY_SEVERE", "HIGH_STRESS_SEVERE", "LATE_STUDY_LOW_ENERGY",
		"LATE_STUDY_HIGH_STRESS", "OVERWORKED_LOW_ENERGY", "HIGH_STRESS_LOW_ENERGY",
	],
	"strained": ["LATE_STUDY", "LOW_ENERGY", "HIGH_STRESS", "OVERWORKED"],
	"rested": ["EARLY_SLEEP_READY"],
	"steady": ["STEADY_FALLBACK"],
}
const RULE_IDS := [
	"LOW_ENERGY_SEVERE", "HIGH_STRESS_SEVERE", "LATE_STUDY_LOW_ENERGY",
	"LATE_STUDY_HIGH_STRESS", "OVERWORKED_LOW_ENERGY", "HIGH_STRESS_LOW_ENERGY",
	"LATE_STUDY", "LOW_ENERGY", "HIGH_STRESS", "OVERWORKED",
	"EARLY_SLEEP_READY", "STEADY_FALLBACK",
]
const REASON_IDS := [
	"LOW_ENERGY_SEVERE", "HIGH_STRESS_SEVERE", "LATE_STUDY_LOW_ENERGY",
	"LATE_STUDY_HIGH_STRESS", "OVERWORKED_LOW_ENERGY", "HIGH_STRESS_LOW_ENERGY",
	"LATE_STUDY", "LOW_ENERGY", "HIGH_STRESS", "OVERWORKED",
	"EARLY_SLEEP_READY", "STEADY_FALLBACK", "EARLY_SLEEP", "PHONE_AT_NIGHT",
]
const NEXT_DAY_EFFECTS := {
	"rested": {"study_modifier": 3, "opening_delta": {"energy": 3, "mood": 1, "stress": -2}},
	"steady": {"study_modifier": 0, "opening_delta": {}},
	"strained": {"study_modifier": -2, "opening_delta": {"energy": -2, "stress": 2}},
	"depleted": {"study_modifier": -4, "opening_delta": {"energy": -3, "mood": -2, "stress": 3}},
}


static func evaluate(inputs: Variant) -> Dictionary:
	var errors := validate_inputs(inputs)
	if not errors.is_empty():
		return {
			"valid": false, "errors": errors, "condition": null,
			"reason_ids": [] as Array[String], "matched_rule_ids": [] as Array[String],
			"next_day_effect": null,
		}
	var normalized := normalize_inputs(inputs)
	var energy: int = normalized["energy"]
	var stress: int = normalized["stress"]
	var counts: Dictionary = normalized["action_counts"]
	var sleep_id: String = normalized["sleep_id"]
	var recovery_count := int(counts.get("nap", 0)) + int(counts.get("walk", 0)) + int(counts.get("allow_imperfection", 0))
	var overworked := int(counts.get("study", 0)) >= 3 and recovery_count == 0
	var late_study := sleep_id == "night_study"
	var early_sleep := sleep_id == "sleep_early"
	var severe: Array[String] = []
	_append_if(severe, energy <= 22, "LOW_ENERGY_SEVERE")
	_append_if(severe, stress >= 82, "HIGH_STRESS_SEVERE")
	_append_if(severe, late_study and energy < 35, "LATE_STUDY_LOW_ENERGY")
	_append_if(severe, late_study and stress >= 75, "LATE_STUDY_HIGH_STRESS")
	_append_if(severe, overworked and energy < 35, "OVERWORKED_LOW_ENERGY")
	_append_if(severe, stress >= 75 and energy < 35, "HIGH_STRESS_LOW_ENERGY")
	var mild: Array[String] = []
	_append_if(mild, late_study, "LATE_STUDY")
	_append_if(mild, energy < 42, "LOW_ENERGY")
	_append_if(mild, stress >= 66, "HIGH_STRESS")
	_append_if(mild, overworked, "OVERWORKED")
	var reasons: Array[String] = []
	reasons.append_array(severe)
	reasons.append_array(mild)
	_append_if(reasons, early_sleep, "EARLY_SLEEP")
	_append_if(reasons, sleep_id == "scroll_phone", "PHONE_AT_NIGHT")
	var condition := "steady"
	var matched: Array[String] = []
	if not severe.is_empty():
		condition = "depleted"
		matched = severe
	elif not mild.is_empty():
		condition = "strained"
		matched = mild
	elif early_sleep and energy >= 58 and stress <= 52 and not overworked:
		condition = "rested"
		matched.append("EARLY_SLEEP_READY")
		reasons.append("EARLY_SLEEP_READY")
	else:
		matched.append("STEADY_FALLBACK")
		reasons.append("STEADY_FALLBACK")
	return {
		"valid": true, "errors": errors, "condition": condition,
		"reason_ids": reasons, "matched_rule_ids": matched,
		"next_day_effect": effect_for(condition),
	}


static func validate_inputs(inputs: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not inputs is Dictionary:
		errors.append("INPUTS_NOT_DICTIONARY")
		return errors
	var data := inputs as Dictionary
	for key in data:
		if typeof(key) != TYPE_STRING or not INPUT_KEYS.has(key):
			errors.append("UNKNOWN_INPUT_KEY")
	for key in INPUT_KEYS:
		if not data.has(key):
			errors.append("MISSING_%s" % String(key).to_upper())
	for key in ["energy", "stress"]:
		if not data.has(key):
			continue
		var value: Variant = data[key]
		if not is_integer(value) or value < 0 or value > 100:
			errors.append("INVALID_%s" % String(key).to_upper())
	if data.has("sleep_id"):
		if typeof(data["sleep_id"]) != TYPE_STRING or not SLEEP_IDS.has(data["sleep_id"]):
			errors.append("INVALID_SLEEP_ID")
	if data.has("action_counts"):
		if not data["action_counts"] is Dictionary:
			errors.append("ACTION_COUNTS_NOT_DICTIONARY")
		else:
			var total := 0
			var counts: Dictionary = data["action_counts"]
			for action_id in counts:
				if typeof(action_id) != TYPE_STRING or not ACTION_IDS.has(action_id):
					errors.append("UNKNOWN_ACTION_ID")
					continue
				var count: Variant = counts[action_id]
				# Reject before accumulating, so arbitrary large values cannot overflow.
				if not is_integer(count) or count < 0 or count > 3:
					errors.append("INVALID_ACTION_COUNT")
					continue
				# Water is an auxiliary interaction, outside the three main slots.
				# This preserves every previously valid record and R2 condition.
				if action_id != "drink_water":
					total += int(count)
				if action_id == "drink_water" and count > 2:
					errors.append("DRINK_WATER_LIMIT_EXCEEDED")
				if action_id == "restock_pantry" and count > 1:
					errors.append("RESTOCK_PANTRY_LIMIT_EXCEEDED")
			if total > 3:
				errors.append("DAILY_ACTION_LIMIT_EXCEEDED")
	return errors


## Accept exact integers from Godot or JSON, rejecting bools, strings, NaN,
## infinities and values outside the shared lossless JSON integer range.
static func is_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER and floor(value) == value
	return false


## This is a deep copy; invalid input never receives silent defaults/coercion.
static func normalize_inputs(inputs: Dictionary) -> Dictionary:
	if not validate_inputs(inputs).is_empty():
		return {}
	var normalized := inputs.duplicate(true)
	normalized["energy"] = int(normalized["energy"])
	normalized["stress"] = int(normalized["stress"])
	for action_id in normalized["action_counts"]:
		normalized["action_counts"][action_id] = int(normalized["action_counts"][action_id])
	return normalized


static func effect_for(condition: String) -> Dictionary:
	if not NEXT_DAY_EFFECTS.has(condition):
		return {}
	return NEXT_DAY_EFFECTS[condition].duplicate(true)


static func _append_if(values: Array[String], applies: bool, id: String) -> void:
	if applies:
		values.append(id)
