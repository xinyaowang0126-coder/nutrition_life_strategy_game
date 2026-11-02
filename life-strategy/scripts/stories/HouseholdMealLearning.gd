extends RefCounted

const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const GROUPS := {"grains_tubers": "谷薯类", "vegetables": "蔬菜", "fruits": "水果", "eggs": "蛋类", "soy_products": "豆制品", "dairy": "奶类", "fish_seafood": "鱼虾类", "poultry_livestock": "禽畜肉类", "nuts_seeds": "坚果种子"}
const DAYS := [2, 3, 4]
const MEALS := ["breakfast", "lunch", "dinner"]
const VARIANTS := ["actual", "label_a", "label_b"]
const MAX_ENTRIES := 192
const MAX_ATTEMPTS := 32


static func initial_state() -> Dictionary:
	return {"version": 1, "serial": 0, "entries": [], "active": {}}


static func context(day: int, meal: String, source: String, ids: Array, foods: Dictionary, scope: String = "selection", recipe: Dictionary = {}) -> Dictionary:
	if day not in DAYS or meal not in MEALS or ids.is_empty() or ids.size() > 3: return {}
	var names: Array[String] = []
	var groups: Array[String] = []
	var seen := {}
	for id in ids:
		if not foods.has(id) or seen.has(id): return {}
		seen[id] = true
		names.append(String(foods[id]["name"]))
		for group in foods[id].get("food_groups", []):
			if GROUPS.has(group) and not groups.has(group): groups.append(group)
	groups.sort()
	return {"version": 1, "day": day, "meal": meal, "source": source, "scope": scope, "food_ids": ids.duplicate(), "food_names": names, "groups": groups, "recipe_facts": recipe.duplicate(true)}


static func key_for(c: Dictionary, variant: String) -> String:
	var ids: Array = c["food_ids"].duplicate()
	ids.sort()
	var recipe: Dictionary = c["recipe_facts"]
	var quantities := "unknown" if recipe.is_empty() else "%s/%s/%s" % [Facts.number(recipe["salt_g"]), Facts.number(recipe["soy_ml"]), Facts.number(recipe["white_sugar_added_g"])]
	return "%d:%s:%s:%s:%s:%s:%s" % [c["day"], c["meal"], c["source"], c["scope"], ",".join(ids), quantities, variant]


static func topic(day: int) -> String:
	return {2: "这一餐有什么", 3: "盐勺以外的钠", 4: "糖量怎样记"}.get(day, "这一餐")


static func composition(c: Dictionary) -> String:
	var names: Array[String] = []
	for group in c["groups"]: names.append(GROUPS[group])
	return "、".join(names) if not names.is_empty() else "配料未记录"


