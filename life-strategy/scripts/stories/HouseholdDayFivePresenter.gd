extends RefCounted

const Day := preload("res://scripts/stories/HouseholdDayFive.gd")
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const Study := preload("res://scripts/stories/HouseholdStudyPresenter.gd")
const Worktop := preload("res://scripts/stories/HouseholdWorktop.gd")


static func resume(game: Node) -> bool:
	if not game.is_node_ready() or not game._household() or game.day != 5 or game._new_day_pending: return false
	var state: Dictionary = game.household_day_five
	if not state["pending"].is_empty():
		_show_reply(game)
		return true
	if not state["active"].is_empty():
		_show_guide(game)
		return true
	if game.phase != "breakfast_source" or state["intro"] not in ["pending", "details"]: return false
	state["intro"] = "details"
	var generation: int = game._save_generation
	var body: String = Day.NEED + "\n\n" + game.shared_meal.summary()
	if game.shared_meal.plan.is_empty(): body += "\n周阿姨：‘午后想问问老陈，晚上有没有空一起吃。’"
	game._show_story_dialog("今天想吃得顺口些", body, [{"id": "look", "text": "看看今天能选的做法"}, {"id": "back", "text": "今天先自己安排"}], func(choice: String) -> void:
		if generation != game._save_generation or state["intro"] != "details" or game.day != 5 or game.phase != "breakfast_source": return
		state["intro"] = "done"
		state["intent"] = "look" if choice == "look" else "own"
		game._queue_autosave()
		if choice == "look": open_guide(game)
	)
	game._queue_autosave()
	return true


static func open_guide(game: Node, ids: Array = [], storage: String = "eat_now", plan: Dictionary = {}) -> bool:
	if not game.is_node_ready() or not game._household() or game.day != 5: return false
	if not game._is_source_phase() and not game._is_meal_phase(): return false
	var kind: String = "source" if game._is_source_phase() else ("cooking" if not plan.is_empty() else "menu")
	if kind != "source" and ids != game.selected_food_ids: return false
	if kind == "cooking" and (game.current_source_id != "home_kitchen" or not Facts.validate(plan, ids, game._story_food_catalog())): return false
	game.household_day_five["active"] = {"kind": kind, "day": 5, "phase": game.phase, "source": game.current_source_id, "ids": ids.duplicate(), "storage": storage, "plan": plan.duplicate(true)}
	game._queue_autosave()
	_show_guide(game)
	return true


static func after_meal(game: Node, meal: Dictionary) -> void:
	if not game.is_node_ready() or game._new_day_pending or game.day != 5: return
	var token: String = meal["phase"]
	if game.household_day_five["acknowledged"].has(token): return
	game.household_day_five["pending"] = token
	game._queue_autosave()
	_show_reply(game)


static func after_invitation(game: Node) -> void:
	if not game.is_node_ready() or game._new_day_pending or game.day != 5 or Day.invitation_reply(game.shared_meal.history).is_empty(): return
	game.household_day_five["pending"] = "invitation"
	game._queue_autosave()
	_show_reply(game)


static func _show_reply(game: Node) -> void:
	var token: String = game.household_day_five["pending"]
	var body := Day.invitation_reply(game.shared_meal.history) if token == "invitation" else ""
	if token != "invitation":
		for meal in game.today_meal_records:
			if meal["phase"] == token: body = String(meal.get("day_five_experience", {}).get("response", ""))
	if body.is_empty(): return
	var generation: int = game._save_generation
	game._show_story_dialog("老陈回话了" if token == "invitation" else "这顿吃完，周阿姨说", body, [{"id": "close", "text": "继续安排"}], func(_choice: String) -> void:
		if generation == game._save_generation and Day.acknowledge(game.household_day_five, token): game._queue_autosave()
	)


