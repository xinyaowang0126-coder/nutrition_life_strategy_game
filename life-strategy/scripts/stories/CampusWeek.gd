class_name CampusWeek
extends RefCounted

const Weekly := preload("res://scripts/systems/WeeklyEventService.gd")
const Learning := preload("res://scripts/stories/CampusMealLearning.gd")
const Journal := preload("res://scripts/stories/CampusStudyJournal.gd")
const Resources := preload("res://scripts/stories/CampusResourcePlan.gd")
const MEALS := ["breakfast", "lunch", "dinner"]
const MEAL_NAMES := {"breakfast": "早餐", "lunch": "午餐", "dinner": "晚餐"}
const BASIC_MENU := ["rice_plain", "oatmeal", "egg", "tofu", "greens", "tomato"]


static func initial_state(seed_value: int = 0, enabled: bool = true) -> Dictionary:
	return {"version": 2, "enabled": enabled, "variant": (seed_value & 1) if enabled else 0, "plans": [], "attempts": [], "active": {}, "journal": Journal.initial_state(), "resources": Resources.initial_state()}


static func migrate(value: Variant) -> Variant:
	if value is Dictionary and value.get("version") == 2: return value
	if not value is Dictionary or value.get("version") != 1 or value.size() != 6 or not value.get("attempts") is Array or not value.get("active") is Dictionary: return value
	var result: Dictionary = value.duplicate(true)
	result["version"] = 2
	result["journal"] = Journal.migrate(value["attempts"], value["active"]) if value.get("enabled", false) else Journal.initial_state()
	result["resources"] = Resources.initial_state()
	if result["active"].get("kind") == "study" and result["active"].get("context") is Dictionary:
		var row := Journal.entry(result["journal"], "composition", result["active"]["context"])
		if not row.is_empty() and row["help_seen"]: result["active"]["help"] = true
	return result


static func enabled(value: Dictionary) -> bool:
	return bool(value.get("enabled", false))


static func limited_meal(value: Dictionary) -> String:
	return "lunch" if int(value.get("variant", 0)) == 0 else "dinner"


static func peer_phase(value: Dictionary) -> String:
	return "lunch_action" if int(value.get("variant", 0)) == 0 else "dinner_action"


static func event(day: int, value: Dictionary) -> Dictionary:
	var result := Weekly.event_for_day(day)
	if not enabled(value): return result
	if day == 3:
		var meal: String = MEAL_NAMES[limited_meal(value)]
		result["title"] = "食堂窗口检修"
		result["summary"] = "今天%s食堂只开基础窗口，最多选2项；便利店和宿舍存粮照常。" % meal
		result["preview"] = "明天%s食堂只开基础窗口，最多选2项。可以提前留存粮，也可以换个来源。" % meal
		result["effect_text"] = "%s食堂：基础菜单、最多2项。" % meal
	elif day == 5:
		var time := "午饭后" if int(value.get("variant", 0)) == 0 else "晚饭后"
		result["title"] = "同学约了对题"
		result["summary"] = "同学约在%s对题。这个时段复习多加6进度、额外耗4精力；也可以自己安排。" % time
		result["preview"] = "明天%s能和同学对题：复习多加6进度，额外耗4精力，记得留精力和安排位。" % time
		result["effect_text"] = "仅%s：对题额外+6进度、-4精力。" % time
	elif day == 6:
		result["summary"] = "一整天有雨。外卖费涨2元，食堂/便利店额外耗2/1精力，散步也更费力。"
		result["preview"] = "明天有雨：外卖费涨2元，食堂/便利店额外耗2/1精力，散步多耗2精力。先看看存粮够不够。"
		result["effect_text"] = "配送费+2；食堂/便利店额外耗2/1精力。"
	if not result.is_empty(): result["campus_version"] = 1
	return result


static func preview(day: int, value: Dictionary) -> Dictionary:
	if not enabled(value): return Weekly.next_day_preview(day)
	if day >= 7: return {}
	var next := event(day + 1, value)
	if next.is_empty(): return Weekly.next_day_preview(day)
	return {"day": day + 1, "has_event": true, "event_id": next["id"], "title": next["title"], "summary": next["preview"], "tone": next.get("tone", "info")}


