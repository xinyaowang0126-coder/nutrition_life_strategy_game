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
			"依据《中国居民膳食指南（2022）》的食物多样、合理搭配和规律进餐原则进行游戏化记录。"
			+ "“来源”仅表示相关食物在当日出现，不代表摄入量达到推荐值；本信息仅用于健康教育，"
			+ "不用于医学诊断或个体化营养处方。"
		),
	}


## Uses the same record quality consumed by gameplay rewards and penalties, so
## the educational summary cannot contradict the mechanical day result.
static func calculate_score(records: Array[Dictionary]) -> int:
	return clamp(MealResolverScript.day_quality(records), 0, 100)


static func rating_for_score(score: int) -> String:
	if score >= 80:
		return "餐盘完整"
	if score >= 66:
		return "搭配较好"
	if score >= 45:
		return "基本接住"
	return "优先补齐"


static func _observation(metrics: Dictionary) -> String:
	var skipped := int(metrics["skipped_meals"])
	var vegetables := int(metrics["vegetable_meals"])
	if skipped > 0:
		return "今日漏餐 %d 次，首先应关注进餐规律。" % skipped
	if vegetables < EXPECTED_MEALS:
		return "今日三餐规律，其中 %d 餐含蔬菜类食物。" % vegetables
	return "今日三餐规律，三餐均记录到蔬菜类食物。"


static func _next_action(metrics: Dictionary) -> String:
	if int(metrics["skipped_meals"]) > 0:
		return "明日可先保证三餐按时，不必在同一天集中补偿。"
	if int(metrics["vegetable_meals"]) < EXPECTED_MEALS:
		return "下一餐可增加蔬菜类食物；水果与蔬菜不宜相互替代。"
	if int(metrics["fruit_meals"]) <= 0:
		return "明日可安排新鲜水果；果汁和含糖饮料不能替代完整水果。"
	if int(metrics["whole_grain_meals"]) <= 0:
		return "可将一餐中的部分精制谷物替换为全谷物。"
	if int(metrics["dairy_meals"]) <= 0:
		return "可根据个人情况安排奶及奶制品，并结合食品标签选择。"
	if int(metrics["soy_meals"]) <= 0:
		return "可在后续餐次中轮换选择大豆及其制品，增加食物种类。"
	var limited := (
		int(metrics["added_sugar_meals"])
		+ int(metrics["high_sodium_meals"])
		+ int(metrics["fried_meals"])
	)
	if limited >= 2:
		return "今日添加糖、高钠或油炸食品出现较多，后续餐次可优先选择较清淡的烹调方式。"
	return "明日可继续保持规律进餐，并轮换谷薯、蔬果和蛋白质食物来源。"


static func _detail_text(metrics: Dictionary) -> String:
	var limited_labels: Array[String] = []
	if int(metrics["added_sugar_meals"]) > 0:
		limited_labels.append("含添加糖选择 %d 餐" % int(metrics["added_sugar_meals"]))
	if int(metrics["high_sodium_meals"]) > 0:
		limited_labels.append("高钠选择 %d 餐" % int(metrics["high_sodium_meals"]))
	if int(metrics["fried_meals"]) > 0:
		limited_labels.append("油炸食品 %d 餐" % int(metrics["fried_meals"]))
	var limited_text := "未记录到特别需要提示的项目" if limited_labels.is_empty() else "、".join(limited_labels)
	return "\n".join([
		"进餐规律：已进餐 %d/%d 餐" % [int(metrics["eaten_meals"]), EXPECTED_MEALS],
		"食物多样性：当前记录到 %d 种食物" % int(metrics["unique_foods"]),
		"食物类别分布：",
		"谷薯类 %d 餐｜蔬菜类 %d 餐｜水果类 %s" % [
			int(metrics["grain_meals"]),
			int(metrics["vegetable_meals"]),
			_present_text(int(metrics["fruit_meals"])),
		],
		"鱼禽肉蛋类 %s｜奶及奶制品 %s｜大豆及制品 %s｜坚果 %s" % [
			_present_text(int(metrics["animal_food_meals"])),
			_present_text(int(metrics["dairy_meals"])),
			_present_text(int(metrics["soy_meals"])),
			_present_text(int(metrics["nuts_meals"])),
		],
		"重点营养素来源：",
		"碳水化合物来源 %d 餐｜膳食纤维来源 %d 餐" % [
			int(metrics["carbohydrate_source_meals"]),
			int(metrics["fiber_source_meals"]),
		],
		"优质蛋白质来源 %d 餐｜钙来源 %s" % [
			int(metrics["high_quality_protein_meals"]),
			_present_text(int(metrics["calcium_source_meals"])),
		],
		"全谷物来源 %s｜不饱和脂肪酸来源 %s" % [
			_present_text(int(metrics["whole_grain_meals"])),
			_present_text(int(metrics["unsaturated_fat_source_meals"])),
		],
		"需关注的膳食因素：%s" % limited_text,
	])


static func _has_any(values: Array, wanted: Array) -> bool:
	for value in wanted:
		if values.has(value):
			return true
	return false


static func _present_text(count: int) -> String:
	return "有记录" if count > 0 else "未记录"
