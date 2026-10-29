extends RefCounted

const Kitchen := preload("res://scripts/stories/KitchenStock.gd")
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const MEALS := ["breakfast", "lunch", "dinner"]
const NAMES := {"breakfast": "早餐", "lunch": "午餐", "dinner": "晚餐"}


static func initial_state(legacy: bool = false) -> Dictionary:
	return {"version": 1, "intro": "legacy" if legacy else "pending", "active": {}, "plans": [], "pending": "", "acknowledged": []}


static func target(meal: String) -> Dictionary:
	return {"day": 7 if meal == "dinner" else 6, "meal": {"breakfast": "lunch", "lunch": "dinner", "dinner": "breakfast"}[meal]}


static func entry(state: Dictionary, meal: String) -> Dictionary:
	for row in state["plans"]:
		if row["meal"] == meal: return row
	return {}


static func choose(state: Dictionary, meal: String, choice: String, batches: Array, hour: int) -> bool:
	if meal not in MEALS or choice not in ["stock", "later", "clear"]: return false
	var previous := entry(state, meal)
	if not previous.get("result", {}).is_empty(): return false
	if choice == "clear":
		if not previous.is_empty(): state["plans"].erase(previous)
		return true
	if not previous.is_empty() and previous["choice"] == choice: return true
	var available: Array[String] = []
	for batch in batches:
		if batch.get("quantity", 0) > 0 and batch.get("made_hour", hour) < hour and Kitchen.classify(batch, 6, hour) == "needs_reheat": available.append(batch["id"])
	var row := {"meal": meal, "choice": choice, "available_ids": available, "result": {}}
	if previous.is_empty(): state["plans"].append(row)
	else: state["plans"][state["plans"].find(previous)] = row
	return true


static func find_meal(records: Array, day: int, meal: String) -> Dictionary:
	for row in records:
		if row["day"] != day: continue
		for item in row["meals"]:
			if item["phase"] == meal: return item
	return {}


static func result_for(plan: Dictionary, records: Array) -> Dictionary:
	var next := target(plan["meal"])
	var actual := find_meal(records, next["day"], next["meal"])
	if actual.is_empty(): return {}
	var eligible: Array = plan["available_ids"].duplicate()
	var origin := find_meal(records, 6, plan["meal"])
	var preparation: Variant = origin.get("kitchen_transaction", {})
	if not preparation is Dictionary: preparation = {}
	var prepared: Variant = preparation.get("prepared", []) if origin.get("source_id") == "home_kitchen" and preparation.get("action") == "cook" else []
	if not prepared is Array: prepared = []
	for batch in prepared:
		if batch is Dictionary and batch.get("storage") == "fridge" and typeof(batch.get("id")) == TYPE_STRING and not eligible.has(batch["id"]): eligible.append(batch["id"])
	var used: Array[String] = []
	var transaction: Variant = actual.get("kitchen_transaction", {})
	if not transaction is Dictionary: transaction = {}
	var taken: Variant = transaction.get("batches", []) if actual.get("source_id") == "home_fridge" and transaction.get("action") == "reheat_and_eat" else []
	if not taken is Array: taken = []
	for batch in taken:
		if batch is Dictionary and batch.has("id") and batch.get("reheat_count") == 1 and eligible.has(batch["id"]) and not used.has(batch["id"]): used.append(batch["id"])
	var status := "changed"
	var text := "这餐改按眼下的条件安排，没有取用计划范围内的熟食。"
	if actual.get("skipped", false):
		status = "skipped"
		text = "这一餐没有进餐，不把计划记成已经取用。"
	elif plan["choice"] == "later":
		status = "stock_instead" if actual.get("source_id") == "home_fridge" else "arranged"
		text = "原先打算到时另安排，这餐实际从冰箱取用；熟食与常温存粮按各自记录保留。" if status == "stock_instead" else "原先打算到时另安排，这餐实际选了%s。" % actual.get("source_name", "当餐来源")
	elif not used.is_empty():
		status = "used" if used.size() == eligible.size() else "part_used"
		text = "这餐取用了计划范围内的%d样熟食，按保存记录彻底再热。%s" % [used.size(), "另有%d样没有在这餐取用。" % (eligible.size() - used.size()) if status == "part_used" else ""]
	elif eligible.is_empty():
		status = "not_prepared"
		text = "原先想先用留存，但没有对应的冷藏熟食记录；这餐按实际选择保留。"
	return {"status": status, "eligible_ids": eligible, "used_ids": used, "text": text}


static func resolve(state: Dictionary, records: Array) -> String:
	var token := ""
	for row in state["plans"]:
		if not row["result"].is_empty(): continue
		var result := result_for(row, records)
		if not result.is_empty():
			row["result"] = result
			token = row["meal"]
	return token


static func acknowledge(state: Dictionary, token: String) -> bool:
	if state["pending"] != token or token not in MEALS or state["acknowledged"].has(token): return false
	state["acknowledged"].append(token)
	state["pending"] = ""
	return true


