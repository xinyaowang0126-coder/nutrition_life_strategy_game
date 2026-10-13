extends Control

const Model := preload("res://tests/preview/G4PreviewModel.gd")
const CompositionScene := preload("res://scenes/game_v2/components/MealCompositionPanel.tscn")
const CompositionScript := preload("res://scripts/ui_v2/MealCompositionPanel.gd")
const V2_THEME := preload("res://scenes/game_v2/V2Theme.tres")
const PHASE_TITLES := {"breakfast": "早饭", "lunch": "午饭", "dinner": "晚饭", "done": "今天吃了什么"}
var model := Model.new()
var title_label: Label
var balance_label: Label
var status_label: Label
var columns: GridContainer
var hand_grid: GridContainer
var content_scroll: ScrollContainer
var hand_panel: PanelContainer
var view_panel: PanelContainer
var composition: CompositionScript
var selection_label: Label
var suggestion_button: Button
var alternative_toggle: Button
var alternative_button: Button
var dismiss_suggestion_button: Button
var plan_label: Label
var diary_panel: PanelContainer
var diary_body: VBoxContainer
var diary_button: Button
var confirm_button: Button
var skip_button: Button
var restart_button: Button
var footer: HBoxContainer
var cards := {}
var diary_mode := false
var _proposal := {}
var _applying_profile := false
var _last_proposal: Dictionary = {}


func _ready() -> void:
	theme = V2_THEME
	_build()
	get_viewport().size_changed.connect(_layout)
	_refresh()
	_layout()


func _build() -> void:
	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = load("res://assets/generated/backgrounds/cafeteria_background.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var wash := ColorRect.new()
	wash.color = Color(0.14, 0.10, 0.05, 0.40)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 16)
	margin.add_child(root_box)
	var header := _paper()
	root_box.add_child(header)
	var header_box := VBoxContainer.new()
	header.add_child(header_box)
	var small := _label("开发预览 · 试菜单", 17)
	small.add_theme_color_override("font_color", Color("#766246"))
	header_box.add_child(small)
	var row := HBoxContainer.new()
	header_box.add_child(row)
	title_label = _label("", 32)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	balance_label = _label("", 25)
	balance_label.custom_minimum_size.x = 170
	balance_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(balance_label)
	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(content_scroll)
	columns = GridContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("h_separation", 22)
	columns.add_theme_constant_override("v_separation", 18)
	content_scroll.add_child(columns)
	hand_panel = _paper()
	hand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(hand_panel)
	var hand_box := VBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 14)
	hand_panel.add_child(hand_box)
	hand_box.add_child(_label("食堂窗口", 25))
	hand_grid = GridContainer.new()
	hand_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_grid.add_theme_constant_override("h_separation", 12)
	hand_grid.add_theme_constant_override("v_separation", 12)
	hand_box.add_child(hand_grid)
	for entry in Model.MENU:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 122)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_stylebox_override("normal", _paper_style(Color("#fff4dc"), 16))
		button.add_theme_stylebox_override("hover", _paper_style(Color("#ffedc5"), 16))
		button.add_theme_stylebox_override("pressed", _paper_style(Color("#dbe9cb"), 16))
		button.add_theme_stylebox_override("hover_pressed", _paper_style(Color("#ccdeb7"), 16))
		button.add_theme_stylebox_override("disabled", _paper_style(Color("#e4d8c0"), 16))
		button.add_theme_color_override("font_color", Color("#483822"))
		button.add_theme_color_override("font_hover_color", Color("#483822"))
		button.add_theme_color_override("font_pressed_color", Color("#483822"))
		button.add_theme_color_override("font_hover_pressed_color", Color("#483822"))
		button.text = "%s\n¥%d" % [entry["name"], entry["cost"]]
		if not String(entry["image"]).is_empty():
			button.icon = load("res://assets/generated/cards/%s.png" % entry["image"])
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 78)
		button.pressed.connect(_toggle.bind(String(entry["id"])))
		hand_grid.add_child(button)
		cards[entry["id"]] = button
	view_panel = _paper()
	view_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(view_panel)
	var view_box := VBoxContainer.new()
	view_box.add_theme_constant_override("separation", 16)
	view_panel.add_child(view_box)
	selection_label = _label("", 22)
	view_box.add_child(selection_label)
	composition = CompositionScene.instantiate() as CompositionScript
	composition.add_theme_stylebox_override("panel", _paper_style(Color("#fff0d4"), 12))
	view_box.add_child(composition)
	suggestion_button = Button.new()
	suggestion_button.custom_minimum_size.y = 56
	suggestion_button.pressed.connect(_try_option)
	view_box.add_child(suggestion_button)
	alternative_toggle = _button("看看另一个办法", _toggle_alternative)
	alternative_toggle.toggle_mode = true
	view_box.add_child(alternative_toggle)
	alternative_button = _button("", _try_alternative)
	view_box.add_child(alternative_button)
	dismiss_suggestion_button = _button("换个建议", _dismiss_suggestion)
	view_box.add_child(dismiss_suggestion_button)
	plan_label = _label("", 21)
	view_box.add_child(plan_label)
	var hint := _label("最多选三样。点选后再结账。", 17)
	view_box.add_child(hint)
	diary_panel = _paper()
	diary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(diary_panel)
	diary_body = VBoxContainer.new()
	diary_body.add_theme_constant_override("separation", 18)
	diary_panel.add_child(diary_body)
	status_label = _label("", 18)
	status_label.add_theme_color_override("font_color", Color("#fff4df"))
	root_box.add_child(status_label)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root_box.add_child(footer)
	diary_button = _button("今天吃了什么", _toggle_diary)
	footer.add_child(diary_button)
	skip_button = _button("先不吃", _skip)
	footer.add_child(skip_button)
	confirm_button = _button("就吃这些", _confirm)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	confirm_button.custom_minimum_size.x = 220
	footer.add_child(confirm_button)
	restart_button = _button("再试一次", _restart)
	footer.add_child(restart_button)


