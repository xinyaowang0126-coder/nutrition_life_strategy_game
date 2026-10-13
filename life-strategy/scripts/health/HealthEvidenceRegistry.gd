class_name HealthEvidenceRegistry
extends RefCounted

## Read-only evidence metadata registry. Source lifecycle is kept separate from
## professional approval of profiles and player-facing copy.

const DEFAULT_REGISTRY_PATH := "res://data/health/evidence_registry.xml"
const XmlStructure := preload("res://scripts/health/HealthXmlStructure.gd")
const ROOT_ELEMENT := "evidence_registry"
const SUPPORTED_SCHEMA_VERSION := 1
const EVIDENCE_STATUSES := ["active", "superseded", "needs_review"]

const STATUS_NOT_LOADED := "not_loaded"
const STATUS_READY := "ready"
const STATUS_READY_EMPTY := "ready_empty"
const STATUS_MISSING := "missing"
const STATUS_EMPTY_FILE := "empty_file"
const STATUS_INVALID_XML := "invalid_xml"
const STATUS_INVALID_ROOT := "invalid_root"
const STATUS_INVALID_SCHEMA_VERSION := "invalid_schema_version"
const STATUS_UNSUPPORTED_LEGACY_SCHEMA := "unsupported_legacy_schema"
const STATUS_UNSUPPORTED_FUTURE_SCHEMA := "unsupported_future_schema"

var _registry: Dictionary = {}
var _records: Dictionary = {}
var _record_entries: Array = []


func _init() -> void:
	_reset(DEFAULT_REGISTRY_PATH)


func load_registry(path: String = DEFAULT_REGISTRY_PATH) -> Dictionary:
	_reset(path)
	if not FileAccess.file_exists(path):
		return _fail(STATUS_MISSING, "Evidence registry is missing: %s" % path, true)
	var xml := FileAccess.get_file_as_string(path).strip_edges()
	if xml.is_empty():
		return _fail(
			STATUS_EMPTY_FILE,
			"Evidence registry contains no XML root: %s" % path,
			true
		)

	var buffer := xml.to_utf8_buffer()
	var structure_error := XmlStructure.validate(buffer)
	if not structure_error.is_empty():
		return _fail(STATUS_INVALID_XML, structure_error, true)
	var parser := XMLParser.new()
	var open_error := parser.open_buffer(buffer)
	if open_error != OK:
		return _fail(
			STATUS_INVALID_XML,
			"Evidence registry could not be opened: %s (error %d)" % [path, open_error],
			true
		)

	var root_seen := false
	var current_record: Dictionary = {}
	var read_error := parser.read()
	while read_error == OK:
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			if not root_seen:
				if node_name != ROOT_ELEMENT:
					return _fail(
						STATUS_INVALID_ROOT,
						"Expected <%s> root but found <%s>." % [ROOT_ELEMENT, node_name],
						true
					)
				root_seen = true
				_read_root(_read_attributes(parser))
				if String(_registry["status"]) != STATUS_NOT_LOADED:
					return _snapshot()
			elif node_name == "evidence":
				current_record = _record_from_attributes(_read_attributes(parser))
				if parser.is_empty():
					_store_record(current_record)
					current_record = {}
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "evidence" and not current_record.is_empty():
				_store_record(current_record)
				current_record = {}
		read_error = parser.read()

	if read_error != ERR_FILE_EOF:
		return _fail(
			STATUS_INVALID_XML,
			"Evidence registry could not be parsed: %s (error %d)" % [path, read_error],
			true
		)
	if not root_seen:
		return _fail(
			STATUS_EMPTY_FILE,
			"Evidence registry contains no XML root: %s" % path,
			true
		)

	_registry["available"] = true
	_registry["degraded"] = false
	_registry["status"] = STATUS_READY_EMPTY if _records.is_empty() else STATUS_READY
	return _snapshot()


func get_registry() -> Dictionary:
	return _snapshot()


func get_evidence_ids() -> Array[String]:
	var ids: Array[String] = []
	for evidence_id in _records.keys():
		ids.append(String(evidence_id))
	ids.sort()
	return ids


func has_evidence(evidence_id: String) -> bool:
	return bool(_registry.get("available", false)) and _records.has(evidence_id)


