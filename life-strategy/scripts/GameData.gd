class_name GameData
extends RefCounted

const CardDataStoreScript := preload("res://scripts/CardDataStore.gd")
const TOTAL_DAYS := 7
const STUDY_TARGET := 70
const DAILY_STUDY_PACE := 10

const STAT_LABELS := {
	"stability": "余力",
	"balance": "余额",
	"energy": "精力",
	"mood": "心情",
	"satiety": "饱腹",
	"stress": "压力",
	"diet_burden": "身体负担",
	"study_progress": "复习",
}

const STARTING_STATS := {
	"stability": 65,
	"balance": 120,
	"energy": 52,
	"mood": 55,
	"satiety": 58,
	"stress": 48,
	"diet_burden": 24,
	"study_progress": 0,
	"study_target": STUDY_TARGET,
}

const ENDINGS := {
	"stable_endurance": {
		"id": "stable_endurance",
		"title": "稳稳到了周末",
		"subtitle": "书看完了，饭也没落下。周末早上醒来，你还有力气下楼走走。",
		"image": "res://assets/generated/endings/stable_endurance.png",
	},
	"barely_survived": {
		"id": "barely_survived",
		"title": "总算到了周末",
		"subtitle": "有几顿没顾上，也熬了几个夜。交卷以后，你只想先睡一觉。",
		"image": "res://assets/generated/endings/barely_survived.png",
	},
	"collapsed": {
		"id": "collapsed",
		"title": "先歇一会儿",
		"subtitle": "闹钟响了又响，你没有起身。今天先不谈计划，先去吃点东西。",
		"image": "res://assets/generated/endings/collapsed.png",
	},
	"study_shortfall": {
		"id": "study_shortfall",
		"title": "这次没赶上",
		"subtitle": "日子照常过下来了，只是书没看完。这次的成绩不太理想。",
		"image": "res://assets/generated/endings/barely_survived.png",
	},
}

static func ensure_loaded() -> void:
	CardDataStoreScript.ensure_loaded()


static func get_starting_stats() -> Dictionary:
	ensure_loaded()
	return STARTING_STATS.duplicate(true)


static func get_food(id: String) -> Dictionary:
	return CardDataStoreScript.get_food(id)


static func get_action(id: String) -> Dictionary:
	return CardDataStoreScript.get_action(id)


static func get_sleep_option(id: String) -> Dictionary:
	return CardDataStoreScript.get_sleep_option(id)


static func get_meal_source(id: String) -> Dictionary:
	return CardDataStoreScript.get_meal_source(id)


static func get_meal_source_ids() -> Array[String]:
	return CardDataStoreScript.get_meal_source_ids()


static func get_meal_source_ids_for_scene(scene: String) -> Array[String]:
	return CardDataStoreScript.get_meal_source_ids_for_scene(scene)


static func is_meal_source_available(id: String, scene: String) -> bool:
	return CardDataStoreScript.is_meal_source_available(id, scene)


static func get_food_ids_for_context(source_id: String, meal_phase: String) -> Array[String]:
	return CardDataStoreScript.get_food_ids_for_context(source_id, meal_phase)


static func get_initial_dorm_inventory() -> Dictionary:
	return CardDataStoreScript.get_initial_dorm_inventory()


static func get_ending(id: String) -> Dictionary:
	if not ENDINGS.has(id):
		push_error("Unknown ending id: %s" % id)
		return ENDINGS["collapsed"].duplicate(true)
	return ENDINGS[id].duplicate(true)


static func get_food_ids_for_scene(scene: String) -> Array[String]:
	return CardDataStoreScript.get_food_ids_for_scene(scene)


static func get_action_ids_for_scene(scene: String) -> Array[String]:
	return CardDataStoreScript.get_action_ids_for_scene(scene)


static func get_sleep_option_ids_for_scene(scene: String = "sleep") -> Array[String]:
	return CardDataStoreScript.get_sleep_option_ids_for_scene(scene)


static func is_food_available(id: String, scene: String) -> bool:
	return CardDataStoreScript.is_food_available(id, scene)


static func is_action_available(id: String, scene: String) -> bool:
	return CardDataStoreScript.is_action_available(id, scene)


static func is_sleep_option_available(id: String, scene: String) -> bool:
	return CardDataStoreScript.is_sleep_option_available(id, scene)


static func has_tag(item: Dictionary, tag: String) -> bool:
	return item.has("tags") and item["tags"].has(tag)


static func cheapest_food_cost(scene: String = "") -> int:
	return CardDataStoreScript.cheapest_food_cost(scene)
