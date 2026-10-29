extends RefCounted

const Study := preload("res://scripts/stories/HouseholdMealLearning.gd")
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const Worktop := preload("res://scripts/stories/HouseholdWorktop.gd")
const Education := preload("res://scripts/stories/StoryEducation.gd")
const Kitchen := preload("res://scripts/stories/KitchenStock.gd")


static func open_selection(game: Node, ids: Array) -> bool:
	if not game._household() or game.day not in Study.DAYS or not game._is_meal_phase() or game._record_book_active() or ids != game.selected_food_ids: return false
	var stock: bool = game.current_source_id == "home_fridge"
	var facts: Dictionary = _stock_facts(game, ids) if stock else {}
	var c := Study.context(game.day, game.phase, game.current_source_id, ids, game._story_food_catalog(), "stock_preview" if stock else "selection", facts)
	return _open(game, c, _return_to(game))


static func open_cooking(game: Node, ids: Array, storage: String, plan: Dictionary) -> bool:
	if game.day not in Study.DAYS or game.current_source_id != "home_kitchen" or not game._is_meal_phase() or ids != game.selected_food_ids: return false
	var facts := Facts.freeze(ids, game._story_food_catalog(), plan)
	if facts.is_empty(): return false
	var c := Study.context(game.day, game.phase, game.current_source_id, ids, game._story_food_catalog(), "recipe_preview", facts)
	var back := _return_to(game)
	back["kind"] = "cooking"
	back["ids"] = ids.duplicate()
	back["storage"] = storage
	back["plan"] = plan.duplicate(true)
	return _open(game, c, back)


static func open_reference(game: Node) -> bool:
	if not game._household() or game.day not in Study.DAYS: return false
	if game._is_meal_phase() and not game.selected_food_ids.is_empty():
		return open_selection(game, game.selected_food_ids)
	for index in range(game.today_meal_records.size() - 1, -1, -1):
		var meal: Dictionary = game.today_meal_records[index]
		if meal.get("skipped", false) or meal.get("food_ids", []).is_empty(): continue
		var c: Dictionary = meal.get("learning_facts", {})
		if c.is_empty():
			c = Study.context(game.day, meal["phase"], meal["source_id"], meal["food_ids"], game._story_food_catalog(), "confirmed", meal.get("recipe_facts", {}))
			if not c.is_empty(): c["food_names"] = meal["food_names"].duplicate()
		return _open(game, c, _return_to(game))
	return false


static func _return_to(game: Node) -> Dictionary:
	return {"kind": "meal", "day": game.day, "phase": game.phase, "source": game.current_source_id, "ids": [], "plan": {}, "storage": "eat_now"}


static func _stock_facts(game: Node, ids: Array) -> Dictionary:
	var batches: Array = []
	for id in ids:
		if id in ["milk", "apple"] and int(game.kitchen.ingredients.get(id, 0)) > 0:
			batches.append({"food_id": id, "kind": "ready_pantry"})
			continue
		for batch in game.kitchen.batches:
			if batch.get("food_id") == id and int(batch.get("quantity", 0)) > 0 and Kitchen.classify(batch, game.day, game._story_clock()) == "needs_reheat":
				batches.append(batch.duplicate(true))
				break
	return Facts.from_batches(batches)


static func _open(game: Node, c: Dictionary, back: Dictionary) -> bool:
	if not game.is_node_ready() or not Study.begin(game.household_lessons, c, back): return false
	game._lesson_seen[game.day] = true
	game._queue_autosave()
	_render(game)
	return true


static func resume(game: Node) -> bool:
	if not game.is_node_ready() or game.household_lessons.get("active", {}).is_empty(): return false
	_render(game)
	return true


static func _render(game: Node) -> void:
	var active: Dictionary = game.household_lessons["active"]
	var row := Study.entry(game.household_lessons, active["entry_id"])
	var q := Study.question(row["context"], row["variant"])
	var generation: int = game._save_generation
	var id: String = row["id"]
	var page := Worktop.new()
	page.name = "MealStudyPage"
	game._present_workspace(page, func() -> void:
		if _current(game, page, generation, id): _leave(game)
	)
	page.title_label.text = q["title"]
	page.subtitle_label.text = "已确认餐次的练习" if row["context"]["scope"] == "confirmed" else "先看看这份预览，确认开饭后才记进餐"
	page.close_button.text = "回到配方" if active["return"]["kind"] == "cooking" else "回到这一餐"
	page.body.add_child(HouseholdUI.label(q["body"], 23))
	if active["page"] == "question":
		HouseholdUI.section(page.body, q["prompt"])
		for choice in q["choices"]:
			var button := _button(page.body, choice["text"], choice["id"])
			button.pressed.connect(func() -> void:
				if _current(game, page, generation, id) and Study.answer(game.household_lessons, choice["id"]):
					game._queue_autosave()
					_render(game)
			)
		var explain := _button(page.footer, "直接看解释", "Explain")
		explain.pressed.connect(func() -> void:
			if _current(game, page, generation, id) and Study.explain(game.household_lessons):
				game._queue_autosave()
				_render(game)
		)
	else:
		var feedback := "先看解释，还没有作答。"
		if not row["attempts"].is_empty(): feedback = "这次判断正确。" if row["attempts"].back()["correct"] else "再看看已知的量和记录范围。"
		HouseholdUI.section(page.body, feedback)
		HouseholdUI.note(page.body, q["explanation"])
		page.body.add_child(HouseholdUI.label(_history_text(row, q), 21, HouseholdUI.MUTED))
		var transfer := _button(page.body, "换一道例子" if row["context"]["day"] == 2 else "换个教学标签", "Transfer")
		transfer.pressed.connect(func() -> void:
			if not _current(game, page, generation, id): return
			var variant := "label_b" if row["variant"] == "label_a" else "label_a"
			if Study.begin(game.household_lessons, row["context"], active["return"], variant):
				game._queue_autosave()
				_render(game)
		)
		var retry := _button(page.footer, "再试一次", "Retry")
		retry.pressed.connect(func() -> void:
			if _current(game, page, generation, id) and Study.retry(game.household_lessons):
				game._queue_autosave()
				_render(game)
		)
	var suggestion := feasible_change(game, row["context"])
	if not suggestion.is_empty(): HouseholdUI.note(page.body, suggestion)
	var reference := _button(page.body, "查看课程依据", "Reference")
	var reference_body := HouseholdUI.label(String(Education.lesson(int(row["context"]["day"]))["body"]), 22, HouseholdUI.MUTED)
	page.body.add_child(reference_body)
	reference_body.hide()
	reference.pressed.connect(func() -> void:
		if _current(game, page, generation, id):
			reference_body.visible = not reference_body.visible
			reference.text = "收起课程依据" if reference_body.visible else "查看课程依据"
			if reference_body.visible:
				row["reference_seen"] = true
				game._queue_autosave()
	)
	page.body.add_child(HouseholdUI.label("查看、作答和重试不改变预算、精力或餐盘。", 20, HouseholdUI.MUTED))
	page.close_button.call_deferred("grab_focus")


