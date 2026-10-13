class_name RecoveryPresenter
extends RefCounted

## Read-only player copy from frozen records. No evaluation or stat writes.
const StateService := preload("res://scripts/systems/RecoveryStateService.gd")
const Gameplay := preload("res://scripts/systems/RecoveryGameplayService.gd")
const MealRecords := preload("res://scripts/systems/MealRecordPresenter.gd")
const SLEEP_NAMES := {"sleep_early": "早点睡", "night_study": "再复习一会儿", "scroll_phone": "刷一会儿手机"}
const REASONS := {
	"LOW_ENERGY_SEVERE": "收工时精力很低",
	"HIGH_STRESS_SEVERE": "收工时压力很高",
	"LATE_STUDY_LOW_ENERGY": "晚间复习后精力偏低",
	"LATE_STUDY_HIGH_STRESS": "晚间复习后压力偏高",
	"OVERWORKED_LOW_ENERGY": "三个安排位都用于复习，收工时精力偏低",
	"HIGH_STRESS_LOW_ENERGY": "收工时压力偏高、精力偏低",
	"LATE_STUDY": "晚间继续复习",
	"LOW_ENERGY": "收工时精力偏低",
	"HIGH_STRESS": "收工时压力偏高",
	"OVERWORKED": "三个安排位都用来复习，没留休息时间",
	"EARLY_SLEEP_READY": "选择早点睡，收工时精力充足、压力较低",
	"STEADY_FALLBACK": "收工时的精力、压力和安排让复习收益保持照常",
}
const HELP := "昨夜恢复在每天收工后记录一次，白天保持这条记录。判断会一起看精力、压力、当天行动和晚间安排。\n恢复会影响第二天的开场与复习收益。这些是游戏规则，不用于判断真实健康；休息也不会改掉已经记下的饮食选择。"
const EFFECT_NAMES := {
	"legacy_quality_bonus": "餐食游戏加成", "legacy_quality_strain": "餐食游戏压力变化",
	"high_quality_bonus": "餐食游戏加成", "low_quality_stress": "餐食游戏压力变化",
	"low_satiety": "低饱腹日终效果", "high_satiety": "高饱腹日终效果",
	"tight_budget": "预算紧张", "study_behind": "复习进度落后",
	"study_on_pace": "复习进度跟上", "end_of_day_decay": "日终饱腹消耗",
}
const STAT_NAMES := {"energy": "精力", "mood": "心情", "stress": "压力", "satiety": "饱腹", "study_progress": "复习", "balance": "余额"}


static func present(record: Variant, timing: String = "current") -> Dictionary:
	var checked := StateService.validate(record)
	if not checked["valid"]:
		if record is Dictionary and (record.get("status") == "unsupported_version" or (typeof(record.get("schema_version")) == TYPE_INT and record["schema_version"] > StateService.SCHEMA_VERSION)):
			return _unavailable("unsupported_version")
		return _unavailable("invalid")
	if record["status"] != "known":
		return _unavailable(String(record["status"]))
	var frozen := StateService.normalize(record)
	if frozen["origin"] == "new_run_default":
		return {"available": true, "title": "起步状态", "label": "起步状态", "summary": "新的一周开始了，还没有昨夜的恢复记录。", "effect_text": "今天从起步状态开始", "detail_text": "这是这一周的起点。今晚怎么安排，收工后再记。\n\n" + HELP}
	var title: String = Gameplay.TITLES[frozen["condition"]]
	var lead := "今晚恢复" if timing == "settled" else "昨夜恢复"
	var facts: Array[String] = []
	for rule_id in frozen["matched_rule_ids"]:
		if REASONS.has(rule_id):
			facts.append(REASONS[rule_id])
	var reason := "；".join(facts)
	var short_reason := "；".join(facts.slice(0, 2))
	if facts.size() > 2:
		short_reason += "；完整依据见详情"
	var sleep: Dictionary = frozen["sleep_snapshot"]
	if sleep["id"] == "scroll_phone":
		reason += "。这晚刷了手机，恢复仍看实际精力、压力和安排"
		short_reason += "。这晚刷了手机，恢复仍看实际精力、压力和安排"
	elif sleep["id"] == "sleep_early" and frozen["condition"] in ["strained", "depleted"]:
		reason += "。虽然早点睡了，收工时仍有这些情况"
		short_reason += "。虽然早点睡了，收工时仍有这些情况"
	var effect := _effect_text(frozen["next_day_effect"], timing)
	var details: Array[String] = ["第 %d 天收工后 · %s" % [frozen["evaluated_day"], title], "判断依据：" + reason, "晚间安排：" + String(SLEEP_NAMES[sleep["id"]])]
	var before: Dictionary = frozen["before_sleep"]
	var after: Dictionary = frozen["after_sleep"]
	var finish: Dictionary = frozen["end_of_day"]
	details.append("精力 %d → %d → %d；压力 %d → %d → %d\n依次为睡前、晚间安排后、收工时。" % [before["energy"], after["energy"], finish["energy"], before["stress"], after["stress"], finish["stress"]])
	details.append("晚间安排实际效果：" + _delta_text(sleep))
	var others: Array[String] = []
	for entry in frozen["settlement_effects"]:
		var delta := _delta_text(entry["requested_delta"])
		if delta != "无数值变化":
			others.append("%s：%s" % [EFFECT_NAMES.get(entry["source_id"], "其他日终游戏效果"), delta])
	if not others.is_empty():
		details.append("其他日终效果（按执行顺序）：\n" + "\n".join(others))
	details.append("数值保持在0–100，这次调整：" + _delta_text(frozen["clamp_delta"]))
	details.append(effect + "。当天事件、精力和压力也会影响实际复习收益；数值到顶或到底时，只记实际变化。")
	if timing == "final":
		details[-1] = "本周已收尾，这条记录的次日效果没有在本局应用。"
	details.append(HELP)
	return {"available": true, "title": title, "label": lead + " · " + title, "summary": short_reason + "。", "effect_text": effect, "detail_text": "\n\n".join(details)}


