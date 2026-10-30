extends RefCounted

## Pure, deterministic presentation over saved facts. Never rewrites the finale.
const Data := preload("res://scripts/GameData.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Trace := preload("res://scripts/systems/ActionFeedbackTrace.gd")
const Copy := preload("res://scripts/ui_v2/EndingFeedbackCopy.gd")
const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const MealRecords := preload("res://scripts/systems/MealRecordPresenter.gd")
const ART := "res://assets/generated/endings/feedback/"
const PERIOD_NAMES := {"breakfast_action": "早饭后", "lunch_action": "午饭后", "dinner_action": "晚饭后"}
const MEAL_NAMES := {"breakfast": "早餐", "lunch": "午餐", "dinner": "晚餐"}


static func build(story: Dictionary, ending_id: String, p: Dictionary) -> Dictionary:
	var household: bool = story.get("mechanics") == "household"
	var result := _household(story, ending_id, p) if household else _student(ending_id, p)
	var candidates := _moments(story, p, result)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["rank"] != b["rank"]: return a["rank"] > b["rank"]
		if a["day"] != b["day"]: return a["day"] < b["day"]
		return String(a["id"]) < String(b["id"])
	)
	var selected: Array[Dictionary] = []
	var categories: Array[String] = []
	for candidate in candidates:
		if categories.has(candidate["category"]): continue
		selected.append(candidate)
		categories.append(candidate["category"])
		if selected.size() == 2: break
	result["version"] = 1
	result["story_id"] = story.get("id", "campus_exam")
	result["ending_id"] = ending_id
	result["day"] = p.get("day", 1)
	result["goal_label"] = story.get("goal_label", "复习")
	result["balance"] = int(p.get("state", {}).get("balance", 0))
	result["moments"] = selected
	result["review"] = _review(story, p, candidates)
	result["next_try"] = Copy.next_try(result["next_try_id"], result.get("next_try_args", {}))
	return result


static func _student(id: String, p: Dictionary) -> Dictionary:
	var state: Dictionary = p.get("state", {})
	var progress := int(state.get("study_progress", 0))
	var reserve := int(state.get("stability", 0))
	var classification := Resolver.ending_result(state)
	var kind := String(classification["reason"])
	var summary := ""
	var next_id := "rest"
	var next_args := {}
	if id == "collapsed":
		kind = "campus_rest"
		summary = _closing(p)
		next_id = "meals" if int(state.get("satiety", 100)) < 20 else "rest"
	elif id == "study_shortfall":
		kind = "study_gap"
		summary = "复习%d/70，距离本周目标还差%d。这一周先到这里。" % [progress, maxi(0, 70 - progress)]
		next_id = "study_state" if _action_count(p, ["study"]) >= 7 else "study_time"
	elif id == "stable_endurance":
		kind = "steady"
		summary = "复习%d/70，余力%d。复习目标完成了，也给自己留了些余力。" % [progress, reserve]
		next_id = "explore_source"
	else:
		kind = "goal_gap" if progress < 70 else "reserve_gap"
		summary = "走完7天，复习%d/70，还差%d。余力%d。" % [progress, 70 - progress, reserve] if progress < 70 else "复习%d/70已经完成。余力%d，距离“稳稳到了周末”的60还差%d。" % [progress, reserve, maxi(0, 60 - reserve)]
		next_id = ("study_state" if _action_count(p, ["study"]) >= 7 else "study_time") if progress < 70 else "study_state"
	if id in ["barely_survived", "study_shortfall"] and progress < 70 and _action_count(p, ["study"]) < 7:
		var free_day := _study_day(p, false)
		if free_day > 0:
			next_id = "study_day"
			next_args = {"day": free_day}
	elif id == "barely_survived" and progress >= 70:
		var later_day := _study_day(p, true)
		if later_day > 0:
			next_id = "rest_day"
			next_args = {"day": later_day}
	var image := String(Data.get_ending(id).get("image", ""))
	if id == "study_shortfall": image = ART + "student_shortfall-v1.png"
	return {"kind": kind, "title": Data.get_ending(id).get("title", "这一局先到这里"), "voice": Copy.voice(kind),
		"summary": summary, "rules": Copy.CAMPUS_RULES, "image": image, "next_try_id": next_id, "next_try_args": next_args,
		"progress": progress, "target": 70, "reserve": reserve}


