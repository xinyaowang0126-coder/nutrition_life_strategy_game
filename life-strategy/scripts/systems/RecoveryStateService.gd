class_name RecoveryStateService
extends RefCounted

## Independent recovery records for NUT-208B. No current-run or file access.
## Creating a day evaluates R2 once. Validating/loading a record does not
## evaluate its historical inputs again or read today's card configuration.

const Rules := preload("res://scripts/systems/RecoveryRules.gd")
const SCHEMA_VERSION := 1
const RULES_VERSION := "recovery-gameplay-v1"
const MAX_SAFE_INTEGER := 9007199254740991
const RECORD_KEYS := [
	"schema_version", "rules_version", "status", "condition", "origin",
	"evaluated_day", "inputs", "sleep_snapshot", "before_sleep", "after_sleep",
	"end_of_day", "settlement_effects", "clamp_delta", "reason_ids",
	"matched_rule_ids", "next_day_effect",
]
const NULL_TRACE_KEYS := [
	"evaluated_day", "inputs", "sleep_snapshot", "before_sleep", "after_sleep",
	"end_of_day", "clamp_delta",
]
const PAIR_KEYS := ["energy", "stress"]
const SLEEP_KEYS := ["id", "energy", "mood", "stress", "study", "satiety"]
const DELTA_KEYS := ["energy", "mood", "stress", "satiety", "study_progress", "balance"]
const MAX_SETTLEMENT_EFFECTS := 128


static func new_run() -> Dictionary:
	var record := _empty_record("known", "new_run_default")
	record["condition"] = "steady"
	record["reason_ids"] = ["NEW_RUN_DEFAULT"]
	record["next_day_effect"] = Rules.effect_for("steady")
	return record


static func unavailable(status: String, reason: String) -> Dictionary:
	if not ["legacy_unknown", "invalid", "unsupported_version"].has(status):
		status = "invalid"
	var record := _empty_record(status, "legacy_record")
	record["reason_ids"] = [reason if not reason.is_empty() else "RECOVERY_UNAVAILABLE"]
	return record


static func settle(
	day: Variant, before_sleep: Variant, sleep_snapshot: Variant,
	action_counts: Variant, settlement_effects: Variant = []
) -> Dictionary:
	var errors := _trace_input_errors(day, before_sleep, sleep_snapshot, settlement_effects)
	if not errors.is_empty():
		return _build_failure(errors)
	var trace := _calculate_trace(before_sleep, sleep_snapshot, settlement_effects)
	if trace.is_empty():
		return _build_failure(["trace: arithmetic exceeds safe integer range"])
	var inputs := {
		"energy": trace["end_of_day"]["energy"],
		"stress": trace["end_of_day"]["stress"],
		"action_counts": action_counts,
		"sleep_id": sleep_snapshot["id"],
	}
	var result := Rules.evaluate(inputs)
	if not result["valid"]:
		return _build_failure(result["errors"])
	var record := _empty_record("known", "day_settlement")
	record.merge({
		"evaluated_day": int(day), "inputs": Rules.normalize_inputs(inputs),
		"sleep_snapshot": _normalize_value(sleep_snapshot),
		"before_sleep": _normalize_value(before_sleep),
		"settlement_effects": _normalize_value(settlement_effects),
	}, true)
	record.merge(trace, true)
	for key in ["condition", "reason_ids", "matched_rule_ids", "next_day_effect"]:
		record[key] = _normalize_value(result[key])
	return {"valid": true, "errors": [], "recovery_state": record}


static func validate(record: Variant) -> Dictionary:
	var errors := _keys_errors(record, RECORD_KEYS, "recovery_state")
	if not errors.is_empty():
		return _validation(errors)
	if not Rules.is_integer(record["schema_version"]) or record["schema_version"] != SCHEMA_VERSION:
		errors.append("schema_version: unsupported or invalid")
	if record["rules_version"] != RULES_VERSION:
		errors.append("rules_version: unsupported")
	if not errors.is_empty():
		return _validation(errors)
	match record["status"]:
		"legacy_unknown":
			errors.append_array(_empty_trace_errors(record))
			if record["origin"] != "legacy_record" or record["condition"] != null:
				errors.append("legacy_unknown: origin or condition is invalid")
			if record["next_day_effect"] != null:
				errors.append("legacy_unknown: next_day_effect must be null")
			if record["reason_ids"] != ["LEGACY_RECOVERY_NOT_RECORDED"]:
				errors.append("legacy_unknown: expected explicit missing-history reason")
		"known":
			if record["origin"] == "new_run_default":
				errors.append_array(_empty_trace_errors(record))
				if record["condition"] != "steady" or record["reason_ids"] != ["NEW_RUN_DEFAULT"]:
					errors.append("new_run_default: must be explicit steady default")
				errors.append_array(_effect_errors(record["next_day_effect"], "steady"))
			elif record["origin"] == "day_settlement":
				errors.append_array(_day_record_errors(record))
			else:
				errors.append("origin: invalid for known recovery")
		_:
			errors.append("status: invalid or unsupported recovery cannot be consumed")
	return _validation(errors)