static func question(c: Dictionary, variant: String = "actual") -> Dictionary:
	var day: int = c["day"]
	var recipe: Dictionary = c["recipe_facts"]
	var title := topic(day)
	var body := ("这一餐：" if c["scope"] == "confirmed" else "餐盘预览：") + "、".join(c["food_names"])
	var prompt := ""
	var explanation := ""
	var choices: Array = []
	var correct := "known"
	if day == 2:
		body += "\n食物种类：" + composition(c) + "。"
		if variant != "actual": body = "练习菜单：面条、豆腐和番茄。" if variant == "label_a" else "练习菜单：米饭、鸡蛋和青菜。"
		prompt = "从这份菜单能看出什么？"
		choices = [{"id": "known", "text": "有哪些食物很清楚，吃得够不够还要看份量和全天安排"}, {"id": "enough", "text": "食物种类够多，一整天就吃够了"}, {"id": "nothing", "text": "份量不清楚，所以连有哪些食物也不知道"}]
		explanation = "能看出这一餐有哪些食物。吃得够不够，还要看份量和一整天的安排。清淡的饭菜也要搭配着吃。"
	elif day == 3:
		if variant != "actual":
			var per100 := 7000 if variant == "label_a" else 6000
			var amount := 10 if variant == "label_a" else 5
			var sodium := per100 * amount / 100
			body += "\n\n练习标签：每100毫升含钠%d毫克，用了%d毫升。" % [per100, amount]
			prompt = "这部分酱油带来多少钠？"
			correct = "measured"
			choices = [{"id": "per100", "text": "%d毫克钠" % per100}, {"id": "measured", "text": "%d毫克钠" % sodium}, {"id": "zero", "text": "零毫克钠"}]
			explanation = "%d × %d ÷ 100 = %d毫克钠。每100毫升的含量，乘上这次用了多少，再除以100。" % [per100, amount, sodium]
		elif not recipe.is_empty():
			body += "\n每人份盐%s克、酱油%s毫升。\n本关酱油标签：每100毫升钠7000毫克。" % [Facts.number(recipe["salt_g"]), Facts.number(recipe["soy_ml"])]
			prompt = "这份配方的盐和酱油，一共带来多少钠？"
			correct = "measured"
			var sodium: int = int(recipe["sodium_from_added_seasonings_mg"])
			choices = [{"id": "per100", "text": "直接记为7000毫克"}, {"id": "measured", "text": "%d毫克，来自盐和酱油" % sodium}, {"id": "whole", "text": "%d毫克，包括整餐的全部钠" % sodium}]
			explanation = "%s × 400 ＋ %s × 7000 ÷ 100 = %d毫克钠。这是盐和酱油中的钠；食材本身和其他未记录项目中的钠另算。" % [Facts.number(recipe["salt_g"]), Facts.number(recipe["soy_ml"]), sodium]
		else:
			prompt = "这餐的盐和酱油用量没有记录，调味钠该怎样记？"
			choices = [{"id": "known", "text": "用量未知，暂时不能计算"}, {"id": "zero", "text": "没有写用量，就记为零"}, {"id": "taste", "text": "只凭菜名或口味估一个准确数值"}]
			explanation = "用量没记下，调味钠就保留未知。做饭时可以看配方；外食也得知道用量，才能算得准。"
	else:
		if variant != "actual":
			var volume := 250 if variant == "label_a" else 300
			var per100 := 8 if variant == "label_a" else 6
			var total := volume * per100 / 100
			body += "\n\n练习标签：一瓶%d毫升，每100毫升总糖%d克，糖的来源没写清。\n这瓶饮料不在餐盘里。" % [volume, per100]
			prompt = "整瓶应怎样记录？"
			correct = "total_known"
			choices = [{"id": "added", "text": "%d克添加糖" % total}, {"id": "total_known", "text": "%d克总糖；添加糖量未知" % total}, {"id": "zero", "text": "没写添加糖，就当作没有糖"}]
			explanation = "%d × %d ÷ 100 = %d克总糖。算出来的是总糖。添加糖的来源没写清，含量未知；碳水化合物也要分开看。" % [per100, volume, total]
		elif not recipe.is_empty():
			var sugar := Facts.number(recipe["white_sugar_added_g"])
			body += "\n本次每人份另加白糖%s克。\n食材原有糖及其他添加糖没有记录。" % sugar
			prompt = "这份配方现在能确定什么？"
			choices = [{"id": "total", "text": "整餐总糖就是%s克" % sugar}, {"id": "known", "text": "另加白糖%s克；总糖与其他添加糖未知" % sugar}, {"id": "zero", "text": "没写的其他糖都可以记为零"}]
			explanation = "另加白糖%s克。总糖还包括食材原有的糖和其他添加糖，这部分未记录。" % sugar
		else:
			prompt = "这餐没有糖量与配方记录，应该怎样判断？"
			choices = [{"id": "zero", "text": "糖量记为零"}, {"id": "known", "text": "总糖和添加糖量都保留未知"}, {"id": "name", "text": "只凭食物名字就能算出糖量"}]
			explanation = "这餐的总糖和添加糖量未知。换张有明确数值的标签，再算整份含量。"
	if variant == "actual" and int(recipe.get("unrecorded_items", 0)) > 0:
		body += "\n另有%d项食物没有调味记录，下面先算有记录的部分。" % int(recipe["unrecorded_items"])
	return {"title": title, "body": body, "prompt": prompt, "choices": choices, "correct": correct, "explanation": explanation}


static func entry(journal: Dictionary, id: String) -> Dictionary:
	for row in journal.get("entries", []):
		if row["id"] == id: return row
	return {}


static func begin(journal: Dictionary, c: Dictionary, return_to: Dictionary, variant: String = "actual") -> bool:
	if c.is_empty() or variant not in VARIANTS: return false
	var key := key_for(c, variant)
	var row := {}
	for existing in journal["entries"]:
		if existing["key"] == key: row = existing
	if row.is_empty():
		if journal["entries"].size() >= MAX_ENTRIES: return false
		journal["serial"] += 1
		row = {"id": "lesson_%d" % journal["serial"], "key": key, "context": c.duplicate(true), "variant": variant, "attempts": [], "attempt_count": 0, "view_count": 0, "explanation_seen": false, "reference_seen": false, "skip_count": 0, "retry_count": 0}
		journal["entries"].append(row)
	row["view_count"] += 1
	journal["active"] = {"entry_id": row["id"], "page": "feedback" if row["attempt_count"] > 0 or row["explanation_seen"] else "question", "return": return_to.duplicate(true)}
	return true


