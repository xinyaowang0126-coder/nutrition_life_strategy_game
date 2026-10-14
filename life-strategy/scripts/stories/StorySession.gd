class_name StorySession
extends RefCounted

const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
static var _requested := Catalog.DEFAULT_ID
static var _saved: Dictionary = {}


static func request(id: String) -> bool:
	if Catalog.get_story(id).is_empty():
		return false
	_requested = id
	_saved.clear()
	return true


static func request_saved(envelope: Dictionary) -> bool:
	var checked := Codec.validate(Codec.normalize(envelope))
	if not checked["ok"]:
		return false
	_requested = envelope["story_id"]
	_saved = checked["save"].duplicate(true)
	return true


static func take_saved() -> Dictionary:
	var result := _saved.duplicate(true)
	_saved.clear()
	return result


static func take_request() -> String:
	var result := _requested
	_requested = Catalog.DEFAULT_ID
	return result