static func _unavailable(status: String) -> Dictionary:
	var title := "恢复记录暂时不可用"
	var text := "这条记录读不完整，暂时看不到恢复依据和效果。"
	if status == "legacy_unknown":
		title = "这段历史没有恢复记录"
		text = "旧记录没有保存恢复依据，这一晚的状态无法确定。"
	elif status == "unsupported_version":
		title = "恢复记录版本暂不支持"
		text = "当前版本无法读取这条恢复记录。"
	return {"available": false, "title": title, "label": title, "summary": text, "effect_text": "恢复效果暂不可用", "detail_text": text + "\n这条记录不参与恢复效果计算。"}


static func _effect_text(effect: Dictionary, timing: String) -> String:
	if timing == "final":
		return "本周已收尾，不再应用次日效果"
	var prefix := "明天" if timing == "settled" else "今天"
	var modifier := int(effect["study_modifier"])
	var study := "每次复习收益不变" if modifier == 0 else "每次复习收益 " + signed(modifier)
	var opening := _delta_text(effect["opening_delta"])
	return "%s%s；开场%s" % [prefix, study, opening]


static func _delta_text(delta: Dictionary) -> String:
	var parts: Array[String] = []
	for key in STAT_NAMES:
		if delta.has(key) and int(delta[key]) != 0:
			parts.append("%s %s" % [STAT_NAMES[key], signed(int(delta[key]))])
	# Sleep uses study rather than study_progress.
	if delta.has("study") and int(delta["study"]) != 0:
		parts.append("复习 " + signed(int(delta["study"])))
	return "、".join(parts) if not parts.is_empty() else "无数值变化"


static func signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


static func ending_text(ending_id: String, history: Array) -> String:
	var result: String = {
		"stable_endurance": "复习目标完成了，也给自己留了些余力。",
		"barely_survived": "这一周走完了。下次换个安排，再试试看。",
		"collapsed": "这次的安排没能撑下去。先停在这里，下次换个节奏。",
		"study_shortfall": "这一周走完了，复习目标还没完成。",
	}.get(ending_id, "这一局先记到这里。")
	if history.is_empty():
		return result + "\n还没有可回顾的日记录。"
	var meals := 0
	var skipped := 0
	var early := 0
	var late := 0
	var last_day := 0
	var settled_days := {}
	for raw in history:
		if not raw is Dictionary or typeof(raw.get("day")) != TYPE_INT or raw["day"] < 1 or raw["day"] > 7:
			continue
		last_day = maxi(last_day, raw["day"])
		if not settled_days.has(raw["day"]) or (not settled_days[raw["day"]].get("meals") is Array and raw.get("meals") is Array):
			settled_days[raw["day"]] = raw
	if last_day == 0:
		return result + "\n选餐记录的日期未记清。"
	var book := MealRecords.capture(history, [], last_day)
	var uncertain := false
	for day in book["days"]:
		if not settled_days.has(day["day"]):
			continue
		meals += day["eaten"]
		skipped += day["skipped"]
		uncertain = uncertain or not settled_days[day["day"]].get("meals") is Array or day["unknown"] > 0 or day["unrecorded"] > 0 or day["unplaced"] > 0
		var sleep_value: Variant = settled_days[day["day"]].get("sleep")
		var sleep: Dictionary = sleep_value if sleep_value is Dictionary else {}
		early += 1 if sleep.get("id") == "sleep_early" else 0
		late += 1 if sleep.get("id") == "night_study" else 0
	var facts := "这 %d 天吃了 %d 餐。" % [settled_days.size(), meals]
	if uncertain:
		facts = "这 %d 天已确认 %d 餐。" % [settled_days.size(), meals]
	if early > 0:
		facts += "有 %d 晚选择早点睡。" % early
	if late > 0:
		facts += "有 %d 晚继续复习。" % late
	if skipped > 0:
		facts += "另外跳过了 %d 餐。" % skipped
	if uncertain:
		facts += "另有选餐记录未记全，不能当成没吃。"
	if not book["notes"].is_empty():
		facts += " ".join(book["notes"])
	return result + "\n" + facts
