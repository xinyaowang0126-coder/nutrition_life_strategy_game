class_name CampusResourcePresenter
extends RefCounted

const Resources := preload("res://scripts/stories/CampusResourcePlan.gd")
const Week := preload("res://scripts/stories/CampusWeek.gd")
const Cards := preload("res://scripts/CardDataStore.gd")
const Worktop := preload("res://scripts/stories/HouseholdWorktop.gd")


static func open(game: Node, target: Dictionary) -> bool:
	if not game.is_node_ready() or game._household() or game._new_day_pending or not Week.enabled(game.campus_week): return false
	if not game.campus_week["active"].is_empty() and game.campus_week["active"].get("kind") != "plan": return false
	Cards.ensure_loaded()
	if game.phase != "ending":
		if target.get("day", 0) not in range(game.day, mini(7, game.day + 1) + 1) or target.get("meal") not in Resources.MEALS: return false
		if Resources.point(target["day"], target["meal"]) < Resources.point(game.day, game.phase): return false
		game.campus_week["active"] = {"kind": "plan", "day": game.day, "phase": game.phase, "target_day": target["day"], "meal": target["meal"], "advance": false}
	var page := Worktop.new()
	page.name = "CampusMealPlan"
	page.set_meta("save_generation", game._save_generation)
	game._present_workspace(page, func() -> void:
		if not _current(game, page): return
		game.campus_week["active"] = {}
		if game._is_meal_phase() and game.current_source_id == "dorm_storage": game.hand.assign(game._hand_for_source("dorm_storage", game.phase))
		game._queue_autosave()
		game._close_workspace()
	)
	page.title_label.text = "之后怎么吃" if game.phase != "ending" else "吃饭计划与记录"
	page.close_button.text = "回到今日小结" if game.phase == "summary" else "回去安排"
	_render(game, page, target)
	game._queue_autosave()
	return true


static func summary(game: Node, target: Dictionary) -> String:
	if target.is_empty(): return "这周的计划与记录"
	Cards.ensure_loaded()
	var plan := Week.plan_for(game.campus_week, target["day"], target["meal"])
	var source := String(plan.get("source", ""))
	var where := String(Cards.meal_sources.get(source, {}).get("name", "去处未定"))
	var text := "第%d天%s · %s" % [target["day"], Resources.NAMES[target["meal"]], where]
	var held := Resources.reserved_here(game.campus_week["resources"], target["day"], target["meal"])
	var names: Array[String] = []
	for id in held: names.append(String(Cards.foods[id]["name"]))
	if not names.is_empty(): text += "\n已留：" + "、".join(names)
	for row in game.campus_week["resources"]["budgets"]:
		if not row["released"] and row["start_day"] == target["day"]:
			text += "\n饭钱留¥%d（%d天）" % [row["amount"], row["days"]]
	return text


