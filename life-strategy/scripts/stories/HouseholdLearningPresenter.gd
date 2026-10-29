extends RefCounted

const Flow := preload("res://scripts/stories/HouseholdLearningFlow.gd")


static func resume(game: Node) -> void:
	if not game.is_node_ready() or not game._household() or game.day != 1 or game.phase != "breakfast_source" or game._new_day_pending: return
	var stage: String = game.household_learning.get("opening_stage", "legacy")
	if stage == "pending":
		if int(Flow.opening_batch(game.kitchen).get("quantity", 0)) <= 0:
			game.household_learning = Flow.legacy_state()
			game._queue_autosave()
			return
		game.household_learning["opening_stage"] = "decision"
		stage = "decision"
	if stage == "decision":
		var generation: int = game._save_generation
		game._show_story_dialog("灶台上的隔夜菜", Flow.opening_body(game.kitchen), [
			{"id": "discard", "text": "丢弃这份菜，换一顿早餐"},
			{"id": "back", "text": "先放着，安排别的早餐"},
		], func(choice: String) -> void:
			if generation != game._save_generation: return
			if resolve_opening(game, "leave" if choice == "back" else choice): resume(game)
		)
		game._queue_autosave()
	elif stage == "breakfast":
		_present_breakfast(game)


static func resolve_opening(game: Node, choice: String) -> bool:
	if not game._household() or game.day != 1 or game.phase != "breakfast_source" or game.household_learning.get("opening_stage") != "decision" or choice not in ["discard", "leave"]: return false
	if choice == "discard" and not game.kitchen.discard(Flow.OPENING_BATCH, game.day): return false
	game.household_learning["opening_choice"] = choice
	game.household_learning["opening_stage"] = "breakfast"
	game._queue_autosave()
	return true


static func breakfast_choices(game: Node) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for id in ["home_kitchen", "breakfast_shop", "home_fridge"]:
		if not game._source_disabled_reason(id, "breakfast").is_empty(): continue
		var source: Dictionary = game._effective_meal_source(id)
		var menu: Array = game._hand_for_source(id, "breakfast")
		var cheapest := ""
		var cost := 1000000
		for food_id in menu:
			var food: Dictionary = game._story_food(food_id)
			var price: int = int(food.get("cost", 0)) + int(source.get("fee", 0))
			if source.get("payment_mode") == "stock":
				if game._stock_count(food_id, id) <= 0: continue
			elif price > int(game.state["balance"]): continue
			if price < cost:
				cheapest = food_id
				cost = price
		if cheapest.is_empty(): continue
		var food: Dictionary = game._story_food(cheapest)
		var effort: int = maxi(0, -int(source.get("energy", 0)))
		var label := "%s：%s¥%d\n本次出门耗%d精力" % [source["name"], food["name"], cost, effort]
		if source.get("payment_mode") == "stock":
			label = "%s：%s%s%d份\n%s耗%d精力" % [source["name"], food["name"], "可做" if id == "home_kitchen" else "现有", game._stock_count(cheapest, id), "本次制作" if id == "home_kitchen" else "取用", effort]
		choices.append({"id": id, "text": label})
	return choices


static func _present_breakfast(game: Node) -> void:
	var choices := breakfast_choices(game)
	choices.append({"id": "close", "text": "回家自己选个地方"})
	var decision := "这份菜已经丢弃。" if game.household_learning.get("opening_choice") == "discard" else "这份菜先放着，仍不供食用。"
	var generation: int = game._save_generation
	game._show_story_dialog("先给自己换一顿早餐", decision + "\n\n下面各列一样当前能选的食物。进菜单后再搭配，确认开饭时才结算。", choices, func(choice: String) -> void:
		if generation != game._save_generation or game.day != 1 or game.phase != "breakfast_source" or game.household_learning.get("opening_stage") != "breakfast": return
		var available := breakfast_choices(game)
		if choice != "close" and not available.any(func(row: Dictionary) -> bool: return row["id"] == choice):
			_present_breakfast(game)
			return
		game.household_learning["opening_stage"] = "done"
		game._queue_autosave()
		if choice != "close": game._choose_meal_source(choice)
	)
	game._queue_autosave()
