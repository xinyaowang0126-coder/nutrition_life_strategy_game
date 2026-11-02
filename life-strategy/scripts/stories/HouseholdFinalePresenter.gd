extends RefCounted

const Finale := preload("res://scripts/stories/HouseholdFinale.gd")
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const Worktop := preload("res://scripts/stories/HouseholdWorktop.gd")


static func resume(game: Node) -> bool:
	if not game.is_node_ready() or not game._household() or game.day != 7 or game._new_day_pending: return false
	var state: Dictionary = game.household_finale
	if state["pending"]:
		_show_reply(game)
		return true
	if not state["active"].is_empty():
		_show_plan(game)
		return true
	if game.phase != "breakfast_source" or state["intro"] not in ["pending", "details"]: return false
	state["intro"] = "details"
	var generation: int = game._save_generation
	game._show_story_dialog("今晚有汇演", "周阿姨：‘歌谱带上了，晚饭后去唱歌。’\n\n排练%d/%d，当前精力%d。演前至少要有%d精力，并留一个安排位。早饭后、午饭后还可以补练或休息。" % [game.state["goal_progress"], game._goal_target(), game.state["energy"], game._story_action("perform")["min_energy"]], [{"id": "look", "text": "看看今天的安排"}, {"id": "back", "text": "先吃早餐"}], func(choice: String) -> void:
		if generation != game._save_generation or state["intro"] != "details": return
		state["intro"] = "done"
		game._queue_autosave()
		if choice == "look": open_plan(game)
	)
	game._queue_autosave()
	return true


static func open_plan(game: Node, ids: Array = [], storage: String = "eat_now", recipe: Dictionary = {}) -> bool:
	if not game.is_node_ready() or not game._household() or game.day != 7 or game._new_day_pending or game.household_finale["pending"] or game.household_preparation["pending"] != "": return false
	if not game._is_source_phase() and not game._is_meal_phase() and not game._is_action_phase(): return false
	var cooking := not recipe.is_empty()
	if cooking and (game.current_source_id != "home_kitchen" or ids != game.selected_food_ids or not Facts.validate(recipe, ids, game._story_food_catalog())): return false
	game.household_finale["active"] = {"kind": "cooking" if cooking else "stage", "day": 7, "phase": game.phase, "source": game.current_source_id, "ids": ids.duplicate() if cooking else [], "storage": storage if cooking else "eat_now", "plan": recipe.duplicate(true)}
	game._queue_autosave()
	_show_plan(game)
	return true


static func after_action(game: Node) -> void:
	if not game.is_node_ready() or not game._household() or game.day != 7 or game.phase != "sleep": return
	if game.household_finale["outcome"].is_empty() or game.household_finale["acknowledged"]: return
	game.household_finale["pending"] = true
	game._queue_autosave()
	_show_reply(game)


static func _show_reply(game: Node) -> void:
	var result: Dictionary = game.household_finale["outcome"]
	var performed: bool = result["kind"] == "performed"
	var title := "汇演结束了" if performed else "今晚没去汇演"
	var reply := "周阿姨：‘今晚先忙别的，歌下次再唱。’" if result["kind"] == "other_choice" else "周阿姨：‘今晚没唱成，下回再去。’"
	var body: String = "周阿姨：‘总算唱完了，回家歇歇。’" if performed else reply + "\n\n" + _outcome_reason(game, result)
	var generation: int = game._save_generation
	game._show_story_dialog(title, body, [{"id": "close", "text": "回家歇一歇"}], func(_choice: String) -> void:
		if generation == game._save_generation and Finale.acknowledge(game.household_finale): game._queue_autosave()
	)


