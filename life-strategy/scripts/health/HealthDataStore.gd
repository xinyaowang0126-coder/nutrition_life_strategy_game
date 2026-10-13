class_name HealthDataStore
extends RefCounted

## Read-only loader for the health-education data layer. This class deliberately
## does not consult legacy card tags or gameplay stats when a profile is absent.

const DEFAULT_PROFILES_PATH := "res://data/health/food_health_profiles.xml"
const XmlStructure := preload("res://scripts/health/HealthXmlStructure.gd")
const ROOT_ELEMENT := "food_health_profiles"
const SUPPORTED_SCHEMA_VERSION := 1

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

var _catalog: Dictionary = {}
var _profiles: Dictionary = {}
var _profile_entries: Array = []


func _init() -> void:
	_reset(DEFAULT_PROFILES_PATH)


func load_catalog(path: String = DEFAULT_PROFILES_PATH) -> Dictionary:
	_reset(path)
	if not FileAccess.file_exists(path):
		return _fail(
			STATUS_MISSING,
			"Health profile catalog is missing: %s" % path,
			true
		)
	var xml := FileAccess.get_file_as_string(path).strip_edges()
	if xml.is_empty():
		return _fail(
			STATUS_EMPTY_FILE,
			"Health profile catalog contains no XML root: %s" % path,
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
			"Health profile catalog could not be opened: %s (error %d)" % [path, open_error],
			true
		)

	var root_seen := false
	var current_profile: Dictionary = {}
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
				if String(_catalog["status"]) != STATUS_NOT_LOADED:
					return _snapshot()
			elif node_name == "profile":
				current_profile = _profile_from_attributes(_read_attributes(parser))
				if parser.is_empty():
					_store_profile(current_profile)
					current_profile = {}
			elif node_name == "component" and not current_profile.is_empty():
				(current_profile["components"] as Array).append(
					_component_from_attributes(_read_attributes(parser))
				)
			elif node_name == "method" and not current_profile.is_empty():
				var method_attributes := _read_attributes(parser)
				(current_profile["cooking_methods"] as Array).append(
					String(method_attributes.get("id", ""))
				)
			elif node_name == "factor" and not current_profile.is_empty():
				(current_profile["factors"] as Array).append(
					_factor_from_attributes(_read_attributes(parser))
				)
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "profile" and not current_profile.is_empty():
				_store_profile(current_profile)
				current_profile = {}

		read_error = parser.read()

	if read_error != ERR_FILE_EOF:
		return _fail(
			STATUS_INVALID_XML,
			"Health profile catalog could not be parsed: %s (error %d)" % [path, read_error],
			true
		)
	if not root_seen:
		return _fail(
			STATUS_EMPTY_FILE,
			"Health profile catalog contains no XML root: %s" % path,
			true
		)

	_catalog["available"] = true
	_catalog["degraded"] = false
	_catalog["status"] = STATUS_READY_EMPTY if _profiles.is_empty() else STATUS_READY
	return _snapshot()


func get_catalog() -> Dictionary:
	return _snapshot()


func get_profile_ids() -> Array[String]:
	var ids: Array[String] = []
	for food_id in _profiles.keys():
		ids.append(String(food_id))
	ids.sort()
	return ids


func has_profile(food_id: String) -> bool:
	return bool(_catalog.get("available", false)) and _profiles.has(food_id)


func get_profile(food_id: String) -> Dictionary:
	if not has_profile(food_id):
		return {}
	return (_profiles[food_id] as Dictionary).duplicate(true)


func lookup_profile(food_id: String) -> Dictionary:
	if not bool(_catalog.get("available", false)):
		return {
			"status": "data_unavailable",
			"food_id": food_id,
			"reason": String(_catalog.get("status", STATUS_NOT_LOADED)),
			"profile": {},
		}
	if not _profiles.has(food_id):
		return {
			"status": "information_insufficient",
			"food_id": food_id,
			"reason": "profile_missing",
			"profile": {},
		}
	return {
		"status": "available",
		"food_id": food_id,
		"reason": "",
		"profile": (_profiles[food_id] as Dictionary).duplicate(true),
	}


func _reset(path: String) -> void:
	_profiles.clear()
	_profile_entries.clear()
	_catalog = {
		"path": path,
		"status": STATUS_NOT_LOADED,
		"available": false,
		"degraded": false,
		"schema_version": -1,
		"supported_schema_version": SUPPORTED_SCHEMA_VERSION,
		"model_version": "",
		"locale": "",
		"reviewed_at": "",
		"profile_count": 0,
		"warnings": [],
		"errors": [],
	}


