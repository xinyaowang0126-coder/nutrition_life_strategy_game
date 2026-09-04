class_name NutritionLedger
extends RefCounted

const MealResolverScript := preload("res://scripts/systems/MealResolver.gd")

## Summarizes observable dietary patterns from today's meal records.
## Food-group and nutrient-source occurrence does not mean intake adequacy.

const EXPECTED_MEALS := 3
const ANIMAL_FOOD_GROUPS := ["fish_seafood", "poultry_livestock", "animal_foods", "eggs"]


static func summarize(records: Array[Dictionary]) -> Dictionary:
	var eaten_meals := 0
	var skipped_meals := 0
	var grain_meals := 0
	var vegetable_meals := 0
	var fruit_meals := 0
	var animal_food_meals := 0
	var dairy_meals := 0
	var soy_meals := 0
	var nuts_meals := 0
	var carbohydrate_source_meals := 0
	var fiber_source_meals := 0
	var high_quality_protein_meals := 0
	var calcium_source_meals := 0
	var unsaturated_fat_source_meals := 0
	var whole_grain_meals := 0
	var added_sugar_meals := 0
	var high_sodium_meals := 0
	var fried_meals := 0
	var unique_food_ids: Dictionary = {}

	for record in records:
		if bool(record.get("skipped", false)):
			skipped_meals += 1
			continue
		eaten_meals += 1
		for food_id in record.get("food_ids", []):
			unique_food_ids[String(food_id)] = true
		var groups: Array = record.get("food_groups", [])
		var nutrients: Array = record.get("nutrient_tags", [])
		var limits: Array = record.get("limit_tags", [])
		grain_meals += 1 if groups.has("grains_tubers") else 0
		vegetable_meals += 1 if groups.has("vegetables") else 0
		fruit_meals += 1 if groups.has("fruits") else 0
		animal_food_meals += 1 if _has_any(groups, ANIMAL_FOOD_GROUPS) else 0
		dairy_meals += 1 if groups.has("dairy") else 0
		soy_meals += 1 if groups.has("soy_products") else 0
		nuts_meals += 1 if groups.has("nuts_seeds") else 0
		carbohydrate_source_meals += 1 if nutrients.has("carbohydrate_source") else 0
		fiber_source_meals += 1 if nutrients.has("dietary_fiber_source") else 0
		high_quality_protein_meals += 1 if nutrients.has("high_quality_protein_source") else 0
		calcium_source_meals += 1 if nutrients.has("calcium_source") else 0
		unsaturated_fat_source_meals += 1 if nutrients.has("unsaturated_fatty_acid_source") else 0
		whole_grain_meals += 1 if nutrients.has("whole_grain") else 0
		added_sugar_meals += 1 if limits.has("added_sugar") else 0
		high_sodium_meals += 1 if limits.has("high_sodium") else 0
		fried_meals += 1 if limits.has("fried") else 0

	var metrics := {
		"expected_meals": EXPECTED_MEALS,
		"eaten_meals": eaten_meals,
		"skipped_meals": skipped_meals,
		"unique_foods": unique_food_ids.size(),
		"grain_meals": grain_meals,
		"vegetable_meals": vegetable_meals,
		"fruit_meals": fruit_meals,
		"animal_food_meals": animal_food_meals,
		"dairy_meals": dairy_meals,
		"soy_meals": soy_meals,
		"nuts_meals": nuts_meals,
		"carbohydrate_source_meals": carbohydrate_source_meals,
		"fiber_source_meals": fiber_source_meals,
		"high_quality_protein_meals": high_quality_protein_meals,
		"calcium_source_meals": calcium_source_meals,
		"unsaturated_fat_source_meals": unsaturated_fat_source_meals,
		"whole_grain_meals": whole_grain_meals,
		"added_sugar_meals": added_sugar_meals,
		"high_sodium_meals": high_sodium_meals,
		"fried_meals": fried_meals,
	}
	var score := calculate_score(records)
	return {
		"metrics": metrics,
		"score": score,
		"rating": rating_for_score(score),
		"observation": _observation(metrics),
		"action": _next_action(metrics),
		"detail_text": _detail_text(metrics),
		"basis": (
			"规则小字：本局饮食信息参考《中国居民膳食指南（2022）》中的食物多样、"
			+ "合理搭配和规律进餐原则，只整理本局卡牌。卡牌出现不代表现实摄入量足够，"
			+ "也不用于现实健康判断。"
		),
	}


## Legacy gameplay compatibility only. New health guidance must not consume it.
static func calculate_score(records: Array[Dictionary]) -> int:
	return clamp(MealResolverScript.day_quality(records), 0, 100)


static func rating_for_score(_score: int) -> String:
	return "旧版结算记录（不作健康评价）"