func get_evidence(evidence_id: String) -> Dictionary:
	if not has_evidence(evidence_id):
		return {}
	return (_records[evidence_id] as Dictionary).duplicate(true)


func audit(as_of_date: String) -> Dictionary:
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var active_ids: Array[String] = []
	var superseded_ids: Array[String] = []
	var needs_review_ids: Array[String] = []
	var review_due_ids: Array[String] = []
	var invalid_ids: Array[String] = []
	var duplicate_ids: Array[String] = []
	var review_due_at_by_id := {}
	var earliest_review_due_at := ""
	var next_review_due_at := ""

	if not bool(_registry.get("available", false)):
		_add_issue(
			errors,
			"error",
			"registry_unavailable",
			"",
			"status",
			"Evidence registry is unavailable: %s" % String(_registry.get("status", "unknown"))
		)
		return _audit_report(
			as_of_date,
			errors,
			warnings,
			active_ids,
			superseded_ids,
			needs_review_ids,
			review_due_ids,
			invalid_ids,
			duplicate_ids,
			review_due_at_by_id,
			earliest_review_due_at,
			next_review_due_at
		)
	if not _is_valid_iso_date(as_of_date):
		_add_issue(
			errors,
			"error",
			"as_of_date_invalid",
			"",
			"as_of_date",
			"as_of_date must use a real YYYY-MM-DD calendar date."
		)
		return _audit_report(
			as_of_date,
			errors,
			warnings,
			active_ids,
			superseded_ids,
			needs_review_ids,
			review_due_ids,
			invalid_ids,
			duplicate_ids,
			review_due_at_by_id,
			earliest_review_due_at,
			next_review_due_at
		)

	var counts := {}
	for record_value in _record_entries:
		if not record_value is Dictionary:
			continue
		var entry_id := String((record_value as Dictionary).get("evidence_id", ""))
		if entry_id.is_empty():
			continue
		counts[entry_id] = int(counts.get(entry_id, 0)) + 1
	for evidence_id_value in counts.keys():
		var counted_id := String(evidence_id_value)
		if int(counts[evidence_id_value]) > 1:
			duplicate_ids.append(counted_id)
			_append_unique(invalid_ids, counted_id)
			_add_issue(
				errors,
				"error",
				"evidence_id_duplicate",
				counted_id,
				"evidence_id",
				"Evidence IDs must be unique."
			)
	duplicate_ids.sort()

	for evidence_id in get_evidence_ids():
		var record := _records[evidence_id] as Dictionary
		var error_count_before := errors.size()
		_validate_record(record, errors, warnings)
		if errors.size() > error_count_before:
			_append_unique(invalid_ids, evidence_id)

		var status := String(record.get("status", ""))
		match status:
			"active":
				active_ids.append(evidence_id)
			"superseded":
				superseded_ids.append(evidence_id)
			"needs_review":
				needs_review_ids.append(evidence_id)
				_add_issue(
					warnings,
					"warning",
					"evidence_needs_review",
					evidence_id,
					"status",
					"Evidence cannot support player guidance until review is complete."
				)

		var due_at := String(record.get("review_due_at", ""))
		if _is_valid_iso_date(due_at):
			review_due_at_by_id[evidence_id] = due_at
			if status != "superseded":
				if earliest_review_due_at.is_empty() or due_at < earliest_review_due_at:
					earliest_review_due_at = due_at
				if due_at <= as_of_date:
					review_due_ids.append(evidence_id)
					_add_issue(
						warnings,
						"warning",
						"review_due",
						evidence_id,
						"review_due_at",
						"Evidence review was due on %s." % due_at
					)
				elif next_review_due_at.is_empty() or due_at < next_review_due_at:
					next_review_due_at = due_at

	active_ids.sort()
	superseded_ids.sort()
	needs_review_ids.sort()
	review_due_ids.sort()
	invalid_ids.sort()
	return _audit_report(
		as_of_date,
		errors,
		warnings,
		active_ids,
		superseded_ids,
		needs_review_ids,
		review_due_ids,
		invalid_ids,
		duplicate_ids,
		review_due_at_by_id,
		earliest_review_due_at,
		next_review_due_at
	)


