class_name GameData
extends RefCounted

const TOTAL_DAYS := 7

const STAT_LABELS := {
	"stability": "稳定度",
	"balance": "余额",
	"energy": "精力",
	"mood": "心情",
	"satiety": "饱腹",
	"stress": "压力",
	"diet_burden": "饮食负担",
	"study_progress": "复习进度",
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
}

const FOOD_IDS := [
	"rice_plain",
	"oatmeal",
	"egg",
	"tofu",
	"greens",
	"tomato",
	"apple",
	"banana",
	"milk",
	"coffee",
	"bubble_tea",
	"instant_noodles",
	"fried_chicken",
	"salad_bowl",
	"sandwich",
]

const FOODS := {
	"rice_plain": {
		"id": "rice_plain",
		"name": "白米饭",
		"kind": "主食",
		"cost": 2,
		"satiety": 25,
		"energy": 4,
		"mood": 0,
		"burden": 0,
		"tags": ["staple", "cheap", "plain"],
		"desc": "便宜顶饱，缺点是有点单调。",
		"image": "res://assets/generated/cards/rice_plain.png",
	},
	"oatmeal": {
		"id": "oatmeal",
		"name": "燕麦",
		"kind": "主食",
		"cost": 3,
		"satiety": 32,
		"energy": 7,
		"mood": 0,
		"burden": 0,
		"tags": ["staple", "whole_grain", "fiber", "cheap"],
		"desc": "慢释放的能量，适合撑过上午。",
		"image": "res://assets/generated/cards/oatmeal.png",
	},
	"egg": {
		"id": "egg",
		"name": "鸡蛋",
		"kind": "蛋白",
		"cost": 2,
		"satiety": 18,
		"energy": 5,
		"mood": 0,
		"burden": 0,
		"tags": ["protein", "cheap"],
		"desc": "便宜蛋白质，组合餐的好拼图。",
		"image": "res://assets/generated/cards/egg.png",
	},
	"tofu": {
		"id": "tofu",
		"name": "豆腐",
		"kind": "蛋白",
		"cost": 3,
		"satiety": 20,
		"energy": 4,
		"mood": 0,
		"burden": 0,
		"tags": ["protein", "cheap", "vegetable"],
		"desc": "清淡、便宜，也能补一点蛋白。",
		"image": "res://assets/generated/cards/tofu.png",
	},
	"greens": {
		"id": "greens",
		"name": "青菜",
		"kind": "蔬菜",
		"cost": 3,
		"satiety": 10,
		"energy": 2,
		"mood": -2,
		"burden": -2,
		"tags": ["vegetable", "fiber", "plain"],
		"desc": "不太快乐，但会让身体轻一点。",
		"image": "res://assets/generated/cards/greens.png",
	},
	"tomato": {
		"id": "tomato",
		"name": "番茄",
		"kind": "蔬果",
		"cost": 3,
		"satiety": 8,
		"energy": 2,
		"mood": 3,
		"burden": -1,
		"tags": ["vegetable", "fruit_like", "fiber"],
		"desc": "清爽的小补充，稳定情绪。",
		"image": "res://assets/generated/cards/tomato.png",
	},
	"apple": {
		"id": "apple",
		"name": "苹果",
		"kind": "水果",
		"cost": 3,
		"satiety": 14,
		"energy": 3,
		"mood": 5,
		"burden": -1,
		"tags": ["fruit", "fiber", "mood"],
		"desc": "清脆的安全感。",
		"image": "res://assets/generated/cards/apple.png",
	},
	"banana": {
		"id": "banana",
		"name": "香蕉",
		"kind": "水果",
		"cost": 3,
		"satiety": 18,
		"energy": 6,
		"mood": 5,
		"burden": 0,
		"tags": ["fruit", "energy", "mood"],
		"desc": "便宜、快速、适合低电量。",
		"image": "res://assets/generated/cards/banana.png",
	},
	"milk": {
		"id": "milk",
		"name": "牛奶",
		"kind": "饮品",
		"cost": 4,
		"satiety": 15,
		"energy": 5,
		"mood": 3,
		"burden": 1,
		"tags": ["protein", "drink"],
		"desc": "温和补能，轻微增加负担。",
		"image": "res://assets/generated/cards/milk.png",
	},
	"coffee": {
		"id": "coffee",
		"name": "咖啡",
		"kind": "饮品",
		"cost": 8,
		"satiety": 2,
		"energy": 14,
		"mood": 5,
		"burden": 1,
		"stress": 3,
		"tags": ["drink", "energy"],
		"desc": "短期提神，也会推高一点紧绷感。",
		"image": "res://assets/generated/cards/coffee.png",
	},
	"bubble_tea": {
		"id": "bubble_tea",
		"name": "奶茶",
		"kind": "快乐",
		"cost": 15,
		"satiety": 8,
		"energy": 4,
		"mood": 18,
		"burden": 8,
		"tags": ["drink", "snack", "high_sugar", "mood", "favorite"],
		"desc": "今天先活下来。明天再说。",
		"image": "res://assets/generated/cards/bubble_tea.png",
	},
	"instant_noodles": {
		"id": "instant_noodles",
		"name": "方便面",
		"kind": "速食",
		"cost": 4,
		"satiety": 24,
		"energy": 5,
		"mood": 8,
		"burden": 9,
		"tags": ["instant", "cheap", "high_sodium", "high_fat", "favorite"],
		"desc": "低价救场，但会留下负担。",
		"image": "res://assets/generated/cards/instant_noodles.png",
	},
	"fried_chicken": {
		"id": "fried_chicken",
		"name": "炸鸡",
		"kind": "奖励",
		"cost": 25,
		"satiety": 32,
		"energy": 5,
		"mood": 20,
		"burden": 12,
		"tags": ["fastfood", "high_fat", "high_sodium", "tasty", "favorite"],
		"desc": "快乐很高，预算和身体会记账。",
		"image": "res://assets/generated/cards/fried_chicken.png",
	},
	"salad_bowl": {
		"id": "salad_bowl",
		"name": "沙拉碗",
		"kind": "轻食",
		"cost": 28,
		"satiety": 20,
		"energy": 5,
		"mood": -3,
		"burden": -4,
		"tags": ["vegetable", "fruit", "light_meal", "expensive"],
		"desc": "清爽但贵，预算紧张时很奢侈。",
		"image": "res://assets/generated/cards/salad_bowl.png",
	},
	"sandwich": {
		"id": "sandwich",
		"name": "三明治",
		"kind": "便利",
		"cost": 15,
		"satiety": 25,
		"energy": 6,
		"mood": 3,
		"burden": 2,
		"tags": ["fastfood", "convenient", "moderate", "staple", "protein"],
		"desc": "均衡一点，也贵一点。",
		"image": "res://assets/generated/cards/sandwich.png",
	},
}

