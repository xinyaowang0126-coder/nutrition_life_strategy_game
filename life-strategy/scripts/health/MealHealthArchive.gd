class_name MealHealthArchive
extends RefCounted

## Stores immutable health snapshots only, not the rest of a playable game save.
## Loading is transactional: invalid input never replaces the current archive.

const SnapshotScript := preload("res://scripts/health/MealHealthSnapshot.gd")
const SCHEMA_VERSION := 1
const ARCHIVE_KIND := "meal_health_archive"
const MAX_SAFE_JSON_INTEGER := 9007199254740991

var _snapshots: Array[Dictionary] = []


func clear() -> void:
	_snapshots.clear()


func append_snapshot(snapshot: Dictionary) -> Dictionary:
	var error := _snapshot_error(snapshot)
	if not error.is_empty():
		return _failure("invalid_snapshot", error)
	_snapshots.append(_copy_snapshot(snapshot))
	return _success("appended")


func get_snapshots() -> Array[Dictionary]:
	return _snapshots.duplicate(true)


func to_save_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"kind": ARCHIVE_KIND,
		"snapshots": get_snapshots(),
	}


func load_data(data: Variant) -> Dictionary:
	if data is Array:
		return _load_entries(data, true, 0)
	if not data is Dictionary:
		return _failure("invalid_data", "Archive must be an object or legacy meal record array.")
	if not data.has("schema_version"):
		if not data.get("meal_records") is Array or not _is_day(data.get("day", 0)):
			return _failure("invalid_legacy_data", "Legacy archive needs meal_records and a valid day.")
		return _load_entries(data["meal_records"], true, int(data.get("day", 0)))
	var version: Variant = data["schema_version"]
	if not _is_day(version):
		return _failure("invalid_schema_version", "Archive schema_version must be a nonnegative integer.")
	if int(version) > SCHEMA_VERSION:
		return _failure("unsupported_future_schema", "Archive schema is newer than supported.")
	if int(version) < SCHEMA_VERSION:
		return _failure("unsupported_legacy_schema", "Versioned archive schema is not supported.")
	if data.get("kind") != ARCHIVE_KIND or not data.get("snapshots") is Array:
		return _failure("invalid_data", "Archive kind or snapshots field is invalid.")
	return _load_entries(data["snapshots"], false, 0)


func save_file(path: String) -> Dictionary:
	if path.strip_edges().is_empty():
		return _failure("invalid_path", "Archive path is empty.")
	var target := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(target):
		return _failure("invalid_path", "Archive target is a directory.")
	var temporary := _temporary_path(target)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("write_failed", "Cannot open temporary archive (error %d)." % FileAccess.get_open_error())
	file.store_string(JSON.stringify(to_save_data(), "\t", true, true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return _failure("write_failed", "Cannot write temporary archive (error %d)." % write_error)
	# Same-directory rename replaces the file without first deleting the old archive.
	var rename_error := DirAccess.rename_absolute(temporary, target)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
		return _failure("replace_failed", "Cannot replace archive (error %d)." % rename_error)
	return _success("saved")


func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("missing_file", "Health archive file does not exist.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("read_failed", "Cannot open health archive (error %d)." % FileAccess.get_open_error())
	var content := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return _failure("read_failed", "Cannot read health archive (error %d)." % read_error)
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return _failure("invalid_json", "Invalid archive JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
	return load_data(parser.data)


func _load_entries(entries: Array, legacy: bool, fallback_day: int) -> Dictionary:
	var pending: Array[Dictionary] = []
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		if not entry is Dictionary:
			return _failure("invalid_record", "Record %d must be an object." % index)
		var snapshot: Variant = entry
		if legacy:
			if entry.has("health_snapshot"):
				snapshot = entry["health_snapshot"]
			elif entry.has("snapshot_schema_version"):
				snapshot = entry
			elif entry.has("schema_version"):
				return _failure("invalid_record", "Record %d has an unsupported schema envelope." % index)
			else:
				if not _is_day(entry.get("day", fallback_day)):
					return _failure("invalid_record", "Record %d has an invalid day." % index)
				snapshot = SnapshotScript.legacy(int(entry.get("day", fallback_day)), entry)
		var error := _snapshot_error(snapshot)
		if not error.is_empty():
			return _failure("invalid_snapshot", "Record %d: %s" % [index, error])
		pending.append(_copy_snapshot(snapshot))
	_snapshots = pending
	return _success("migrated_legacy" if legacy else "ready")


static func _snapshot_error(snapshot: Variant) -> String:
	if not _is_json_value(snapshot):
		return "Snapshot contains a value that cannot be preserved in JSON."
	var validation: Dictionary = SnapshotScript.validate(snapshot)
	if not bool(validation.get("valid", false)):
		return "Invalid health snapshot: %s" % str(validation.get("errors", []))
	return ""


static func _copy_snapshot(snapshot: Dictionary) -> Dictionary:
	# JSON decodes integer tokens as floats. Only schema-defined integers are
	# normalized; estimated amounts keep their original numeric precision.
	var copy := snapshot.duplicate(true)
	copy["snapshot_schema_version"] = int(copy["snapshot_schema_version"])
	if copy["day"] != null:
		copy["day"] = int(copy["day"])
	for food_id in copy["profile_versions"]:
		copy["profile_versions"][food_id] = int(copy["profile_versions"][food_id])
	for profile in (copy["profile_snapshots"] as Dictionary).values():
		profile["profile_version"] = int(profile["profile_version"])
	for key in ["component_snapshot", "factor_snapshot"]:
		for entry in copy[key]:
			entry["profile_version"] = int(entry["profile_version"])
	return copy


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


static func _is_day(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and (
		float(value) >= 0.0 and float(value) <= MAX_SAFE_JSON_INTEGER
		and float(value) == floor(float(value))
	)


static func _temporary_path(target: String) -> String:
	var candidate := "%s.tmp-%d-%d" % [target, OS.get_process_id(), Time.get_ticks_usec()]
	while FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
		candidate += "-next"
	return candidate


static func _failure(status: String, error: String) -> Dictionary:
	return {"ok": false, "status": status, "error": error}


static func _success(status: String) -> Dictionary:
	return {"ok": true, "status": status, "error": ""}