static func answer(journal: Dictionary, choice: String) -> bool:
	if journal["active"].get("page") != "question": return false
	var row := entry(journal, journal["active"]["entry_id"])
	var q := question(row["context"], row["variant"])
	if not q["choices"].any(func(option: Dictionary) -> bool: return option["id"] == choice): return false
	row["attempt_count"] += 1
	row["attempts"].append({"choice": choice, "correct": choice == q["correct"], "after_help": row["explanation_seen"] or row["reference_seen"], "number": row["attempt_count"]})
	if row["attempts"].size() > MAX_ATTEMPTS: row["attempts"].remove_at(1)
	row["explanation_seen"] = true
	journal["active"]["page"] = "feedback"
	return true


static func explain(journal: Dictionary) -> bool:
	if journal["active"].get("page") != "question": return false
	var row := entry(journal, journal["active"]["entry_id"])
	row["explanation_seen"] = true
	row["skip_count"] += 1
	journal["active"]["page"] = "feedback"
	return true


static func retry(journal: Dictionary) -> bool:
	if journal["active"].get("page") != "feedback": return false
	entry(journal, journal["active"]["entry_id"])["retry_count"] += 1
	journal["active"]["page"] = "question"
	return true


static func close(journal: Dictionary) -> void:
	if journal.get("active", {}).is_empty(): return
	if journal["active"]["page"] == "question": entry(journal, journal["active"]["entry_id"])["skip_count"] += 1
	journal["active"] = {}


static func valid_context(c: Variant, foods: Dictionary, sources: Dictionary) -> bool:
	if not c is Dictionary or c.size() != 9 or c.get("version") != 1 or typeof(c["version"]) != TYPE_INT or c.get("day") not in DAYS or typeof(c["day"]) != TYPE_INT or c.get("meal") not in MEALS: return false
	if not sources.has(c.get("source")) or c.get("scope") not in ["selection", "stock_preview", "recipe_preview", "confirmed"]: return false
	if not _strings(c.get("food_ids"), 3) or c["food_ids"].is_empty() or not _strings(c.get("food_names"), 3) or c["food_names"].size() != c["food_ids"].size() or not _strings(c.get("groups"), GROUPS.size()): return false
	var seen := {}
	for id in c["food_ids"]:
		if not foods.has(id) or seen.has(id): return false
		seen[id] = true
	for group in c["groups"]:
		if not GROUPS.has(group): return false
	if not c.get("recipe_facts") is Dictionary: return false
	var facts: Dictionary = c["recipe_facts"]
	if not facts.is_empty() and not Facts.valid(facts): return false
	for recipe in facts.get("recipes", []):
		if not c["food_ids"].has(recipe["food_id"]): return false
	if c["scope"] == "recipe_preview" and (facts.is_empty() or c["source"] != "home_kitchen"): return false
	if c["scope"] == "stock_preview" and c["source"] != "home_fridge": return false
	if c["scope"] == "selection" and not facts.is_empty(): return false
	return true