static func normalize(record: Dictionary) -> Dictionary:
	if not validate(record)["valid"]:
		return {}
	return _normalize_value(record)


static func _empty_record(status: String, origin: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "rules_version": RULES_VERSION,
		"status": status, "condition": null, "origin": origin,
		"evaluated_day": null, "inputs": null, "sleep_snapshot": null,
		"before_sleep": null, "after_sleep": null, "end_of_day": null,
		"settlement_effects": [], "clamp_delta": null,
		"reason_ids": [], "matched_rule_ids": [], "next_day_effect": null,
	}


static func _trace_input_errors(
	day: Variant, before: Variant, sleep: Variant, effects: Variant
) -> Array[String]:
	var errors: Array[String] = []
	if not Rules.is_integer(day) or day < 1 or day > 7:
		errors.append("evaluated_day: expected integer 1..7")
	errors.append_array(_pair_errors(before, "before_sleep", true))
	var sleep_errors := _keys_errors(sleep, SLEEP_KEYS, "sleep_snapshot")
	errors.append_array(sleep_errors)
	if sleep_errors.is_empty():
		if not Rules.SLEEP_IDS.has(sleep["id"]):
			errors.append("sleep_snapshot.id: unknown sleep option")
		for key in SLEEP_KEYS:
			if key != "id" and not Rules.is_integer(sleep[key]):
				errors.append("sleep_snapshot.%s: expected safe integer" % key)
	errors.append_array(_effects_errors(effects))
	return errors


