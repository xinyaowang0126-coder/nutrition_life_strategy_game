class_name MealResolver
extends RefCounted

const FoodPreferenceServiceScript := preload("res://scripts/systems/FoodPreferenceService.gd")
const Reserve := preload("res://scripts/systems/GameReserveCalculator.gd")
const PROTEIN_FOOD_GROUPS := [
	"fish_seafood",
	"poultry_livestock",
	"animal_foods",
	"eggs",
	"dairy",
	"soy_products",
	"nuts_seeds",
]


static func build_record(
	meal_phase: String,
	source: Dictionary,
	foods: Array[Dictionary],
	preferences: Variant = null
) -> Dictionary:
	var food_ids: Array[String] = []
	var food_names: Array[String] = []
	var tags: Array[String] = []
	var food_groups: Array[String] = []
	var nutrient_tags: Array[String] = []
	var limit_tags: Array[String] = []
	var reactions := _preference_reactions(foods, preferences)
	var delta := _stat_delta(foods, source, reactions)
	var food_cost := 0

	for food in foods:
		food_ids.append(String(food["id"]))
		food_names.append(String(food["name"]))
		food_cost += int(food.get("cost", 0))
		for tag in food.get("tags", []):
			var normalized := String(tag)
			if not tags.has(normalized):
				tags.append(normalized)
		_merge_unique(food_groups, food.get("food_groups", []))
		_merge_unique(nutrient_tags, food.get("nutrient_tags", []))
		_merge_unique(limit_tags, food.get("limit_tags", []))

	var uses_stock := String(source.get("payment_mode", "cash")) == "stock"
	var source_fee := 0 if uses_stock else int(source.get("fee", 0))
	var charged_food_cost := 0 if uses_stock else food_cost
	return {
		"phase": meal_phase,
		"source_id": String(source.get("id", "")),
		"source_name": String(source.get("name", "")),
		"food_ids": food_ids,
		"food_names": food_names,
		"food_cost": charged_food_cost,
		"source_fee": source_fee,
		"total_cost": charged_food_cost + source_fee,
		"tags": tags,
		"food_groups": food_groups,
		"nutrient_tags": nutrient_tags,
		"limit_tags": limit_tags,
		"stat_delta": delta,
		"preference_reactions": reactions,
		"skipped": false,
		"uses_stock": uses_stock,
		"comfort": reactions.any(func(reaction: Dictionary) -> bool: return reaction["comfort"]),
	}


static func _preference_reactions(foods: Array[Dictionary], preferences: Variant) -> Array[Dictionary]:
	# null preserves existing callers; an explicitly empty profile means no
	# declared tastes. Never infer preferences from food or health metadata.
	var profile: Dictionary = FoodPreferenceServiceScript.default_profile() if preferences == null else (
		preferences if preferences is Dictionary else {}
	)
	var reactions: Array[Dictionary] = []
	for food in foods:
		var food_id := String(food["id"])
		var reaction: Dictionary = FoodPreferenceServiceScript.reaction(food_id, profile)
		reaction["food_id"] = food_id
		reactions.append(reaction)
	return reactions


static func _stat_delta(foods: Array[Dictionary], source: Dictionary, reactions: Array[Dictionary]) -> Dictionary:
	var delta := {"satiety": 0, "energy": 0, "mood": 0, "stress": 0, "study_progress": 0}
	for food in foods:
		for key in ["satiety", "energy", "stress"]:
			delta[key] += int(food.get(key, 0))
	for reaction in reactions:
		delta["mood"] += int(reaction["mood_delta"])
	# Source events still express effort/mood costs independently of taste.
	for key in ["energy", "mood", "stress"]:
		delta[key] += int(source.get(key, 0))
	return delta


static func build_skipped_record(meal_phase: String) -> Dictionary:
	return {
		"phase": meal_phase,
		"source_id": "",
		"source_name": "",
		"food_ids": [],
		"food_names": [],
		"food_cost": 0,
		"source_fee": 0,
		"total_cost": 0,
		"tags": [],
		"food_groups": [],
		"nutrient_tags": [],
		"limit_tags": [],
		"stat_delta": {
			"satiety": 0,
			"energy": -2,
			"mood": -2,
			"stress": 3,
			"study_progress": 0,
		},
		"skipped": true,
		"preference_reactions": [],
		"uses_stock": false,
		"comfort": false,
	}




static func has_meal_group_combination(record: Dictionary) -> bool:
	var groups: Array = record.get("food_groups", [])
	var has_protein_food := _has_any_value(groups, PROTEIN_FOOD_GROUPS)
	return groups.has("grains_tubers") and groups.has("vegetables") and has_protein_food


static func comfort_meal_count(records: Array[Dictionary]) -> int:
	var count := 0
	for record in records:
		if bool(record.get("comfort", false)):
			count += 1
	return count


static func total_spend(records: Array[Dictionary]) -> int:
	var total := 0
	for record in records:
		total += int(record.get("total_cost", 0))
	return total


static func has_tag(item: Dictionary, tag: String) -> bool:
	return item.has("tags") and item["tags"].has(tag)


static func has_any_tag(tags: Array[String], wanted: Array) -> bool:
	for tag in wanted:
		if tags.has(String(tag)):
			return true
	return false


static func _merge_unique(target: Array[String], values: Array) -> void:
	for value in values:
		var normalized := String(value)
		if not target.has(normalized):
			target.append(normalized)


static func _has_any_value(values: Array, wanted: Array) -> bool:
	for value in wanted:
		if values.has(value):
			return true
	return false


## Deprecated positional compatibility for existing gameplay callers.
## The former meal-quality argument has no effect on game reserve.
static func calculate_stability(state: Dictionary, _avg_quality: int, day: int, total_days: int, recovery_contribution: float) -> int:
	return Reserve.calculate(state, day, total_days, recovery_contribution)


static func select_ending(state: Dictionary, _recovery_rules: bool = true) -> String:
	return String(ending_result(state)["id"])


## Shared classification and explanation; preserve the existing priority order.
static func ending_result(state: Dictionary) -> Dictionary:
	var reserve := int(state.get("stability", 0))
	var progress := int(state.get("study_progress", 0))
	var id := "collapsed"
	var reason := "low_reserve"
	if reserve <= 15:
		reason = "critical_reserve"
	elif progress < 50:
		id = "study_shortfall"
		reason = "study_gap"
	elif progress >= 70 and reserve >= 60:
		id = "stable_endurance"
		reason = "steady"
	elif reserve >= 25:
		id = "barely_survived"
		reason = "goal_gap" if progress < 70 else "reserve_gap"
	return {"id": id, "reason": reason, "goal_gap": maxi(0, 70 - progress), "reserve_gap": maxi(0, 60 - reserve)}
