class_name CampusResourcePlan
extends RefCounted

const MEALS := ["breakfast", "lunch", "dinner"]
const NAMES := {"breakfast": "早餐", "lunch": "午餐", "dinner": "晚餐"}
const PHASES := ["breakfast_source", "breakfast", "breakfast_action", "lunch_source", "lunch", "lunch_action", "dinner_source", "dinner", "dinner_action", "sleep", "summary", "ending"]


static func initial_state() -> Dictionary:
	return {"version": 1, "stock": [], "budgets": []}


static func point(day: int, phase: String) -> int:
	return day * 12 + PHASES.find(phase)


static func upcoming(day: int, phase: String) -> Dictionary:
	if phase in ["ending", "sleep", "summary", "dinner_action"]: return {"day": day + 1, "meal": "breakfast"} if day < 7 and phase != "ending" else {}
	if phase == "breakfast_action": return {"day": day, "meal": "lunch"}
	if phase == "lunch_action": return {"day": day, "meal": "dinner"}
	return {"day": day, "meal": phase.trim_suffix("_source")}


static func _next_id(rows: Array) -> int:
	var result := 1
	for row in rows: result = maxi(result, int(row["id"]) + 1)
	return result


static func quantity(value: Dictionary, inventory: Dictionary, id: String, day: int, meal: String) -> int:
	var held := 0
	for row in value.get("stock", []):
		if row["status"] == "pending" and row["food_id"] == id and (row["day"] > day or (row["day"] == day and MEALS.find(row["meal"]) > MEALS.find(meal))): held += 1
	return maxi(0, int(inventory.get(id, 0)) - held)


static func reserve_stock(value: Dictionary, inventory: Dictionary, id: String, day: int, meal: String, made_day: int, phase: String) -> bool:
	if value.get("stock", []).size() >= 64 or meal not in MEALS or phase not in PHASES or phase == "ending" or day not in range(made_day, mini(7, made_day + 1) + 1) or point(day, meal) < point(made_day, phase): return false
	var reserved := 0
	var portions := 0
	for row in value["stock"]:
		if row["status"] == "pending" and row["day"] == day and row["meal"] == meal: portions += 1
		if row["status"] == "pending" and row["food_id"] == id:
			reserved += 1
			if row["day"] == day and row["meal"] == meal: return false
	if int(inventory.get(id, 0)) <= reserved or portions >= 2: return false
	value["stock"].append({"id": _next_id(value["stock"]), "day": day, "meal": meal, "food_id": id, "created_day": made_day, "created_phase": phase, "status": "pending", "resolved_day": 0, "resolved_phase": "", "actual_source": "", "actual_foods": []})
	return true


static func reserved_here(value: Dictionary, day: int, meal: String) -> Array[String]:
	var result: Array[String] = []
	for row in value.get("stock", []):
		if row["status"] == "pending" and row["day"] == day and row["meal"] == meal and not result.has(row["food_id"]): result.append(String(row["food_id"]))
	return result


static func release_stock(value: Dictionary, id: int, day: int, phase: String) -> bool:
	if phase == "ending": return false
	for row in value.get("stock", []):
		if row["id"] == id and row["status"] == "pending":
			row["status"] = "released"
			row["resolved_day"] = day
			row["resolved_phase"] = phase
			return true
	return false


static func settle(value: Dictionary, day: int, meal: Dictionary) -> void:
	for row in value.get("stock", []):
		if row["status"] != "pending" or row["day"] != day or row["meal"] != meal["phase"]: continue
		row["status"] = "skipped" if meal["skipped"] else ("used" if meal.get("source_id") == "dorm_storage" and meal["food_ids"].has(row["food_id"]) else "changed")
		row["resolved_day"] = day
		row["resolved_phase"] = meal["phase"]
		row["actual_source"] = meal.get("source_id", "")
		row["actual_foods"] = meal["food_ids"].duplicate()


static func locked_money(value: Dictionary, day: int) -> int:
	var total := 0
	for row in value.get("budgets", []):
		if not row["released"] and day < row["start_day"]: total += int(row["amount"])
	return total


static func balance(value: Dictionary, cash: int, day: int) -> int:
	return maxi(0, cash - locked_money(value, day))


static func reserve_budget(value: Dictionary, amount: int, days: int, day: int, phase: String, cash: int) -> bool:
	if amount <= 0 or amount > cash or days not in [1, 2] or day + days > 7 or phase not in PHASES or phase == "ending" or value.get("budgets", []).size() >= 32: return false
	for row in value["budgets"]:
		if not row["released"] and row["start_day"] + row["days"] - 1 >= day + 1: return false
	value["budgets"].append({"id": _next_id(value["budgets"]), "created_day": day, "created_phase": phase, "start_day": day + 1, "days": days, "amount": amount, "released": false, "release_day": 0, "release_phase": ""})
	return true


