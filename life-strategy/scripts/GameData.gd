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
	"study_progress": "复习",
}

const STARTING_STATS := {
	"stability": 51,
	"balance": 150,
	"energy": 60,
	"mood": 55,
	"satiety": 40,
	"stress": 48,
	"study_progress": 0,
	"study_target": STUDY_TARGET,
}

const ENDINGS := {
	"stable_endurance": {
		"id": "stable_endurance",
		"title": "稳稳到了周末",
		"subtitle": "复习目标完成了，也给自己留了些余力。",
		"image": "res://assets/generated/endings/stable_endurance.png",
	},
	"barely_survived": {
		"id": "barely_survived",
		"title": "总算到了周末",
		"subtitle": "这一周走完了。下次换个安排，再试试看。",
		"image": "res://assets/generated/endings/barely_survived.png",
	},
	"collapsed": {
		"id": "collapsed",
		"title": "先歇一会儿",
		"subtitle": "这次的安排没能撑下去。先停在这里，下次换个节奏。",
		"image": "res://assets/generated/endings/collapsed.png",
	},
	"study_shortfall": {
		"id": "study_shortfall",
		"title": "这次没赶上",
		"subtitle": "这一周走完了，复习目标还没完成。",
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
