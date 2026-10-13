class_name DietPatternPresenter
extends RefCounted

## Fact-only views of an owned ledger. No arbitrary caller-supplied assessment,
## live profiles, gameplay values, dietary targets or recommendation text.
const Ledger := preload("res://scripts/health/DietPatternLedger.gd")
const PHASE_NAMES := {"breakfast": "早饭", "lunch": "午饭", "dinner": "晚饭"}
const STATUS_NAMES := {"eaten": "吃了", "skipped": "没吃", "legacy_unknown": "旧记录", "unrecorded": "未记"}


static func day_view(ledger: Ledger, day: int) -> Dictionary:
	return _view(ledger.day_view(day))


static func week_view(ledger: Ledger, through_day: int = 7) -> Dictionary:
	return _view(ledger.week_view(through_day))


static func _view(report: Dictionary) -> Dictionary:
	if not report["valid"]:
		return {"valid": false, "title": "餐次记录", "summary": "记录暂时打不开。", "rows": [], "composition": [], "notes": []}
	var view := {"valid": true, "title": "第 %d 天" % report["first_day"] if report["scope"] == "day" else "这一周 · 第 1–%d 天" % report["last_day"], "summary": "还没有确认的餐次。", "rows": [], "composition": [], "notes": []}
	var counts: Dictionary = report["regularity"]
	if report["scope"] == "day" and counts["skipped"] > 0:
		var names: Array[String] = []
		for meal in report["meals"]:
			if meal["status"] == "skipped":
				names.append(PHASE_NAMES[meal["phase"]])
		view["summary"] = "今天三顿都没吃。" if names.size() == 3 else "、".join(names) + "没吃。"
	elif counts["eaten"] > 0 or counts["skipped"] > 0:
		view["summary"] = "已记下 %d 顿，%d 顿没吃。" % [counts["eaten"], counts["skipped"]] if report["scope"] == "week" else "已记下 %d 顿。" % counts["eaten"]
	for meal in report["meals"]:
		var names: Array[String] = []
		for ingredient in meal["ingredients"]:
			names.append(ingredient["name"])
		view["rows"].append({"day": meal["day"], "phase": meal["phase"], "title": PHASE_NAMES[meal["phase"]], "status": STATUS_NAMES[meal["status"]], "ingredients": "、".join(names), "as_of_date": meal["as_of_date"], "model_version": meal["model_version"]})
	var diversity: Dictionary = report["diversity"]
	for segment in diversity["segments"]:
		var lines: Array[String] = []
		for ingredient in segment["ingredients"]:
			lines.append("%s · %d 餐" % [ingredient["name"], ingredient["meal_keys"].size()])
		var count: Variant = segment["unique_ingredient_count"]
		view["composition"].append({"model_version": segment["model_version"], "text": "配料还在核对。" if count == null else "记到 %d 种配料" % count, "lines": lines})
		if not segment["conflicting_ingredient_ids"].is_empty():
			view["notes"].append("有配料分类不一致，没算进种数。")
	if diversity["segments"].is_empty():
		view["composition"].append({"model_version": "", "text": "没有配料记录。" if diversity["status"] == "not_applicable" else "配料还在核对。", "lines": []})
	if diversity["status"] == "segmented":
		view["notes"].append("资料版本不同，配料分开记。")
	if not diversity["unknown_portion_meal_keys"].is_empty():
		view["notes"].append("%d 餐份量未标。" % diversity["unknown_portion_meal_keys"].size())
	if counts["unrecorded"] > 0:
		view["notes"].append("未记的餐次，不能当成没吃。")
	if counts["legacy_unknown"] > 0 or report["unplaced_legacy_count"] > 0:
		view["notes"].append("旧记录只保留餐次，配料未知。")
	if report["unplaced_legacy_count"] > 0:
		view["notes"].append("%d 条旧记录没标完整日期或餐次。" % report["unplaced_legacy_count"])
	return view
