class_name StoryDialog
extends Control

signal chosen(choice: String)
var _panel: PanelContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _revision := 0


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
	stack.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 260
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	_body = Label.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 23)
	scroll.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	stack.add_child(_buttons)
	visibility_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	hide()


static func paper() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#eadcc4")
	box.border_color = Color("#927249")
	box.set_border_width_all(2)
	box.set_corner_radius_all(16)
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 22
	box.content_margin_bottom = 22
	return box


func present(title: String, body: String, choices: Array) -> void:
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
		button.pressed.connect(func() -> void:
			if revision != _revision or not visible:
				return
			hide()
			chosen.emit(String(choice["id"]))
		)
		_buttons.add_child(button)
	show()
	move_to_front()
	_layout()
	call_deferred("_focus_first")


func _focus_first() -> void:
	if visible and _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()


func _layout() -> void:
	if _panel == null:
		return
	var mobile := size.y > size.x
	_panel.anchor_left = 0.04 if mobile else 0.29
	_panel.anchor_right = 0.96 if mobile else 0.76
	_panel.anchor_top = 0.10
	_panel.anchor_bottom = 0.84
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0