static func _household(story: Dictionary, id: String, p: Dictionary) -> Dictionary:
	var state: Dictionary = p.get("state", {})
	var finale: Dictionary = p.get("household_finale", {})
	var outcome: Dictionary = finale.get("outcome", {})
	var target := int(story.get("goal_target", 70))
	var minimum := int(Catalog.content(story, "actions").get("perform", {}).get("min_energy", 25))
	var actual := _performed(p)
	var kind := "unready"
	var title := "这次没赶上舞台"
	var summary := ""
	var next_id := "preflight"
	var image := ART + "zhou_unready-v1.png"
	if actual:
		kind = "performed"
		title = "把歌唱完了"
		summary = "已参加社区合唱汇演。排练%d/%d，余力%d。" % [int(state.get("goal_progress", 0)), target, int(state.get("stability", 0))]
		image = "res://assets/generated/stories/actions/zhou_perform-v1.png"
		next_id = "preparation" if _prepared_unused(p) else "menu"
	elif outcome.get("kind") == "other_choice":
		kind = "other_choice"
		title = "这一周，按自己的安排"
		summary = "演前排练%d/%d、精力%d，具备参演条件。%s" % [outcome["progress"], target, outcome["energy"], _chosen_action(p, outcome.get("trigger", ""))]
		image = ART + "zhou_other_choice-v1.png"
		next_id = "own_choice"
	elif id == "collapsed":
		kind = "zhou_rest"
		title = "先歇一会儿"
		summary = _closing(p)
		image = String(story.get("background", ""))
		next_id = "rest"
	elif not outcome.is_empty():
		var missing: Array[String] = []
		if int(outcome["progress"]) < target: missing.append("排练%d/%d，还差%d" % [outcome["progress"], target, target - int(outcome["progress"])])
		if int(outcome["energy"]) < minimum: missing.append("演前精力%d/%d，还差%d" % [outcome["energy"], minimum, minimum - int(outcome["energy"])])
		if int(outcome["slots"]) >= 3: missing.append("当天已经没有可用安排位")
		summary = "演前核对：\n" + "。\n".join(missing) + "。\n这次没有参加汇演。"
		if missing.size() == 1: next_id = "rehearse" if int(outcome["progress"]) < target else ("energy" if int(outcome["energy"]) < minimum else "slots")
		if missing.size() == 1 and int(outcome["progress"]) < target / 2: next_id = "rehearsal_time"
	else:
		kind = "legacy"
		title = "这一周，按实际记录回看" if p.get("performed", false) else title
		summary = "本局没有实际参演记录，演前原因也没有记全。下面只回看已经留下的经历。"
	if id == "collapsed" and kind in ["performed", "other_choice"]:
		summary += "\n" + _closing(p)
		next_id = "rest"
	return {"kind": kind, "title": title, "voice": Copy.voice(kind), "summary": summary,
		"rules": "第7天晚饭后可以参演。\n条件：\n排练至少%d，演前精力至少%d。\n还留有一个安排位。\n满足条件仍可以另作安排。\n\n实际执行参演，才算唱完。\n连续两天日结余力不高于15，会提前收束。\n最后一天余力不高于15，也会这样收尾。\n已经参演或另作安排的事实分别保留。" % [target, minimum],
		"image": image, "next_try_id": next_id, "progress": int(state.get("goal_progress", 0)), "target": target, "reserve": int(state.get("stability", 0))}


static func _closing(p: Dictionary) -> String:
	var day := int(p.get("day", 1))
	var reserve := int(p.get("state", {}).get("stability", 0))
	if int(p.get("low_stability_days", 0)) >= 2:
		return "本局停在第%d天。第%d、%d天日结余力连续不高于15，触发了提前收束。" % [day, maxi(1, day - 1), day]
	if day >= 7: return "本局走到第7天，日结余力%d，触发了低余力收尾。" % reserve
	return "本局在第%d天收束。回顾保留已经发生的经历。" % day


static func _performed(p: Dictionary) -> bool:
	for day_record in p.get("run_history", []):
		if not day_record is Dictionary or day_record.get("day") != 7: continue
		for action in day_record.get("actions", []):
			if action is Dictionary and action.get("id") == "perform": return true
	return false


