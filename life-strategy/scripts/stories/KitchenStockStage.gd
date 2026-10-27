class_name KitchenStockStage
extends HouseholdWorktop

signal discard_requested(batch_id: String)
var _stock: KitchenStock
var _foods: Dictionary = {}
var _day := 1
var _active_tab := "cooked"
var _tab_buttons: Dictionary = {}
var _tab_pages: Dictionary = {}
var _expanded_batches: Dictionary = {}


func setup(stock: KitchenStock, foods: Dictionary, current_day: int) -> void:
	_stock = stock
	_foods = foods.duplicate(true)
	_day = current_day
	title_label.text = "冰箱与存粮"
	refresh()


func refresh() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	var restore_name := String(owner.name) if owner != null and is_ancestor_of(owner) else ""
	var scroll_position := scroll.scroll_vertical
	clear_body()
	_tab_buttons.clear()
	_tab_pages.clear()
	var ready: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	var ready_count := 0
	var pending_count := 0
	for batch in _stock.batches:
		if int(batch.get("quantity", 0)) <= 0: continue
		if batch.get("status") == "needs_reheat":
			ready.append(batch)
			ready_count += int(batch["quantity"])
		else:
			pending.append(batch)
			pending_count += int(batch["quantity"])
	subtitle_label.text = "待再热%d份 · 待处理%d份" % [ready_count, pending_count]
	# Tabs stay outside the scroll so the pantry is one action away from a
	# long collection of cooked batches, including on a short phone screen.
	var tabs := paper_panel.find_child("StockTabs", true, false) as HBoxContainer
	if tabs == null:
		tabs = HBoxContainer.new()
		tabs.name = "StockTabs"
		tabs.add_theme_constant_override("separation", 10)
		var stack := scroll.get_parent()
		stack.add_child(tabs)
		stack.move_child(tabs, scroll.get_index())
	else:
		for child in tabs.get_children():
			tabs.remove_child(child)
			child.queue_free()
	for tab_id in ["cooked", "ingredients"]:
		var button := HouseholdUI.button("熟食 %d份" % (ready_count + pending_count) if tab_id == "cooked" else "原料与调味", "Tab_" + tab_id)
		button.toggle_mode = true
		button.custom_minimum_size.y = 52
		tabs.add_child(button)
		_tab_buttons[tab_id] = button
		button.pressed.connect(func() -> void:
			if is_visible_in_tree() and not is_queued_for_deletion() and button.is_visible_in_tree(): _select_tab(tab_id)
		)
		var page := VBoxContainer.new()
		page.name = "Stock_" + tab_id
		page.add_theme_constant_override("separation", 10)
		body.add_child(page)
		_tab_pages[tab_id] = page
	var cooked := _tab_pages["cooked"] as VBoxContainer
	if not pending.is_empty():
		HouseholdUI.section(cooked, "需要处理")
		for batch in pending: _add_batch(cooked, batch)
	if not ready.is_empty():
		HouseholdUI.section(cooked, "冷藏待再热")
		for batch in ready: _add_batch(cooked, batch)
	if pending.is_empty() and ready.is_empty():
		cooked.add_child(HouseholdUI.image(preload("res://assets/generated/stories/props/pantry-fridge-v1.png"), 148))
		HouseholdUI.note(cooked, "没有留存的熟食。做饭时可以另备1份，分装冷藏。")
	var reminder := HouseholdUI.button("保存提醒", "StorageReminder")
	reminder.toggle_mode = true
	reminder.custom_minimum_size.y = 46
	cooked.add_child(reminder)
	var warning := HouseholdUI.note(cooked, "保存不当的隔夜熟食有健康风险。再烧开不能保证消除危害，闻着正常也不证明安全。", true).get_parent() as Control
	warning.hide()
	reminder.toggled.connect(func(open: bool) -> void: warning.visible = open)
	var ingredients := _tab_pages["ingredients"] as VBoxContainer
	HouseholdUI.section(ingredients, "现有原料（游戏份数）")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	ingredients.add_child(grid)
	for key in HouseholdUI.INGREDIENT_IDS:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", HouseholdUI.paper(HouseholdUI.TILE, 8, 10))
		grid.add_child(tile)
		var stack := VBoxContainer.new()
		tile.add_child(stack)
		stack.add_child(HouseholdUI.image(HouseholdUI.ingredient_texture(String(key)), 90))
		var quantity := int(_stock.ingredients.get(key, 0))
		stack.add_child(HouseholdUI.label("%s ×%d" % [HouseholdUI.ingredient_name(String(key)), quantity], 21, HouseholdUI.INK if quantity > 0 else HouseholdUI.DANGER))
	HouseholdUI.section(ingredients, "调味库存")
	HouseholdUI.note(ingredients, "盐 %d克  ·  酱油 %d毫升  ·  白糖 %d克" % [_stock.condiments.get("salt_g", 0), _stock.condiments.get("soy_ml", 0), _stock.condiments.get("sugar_g", 0)])
	_select_tab(_active_tab, false)
	scroll.set_deferred("scroll_vertical", scroll_position)
	if not restore_name.is_empty(): call_deferred("_restore_stock_focus", restore_name)