static func _effects_errors(effects: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not effects is Array or effects.size() > MAX_SETTLEMENT_EFFECTS:
		return ["settlement_effects: expected bounded array"]
	for index in range(effects.size()):
		var prefix := "settlement_effects[%d]" % index
		var item: Variant = effects[index]
		var item_errors := _keys_errors(item, ["source_id", "requested_delta"], prefix)
		errors.append_array(item_errors)
		if not item_errors.is_empty():
			continue
		if not _is_source_id(item["source_id"]):
			errors.append(prefix + ".source_id: expected stable identifier")
		if not item["requested_delta"] is Dictionary:
			errors.append(prefix + ".requested_delta: expected dictionary")
			continue
		for key in item["requested_delta"]:
			if not DELTA_KEYS.has(key) or not Rules.is_integer(item["requested_delta"][key]):
				errors.append(prefix + ".requested_delta: invalid key or numeric value")
	return errors


static func _calculate_trace(before: Dictionary, sleep: Dictionary, effects: Array) -> Dictionary:
	var after := {}
	var end := {}
	var clamp_delta := {}
	for key in PAIR_KEYS:
		var value: Variant = _safe_add(int(before[key]), int(sleep[key]))
		if value == null:
			return {}
		after[key] = value
		for effect in effects:
			value = _safe_add(int(value), int(effect["requested_delta"].get(key, 0)))
			if value == null:
				return {}
		end[key] = clampi(int(value), 0, 100)
		clamp_delta[key] = int(end[key]) - int(value)
	return {"after_sleep": after, "end_of_day": end, "clamp_delta": clamp_delta}


static func _day_record_errors(record: Dictionary) -> Array[String]:
	var errors := _trace_input_errors(
		record["evaluated_day"], record["before_sleep"],
		record["sleep_snapshot"], record["settlement_effects"]
	)
	errors.append_array(Rules.validate_inputs(record["inputs"]))
	errors.append_array(_pair_errors(record["after_sleep"], "after_sleep", false))
	errors.append_array(_pair_errors(record["end_of_day"], "end_of_day", true))
	errors.append_array(_pair_errors(record["clamp_delta"], "clamp_delta", false))
	if errors.is_empty():
		var trace := _calculate_trace(
			record["before_sleep"], record["sleep_snapshot"], record["settlement_effects"]
		)
		if trace.is_empty():
			errors.append("trace: arithmetic exceeds safe integer range")
		else:
			for key in trace:
				if trace[key] != _normalize_value(record[key]):
					errors.append("%s: inconsistent with frozen trace" % key)
		for key in PAIR_KEYS:
			if record["inputs"][key] != record["end_of_day"][key]:
				errors.append("inputs.%s: inconsistent with end_of_day" % key)
		if record["inputs"]["sleep_id"] != record["sleep_snapshot"]["id"]:
			errors.append("inputs.sleep_id: inconsistent with sleep_snapshot")
	errors.append_array(_outcome_errors(record))
	return errors


static func _outcome_errors(record: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not Rules.CONDITIONS.has(record["condition"]):
		return ["condition: unknown recovery condition"]
	errors.append_array(_string_list_errors(record["reason_ids"], "reason_ids", Rules.REASON_IDS, true))
	errors.append_array(_string_list_errors(
		record["matched_rule_ids"], "matched_rule_ids",
		Rules.RULE_IDS_BY_CONDITION[record["condition"]], true
	))
	if errors.is_empty():
		for rule_id in record["matched_rule_ids"]:
			if not record["reason_ids"].has(rule_id):
				errors.append("reason_ids: missing deciding rule %s" % rule_id)
	errors.append_array(_effect_errors(record["next_day_effect"], record["condition"]))
	return errors


static func _effect_errors(value: Variant, condition: String) -> Array[String]:
	var errors := _keys_errors(value, ["study_modifier", "opening_delta"], "next_day_effect")
	if not errors.is_empty():
		return errors
	if not Rules.is_integer(value["study_modifier"]) or not value["opening_delta"] is Dictionary:
		return ["next_day_effect: invalid effect values"]
	for key in value["opening_delta"]:
		if not ["energy", "mood", "stress"].has(key) or not Rules.is_integer(value["opening_delta"][key]):
			errors.append("next_day_effect.opening_delta: invalid key or value")
	if errors.is_empty() and _normalize_value(value) != Rules.effect_for(condition):
		errors.append("next_day_effect: inconsistent with recorded condition/version")
	return errors


static func _empty_trace_errors(record: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in NULL_TRACE_KEYS:
		if record[key] != null:
			errors.append("%s: must be null without a day settlement" % key)
	for key in ["settlement_effects", "matched_rule_ids"]:
		if record[key] != []:
			errors.append("%s: must be empty without a day settlement" % key)
	return errors


static func _keys_errors(value: Variant, keys: Array, path: String) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		return [path + ": expected dictionary"]
	for key in keys:
		if not value.has(key):
			errors.append("%s.%s: missing field" % [path, key])
	for key in value:
		if not keys.has(key):
			errors.append(path + ": unexpected field")
	return errors


static func _pair_errors(value: Variant, path: String, bounded: bool) -> Array[String]:
	var errors := _keys_errors(value, PAIR_KEYS, path)
	if not errors.is_empty():
		return errors
	for key in PAIR_KEYS:
		if not Rules.is_integer(value[key]):
			errors.append("%s.%s: expected safe integer" % [path, key])
		elif bounded and (value[key] < 0 or value[key] > 100):
			errors.append("%s.%s: outside 0..100" % [path, key])
	return errors


static func _string_list_errors(
	value: Variant, path: String, allowed: Array, require_nonempty: bool
) -> Array[String]:
	if not value is Array or (require_nonempty and value.is_empty()):
		return [path + ": expected nonempty array"]
	var seen := {}
	for item in value:
		if not item is String or item.is_empty():
			return [path + ": invalid identifier"]
		if seen.has(item) or (not allowed.is_empty() and not allowed.has(item)):
			return [path + ": duplicate or unknown identifier"]
		seen[item] = true
	return []


static func _is_source_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64:
		return false
	for character in value:
		if not "abcdefghijklmnopqrstuvwxyz0123456789_".contains(character):
			return false
	return true


static func _safe_add(left: int, right: int) -> Variant:
	if (right > 0 and left > MAX_SAFE_INTEGER - right) or (
		right < 0 and left < -MAX_SAFE_INTEGER - right
	):
		return null
	return left + right


static func _normalize_value(value: Variant) -> Variant:
	if value is Dictionary:
		var copy := {}
		for key in value:
			copy[key] = _normalize_value(value[key])
		return copy
	if value is Array:
		var copy: Array = []
		for item in value:
			copy.append(_normalize_value(item))
		return copy
	if value is float:
		return int(value)
	return value


static func _validation(errors: Array[String]) -> Dictionary:
	return {"valid": errors.is_empty(), "errors": errors}


static func _build_failure(errors: Array) -> Dictionary:
	return {
		"valid": false, "errors": errors.duplicate(),
		"recovery_state": unavailable("invalid", "INVALID_RECOVERY_INPUT"),
	}