static func notice(state: Dictionary, day: int, meal: String) -> String:
	for row in state["plans"]:
		if target(row["meal"]) == {"day": day, "meal": meal} and row["result"].is_empty():
			return "原计划：先看留存。" if row["choice"] == "stock" else "原计划：到时另安排。"
	return ""


static func recap(state: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	for meal in MEALS:
		var row := entry(state, meal)
		if row.is_empty(): continue
		var next := target(meal)
		var label := "第%d天%s" % [next["day"], NAMES[next["meal"]]]
		lines.append("%s：%s" % [label, row["result"]["text"] if not row["result"].is_empty() else ("计划先看留存，还没有实际取用记录。" if row["choice"] == "stock" else "计划到时另安排，还没有实际进餐记录。")])
	return {"text": "\n".join(lines) if not lines.is_empty() else "没有记下下一餐计划，备餐与取用仍按实际记录保留。", "plans": state["plans"].duplicate(true)}


static func records_for(p: Dictionary) -> Array:
	var records: Array = p["run_history"].duplicate(true)
	if not records.any(func(row: Dictionary) -> bool: return row["day"] == p["day"]): records.append({"day": p["day"], "meals": p["today_meal_records"]})
	return records


static func valid(value: Variant, household: bool, p: Dictionary, foods: Dictionary) -> bool:
	if not value is Dictionary: return false
	if not household: return value.is_empty()
	if value.size() != 6 or typeof(value.get("version")) != TYPE_INT or value["version"] != 1 or value.get("intro") not in ["pending", "details", "done", "legacy"]: return false
	if not value.get("active") is Dictionary or not value.get("plans") is Array or value["plans"].size() > 3 or not value.get("acknowledged") is Array or value["acknowledged"].size() > 3 or value.get("pending") not in ["", "breakfast", "lunch", "dinner"]: return false
	if p["day"] < 6 and (not value["active"].is_empty() or not value["plans"].is_empty() or not value["acknowledged"].is_empty() or value["pending"] != "" or value["intro"] in ["done", "details"]): return false
	if value["intro"] == "details" and (p["day"] != 6 or p["phase"] != "breakfast_source" or p["new_day_pending"]): return false
	var records := records_for(p)
	var seen := {}
	var phase_order := ["breakfast_source", "breakfast", "breakfast_action", "lunch_source", "lunch", "lunch_action", "dinner_source", "dinner", "dinner_action", "sleep", "summary", "ending"]
	for row in value["plans"]:
		if not row is Dictionary or row.size() != 4 or row.get("meal") not in MEALS or seen.has(row["meal"]) or row.get("choice") not in ["stock", "later"] or not row.get("available_ids") is Array or row["available_ids"].size() > 63 or not row.get("result") is Dictionary: return false
		seen[row["meal"]] = true
		if p["day"] == 6 and phase_order.find(p["phase"]) < MEALS.find(row["meal"]) * 3: return false
		var ids := {}
		var hour := 6 * 24 + int({"breakfast": 8, "lunch": 13, "dinner": 18}[row["meal"]])
		for id in row["available_ids"]:
			if typeof(id) != TYPE_STRING or ids.has(id): return false
			ids[id] = true
			var found := false
			for batch in p["kitchen"]["batches"]:
				if batch.get("id") != id or batch.get("made_hour", hour) >= hour: continue
				var at_planning: Dictionary = batch.duplicate(true)
				at_planning["reheat_count"] = 0
				if Kitchen.classify(at_planning, 6, hour) == "needs_reheat": found = true
			if not found: return false
		if row["result"] != result_for(row, records): return false
	var ack := {}
	for token in value["acknowledged"]:
		if token not in MEALS or ack.has(token) or entry(value, token).get("result", {}).is_empty(): return false
		ack[token] = true
	var pending: String = value["pending"]
	if pending != "":
		var result := entry(value, pending).get("result", {}) as Dictionary
		var next := target(pending)
		if result.is_empty() or ack.has(pending) or p["day"] != next["day"] or p["phase"] != next["meal"] + "_action" or p["new_day_pending"]: return false
	var active: Dictionary = value["active"]
	if value["intro"] == "details" and (pending != "" or not active.is_empty()): return false
	if active.is_empty(): return true
	if pending != "" or active.size() != 7 or active.get("day") != 6 or p["day"] != 6 or active.get("phase") != p["phase"] or active.get("source") != p["current_source_id"] or p["new_day_pending"] or active.get("kind") not in ["source", "menu", "cooking"] or not active.get("ids") is Array or not active.get("plan") is Dictionary: return false
	if active["kind"] == "source": return p["phase"].ends_with("_source") and active["ids"].is_empty() and active["plan"].is_empty() and active.get("storage") == "eat_now"
	if p["phase"] not in MEALS or active["ids"] != p["selected_food_ids"]: return false
	if active["kind"] == "menu": return active["plan"].is_empty() and active.get("storage") == "eat_now"
	return active["source"] == "home_kitchen" and active.get("storage") in ["eat_now", "fridge", "counter"] and Facts.validate(active["plan"], active["ids"], foods)