static func _observation(metrics: Dictionary) -> String:
	var skipped := int(metrics["skipped_meals"])
	var vegetables := int(metrics["vegetable_meals"])
	if skipped > 0:
		var skipped_text := "一餐" if skipped == 1 else "%d 餐" % skipped
		return "今天有%s没吃。先把这件事记下来。" % skipped_text
	if vegetables < EXPECTED_MEALS:
		return "今天吃了 %d 餐，其中 %d 餐有蔬菜类食物出现。" % [
			int(metrics["eaten_meals"]),
			vegetables,
		]
	return "三餐都吃了，也都有蔬菜类食物出现。这里只记录出现，不判断份量。"


static func _next_action(metrics: Dictionary) -> String:
	if int(metrics["skipped_meals"]) > 0:
		return "明天要是排得开，先给吃饭留个空档；不用靠下一顿把没吃的‘补回来’。"
	if int(metrics["vegetable_meals"]) < EXPECTED_MEALS:
		return "下一顿要是窗口里正好有蔬菜，可以顺手换个搭配；水果还是单独算。"
	if int(metrics["fruit_meals"]) <= 0:
		return "下次碰见完整水果，可以按预算和口味拿一份；饮料不算水果卡。"
	if int(metrics["whole_grain_meals"]) <= 0:
		return "碰到标得清楚的全谷物主食时，可以拿来换换口味；看不清配方就先不盖章。"
	if int(metrics["dairy_meals"]) <= 0:
		return "奶类卡今天没出现。明天货架上若有，再按预算和口味决定要不要拿。"
	if int(metrics["soy_meals"]) <= 0:
		return "大豆制品今天没碰见；下次窗口里若有，可以拿来换换组合。"
	var limited := (
		int(metrics["added_sugar_meals"])
		+ int(metrics["high_sodium_meals"])
		+ int(metrics["fried_meals"])
	)
	if limited >= 2:
		return "今天几张卡带着添加糖、高钠或油炸线索。别的卡不会把它们‘洗掉’，下次可以顺手比较做法。"
	return "明天继续照预算、时间和口味做选择，餐桌上换点新组合也不错。"


static func _detail_text(metrics: Dictionary) -> String:
	var limited_labels: Array[String] = []
	if int(metrics["added_sugar_meals"]) > 0:
		limited_labels.append("含添加糖选择 %d 餐" % int(metrics["added_sugar_meals"]))
	if int(metrics["high_sodium_meals"]) > 0:
		limited_labels.append("高钠选择 %d 餐" % int(metrics["high_sodium_meals"]))
	if int(metrics["fried_meals"]) > 0:
		limited_labels.append("油炸食品 %d 餐" % int(metrics["fried_meals"]))
	var limited_text := (
		"卡牌上没写到添加糖、高钠或油炸；这不等于一定没有"
		if limited_labels.is_empty()
		else "、".join(limited_labels)
	)
	return "\n".join([
		"三餐情况　吃了 %d/%d 餐" % [int(metrics["eaten_meals"]), EXPECTED_MEALS],
		"今天遇到　%d 种食物卡" % int(metrics["unique_foods"]),
		"",
		"餐盘线索",
		"主食 %d 顿｜蔬菜 %d 顿｜水果 %s" % [
			int(metrics["grain_meals"]),
			int(metrics["vegetable_meals"]),
			_present_text(int(metrics["fruit_meals"])),
		],
		"蛋/肉/鱼 %s｜奶类 %s｜大豆制品 %s｜坚果 %s" % [
			_present_text(int(metrics["animal_food_meals"])),
			_present_text(int(metrics["dairy_meals"])),
			_present_text(int(metrics["soy_meals"])),
			_present_text(int(metrics["nuts_meals"])),
		],
		"",
		"卡牌资料线索",
		"主食来源 %d 顿｜膳食纤维来源 %d 顿" % [
			int(metrics["carbohydrate_source_meals"]),
			int(metrics["fiber_source_meals"]),
		],
		"蛋白质来源 %d 顿｜钙来源 %s" % [
			int(metrics["high_quality_protein_meals"]),
			_present_text(int(metrics["calcium_source_meals"])),
		],
		"全谷物 %s｜不饱和脂肪酸来源 %s" % [
			_present_text(int(metrics["whole_grain_meals"])),
			_present_text(int(metrics["unsaturated_fat_source_meals"])),
		],
		"需留意的卡牌线索：%s" % limited_text,
	])


static func _has_any(values: Array, wanted: Array) -> bool:
	for value in wanted:
		if values.has(value):
			return true
	return false


static func _present_text(count: int) -> String:
	return "碰见过" if count > 0 else "没碰见"