static func release_budget(value: Dictionary, id: int, day: int, phase: String) -> bool:
	if phase == "ending": return false
	for row in value.get("budgets", []):
		if row["id"] == id and not row["released"]:
			row["released"] = true
			row["release_day"] = day
			row["release_phase"] = phase
			return true
	return false


static func meals(p: Dictionary) -> Array:
	var result: Array = []
	var today_saved := false
	for record in p.get("run_history", []):
		if record.get("day") == p["day"]: today_saved = true
		for meal in record.get("meals", []):
			var copy: Dictionary = meal.duplicate(true)
			copy["_day"] = record["day"]
			result.append(copy)
	if not today_saved:
		for meal in p.get("today_meal_records", []):
			var copy: Dictionary = meal.duplicate(true)
			copy["_day"] = p["day"]
			result.append(copy)
	return result


static func spent(row: Dictionary, p: Dictionary) -> int:
	var end := point(row["start_day"] + row["days"] - 1, "ending")
	if row["released"]: end = mini(end, point(row["release_day"], row["release_phase"]) - 1)
	var start := point(row["start_day"], "breakfast_source")
	var total := 0
	for meal in meals(p):
		if point(meal["_day"], meal["phase"]) in range(start, end + 1): total += int(meal.get("total_cost", 0))
	var records: Array = p.get("run_history", []).duplicate()
	if records.is_empty() or records.back().get("day") != p["day"]: records.append({"day": p["day"], "actions": p.get("today_action_records", [])})
	for record in records:
		for action in record.get("actions", []):
			var phase: String = action.get("feedback_trace", {}).get("phase", "")
			if phase in PHASES and point(record["day"], phase) in range(start, end + 1): total += int(action.get("cost", 0))
	return total


static func stock_text(row: Dictionary, foods: Dictionary) -> String:
	var prefix := "第%d天%s留1份%s" % [row["day"], NAMES[row["meal"]], foods.get(row["food_id"], {}).get("name", row["food_id"])]
	return prefix + {"pending": " · 等这餐取用", "released": " · 已解除预留", "used": " · 这餐已取用", "changed": " · 这餐换了安排，未取用", "skipped": " · 这餐跳过，未取用"}.get(row["status"], "")


static func budget_text(row: Dictionary, p: Dictionary) -> String:
	var interval := "第%d天" % row["start_day"] if row["days"] == 1 else "第%d–%d天" % [row["start_day"], row["start_day"] + row["days"] - 1]
	var total := spent(row, p)
	if row["released"]: return "%s原留¥%d · 已解除，解除前花了¥%d" % [interval, row["amount"], total]
	if p.get("phase") == "ending" and int(p["day"]) < int(row["start_day"]): return "%s原留¥%d · 本局结束，预留未启用" % [interval, row["amount"]]
	if int(p["day"]) < int(row["start_day"]): return "%s留¥%d · 到这天可以使用" % [interval, row["amount"]]
	return "%s预算¥%d · 已花¥%d%s" % [interval, row["amount"], total, "，超出¥%d" % (total - row["amount"]) if total > int(row["amount"]) else "，计划内还余¥%d" % (row["amount"] - total)]


static func notice(value: Dictionary, foods: Dictionary, p: Dictionary, meal: String) -> String:
	var reserved := reserved_here(value, p["day"], meal)
	if not reserved.is_empty():
		var names: Array[String] = []
		for id in reserved: names.append(String(foods.get(id, {}).get("name", id)))
		return "这餐留了%s，去宿舍存粮可以取用。" % "、".join(names)
	var held := locked_money(value, p["day"])
	if held > 0: return "给之后留了¥%d，这餐可用¥%d。" % [held, balance(value, p["state"]["balance"], p["day"])]
	for row in value.get("budgets", []):
		if not row["released"] and p["day"] in range(row["start_day"], row["start_day"] + row["days"]): return budget_text(row, p)
	return ""


