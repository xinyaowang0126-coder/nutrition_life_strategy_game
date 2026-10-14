class_name StoryCatalog
extends RefCounted

const Data := preload("res://scripts/GameData.gd")
const Cards := preload("res://scripts/CardDataStore.gd")
const PATH := "res://data/stories/stories.xml"
const CHARACTERS_PATH := "res://data/characters/personas.xml"
const DEFAULT_ID := "campus_exam"
static var _stories: Dictionary = {}
static var _content: Dictionary = {}
static var _characters: Dictionary = {}


static func all() -> Array[Dictionary]:
	_load()
	var result: Array[Dictionary] = []
	for value in _stories.values():
		result.append(value.duplicate(true))
	return result


static func get_story(id: String) -> Dictionary:
	_load()
	return _stories.get(id, {}).duplicate(true)


static func _load() -> void:
	if not _stories.is_empty():
		return
	_load_characters()
	var parser := XMLParser.new()
	if parser.open(PATH) != OK:
		return
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT or parser.get_node_name() != "story":
			continue
		var story := {}
		for i in parser.get_attribute_count():
			story[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
		for key in ["days", "goal_target", "version"]:
			story[key] = int(story.get(key, 0))
		var id := String(story.get("id", ""))
		if id.is_empty() or _stories.has(id) or story.get("days") != 7:
			continue
		if story.get("mechanics") not in ["campus", "household"]:
			continue
		if int(story.get("goal_target", 0)) <= 0 or String(story.get("character_id", "")).is_empty():
			continue
		var character: Dictionary = _characters.get(story["character_id"], {})
		if character.is_empty():
			continue
		story["character_name"] = character["name"]
		story["character_version"] = character["version"]
		story["preferences"] = character["preferences"]
		story["portrait"] = character["portrait"]
		if not ResourceLoader.exists(String(story["portrait"])) or not FileAccess.file_exists(String(story["preferences"])):
			continue
		if story["mechanics"] == "household" and (not FileAccess.file_exists(String(story.get("foods", ""))) or not FileAccess.file_exists(String(story.get("actions", ""))) or not FileAccess.file_exists(String(story.get("sources", "")))):
			continue
		_stories[id] = story


static func _load_characters() -> void:
	var parser := XMLParser.new()
	if parser.open(CHARACTERS_PATH) != OK:
		return
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT or parser.get_node_name() != "character":
			continue
		var character := {}
		for i in parser.get_attribute_count():
			character[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
		character["version"] = int(character.get("version", 0))
		if not String(character.get("id", "")).is_empty() and not _characters.has(character["id"]):
			_characters[character["id"]] = character


static func content(story: Dictionary, kind: String) -> Dictionary:
	var cache_key := "%s:%s" % [story.get("id", ""), kind]
	if not _content.has(cache_key):
		var ids: Array[String] = []
		var entries := {}
		var elements := {"foods": "food", "actions": "action", "sources": "meal_source"}
		if not elements.has(kind) or not FileAccess.file_exists(String(story.get(kind, ""))):
			return {}
		Cards._load_xml_cards(String(story[kind]), elements[kind], ids, entries)
		_content[cache_key] = entries
	return _content[cache_key].duplicate(true)


static func initial_stats(story: Dictionary) -> Dictionary:
	var result := Data.get_starting_stats()
	if story.get("mechanics") == "household":
		result["balance"] = 210
		result["stress"] = 35
		result.erase("study_progress")
		result.erase("study_target")
		result["goal_progress"] = 0
		result["goal_target"] = int(story["goal_target"])
	return result


static func resource_projection(state: Dictionary, story: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	if story.get("mechanics") == "household":
		result["study_progress"] = int(state.get("goal_progress", 0))
		result["study_target"] = int(story.get("goal_target", 70))
	return result