static func _action_count(p: Dictionary, ids: Array) -> int:
	var total := 0
	for row in p.get("run_history", []):
		for action in row.get("actions", []):
			if action is Dictionary and ids.has(action.get("id")): total += 1
	return total


static func _study_day(p: Dictionary, after_target: bool) -> int:
	for row in p.get("run_history", []):
		var day := int(row.get("day", 0))
		var actions: Array = row.get("actions", [])
		if day < 1 or day > int(p.get("day", 1)) or actions.is_empty(): continue
		var has_study := actions.any(func(action: Variant) -> bool: return action is Dictionary and action.get("id") == "study")
		if not after_target and not has_study: return day
		if not after_target or not has_study: continue
		if int(row.get("start_state", {}).get("study_progress", -1)) >= 70: return day
		for action in actions:
			if action is Dictionary and action.get("id") == "study" and int(action.get("feedback_trace", {}).get("before", {}).get("progress", -1)) >= 70: return day
	return 0


static func _chosen_action(p: Dictionary, trigger: String) -> String:
	if trigger == "skip": return "这段时间没有再排事情。"
	for action in p.get("today_action_records", []):
		if action.get("id") == trigger: return "这段时间，你选择了“%s”。" % action.get("name", "另作安排")
	return "这次选择了其他安排。"


static func _prepared_unused(p: Dictionary) -> bool:
	for batch in p.get("kitchen", {}).get("batches", []):
		if batch.get("storage") == "fridge" and int(batch.get("quantity", 0)) > 0 and int(batch.get("day", 0)) > 0: return true
	return false


static func _moment(id: String, category: String, title: String, text: String, day: int, rank: int, basis: String) -> Dictionary:
	return {"id": id, "category": category, "title": title, "text": text, "day": day, "rank": rank, "basis": basis, "anchor": "day_%d" % day}


