class_name LifeSceneCatalog
extends RefCounted

const PATH := "res://data/title_life_scenes.json"


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary or not data.get("scenes") is Array: return result
	var people := {}
	for story in StoryCatalog.all(): people[story["character_id"]] = true
	for row in data["scenes"]:
		if not row is Dictionary or not people.has(row.get("character_id")) or not ResourceLoader.exists(row.get("image", "")): continue
		result.append(row.duplicate(true))
	return result
