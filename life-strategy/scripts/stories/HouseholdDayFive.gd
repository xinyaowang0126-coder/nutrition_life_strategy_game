extends RefCounted

const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const SOFT_FOODS := ["soft_apple", "steamed_egg", "soft_tofu_greens", "millet_porridge"]
const MEALS := ["breakfast", "lunch", "dinner"]
const TOKENS := ["invitation", "breakfast", "lunch", "dinner"]
const NEED := "周阿姨：‘硬苹果嚼着费劲，我愿意试试切小或煮软。蒸蛋、炖豆腐也想尝尝，饭还是按自己的口味挑。’"


static func initial_state(legacy: bool = false) -> Dictionary:
	return {"version": 1, "intro": "legacy" if legacy else "pending", "intent": "", "pending": "", "acknowledged": [], "active": {}, "invite_declined": false}


static func methods(ids: Array, names: Array, foods: Dictionary, source: String, recipe: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(ids.size()):
		var id: String = ids[index]
		var row := {"id": id, "name": names[index], "method": "", "texture": "", "basis": "unrecorded"}
		for item in recipe.get("recipes", []):
			if item.get("food_id") == id and typeof(item.get("method")) == TYPE_STRING and typeof(item.get("texture")) == TYPE_STRING:
				row["method"] = String(item.get("method", ""))
				row["texture"] = String(item.get("texture", ""))
				row["basis"] = "recipe"
		if row["basis"] == "unrecorded" and source != "home_fridge":
			row["method"] = String(foods.get(id, {}).get("method", ""))
			row["texture"] = String(foods.get(id, {}).get("texture", ""))
			row["basis"] = "menu"
		result.append(row)
	return result


static func is_adapted(method: Dictionary) -> bool:
	return method["id"] in SOFT_FOODS and method["basis"] != "unrecorded" and method["texture"] in ["细软", "柔软"] and not method["method"].is_empty()


static func shared(meal: Dictionary) -> bool:
	if meal.get("skipped", false) or meal.get("phase") != "dinner" or meal.get("source_id") not in ["home_kitchen", "community_canteen"]: return false
	if not meal.get("companions", []) is Array: return false
	for companion in meal.get("companions", []):
		if companion is Dictionary and companion.get("id") == "chen_friend": return true
	return false


static func freeze(meal: Dictionary, foods: Dictionary) -> Dictionary:
	var recorded := methods(meal["food_ids"], meal["food_names"], foods, meal["source_id"], meal.get("recipe_facts", {}))
	var adapted: Array[String] = []
	for row in recorded:
		if is_adapted(row): adapted.append(row["name"])
	var line := "周阿姨：‘这顿是%s，就按我自己选的吃。’" % "、".join(meal["food_names"])
	if not adapted.is_empty():
		line = "周阿姨：‘今天这份%s，我吃着顺口。’" % "、".join(adapted)
	elif meal["food_ids"].has("apple"):
		line = "周阿姨：‘苹果我还想试试切小或煮软，下次再选。’"
	elif recorded.any(func(row: Dictionary) -> bool: return row["basis"] == "unrecorded"):
		line = "周阿姨：‘这顿是%s，我慢慢吃，下次再挑想试的做法。’" % "、".join(meal["food_names"])
	var together := shared(meal)
	var venue := ("home" if meal["source_id"] == "home_kitchen" else "community") if together else ""
	if together:
		line += "\n老陈：‘%s，正好聊聊周日要唱的歌。’" % ("饭上桌了" if venue == "home" else "找到一张小桌了")
	return {"version": 1, "day": 5, "phase": meal["phase"], "food_ids": meal["food_ids"].duplicate(), "food_names": meal["food_names"].duplicate(), "methods": recorded, "response": line, "shared": together, "venue": venue}


static func invitation_reply(history: Array) -> String:
	for row in history:
		if row.get("kind") == "invitation" and row.get("day") == 5:
			return "老陈：‘好，%s，晚饭见。’\n\n约定已经记下，真正同桌吃饭后才记为完成。" % ("今晚去你家" if row["plan"]["venue"] == "home" else "今晚在家常小馆见")
	return ""


static func acknowledge(state: Dictionary, token: String) -> bool:
	if state.get("pending") != token or token not in TOKENS or state["acknowledged"].has(token): return false
	state["acknowledged"].append(token)
	state["pending"] = ""
	return true


static func recap(meals: Array, state: Dictionary, history: Array) -> Dictionary:
	var adapted: Array[String] = []
	var eaten := 0
	var unknown := 0
	var dinner := {}
	var together := false
	for meal in meals:
		if meal.get("phase") == "dinner": dinner = meal
		if meal.get("skipped", false) or meal.get("food_ids", []).is_empty(): continue
		eaten += 1
		together = together or shared(meal)
		var experience: Dictionary = meal.get("day_five_experience", {})
		if experience.is_empty() or experience.get("methods", []).any(func(row: Dictionary) -> bool: return row["basis"] == "unrecorded"): unknown += 1
		for row in experience.get("methods", []):
			if is_adapted(row) and not adapted.has(row["name"]): adapted.append(row["name"])
	var invited := history.any(func(row: Dictionary) -> bool: return row.get("kind") == "invitation" and row.get("day") == 5)
	var missed := history.any(func(row: Dictionary) -> bool: return row.get("kind") == "missed" and row.get("day") == 5)
	var lines: Array[String] = []
	if not adapted.is_empty(): lines.append("今天选了%s，做法按菜单或配方记录保留。" % "、".join(adapted))
	elif eaten > 0: lines.append("今天照实际选择吃了%d餐。" % eaten)
	else: lines.append("今天没有已确认的进餐，不生成食后体验。")
	if unknown > 0: lines.append("部分做法未记录。")
	if together:
		lines.append("晚饭%s和老陈同桌，约定实际完成。" % ("在家" if dinner.get("source_id") == "home_kitchen" else "在家常小馆"))
	elif missed:
		lines.append("晚饭没吃，今天的约定没有完成。" if dinner.get("skipped", false) else "晚饭改选%s，没有同桌记录。" % dinner.get("source_name", "别处"))
	elif not dinner.is_empty() and not dinner.get("skipped", false):
		lines.append("今天晚饭自己安排。")
	elif invited: lines.append("已经约过晚饭，但还没有实际同桌记录。")
	return {"text": "\n".join(lines), "adapted_foods": adapted, "eaten": eaten, "unrecorded_methods": unknown, "shared": together, "invited": invited, "missed": missed, "chose_own_dinner": bool(state.get("invite_declined", false))}


static func valid_experience(value: Variant, meal: Dictionary, day: int) -> bool:
	if not value is Dictionary or value.size() != 9 or value.get("version") != 1 or typeof(value["version"]) != TYPE_INT or value.get("day") != 5 or (day > 0 and day != 5): return false
	if meal.get("skipped", false) or value.get("phase") != meal.get("phase") or value["phase"] not in MEALS or value.get("food_ids") != meal.get("food_ids") or value.get("food_names") != meal.get("food_names"): return false
	if value["food_names"].size() != value["food_ids"].size(): return false
	if typeof(value.get("response")) != TYPE_STRING or value["response"].is_empty() or value["response"].length() > 1000 or typeof(value.get("shared")) != TYPE_BOOL or value["shared"] != shared(meal): return false
	var venue := ("home" if meal["source_id"] == "home_kitchen" else "community") if value["shared"] else ""
	if value.get("venue") != venue or not value.get("methods") is Array or value["methods"].size() != value["food_ids"].size(): return false
	for index in range(value["methods"].size()):
		var row: Variant = value["methods"][index]
		if not row is Dictionary or row.size() != 5 or row.get("id") != value["food_ids"][index] or row.get("name") != value["food_names"][index] or row.get("basis") not in ["recipe", "menu", "unrecorded"]: return false
		for key in ["method", "texture"]:
			if typeof(row.get(key)) != TYPE_STRING or row[key].length() > 160: return false
		if row["basis"] == "unrecorded" and (row["method"] != "" or row["texture"] != ""): return false
		if row["basis"] == "menu" and meal["source_id"] == "home_fridge": return false
		if row["basis"] == "recipe":
			var recipes: Array = meal.get("recipe_facts", {}).get("recipes", [])
			if not recipes.any(func(item: Dictionary) -> bool: return item.get("food_id") == row["id"] and item.get("method") == row["method"] and item.get("texture") == row["texture"]): return false
	return true


static func valid_state(value: Variant, household: bool, p: Dictionary, foods: Dictionary) -> bool:
	if not value is Dictionary: return false
	if not household: return value.is_empty()
	if value.size() != 7 or value.get("version") != 1 or typeof(value["version"]) != TYPE_INT or value.get("intro") not in ["pending", "details", "done", "legacy"] or typeof(value.get("invite_declined")) != TYPE_BOOL: return false
	if value["intro"] == "done":
		if value.get("intent") not in ["look", "own"] or p["day"] < 5: return false
	elif value.get("intent") != "": return false
	if value["intro"] == "details" and (p["day"] != 5 or p["phase"] != "breakfast_source" or p["new_day_pending"]): return false
	if not value.get("acknowledged") is Array or value["acknowledged"].size() > 4 or value.get("pending") not in ["", "invitation", "breakfast", "lunch", "dinner"] or not value.get("active") is Dictionary: return false
	if p["day"] < 5 and (not value["acknowledged"].is_empty() or value["pending"] != "" or not value["active"].is_empty()): return false
	if value["invite_declined"] and p["day"] < 5: return false
	var meals: Array = p["today_meal_records"] if p["day"] == 5 else []
	for row in p["run_history"]:
		if row.get("day") == 5: meals = row["meals"]
	for row in p["shared_meal"]["history"]:
		if not row is Dictionary: return false
	var invitation: bool = p["shared_meal"]["history"].any(func(row: Dictionary) -> bool: return row.get("kind") == "invitation" and row.get("day") == 5)
	var tokens := {}
	if invitation: tokens["invitation"] = true
	for meal in meals:
		if meal.has("day_five_experience") and not meal.get("skipped", false): tokens[meal["phase"]] = true
	var seen := {}
	for token in value["acknowledged"]:
		if not tokens.has(token) or seen.has(token): return false
		seen[token] = true
	var pending: String = value["pending"]
	if not pending.is_empty():
		if p["day"] != 5 or p["new_day_pending"] or not tokens.has(pending) or seen.has(pending): return false
		if p["phase"] != ("lunch_action" if pending == "invitation" else pending + "_action"): return false
	var active: Dictionary = value["active"]
	if value["intro"] == "details" and (not pending.is_empty() or not active.is_empty()): return false
	if active.is_empty(): return true
	if not pending.is_empty() or active.size() != 7 or active.get("day") != 5 or p["day"] != 5 or active.get("phase") != p["phase"] or active.get("source") != p["current_source_id"] or p["new_day_pending"]: return false
	if active.get("kind") not in ["source", "menu", "cooking"] or not active.get("ids") is Array or not active.get("plan") is Dictionary: return false
	if active["kind"] == "source": return p["phase"].ends_with("_source") and active["ids"].is_empty() and active["plan"].is_empty() and active.get("storage") == "eat_now"
	if p["phase"] not in MEALS or active["ids"] != p["selected_food_ids"]: return false
	if active["kind"] == "menu": return active["plan"].is_empty() and active.get("storage") == "eat_now"
	return p["current_source_id"] == "home_kitchen" and active.get("storage") in ["eat_now", "fridge", "counter"] and Facts.validate(active["plan"], active["ids"], foods)