static func _moments(story: Dictionary, p: Dictionary, outcome: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var household: bool = story.get("mechanics") == "household"
	var goal_key := "goal_progress" if household else "study_progress"
	var goal_label := "排练" if household else "复习"
	var early_days: Array[String] = []
	var rehearsal_days: Array[String] = []
	var boost := 120 if outcome["kind"] == "performed" else 0
	for row in p.get("run_history", []):
		var day := int(row.get("day", 0))
		if day < 1 or day > int(p.get("day", 1)): continue
		var found_trace := false
		var actions: Array = row.get("actions", [])
		for index in range(actions.size()):
			var action: Variant = actions[index]
			if not action is Dictionary: continue
			if action.get("id") in ["rehearse", "group_rehearsal"]: rehearsal_days.append("第%d天" % day)
			var trace: Dictionary = action.get("feedback_trace", {})
			if trace.is_empty() or not Trace.valid(trace, action, day, index + 1, row.get("learning_state", {})): continue
			var tradeoff: bool = action.get("id") in ["study", "rehearse", "group_rehearsal"] and outcome["kind"] in ["reserve_gap", "unready"] and int(trace["before"]["progress"]) >= int(outcome["target"]) and int(trace["actual"]["energy"]) < 0
			if int(trace["actual"]["progress"]) <= 0 and not tradeoff: continue
			found_trace = true
			var parts: Dictionary = trace["goal_components"]
			var period := String(PERIOD_NAMES.get(trace["phase"], "餐后"))
			var rank := 120 + (20 if int(parts.get("recovery", 0)) > 0 else 0)
			if outcome["kind"] == "study_gap" and int(parts.get("current", 0)) < 0: rank += 40
			var reached: bool = int(trace["before"]["progress"]) < int(outcome["target"]) and int(trace["after"]["progress"]) >= int(outcome["target"])
			if reached: rank = 185
			if tradeoff: rank = 210 if int(trace["actual"]["progress"]) < int(trace["requested"]["progress"]) else 200
			var title := "第%d天，%s到了%d" % [day, goal_label, outcome["target"]] if reached else "第%d天%s的%s" % [day, period, goal_label]
			if tradeoff: title = "第%d天，目标到位后的%s" % [day, goal_label]
			var text := "选择了“%s”。\n%s进度 %d → %d。" % [action.get("name", goal_label), goal_label, trace["before"]["progress"], trace["after"]["progress"]]
			if tradeoff: text += "\n这次精力%s。" % _signed(trace["actual"]["energy"])
			if int(trace["actual"]["progress"]) < int(trace["requested"]["progress"]):
				text += "\n进度已到上限，这次没有再增加。" if int(trace["actual"]["progress"]) == 0 else "\n进度达到上限，收益没有全部计入。"
			elif int(parts.get("recovery", 0)) > 0:
				text += "\n昨夜恢复加成 %s。" % _signed(parts["recovery"])
			elif int(parts.get("recovery", 0)) < 0:
				text += "\n昨夜恢复对本次收益的影响为%s。" % _signed(parts["recovery"])
			var explanation: Array[String] = ["基础收益%s" % _signed(parts.get("base", 0))]
			for key in ["event", "recovery", "current", "floor"]:
				if int(parts.get(key, 0)) != 0: explanation.append(String({"event": "当天事件", "recovery": "昨夜恢复", "current": "当前状态", "floor": "最低收益调整"}[key]) + _signed(parts[key]))
			var basis := "第%d天%s，选择“%s”。\n原收益%s，实际增加%s。\n%s。" % [day, period, action.get("name", goal_label), _signed(trace["requested"]["progress"]), _signed(trace["actual"]["progress"]), "，".join(explanation)]
			if tradeoff: basis += "\n行动自身精力%d→%d；餐后时段的公共消耗另计。" % [trace["before"]["energy"], trace["after"]["energy"]]
			result.append(_moment("action_%02d_%02d" % [day, index], "progress", title, text, day, rank, basis))
		if not found_trace and row.get("start_state", {}).has(goal_key) and row.get("end_state", {}).has(goal_key):
			var gain := int(row["end_state"][goal_key]) - int(row["start_state"][goal_key])
			if gain > 0:
				result.append(_moment("daily_%02d" % day, "progress", "第%d天，进度往前走了一段" % day, "当日%s进度增加%d。" % [goal_label, gain], day, 100, "来自第%d天日结前后的进度差额，是整天合计；没有逐次证据时，不归给其中某一个行动。" % day))
		if row.get("sleep", {}).get("id") == "sleep_early":
			early_days.append("第%d晚" % day)
			for next_day in p.get("run_history", []):
				if next_day.get("day") != day + 1: continue
				var opening: Variant = next_day.get("learning_state", {})
				if opening is Dictionary and not String(opening.get("title", "")).is_empty():
					result.append(_moment("night_%02d" % day, "night", "第%d晚的早点睡" % day, "第%d天以“%s”开场。" % [day + 1, opening["title"]], day, 110, "第%d晚实际选择早点睡。\n第%d天冻结的开场恢复：%s。恢复按当时精力、压力和已执行行动共同判断。" % [day, day + 1, opening["title"]]))
		for meal in row.get("meals", []):
			if not meal is Dictionary or meal.get("skipped", false) or meal.get("food_ids", []).is_empty(): continue
			var names := "、".join(meal.get("food_names", []).slice(0, 2))
			if names.is_empty(): continue
			var phase := String(meal.get("phase", ""))
			var meal_name := String(MEAL_NAMES.get(phase, "这一餐"))
			if meal.get("source_id") == "dorm_storage":
				result.append(_moment("pantry_%02d_%s" % [day, phase], "pantry", "第%d天，存粮派上用场" % day, "从宿舍存粮取了%s，这餐现金支出¥%d。" % [names, int(meal.get("total_cost", 0))], day, 90, "第%d天%s：%s；食物%s；餐次费用¥%d。只回顾这次取用，不把库存食物视作没有购买成本。" % [day, meal_name, meal.get("source_name", "宿舍存粮"), names, int(meal.get("total_cost", 0))]))
			var companions: Variant = meal.get("companions", [])
			if companions is Array and companions.any(func(person: Variant) -> bool: return person is Dictionary and person.get("id") == "chen_friend"):
				result.append(_moment("shared_%02d_%s" % [day, phase], "together", "第%d天，和老陈同桌" % day, "这一餐一起吃了%s。" % names, day, 160 + boost, "真实餐次中记录了同桌人老陈。\n第%d天%s，来源：%s，食物：%s。邀约本身不计为共餐。" % [day, meal_name, meal.get("source_name", ""), names]))
	if not early_days.is_empty():
		result.append(_moment("sleep_early", "night", "%d晚选择了早点睡" % early_days.size(), "这是这一周实际留下的晚间安排。", 1, 80, "、".join(early_days) + "选择早点睡。恢复仍按各晚实际精力、压力和行动判断，不能只由早睡次数推断。"))
	if not rehearsal_days.is_empty():
		result.append(_moment("rehearsal", "progress", "这一周的练歌时间", "实际安排了%d次练歌或合练。" % rehearsal_days.size(), 1, 95, "、".join(rehearsal_days) + "有练歌或合练行动。次数不代替实际进度或参演记录。"))
	var made := {}
	for row in p.get("kitchen", {}).get("history", []):
		if not row is Dictionary: continue
		if row.get("action") == "cook":
			for batch in row.get("prepared", []):
				if batch.get("storage") == "fridge" and batch.has("id"): made[batch["id"]] = batch
		if row.get("action") != "reheat_and_eat": continue
		var names: Array[String] = []
		var proof: Array[String] = []
		for batch in row.get("batches", []):
			if not batch.has("id") or not made.has(batch["id"]) or batch.get("reheat_count") != 1: continue
			var original: Dictionary = made[batch["id"]]
			var name := String(Catalog.content(story, "foods").get(batch.get("food_id", ""), {}).get("name", "熟食"))
			names.append(name)
			proof.append("%s：第%d天另留冷藏，第%d天实际取用并再热。" % [name, int(original.get("day", 0)), int(row.get("day", 0))])
		if not names.is_empty():
			var day := int(row.get("day", 1))
			result.append(_moment("prepared_%02d_%s" % [day, result.size()], "kitchen", "多做的饭，有了后续", "第%d天取用了此前另留冷藏的%s。" % [day, "、".join(names.slice(0, 2))], day, 150 + boost, "\n".join(proof)))
	return result


static func _review(story: Dictionary, p: Dictionary, moments: Array[Dictionary]) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	var household: bool = story.get("mechanics") == "household"
	var goal_key := "goal_progress" if household else "study_progress"
	var book := MealRecords.capture(p.get("run_history", []), p.get("today_meal_records", []), int(p.get("day", 1)))
	for row in p.get("run_history", []):
		var day := int(row.get("day", 0))
		if day < 1 or day > int(p.get("day", 1)): continue
		var lines: Array[String] = []
		if row.get("start_state", {}).has(goal_key) and row.get("end_state", {}).has(goal_key):
			lines.append("%s进度 %d→%d · 花费 ¥%d" % [story.get("goal_label", "复习"), int(row["start_state"][goal_key]), int(row["end_state"][goal_key]), int(row.get("spend", 0))])
		if book.get("valid", false) and book["days"].size() >= day:
			for meal in book["days"][day - 1]["rows"]:
				var meal_name: String = {"breakfast": "早餐", "lunch": "午餐", "dinner": "晚餐"}.get(meal.get("phase", ""), "餐次")
				lines.append(meal_name + "：" + String(meal.get("text", "未记全")))
		var names: Array[String] = []
		for action in row.get("actions", []):
			if action is Dictionary: names.append(String(action.get("name", action.get("id", "安排"))))
		if not names.is_empty(): lines.append("实际安排：" + "、".join(names))
		if row.get("sleep", {}).has("name"): lines.append("夜里：" + String(row["sleep"]["name"]))
		if row.get("learning_state") is Dictionary and row["learning_state"].has("title"): lines.append("开场恢复：" + String(row["learning_state"]["title"]))
		for moment in moments:
			if moment["day"] == day and moment["category"] in ["progress", "together", "kitchen"]:
				lines.append(moment["title"] + "\n" + moment["basis"])
		sections.append({"id": "day_%d" % day, "title": "第%d天" % day, "text": "\n\n".join(lines)})
	if household:
		var stored: Dictionary = p.get("household_finale", {}).get("review", {})
		for item in stored.get("highlights", []):
			sections.append({"id": "household_%d" % sections.size(), "title": item.get("title", "本周记录"), "text": item.get("text", "")})
	return sections


static func _signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