static func _button(parent: Container, text: String, id: String) -> Button:
	var button := HouseholdUI.button(text, id)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 66
	button.add_theme_font_size_override("font_size", 22)
	parent.add_child(button)
	return button


static func _current(game: Node, page: Control, generation: int, id: String) -> bool:
	return is_instance_valid(page) and page == game._workspace and page.visible and not page.is_queued_for_deletion() and generation == game._save_generation and game.household_lessons.get("active", {}).get("entry_id") == id


static func _leave(game: Node) -> void:
	var back: Dictionary = game.household_lessons["active"]["return"].duplicate(true)
	Study.close(game.household_lessons)
	game._queue_autosave()
	game._close_workspace(false)
	if back["kind"] == "cooking" and back["day"] == game.day and back["phase"] == game.phase and back["source"] == game.current_source_id:
		var ids: Array[String] = []
		ids.assign(back["ids"])
		game._show_cooking_choice(ids, back["storage"], back["plan"])
		if game._workspace.learning_button != null: game._workspace.learning_button.call_deferred("grab_focus")
	else:
		game._render_phase()
		var target: Control = game._active_stage.find_child("MealStudy", true, false) if is_instance_valid(game._active_stage) else null
		if target != null: target.call_deferred("grab_focus")
		else: game.menu_button.call_deferred("grab_focus")


static func _history_text(row: Dictionary, q: Dictionary) -> String:
	var lines: Array[String] = []
	if not row["attempts"].is_empty():
		var first: Dictionary = row["attempts"][0]
		for choice in q["choices"]:
			if choice["id"] == first["choice"]: lines.append("首次选择：" + String(choice["text"]) + ("（作答前已看解释或依据）" if first["after_help"] else ""))
	var counts: Array[String] = []
	for pair in [["attempt_count", "作答"], ["retry_count", "重试"], ["skip_count", "跳过"]]:
		if row[pair[0]] > 0: counts.append("%s%d次" % [pair[1], row[pair[0]]])
	if not counts.is_empty(): lines.append("、".join(counts) + "。首次选择单独保留。")
	return "\n".join(lines)


static func feasible_change(game: Node, c: Dictionary) -> String:
	if c["day"] != 2 or c["scope"] not in ["selection", "stock_preview"] or not game._is_meal_phase() or c["day"] != game.day or c["meal"] != game.phase or c["source"] != game.current_source_id or c["food_ids"] != game.selected_food_ids: return ""
	var foods: Dictionary = game._story_food_catalog()
	var source: Dictionary = game._effective_meal_source(game.current_source_id)
	for id in game.hand:
		if game.selected_food_ids.has(id): continue
		if not foods[id].get("food_groups", []).any(func(group: String) -> bool: return not c["groups"].has(group)): continue
		var proposed: Array = game.selected_food_ids.duplicate()
		var removed := ""
		if proposed.size() >= game._source_selection_limit(game.current_source_id): removed = proposed.pop_back()
		proposed.append(id)
		var price := int(source.get("fee", 0))
		for item in proposed: price += int(foods[item].get("cost", 0))
		if source.get("payment_mode") == "stock":
			if game.current_source_id == "home_kitchen":
				if not game.kitchen.can_prepare(proposed, foods, game._served_portions(), Facts.defaults(proposed, foods)): continue
			elif proposed.any(func(item: String) -> bool: return game._stock_count(item, game.current_source_id) <= 0): continue
		elif price > game.state["balance"]: continue
		var change := "加入%s" % foods[id]["name"] if removed.is_empty() else "把%s换成%s" % [foods[removed]["name"], foods[id]["name"]]
		return "当前菜单还可%s%s。回到选菜页后由你决定。" % [change, "（使用现有原料）" if source.get("payment_mode") == "stock" else "（本餐¥%d）" % price]
	return ""
