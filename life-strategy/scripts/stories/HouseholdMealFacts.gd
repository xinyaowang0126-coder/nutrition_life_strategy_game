class_name HouseholdMealFacts
extends RefCounted

## Declared classroom recipe quantities, not measurements of real products.
const VERSION := "household-recipe-facts-v1"
const SOY_LABEL_ID := "teaching-soy-7000-v1"
const SOY_SODIUM_PER_100_ML := 7000
const SEASONINGS := {
	"none": {"name": "不另加咸味调味", "salt_g": 0, "soy_ml": 0},
	"light": {"name": "少放一点", "salt_g": 1, "soy_ml": 5},
	"usual": {"name": "按原来的口味", "salt_g": 2, "soy_ml": 10},
}
const SEASONING_ORDER := ["light", "usual", "none"]
const SUGAR_ORDER := [0, 4, 8]


static func supports(ids: Array, foods: Dictionary, key: String) -> bool:
	for id in ids:
		if String(foods.get(id, {}).get(key, "false")) == "true":
			return true
	return false


static func defaults(ids: Array, foods: Dictionary) -> Dictionary:
	return {"seasoning": "light" if supports(ids, foods, "seasonable") else "none", "added_sugar_g": 0}


static func validate(plan: Dictionary, ids: Array, foods: Dictionary) -> bool:
	if ids.is_empty():
		return false
	var unique := {}
	for id in ids:
		if typeof(id) != TYPE_STRING or not foods.get(id) is Dictionary or unique.has(id):
			return false
		unique[id] = true
	if plan.size() != 2 or not plan.has("seasoning") or not plan.has("added_sugar_g"):
		return false
	if typeof(plan["seasoning"]) != TYPE_STRING or not SEASONINGS.has(plan["seasoning"]):
		return false
	if typeof(plan["added_sugar_g"]) != TYPE_INT or not SUGAR_ORDER.has(plan["added_sugar_g"]):
		return false
	if not supports(ids, foods, "seasonable") and plan["seasoning"] != "none":
		return false
	return supports(ids, foods, "sweetenable") or plan["added_sugar_g"] == 0


static func seasoning_needs(plan: Dictionary, portions: int = 1) -> Dictionary:
	var preset: Dictionary = SEASONINGS.get(plan.get("seasoning", ""), {})
	return {"salt_g": int(preset.get("salt_g", 0)) * portions, "soy_ml": int(preset.get("soy_ml", 0)) * portions, "sugar_g": int(plan.get("added_sugar_g", 0)) * portions}


static func freeze(ids: Array, foods: Dictionary, plan: Dictionary) -> Dictionary:
	if not validate(plan, ids, foods):
		return {}
	var quantities := seasoning_needs(plan)
	var recipes: Array[Dictionary] = []
	for id in ids:
		var food: Dictionary = foods[id]
		recipes.append({"food_id": id, "name": food["name"], "recipe_version": 1, "ingredients": String(food.get("ingredients", "")), "method": String(food.get("method", "现做")), "texture": String(food.get("texture", "按原做法")), "seasonable": String(food.get("seasonable", "false")) == "true", "sweetenable": String(food.get("sweetenable", "false")) == "true"})
	var sodium := int(quantities["salt_g"]) * 400 + int(quantities["soy_ml"]) * SOY_SODIUM_PER_100_ML / 100
	return {"version": VERSION, "scope": "declared_game_recipe", "personal_portions": 1, "recipes": recipes, "salt_g": quantities["salt_g"], "soy_ml": quantities["soy_ml"], "sodium_from_added_seasonings_mg": int(sodium), "ingredient_sodium_status": "unknown", "white_sugar_added_g": quantities["sugar_g"], "total_sugars_status": "unknown", "other_added_sugars_status": "unknown", "soy_label_id": SOY_LABEL_ID}


static func describe(facts: Dictionary) -> String:
	if not valid(facts):
		return "这份配方的调味量未记录。"
	var text := "本关配方，每人份：食盐约%s克、酱油约%s毫升，追加调味带来约%s毫克钠；另加白糖约%s克。\n食材本身的钠、原有糖和其他添加糖未记录，不能当成整餐或全天总量。" % [number(facts["salt_g"]), number(facts["soy_ml"]), number(facts["sodium_from_added_seasonings_mg"]), number(facts["white_sugar_added_g"])]
	if int(facts.get("unrecorded_items", 0)) > 0:
		text += "\n另有%d项食物没有配方调味记录。" % int(facts["unrecorded_items"])
	return text


