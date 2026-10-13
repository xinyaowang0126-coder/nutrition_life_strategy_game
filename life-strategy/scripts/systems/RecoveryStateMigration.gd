class_name RecoveryStateMigration
extends RefCounted

## Pure adapter for recovery records, not a complete game save or a health archive.
## No input is modified; loading history never reads current data or evaluates rules.
const StateScript := preload("res://scripts/systems/RecoveryStateService.gd")
const RulesScript := preload("res://scripts/systems/RecoveryRules.gd")

const GAMEPLAY_STATE_VERSION := 2
const KIND := "gameplay_recovery"
const ENVELOPE_KEYS := ["kind", "gameplay_state_version", "recovery_state"]
const LEGACY_STAT_KEYS := [
	"stability", "balance", "energy", "mood", "satiety", "stress",
	"burden", "diet_burden", "character_health", "study_progress", "study_target", "quality",
]
const LEGACY_RECOGNITION_KEYS := ["energy", "stress", "burden", "diet_burden", "character_health"]
const NEW_RECOVERY_KEYS := [
	"recovery_state", "rules_version", "condition", "next_day_effect", "evaluated_day",
	"inputs", "sleep_snapshot", "before_sleep", "after_sleep", "end_of_day",
	"settlement_effects", "clamp_delta", "reason_ids", "matched_rule_ids",
]


