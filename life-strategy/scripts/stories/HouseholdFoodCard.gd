class_name HouseholdFoodCard
extends Button

signal selected(item_id: String)
signal detail_requested(payload: Dictionary, anchor_rect: Rect2, pinned: bool)
signal detail_dismissed(item_id: String)
var item_id := ""
var _payload: Dictionary = {}
var _selected := false
var _stock := -1
var _reason := ""
var _top: Label
var _status: Label
var _art: TextureRect
var _content_margin: MarginContainer
var _fitting_height := false
var info_button: Button


func configure(payload: Dictionary, _mode: String, chosen: bool, enabled: bool, stock: int, reason: String, _button_text: String) -> void:
	_payload = payload.duplicate(true)
	item_id = String(payload["id"])
	_stock = stock
	_selected = chosen
	_reason = reason
	custom_minimum_size = Vector2(0, 304)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	var margin := MarginContainer.new()
	_content_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(side, 12)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(top)
	_top = HouseholdUI.label("", 18, HouseholdUI.MUTED)
	top.add_child(_top)
	info_button = HouseholdUI.info_button()
	info_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	info_button.pressed.connect(func() -> void: request_detail(true))
	for target: Control in [self, info_button]:
		target.mouse_entered.connect(_preview_detail)
		target.mouse_exited.connect(_dismiss_preview)
		target.focus_entered.connect(_preview_detail)
		target.focus_exited.connect(_dismiss_preview)
	top.add_child(info_button)
	_art = HouseholdUI.image(HouseholdUI.food_texture(payload), 80)
	stack.add_child(_art)
	var title := HouseholdUI.label(String(payload["name"]), 25, HouseholdUI.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var line := String(payload.get("ingredient_line", payload.get("batch_note", payload.get("kind", ""))))
	var detail := HouseholdUI.label(line, 18, HouseholdUI.MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(detail)
	_status = HouseholdUI.label("", 19, HouseholdUI.GREEN)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_status)
	pressed.connect(func() -> void:
		if not disabled and visible and not is_queued_for_deletion(): selected.emit(item_id)
	)
	set_enabled(enabled, reason)
	set_selected(chosen)
	margin.minimum_size_changed.connect(_fit_content_height)
	resized.connect(_fit_content_height)
	_fit_content_height()


func _fit_content_height() -> void:
	# Wrapped titles and unavailable reasons must fit at the current card
	# width. The first layout pass has no content width yet.
	if _fitting_height or not is_instance_valid(_content_margin) or _content_margin.size.x <= 0: return
	_fitting_height = true
	custom_minimum_size.y = maxf(304.0, ceilf(_content_margin.get_combined_minimum_size().y))
	_fitting_height = false


func set_selected(value: bool, _animate: bool = false) -> void:
	_selected = value
	HouseholdUI.style_button(self, false, value)
	_update_text()


func set_enabled(value: bool, reason: String = "") -> void:
	disabled = not value
	_reason = reason
	_update_text()


func set_stock(value: int) -> void:
	_stock = value
	_update_text()


func _update_text() -> void:
	if _top == null: return
	_top.text = "已选" if _selected else ("可做 %d份" % _stock if _stock >= 0 and _payload.get("meal_kind") == "cook" else ("可用 %d份" % _stock if _stock >= 0 else "¥%d" % int(_payload.get("cost", 0))))
	_status.text = "点一下移出" if _selected else (_reason if disabled else "饱腹 +%d · 加入" % int(_payload.get("satiety", 0)))
	_status.add_theme_color_override("font_color", HouseholdUI.DANGER if disabled else HouseholdUI.GREEN)
	_fit_content_height()


func request_detail(pinned: bool = true) -> void:
	if not is_visible_in_tree() or is_queued_for_deletion(): return
	var payload := _payload.duplicate(true)
	payload["disabled_reason"] = _reason
	if _stock >= 0: payload["stock"] = _stock
	detail_requested.emit(payload, get_global_rect(), pinned)


func _preview_detail() -> void:
	var canvas := get_viewport_rect().size
	if canvas.y <= canvas.x * 1.18: request_detail(false)


func _dismiss_preview() -> void:
	detail_dismissed.emit(item_id)