func check_references(
	evidence_ids: Variant,
	as_of_date: String,
	required_capabilities: Variant = []
) -> Dictionary:
	var reference_ids := _string_array(evidence_ids)
	var unique_ids: Array[String] = []
	for evidence_id in reference_ids:
		if not unique_ids.has(evidence_id):
			unique_ids.append(evidence_id)
	var required_capability_ids: Array[String] = []
	for capability in _string_array(required_capabilities):
		if not required_capability_ids.has(capability):
			required_capability_ids.append(capability)
	required_capability_ids.sort()

	var missing_ids: Array[String] = []
	var usable_ids: Array[String] = []
	var review_due_ids: Array[String] = []
	var needs_review_ids: Array[String] = []
	var superseded_ids: Array[String] = []
	var invalid_ids: Array[String] = []
	var replacement_chains := {}
	var replacement_ids := {}
	var audit_report := audit(as_of_date)

	if bool(audit_report.get("registry_available", false)) and bool(
		audit_report.get("as_of_date_valid", false)
	):
		var audit_invalid_ids := _string_array(audit_report.get("invalid_ids", []))
		for evidence_id in unique_ids:
			if not _records.has(evidence_id):
				missing_ids.append(evidence_id)
				continue
			if audit_invalid_ids.has(evidence_id):
				invalid_ids.append(evidence_id)
				continue
			var record := _records[evidence_id] as Dictionary
			var status := String(record.get("status", ""))
			if status == "superseded":
				superseded_ids.append(evidence_id)
				var resolution := _replacement_resolution(evidence_id)
				replacement_chains[evidence_id] = resolution["chain"]
				var replacement_id := String(resolution.get("final_id", ""))
				if _is_usable_record(replacement_id, as_of_date, audit_invalid_ids):
					replacement_ids[evidence_id] = replacement_id
				continue
			if status == "needs_review":
				needs_review_ids.append(evidence_id)
				continue
			if String(record.get("review_due_at", "")) <= as_of_date:
				review_due_ids.append(evidence_id)
				continue
			usable_ids.append(evidence_id)

	var unusable_ids: Array[String] = []
	for source in [
		missing_ids,
		review_due_ids,
		needs_review_ids,
		superseded_ids,
		invalid_ids,
	]:
		for evidence_id in source:
			_append_unique(unusable_ids, evidence_id)

	var supporting_ids_by_capability := {}
	var explicitly_unsupported_ids_by_capability := {}
	var unsupported_capabilities: Array[String] = []
	for capability in required_capability_ids:
		var supporting_ids: Array[String] = []
		var explicitly_unsupported_ids: Array[String] = []
		for evidence_id in usable_ids:
			var record := _records[evidence_id] as Dictionary
			if _string_array(record.get("supports", [])).has(capability):
				supporting_ids.append(evidence_id)
			if _string_array(record.get("does_not_support", [])).has(capability):
				explicitly_unsupported_ids.append(evidence_id)
		supporting_ids.sort()
		explicitly_unsupported_ids.sort()
		supporting_ids_by_capability[capability] = supporting_ids
		explicitly_unsupported_ids_by_capability[capability] = explicitly_unsupported_ids
		if supporting_ids.is_empty():
			unsupported_capabilities.append(capability)

	return {
		"valid": (
			bool(audit_report.get("registry_available", false))
			and bool(audit_report.get("as_of_date_valid", false))
			and unusable_ids.is_empty()
			and unsupported_capabilities.is_empty()
		),
		"as_of_date": as_of_date,
		"reference_ids": unique_ids.duplicate(),
		"missing_ids": missing_ids.duplicate(),
		"usable_ids": usable_ids.duplicate(),
		"review_due_ids": review_due_ids.duplicate(),
		"needs_review_ids": needs_review_ids.duplicate(),
		"superseded_ids": superseded_ids.duplicate(),
		"invalid_ids": invalid_ids.duplicate(),
		"unusable_ids": unusable_ids.duplicate(),
		"required_capabilities": required_capability_ids.duplicate(),
		"unsupported_capabilities": unsupported_capabilities.duplicate(),
		"supporting_ids_by_capability": supporting_ids_by_capability.duplicate(true),
		"explicitly_unsupported_ids_by_capability": (
			explicitly_unsupported_ids_by_capability.duplicate(true)
		),
		"replacement_chains": replacement_chains.duplicate(true),
		"replacement_ids": replacement_ids.duplicate(true),
		"registry_audit": audit_report.duplicate(true),
	}