const ACTION_IDS := [
	"study",
	"nap",
	"walk",
	"drink_water",
	"go_cafeteria",
	"convenience_store",
]

const ACTIONS := {
	"study": {
		"id": "study",
		"name": "复习",
		"cost": 0,
		"slots": 1,
		"energy": -8,
		"mood": -2,
		"stress": 3,
		"study": 10,
		"satiety": -4,
		"burden": 0,
		"desc": "推进考试目标，但会消耗状态。",
		"image": "res://assets/generated/actions/study.png",
	},
	"nap": {
		"id": "nap",
		"name": "小睡",
		"cost": 0,
		"slots": 1,
		"energy": 14,
		"mood": 2,
		"stress": -4,
		"study": 0,
		"satiety": -2,
		"burden": 0,
		"desc": "短休恢复精力，牺牲一个行动。",
		"image": "res://assets/generated/actions/nap.png",
	},
	"walk": {
		"id": "walk",
		"name": "散步",
		"cost": 0,
		"slots": 1,
		"energy": -3,
		"mood": 3,
		"stress": -6,
		"study": 0,
		"satiety": -3,
		"burden": -2,
		"desc": "让脑子透气，降低压力和负担。",
		"image": "res://assets/generated/actions/walk.png",
	},
	"drink_water": {
		"id": "drink_water",
		"name": "喝水",
		"cost": 0,
		"slots": 1,
		"energy": 1,
		"mood": 0,
		"stress": -1,
		"study": 0,
		"satiety": 3,
		"burden": -3,
		"desc": "免费小维护，占一次餐后行动，每天最多两次。",
		"image": "res://assets/generated/actions/drink_water.png",
	},
	"go_cafeteria": {
		"id": "go_cafeteria",
		"name": "去食堂",
		"cost": 0,
		"slots": 1,
		"energy": -2,
		"mood": 1,
		"stress": -2,
		"study": 0,
		"satiety": 0,
		"burden": -1,
		"desc": "把明天的抽牌偏向便宜均衡食物。",
		"image": "res://assets/generated/actions/go_cafeteria.png",
	},
	"convenience_store": {
		"id": "convenience_store",
		"name": "便利店",
		"cost": 0,
		"slots": 1,
		"energy": -2,
		"mood": 3,
		"stress": 0,
		"study": 0,
		"satiety": 0,
		"burden": 2,
		"desc": "把明天的抽牌偏向快乐速食。",
		"image": "res://assets/generated/actions/convenience_store.png",
	},
	"sleep_early": {
		"id": "sleep_early",
		"name": "早睡",
		"cost": 0,
		"slots": 1,
		"energy": 8,
		"mood": 2,
		"stress": -3,
		"study": 0,
		"satiety": -3,
		"burden": -1,
		"desc": "提前收尾，让夜晚少一点透支。",
		"image": "res://assets/generated/actions/sleep_early.png",
	},
	"allow_imperfection": {
		"id": "allow_imperfection",
		"name": "允许不完美",
		"cost": 0,
		"slots": 1,
		"energy": 4,
		"mood": 7,
		"stress": -8,
		"study": -2,
		"satiety": 0,
		"burden": -1,
		"desc": "少一点自责，今天也算走过来了。",
		"image": "res://assets/generated/actions/allow_imperfection.png",
	},
}