func _read_root(attributes: Dictionary) -> void:
	_catalog["model_version"] = String(attributes.get("model_version", ""))
	_catalog["locale"] = String(attributes.get("locale", ""))
	_catalog["reviewed_at"] = String(attributes.get("reviewed_at", ""))

	var raw_schema_version := String(attributes.get("schema_version", ""))
	if not raw_schema_version.is_valid_int():
		_fail(
			STATUS_INVALID_SCHEMA_VERSION,
			"Health profile schema_version must be an integer.",
			true
		)
		return

	var schema_version := int(raw_schema_version)
	_catalog["schema_version"] = schema_version
	if schema_version < SUPPORTED_SCHEMA_VERSION:
		_fail(
			STATUS_UNSUPPORTED_LEGACY_SCHEMA,
			"Health profile schema %d is older than supported schema %d; no profile was inferred." % [
				schema_version,
				SUPPORTED_SCHEMA_VERSION,
			],
			true
		)
	elif schema_version > SUPPORTED_SCHEMA_VERSION:
		_fail(
			STATUS_UNSUPPORTED_FUTURE_SCHEMA,
			"Health profile schema %d is newer than supported schema %d; no profile was inferred." % [
				schema_version,
				SUPPORTED_SCHEMA_VERSION,
			],
			true
		)


func _profile_from_attributes(attributes: Dictionary) -> Dictionary:
	var portion := {
		"status": String(attributes.get("portion_status", "")),
		"label": String(attributes.get("display_basis", "")),
		"band": String(attributes.get("portion_band", "")),
	}
	if attributes.has("portion_value"):
		portion["value"] = _number_or_source_text(String(attributes["portion_value"]))
	if attributes.has("portion_unit"):
		portion["unit"] = String(attributes["portion_unit"])
	var caffeine := {
		"status": String(attributes.get("caffeine_status", "")),
		"band": String(attributes.get("caffeine_band", "")),
		"serving_time_relevance": String(attributes.get("serving_time_relevance", "")),
	}
	if attributes.has("caffeine_mg"):
		caffeine["mg"] = _number_or_source_text(String(attributes["caffeine_mg"]))

	return {
		"food_id": String(attributes.get("food_id", "")),
		"profile_version": _integer_or_source_text(String(attributes.get("profile_version", ""))),
		"model_version": String(_catalog.get("model_version", "")),
		"portion": portion,
		"basis_type": String(attributes.get("basis_type", "")),
		"composition_status": String(attributes.get("composition_status", "")),
		"components": [],
		"cooking_methods": [],
		"factors": [],
		"caffeine": caffeine,
		"allergens": [],
		"food_safety": {},
		"confidence": String(attributes.get("confidence", "")),
		"review_status": String(attributes.get("review_status", "")),
		"evidence_refs": _split_csv(String(attributes.get("evidence_refs", ""))),
		"reviewed_by": String(attributes.get("reviewed_by", "")),
		"reviewed_at": String(attributes.get("reviewed_at", "")),
	}


func _component_from_attributes(attributes: Dictionary) -> Dictionary:
	var component := {
		"ingredient_id": String(attributes.get("ingredient_id", "")),
		"name": String(attributes.get("name", "")),
		"food_group": String(attributes.get("food_group", "")),
		"contribution_band": String(attributes.get("contribution_band", "")),
		"basis_type": String(attributes.get("basis_type", "")),
		"confidence": String(attributes.get("confidence", "")),
	}
	if attributes.has("amount_value"):
		component["amount_value"] = _number_or_source_text(String(attributes["amount_value"]))
	if attributes.has("amount_unit"):
		component["amount_unit"] = String(attributes["amount_unit"])
	return component


func _factor_from_attributes(attributes: Dictionary) -> Dictionary:
	return {
		"factor_id": String(attributes.get("factor_id", "")),
		"band": String(attributes.get("band", "")),
		"basis_type": String(attributes.get("basis_type", "")),
		"confidence": String(attributes.get("confidence", "")),
		"evidence_refs": _split_csv(String(attributes.get("evidence_refs", ""))),
	}


func _store_profile(profile: Dictionary) -> void:
	_profile_entries.append(profile.duplicate(true))
	var food_id := String(profile.get("food_id", ""))
	if food_id.is_empty():
		(_catalog["warnings"] as Array).append("A profile without food_id was skipped.")
		return
	if _profiles.has(food_id):
		(_catalog["warnings"] as Array).append(
			"Duplicate profile '%s' was skipped; validation must block this catalog." % food_id
		)
		return
	_profiles[food_id] = profile.duplicate(true)


func _fail(status: String, message: String, degraded: bool) -> Dictionary:
	_profiles.clear()
	_profile_entries.clear()
	_catalog["status"] = status
	_catalog["available"] = false
	_catalog["degraded"] = degraded
	(_catalog["errors"] as Array).append(message)
	return _snapshot()


func _snapshot() -> Dictionary:
	var result := _catalog.duplicate(true)
	result["profile_count"] = _profile_entries.size()
	result["unique_profile_count"] = _profiles.size()
	result["profile_entries"] = _profile_entries.duplicate(true)
	result["profiles"] = _profiles.duplicate(true)
	return result


static func _read_attributes(parser: XMLParser) -> Dictionary:
	var attributes := {}
	for index in range(parser.get_attribute_count()):
		attributes[parser.get_attribute_name(index)] = parser.get_attribute_value(index)
	return attributes


static func _split_csv(value: String) -> Array[String]:
	var result: Array[String] = []
	for raw_item in value.split(",", false):
		var item := String(raw_item).strip_edges()
		if not item.is_empty():
			result.append(item)
	return result


static func _integer_or_source_text(value: String) -> Variant:
	return int(value) if value.is_valid_int() else value


static func _number_or_source_text(value: String) -> Variant:
	return float(value) if value.is_valid_float() else value
