class_name StoryDialog
extends Control

signal chosen(choice: String)
var _panel: PanelContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _revision := 0
var _return_focus: WeakRef


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.13, 0.10, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "Paper"
	add_child(_panel)
	_panel.add_theme_stylebox_override("panel", paper())
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	_panel.add_child(stack)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_font_override("font", HouseholdUI.TITLE_FONT)
	_title.add_theme_color_override("font_color", HouseholdUI.INK)
	stack.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	stack.add_child(scroll)
	_body = Label.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 23)
	_body.add_theme_font_override("font", HouseholdUI.BODY_FONT)
	_body.add_theme_color_override("font_color", HouseholdUI.INK)
	scroll.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	stack.add_child(_buttons)
	visibility_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	hide()


static func paper() -> StyleBoxFlat:
	return HouseholdUI.paper(HouseholdUI.PAPER, 26)


func present(title: String, body: String, choices: Array) -> void:
	if not visible:
		var owner := get_viewport().gui_get_focus_owner()
		if owner != null and not is_ancestor_of(owner): _return_focus = weakref(owner)
	_revision += 1
	var revision := _revision
	_title.text = title
	_body.text = body
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for choice in choices:
		var button := Button.new()
		button.name = String(choice["id"])
		button.text = String(choice["text"])
		button.custom_minimum_size.y = 55
		button.add_theme_font_size_override("font_size", 22)
		button.disabled = not bool(choice.get("enabled", true))
		HouseholdUI.style_button(button, String(choice["id"]) in ["confirm", "start", "read", "save", "import"])
		if choice.get("texture") is Texture2D:
			button.custom_minimum_size.y = 132
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			for state in ["normal", "hover", "hover_pressed", "pressed", "focus", "disabled"]:
				var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
				style.content_margin_left = 172
				button.add_theme_stylebox_override(state, style)
			var photo := HouseholdUI.image(choice["texture"])
			photo.name = "LocationPhoto"
			photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			photo.custom_minimum_size = Vector2.ZERO
			photo.anchor_bottom = 1.0
			photo.offset_left = 12
			photo.offset_right = 154
			photo.offset_top = 12
			photo.offset_bottom = -12
			photo.modulate = Color(0.80, 0.77, 0.70, 0.75) if button.disabled else Color.WHITE
			button.add_child(photo)
		button.pressed.connect(_choose.bind(button, revision))
		_buttons.add_child(button)
	show()
	move_to_front()
	_layout()
	call_deferred("_layout")
	call_deferred("_focus_first")


func _focus_first() -> void:
	# A synchronous save can switch scenes before this deferred callback runs.
	if not is_visible_in_tree(): return
	var controls := HouseholdUI.focusable_controls(_buttons)
	if not controls.is_empty(): controls[0].grab_focus()
	else:
		var owner := get_viewport().gui_get_focus_owner()
		if owner != null: owner.release_focus()


func _choose(button: Button, revision: int) -> void:
	if revision != _revision or not visible or button.disabled: return
	hide()
	chosen.emit(String(button.name))
	call_deferred("_restore_focus", revision)


func _restore_focus(revision: int) -> void:
	if visible or revision != _revision or _return_focus == null: return
	var owner := _return_focus.get_ref() as Control
	if is_instance_valid(owner) and owner.is_visible_in_tree() and not owner.is_queued_for_deletion() and (not owner is BaseButton or not (owner as BaseButton).disabled):
		owner.grab_focus()
	_return_focus = null


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel", true):
		get_viewport().set_input_as_handled()
		if event.is_echo(): return
		# Escape can only choose an available, explicit return/cancel action.
		# A pending write with no choices stays open until its receipt arrives.
		for id in ["cancel", "back", "close"]:
			var button := _buttons.get_node_or_null(NodePath(id)) as Button
			if button != null and not button.disabled:
				_choose(button, _revision)
				return
	elif HouseholdUI.handle_modal_key(self, event):
		get_viewport().set_input_as_handled()


func _layout() -> void:
	if _panel == null:
		return
	var mobile := size.y > size.x
	_panel.anchor_left = 0.04 if mobile else 0.29
	_panel.anchor_right = 0.96 if mobile else 0.76
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = 0
	_panel.offset_right = 0
	# Fit short introductions and confirmations to their real content. Long
	# science text still scrolls inside the bounded modal above its buttons.
	_body.size.x = maxf(100.0, size.x * (_panel.anchor_right - _panel.anchor_left) - 64.0)
	_body.get_line_count()
	var has_body := not _body.text.strip_edges().is_empty()
	_body.get_parent().visible = has_body
	var fixed_height := _title.get_combined_minimum_size().y + _buttons.get_combined_minimum_size().y + (88.0 if has_body else 70.0)
	var body_height := maxf(100.0, _body.get_combined_minimum_size().y) if has_body else 0.0
	var height := clampf(fixed_height + body_height, 300.0, size.y * 0.80)
	_panel.offset_top = -height * 0.5
	_panel.offset_bottom = height * 0.5
