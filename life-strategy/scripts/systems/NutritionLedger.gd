class_name NutritionLedger
extends RefCounted

## Compatibility name for the daily fact presenter. Does not evaluate meals.
const Records := preload("res://scripts/systems/MealRecordPresenter.gd")
const EXPECTED_MEALS := 3


static func summarize(records: Array[Dictionary]) -> Dictionary:
	var book := Records.capture([], records, 1)
	var day: Dictionary = book["days"][0]
	var view := Records.view(book, 1)
	return {
		"metrics": {
			"expected_meals": EXPECTED_MEALS,
			"eaten_meals": day["eaten"],
			"skipped_meals": day["skipped"],
			"unknown_meals": day["unknown"],
			"unrecorded_meals": day["unrecorded"],
			"unplaced_records": day["unplaced"],
		},
		"observation": _observation(day),
		"action": "",
		"detail_text": _detail_text(day, view["notes"]),
		"basis": "这里只记录已确认的选餐。成分与份量尚未核对，暂不作营养评价。",
	}


static func _observation(day: Dictionary) -> String:
	if day["unknown"] > 0 or day["unplaced"] > 0:
		return "已记下 %d 餐，%d 餐没吃；另有记录未记清。" % [day["eaten"], day["skipped"]]
	if day["skipped"] > 0:
		return "今天" + String(day["summary"])
	if day["eaten"] == 0:
		return "还没有确认的餐次。"
	return "今天三顿都吃了。" if day["eaten"] == 3 else "已记下 %d 餐。" % day["eaten"]


static func _detail_text(day: Dictionary, notes: Array) -> String:
	var lines: Array[String] = ["选餐记录", "吃了 %d 餐｜跳过 %d 餐" % [day["eaten"], day["skipped"]]]
	var meal_names := {"breakfast": "早餐", "lunch": "午餐", "dinner": "晚餐"}
	for row in day["rows"]:
		var parts: Array[String] = [meal_names[row["phase"]]]
		if row["status"] == "skipped":
			parts.append("跳过")
		else:
			if not row["source"].is_empty():
				parts.append(row["source"])
			parts.append(String(row["text"]).replace("\n", "｜"))
			if not row["payment"].is_empty():
				parts.append(row["payment"])
		lines.append("｜".join(parts))
	for note in notes:
		lines.append(String(note))
	return "\n".join(lines)
