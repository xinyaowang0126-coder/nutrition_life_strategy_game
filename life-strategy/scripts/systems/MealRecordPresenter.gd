class_name MealRecordPresenter
extends RefCounted

## Normal-play facts only. Reads frozen names/source/payment, never current
## cards, legacy scores/tags, health catalogs or reconstructed snapshots.
const PHASES := ["breakfast", "lunch", "dinner"]
const TITLES := {"breakfast": "早饭", "lunch": "午饭", "dinner": "晚饭"}


static func capture(history: Variant, today: Variant, current_day: int) -> Dictionary:
	if not history is Array or not today is Array or current_day < 1 or current_day > 7:
		return {"valid": false, "days": [], "last_day": 0, "notes": ["记录暂时打不开。"]}
	var by_day := {}
	var notes: Array[String] = []
	for entry in history:
		if not entry is Dictionary or typeof(entry.get("day")) != TYPE_INT or entry["day"] < 1 or entry["day"] > current_day or not entry.get("meals") is Array:
			if not notes.has("有旧记录没标完整日期，未排进餐次。"):
				notes.append("有旧记录没标完整日期，未排进餐次。")
			continue
		var day: int = entry["day"]
		if by_day.has(day):
			notes.append("第 %d 天的记录有重复，请按已确认餐次查看。" % day)
			continue
		by_day[day] = entry["meals"].duplicate(true)
	# Summary/ending keep today's array after freezing the same day in history.
	# The settled day is authoritative; never add it to itself again.
	if not by_day.has(current_day):
		by_day[current_day] = today.duplicate(true)
	var days: Array[Dictionary] = []
	for day in range(1, current_day + 1):
		days.append(_day(day, by_day.get(day, [])))
	return {"valid": true, "days": days, "last_day": current_day, "notes": notes, "basis": "这里只记已确认的选餐。配料资料还在核对。"}


static func view(book: Dictionary, selected_day: int, weekly: bool = false) -> Dictionary:
	if not book.get("valid", false) or selected_day < 1 or selected_day > int(book.get("last_day", 0)):
		return {"valid": false, "title": "选餐记录", "summary": "记录暂时打不开。", "days": [], "notes": []}
	var days: Array[Dictionary] = []
	var eaten := 0
	var skipped := 0
	var unknown := 0
	var unrecorded := 0
	var unplaced := 0
	for day in book["days"]:
		if not weekly and day["day"] != selected_day:
			continue
		days.append(day.duplicate(true))
		eaten += day["eaten"]
		skipped += day["skipped"]
		unknown += day["unknown"]
		unrecorded += day["unrecorded"]
		unplaced += day["unplaced"]
	var summary := "还没有确认的餐次。"
	if eaten > 0 or skipped > 0:
		summary = "已记下 %d 餐，%d 餐没吃。" % [eaten, skipped] if weekly else days[0]["summary"]
	var notes: Array = book["notes"].duplicate()
	if unrecorded > 0:
		notes.append("未记的餐次，不能当成没吃。")
	if unknown > 0:
		notes.append("旧记录的信息不全，配料保持未知。")
	if unplaced > 0:
		notes.append("%d 条旧记录没标餐次，未排进早午晚。" % unplaced)
	return {"valid": true, "title": "这一周的选餐" if weekly else "第 %d 天的选餐" % selected_day, "summary": summary, "days": days, "notes": notes, "basis": book["basis"]}


static func _day(day: int, records: Array) -> Dictionary:
	var slots := {}
	var unplaced := 0
	for record in records:
		if not record is Dictionary or record.get("phase") not in PHASES:
			unplaced += 1
			continue
		var phase: String = record["phase"]
		if slots.has(phase):
			# Contradictory duplicates cannot become two eaten meals or select a
			# convenient price. Exact copies are harmless duplicate delivery.
			if _row(phase, slots[phase]) != _row(phase, record):
				slots[phase] = {"phase": phase, "conflict": true}
		else:
			slots[phase] = record.duplicate(true)
	var rows: Array[Dictionary] = []
	var counts := {"eaten": 0, "skipped": 0, "unknown": 0, "unrecorded": 0}
	var skipped_names: Array[String] = []
	for phase in PHASES:
		var row := _row(phase, slots.get(phase, {}))
		rows.append(row)
		counts[row["status"]] += 1
		if row["status"] == "skipped":
			skipped_names.append(TITLES[phase])
	var summary := "还没有确认的餐次。"
	if not skipped_names.is_empty():
		summary = "三顿都没吃。" if skipped_names.size() == 3 else "、".join(skipped_names) + "没吃。"
	elif counts["eaten"] > 0:
		summary = "三顿都吃了。" if counts["eaten"] == 3 else "已记下 %d 餐。" % counts["eaten"]
	return {"day": day, "rows": rows, "summary": summary, "eaten": counts["eaten"], "skipped": counts["skipped"], "unknown": counts["unknown"], "unrecorded": counts["unrecorded"], "unplaced": unplaced}


static func _row(phase: String, record: Dictionary) -> Dictionary:
	var row := {"phase": phase, "title": TITLES[phase], "status": "unrecorded", "text": "未记", "source": "", "payment": "", "composition": "unknown"}
	if record.is_empty():
		return row
	if not _valid_names(record.get("food_names", [])) or not _valid_names(record.get("food_ids", [])):
		row["status"] = "unknown"
		row["text"] = "旧记录 · 信息未记全"
		return row
	var names := _names(record.get("food_names", []))
	var ids := _names(record.get("food_ids", []))
	var explicit: bool = record.get("skipped") is bool and not record.get("conflict", false)
	if explicit and record["skipped"] and names.is_empty() and ids.is_empty():
		row["status"] = "skipped"
		row["text"] = "没吃"
		return row
	if not explicit or record.get("skipped", false) or (names.is_empty() and ids.is_empty()):
		row["status"] = "unknown"
		row["text"] = "记录不一致" if record.get("conflict", false) else "旧记录 · 信息未记全"
		if not names.is_empty():
			row["text"] += "\n" + "、".join(names)
		return row
	row["status"] = "eaten"
	row["text"] = "、".join(names) if not names.is_empty() else "食物名称未记"
	row["source"] = record["source_name"] if record.get("source_name") is String and not record["source_name"].strip_edges().is_empty() else "来源未记"
	if record.get("uses_stock") is bool and record["uses_stock"]:
		row["payment"] = "使用存粮"
	elif typeof(record.get("total_cost")) == TYPE_INT and record["total_cost"] >= 0:
		row["payment"] = "¥%d" % record["total_cost"]
	else:
		row["payment"] = "消费未记"
	return row


static func _names(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		if not item is String or item.strip_edges().is_empty():
			return []
		result.append(item)
	return result


static func _valid_names(value: Variant) -> bool:
	if not value is Array:
		return false
	for item in value:
		if not item is String or item.strip_edges().is_empty():
			return false
	return true