static func _render(game: Node, page: HouseholdWorktop, target: Dictionary, days: int = 1) -> void:
	var owner := page.get_viewport().gui_get_focus_owner()
	var focus_name := String(owner.name) if owner != null and page.is_ancestor_of(owner) else ""
	var scroll_position := page.scroll.scroll_vertical
	page.clear_body()
	page.subtitle_label.text = "余额¥%d · 今天还能花¥%d" % [game.state["balance"], game._spendable_balance()]
	if game.phase != "ending":
		page.title_label.text = "第%d天%s怎么吃" % [target["day"], Resources.NAMES[target["meal"]]]
		var targets := _grid(page.body, 2)
		var upcoming := Resources.upcoming(game.day, game.phase)
		_add_target(game, page, targets, upcoming, target, "下一餐", "target_upcoming")
		var tomorrow := {"day": game.day + 1, "meal": "breakfast"}
		if game.day < 7 and tomorrow != upcoming: _add_target(game, page, targets, tomorrow, target, "明天早餐", "target_tomorrow")
		HouseholdUI.section(page.body, summary(game, target))
		if target["day"] > game.day:
			var preview := Week.preview(game.day, game.campus_week)
			if not preview.is_empty(): HouseholdUI.note(page.body, preview["summary"])
		HouseholdUI.section(page.body, "打算去哪吃")
		var plan := Week.plan_for(game.campus_week, target["day"], target["meal"])
		var source := String(plan.get("source", ""))
		var sources := _grid(page.body, 2)
		for id in Cards.meal_source_ids:
			if not Cards.meal_sources[id].get("scenes", []).has(target["meal"]): continue
			var button := _button(sources, String(Cards.meal_sources[id]["name"]), "source_" + id, source == id)
			_connect(game, page, button, func() -> void:
				if choose_source(game, target, id): _render(game, page, target, days)
			)
		var later := _button(sources, "到时再选", "source_later", source.is_empty())
		_connect(game, page, later, func() -> void:
			if choose_source(game, target, ""): _render(game, page, target, days)
		)
		if source == "dorm_storage" or not Resources.reserved_here(game.campus_week["resources"], target["day"], target["meal"]).is_empty():
			_stock(game, page, target, days)
		_budget(game, page, target, days)
	_history(game, page)
	page.scroll.set_deferred("scroll_vertical", scroll_position)
	if not focus_name.is_empty(): _restore_focus.call_deferred(page, focus_name)


static func choose_source(game: Node, target: Dictionary, source: String) -> bool:
	if game.phase == "ending" or not Week.enabled(game.campus_week): return false
	if source != "" and (not Cards.meal_sources.has(source) or not Cards.meal_sources[source].get("scenes", []).has(target["meal"])): return false
	if not Week.set_plan(game.campus_week, target["day"], target["meal"], source, game.day): return false
	if source != "dorm_storage":
		for row in game.campus_week["resources"]["stock"]:
			if row["status"] == "pending" and row["day"] == target["day"] and row["meal"] == target["meal"]:
				Resources.release_stock(game.campus_week["resources"], row["id"], game.day, game.phase)
	game._queue_autosave()
	return true


static func _add_target(game: Node, page: HouseholdWorktop, parent: Container, next: Dictionary, current: Dictionary, text: String, id: String) -> void:
	if next.is_empty(): return
	var button := _button(parent, text, id, next == current)
	_connect(game, page, button, func() -> void:
		game.campus_week["active"]["target_day"] = next["day"]
		game.campus_week["active"]["meal"] = next["meal"]
		_render(game, page, next)
		page.scroll.set_deferred("scroll_vertical", 0)
		game._queue_autosave()
	)


static func _stock(game: Node, page: HouseholdWorktop, target: Dictionary, days: int) -> void:
	HouseholdUI.section(page.body, "给这餐留存粮")
	var grid := _grid(page.body, 2)
	var resources: Dictionary = game.campus_week["resources"]
	for id in game.dorm_inventory:
		if game.dorm_inventory[id] <= 0: continue
		var held := {}
		var free: int = game.dorm_inventory[id]
		for row in resources["stock"]:
			if row["status"] != "pending" or row["food_id"] != id: continue
			free -= 1
			if row["day"] == target["day"] and row["meal"] == target["meal"]: held = row
		var name: String = Cards.foods[id]["name"]
		var text := "已留%s · 取消" % name if not held.is_empty() else "留1份%s" % name
		var button_id := "release_stock_%d" % held["id"] if not held.is_empty() else "reserve_" + String(id)
		var button := _button(grid, text, button_id, not held.is_empty())
		button.disabled = held.is_empty() and free <= 0
		_connect(game, page, button, func() -> void:
			if not held.is_empty(): Resources.release_stock(resources, held["id"], game.day, game.phase)
			elif not Resources.reserve_stock(resources, game.dorm_inventory, id, target["day"], target["meal"], game.day, game.phase):
				game._post("这餐最多留2份不同存粮，也需要有多余库存。", "warning")
			_render(game, page, target, days)
			game._queue_autosave()
		)
	if grid.get_child_count() == 0: HouseholdUI.note(page.body, "柜子里暂时没有存粮。")


