class_name HouseholdLearningFlow
extends RefCounted

const Kitchen := preload("res://scripts/stories/KitchenStock.gd")
const OPENING_BATCH := "before_week_greens"


static func initial_state() -> Dictionary:
	return {"version": 1, "opening_stage": "pending", "opening_choice": ""}


static func legacy_state() -> Dictionary:
	return {"version": 1, "opening_stage": "legacy", "opening_choice": ""}


static func valid(value: Variant, household: bool) -> bool:
	if not value is Dictionary: return false
	if not household: return value.is_empty()
	if value.size() != 3 or typeof(value.get("version")) != TYPE_INT or value["version"] != 1: return false
	var stage: Variant = value.get("opening_stage")
	if stage not in ["pending", "decision", "breakfast", "done", "legacy"]: return false
	var choice: Variant = value.get("opening_choice")
	return choice in ["discard", "leave"] if stage in ["breakfast", "done"] else choice == ""


static func opening_batch(stock: KitchenStock) -> Dictionary:
	for batch in stock.batches:
		if batch.get("id") == OPENING_BATCH: return batch.duplicate(true)
	return {}


static func opening_body(stock: KitchenStock) -> String:
	var batch := opening_batch(stock)
	return "周阿姨：‘这盘菜闻着还行，今天还能吃吗？’\n\n保存记录\n%s\n\n这份菜保存不当，不供食用。闻着正常也不能证明安全，再烧开不能保证消除危害。\n先决定怎么处置，再给自己安排另一顿早餐。" % String(batch.get("note", "这份熟食的保存记录需要核对。"))


static func matches_save(value: Dictionary, stock: Dictionary, day: int, phase: String) -> bool:
	if value.get("opening_stage") in ["decision", "breakfast"] and (day != 1 or phase != "breakfast_source"): return false
	if value.get("opening_choice") != "discard": return true
	var disposals := 0
	for row in stock.get("history", []):
		if row is Dictionary and row.get("action") == "discard" and row.get("day") == 1 and row.get("batch") is Dictionary and row["batch"].get("id") == OPENING_BATCH:
			disposals += int(row["batch"].get("quantity", 0))
	for batch in stock.get("batches", []):
		if batch is Dictionary and batch.get("id") == OPENING_BATCH: return disposals == 1 and batch.get("quantity") == 0
	return false


static func ready_batches(stock: KitchenStock, day: int, hour: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for batch in stock.batches:
		if int(batch.get("quantity", 0)) <= 0 or not batch.has("made_hour") or int(batch["made_hour"]) >= hour: continue
		if Kitchen.classify(batch, day, hour) == "needs_reheat": result.append(batch.duplicate(true))
	return result


static func preparation_notice(stock: KitchenStock, foods: Dictionary, day: int, hour: int, effort: int) -> String:
	var batches := ready_batches(stock, day, hour)
	if batches.is_empty(): return ""
	var names: Array[String] = []
	var quantities := {}
	for batch in batches:
		var food_name := String(foods.get(batch.get("food_id"), {}).get("name", "熟食"))
		if not names.has(food_name): names.append(food_name)
		quantities[food_name] = int(quantities.get(food_name, 0)) + int(batch["quantity"])
	var shown: Array[String] = []
	for food_name in names.slice(0, 2): shown.append("%s×%d" % [food_name, quantities[food_name]])
	var label := "、".join(shown) + ("等%d样" % names.size() if names.size() > 2 else "")
	return "冷藏：%s\n取用耗%d精力\n先看保存记录，彻底再热。" % [label, effort]


static func day_recap(stock: KitchenStock, learning: Dictionary, day: int, hour: int) -> Dictionary:
	var cooked := 0
	var prepared := 0
	var reheated := 0
	var discarded := 0
	var opening_discarded := 0
	for row in stock.history:
		if row.get("day") != day: continue
		match row.get("action"):
			"cook":
				cooked += 1
				if not row.get("prepared", []).is_empty() and row["prepared"][0].get("storage") == "fridge": prepared += 1
			"reheat_and_eat":
				for batch in row.get("batches", []):
					if batch.get("reheat_count") == 1:
						reheated += 1
						break
			"discard":
				var batch: Dictionary = row.get("batch", {})
				if batch.get("id") == OPENING_BATCH: opening_discarded += int(batch.get("quantity", 0))
				else: discarded += int(batch.get("quantity", 0))
	var lines: Array[String] = []
	if opening_discarded > 0:
		lines.append("已丢弃开局前保存不当的%d份熟食。" % opening_discarded)
	elif day == 1 and learning.get("opening_choice") == "leave" and int(opening_batch(stock).get("quantity", 0)) > 0:
		lines.append("开局那份菜暂未处理，仍不供食用。")
	if cooked > 0 or reheated > 0:
		lines.append("今天做饭%d次，其中%d次另备冷藏；再热取用%d餐。" % [cooked, prepared, reheated])
	else:
		lines.append("今天没有做饭或再热熟食，餐次按实际记录保留。")
	if discarded > 0: lines.append("另丢弃了%d份熟食，保存记录可回看。" % discarded)
	var remaining := ready_batches(stock, day, hour)
	if not remaining.is_empty():
		lines.append("本周还有留存熟食未取用。" if day >= 7 else "冷藏还有留存熟食，下一餐先看保存记录再安排。")
	elif day < 7:
		lines.append("下次先看人数与库存，再决定做当餐还是另备一份。")
	return {"text": "\n".join(lines), "cooked": cooked, "prepared": prepared, "reheated_meals": reheated, "discarded": discarded, "opening_discarded": opening_discarded}
