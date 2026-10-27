class_name DecisionCostPreview
extends RefCounted

## Presentation of explicit game costs. Meal money comes from MealResolver;
## food effects and elapsed-period effects remain separate from these costs.
const Balance := preload("res://scripts/systems/GameplayBalanceRules.gd")


static func meal(record: Dictionary, source: Dictionary, inventory: Dictionary, caption: String, recipe_next: bool = false) -> Dictionary:
	var cash := int(record.get("total_cost", 0))
	var fee := int(record.get("source_fee", 0))
	var effort := maxi(0, -int(source.get("energy", 0)))
	var money := "¥%d" % cash
	if fee > 0: money += "（含%s%d）" % ["配送" if source.get("id") == "takeout" or source.get("stage_kind") == "takeout" else "附加", fee]
	var verb := "制作" if source.get("stage_kind") == "cook" else ("取用" if source.get("payment_mode") == "stock" else "用餐")
	var headline := "%s · %s耗%d精力" % [money, verb, effort]
	var quantities: Array[String] = []
	for name in inventory: quantities.append("%s×%d" % [name, int(inventory[name])])
	var stock_line := "现有库存不变" if quantities.is_empty() else "%s：%s" % [caption, "、".join(quantities)]
	var detail := "确认后花费%s；%s消耗%d精力。食物本身的游戏效果另计。\n%s。" % [money, verb, effort, stock_line]
	if recipe_next: detail += "\n这里列当餐食材，调味和另备份量在配方页确认。"
	return {"cash_cost": cash, "source_fee": fee, "source_effort": effort, "inventory": inventory.duplicate(true), "inventory_caption": caption, "recipe_next": recipe_next, "headline": headline, "stock_line": stock_line, "text": headline + "\n" + stock_line, "detail": detail}


static func choice(payload: Dictionary, mode: String) -> String:
	var cost := int(payload.get("cost", 0))
	var effort := maxi(0, -int(payload.get("energy", 0)))
	if mode == "sleep":
		var costs: Array[String] = ["¥%d" % cost]
		if effort > 0: costs.append("精力−%d" % effort)
		if int(payload.get("satiety", 0)) < 0: costs.append("饱腹%d" % int(payload["satiety"]))
		if int(payload.get("stress", 0)) > 0: costs.append("压力+%d" % int(payload["stress"]))
		if int(payload.get("mood", 0)) < 0: costs.append("心情%d" % int(payload["mood"]))
		return " · ".join(costs)
	var slots := maxi(0, int(payload.get("slots", 1)))
	var period_effort := maxi(0, -int(Balance.PERIOD_DELTA["energy"]))
	var period := "占%d安排，时段另耗%d" % [slots, period_effort] if slots > 0 else "不占安排，时段不推进"
	return "¥%d · 行动耗%d精力\n%s" % [cost, effort, period]
