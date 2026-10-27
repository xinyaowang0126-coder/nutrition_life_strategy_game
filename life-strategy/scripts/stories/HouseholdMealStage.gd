class_name HouseholdMealStage
extends MealStageBaseV2

signal kitchen_requested
const SELECTED_CARD_SCENE := preload("res://scenes/game_v2/components/SelectedFoodCard.tscn")
var paper_panel: PanelContainer
var food_scroll: ScrollContainer
var _grid: GridContainer
var _title: Label
var _note: Label
var _receipt: Label
var _confirm: Button
var _footer: HBoxContainer
var _selected_strip: GridContainer
var _remove_buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper_panel = PanelContainer.new()
	paper_panel.name = "MealPaper"
	add_child(paper_panel)
	paper_panel.add_theme_stylebox_override("panel", HouseholdUI.paper())
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	paper_panel.add_child(stack)
	_title = HouseholdUI.label("", 36, HouseholdUI.INK, true)
	stack.add_child(_title)
	_note = HouseholdUI.label("", 21, HouseholdUI.MUTED)
	stack.add_child(_note)
	food_scroll = ScrollContainer.new()
	food_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	food_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	food_scroll.follow_focus = true
	stack.add_child(food_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	food_scroll.add_child(_grid)
	var selected_title := HBoxContainer.new()
	stack.add_child(selected_title)
	selected_title.add_child(HouseholdUI.label("本餐卡牌", 25, HouseholdUI.INK, true))
	var stock := HouseholdUI.button("冰箱与存粮", "Kitchen")
	stock.custom_minimum_size.y = 42
	stock.add_theme_font_size_override("font_size", 19)
	stock.pressed.connect(func() -> void: kitchen_requested.emit())
	selected_title.add_child(stock)
	_selected_strip = GridContainer.new()
	_selected_strip.add_theme_constant_override("h_separation", 10)
	_selected_strip.add_theme_constant_override("v_separation", 8)
	stack.add_child(_selected_strip)
	_receipt = HouseholdUI.label("", 18, HouseholdUI.MUTED)
	stack.add_child(_receipt)
	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.add_theme_constant_override("separation", 10)
	stack.add_child(_footer)
	var back := HouseholdUI.button("换个地方", "BackButton")
	var skip := HouseholdUI.button("先不吃", "SkipButton")
	_confirm = HouseholdUI.button("准备配方", "ConfirmButton", true)
	_confirm.size_flags_stretch_ratio = 1.45
	_footer.add_child(back)
	_footer.add_child(skip)
	_footer.add_child(_confirm)
	_bind_meal_controls(back, skip, _confirm, food_scroll)
	_finish_ready()


func _populate_cards() -> void:
	var kind := String(_options.get("meal_kind", "cook"))
	for food in _foods:
		food["meal_kind"] = kind
		if kind == "cook":
			var ingredients: Array[String] = []
			for value in String(food.get("ingredients", "")).split(",", false):
				var parts: PackedStringArray = value.split(":")
				ingredients.append(HouseholdUI.ingredient_name(parts[0]))
			food["ingredient_line"] = " + ".join(ingredients) + " · " + String(food.get("method", "现做"))
		elif kind == "fridge":
			food["batch_note"] = String((_options.get("batch_notes", {}) as Dictionary).get(food["id"], "未开封／现有存粮"))
		_foods_by_id[food["id"]] = food
	super._populate_cards()


func _create_card() -> Variant:
	return HouseholdFoodCard.new()


func _get_card_container() -> Container:
	return _grid


func _get_confirm_button() -> Button:
	return _confirm


func _get_cost_preview_label() -> Label:
	return _receipt


func _cost_preview_text(preview: Dictionary) -> String:
	if preview.is_empty(): return "已选 %d/%d · 确认前可查看费用与用量" % [_selected_ids.size(), _max_selected]
	return "已选 %d/%d · %s" % [_selected_ids.size(), _max_selected, String(preview.get("text", ""))]


func _get_slot_nodes() -> Array:
	return _selected_strip.get_children() if _selected_strip != null else []


func _update_slot_labels(_animate: bool) -> void:
	# This stage creates the same shared selected cards with recipe/stock
	# badges; its grid is rebuilt with the source-specific summary below.
	pass


func _update_scene_summary() -> void:
	if _title == null: return
	var kind := String(_options.get("meal_kind", "cook"))
	_title.text = "%s · %s" % [_meal_label, _options.get("location_name", "家里做饭")]
	(find_child("BackButton", true, false) as Button).text = String(_options.get("return_label", "换个地方"))
	_note.text = {"cook": "从手牌中选菜，再核对原料、调味与份量。", "fridge": "选择保存合规的存粮卡；熟食确认后彻底再热一次。", "purchase": "挑选餐食卡，按预算组成这一餐。"}.get(kind, "")
	for child in _selected_strip.get_children():
		_selected_strip.remove_child(child)
		child.queue_free()
	_remove_buttons.clear()
	_selected_strip.columns = _max_selected
	for index in range(_max_selected):
		var slot := SELECTED_CARD_SCENE.instantiate() as SelectedFoodCardV2
		slot.name = "SelectedSlot%d" % (index + 1)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_selected_strip.add_child(slot)
		slot.set_card_size(Vector2(0, _selection_card_height()), _layout_mobile_mode)
		if index < _selected_ids.size():
			var id := _selected_ids[index]
			var food: Dictionary = _foods_by_id[id]
			var badge := "菜谱" if kind == "cook" else ("库存" if kind == "fridge" else "")
			slot.show_food(food, HouseholdUI.food_texture(food), _payment_mode == "stock", badge)
			_remove_buttons[id] = slot.remove_button
			slot.remove_requested.connect(func(food_id: String) -> void: _remove_selected_food(food_id, slot.remove_button))
		else:
			slot.clear_food()
	_receipt.text = "已选 %d/%d · %s" % [_selected_ids.size(), _max_selected, "使用现有库存" if _payment_mode == "stock" else "本餐 ¥%d" % _selection_total()]
	_confirm.text = "准备配方" if kind == "cook" else ("再热并开饭" if kind == "fridge" else "确认这一餐")


func _remove_selected_food(id: String, button: Button) -> void:
	if not is_visible_in_tree() or is_queued_for_deletion() or not button.is_visible_in_tree() or button.is_queued_for_deletion(): return
	var index := _selected_ids.find(id)
	if index < 0: return
	var next_id := _selected_ids[(index + 1) % _selected_ids.size()] if _selected_ids.size() > 1 else ""
	var restore_focus := button.has_focus()
	_on_card_selected(id)
	if restore_focus: call_deferred("_focus_after_removal", next_id, id)


func _focus_after_removal(next_id: String, removed_id: String) -> void:
	if not is_visible_in_tree() or is_queued_for_deletion(): return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and not is_ancestor_of(owner): return
	var target := _remove_buttons.get(next_id) as Button
	if target == null: target = _cards_by_id.get(removed_id) as Button
	if target != null and not target.disabled: target.grab_focus()
	else: (find_child("BackButton", true, false) as Button).grab_focus()


func _selection_card_height() -> float:
	return 64.0 if _selected_ids.is_empty() else (194.0 if _layout_mobile_mode else 212.0)


func apply_selection_layout(mobile: bool) -> void:
	_layout_mobile_mode = mobile
	if paper_panel == null: return
	paper_panel.anchor_left = 0.31 if mobile else 0.40
	paper_panel.anchor_right = 0.99 if mobile else 0.97
	paper_panel.anchor_top = 0.01 if mobile else 0.04
	paper_panel.anchor_bottom = 0.98 if mobile else 0.91
	paper_panel.offset_left = 0
	paper_panel.offset_top = 0
	paper_panel.offset_right = 0
	paper_panel.offset_bottom = 0
	paper_panel.add_theme_stylebox_override("panel", HouseholdUI.paper(HouseholdUI.PAPER, 18 if mobile else 26))
	_title.add_theme_font_size_override("font_size", 31 if mobile else 38)
	_grid.columns = 2 if mobile else 3
	_selected_strip.columns = _max_selected
	for slot: SelectedFoodCardV2 in _selected_strip.get_children():
		slot.set_card_size(Vector2(0, _selection_card_height()), mobile)
	for button in _footer.get_children():
		(button as Button).add_theme_font_size_override("font_size", 19 if mobile else 24)
		(button as Button).custom_minimum_size.y = 62


func get_selection_layout_rects() -> Dictionary:
	return {"cards": food_scroll.get_global_rect(), "selection": _selected_strip.get_global_rect(), "footer": _footer.get_global_rect()}
