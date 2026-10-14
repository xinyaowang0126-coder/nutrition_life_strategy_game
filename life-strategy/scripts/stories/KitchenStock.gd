class_name KitchenStock
extends RefCounted

## This is inventory and temperature-history simulation, not a illness model.
const RULE_VERSION := "leftovers-cfs-v1"
const READY_FOODS := ["milk", "apple"]
const MealFacts := preload("res://scripts/stories/HouseholdMealFacts.gd")
var ingredients: Dictionary = {}
var condiments: Dictionary = {}
var batches: Array[Dictionary] = []
var history: Array[Dictionary] = []
var _serial := 0


func reset() -> void:
	ingredients = {"rice_plain": 8, "egg": 5, "tofu": 5, "greens": 5, "tomato": 4, "oatmeal": 4, "millet": 4, "milk": 3, "apple": 3, "fish": 2}
	condiments = {"salt_g": 40, "soy_ml": 60, "sugar_g": 40}
	batches.clear()
	history.clear()
	_serial = 0
	# A disclosed fact from before this run, never attributed to the player.
	batches.append({"id": "before_week_greens", "food_id": "greens", "day": 0, "storage": "counter", "reheated": false, "reheat_count": 0, "danger_minutes": 720, "known_history": true, "status": "discard_required", "quantity": 1, "note": "昨晚20:00做；今早08:00仍在灶台，常温12小时，未冷藏。"})


func needs(ids: Array, foods: Dictionary) -> Dictionary:
	var required := {}
	for id in ids:
		if not foods.has(id):
			return {"__invalid": 999}
		for item in String(foods[id].get("ingredients", id + ":1")).split(",", false):
			var parts := item.split(":", false)
			if parts.size() != 2 or int(parts[1]) <= 0:
				return {"__invalid": 999}
			required[parts[0]] = int(required.get(parts[0], 0)) + int(parts[1])
	return required


func can_cook(ids: Array, foods: Dictionary, multiplier: int = 1) -> bool:
	if ids.is_empty() or multiplier < 1 or multiplier > 3:
		return false
	for id in needs(ids, foods):
		if int(ingredients.get(id, 0)) < int(needs(ids, foods)[id]) * multiplier:
			return false
	return true


func can_prepare(ids: Array, foods: Dictionary, portions: int, plan: Dictionary) -> bool:
	if not can_cook(ids, foods, portions) or not MealFacts.validate(plan, ids, foods):
		return false
	for key in MealFacts.seasoning_needs(plan, portions):
		if int(condiments.get(key, 0)) < int(MealFacts.seasoning_needs(plan, portions)[key]):
			return false
	return true


func cook(ids: Array, foods: Dictionary, day: int, storage: String = "eat_now", hour: int = -1, plan: Dictionary = {}, served_portions: int = 1) -> Dictionary:
	if day < 1 or day > 7:
		return {"ok": false, "reason": "day_invalid"}
	if storage not in ["eat_now", "fridge", "counter"]:
		return {"ok": false, "reason": "storage_unknown"}
	if served_portions not in [1, 2]:
		return {"ok": false, "reason": "portions_invalid"}
	var selected_plan := MealFacts.defaults(ids, foods) if plan.is_empty() else plan.duplicate(true)
	var multiplier := served_portions + (0 if storage == "eat_now" else 1)
	if not can_prepare(ids, foods, multiplier, selected_plan):
		return {"ok": false, "reason": "ingredients_or_condiments_short"}
	var facts := MealFacts.freeze(ids, foods, selected_plan)
	var condiment_used := MealFacts.seasoning_needs(selected_plan, multiplier)
	for key in condiment_used:
		condiments[key] -= condiment_used[key]
	var consumed := needs(ids, foods)
	for id in consumed:
		consumed[id] *= multiplier
		ingredients[id] -= consumed[id]
	var prepared: Array[Dictionary] = []
	if storage != "eat_now":
		for id in ids:
			_serial += 1
			var batch := {"id": "batch_%d" % _serial, "food_id": id, "day": day, "quantity": 1, "storage": storage, "reheated": false, "reheat_count": 0, "known_history": true, "danger_minutes": 60 if storage == "fridge" else 300, "cooled_after_minutes": 60, "fridge_max_c": 4, "clean_container": true, "status": "needs_reheat" if storage == "fridge" else "discard_required", "rule_version": RULE_VERSION, "note": "上桌前用清洁浅盒分装，1小时内放入4℃冰箱，连续冷藏。" if storage == "fridge" else "计划留在灶台至下一餐；关卡经过5小时，未保持安全温度。"}
			batches.append(batch)
			batch["made_hour"] = day * 24 + 8 if hour < 0 else hour
			batch["stored_hour"] = batch["made_hour"] + 1
			# A batch is one complete future portion, including this dish's share
			# of the plate's seasoning. It is never recomputed from today's defaults.
			batch["recipe_facts"] = MealFacts.for_food(facts, String(id))
			prepared.append(batch.duplicate(true))
	var record := {"action": "cook", "day": day, "ingredients_used": consumed, "condiments_used": condiment_used, "served_portions": served_portions, "recipe_facts": facts, "prepared": prepared}
	history.append(record.duplicate(true))
	return {"ok": true, "record": record}


