extends RefCounted

const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")


static func initial_state(legacy: bool = false) -> Dictionary:
	return {"version": 1, "intro": "legacy" if legacy else "pending", "active": {}, "outcome": {}, "pending": false, "acknowledged": false, "review": {}}


static func outcome(progress: int, energy: int, slots: int, trigger: String, target: int, minimum: int, maximum: int) -> Dictionary:
	var missing: Array[String] = []
	if progress < target: missing.append("排练%d/%d" % [progress, target])
	if energy < minimum: missing.append("演前精力%d，需至少%d" % [energy, minimum])
	if slots >= maximum: missing.append("当天安排位已用完")
	var kind := "performed" if trigger == "perform" else ("unready" if not missing.is_empty() else "other_choice")
	var reason := "实际选择参加汇演，完成后记入行动记录。" if kind == "performed" else ("离开晚饭后时段前：" + "；".join(missing) + "。" if kind == "unready" else "离开晚饭后时段前，参演条件已满足；这次选择了其他安排。")
	return {"kind": kind, "progress": progress, "energy": energy, "slots": slots, "trigger": trigger, "reason": reason}


static func capture(game: Node, trigger: String) -> bool:
	if not game._household() or game.day != 7 or game.phase != "dinner_action" or not game.household_finale["outcome"].is_empty(): return false
	game.household_finale["outcome"] = outcome(game.state["goal_progress"], game.state["energy"], game.actions_used_today, trigger, game._goal_target(), game._story_action("perform")["min_energy"], game.MAX_DAILY_ACTIONS)
	return true


static func acknowledge(state: Dictionary) -> bool:
	if not state["pending"] or state["acknowledged"] or state["outcome"].is_empty(): return false
	state["pending"] = false
	state["acknowledged"] = true
	return true


static func review(p: Dictionary) -> Dictionary:
	var counts := {"days": p["run_history"].size(), "meals": 0, "skipped": 0, "rehearsals": 0, "performances": 0, "shared": 0, "prepared_items": 0, "counter_items": 0, "reheated_items": 0, "first_correct": 0, "first_wrong": 0, "first_after_help": 0, "attempted_contexts": 0, "retries": 0, "plans": p["household_preparation"].get("plans", []).size(), "plans_used": 0, "opening_discarded": 0}
	for day_record in p["run_history"]:
		for meal in day_record["meals"]:
			if meal.get("skipped", false): counts["skipped"] += 1
			elif not meal.get("food_ids", []).is_empty():
				counts["meals"] += 1
				var companions: Variant = meal.get("companions", [])
				if companions is Array and companions.any(func(person: Variant) -> bool: return person is Dictionary and person.get("id") == "chen_friend"): counts["shared"] += 1
		for action in day_record["actions"]:
			if not action is Dictionary: continue
			if action.get("id") in ["rehearse", "group_rehearsal"]: counts["rehearsals"] += 1
			if day_record["day"] == 7 and action.get("id") == "perform": counts["performances"] += 1
	for row in p["kitchen"]["history"]:
		if not row is Dictionary: continue
		if row.get("action") == "discard" and row.get("batch") is Dictionary and row["batch"].get("id") == "before_week_greens": counts["opening_discarded"] += int(row["batch"].get("quantity", 0))
		if row.get("action") == "cook" and row.get("prepared") is Array:
			for batch in row["prepared"]:
				if not batch is Dictionary: continue
				if batch.get("storage") == "fridge": counts["prepared_items"] += 1
				if batch.get("storage") == "counter": counts["counter_items"] += 1
		if row.get("action") == "reheat_and_eat":
			var batches: Variant = row.get("batches", [])
			if not batches is Array: continue
			for batch in batches:
				if batch is Dictionary and batch.has("id") and batch.get("reheat_count") == 1: counts["reheated_items"] += 1
	for row in p["household_lessons"].get("entries", []):
		counts["retries"] += row["retry_count"]
		if row["attempts"].is_empty(): continue
		counts["attempted_contexts"] += 1
		var first: Dictionary = row["attempts"][0]
		if first["after_help"]: counts["first_after_help"] += 1
		elif first["correct"]: counts["first_correct"] += 1
		else: counts["first_wrong"] += 1
	for row in p["household_preparation"].get("plans", []):
		if not row["result"].get("used_ids", []).is_empty(): counts["plans_used"] += 1
	var saved: Dictionary = p["household_finale"]["outcome"]
	var outcome_text: String = "实际参加了社区合唱汇演。" if counts["performances"] > 0 else (saved["reason"] if not saved.is_empty() else ("本局在第%d天收束，还没有第7天参演记录。" % p["day"] if p["day"] < 7 else "本局没有实际参演记录；未记录的演前原因保持未知。"))
	var highlights: Array[Dictionary] = [
		{"title": "这一周的饭", "text": "实际记录%d天，确认进餐%d餐，跳过%d餐。组成、份量和全天安排需要分开看。" % [counts["days"], counts["meals"], counts["skipped"]]},
		{"title": "开局那份隔夜菜", "text": "已实际丢弃开局前保存不当的熟食。" if counts["opening_discarded"] > 0 else "没有找到丢弃开局那份熟食的记录，不补写已经处理。"},
		{"title": "选餐与标签练习", "text": "%d个情境有作答；首次独立正确%d、首次独立错误%d、帮助后首次%d，重试%d次。重试不覆盖首次记录，答对不等于已经学会。" % [counts["attempted_contexts"], counts["first_correct"], counts["first_wrong"], counts["first_after_help"], counts["retries"]] if counts["attempted_contexts"] > 0 else "本局没有已记录的练习作答；看过说明不等于已经作答或学会。"},
		{"title": "同桌的约定", "text": "实际记录和老陈同桌%d餐，邀约本身不计为已经一起吃。" % counts["shared"]},
		{"title": "备餐的后续", "text": "实际另留冷藏%d样熟食，取用并再热%d样；%d个下一餐计划中，%d个记录到熟食取用，其余按实际安排保留。%s" % [counts["prepared_items"], counts["reheated_items"], counts["plans"], counts["plans_used"], "另有%d样选择灶台留存，不算可用冷藏备餐。" % counts["counter_items"] if counts["counter_items"] > 0 else ""]},
	]
	var next_step := "下次先为三餐留出安排，再排练歌与休息。" if counts["skipped"] > 0 else ("下次换一个菜单或标签，再核对实际份量和仍未知的项目。" if counts["first_wrong"] > 0 or counts["attempted_contexts"] == 0 else "下次先对照下一餐的人数与库存，再决定是否另留一份。")
	return {"version": 1, "outcome_text": outcome_text, "highlights": highlights, "next_step": next_step, "counts": counts}