static func _budget(game: Node, page: HouseholdWorktop, target: Dictionary, days: int) -> void:
	if game.day >= 7: return
	HouseholdUI.section(page.body, "明天起的饭钱")
	var resources: Dictionary = game.campus_week["resources"]
	var blocked := false
	for row in resources["budgets"]:
		if row["released"] or row["start_day"] + row["days"] - 1 < game.day: continue
		HouseholdUI.note(page.body, Resources.budget_text(row, game.capture_game_save()["payload"]))
		if row["start_day"] + row["days"] - 1 >= game.day + 1: blocked = true
		var release := _button(page.body, "解除这笔饭钱预留", "release_budget_%d" % row["id"])
		_connect(game, page, release, func() -> void:
			Resources.release_budget(resources, row["id"], game.day, game.phase)
			_render(game, page, target, days)
			game._queue_autosave()
		)
	if blocked: return
	var periods := _grid(page.body, 2)
	for count in [1, 2]:
		if game.day + count > 7: continue
		var period := _button(periods, "留%d天的饭钱" % count, "budget_days_%d" % count, days == count)
		_connect(game, page, period, func() -> void: _render(game, page, target, count))
	var amounts := _grid(page.body, 3)
	for amount in [10, 20, 40]:
		var button := _button(amounts, "留¥%d" % amount, "budget_%d_%d" % [days, amount])
		button.disabled = amount > game.state["balance"]
		_connect(game, page, button, func() -> void:
			Resources.reserve_budget(resources, amount, days, game.day, game.phase, game.state["balance"])
			_render(game, page, target, days)
			game._queue_autosave()
		)
	page.body.add_child(HouseholdUI.label("留出的饭钱从明天可用，今天要用可以解除预留。", 20, HouseholdUI.MUTED))


static func _history(game: Node, page: HouseholdWorktop) -> void:
	var rows: Array[String] = []
	for plan in game.campus_week["plans"]: rows.append(Week.plan_text(plan, Cards.meal_sources))
	for row in game.campus_week["resources"]["stock"]: rows.append(Resources.stock_text(row, Cards.foods))
	for row in game.campus_week["resources"]["budgets"]: rows.append(Resources.budget_text(row, game.capture_game_save()["payload"]))
	if rows.is_empty(): return
	var button := _button(page.body, "回看计划与实际安排", "PlanHistory")
	var history := VBoxContainer.new()
	page.body.add_child(history)
	for text in rows: HouseholdUI.note(history, text)
	history.hide()
	_connect(game, page, button, func() -> void:
		history.visible = not history.visible
		button.text = "收起计划记录" if history.visible else "回看计划与实际安排"
	)


static func _grid(parent: Container, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid


static func _button(parent: Container, text: String, id: String, selected: bool = false) -> Button:
	var button := HouseholdUI.button(text, id)
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 21)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HouseholdUI.style_button(button, false, selected)
	parent.add_child(button)
	return button


static func _connect(game: Node, page: HouseholdWorktop, button: Button, callback: Callable) -> void:
	button.pressed.connect(func() -> void:
		if _current(game, page) and button.is_visible_in_tree() and not button.is_queued_for_deletion(): callback.call()
	)


static func _restore_focus(page: HouseholdWorktop, name: String) -> void:
	if not is_instance_valid(page) or not page.visible or page.is_queued_for_deletion(): return
	var control := page.find_child(name, true, false) as Control
	if control != null and control.is_visible_in_tree() and (not control is Button or not (control as Button).disabled): control.grab_focus()


static func _current(game: Node, page: HouseholdWorktop) -> bool:
	return is_instance_valid(page) and page == game._workspace and page.visible and not page.is_queued_for_deletion() and page.get_meta("save_generation") == game._save_generation