static func source(day: int, meal: String, id: String, base: Dictionary, value: Dictionary) -> Dictionary:
	var result := Weekly.apply_meal_source(day, id, base)
	if not enabled(value): return result
	if day == 3 and id == "cafeteria":
		result = base.duplicate(true)
		if meal == limited_meal(value):
			result["selection_limit"] = 2
			result["hand_size"] = 4
			result["rule_hint"] = String(result.get("rule_hint", "")) + "\n窗口检修，这餐只开基础菜单，最多选2项。"
	if day == 6 and id in ["cafeteria", "convenience_store"]:
		var extra := 2 if id == "cafeteria" else 1
		result["energy"] = int(result.get("energy", 0)) - extra
		result["rule_hint"] = String(result.get("rule_hint", "")) + "\n雨天出门，额外耗%d精力。" % extra
	return result


static func food_ids(day: int, meal: String, source_id: String, ids: Array[String], value: Dictionary) -> Array[String]:
	if enabled(value) and day == 3 and source_id == "cafeteria" and meal == limited_meal(value):
		return ids.filter(func(id: String) -> bool: return id in BASIC_MENU)
	return ids.duplicate()


static func action(day: int, phase: String, id: String, base: Dictionary, value: Dictionary) -> Dictionary:
	if not enabled(value) or day != 5 or id != "study": return Weekly.apply_action(day, id, base)
	var result := base.duplicate(true)
	if phase == peer_phase(value):
		result["study"] = int(result.get("study", 0)) + 6
		result["energy"] = int(result.get("energy", 0)) - 4
		result["min_energy"] = maxi(int(result.get("min_energy", 0)), 14)
		result["stress"] = int(result.get("stress", 0)) + 1
		result["name_" + phase] = "和同学对题"
		result["desc"] = "和同学一起讲题，把卡住的地方过一遍。"
		result["rule_hint"] = String(result.get("rule_hint", "")) + "\n这是今天约好的时段：额外+6复习、-4精力、+1压力，占1个安排。"
	return result


static func opening(day: int, state: Dictionary, history: Array, value: Dictionary) -> String:
	var gap := maxi(0, 70 - int(state.get("study_progress", 0)))
	match day:
		1: return "小林：周日考试，这周饭钱¥%d。先吃早饭，再把复习排进去。" % int(state.get("balance", 150))
		2:
			var spent: int = int(history.back().get("spend", 0)) if not history.is_empty() else 0
			return "小林：昨天花了¥%d，复习还差%d。今天想出门走走。" % [spent, gap]
		3: return "小林：常去的窗口要检修，今天得换个搭配，或者换个去处。"
		4: return "小林：有张配送券，先看看把饭钱算进去要花多少。"
		5: return "小林：同学约了对题，还差%d进度。先看看约在什么时候。" % gap if gap > 0 else "小林：复习目标到了。同学约了对题，去不去再想想。"
		6: return "小林：雨要下一整天，先翻翻柜子，再决定出不出门。"
		_: return "小林：最后一天，还差%d进度，今天得留点时间复习。" % gap if gap > 0 else "小林：复习目标到了，今天把三餐和休息安排好。"


static func action_note(day: int, phase: String, state: Dictionary, value: Dictionary) -> String:
	var tomorrow := ""
	if phase == "dinner_action" and day in [2, 4, 5]:
		tomorrow = "明天%s食堂窗口检修，这段时间也可以补存粮。" % MEAL_NAMES[limited_meal(value)] if day == 2 else ("明天%s和同学对题，今晚想想怎样留精力。" % ("午饭后" if int(value.get("variant", 0)) == 0 else "晚饭后") if day == 4 else "明天有雨，可以留存粮，也可以留出门或配送的预算。")
	if day == 5 and phase == peer_phase(value): return "同学已经到了：选“和同学对题”赴约，也可以自己安排。" + ("\n" + tomorrow if not tomorrow.is_empty() else "")
	if not tomorrow.is_empty(): return tomorrow
	if int(state.get("energy", 0)) < 25: return "小林：有点累了，先看看还能做什么。"
	if int(state.get("study_progress", 0)) >= 70: return "小林：复习目标到了，这段时间可以另作安排。"
	return "小林：复习还差%d，吃过饭再挑这段时间要做的事。" % maxi(0, 70 - int(state.get("study_progress", 0)))


static func plan_for(value: Dictionary, day: int, meal: String) -> Dictionary:
	for row in value.get("plans", []):
		if row["day"] == day and row["meal"] == meal: return row
	return {}