static func valid_state(value: Variant, household: bool, current_day: int, phase: String, source: String, selected: Array, foods: Dictionary, sources: Dictionary) -> bool:
	if not value is Dictionary: return false
	if not household: return value.is_empty()
	if value.size() != 4 or typeof(value.get("version")) != TYPE_INT or value["version"] != 1 or not _count(value.get("serial")) or not value.get("entries") is Array or value["entries"].size() > MAX_ENTRIES or not value.get("active") is Dictionary: return false
	var ids := {}
	var keys := {}
	for row in value["entries"]:
		if not row is Dictionary or row.size() != 11 or not valid_context(row.get("context"), foods, sources) or row["context"]["day"] > current_day or row.get("variant") not in VARIANTS: return false
		var id: Variant = row.get("id")
		if typeof(id) != TYPE_STRING or not id.begins_with("lesson_") or not id.trim_prefix("lesson_").is_valid_int() or int(id.trim_prefix("lesson_")) < 1 or int(id.trim_prefix("lesson_")) > value["serial"] or ids.has(id): return false
		if row.get("key") != key_for(row["context"], row["variant"]) or keys.has(row["key"]): return false
		ids[id] = true
		keys[row["key"]] = true
		for key in ["attempt_count", "view_count", "skip_count", "retry_count"]:
			if not _count(row.get(key)): return false
		if row["view_count"] < 1 or typeof(row.get("explanation_seen")) != TYPE_BOOL or typeof(row.get("reference_seen")) != TYPE_BOOL or not row.get("attempts") is Array or row["attempts"].size() > MAX_ATTEMPTS or row["attempts"].size() > row["attempt_count"]: return false
		if row["attempts"].is_empty() != (row["attempt_count"] == 0): return false
		var q := question(row["context"], row["variant"])
		var number := 0
		var explained := false
		for attempt in row["attempts"]:
			if not attempt is Dictionary or attempt.size() != 4 or not _count(attempt.get("number")) or attempt["number"] <= number or attempt["number"] > row["attempt_count"]: return false
			if number == 0 and attempt["number"] != 1: return false
			number = attempt["number"]
			if typeof(attempt.get("correct")) != TYPE_BOOL or typeof(attempt.get("after_help")) != TYPE_BOOL or not q["choices"].any(func(option: Dictionary) -> bool: return option["id"] == attempt.get("choice")): return false
			if attempt["correct"] != (attempt["choice"] == q["correct"]) or (attempt["after_help"] and not (row["explanation_seen"] or row["reference_seen"])) or (explained and not attempt["after_help"]): return false
			explained = attempt["after_help"]
		if not row["attempts"].is_empty() and number != row["attempt_count"]: return false
	var active: Dictionary = value["active"]
	if active.is_empty(): return true
	if active.size() != 3 or not ids.has(active.get("entry_id")) or active.get("page") not in ["question", "feedback"] or not active.get("return") is Dictionary: return false
	var row := entry(value, active["entry_id"])
	if active["page"] == "feedback" and not row["explanation_seen"]: return false
	var back: Dictionary = active["return"]
	if back.size() != 7 or back.get("day") != current_day or back.get("phase") != phase or back.get("source") != source or back.get("kind") not in ["meal", "cooking"] or not back.get("plan") is Dictionary or not back.get("ids") is Array: return false
	if back["kind"] == "meal": return back["ids"].is_empty() and back["plan"].is_empty() and back.get("storage") == "eat_now"
	return source == "home_kitchen" and phase in MEALS and back["ids"] == selected and back.get("storage") in ["eat_now", "fridge", "counter"] and Facts.validate(back["plan"], back["ids"], foods) and row["context"]["scope"] == "recipe_preview" and _same_recipe(row["context"]["recipe_facts"], Facts.freeze(back["ids"], foods, back["plan"]))


static func _same_recipe(a: Dictionary, b: Dictionary) -> bool:
	var left := a.duplicate(true)
	var right := b.duplicate(true)
	var left_recipes := {}
	var right_recipes := {}
	for recipe in left.get("recipes", []): left_recipes[recipe["food_id"]] = recipe
	for recipe in right.get("recipes", []): right_recipes[recipe["food_id"]] = recipe
	left.erase("recipes")
	right.erase("recipes")
	return left == right and left_recipes == right_recipes


static func day_observation(meals: Array, day: int) -> Dictionary:
	if day not in DAYS: return {}
	var eaten := 0
	var groups: Array[String] = []
	var recorded := 0
	var sodium := 0.0
	var sugar := 0.0
	for meal in meals:
		if meal.get("skipped", false) or meal.get("food_ids", []).is_empty(): continue
		eaten += 1
		for group in meal.get("food_groups", []):
			if GROUPS.has(group) and not groups.has(group): groups.append(group)
		var recipe: Dictionary = meal.get("recipe_facts", {})
		if not recipe.is_empty() and Facts.valid(recipe):
			recorded += 1
			sodium += float(recipe["sodium_from_added_seasonings_mg"])
			sugar += float(recipe["white_sugar_added_g"])
	var text := "今天还没吃饭。"
	if eaten > 0:
		if day == 2:
			var names: Array[String] = []
			for group in groups: names.append(GROUPS[group])
			text = "今天吃了%s。份量未记录。" % "、".join(names) if not names.is_empty() else "今天的配料信息不全。"
		elif day == 3:
			text = "%d餐的调味钠小计%s毫克；食材本身和未记录项目中的钠未知。" % [recorded, Facts.number(sodium)] if recorded > 0 else "今天没记调味用量，调味钠未知。"
		else:
			text = "%d餐另加白糖共%s克；总糖和其他添加糖未知。" % [recorded, Facts.number(sugar)] if recorded > 0 else "今天没记糖量，总糖和添加糖未知。"
	var next_step: String = {2: "下一餐看看还有哪些原料可选。", 3: "下次做饭，再算算盐和酱油里的钠。", 4: "下次看标签，先算整份，再分清总糖和添加糖。"}[day]
	return {"day": day, "text": text, "next_step": next_step, "eaten": eaten, "recorded_recipes": recorded, "known_sodium_mg": sodium if recorded > 0 else null, "known_white_sugar_g": sugar if recorded > 0 else null}


static func _strings(value: Variant, maximum: int) -> bool:
	if not value is Array or value.size() > maximum: return false
	for item in value:
		if typeof(item) != TYPE_STRING or item.length() > 160: return false
	return true


static func _count(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= 100000
