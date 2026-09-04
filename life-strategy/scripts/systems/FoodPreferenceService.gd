class_name FoodPreferenceService
extends RefCounted

## A character's food preferences are gameplay inputs, separate from the food's
## composition. Missing data never falls back to tags, health data, or old mood.

const DEFAULT_PROFILE_PATH := "res://data/characters/default_food_preferences.xml"
const SCHEMA_VERSION := 1
const ROOT_ELEMENT := "food_preferences"

static var _default_cache: Dictionary = {}
static var _default_loaded := false


static func default_profile() -> Dictionary:
	if not _default_loaded:
		_default_cache = load_profile(DEFAULT_PROFILE_PATH)
		_default_loaded = true
	return _default_cache.duplicate(true)


static func load_profile(path: String) -> Dictionary:
	var parser := _open_parser(path)
	if parser == null:
		return {}
	var profile := {}
	var open_elements: Array[String] = []
	var root_seen := false
	var root_closed := false
	var result := parser.read()
	while result == OK:
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var name := parser.get_node_name()
			if root_closed:
				return {}
			if not root_seen:
				if name != ROOT_ELEMENT:
					return {}
				profile = _read_root(_attributes(parser))
				if profile.is_empty():
					return {}
				root_seen = true
			elif open_elements != [ROOT_ELEMENT] or name != "reaction":
				return {}
			elif not _add_reaction(profile, _attributes(parser)):
				return {}
			if not parser.is_empty():
				open_elements.append(name)
			elif name == ROOT_ELEMENT:
				root_closed = true
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if open_elements.is_empty() or open_elements.back() != parser.get_node_name():
				return {}
			open_elements.pop_back()
			root_closed = open_elements.is_empty()
		elif node_type in [XMLParser.NODE_TEXT, XMLParser.NODE_CDATA]:
			if not parser.get_node_data().strip_edges().is_empty():
				return {}
		result = parser.read()
	if result != ERR_FILE_EOF or not root_closed or not _valid_profile(profile):
		return {}
	return profile.duplicate(true)


static func _open_parser(path: String) -> XMLParser:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	var read_error := file.get_error()
	file.close()
	if bytes.is_empty() or read_error not in [OK, ERR_FILE_EOF]:
		return null
	var parser := XMLParser.new()
	return parser if parser.open_buffer(bytes) == OK else null


static func reaction(food_id: String, profile: Dictionary) -> Dictionary:
	var output := {
		"profile_id": "", "profile_version": 0, "character_name": "",
		"status": "unspecified", "mood_delta": 0, "comfort": false,
	}
	if not _valid_profile(profile):
		return output
	output["profile_id"] = profile["id"]
	output["profile_version"] = profile["version"]
	output["character_name"] = profile["name"]
	if not profile["reactions"].has(food_id):
		return output
	var preference: Dictionary = profile["reactions"][food_id]
	output["status"] = "known"
	output["mood_delta"] = preference["mood_delta"]
	output["comfort"] = preference["comfort"]
	return output


static func decorate_food(food: Dictionary, profile: Dictionary) -> Dictionary:
	var copy := food.duplicate(true)
	copy.erase("mood")
	var food_id: String = food.get("id", "") if food.get("id", "") is String else ""
	copy["food_preference"] = reaction(food_id, profile)
	return copy


static func _read_root(attributes: Dictionary) -> Dictionary:
	if attributes.get("schema_version") != str(SCHEMA_VERSION):
		return {}
	if not _text_present(attributes.get("id")) or not _text_present(attributes.get("name")):
		return {}
	if not _integer_text(attributes.get("version", "")) or int(attributes["version"]) < 1:
		return {}
	return {
		"id": attributes["id"], "version": int(attributes["version"]),
		"name": attributes["name"], "reactions": {},
	}


static func _add_reaction(profile: Dictionary, attributes: Dictionary) -> bool:
	var food_id: Variant = attributes.get("food_id")
	if not _text_present(food_id) or profile["reactions"].has(food_id):
		return false
	if not _integer_text(attributes.get("mood_delta", "")):
		return false
	if attributes.get("comfort") not in ["true", "false"]:
		return false
	profile["reactions"][food_id] = {
		"mood_delta": int(attributes["mood_delta"]), "comfort": attributes["comfort"] == "true",
	}
	return true


static func _valid_profile(profile: Dictionary) -> bool:
	if not _text_present(profile.get("id")) or not _text_present(profile.get("name")):
		return false
	if not profile.get("version") is int or profile["version"] < 1:
		return false
	if not profile.get("reactions") is Dictionary:
		return false
	for food_id in profile["reactions"]:
		var item: Variant = profile["reactions"][food_id]
		if not _text_present(food_id) or not item is Dictionary:
			return false
		if not item.get("mood_delta") is int or not item.get("comfort") is bool:
			return false
	return true


static func _attributes(parser: XMLParser) -> Dictionary:
	var attributes := {}
	for index in range(parser.get_attribute_count()):
		var key := parser.get_attribute_name(index)
		if attributes.has(key):
			return {}
		attributes[key] = parser.get_attribute_value(index)
	return attributes


static func _text_present(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


static func _integer_text(value: String) -> bool:
	return value.is_valid_int() and str(int(value)) == value
