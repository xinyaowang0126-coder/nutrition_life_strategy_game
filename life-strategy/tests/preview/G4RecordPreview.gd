extends Control

const Model := preload("res://tests/preview/G4RecordPreviewModel.gd")
const ThemeResource := preload("res://scenes/game_v2/V2Theme.tres")
var model := Model.new()
var title_label: Label
var summary_label: Label
var scroll: ScrollContainer
var body: VBoxContainer
var day_buttons: Array[Button] = []
var week_button: Button
var clear_button: Button
var restore_button: Button


func _ready() -> void:
	theme = ThemeResource
	var backdrop := ColorRect.new()
	backdrop.color = Color("#bfa47b")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	box.add_child(_label("开发预览 · 七日测试记录", 18))
	title_label = _label("", 32)
	box.add_child(title_label)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 10)
	tabs.add_theme_constant_override("v_separation", 10)
	box.add_child(tabs)
	for day in range(1, 8):
		var button := _button("第 %d 天" % day, _select_day.bind(day))
		button.toggle_mode = true
		tabs.add_child(button)
		day_buttons.append(button)
	week_button = _button("这一周", _select_week)
	week_button.toggle_mode = true
	tabs.add_child(week_button)
	summary_label = _label("", 25)
	box.add_child(summary_label)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	var footer := HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", 12)
	box.add_child(footer)
	clear_button = _button("清空测试记录", _clear)
	restore_button = _button("载入示例", _restore)
	footer.add_child(clear_button)
	footer.add_child(restore_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()


func _refresh() -> void:
	var view := model.view()
	title_label.text = view["title"]
	summary_label.text = view["summary"]
	for index in range(day_buttons.size()):
		day_buttons[index].set_pressed_no_signal(not model.weekly and model.selected_day == index + 1)
	week_button.set_pressed_no_signal(model.weekly)
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var last_day := 0
	var day_box: VBoxContainer
	for row in view["rows"]:
		if row["day"] != last_day:
			last_day = row["day"]
			day_box = _paper(body)
			day_box.add_child(_label("第 %d 天" % last_day, 24))
		var text := "%s · %s" % [row["title"], row["status"]]
		if not String(row["ingredients"]).is_empty():
			text += "\n" + row["ingredients"]
		day_box.add_child(_label(text, 22))
	for segment in view["composition"]:
		var segment_box := _paper(body)
		segment_box.add_child(_label(segment["text"], 25))
		if not String(segment["model_version"]).is_empty():
			segment_box.add_child(_label("资料版本：" + segment["model_version"], 17))
		if not segment["lines"].is_empty():
			segment_box.add_child(_label("\n".join(segment["lines"]), 22))
	if not view["notes"].is_empty():
		body.add_child(_label("\n".join(view["notes"]), 19))
	body.add_child(_label("种数只统计记到的配料，份量另记。示例中的审校字段是测试设定。", 17))
	scroll.scroll_vertical = 0


func _select_day(day: int) -> void:
	model.select_day(day)
	_refresh()


func _select_week() -> void:
	model.weekly = true
	_refresh()


func _clear() -> void:
	model.ledger.clear()
	_refresh()


func _restore() -> void:
	model.load_examples()
	_refresh()


func _layout() -> void:
	if get_viewport() is Window:
		var window := get_window()
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		var target := Vector2i(720, 1280) if window.size.y > window.size.x else Vector2i(1920, 1080)
		if window.content_scale_size != target:
			window.content_scale_size = target


func _paper(parent: Node) -> VBoxContainer:
	var paper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff0d4")
	style.border_color = Color("#9d774a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20)
	paper.add_theme_stylebox_override("panel", style)
	parent.add_child(paper)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	paper.add_child(content)
	return content


func _label(text: String, size_value: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", Color("#483822"))
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(112, 56)
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(callback)
	return button