static func load_data(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return _failure("invalid", "RECOVERY_ENVELOPE_NOT_DICTIONARY")
	var envelope := data as Dictionary
	if envelope.has("gameplay_state_version"):
		var version: Variant = envelope["gameplay_state_version"]
		if not _is_integer(version) or version < 1:
			return _failure("invalid", "INVALID_GAMEPLAY_STATE_VERSION")
		if version > GAMEPLAY_STATE_VERSION:
			return _failure("unsupported_version", "UNSUPPORTED_GAMEPLAY_STATE_VERSION")
		if int(version) == GAMEPLAY_STATE_VERSION:
			return _load_current(envelope)
		return _load_legacy(envelope, true)
	return _load_legacy(envelope, false)


## The wrapper keeps failed records out of serialization. Only data is JSON payload.
static func encode(record: Variant) -> Dictionary:
	var result := load_data({
		"kind": KIND,
		"gameplay_state_version": GAMEPLAY_STATE_VERSION,
		"recovery_state": record,
	})
	if result["status"] not in ["known", "legacy_unknown"]:
		return {"valid": false, "errors": result["errors"].duplicate(), "data": null}
	return {
		"valid": true,
		"errors": [] as Array[String],
		"data": {
			"kind": KIND,
			"gameplay_state_version": GAMEPLAY_STATE_VERSION,
			"recovery_state": result["recovery_state"],
		},
	}


static func _load_current(envelope: Dictionary) -> Dictionary:
	for key in envelope:
		if not key is String or key not in ENVELOPE_KEYS:
			return _failure("invalid", "UNEXPECTED_RECOVERY_ENVELOPE_FIELD")
	if envelope.get("kind") != KIND:
		return _failure("invalid", "INVALID_RECOVERY_ENVELOPE_KIND")
	if not envelope.get("recovery_state") is Dictionary:
		return _failure("invalid", "MISSING_OR_INVALID_RECOVERY_STATE")
	var record: Dictionary = envelope["recovery_state"]
	var schema_version: Variant = record.get("schema_version")
	if not _is_integer(schema_version) or schema_version < 1:
		return _failure("invalid", "INVALID_RECOVERY_SCHEMA_VERSION")
	if schema_version > StateScript.SCHEMA_VERSION:
		return _failure("unsupported_version", "UNSUPPORTED_RECOVERY_SCHEMA_VERSION")
	var rules_version: Variant = record.get("rules_version")
	if not rules_version is String or rules_version.is_empty():
		return _failure("invalid", "INVALID_RECOVERY_RULES_VERSION")
	if rules_version != StateScript.RULES_VERSION:
		return _failure("unsupported_version", "UNSUPPORTED_RECOVERY_RULES_VERSION")
	var validation: Dictionary = StateScript.validate(record)
	if not bool(validation["valid"]):
		return _failure("invalid", "INVALID_RECOVERY_RECORD", validation["errors"])
	if record.get("status") not in ["known", "legacy_unknown"]:
		return _failure("invalid", "RECOVERY_STATUS_NOT_HISTORICAL")
	return _success(StateScript.normalize(record))


static func _load_legacy(envelope: Dictionary, explicit_v1: bool) -> Dictionary:
	# Archive markers are never interpreted as gameplay, even in a mixed object.
	if envelope.has("schema_version") or envelope.has("snapshots"):
		return _failure("invalid", "NOT_A_LEGACY_GAMEPLAY_RECORD")
	if envelope.has("kind") and envelope["kind"] != KIND:
		return _failure("invalid", "NOT_A_LEGACY_GAMEPLAY_RECORD")
	if _has_new_recovery_fields(envelope):
		return _failure("invalid", "RECOVERY_FIELDS_REQUIRE_CURRENT_VERSION")
	if not _is_json_value(envelope):
		return _failure("invalid", "INVALID_LEGACY_RECORD_VALUE")
	var payload := envelope.duplicate()
	if explicit_v1:
		# A version declaration alone is not evidence that a gameplay record exists.
		payload.erase("gameplay_state_version")
		payload.erase("kind")
	if payload.has("start_state") or payload.has("end_state"):
		if not _is_legacy_stats(payload.get("start_state")) \
			or not _is_legacy_stats(payload.get("end_state")):
			return _failure("invalid", "INVALID_LEGACY_DAY_RECORD")
		if payload.has("state") and not _is_legacy_stats(payload["state"]):
			return _failure("invalid", "INVALID_LEGACY_GAMEPLAY_STATE")
	elif explicit_v1 and payload.has("state"):
		if payload.size() != 1 or not _is_legacy_stats(payload["state"]):
			return _failure("invalid", "INVALID_LEGACY_GAMEPLAY_STATE")
	elif not _is_legacy_stats(payload):
		return _failure("invalid", "NOT_A_LEGACY_GAMEPLAY_RECORD")
	return _success(StateScript.unavailable("legacy_unknown", "LEGACY_RECOVERY_NOT_RECORDED"))


static func _has_new_recovery_fields(record: Dictionary) -> bool:
	for key in NEW_RECOVERY_KEYS:
		if record.has(key):
			return true
	for key in ["state", "start_state", "end_state"]:
		if record.get(key) is Dictionary:
			for recovery_key in NEW_RECOVERY_KEYS:
				if record[key].has(recovery_key):
					return true
	return false


static func _is_legacy_stats(value: Variant) -> bool:
	if not value is Dictionary or value.is_empty():
		return false
	var recognized := false
	for key in value:
		if not key is String or key not in LEGACY_STAT_KEYS or not _is_integer(value[key]):
			return false
		if key in LEGACY_RECOGNITION_KEYS:
			recognized = true
	return recognized


static func _is_integer(value: Variant) -> bool:
	return RulesScript.is_integer(value)


static func _is_json_value(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for item in value:
				if not _is_json_value(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not key is String or not _is_json_value(value[key], depth + 1):
					return false
			return true
	return false


static func _success(record: Dictionary) -> Dictionary:
	return {
		"status": record["status"],
		"gameplay_state_version": GAMEPLAY_STATE_VERSION,
		"recovery_state": record,
		"errors": [] as Array[String],
	}


static func _failure(status: String, reason: String, details: Array = []) -> Dictionary:
	var errors: Array[String] = [reason]
	for detail in details:
		errors.append(String(detail))
	return {
		"status": status,
		"gameplay_state_version": GAMEPLAY_STATE_VERSION,
		"recovery_state": StateScript.unavailable(status, reason),
		"errors": errors,
	}
