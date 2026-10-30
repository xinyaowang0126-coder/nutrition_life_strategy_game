class_name EndingScreenV2
extends Control

signal restart_requested
signal story_requested
signal record_book_requested

const UI := preload("res://scripts/stories/HouseholdUI.gd")
var feedback: Dictionary = {}
var review_open := false
var title_label: Label
var summary_label: Label
var hero_image: TextureRect
var main_scroll: ScrollContainer
var review_button: Button
var restart_button: Button
var story_button: Button
var _blocked := false
var _locked := false
var _factor := 1.0
var _portrait := false
var _layout_queued := false
var _buttons: Array[Button] = []
var _anchors: Dictionary = {}
var _return_moment := ""
var _main_position := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.GAME_THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_queue_layout)
	set_process_input(false)
	if not feedback.is_empty(): _build()


func present(value: Dictionary) -> void:
	var changed := feedback != value or not visible
	feedback = value.duplicate(true)
	visible = true
	move_to_front()
	set_process_input(not _blocked)
	if changed:
		review_open = false
		_locked = false
		_main_position = 0
		if is_node_ready(): _build()


func hide_screen() -> void:
	visible = false
	review_open = false
	_locked = false
	_blocked = false
	set_process_input(false)


func set_modal_blocked(value: bool) -> void:
	_blocked = value
	set_process_input(visible and not value)
	for button in _buttons:
		if is_instance_valid(button): button.disabled = value
	if not value: _locked = false


func restore_focus() -> void:
	if visible and is_instance_valid(review_button): review_button.grab_focus()


func button_for(id: String) -> Button:
	for button in _buttons:
		if is_instance_valid(button) and String(button.name) == id: return button
	return null


func _queue_layout() -> void:
	if _layout_queued or not visible or feedback.is_empty(): return
	_layout_queued = true
	call_deferred("_relayout")


func _relayout() -> void:
	_layout_queued = false
	if visible and not feedback.is_empty(): _build()


func _label(text: String, pixels: float, heading: bool = false, color: Color = UI.INK) -> Label:
	return UI.label(text, roundi(pixels * _factor), color, heading)


func _button(text: String, id: String, callback: Callable, primary: bool = false, small: bool = false) -> Button:
	var button := UI.button(text, id, primary)
	button.custom_minimum_size.y = (44 if small else 50) * _factor
	button.add_theme_font_size_override("font_size", roundi((15 if small else 18) * _factor))
	if primary:
		var box := UI.paper(UI.GREEN, roundi(10 * _factor), roundi(8 * _factor))
		button.add_theme_stylebox_override("normal", box)
		var hover := box.duplicate() as StyleBoxFlat
		hover.bg_color = Color("#40523c")
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
	button.disabled = _blocked
	button.pressed.connect(func() -> void:
		if not _blocked and not _locked and visible: callback.call()
	)
	_buttons.append(button)
	return button


func _stack(parent: Node, separation: float = 8) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", roundi(separation * _factor))
	parent.add_child(stack)
	return stack


func _build() -> void:
	var window_size := Vector2(get_window().size)
	var viewport_size := get_viewport_rect().size
	_factor = viewport_size.x / maxf(1, window_size.x)
	_portrait = window_size.x < 760 or window_size.y > window_size.x
	for child in get_children():
		if child.is_queued_for_deletion(): continue
		if child is CanvasItem: child.hide()
		child.queue_free()
	_buttons.clear()
	_anchors.clear()
	var background := ColorRect.new()
	background.color = UI.PAPER
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := roundi((16 if _portrait else 28) * _factor)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, inset)
	add_child(margin)
	var page := _stack(margin, 10)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", roundi(8 * _factor))
	page.add_child(header)
	var kicker := _label(("自己的舞台" if feedback.get("story_id") == "choir_week" else "撑过这一周") + " · 第%d天收尾" % int(feedback.get("day", 1)), 14, false, UI.MUTED)
	header.add_child(kicker)
	var balance := _label("余额 ¥%d" % int(feedback.get("balance", 0)), 14, false, UI.MUTED)
	balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance.custom_minimum_size.x = 90 * _factor
	balance.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(balance)
	title_label = _label("本周回顾" if review_open else String(feedback["title"]), 26 if _portrait else 32, true)
	page.add_child(title_label)
	main_scroll = ScrollContainer.new()
	main_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_scroll.follow_focus = true
	page.add_child(main_scroll)
	if review_open: _build_review(page)
	else: _build_main(page, window_size)
	call_deferred("_finish_layout")