static func set_plan(value: Dictionary, target_day: int, meal: String, source_id: String, made_day: int) -> bool:
	if not enabled(value) or target_day not in range(made_day, mini(7, made_day + 1) + 1) or meal not in MEALS: return false
	var previous := plan_for(value, target_day, meal)
	if not previous.is_empty() and previous["resolved"]: return false
	if not previous.is_empty(): value["plans"].erase(previous)
	value["plans"].append({"day": target_day, "meal": meal, "source": source_id, "made_day": made_day, "resolved": false, "actual_source": "", "actual_foods": [], "skipped": false})
	return true


static func resolve_plan(value: Dictionary, day: int, meal: Dictionary) -> void:
	var plan := plan_for(value, day, String(meal["phase"]))
	if plan.is_empty() or plan["resolved"]: return
	plan["resolved"] = true
	plan["actual_source"] = String(meal.get("source_id", ""))
	plan["actual_foods"] = meal["food_ids"].duplicate()
	plan["skipped"] = bool(meal["skipped"])


static func plan_text(plan: Dictionary, sources: Dictionary) -> String:
	var wanted := String(sources.get(plan.get("source", ""), {}).get("name", "到时再选"))
	var title := "第%d天%s原打算：%s" % [plan["day"], MEAL_NAMES[plan["meal"]], wanted]
	if not plan["resolved"]: return title
	if plan["skipped"]: return title + "；实际跳过了这一餐。"
	var actual := String(sources.get(plan["actual_source"], {}).get("name", "其他来源"))
	return title + "；实际在%s选了%d项。" % [actual, plan["actual_foods"].size()]


static func recap(day: int, meals: Array, actions: Array, state: Dictionary, value: Dictionary) -> String:
	if day == 3:
		for meal in meals:
			if meal["phase"] != limited_meal(value): continue
			if meal.get("skipped", false): return "小林：检修那顿没吃，下一餐想早点定个去处。"
			if meal.get("source_id") == "cafeteria": return "小林：窗口少开了几个，这顿在基础菜单里选了%d样。" % meal["food_ids"].size()
			return "小林：食堂检修，这顿换了个去处。"
	if day == 5:
		for item in actions:
			if item.get("campus_event", "") == "peer_review": return "小林：和同学对过题了，讲出来才发现有几处没记牢。"
		return "小林：今天没去对题，按自己的节奏安排了。"
	if int(state.get("study_progress", 0)) >= 70: return "小林：复习目标到了，剩下几顿想好好安排。" if day < 7 else "小林：这一周复习到这里，准备去考试了。"
	if day >= 7: return "小林：这一周走完了，复习还差%d。下次得早点留出复习时间。" % maxi(0, 70 - int(state.get("study_progress", 0)))
	var pantry := 0
	for meal in meals:
		if meal.get("source_id") == "dorm_storage": pantry += 1
	if day == 6 and pantry > 0: return "小林：下雨这天，柜子里的存粮用上了。"
	if pantry > 0: return "小林：今天有%d餐用了存粮，之后补不补还得算算。" % pantry
	return "小林：复习还差%d，明天先把吃饭的去处想好。" % maxi(0, 70 - int(state.get("study_progress", 0)))


