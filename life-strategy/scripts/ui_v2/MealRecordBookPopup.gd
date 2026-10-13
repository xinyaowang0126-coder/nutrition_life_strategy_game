class_name MealRecordBookPopupV2
extends Control

signal closed()
signal main_menu_requested()
const Presenter := preload("res://scripts/systems/MealRecordPresenter.gd")
var _book: Dictionary = {}
var _day := 1
var _weekly := false
var _return_text := "继续安排"
var paper: PanelContainer
var title_label: Label
var summary_label: Label
var scroll: ScrollContainer
var body: VBoxContainer
var day_buttons: Array[Button] = []
var week_button: Button
var close_button: Button
var return_button: Button
var main_button: Button


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.02, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	paper = PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _style(22))
	add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	paper.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	title_label = _label("选餐记录", 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_label)
	close_button = _button("×", close_book)
	close_button.custom_minimum_size.x = 56
	heading.add_child(close_button)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	box.add_child(tabs)
	for day in range(1, 8):
		var button := _button("第 %d 天" % day, _select_day.bind(day))
		button.toggle_mode = true
		tabs.add_child(button)
		day_buttons.append(button)
	week_button = _button("这一周", _select_week)
	week_button.toggle_mode = true
	tabs.add_child(week_button)
	summary_label = _label("", 24)
	box.add_child(summary_label)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var footer := HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", 12)
	box.add_child(footer)
	main_button = _button("回主菜单", func() -> void: main_menu_requested.emit())
	return_button = _button(_return_text, close_book)
	footer.add_child(main_button)
	footer.add_child(return_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()


func show_book(book: Dictionary, return_text: String = "继续安排") -> void:
	_book = book.duplicate(true)
	_day = maxi(1, int(book.get("last_day", 1)))
	_weekly = false
	_return_text = return_text
	return_button.text = return_text
	_refresh()
	show()
	move_to_front()
	_layout()
	close_button.grab_focus()


func close_book() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _refresh() -> void:
	var view := Presenter.view(_book, _day, _weekly)
	title_label.text = view["title"]
	summary_label.text = view["summary"]
	for index in range(day_buttons.size()):
		day_buttons[index].disabled = index + 1 > int(_book.get("last_day", 0))
		day_buttons[index].set_pressed_no_signal(not _weekly and _day == index + 1)
	week_button.set_pressed_no_signal(_weekly)
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for day in view["days"]:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(14))
		body.add_child(panel)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 10)
		panel.add_child(content)
		content.add_child(_label("第 %d 天" % day["day"], 23))
		for row in day["rows"]:
			var text: String = row["title"] + " · " + row["text"]
			if row["status"] == "eaten":
				text += "\n" + row["source"] + " · " + row["payment"]
			content.add_child(_label(text, 21))
	for note in view["notes"]:
		body.add_child(_label(note, 18))
	body.add_child(_label(String(view.get("basis", "")), 18))
	scroll.scroll_vertical = 0


func _select_day(day: int) -> void:
	if day < 1 or day > int(_book.get("last_day", 0)):
		return
	_day = day
	_weekly = false
	_refresh()


func _select_week() -> void:
	_weekly = true
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_book()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()


func _layout() -> void:
	if paper == null:
		return
	var canvas := get_viewport_rect().size
	var target := Vector2(minf(940, canvas.x - 32), minf(940, canvas.y - 32))
	paper.size = target
	paper.position = (canvas - target) * 0.5


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(104, 56)
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(callback)
	return button


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#483822"))
	return label


func _style(padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff0d4")
	style.border_color = Color("#a6804f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(padding)
	return style