static func number(value: Variant) -> String:
	return str(int(value)) if is_equal_approx(float(value), float(int(value))) else "%.2f" % float(value)


static func valid(facts: Dictionary) -> bool:
	if facts.get("version") != VERSION or facts.get("scope") != "declared_game_recipe" or facts.get("soy_label_id") != SOY_LABEL_ID:
		return false
	if facts.get("personal_portions") != 1 or not facts.get("recipes") is Array or facts["recipes"].is_empty():
		return false
	for key in ["ingredient_sodium_status", "total_sugars_status", "other_added_sugars_status"]:
		if facts.get(key) != "unknown":
			return false
	for recipe in facts["recipes"]:
		if not recipe is Dictionary or typeof(recipe.get("food_id")) != TYPE_STRING or String(recipe["food_id"]).is_empty():
			return false
		if typeof(recipe.get("seasonable")) != TYPE_BOOL or typeof(recipe.get("sweetenable")) != TYPE_BOOL:
			return false
	for key in ["salt_g", "soy_ml", "sodium_from_added_seasonings_mg", "white_sugar_added_g"]:
		if typeof(facts.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(facts[key])) or float(facts[key]) < 0:
			return false
	return is_equal_approx(float(facts["sodium_from_added_seasonings_mg"]), float(facts["salt_g"]) * 400 + float(facts["soy_ml"]) * SOY_SODIUM_PER_100_ML / 100)


static func for_food(facts: Dictionary, food_id: String) -> Dictionary:
	if not valid(facts):
		return {}
	var result := facts.duplicate(true)
	var salty := 0
	var sweet := 0
	var selected := {}
	for recipe in facts["recipes"]:
		salty += 1 if recipe["seasonable"] else 0
		sweet += 1 if recipe["sweetenable"] else 0
		if recipe["food_id"] == food_id:
			selected = recipe.duplicate(true)
	if selected.is_empty():
		return {}
	result["recipes"] = [selected]
	for key in ["salt_g", "soy_ml", "sodium_from_added_seasonings_mg"]:
		result[key] = float(facts[key]) / salty if selected["seasonable"] and salty > 0 else 0.0
	result["white_sugar_added_g"] = float(facts["white_sugar_added_g"]) / sweet if selected["sweetenable"] and sweet > 0 else 0.0
	return result


static func from_batches(batches: Array) -> Dictionary:
	var recipes: Array[Dictionary] = []
	var totals := {"salt_g": 0.0, "soy_ml": 0.0, "sodium_from_added_seasonings_mg": 0.0, "white_sugar_added_g": 0.0}
	var known := 0
	var unknown := 0
	for batch in batches:
		var facts: Variant = batch.get("recipe_facts") if batch is Dictionary else null
		if not facts is Dictionary or not valid(facts) or facts["recipes"].size() != 1 or facts["recipes"][0]["food_id"] != batch.get("food_id"):
			unknown += 1
			continue
		known += 1
		for key in totals:
			totals[key] += float(facts[key])
		for recipe in facts.get("recipes", []):
			if recipe.get("food_id") == batch.get("food_id"):
				recipes.append(recipe.duplicate(true))
	if known == 0:
		return {}
	var result := {"version": VERSION, "scope": "declared_game_recipe", "personal_portions": 1, "recipes": recipes, "ingredient_sodium_status": "unknown", "total_sugars_status": "unknown", "other_added_sugars_status": "unknown", "soy_label_id": SOY_LABEL_ID}
	for key in totals:
		result[key] = totals[key]
	result["unrecorded_items"] = unknown
	return result


static func summarize(meals: Array) -> Dictionary:
	var sodium := 0.0
	var sugar := 0.0
	var counted := 0
	var unknown := 0
	for meal in meals:
		if not meal is Dictionary or bool(meal.get("skipped", false)):
			continue
		var facts: Variant = meal.get("recipe_facts")
		if not facts is Dictionary or not valid(facts):
			unknown += 1
			continue
		counted += 1
		sodium += float(facts["sodium_from_added_seasonings_mg"])
		sugar += float(facts["white_sugar_added_g"])
	var text := "今天%d餐有配方记录：追加调味钠已知小计约%s毫克，另加白糖已知小计约%s克。" % [counted, number(sodium), number(sugar)] if counted > 0 else "今天没有可汇总的配方调味量。"
	return {"known_seasoning_sodium_mg": sodium, "known_white_sugar_g": sugar, "recorded_meals": counted, "meals_without_recipe_facts": unknown, "text": text + "\n这不是全天总摄入；食材本底及未记录项目仍未知。"}