static func review_text(value: Dictionary) -> String:
	var lines: Array[String] = [value["outcome_text"]]
	for item in value["highlights"]: lines.append(item["title"] + "\n" + item["text"])
	lines.append("下次的一件小事\n" + value["next_step"])
	return "\n\n".join(lines)


static func valid(value: Variant, household: bool, p: Dictionary, foods: Dictionary, actions: Dictionary, target: int) -> bool:
	if not value is Dictionary: return false
	if not household: return value.is_empty()
	if value.size() != 7 or typeof(value.get("version")) != TYPE_INT or value["version"] != 1 or value.get("intro") not in ["pending", "details", "done", "legacy"] or not value.get("active") is Dictionary or not value.get("outcome") is Dictionary or not value.get("review") is Dictionary or typeof(value.get("pending")) != TYPE_BOOL or typeof(value.get("acknowledged")) != TYPE_BOOL: return false
	if p["day"] < 7 and (value["intro"] in ["details", "done"] or not value["active"].is_empty() or not value["outcome"].is_empty() or value["pending"] or value["acknowledged"]): return false
	if value["intro"] == "details" and (p["day"] != 7 or p["phase"] != "breakfast_source" or p["new_day_pending"]): return false
	var result: Dictionary = value["outcome"]
	if result.is_empty():
		if value["pending"] or value["acknowledged"]: return false
	else:
		if result.size() != 6 or p["day"] != 7 or p["phase"] not in ["sleep", "summary", "ending"] or typeof(result.get("progress")) != TYPE_INT or result["progress"] < 0 or result["progress"] > 100 or typeof(result.get("energy")) != TYPE_INT or result["energy"] < 0 or result["energy"] > 100 or typeof(result.get("slots")) != TYPE_INT or result["slots"] < 0 or result["slots"] > 3: return false
		var trigger: Variant = result.get("trigger")
		if trigger != "skip" and (typeof(trigger) != TYPE_STRING or not actions.has(trigger) or int(actions[trigger].get("slots", 1)) <= 0): return false
		if result != outcome(result["progress"], result["energy"], result["slots"], trigger, target, int(actions["perform"]["min_energy"]), 3): return false
		if result["kind"] == "performed" and (result["progress"] < target or result["energy"] < actions["perform"]["min_energy"] or result["slots"] >= 3): return false
		var periods: Array = p["today_period_records"].filter(func(row: Dictionary) -> bool: return row.get("phase") == "dinner_action" and row.get("finale_context") == result)
		var actual: Array = p["today_action_records"].filter(func(row: Dictionary) -> bool: return row.get("id") == "perform")
		if periods.size() != 1 or (result["kind"] == "performed") != (actual.size() == 1) or p["performed"] != (result["kind"] == "performed"): return false
		if trigger != "skip" and not p["today_action_records"].any(func(row: Dictionary) -> bool: return row.get("id") == trigger): return false
		if value["pending"] and (value["acknowledged"] or p["phase"] != "sleep"): return false
	if not value["review"].is_empty() and (p["phase"] != "ending" or value["review"] != review(p)): return false
	var active: Dictionary = value["active"]
	if value["intro"] == "details" and (not active.is_empty() or value["pending"]): return false
	if active.is_empty(): return true
	if value["pending"] or p["day"] != 7 or p["new_day_pending"] or active.size() != 7 or active.get("day") != 7 or active.get("phase") != p["phase"] or active.get("source") != p["current_source_id"] or active.get("kind") not in ["stage", "cooking"] or not active.get("ids") is Array or not active.get("plan") is Dictionary or p["phase"] in ["sleep", "summary", "ending"]: return false
	if active["kind"] == "stage": return active["ids"].is_empty() and active["plan"].is_empty() and active.get("storage") == "eat_now"
	return p["phase"] in ["breakfast", "lunch", "dinner"] and active["source"] == "home_kitchen" and active["ids"] == p["selected_food_ids"] and active.get("storage") in ["eat_now", "fridge", "counter"] and Facts.validate(active["plan"], active["ids"], foods)