func refresh(day: int, hour: int = -1) -> void:
	for batch in batches:
		if int(batch.get("quantity", 0)) > 0:
			batch["status"] = classify(batch, day, hour)
			if day - int(batch.get("day", day)) > 3 or (hour >= 0 and batch.has("stored_hour") and hour - int(batch["stored_hour"]) > 72):
				batch["note"] = "冷藏已超过3天，应丢弃。"


static func classify(batch: Dictionary, day: int, hour: int = -1) -> String:
	if typeof(batch.get("known_history")) != TYPE_BOOL or not batch.get("known_history", false) or not batch.has("danger_minutes") or not batch.has("reheat_count") or not batch.has("day"):
		return "history_unknown"
	for key in ["danger_minutes", "reheat_count", "day"]:
		if typeof(batch[key]) != TYPE_INT or int(batch[key]) < 0:
			return "history_unknown"
	if int(batch["danger_minutes"]) > 240 or int(batch["reheat_count"]) > 0 or day - int(batch["day"]) > 3:
		return "discard_required"
	if hour >= 0 and batch.has("stored_hour") and hour - int(batch["stored_hour"]) > 72:
		return "discard_required"
	if day < int(batch["day"]) or batch.get("storage") != "fridge":
		return "history_unknown"
	if typeof(batch.get("cooled_after_minutes")) != TYPE_INT or typeof(batch.get("clean_container")) != TYPE_BOOL or not batch.get("clean_container", false):
		return "history_unknown"
	if typeof(batch.get("fridge_max_c")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(batch["fridge_max_c"])) or int(batch["cooled_after_minutes"]) < 0:
		return "history_unknown"
	if int(batch["danger_minutes"]) >= 120 or int(batch["cooled_after_minutes"]) >= 120 or float(batch["fridge_max_c"]) > 4:
		return "discard_required"
	return "needs_reheat"


func available(food_id: String, day: int, hour: int = -1) -> int:
	refresh(day, hour)
	var count := int(ingredients.get(food_id, 0)) if READY_FOODS.has(food_id) else 0
	for batch in batches:
		if batch["food_id"] == food_id and batch["status"] == "needs_reheat" and not batch["reheated"]:
			count += int(batch["quantity"])
	return count


func consume(ids: Array, day: int, hour: int = -1) -> Dictionary:
	var unique := {}
	for id in ids:
		if unique.has(id) or available(String(id), day, hour) <= 0:
			return {"ok": false, "reason": "batch_unavailable"}
		unique[id] = true
	var consumed: Array[Dictionary] = []
	for id in ids:
		if READY_FOODS.has(id) and int(ingredients.get(id, 0)) > 0:
			ingredients[id] -= 1
			consumed.append({"food_id": id, "kind": "ready_pantry", "quantity": 1, "served_day": day, "note": "按标签贮存的未开封常温奶／完整水果，按份取用。"})
			continue
		for batch in batches:
			if batch["food_id"] == id and batch["status"] == "needs_reheat" and int(batch["quantity"]) > 0:
				batch["reheated"] = true
				batch["reheat_count"] = 1
				batch["quantity"] -= 1
				batch["status"] = "consumed"
				var snapshot := batch.duplicate(true)
				snapshot["served_day"] = day
				snapshot["reheat_note"] = "取当餐份量，彻底再热至中心温度至少75℃；再热一次。"
				consumed.append(snapshot)
				break
	var record := {"action": "reheat_and_eat", "day": day, "batches": consumed}
	history.append(record.duplicate(true))
	return {"ok": true, "record": record}


func discard(batch_id: String, day: int) -> bool:
	for batch in batches:
		if batch["id"] == batch_id and int(batch["quantity"]) > 0:
			var record := {"action": "discard", "day": day, "batch": batch.duplicate(true)}
			batch["quantity"] = 0
			batch["status"] = "discarded"
			history.append(record)
			return true
	return false