func get_replacement_chain(evidence_id: String) -> Array[String]:
	return _string_array(_replacement_resolution(evidence_id).get("chain", []))


func get_deprecated_ids(as_of_date: String) -> Array[String]:
	var report := audit(as_of_date)
	var result: Array[String] = []
	for key in ["superseded_ids", "needs_review_ids", "review_due_ids", "invalid_ids"]:
		for evidence_id in _string_array(report.get(key, [])):
			_append_unique(result, evidence_id)
	result.sort()
	return result


func _reset(path: String) -> void:
	_records.clear()
	_record_entries.clear()
	_registry = {
		"path": path,
		"status": STATUS_NOT_LOADED,
		"available": false,
		"degraded": false,
		"schema_version": -1,
		"supported_schema_version": SUPPORTED_SCHEMA_VERSION,
		"registry_version": "",
		"locale": "",
		"accessed_at": "",
		"evidence_count": 0,
		"warnings": [],
		"errors": [],
	}


func _read_root(attributes: Dictionary) -> void:
	_registry["registry_version"] = String(attributes.get("registry_version", ""))
	_registry["locale"] = String(attributes.get("locale", ""))
	_registry["accessed_at"] = String(attributes.get("accessed_at", ""))
	var raw_schema_version := String(attributes.get("schema_version", ""))
	if not raw_schema_version.is_valid_int():
		_fail(
			STATUS_INVALID_SCHEMA_VERSION,
			"Evidence registry schema_version must be an integer.",
			true
		)
		return
	var schema_version := int(raw_schema_version)
	_registry["schema_version"] = schema_version
	if schema_version < SUPPORTED_SCHEMA_VERSION:
		_fail(
			STATUS_UNSUPPORTED_LEGACY_SCHEMA,
			"Evidence registry schema %d is older than supported schema %d." % [
				schema_version,
				SUPPORTED_SCHEMA_VERSION,
			],
			true
		)
	elif schema_version > SUPPORTED_SCHEMA_VERSION:
		_fail(
			STATUS_UNSUPPORTED_FUTURE_SCHEMA,
			"Evidence registry schema %d is newer than supported schema %d." % [
				schema_version,
				SUPPORTED_SCHEMA_VERSION,
			],
			true
		)


func _record_from_attributes(attributes: Dictionary) -> Dictionary:
	return {
		"evidence_id": String(attributes.get("evidence_id", "")),
		"title": String(attributes.get("title", "")),
		"publisher": String(attributes.get("publisher", "")),
		"url": String(attributes.get("url", "")),
		"published_at": String(attributes.get("published_at", "")),
		"accessed_at": String(attributes.get("accessed_at", "")),
		"jurisdiction": String(attributes.get("jurisdiction", "")),
		"population_scope": String(attributes.get("population_scope", "")),
		"supports": _split_pipe(String(attributes.get("supports", ""))),
		"does_not_support": _split_pipe(String(attributes.get("does_not_support", ""))),
		"scope_note": String(attributes.get("scope_note", "")),
		"boundary_note": String(attributes.get("boundary_note", "")),
		"effective_at": String(attributes.get("effective_at", "")),
		"review_due_at": String(attributes.get("review_due_at", "")),
		"review_reason": String(attributes.get("review_reason", "")),
		"status": String(attributes.get("status", "")),
		"superseded_by": String(attributes.get("superseded_by", "")),
		"source_type": String(attributes.get("source_type", "")),
	}


func _store_record(record: Dictionary) -> void:
	_record_entries.append(record.duplicate(true))
	var evidence_id := String(record.get("evidence_id", ""))
	if evidence_id.is_empty():
		(_registry["warnings"] as Array).append("An evidence record without evidence_id was skipped.")
		return
	if _records.has(evidence_id):
		(_registry["warnings"] as Array).append(
			"Duplicate evidence '%s' was skipped; audit must block this registry." % evidence_id
		)
		return
	_records[evidence_id] = record.duplicate(true)


