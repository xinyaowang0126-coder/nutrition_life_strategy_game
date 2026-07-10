class_name MealResolver
extends RefCounted

const COMFORT_TAGS := ["favorite", "instant", "high_sugar", "high_fat", "high_sodium"]


static func build_record(
	meal_phase: String,
	source: Dictionary,
	foods: Array[Dictionary]
) -> Dictionary:
	var food_ids: Array[String] = []
	var food_names: Array[String] = []
	var qualities: Array[int] = []
	var tags: Array[String] = []
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
		qualities.append(food_quality(food))
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
		"quality": average_scores(qualities),
		"tags": tags,
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
	var quality := 48
	if has_tag(food, "staple"):
		quality += 8
	if has_tag(food, "protein"):
		quality += 12
	if has_tag(food, "vegetable") or has_tag(food, "fruit") or has_tag(food, "fruit_like"):
		quality += 13
	if has_tag(food, "fiber") or has_tag(food, "whole_grain"):
		quality += 5
	if has_tag(food, "high_sugar"):
		quality -= 11
	if has_tag(food, "high_fat"):
		quality -= 10
	if has_tag(food, "high_sodium"):
		quality -= 8
	if has_tag(food, "instant"):
		quality -= 6
	if int(food.get("cost", 0)) > 22:
		quality -= 2
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


static func has_balanced_plate(record: Dictionary) -> bool:
	var tags: Array = record.get("tags", [])
	return (
		tags.has("staple")
		and tags.has("protein")
		and (tags.has("vegetable") or tags.has("fruit") or tags.has("fruit_like"))
	)


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


static func calculate_stability(state: Dictionary, avg_quality: int, day: int, total_days: int) -> int:
	var mental := float(state["mood"]) * 0.55 + (100.0 - float(state["stress"])) * 0.45
	var remaining_days: int = max(1, total_days - day + 1)
	var budget_safety: float = clamp(float(state["balance"]) / (float(remaining_days) * 10.0) * 100.0, 0.0, 100.0)
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
	if int(state["balance"]) < max(1, remaining_days * 6):
		score -= 8
	return int(round(clamp(score, 0.0, 100.0)))


static func select_ending(state: Dictionary) -> String:
	if int(state["stability"]) <= 15:
		return "collapsed"
	if int(state["study_progress"]) < 45:
		return "study_shortfall"
	if int(state["study_progress"]) >= 72 and int(state["stability"]) >= 60 and int(state["diet_burden"]) <= 60:
		return "stable_endurance"
	if int(state["study_progress"]) >= 50 and int(state["stability"]) >= 25:
		return "barely_survived"
	return "collapsed"