static func _show_plan(game: Node) -> void:
	var back: Dictionary = game.household_finale["active"].duplicate(true)
	var generation: int = game._save_generation
	var page := Worktop.new()
	page.name = "FinalePlan"
	game._present_workspace(page, func() -> void:
		if _current(game, page, generation): _leave(game)
	)
	page.title_label.text = "汇演前的安排"
	page.subtitle_label.text = "晚饭后出发，先看看排练和精力"
	page.close_button.text = "回到配方" if back["kind"] == "cooking" else "回到当前安排"
	HouseholdUI.note(page.body, "排练 %d/%d · 精力 %d\n演前至少需要%d精力，晚饭后留一个安排位。" % [game.state["goal_progress"], game._goal_target(), game.state["energy"], game._story_action("perform")["min_energy"]])
	if game._is_action_phase() and back["kind"] == "stage":
		HouseholdUI.section(page.body, "眼下可以选择")
		for id in (["perform"] if game.phase == "dinner_action" else ["rehearse", "nap", "walk"]):
			if not game._story_action_ids(game.phase).has(id): continue
			var action: Dictionary = game._effective_action(id)
			var reason: String = game._action_disabled_reason(action)
			var detail := "排练 +%d · 精力 %+d" % [action.get("study", 0), action.get("energy", 0)]
			var button := HouseholdUI.button("%s\n%s%s" % [action["name"], detail, "\n" + reason if not reason.is_empty() else ""], id)
			button.disabled = not reason.is_empty()
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			page.body.add_child(button)
			button.pressed.connect(func() -> void:
				if not _current(game, page, generation) or game._action_disabled_reason(game._effective_action(id)) != "": return
				_leave(game, false)
				game._apply_action(id)
			)
		page.body.add_child(HouseholdUI.label("选一项会占用这段餐后安排。精力还会扣除时段消耗，数值范围为0–100。", 21, HouseholdUI.MUTED))
	else:
		page.body.add_child(HouseholdUI.label("先吃这顿饭。早饭后、午饭后可以练歌或休息，晚饭后再去汇演。", 23))
	HouseholdUI.section(page.body, "这周做了什么")
	var rehearsals := 0
	for record in game.run_history:
		for action in record["actions"]:
			if action["id"] in ["rehearse", "group_rehearsal"]: rehearsals += 1
	for action in game.today_action_records:
		if action["id"] in ["rehearse", "group_rehearsal"]: rehearsals += 1
	HouseholdUI.note(page.body, "排练了%d次。\n%s" % [rehearsals, game.shared_meal.summary()])
	page.close_button.call_deferred("grab_focus")


static func _outcome_reason(game: Node, result: Dictionary) -> String:
	# Keep the frozen v1 outcome untouched; only format the visible explanation.
	if result["kind"] == "other_choice": return "这次选了其他安排。"
	var missing: Array[String] = []
	if result["progress"] < game._goal_target(): missing.append("排练%d/%d" % [result["progress"], game._goal_target()])
	var minimum: int = game._story_action("perform")["min_energy"]
	if result["energy"] < minimum: missing.append("演前精力%d，需要%d" % [result["energy"], minimum])
	if result["slots"] >= game.MAX_DAILY_ACTIONS: missing.append("今天的安排位用完了")
	return "；".join(missing) + "。"


static func _current(game: Node, page: Control, generation: int) -> bool:
	return is_instance_valid(page) and page == game._workspace and page.visible and not page.is_queued_for_deletion() and generation == game._save_generation and game.household_finale["active"].get("phase") == game.phase


static func _leave(game: Node, render: bool = true) -> void:
	var back: Dictionary = game.household_finale["active"].duplicate(true)
	game.household_finale["active"] = {}
	game._queue_autosave()
	game._close_workspace(false)
	if not render: return
	if back["kind"] == "cooking":
		var ids: Array[String] = []
		ids.assign(back["ids"])
		game._show_cooking_choice(ids, back["storage"], back["plan"])
		game._workspace.learning_button.call_deferred("grab_focus")
	else:
		game._render_phase()
		var button: Control = game._active_stage.find_child("FinaleButton", true, false) if is_instance_valid(game._active_stage) else null
		if button != null: button.call_deferred("grab_focus")