func _validate_record(
	record: Dictionary,
	errors: Array[Dictionary],
	warnings: Array[Dictionary]
) -> void:
	var evidence_id := String(record.get("evidence_id", ""))
	for field_name in [
		"evidence_id",
		"title",
		"publisher",
		"published_at",
		"accessed_at",
		"jurisdiction",
		"population_scope",
		"review_due_at",
		"review_reason",
		"status",
		"source_type",
	]:
		if String(record.get(field_name, "")).strip_edges().is_empty():
			_add_issue(
				errors,
				"error",
				"required_field_missing",
				evidence_id,
				field_name,
				"Evidence field '%s' is required." % field_name
			)
	var source_type := String(record.get("source_type", ""))
	if not source_type.begins_with("internal_") and not String(
		record.get("url", "")
	).begins_with("https://"):
		_add_issue(
			errors,
			"error",
			"official_url_required",
			evidence_id,
			"url",
			"External evidence requires an official HTTPS URL."
		)
	var supports := _string_array(record.get("supports", []))
	var does_not_support := _string_array(record.get("does_not_support", []))
	if supports.is_empty():
		_add_issue(
			errors,
			"error",
			"supports_missing",
			evidence_id,
			"supports",
			"Evidence must declare what it supports."
		)
	if does_not_support.is_empty():
		_add_issue(
			errors,
			"error",
			"boundary_missing",
			evidence_id,
			"does_not_support",
			"Evidence must declare what it does not support."
		)
	for capability in supports:
		if does_not_support.has(capability):
			_add_issue(
				errors,
				"error",
				"support_boundary_conflict",
				evidence_id,
				"supports",
				"Capability '%s' cannot appear in both supports and does_not_support." % capability
			)
	var status := String(record.get("status", ""))
	if not EVIDENCE_STATUSES.has(status):
		_add_issue(
			errors,
			"error",
			"status_invalid",
			evidence_id,
			"status",
			"Evidence status must be active, superseded, or needs_review."
		)
	if status == "superseded" and String(record.get("superseded_by", "")).is_empty():
		_add_issue(
			errors,
			"error",
			"replacement_missing",
			evidence_id,
			"superseded_by",
			"Superseded evidence must identify its replacement."
		)
	var published_at := String(record.get("published_at", ""))
	if published_at != "unknown" and not _is_valid_iso_date(published_at):
		_add_issue(
			errors,
			"error",
			"date_invalid",
			evidence_id,
			"published_at",
			"published_at must be 'unknown' or a real YYYY-MM-DD date."
		)
	for field_name in ["accessed_at", "review_due_at"]:
		if not _is_valid_iso_date(String(record.get(field_name, ""))):
			_add_issue(
				errors,
				"error",
				"date_invalid",
				evidence_id,
				field_name,
				"%s must be a real YYYY-MM-DD date." % field_name
			)
	var effective_at := String(record.get("effective_at", ""))
	if not effective_at.is_empty() and not _is_valid_iso_date(effective_at):
		_add_issue(
			errors,
			"error",
			"date_invalid",
			evidence_id,
			"effective_at",
			"effective_at must be a real YYYY-MM-DD date when present."
		)
	var accessed_at := String(record.get("accessed_at", ""))
	var review_due_at := String(record.get("review_due_at", ""))
	if (
		_is_valid_iso_date(accessed_at)
		and _is_valid_iso_date(review_due_at)
		and review_due_at < accessed_at
	):
		_add_issue(
			errors,
			"error",
			"review_due_before_access",
			evidence_id,
			"review_due_at",
			"review_due_at cannot be earlier than accessed_at."
		)
	if status == "active" and not String(record.get("superseded_by", "")).is_empty():
		_add_issue(
			warnings,
			"warning",
			"active_has_replacement",
			evidence_id,
			"superseded_by",
			"Active evidence should not declare a replacement."
		)


func _replacement_resolution(evidence_id: String) -> Dictionary:
	var chain: Array[String] = []
	var seen := {}
	var current_id := evidence_id
	var issue := ""
	while not current_id.is_empty():
		if seen.has(current_id):
			issue = "cycle"
			break
		seen[current_id] = true
		chain.append(current_id)
		if not _records.has(current_id):
			issue = "missing_record"
			break
		var record := _records[current_id] as Dictionary
		if String(record.get("status", "")) != "superseded":
			break
		var next_id := String(record.get("superseded_by", ""))
		if next_id.is_empty():
			issue = "missing_replacement"
			break
		current_id = next_id
	return {
		"chain": chain.duplicate(),
		"final_id": chain[-1] if not chain.is_empty() and issue.is_empty() else "",
		"issue": issue,
	}


