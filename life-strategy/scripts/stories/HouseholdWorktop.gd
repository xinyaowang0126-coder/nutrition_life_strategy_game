class_name HouseholdWorktop
extends Control

signal close_requested
var paper_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var body: VBoxContainer
var scroll: ScrollContainer
var footer: HBoxContainer
var close_button: Button
var modal_input_enabled := false
var _mobile := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper_panel = PanelContainer.new()
	paper_panel.name = "WorktopPaper"
	paper_panel.add_theme_stylebox_override("panel", HouseholdUI.paper())
	add_child(paper_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	paper_panel.add_child(stack)
	title_label = HouseholdUI.label("", 36, HouseholdUI.INK, true)
	title_label.name = "Title"
	stack.add_child(title_label)
	subtitle_label = HouseholdUI.label("", 21, HouseholdUI.MUTED)
	stack.add_child(subtitle_label)
	scroll = ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	stack.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	footer = HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 12)
	stack.add_child(footer)
	close_button = HouseholdUI.button("回到这一餐", "close")
	close_button.pressed.connect(func() -> void:
		if visible and not is_queued_for_deletion(): close_requested.emit()
	)
	footer.add_child(close_button)
	get_viewport().size_changed.connect(_viewport_changed)
	apply_profile(DisplayServer.window_get_size().y > DisplayServer.window_get_size().x * 1.18)


func _input(event: InputEvent) -> void:
	if not modal_input_enabled or not is_visible_in_tree() or is_queued_for_deletion(): return
	if event.is_action_pressed("ui_cancel", true):
		get_viewport().set_input_as_handled()
		if not event.is_echo(): close_requested.emit()
	elif HouseholdUI.handle_modal_key(self, event):
		get_viewport().set_input_as_handled()


func apply_profile(mobile: bool) -> void:
	_mobile = mobile
	if not is_instance_valid(paper_panel): return
	paper_panel.anchor_left = 0.31 if mobile else 0.40
	paper_panel.anchor_right = 0.99 if mobile else 0.97
	paper_panel.anchor_top = 0.01 if mobile else 0.04
	paper_panel.anchor_bottom = 0.98 if mobile else 0.91
	paper_panel.offset_left = 0
	paper_panel.offset_top = 0
	paper_panel.offset_right = 0
	paper_panel.offset_bottom = 0
	title_label.add_theme_font_size_override("font_size", 31 if mobile else 38)
	var style := HouseholdUI.paper(HouseholdUI.PAPER, 18 if mobile else 26)
	paper_panel.add_theme_stylebox_override("panel", style)
	for control in footer.get_children():
		if control is Button:
			(control as Button).add_theme_font_size_override("font_size", 21 if mobile else 24)
			(control as Button).custom_minimum_size.y = 62


func _viewport_changed() -> void:
	apply_profile(DisplayServer.window_get_size().y > DisplayServer.window_get_size().x * 1.18)


func clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func get_layout_rects() -> Dictionary:
	return {"paper": paper_panel.get_global_rect(), "scroll": scroll.get_global_rect(), "footer": footer.get_global_rect()}