func _build_main(page: VBoxContainer, window_size: Vector2) -> void:
	var layout: BoxContainer = VBoxContainer.new() if _portrait else HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", roundi((12 if _portrait else 32) * _factor))
	main_scroll.add_child(layout)
	hero_image = TextureRect.new()
	hero_image.name = "EndingArt"
	hero_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_image.clip_contents = true
	var image_path := String(feedback.get("image", ""))
	if ResourceLoader.exists(image_path):
		var texture := load(image_path) as Texture2D
		var legacy_frame := texture != null and image_path.begins_with("res://assets/generated/endings/") and not image_path.contains("/feedback/") and texture.get_width() > texture.get_height() * 1.5
		if texture != null and (legacy_frame or _portrait):
			var region := Rect2(Vector2.ZERO, texture.get_size())
			if legacy_frame: region = Rect2(texture.get_width() * 0.205, 0, texture.get_width() * 0.59, texture.get_height())
			if _portrait:
				var banner_height := 128.0 if window_size.y < 720 else 190.0
				var banner_ratio := maxf(1, window_size.x - 40) / banner_height
				var crop_height := minf(region.size.y, region.size.x / banner_ratio)
				# The characters' faces are above the image centre. Keep them in
				# the short portrait banner instead of cropping around the torso.
				var focal_y := 0.20 if image_path.ends_with("zhou_perform-v1.png") else (0.31 if legacy_frame else 0.37)
				region.position.y += clampf(region.size.y * focal_y - crop_height * 0.5, 0, region.size.y - crop_height)
				region.size.y = crop_height
			var crop := AtlasTexture.new()
			crop.atlas = texture
			crop.region = region
			hero_image.texture = crop
		else: hero_image.texture = texture
	if _portrait:
		hero_image.custom_minimum_size.y = (128 if window_size.y < 720 else 190) * _factor
	else:
		hero_image.custom_minimum_size = Vector2((window_size.x - 88) * 0.40 * _factor, minf(510, window_size.y - 190) * _factor)
		hero_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(hero_image)
	var body := _stack(layout, 10 if _portrait else 13)
	var body_pixels := 20 if feedback.get("story_id") == "choir_week" else 18
	body.add_child(_label("“" + String(feedback["voice"]) + "”", 18, false, UI.GREEN))
	summary_label = _label(String(feedback["summary"]), body_pixels)
	body.add_child(summary_label)
	if not feedback["moments"].is_empty():
		var span := "这周" if int(feedback.get("day", 1)) >= 7 else "这几天"
		body.add_child(_label(span + "留下的" + ("两件事" if feedback["moments"].size() == 2 else "一件事"), 14, true, UI.ORANGE))
	for moment in feedback["moments"]:
		var item := _stack(body, 3)
		var button := _button(String(moment["title"]) + " · 回看", "Moment_" + String(moment["id"]), func() -> void: open_review(String(moment["id"])), false, true)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.flat = true
		item.add_child(button)
		item.add_child(_label(String(moment["text"]), body_pixels))
	body.add_child(_label("下次试一件事", 14, true, UI.GREEN))
	body.add_child(_label(String(feedback["next_try"]), body_pixels))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", roundi(8 * _factor))
	page.add_child(footer)
	review_button = _button("本周回顾", "Review", func() -> void: open_review(), false, _portrait)
	story_button = _button("回到故事", "Stories", _return_story, false, _portrait)
	restart_button = _button("再来一周", "Restart", _restart, true, _portrait)
	for button in [review_button, story_button, restart_button]: footer.add_child(button)


func _build_review(page: VBoxContainer) -> void:
	var content := _stack(main_scroll, 18)
	_add_section(content, "rules", "这次结局的依据", String(feedback.get("summary", "")) + "\n\n" + String(feedback.get("rules", "")))
	for moment in feedback.get("moments", []):
		_add_section(content, String(moment["id"]), String(moment["title"]), String(moment["basis"]))
	for section in feedback.get("review", []):
		_add_section(content, String(section["id"]), String(section["title"]), String(section["text"]))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", roundi(8 * _factor))
	page.add_child(footer)
	review_button = _button("回到结局", "Back", close_review, true, _portrait)
	footer.add_child(review_button)
	footer.add_child(_button("查看餐次记录", "Meals", func() -> void: record_book_requested.emit(), false, _portrait))
	restart_button = null
	story_button = null


func _add_section(parent: VBoxContainer, id: String, title: String, text: String) -> void:
	var section := _stack(parent, 8)
	_anchors[id] = section
	section.add_child(_label(title, 21, true, UI.GREEN))
	section.add_child(_label(text, 20 if feedback.get("story_id") == "choir_week" else 18))


func open_review(anchor: String = "") -> void:
	if _blocked or _locked: return
	_main_position = main_scroll.scroll_vertical
	_return_moment = anchor
	review_open = true
	_build()
	call_deferred("_scroll_to_anchor", anchor)


func close_review() -> void:
	if _blocked: return
	review_open = false
	_build()
	call_deferred("_restore_main_position")


func _finish_layout() -> void:
	if not visible or _blocked: return
	restore_focus()


func _restore_main_position() -> void:
	if review_open or not visible: return
	main_scroll.scroll_vertical = _main_position
	var moment_button := button_for("Moment_" + _return_moment)
	if moment_button != null: moment_button.grab_focus()


func _scroll_to_anchor(id: String) -> void:
	await get_tree().process_frame
	if review_open and _anchors.has(id): main_scroll.ensure_control_visible(_anchors[id])


func _restart() -> void:
	if review_open or _blocked or _locked: return
	_locked = true
	restart_requested.emit()


func _return_story() -> void:
	if _blocked or _locked: return
	_locked = true
	story_requested.emit()


func _input(event: InputEvent) -> void:
	if not visible or _blocked: return
	if event.is_action_pressed("ui_cancel"):
		if review_open: close_review()
		get_viewport().set_input_as_handled()
	elif UI.handle_modal_key(self, event, true):
		get_viewport().set_input_as_handled()