static func day_notes(value: Dictionary, foods: Dictionary, p: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for row in value.get("stock", []):
		if row["resolved_day"] == p["day"]: result.append(stock_text(row, foods))
	for row in value.get("budgets", []):
		if row["created_day"] == p["day"] or row["release_day"] == p["day"] or p["day"] in range(row["start_day"], row["start_day"] + row["days"]): result.append(budget_text(row, p))
	return result


static func valid(value: Variant, p: Dictionary, foods: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 3 or value.get("version") != 1 or not value.get("stock") is Array or value["stock"].size() > 64 or not value.get("budgets") is Array or value["budgets"].size() > 32: return false
	var all_meals := meals(p)
	var held := {}
	var keys := {}
	var portions := {}
	var ids := {}
	for row in value["stock"]:
		if not row is Dictionary or row.size() != 11 or typeof(row.get("id")) != TYPE_INT or row["id"] <= 0 or ids.has(row["id"]) or not foods.has(row.get("food_id")) or not foods[row["food_id"]].get("sources", []).has("dorm_storage"): return false
		ids[row["id"]] = true
		if typeof(row.get("created_day")) != TYPE_INT or row["created_day"] not in range(1, p["day"] + 1) or row.get("created_phase") not in PHASES or typeof(row.get("day")) != TYPE_INT or row["day"] not in range(row["created_day"], mini(7, row["created_day"] + 1) + 1) or row.get("meal") not in MEALS or point(row["day"], row["meal"]) < point(row["created_day"], row["created_phase"]): return false
		if row.get("status") not in ["pending", "released", "used", "changed", "skipped"] or typeof(row.get("resolved_day")) != TYPE_INT or typeof(row.get("resolved_phase")) != TYPE_STRING or typeof(row.get("actual_source")) != TYPE_STRING or not row.get("actual_foods") is Array: return false
		var actual := {}
		for meal in all_meals:
			if meal["_day"] == row["day"] and meal["phase"] == row["meal"]: actual = meal
		if row["status"] == "pending":
			var key := "%d:%s:%s" % [row["day"], row["meal"], row["food_id"]]
			if keys.has(key) or not actual.is_empty() or point(row["day"], row["meal"]) < point(p["day"], p["phase"]) or row["resolved_day"] != 0 or row["resolved_phase"] != "" or row["actual_source"] != "" or not row["actual_foods"].is_empty(): return false
			keys[key] = true
			var meal_key := "%d:%s" % [row["day"], row["meal"]]
			portions[meal_key] = int(portions.get(meal_key, 0)) + 1
			if portions[meal_key] > 2: return false
			held[row["food_id"]] = int(held.get(row["food_id"], 0)) + 1
		elif row["status"] == "released":
			if row["resolved_phase"] not in PHASES or point(row["resolved_day"], row["resolved_phase"]) not in range(point(row["created_day"], row["created_phase"]), point(p["day"], p["phase"]) + 1) or row["actual_source"] != "" or not row["actual_foods"].is_empty(): return false
		else:
			if actual.is_empty() or row["resolved_day"] != row["day"] or row["resolved_phase"] != row["meal"] or row["actual_source"] != actual.get("source_id", "") or row["actual_foods"] != actual["food_ids"]: return false
			var status := "skipped" if actual["skipped"] else ("used" if actual.get("source_id") == "dorm_storage" and actual["food_ids"].has(row["food_id"]) else "changed")
			if status != row["status"]: return false
	for id in held:
		if held[id] > int(p.get("dorm_inventory", {}).get(id, 0)): return false
	ids.clear()
	var intervals: Array = []
	for row in value["budgets"]:
		if not row is Dictionary or row.size() != 9: return false
		for field in ["id", "created_day", "start_day", "days", "amount", "release_day"]:
			if typeof(row.get(field)) != TYPE_INT: return false
		if row["id"] <= 0 or ids.has(row["id"]) or row["created_day"] not in range(1, p["day"] + 1) or row.get("created_phase") not in PHASES or row["start_day"] != row["created_day"] + 1 or row["days"] not in [1, 2] or row["start_day"] + row["days"] > 8 or row["amount"] not in range(1, 1000) or typeof(row.get("released")) != TYPE_BOOL or typeof(row.get("release_phase")) != TYPE_STRING: return false
		ids[row["id"]] = true
		if row["released"]:
			if row["release_phase"] not in PHASES or point(row["release_day"], row["release_phase"]) not in range(point(row["created_day"], row["created_phase"]), point(p["day"], p["phase"]) + 1): return false
		else:
			if row["release_day"] != 0 or row["release_phase"] != "": return false
			for previous in intervals:
				if row["start_day"] <= previous[1] and row["start_day"] + row["days"] - 1 >= previous[0]: return false
			intervals.append([row["start_day"], row["start_day"] + row["days"] - 1])
	return locked_money(value, p["day"]) <= int(p["state"]["balance"])
