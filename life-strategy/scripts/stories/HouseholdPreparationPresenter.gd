extends RefCounted

const Prep := preload("res://scripts/stories/HouseholdPreparation.gd")
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const Worktop := preload("res://scripts/stories/HouseholdWorktop.gd")


static func resume(game: Node) -> bool:
	if not game.is_node_ready() or not game._household() or game.day not in [6, 7] or game._new_day_pending: return false
	var state: Dictionary = game.household_preparation
	if state["pending"] != "":
		_show_reply(game)
		return true
	if not state["active"].is_empty():
		_show_planner(game)
		return true
	if game.day != 6 or game.phase != "breakfast_source" or state["intro"] not in ["pending", "details"]: return false
	state["intro"] = "details"
	var generation: int = game._save_generation
	game._show_story_dialog("给下一餐留个安排", "周阿姨：‘明晚就要登台了。今天多做一份，明天就省点事。先看看家里够不够。’\n\n多做的那份要在上桌前分出，及时冷藏。想每餐现做也可以。", [{"id": "look", "text": "看看库存和下一餐"}, {"id": "back", "text": "先安排这顿饭"}], func(choice: String) -> void:
		if generation != game._save_generation or state["intro"] != "details": return
		state["intro"] = "done"
		game._queue_autosave()
		if choice == "look": open_planner(game)
	)
	game._queue_autosave()
	return true


static func open_planner(game: Node, ids: Array = [], storage: String = "eat_now", plan: Dictionary = {}) -> bool:
	if not game.is_node_ready() or not game._household() or game.day != 6 or game._new_day_pending or game.household_preparation["pending"] != "": return false
	if not game._is_source_phase() and not game._is_meal_phase(): return false
	var kind: String = "source" if game._is_source_phase() else ("cooking" if not plan.is_empty() else "menu")
	if kind != "source" and ids != game.selected_food_ids: return false
	if kind == "cooking" and (game.current_source_id != "home_kitchen" or not Facts.validate(plan, ids, game._story_food_catalog())): return false
	game.household_preparation["active"] = {"kind": kind, "day": 6, "phase": game.phase, "source": game.current_source_id, "ids": ids.duplicate(), "storage": storage, "plan": plan.duplicate(true)}
	game._queue_autosave()
	_show_planner(game)
	return true


static func after_meal(game: Node) -> void:
	if not game._household() or game.day not in [6, 7]: return
	if game.household_preparation["plans"].is_empty(): return
	var token := Prep.resolve(game.household_preparation, Prep.records_for(game.capture_game_save()["payload"]))
	if token == "" or not game.is_node_ready() or game._new_day_pending: return
	game.household_preparation["pending"] = token
	game._queue_autosave()
	_show_reply(game)


static func _show_reply(game: Node) -> void:
	var token: String = game.household_preparation["pending"]
	var row := Prep.entry(game.household_preparation, token)
	var generation: int = game._save_generation
	var next := Prep.target(token)
	var quote := "周阿姨：‘留的这份正好吃。’" if row["result"]["status"] in ["used", "part_used"] else "周阿姨：‘这顿换点别的吃。’"
	game._show_story_dialog("这餐吃了什么", "第%d天%s\n%s\n\n%s" % [next["day"], Prep.NAMES[next["meal"]], Prep.result_text(row["result"]), quote], [{"id": "close", "text": "继续安排"}], func(_choice: String) -> void:
		if generation == game._save_generation and Prep.acknowledge(game.household_preparation, token): game._queue_autosave()
	)


