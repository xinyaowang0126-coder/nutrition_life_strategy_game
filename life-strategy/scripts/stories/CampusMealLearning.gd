class_name CampusMealLearning
extends RefCounted

const PATH := "res://data/stories/campus_menu_facts.xml"
const MEALS := ["breakfast", "lunch", "dinner"]
const MEAL_NAMES := {"breakfast": "早餐", "lunch": "午餐", "dinner": "晚餐"}
static var _ingredients: Dictionary = {}
static var _items: Dictionary = {}


static func _load() -> void:
	if not _ingredients.is_empty(): return
	var parser := XMLParser.new()
	if parser.open(PATH) != OK: return
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT: continue
		var a := {}
		for i in parser.get_attribute_count(): a[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
		if parser.get_node_name() == "ingredient": _ingredients[a["id"]] = a["name"]
		elif parser.get_node_name() == "item": _items[a["food_id"]] = Array(String(a["ingredients"]).split(",", false))


static func facts(ids: Array) -> Dictionary:
	_load()
	var known: Array[String] = []
	var unknown: Array[String] = []
	for raw in ids:
		var id := String(raw)
		if not _items.has(id):
			unknown.append(id)
			continue
		for ingredient in _items[id]:
			if not known.has(ingredient): known.append(ingredient)
	return {"version": 1, "ingredients": known, "unrecorded": unknown}


static func valid_facts(value: Variant, ids: Array) -> bool:
	return value is Dictionary and value == facts(ids)


static func names(value: Dictionary) -> Array[String]:
	_load()
	var result: Array[String] = []
	for id in value.get("ingredients", []):
		if _ingredients.has(id): result.append(String(_ingredients[id]))
	return result


static func preview(ids: Array) -> String:
	if ids.is_empty(): return ""
	var f := facts(ids)
	var listed := names(f)
	var text := "主要原料：" + "、".join(listed.slice(0, 4)) if not listed.is_empty() else "菜单未写明原料"
	if listed.size() > 4: text += "等"
	if not f["unrecorded"].is_empty() and not listed.is_empty(): text += "；另有未写明项"
	return text


static func food_note(id: String) -> String:
	return preview([id]) + "。"


static func repetition_note(ids: Array) -> String:
	_load()
	var appearances := {}
	for id in ids:
		for ingredient in _items.get(id, []): appearances[ingredient] = int(appearances.get(ingredient, 0)) + 1
	for ingredient in appearances:
		if int(appearances[ingredient]) > 1: return "%s在%d项里出现，原料种类按同一种记。" % [_ingredients[ingredient], appearances[ingredient]]
	return ""


static func context(day: int, meal: String, source: String, ids: Array, foods: Dictionary) -> Dictionary:
	if day not in range(1, 8) or meal not in MEALS or ids.is_empty() or ids.size() > 3: return {}
	var labels: Array[String] = []
	var seen := {}
	for id in ids:
		if not foods.has(id) or seen.has(id): return {}
		seen[id] = true
		labels.append(String(foods[id]["name"]))
	return {"day": day, "meal": meal, "source": source, "food_ids": ids.duplicate(), "food_names": labels, "facts": facts(ids)}


static func valid_context(c: Variant, foods: Dictionary, sources: Dictionary) -> bool:
	if not c is Dictionary or c.size() != 6 or typeof(c.get("day")) != TYPE_INT or typeof(c.get("meal")) != TYPE_STRING or not sources.has(c.get("source")) or not c.get("food_ids") is Array: return false
	var canonical := context(c["day"], c["meal"], c["source"], c["food_ids"], foods)
	if canonical.is_empty() or not c.get("food_names") is Array or c["food_names"].size() != c["food_ids"].size() or c.get("facts") != canonical["facts"]: return false
	for label in c["food_names"]:
		if typeof(label) != TYPE_STRING or label.strip_edges().is_empty() or label.length() > 128: return false
	return true


static func question(c: Dictionary) -> Dictionary:
	var f: Dictionary = c["facts"]
	var listed := names(f)
	var body := "第%d天%s：%s\n%s。" % [c["day"], MEAL_NAMES[c["meal"]], "、".join(c["food_names"]), preview(c["food_ids"])]
	var correct := "known"
	var choices: Array = []
	var explanation := ""
	if not f["unrecorded"].is_empty():
		choices = [{"id": "zero", "text": "没写的原料就当没有"}, {"id": "known", "text": "写明的可以记录，未写明的还要看配料"}, {"id": "enough", "text": "菜名齐全，就能判断一整天吃够了"}]
		explanation = "先记录菜单写明的部分。其他原料要看配料表或问清楚，份量也要另外看。"
	else:
		var appearances := 0
		for id in c["food_ids"]: appearances += _items.get(id, []).size()
		if appearances > listed.size():
			choices = [{"id": "more", "text": "同一种原料每出现一次，就多算一种"}, {"id": "enough", "text": "原料重复了，这餐就不能吃"}, {"id": "known", "text": "相同原料只记一种，份量另外看"}]
			explanation = "这份菜单共写明%d种主要原料：%s。同一种原料出现在两道菜里，也还是同一种。份量未标，不能据此判断吃够没有。" % [listed.size(), "、".join(listed)]
		else:
			choices = [{"id": "known", "text": "能看出写明的原料，吃够没有还要看份量和全天安排"}, {"id": "enough", "text": "只要原料不同，一整天就吃够了"}, {"id": "zero", "text": "份量没写，所以连原料也不能记录"}]
			explanation = "菜单写明了%s。原料和份量是两件事，还要对照一整天实际吃了什么。" % "、".join(listed)
	return {"title": "看看这一餐", "body": body, "prompt": "这些信息应该怎样记录？", "choices": choices, "correct": correct, "explanation": explanation}


static func observation(day: int, meals: Array, history: Array) -> Dictionary:
	var skipped: Array[String] = []
	var today: Array[String] = []
	var appearances := {}
	var recorded := 0
	for meal in meals:
		if meal.get("skipped", false):
			skipped.append(String(MEAL_NAMES.get(meal.get("phase"), "餐次")))
			continue
		if not meal.has("campus_facts"): continue
		recorded += 1
		for ingredient in meal["campus_facts"]["ingredients"]:
			if not today.has(ingredient): today.append(ingredient)
			appearances[ingredient] = int(appearances.get(ingredient, 0)) + 1
	if not skipped.is_empty(): return {"text": "今天跳过了%s。" % "、".join(skipped), "next_step": "下一餐先定个去处，再看看菜单和余额。"}
	if recorded == 0: return {}
	_load()
	var previous: Array[String] = []
	for row in history:
		if int(row.get("day", 0)) >= day: continue
		for meal in row.get("meals", []):
			for ingredient in meal.get("campus_facts", {}).get("ingredients", []):
				if not previous.has(ingredient): previous.append(ingredient)
	if not previous.is_empty():
		var new_names: Array[String] = []
		for ingredient in today:
			if not previous.has(ingredient): new_names.append(String(_ingredients[ingredient]))
		if not new_names.is_empty(): return {"text": "和前几天的已记原料相比，今天新出现了%s。" % "、".join(new_names.slice(0, 3)), "next_step": "下次比较菜单时，也看看同一个原料是否换了菜名。"}
	for ingredient in appearances:
		if int(appearances[ingredient]) >= 2:
			return {"text": "今天%d餐里都有%s，原料种类按同一种记。" % [appearances[ingredient], _ingredients[ingredient]], "next_step": "下一餐可以对照原料，再决定保留还是换个搭配。"}
	var listed: Array[String] = []
	for ingredient in today: listed.append(String(_ingredients[ingredient]))
	return {"text": "今天菜单写明了%s。" % "、".join(listed.slice(0, 4)) if not listed.is_empty() else "今天所选餐食还没写明原料。", "next_step": "原料先照实记录，份量和调味用量另看。"}