func _select_tab(tab_id: String, reset_scroll: bool = true) -> void:
	if not _tab_pages.has(tab_id): return
	_active_tab = tab_id
	for key in _tab_buttons:
		var selected: bool = key == tab_id
		HouseholdUI.style_button(_tab_buttons[key], false, selected)
		(_tab_buttons[key] as Button).set_pressed_no_signal(selected)
		(_tab_pages[key] as Control).visible = selected
	if reset_scroll: scroll.scroll_vertical = 0


func _add_batch(parent: Container, batch: Dictionary) -> void:
	var id := String(batch["id"])
	var status := String(batch.get("status", "history_unknown"))
	var usable := status == "needs_reheat"
	var card := PanelContainer.new()
	card.name = "Batch_" + id
	card.add_theme_stylebox_override("panel", HouseholdUI.paper(Color("#e8ecd9") if usable else Color("#f5dfcb"), 14, 12))
	parent.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	card.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)
	var food: Dictionary = _foods.get(batch["food_id"], {})
	var art := HouseholdUI.image(HouseholdUI.food_texture(food), 82)
	art.custom_minimum_size.x = 82
	row.add_child(art)
	var description := VBoxContainer.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(description)
	description.add_child(HouseholdUI.label("%s ×%d" % [food.get("name", "熟食"), int(batch["quantity"])], 26, HouseholdUI.INK, true))
	description.add_child(HouseholdUI.label({"needs_reheat": "食用前须彻底再热", "discard_required": "保存不当 · 应丢弃"}.get(status, "保存史不清 · 不供食用"), 21, HouseholdUI.GREEN if usable else HouseholdUI.DANGER))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	stack.add_child(actions)
	var details := HouseholdUI.button("保存详情", "Details_" + id)
	details.toggle_mode = true
	details.custom_minimum_size.y = 50
	actions.add_child(details)
	if not usable:
		var discard := HouseholdUI.button("丢弃%d份" % int(batch["quantity"]), id)
		discard.custom_minimum_size.y = 50
		actions.add_child(discard)
		discard.pressed.connect(func() -> void:
			if is_visible_in_tree() and not is_queued_for_deletion() and discard.is_visible_in_tree(): discard_requested.emit(id)
		)
	var record := VBoxContainer.new()
	record.name = "Record_" + id
	stack.add_child(record)
	record.add_child(HouseholdUI.label(String(batch.get("note", "保存情况未记录。")), 21, HouseholdUI.MUTED))
	var facts: Variant = batch.get("recipe_facts")
	if facts is Dictionary and HouseholdMealFacts.valid(facts):
		record.add_child(HouseholdUI.label("原配方：调味钠 %s毫克，另加白糖 %s克／人份。食材本底与总糖未知。" % [HouseholdMealFacts.number(facts["sodium_from_added_seasonings_mg"]), HouseholdMealFacts.number(facts["white_sugar_added_g"])], 20, HouseholdUI.MUTED))
	else:
		record.add_child(HouseholdUI.label("这份熟食的配方调味量未记录。", 20, HouseholdUI.MUTED))
	record.visible = bool(_expanded_batches.get(id, false))
	details.set_pressed_no_signal(record.visible)
	details.text = "收起详情" if record.visible else "保存详情"
	details.toggled.connect(func(open: bool) -> void:
		if not details.is_visible_in_tree() or details.is_queued_for_deletion(): return
		_expanded_batches[id] = open
		record.visible = open
		details.text = "收起详情" if open else "保存详情"
		if open: call_deferred("_reveal_record", record)
	)


func _reveal_record(record: Control) -> void:
	for frame in range(3):
		if not is_inside_tree() or is_queued_for_deletion(): return
		await get_tree().process_frame
	if is_instance_valid(record) and record.is_visible_in_tree(): scroll.ensure_control_visible(record)


func _restore_stock_focus(previous_name: String) -> void:
	if not is_visible_in_tree() or is_queued_for_deletion(): return
	var target := find_child(previous_name, true, false) as Control
	if target == null or not target.is_visible_in_tree():
		target = _tab_buttons[_active_tab]
	target.grab_focus()
