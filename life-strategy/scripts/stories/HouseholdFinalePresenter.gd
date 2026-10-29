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
	game._show_story_dialog("今晚，轮到自己的舞台", "周阿姨：‘歌谱带好了。今天照样把饭吃好，晚饭后再决定怎么安排。’\n\n排练%d/%d，眼下精力%d。晚饭后参演需达到排练目标，并在演前保留至少%d游戏精力；早饭后、午饭后仍可按当前条件补练或休息。" % [game.state["goal_progress"], game._goal_target(), game.state["energy"], game._story_action("perform")["min_energy"]], [{"id": "look", "text": "看看今天的安排"}, {"id": "back", "text": "先安排早餐"}], func(choice: String) -> void:
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
	var title := "把歌唱完了" if performed else "今晚，按实际安排收好歌谱"
	var body: String = "周阿姨：‘最后一句唱完，心里踏实了。这一周没白惦记这首歌。’\n\n已实际完成社区合唱汇演；排练与演出消耗按行动记录保留。" if performed else "周阿姨：‘这回没上台，这一周的饭和练歌也都实实在在过了。收好歌谱，再看看下次怎么排。’\n\n" + result["reason"]
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
	page.title_label.text = "今晚之前，先看看安排"
	page.subtitle_label.text = "排练与精力是游戏刻度，参演按实际行动记录"
	page.close_button.text = "回到配方" if back["kind"] == "cooking" else "回到当前安排"
	HouseholdUI.note(page.body, "眼下排练 %d/%d · 精力 %d\n晚饭后参演至少保留%d游戏精力。现在的状态不等于届时一定能上台。" % [game.state["goal_progress"], game._goal_target(), game.state["energy"], game._story_action("perform")["min_energy"]])
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
		page.body.add_child(HouseholdUI.label("执行会使用这一段餐后安排；实际变化受游戏上下限和原有时段消耗影响。返回页面本身不占安排。", 21, HouseholdUI.MUTED))
	else:
		page.body.add_child(HouseholdUI.label("先安排眼下这一餐。早饭后、午饭后可按实际条件选择练歌或休息；晚饭后再核对参演条件。", 23))
	HouseholdUI.section(page.body, "这一周已经留下的事")
	var rehearsals := 0
	for record in game.run_history:
		for action in record["actions"]:
			if action["id"] in ["rehearse", "group_rehearsal"]: rehearsals += 1
	for action in game.today_action_records:
		if action["id"] in ["rehearse", "group_rehearsal"]: rehearsals += 1
	HouseholdUI.note(page.body, "已记录排练%d次。\n%s" % [rehearsals, game.shared_meal.summary()])
	page.body.add_child(HouseholdUI.label("演出完成表示本局目标达成；饮食回顾另看真实餐次、份量和保存记录。", 21, HouseholdUI.MUTED))
	page.close_button.call_deferred("grab_focus")


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