const SLEEP_OPTIONS := {
	"sleep_early": {
		"id": "sleep_early",
		"name": "早睡恢复",
		"energy": 26,
		"mood": 3,
		"stress": -9,
		"study": 0,
		"satiety": -12,
		"burden": -4,
		"desc": "明天的底盘更稳。",
	},
	"night_study": {
		"id": "night_study",
		"name": "熬夜复习",
		"energy": -22,
		"mood": -5,
		"stress": 12,
		"study": 16,
		"satiety": -11,
		"burden": 2,
		"desc": "进度会上去，代价也会显形。",
	},
	"scroll_phone": {
		"id": "scroll_phone",
		"name": "刷手机放空",
		"energy": -10,
		"mood": 8,
		"stress": -2,
		"study": 0,
		"satiety": -8,
		"burden": 1,
		"desc": "心情松一点，睡眠浅一点。",
	},
}

const ENDINGS := {
	"stable_endurance": {
		"id": "stable_endurance",
		"title": "稳定通过",
		"subtitle": "你没有完美生活，但你学会了把自己托住。",
		"image": "res://assets/generated/endings/stable_endurance.png",
	},
	"barely_survived": {
		"id": "barely_survived",
		"title": "勉强撑过",
		"subtitle": "这一周很狼狈，但你还是抵达了周末。",
		"image": "res://assets/generated/endings/barely_survived.png",
	},
	"collapsed": {
		"id": "collapsed",
		"title": "状态崩盘",
		"subtitle": "身体、预算和压力同时报警。下次需要更早止损。",
		"image": "res://assets/generated/endings/collapsed.png",
	},
}

static func get_starting_stats() -> Dictionary:
	return STARTING_STATS.duplicate(true)


static func get_food(id: String) -> Dictionary:
	if not FOODS.has(id):
		push_error("Unknown food id: %s" % id)
		return {}
	return FOODS[id].duplicate(true)


static func get_action(id: String) -> Dictionary:
	if not ACTIONS.has(id):
		push_error("Unknown action id: %s" % id)
		return {}
	return ACTIONS[id].duplicate(true)


static func get_sleep_option(id: String) -> Dictionary:
	if not SLEEP_OPTIONS.has(id):
		push_error("Unknown sleep id: %s" % id)
		return {}
	return SLEEP_OPTIONS[id].duplicate(true)


static func get_ending(id: String) -> Dictionary:
	if not ENDINGS.has(id):
		push_error("Unknown ending id: %s" % id)
		return ENDINGS["collapsed"].duplicate(true)
	return ENDINGS[id].duplicate(true)


static func has_tag(item: Dictionary, tag: String) -> bool:
	return item.has("tags") and item["tags"].has(tag)


static func cheapest_food_cost() -> int:
	var cheapest := 999
	for id in FOOD_IDS:
		cheapest = min(cheapest, int(FOODS[id]["cost"]))
	return cheapest