func _refresh() -> void:
	title_label.text = "今天吃了什么" if diary_mode or model.phase() == "done" else PHASE_TITLES[model.phase()] + "想吃什么？"
	balance_label.text = "余额 ¥%d" % model.balance
	hand_panel.visible = not diary_mode and model.phase() != "done"
	view_panel.visible = hand_panel.visible
	diary_panel.visible = diary_mode or model.phase() == "done"
	for id in cards:
		var button := cards[id] as Button
		button.set_pressed_no_signal(model.selected.has(id))
		button.disabled = not model.can_toggle(id)
	selection_label.text = "还没选。" if model.selected.is_empty() else "选了 %d/3 样 · 合计 ¥%d" % [model.selected.size(), model.total()]
	composition.show_view(model.meal_view())
	_proposal = model.suggestion() if not model.selected.is_empty() and model.phase() != "done" else {"verified": false}
	if _proposal != _last_proposal:
		alternative_toggle.set_pressed_no_signal(false)
	_last_proposal = _proposal.duplicate(true)
	suggestion_button.visible = _proposal.get("verified", false)
	if suggestion_button.visible:
		suggestion_button.text = _action_text(_proposal["action"])
	alternative_toggle.visible = suggestion_button.visible and _proposal.get("alternative") is Dictionary
	alternative_button.visible = alternative_toggle.visible and alternative_toggle.button_pressed
	if alternative_toggle.visible:
		alternative_button.text = _action_text(_proposal["alternative"])
	dismiss_suggestion_button.visible = suggestion_button.visible
	plan_label.visible = _proposal.get("plan") is Dictionary
	if plan_label.visible:
		# Neutral, test-preview copy. No future menu is claimed available.
		plan_label.text = ("明天" if _proposal["plan"]["target_day"] > 1 else "") + "%s再看看配料。" % PHASE_TITLES[_proposal["plan"]["target_phase"]]
	diary_button.text = "回去选饭" if diary_mode and model.phase() != "done" else "今天吃了什么"
	diary_button.disabled = model.phase() == "done"
	skip_button.visible = hand_panel.visible
	confirm_button.visible = hand_panel.visible
	confirm_button.disabled = model.selected.is_empty() or model.total() > model.balance
	confirm_button.text = "就吃这些 · ¥%d" % model.total()
	restart_button.visible = model.phase() == "done"
	_render_diary()
	_layout()