static func valid(value: Variant, campus: bool, p: Dictionary, foods: Dictionary, sources: Dictionary) -> bool:
	if not value is Dictionary: return false
	if not campus: return value.is_empty()
	if value.size() != 8 or value.get("version") != 2 or typeof(value.get("version")) != TYPE_INT or typeof(value.get("enabled")) != TYPE_BOOL or typeof(value.get("variant")) != TYPE_INT or value["variant"] not in [0, 1]: return false
	if not value.get("plans") is Array or value["plans"].size() > 21 or not value.get("attempts") is Array or value["attempts"].size() > 128 or not value.get("active") is Dictionary: return false
	if not value["enabled"]: return value == initial_state(0, false)
	if not Journal.valid(value.get("journal")) or not Resources.valid(value.get("resources"), p, foods): return false
	for row in value["journal"]["entries"]:
		var c: Dictionary = row["context"]
		if not Learning.valid_context(c, foods, sources) or c["day"] > p["day"]: return false
		var q := Learning.question(c)
		for answer in row["answers"]:
			var response: Dictionary = answer["response"]
			if response.size() != 1 or not q["choices"].any(func(choice: Dictionary) -> bool: return choice["id"] == response.get("choice")) or answer["correct"] != (response["choice"] == q["correct"]): return false
	var keys := {}
	var records: Array = p.get("today_meal_records", []).duplicate(true)
	for row in p.get("run_history", []):
		for meal in row.get("meals", []):
			var copy: Dictionary = meal.duplicate(true)
			copy["_day"] = row.get("day")
			records.append(copy)
	for plan in value["plans"]:
		if not plan is Dictionary or plan.size() != 8 or typeof(plan.get("day")) != TYPE_INT or plan["day"] not in range(1, 8) or plan.get("meal") not in MEALS or typeof(plan.get("made_day")) != TYPE_INT or plan["made_day"] not in range(1, int(p["day"]) + 1) or plan["day"] not in range(plan["made_day"], mini(7, plan["made_day"] + 1) + 1): return false
		if typeof(plan.get("source")) != TYPE_STRING or (plan["source"] != "" and not sources.has(plan["source"])) or typeof(plan.get("resolved")) != TYPE_BOOL or typeof(plan.get("skipped")) != TYPE_BOOL or typeof(plan.get("actual_source")) != TYPE_STRING or not plan.get("actual_foods") is Array: return false
		if plan["source"] != "" and not sources[plan["source"]].get("scenes", []).has(plan["meal"]): return false
		var key := "%d:%s" % [plan["day"], plan["meal"]]
		if keys.has(key): return false
		keys[key] = true
		var actual := {}
		for meal in records:
			if int(meal.get("_day", p["day"])) == plan["day"] and meal.get("phase") == plan["meal"]: actual = meal
		if plan["resolved"]:
			if actual.is_empty() or plan["actual_source"] != actual.get("source_id", "") or plan["actual_foods"] != actual["food_ids"] or plan["skipped"] != actual["skipped"]: return false
		elif not actual.is_empty() or plan["actual_source"] != "" or not plan["actual_foods"].is_empty() or plan["skipped"]: return false
	for attempt in value["attempts"]:
		if not attempt is Dictionary or attempt.size() != 4 or not Learning.valid_context(attempt.get("context"), foods, sources) or int(attempt["context"]["day"]) > int(p["day"]) or typeof(attempt.get("after_help")) != TYPE_BOOL or typeof(attempt.get("correct")) != TYPE_BOOL: return false
		var q := Learning.question(attempt["context"])
		if not q["choices"].any(func(choice: Dictionary) -> bool: return choice["id"] == attempt.get("choice")) or attempt["correct"] != (attempt["choice"] == q["correct"]): return false
	var active: Dictionary = value["active"]
	if active.is_empty(): return true
	if active.get("day") != p["day"] or active.get("phase") != p["phase"] or p.get("new_day_pending", false): return false
	if active.get("kind") == "plan":
		return active.size() == 6 and typeof(active.get("target_day")) == TYPE_INT and active["target_day"] in range(p["day"], mini(7, p["day"] + 1) + 1) and active.get("meal") in MEALS and typeof(active.get("advance")) == TYPE_BOOL and (not active["advance"] or (p["phase"] == "summary" and active["target_day"] == p["day"] + 1 and active["meal"] == "breakfast"))
	if active.get("kind") != "study" or active.size() != 7 or not Learning.valid_context(active.get("context"), foods, sources) or active["context"]["day"] != p["day"] or active.get("page") not in ["question", "feedback"] or typeof(active.get("help")) != TYPE_BOOL or typeof(active.get("answer")) != TYPE_STRING: return false
	var matching := false
	if p["phase"] in MEALS and active["context"]["meal"] == p["phase"] and active["context"]["source"] == p["current_source_id"] and active["context"]["food_ids"] == p["selected_food_ids"]: matching = true
	for meal in p["today_meal_records"]:
		if meal["phase"] == active["context"]["meal"] and meal["food_ids"] == active["context"]["food_ids"] and meal.get("source_id", "") == active["context"]["source"]: matching = true
	if not matching: return false
	var q := Learning.question(active["context"])
	if active["page"] == "question" and active["answer"] != "": return false
	if active["page"] == "feedback" and not active["help"]: return false
	var lesson := Journal.entry(value["journal"], "composition", active["context"])
	if lesson.is_empty() or bool(active["help"]) != bool(lesson["help_seen"]): return false
	return active["answer"] == "" or q["choices"].any(func(choice: Dictionary) -> bool: return choice["id"] == active["answer"])