func _is_usable_record(
	evidence_id: String,
	as_of_date: String,
	invalid_ids: Array[String]
) -> bool:
	if evidence_id.is_empty() or not _records.has(evidence_id) or invalid_ids.has(evidence_id):
		return false
	var record := _records[evidence_id] as Dictionary
	return (
		String(record.get("status", "")) == "active"
		and String(record.get("review_due_at", "")) > as_of_date
	)


func _fail(status: String, message: String, degraded: bool) -> Dictionary:
	_records.clear()
	_record_entries.clear()
	_registry["status"] = status
	_registry["available"] = false
	_registry["degraded"] = degraded
	(_registry["errors"] as Array).append(message)
	return _snapshot()


func _snapshot() -> Dictionary:
	var result := _registry.duplicate(true)
	result["evidence_count"] = _record_entries.size()
	result["unique_evidence_count"] = _records.size()
	result["evidence_entries"] = _record_entries.duplicate(true)
	result["evidence"] = _records.duplicate(true)
	return result


static func _audit_report(
	as_of_date: String,
	errors: Array[Dictionary],
	warnings: Array[Dictionary],
	active_ids: Array[String],
	superseded_ids: Array[String],
	needs_review_ids: Array[String],
	review_due_ids: Array[String],
	invalid_ids: Array[String],
	duplicate_ids: Array[String],
	review_due_at_by_id: Dictionary,
	earliest_review_due_at: String,
	next_review_due_at: String
) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"registry_available": errors.is_empty() or not _has_code(errors, "registry_unavailable"),
		"as_of_date_valid": _is_valid_iso_date(as_of_date),
		"as_of_date": as_of_date,
		"error_count": errors.size(),
		"warning_count": warnings.size(),
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
		"active_ids": active_ids.duplicate(),
		"superseded_ids": superseded_ids.duplicate(),
		"needs_review_ids": needs_review_ids.duplicate(),
		"review_due_ids": review_due_ids.duplicate(),
		"invalid_ids": invalid_ids.duplicate(),
		"duplicate_ids": duplicate_ids.duplicate(),
		"review_due_at_by_id": review_due_at_by_id.duplicate(true),
		"earliest_review_due_at": earliest_review_due_at,
		"next_review_due_at": next_review_due_at,
	}


static func _add_issue(
	issues: Array[Dictionary],
	severity: String,
	code: String,
	evidence_id: String,
	field: String,
	message: String
) -> void:
	issues.append({
		"severity": severity,
		"code": code,
		"evidence_id": evidence_id,
		"field": field,
		"path": field if evidence_id.is_empty() else "evidence[%s].%s" % [evidence_id, field],
		"message": message,
	})


static func _has_code(issues: Array[Dictionary], code: String) -> bool:
	for issue in issues:
		if String(issue.get("code", "")) == code:
			return true
	return false


static func _read_attributes(parser: XMLParser) -> Dictionary:
	var attributes := {}
	for index in range(parser.get_attribute_count()):
		attributes[parser.get_attribute_name(index)] = parser.get_attribute_value(index)
	return attributes


static func _split_pipe(value: String) -> Array[String]:
	var result: Array[String] = []
	for raw_item in value.split("|", false):
		var item := String(raw_item).strip_edges()
		if not item.is_empty():
			result.append(item)
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	var value_type := typeof(value)
	if value_type == TYPE_ARRAY or value_type == TYPE_PACKED_STRING_ARRAY:
		for item in value:
			var text := String(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	elif value_type == TYPE_STRING:
		for item in String(value).split(",", false):
			var text := String(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


static func _append_unique(values: Array, value: Variant) -> void:
	if not values.has(value):
		values.append(value)


static func _is_valid_iso_date(value: String) -> bool:
	if value.length() != 10 or value.substr(4, 1) != "-" or value.substr(7, 1) != "-":
		return false
	var year_text := value.substr(0, 4)
	var month_text := value.substr(5, 2)
	var day_text := value.substr(8, 2)
	if not year_text.is_valid_int() or not month_text.is_valid_int() or not day_text.is_valid_int():
		return false
	var year := int(year_text)
	var month := int(month_text)
	var day := int(day_text)
	if year <= 0 or month < 1 or month > 12 or day < 1:
		return false
	var days_in_month := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var is_leap := year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)
	if is_leap:
		days_in_month[1] = 29
	return day <= int(days_in_month[month - 1])