static func _show_guide(game: Node) -> void:
	var back: Dictionary = game.household_day_five["active"].duplicate(true)
	var generation: int = game._save_generation
	var page := Worktop.new()
	page.name = "DayFiveGuide"
	game._present_workspace(page, func() -> void:
		if _current(game, page, generation): _leave(game)
	)
	page.title_label.text = "今天的做法与约定"
	page.subtitle_label.text = "先听听想吃什么，再按现有条件选"
	page.close_button.text = "回到配方" if back["kind"] == "cooking" else "继续自己安排"
	page.body.add_child(HouseholdUI.label(Day.NEED, 23))
	if back["kind"] == "source":
		HouseholdUI.section(page.body, "先选个地方看看")
		for id in ["home_kitchen", "breakfast_shop", "community_canteen", "home_fridge", "local_market"]:
			if not game._source_disabled_reason(id, game._current_meal_phase()).is_empty(): continue
			var source: Dictionary = game._effective_meal_source(id)
			var button := HouseholdUI.button("%s · 查看菜单，确认开饭才结算" % source["name"], id)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			page.body.add_child(button)
			button.pressed.connect(func() -> void:
				if not _current(game, page, generation): return
				game.household_day_five["active"] = {}
				game._close_workspace(false)
				game._choose_meal_source(id)
			)
	else:
		var foods: Dictionary = game._story_food_catalog()
		HouseholdUI.section(page.body, "这份菜单里的做法")
		var found := 0
		for id in game.hand:
			if id not in Day.SOFT_FOODS and not back["ids"].has(id): continue
			var recipe: Dictionary = Facts.freeze(back["ids"], foods, back["plan"]) if back["kind"] == "cooking" and back["ids"].has(id) else {}
			if game.current_source_id == "home_fridge": recipe = Study._stock_facts(game, [id])
			var method: Dictionary = Day.methods([id], [foods[id]["name"]], foods, game.current_source_id, recipe)[0]
			if not back["ids"].has(id) and not Day.is_adapted(method): continue
			found += 1
			var row := HBoxContainer.new()
			page.body.add_child(row)
			var art := HouseholdUI.image(HouseholdUI.food_texture(foods[id]), 68)
			art.custom_minimum_size.x = 68
			row.add_child(art)
			var status: String = "已经选入" if back["ids"].has(id) else ("可回菜单选择" if game._can_add_food(id) else "需先调整餐盘或材料")
			row.add_child(HouseholdUI.label("%s · %s\n%s" % [foods[id]["name"], method["method"] if method["basis"] != "unrecorded" else "做法未记录", status], 22))
		if found == 0: HouseholdUI.note(page.body, "这份菜单暂没有这些做法，可以照现有选择吃，也可以回去换个地方看看。")
	HouseholdUI.section(page.body, "今晚的约定")
	HouseholdUI.note(page.body, game.shared_meal.summary())
	if game.shared_meal.plan.is_empty():
		page.body.add_child(HouseholdUI.label("午饭后的行动页可先问老陈，再去合练。约饭不占整段安排，实际同桌后才记完成。", 22))
	page.body.add_child(HouseholdUI.label("这是周阿姨今天的个人困难和喜好；做法顺口，也还要看搭配与份量。", 21, HouseholdUI.MUTED))
	page.close_button.call_deferred("grab_focus")


static func _current(game: Node, page: Control, generation: int) -> bool:
	return is_instance_valid(page) and page == game._workspace and page.visible and not page.is_queued_for_deletion() and generation == game._save_generation and not game.household_day_five["active"].is_empty()


static func _leave(game: Node) -> void:
	var back: Dictionary = game.household_day_five["active"].duplicate(true)
	game.household_day_five["active"] = {}
	game._queue_autosave()
	game._close_workspace(false)
	if back["kind"] == "cooking":
		var ids: Array[String] = []
		ids.assign(back["ids"])
		game._show_cooking_choice(ids, back["storage"], back["plan"])
		game._workspace.learning_button.call_deferred("grab_focus")
	else:
		game._render_phase()
		var target: Control = game._active_stage.find_child("MealStudy", true, false) if is_instance_valid(game._active_stage) else null
		if target != null: target.call_deferred("grab_focus")
		else: game.menu_button.call_deferred("grab_focus")
