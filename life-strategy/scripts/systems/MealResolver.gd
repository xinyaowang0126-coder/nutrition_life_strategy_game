class_name MealResolver
extends RefCounted

const COMFORT_TAGS := ["favorite", "instant", "high_sugar", "high_fat", "high_sodium"]
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
	foods: Array[Dictionary]
) -> Dictionary:
	var food_ids: Array[String] = []
	var food_names: Array[String] = []
	var tags: Array[String] = []
	var food_groups: Array[String] = []
	var nutrient_tags: Array[String] = []
	var limit_tags: Array[String] = []
	var delta := {
		"satiety": 0,
		"energy": 0,
		"mood": 0,
		"stress": 0,
		"diet_burden": 0,
		"study_progress": 0,
	}
	var food_cost := 0

	for food in foods:
		food_ids.append(String(food["id"]))
		food_names.append(String(food["name"]))
		food_cost += int(food.get("cost", 0))
		delta["satiety"] += int(food.get("satiety", 0))
		delta["energy"] += int(food.get("energy", 0))
		delta["mood"] += int(food.get("mood", 0))
		delta["stress"] += int(food.get("stress", 0))
		delta["diet_burden"] += int(food.get("burden", 0))
		for tag in food.get("tags", []):
			var normalized := String(tag)
			if not tags.has(normalized):
				tags.append(normalized)
		_merge_unique(food_groups, food.get("food_groups", []))
		_merge_unique(nutrient_tags, food.get("nutrient_tags", []))
		_merge_unique(limit_tags, food.get("limit_tags", []))

	# A source can trade time/effort for money. Keeping these effects in the
	# resolver also lets temporary events pass an adjusted source dictionary.
	delta["energy"] += int(source.get("energy", 0))
	delta["mood"] += int(source.get("mood", 0))
	delta["stress"] += int(source.get("stress", 0))
	delta["diet_burden"] += int(source.get("burden", 0))

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
		"quality": plate_quality(food_groups, nutrient_tags, limit_tags),
		"tags": tags,
		"food_groups": food_groups,
		"nutrient_tags": nutrient_tags,
		"limit_tags": limit_tags,
		"stat_delta": delta,
		"skipped": false,
		"uses_stock": uses_stock,
		"comfort": has_any_tag(tags, COMFORT_TAGS),
	}


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
		"quality": 25,
		"tags": [],
		"food_groups": [],
		"nutrient_tags": [],
		"limit_tags": [],
		"stat_delta": {
			"satiety": -16,
			"energy": -5,
			"mood": -4,
			"stress": 7,
			"diet_burden": 0,
			"study_progress": 0,
		},
		"skipped": true,
		"uses_stock": false,
		"comfort": false,
	}


static func food_quality(food: Dictionary) -> int:
	return plate_quality(
		food.get("food_groups", []),
		food.get("nutrient_tags", []),
		food.get("limit_tags", [])
	)


## Rates the structure of the whole plate instead of averaging unrelated
## single-food scores. The inputs deliberately use the professional food data;
## presentation tags and price do not stand in for nutritional composition.
static func plate_quality(food_groups: Array, nutrient_tags: Array, limit_tags: Array) -> int:
	var quality := 20
	var has_grain := food_groups.has("grains_tubers")
	var has_vegetable := food_groups.has("vegetables")
	var has_protein_food := _has_any_value(food_groups, PROTEIN_FOOD_GROUPS)

	quality += 12 if has_grain else 0
	quality += 15 if has_vegetable else 0
	quality += 10 if food_groups.has("fruits") else 0
	quality += 14 if has_protein_food else 0
	quality += 3 if food_groups.has("dairy") else 0

	quality += 4 if nutrient_tags.has("carbohydrate_source") else 0
	quality += 5 if nutrient_tags.has("dietary_fiber_source") else 0
	quality += 6 if nutrient_tags.has("high_quality_protein_source") else 0
	quality += 4 if nutrient_tags.has("whole_grain") else 0
	quality += 3 if nutrient_tags.has("calcium_source") else 0
	quality += 3 if nutrient_tags.has("unsaturated_fatty_acid_source") else 0

	if has_grain and has_vegetable and has_protein_food:
		quality += 10

	quality -= 12 if limit_tags.has("added_sugar") else 0
	quality -= 10 if limit_tags.has("high_sodium") else 0
	quality -= 12 if limit_tags.has("fried") else 0
	return clamp(quality, 20, 95)


static func average_scores(scores: Array[int]) -> int:
	if scores.is_empty():
		return 25
	var total := 0
	for score in scores:
		total += score
	return int(round(float(total) / float(scores.size())))


static func day_quality(records: Array[Dictionary]) -> int:
	var scores: Array[int] = []
	for record in records:
		scores.append(int(record.get("quality", 25)))
	return average_scores(scores)


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


static func calculate_stability(state: Dictionary, avg_quality: int, day: int, total_days: int) -> int:
	var mental := float(state["mood"]) * 0.55 + (100.0 - float(state["stress"])) * 0.45
	var remaining_days: int = max(0, total_days - day)
	var budget_safety := 100.0
	if remaining_days > 0:
		budget_safety = clamp(float(state["balance"]) / (float(remaining_days) * 10.0) * 100.0, 0.0, 100.0)
	var diet_control := 100.0 - float(state["diet_burden"])
	var score := float(avg_quality) * 0.20
	score += mental * 0.25
	score += float(state["energy"]) * 0.20
	score += float(state["satiety"]) * 0.10
	score += diet_control * 0.10
	score += float(state["study_progress"]) * 0.10
	score += budget_safety * 0.05
	if int(state["energy"]) < 16:
		score -= 10
	if int(state["mood"]) < 16:
		score -= 10
	if int(state["satiety"]) < 12:
		score -= 8
	if int(state["stress"]) > 88:
		score -= 10
	if remaining_days > 0 and int(state["balance"]) < remaining_days * 6:
		score -= 8
	return int(round(clamp(score, 0.0, 100.0)))


static func select_ending(state: Dictionary) -> String:
	if int(state["stability"]) <= 15:
		return "collapsed"
	if int(state["study_progress"]) < 50:
		return "study_shortfall"
	if int(state["study_progress"]) >= 70 and int(state["stability"]) >= 60 and int(state["diet_burden"]) <= 60:
		return "stable_endurance"
	if int(state["stability"]) >= 25:
		return "barely_survived"
	return "collapsed"