static func _show_planner(game: Node) -> void:
	var back: Dictionary = game.household_preparation["active"].duplicate(true)
	var generation: int = game._save_generation
	var page := Worktop.new()
	page.name = "PreparationPlanner"
	game._present_workspace(page, func() -> void:
		if _current(game, page, generation): _leave(game)
	)
	page.title_label.text = "下一餐怎么吃"
	var meal: String = game._current_meal_phase()
	var next := Prep.target(meal)
	page.subtitle_label.text = "眼下是%s，下一餐是第%d天%s" % [Prep.NAMES[meal], next["day"], Prep.NAMES[next["meal"]]]
	page.close_button.text = "回到配方" if back["kind"] == "cooking" else "回到这一餐"
	HouseholdUI.section(page.body, "先看家里有多少")
	var inventory: Array[String] = []
	for id in game.kitchen.ingredients:
		inventory.append("%s×%d" % [HouseholdUI.ingredient_name(id), game.kitchen.ingredients[id]])
	HouseholdUI.note(page.body, "现有食材\n" + "、".join(inventory))
	var ready: Array[Dictionary] = HouseholdLearningFlow.ready_batches(game.kitchen, 6, game._story_clock())
	var names: Array[String] = []
	for batch in ready: names.append("%s×%d" % [game._story_food_catalog()[batch["food_id"]]["name"], batch["quantity"]])
	HouseholdUI.note(page.body, "冷藏熟食：%s\n吃之前要查看保存时间，再彻底再热。" % ("、".join(names) if not names.is_empty() else "暂无"))
	if back["kind"] == "cooking":
		HouseholdUI.section(page.body, "对照这份配方")
		var served: int = game._served_portions()
		var portions: int = served + (0 if back["storage"] == "eat_now" else 1)
		var needs: Dictionary = game.kitchen.needs(back["ids"], game._story_food_catalog())
		var needed: Array[String] = []
		for id in needs: needed.append("%s×%d / 库存%d" % [HouseholdUI.ingredient_name(id), needs[id] * portions, game.kitchen.ingredients.get(id, 0)])
		page.body.add_child(HouseholdUI.label("当餐%d人份%s，本次共做%d份\n%s" % [served, "＋另留1份" if portions > served else "，不另留", portions, "、".join(needed)], 22))
		HouseholdUI.note(page.body, "食材和调味料够用。" if game.kitchen.can_prepare(back["ids"], game._story_food_catalog(), portions, back["plan"]) else "食材或调味库存不足，回配方减些份数，或先补货。")
		page.body.add_child(HouseholdUI.label({"eat_now": "现在只做这顿。", "fridge": "另留的一份在上桌前分装，1小时内放入4℃冰箱，下次吃之前彻底再热。", "counter": "选了留在灶台。到下一餐已过5小时，届时只能丢弃。"}[back["storage"]], 22, HouseholdUI.DANGER if back["storage"] == "counter" else HouseholdUI.MUTED))
	HouseholdUI.section(page.body, "记下下一餐的打算")
	page.body.add_child(HouseholdUI.label("可以用现有的冷藏熟食，也可以把这餐多做的一份留到下餐。", 21, HouseholdUI.MUTED))
	var planned := Prep.entry(game.household_preparation, meal)
	for choice in [{"id": "stock", "text": "下一餐吃留存的熟食"}, {"id": "later", "text": "下一餐到时再选"}, {"id": "clear", "text": "暂时不定"}]:
		var button := HouseholdUI.button(choice["text"], choice["id"])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		HouseholdUI.style_button(button, false, planned.get("choice", "clear") == choice["id"])
		page.body.add_child(button)
		button.pressed.connect(func() -> void:
			if not _current(game, page, generation): return
			Prep.choose(game.household_preparation, meal, choice["id"], game.kitchen.batches, game._story_clock())
			game._queue_autosave()
			_show_planner(game)
		)
	page.body.add_child(HouseholdUI.label("这里只定计划。回配方确认才会做饭、扣材料；下餐也可以改选。", 21, HouseholdUI.MUTED))
	page.close_button.call_deferred("grab_focus")


static func _current(game: Node, page: Control, generation: int) -> bool:
	return is_instance_valid(page) and page == game._workspace and page.visible and not page.is_queued_for_deletion() and generation == game._save_generation and not game.household_preparation["active"].is_empty()


static func _leave(game: Node) -> void:
	var back: Dictionary = game.household_preparation["active"].duplicate(true)
	game.household_preparation["active"] = {}
	game._queue_autosave()
	game._close_workspace(false)
	if back["kind"] == "cooking":
		var ids: Array[String] = []
		ids.assign(back["ids"])
		game._show_cooking_choice(ids, back["storage"], back["plan"])
		game._workspace.learning_button.call_deferred("grab_focus")
	else:
		game._render_phase()
		var button: Control = game._active_stage.find_child("MealStudy", true, false) if is_instance_valid(game._active_stage) else null
		if button != null: button.call_deferred("grab_focus")
		else: game.menu_button.call_deferred("grab_focus")
