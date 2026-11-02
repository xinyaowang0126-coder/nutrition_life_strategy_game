class_name CampusPresenter
extends RefCounted

const Week := preload("res://scripts/stories/CampusWeek.gd")
const Learning := preload("res://scripts/stories/CampusMealLearning.gd")
const Cards := preload("res://scripts/CardDataStore.gd")
const Worktop := preload("res://scripts/stories/HouseholdWorktop.gd")
const Journal := preload("res://scripts/stories/CampusStudyJournal.gd")
const ResourceUI := preload("res://scripts/stories/CampusResourcePresenter.gd")
const Resources := preload("res://scripts/stories/CampusResourcePlan.gd")


static func _available(game: Node) -> bool:
	return game.is_node_ready() and not game._household() and Week.enabled(game.campus_week) and not game._new_day_pending


static func meal_context(game: Node) -> Dictionary:
	Cards.ensure_loaded()
	if game._is_meal_phase() and not game.selected_food_ids.is_empty():
		return Learning.context(game.day, game.phase, game.current_source_id, game.selected_food_ids, Cards.foods)
	for i in range(game.today_meal_records.size() - 1, -1, -1):
		var meal: Dictionary = game.today_meal_records[i]
		if not meal.get("skipped", false) and meal.has("campus_facts"):
			var c := Learning.context(game.day, meal["phase"], meal["source_id"], meal["food_ids"], Cards.foods)
			if not c.is_empty(): c["food_names"] = meal["food_names"].duplicate()
			return c
	return {}


static func notebook(game: Node) -> bool:
	if not _available(game): return false
	var page := Worktop.new()
	game._present_workspace(page)
	page.title_label.text = "小林的笔记"
	page.subtitle_label.text = "第%d天 · 余额¥%d · 复习%d/70" % [game.day, game.state["balance"], game.state["study_progress"]]
	page.close_button.text = "回去安排"
	var c := meal_context(game)
	if not c.is_empty():
		HouseholdUI.section(page.body, "这一餐")
		HouseholdUI.note(page.body, "、".join(c["food_names"]) + "\n" + Learning.preview(c["food_ids"]) + "。份量、调味用量未标。")
		if game.phase != "ending": _add_button(game, page, "用这份菜单练习", "study", func() -> void: open_study(game))
	else:
		HouseholdUI.note(page.body, "选好食物后，可以对照这份菜单的原料。")
	_add_button(game, page, "之后怎么吃", "plan", func() -> void: open_plan(game))
	if not game.campus_week["plans"].is_empty():
		HouseholdUI.section(page.body, "原打算和实际安排")
		for plan in game.campus_week["plans"]:
			HouseholdUI.note(page.body, Week.plan_text(plan, Cards.meal_sources))
	var lessons: Array = game.campus_week["journal"]["entries"]
	if not lessons.is_empty():
		var independent := 0
		var helped := 0
		var unknown := 0
		for row in lessons:
			var first: Dictionary = row["first_answer"]
			if first.is_empty():
				if row["help_seen"]: helped += 1
				continue
			if first["independence"] == "after_help": helped += 1
			elif first["independence"] == "unknown": unknown += 1
			elif first["correct"]: independent += 1
		HouseholdUI.note(page.body, "看过%d题，首次独立答对%d题，先看解释%d题。" % [lessons.size(), independent, helped] + ("旧记录中%d题的帮助经历未知。" % unknown if unknown > 0 else ""))
	return true


static func _add_button(game: Node, page: HouseholdWorktop, text: String, id: String, callback: Callable) -> void:
	var button := HouseholdUI.button(text, id)
	page.body.add_child(button)
	button.pressed.connect(func() -> void:
		if page == game._workspace and page.visible:
			game._close_workspace(false)
			callback.call()
	)


static func open_study(game: Node) -> bool:
	if not _available(game): return false
	if game.phase == "ending": return false
	var c := meal_context(game)
	if c.is_empty(): return notebook(game)
	var lesson := Journal.open(game.campus_week["journal"], "composition", c)
	if lesson.is_empty(): return false
	game.campus_week["active"] = {"kind": "study", "day": game.day, "phase": game.phase, "context": c, "page": "question", "help": lesson["help_seen"], "answer": ""}
	game._queue_autosave()
	_render_study(game)
	return true


static func _render_study(game: Node) -> void:
	var active: Dictionary = game.campus_week["active"]
	var c: Dictionary = active["context"]
	var q := Learning.question(c)
	var generation: int = game._save_generation
	var page: String = active["page"]
	var choices: Array = []
	var body := String(q["body"])
	if page == "question":
		body += "\n\n" + String(q["prompt"])
		choices = q["choices"].duplicate(true)
		choices.append({"id": "explain", "text": "直接看解释"})
	else:
		if not String(active["answer"]).is_empty(): body += "\n\n" + ("答对了。" if active["answer"] == q["correct"] else "再对照一下菜单。")
		body += "\n\n" + String(q["explanation"])
		choices.append({"id": "retry", "text": "再试一次"})
	choices.append({"id": "back", "text": "回到这一餐"})
	game._show_story_dialog(q["title"], body, choices, func(choice: String) -> void:
		if generation != game._save_generation or game.campus_week.get("active", {}) != active: return
		if choice == "back":
			if page == "question": Journal.skip(game.campus_week["journal"], "composition", c)
			_leave(game)
			return
		if page == "feedback":
			if choice != "retry": return
			Journal.retry(game.campus_week["journal"], "composition", c)
			active["page"] = "question"
			active["answer"] = ""
		elif choice == "explain":
			Journal.help(game.campus_week["journal"], "composition", c)
			active["help"] = true
			active["page"] = "feedback"
		else:
			if not q["choices"].any(func(option: Dictionary) -> bool: return option["id"] == choice): return
			var result := Journal.answer(game.campus_week["journal"], "composition", c, {"choice": choice}, choice == q["correct"])
			if game.campus_week["attempts"].size() < 128:
				game.campus_week["attempts"].append({"context": c.duplicate(true), "choice": choice, "correct": choice == q["correct"], "after_help": result.get("after_help", true)})
			Journal.help(game.campus_week["journal"], "composition", c)
			active["answer"] = choice
			active["help"] = true
			active["page"] = "feedback"
		game._queue_autosave()
		_render_study(game)
	)


static func target(game: Node) -> Dictionary:
	return Resources.upcoming(game.day, game.phase)


static func open_plan(game: Node, tomorrow: bool = false) -> bool:
	if not _available(game): return false
	var next := {"day": game.day + 1, "meal": "breakfast"} if tomorrow and game.day < 7 else target(game)
	return ResourceUI.open(game, next)


static func planning_summary(game: Node) -> String:
	if game.day >= 7: return ""
	return ResourceUI.summary(game, {"day": game.day + 1, "meal": "breakfast"}) + "\n点这里安排或修改"


static func _leave(game: Node) -> void:
	game.campus_week["active"] = {}
	game._queue_autosave()


static func resume(game: Node) -> bool:
	if not _available(game) or game.campus_week.get("active", {}).is_empty(): return false
	if game.campus_week["active"]["kind"] == "study": _render_study(game)
	else:
		var active: Dictionary = game.campus_week["active"]
		ResourceUI.open(game, {"day": active["target_day"], "meal": active["meal"]})
	return true