func _render_diary() -> void:
	for child in diary_body.get_children():
		diary_body.remove_child(child)
		child.queue_free()
	var view := model.diary()
	diary_body.add_child(_label(view["observation"], 28))
	for phase in Model.PHASES:
		var text := "还没吃到这顿"
		for row in view["rows"]:
			if row["phase"] == phase:
				text = row["text"]
		var entry := _paper()
		entry.add_theme_stylebox_override("panel", _paper_style(Color("#fff0d4"), 16))
		var box := VBoxContainer.new()
		entry.add_child(box)
		box.add_child(_label(PHASE_TITLES[phase], 21))
		box.add_child(_label(text, 24))
		diary_body.add_child(entry)
	diary_body.add_child(_label("今天餐费 ¥%d" % view["spent"], 22))
	var period := model.period_view()
	for segment in period["composition"]:
		diary_body.add_child(_label(segment["text"], 22))
		if not segment["lines"].is_empty():
			diary_body.add_child(_label("\n".join(segment["lines"]), 19))
	diary_body.add_child(_label("菜单说明：这里用测试菜谱试界面。份量未标的，只看配料。正式营养资料仍在审核。", 17))


func _layout() -> void:
	if columns == null:
		return
	if get_viewport() is Window and not _applying_profile:
		_applying_profile = true
		var window := get_window()
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		var target := Vector2i(720, 1280) if window.size.y > window.size.x else Vector2i(1920, 1080)
		if window.content_scale_size != target:
			window.content_scale_size = target
		_applying_profile = false
	var narrow := get_viewport_rect().size.x < 1100
	columns.columns = 1 if narrow or diary_panel.visible else 2
	hand_grid.columns = 2 if narrow else 3
	footer.alignment = BoxContainer.ALIGNMENT_END
	for button in cards.values():
		(button as Button).custom_minimum_size.y = 112 if narrow else 128


func _toggle(id: String) -> void:
	model.toggle(id)
	status_label.text = ""
	_refresh()


func _try_option() -> void:
	status_label.text = "" if model.apply_suggestion(_proposal) else "菜单变了，再选一次。"
	_refresh()


func _toggle_alternative() -> void:
	alternative_button.visible = alternative_toggle.visible and alternative_toggle.button_pressed
	if alternative_button.visible:
		_reveal_alternative.call_deferred()


func _reveal_alternative() -> void:
	await get_tree().process_frame
	if alternative_button.visible:
		_scroll_to_control(alternative_button)


func _try_alternative() -> void:
	if _proposal.get("alternative") is Dictionary:
		status_label.text = "" if model.apply_suggestion({"verified": true, "action": _proposal["alternative"]}) else "菜单变了，再选一次。"
	_refresh()


func _dismiss_suggestion() -> void:
	model.dismiss_suggestion(_proposal)
	_refresh()
	if plan_label.visible:
		_reveal_plan.call_deferred()
	elif dismiss_suggestion_button.visible:
		_reveal_current_suggestion.call_deferred()


func _reveal_current_suggestion() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if dismiss_suggestion_button.visible:
		_scroll_to_control(dismiss_suggestion_button)


func _reveal_plan() -> void:
	await get_tree().process_frame
	if plan_label.visible:
		_scroll_to_control(plan_label)


func _scroll_to_control(control: Control) -> void:
	# Visibility changes can temporarily shrink the scrollbar range to zero.
	# Recheck after the queued container layout before relying on the clamp.
	for attempt in range(4):
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			return
		var visible_area := content_scroll.get_global_rect()
		var target := control.get_global_rect()
		if target.end.y > visible_area.end.y:
			content_scroll.scroll_vertical += ceili(target.end.y - visible_area.end.y + 8)
		elif target.position.y < visible_area.position.y:
			content_scroll.scroll_vertical -= ceili(visible_area.position.y - target.position.y + 8)
		else:
			return
		await get_tree().process_frame


func _action_text(action: Dictionary) -> String:
	var text := ("再加%s" % action["food_name"]) if action["kind"] == "add_food" else ("%s换成%s" % [action["remove_food_name"], action["food_name"]])
	return text + " · 合计 ¥%d" % action["total_cost"]


func _confirm() -> void:
	if model.confirm():
		diary_mode = model.phase() == "done"
		status_label.text = ""
		content_scroll.scroll_vertical = 0
	_refresh()


func _skip() -> void:
	model.skip()
	diary_mode = model.phase() == "done"
	content_scroll.scroll_vertical = 0
	_refresh()


func _toggle_diary() -> void:
	diary_mode = not diary_mode
	content_scroll.scroll_vertical = 0
	_refresh()


func _restart() -> void:
	model = Model.new()
	diary_mode = false
	content_scroll.scroll_vertical = 0
	_refresh()


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(callback)
	return button


func _paper() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _paper_style(Color("#f7e9cc"), 20))
	return panel


func _paper_style(color: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#ad8956")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(padding)
	return style


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#483822"))
	return label
