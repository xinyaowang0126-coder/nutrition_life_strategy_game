class_name MealGuidanceAdapter
extends RefCounted

## Reads a detached V2 selection. No drawing cards, changing selection, paying,
## inventory consumption, health-history access, or approval of production data.
const Data := preload("res://scripts/GameData.gd")
const Events := preload("res://scripts/systems/WeeklyEventService.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Suggestions := preload("res://scripts/health/FeasibleSuggestionService.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")


static func build_context(live: Variant, catalog: Dictionary = {}) -> Dictionary:
	if not live is Dictionary:
		return _invalid("input_invalid")
	if typeof(live.get("day")) != TYPE_INT or live["day"] < 1 or live["day"] > Data.TOTAL_DAYS:
		return _invalid("day_invalid")
	if live.get("phase") not in Snapshot.MEAL_PHASES:
		return _invalid("not_selecting")
	if not live.get("source_id") is String or not Data.is_meal_source_available(live["source_id"], live["phase"]):
		return _invalid("source_unavailable")
	if typeof(live.get("balance")) != TYPE_INT or live["balance"] < 0 or live["balance"] > 999:
		return _invalid("balance_invalid")
	if not live.get("hand_ids") is Array or not live.get("selected_ids") is Array or not live.get("inventory") is Dictionary:
		return _invalid("selection_invalid")
	var source := Events.apply_meal_source(live["day"], live["source_id"], Data.get_meal_source(live["source_id"]))
	var uses_stock: bool = source["payment_mode"] == "stock"
	var limit := clampi(int(source["selection_limit"]), 1, 3)
	var pool := Data.get_food_ids_for_context(live["source_id"], live["phase"])
	var hand: Array = live["hand_ids"]
	var selected: Array = live["selected_ids"]
	var seen := {}
	var options: Array[Dictionary] = []
	for id in hand:
		if not id is String or seen.has(id) or not pool.has(id):
			return _invalid("hand_invalid")
		seen[id] = true
		var stock := 0
		if uses_stock:
			var amount: Variant = live["inventory"].get(id, 0)
			if typeof(amount) != TYPE_INT or amount < 0 or amount > 999:
				return _invalid("stock_invalid")
			stock = amount
		var food := Data.get_food(id)
		options.append({"id": id, "name": food["name"], "cost": int(food["cost"]), "stock": stock, "available": not uses_stock or stock > 0, "candidate_snapshots": {}})
	if selected.size() > limit:
		return _invalid("selection_limit")
	seen.clear()
	var total := 0 if uses_stock or selected.is_empty() else int(source["fee"])
	for id in selected:
		if not id is String or seen.has(id) or not hand.has(id):
			return _invalid("selection_invalid")
		seen[id] = true
		if uses_stock and int(live["inventory"].get(id, 0)) <= 0:
			return _invalid("stock_unavailable")
		if not uses_stock:
			total += int(Data.get_food(id)["cost"])
	if total > live["balance"]:
		return _invalid("selection_unaffordable")
	for row in options:
		if not row["available"] or selected.has(row["id"]):
			continue
		var removals: Array = [""] if selected.size() < limit else []
		removals.append_array(selected)
		for remove_id in removals:
			var proposed := selected.duplicate()
			if remove_id != "":
				proposed.erase(remove_id)
			proposed.append(row["id"])
			row["candidate_snapshots"][String(remove_id)] = _snapshot(live, proposed, catalog)
	var context := {
		"valid": true, "reason": "current_selection", "stage": "selecting",
		"day": live["day"], "phase": live["phase"], "source_id": live["source_id"],
		"payment_mode": source["payment_mode"], "balance": live["balance"],
		"fee": 0 if uses_stock else int(source["fee"]), "selection_limit": limit,
		"revision": 0, "selected_ids": selected.duplicate(), "options": options,
		"current_snapshot": _snapshot(live, selected, catalog), "total_cost": total,
	}
	# Include exact snapshots, current hand, price, stock, phase and date. A
	# content token detects changes even when UI revisions restart at zero.
	context["context_token"] = JSON.stringify(context).sha256_text()
	return context


static func resolve_proposal(proposal: Variant, live: Variant, catalog: Dictionary, config: Dictionary, registry: Evidence, date: String, copies: Dictionary, policy: Variant = {}) -> Dictionary:
	if not proposal is Dictionary or proposal.get("verified") != true or not proposal.get("action") is Dictionary:
		return _invalid("proposal_invalid")
	var context := build_context(live, catalog)
	if not context["valid"]:
		return context
	var fresh := Suggestions.find_option(context, config, registry, date, copies, policy)
	if not fresh["verified"] or (fresh["action"] != proposal["action"] and fresh["alternative"] != proposal["action"]):
		return _invalid("proposal_stale")
	# This resolves an optional selection only. The normal game confirmation
	# remains the sole consumer of money, stock and phase advancement.
	return {"valid": true, "reason": "current_proposal", "selected_ids": proposal["action"]["selection"].duplicate()}


static func _snapshot(live: Dictionary, ids: Array, catalog: Dictionary) -> Dictionary:
	return Snapshot.build(live["day"], {"phase": live["phase"], "source_id": live["source_id"], "food_ids": ids}, catalog)


static func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
