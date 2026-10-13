class_name MealCompositionPanelV2
extends PanelContainer

## Rendering only: the approved/gated view model is supplied by the presenter.
var _view: Dictionary = {}
var heading: Label
var summary: Label
var ingredients_label: Label
var portion_label: Label
var details_button: Button
var details_scroll: ScrollContainer
var details_label: Label
var _ready_finished := false


func _ready() -> void:
	_ready_finished = true
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	heading = _label("这份里有什么", 25)
	box.add_child(heading)
	summary = _label("先点几样看看。", 21)
	box.add_child(summary)
	ingredients_label = _label("", 24)
	box.add_child(ingredients_label)
	portion_label = _label("", 18)
	portion_label.add_theme_color_override("font_color", Color("#756954"))
	box.add_child(portion_label)
	details_button = Button.new()
	details_button.text = "看配料"
	details_button.custom_minimum_size.y = 48
	details_button.pressed.connect(_toggle_details)
	box.add_child(details_button)
	details_scroll = ScrollContainer.new()
	details_scroll.custom_minimum_size.y = 160
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(details_scroll)
	details_label = _label("", 18)
	details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(details_label)
	_apply()


func show_view(view: Dictionary) -> void:
	_view = view.duplicate(true)
	if _ready_finished:
		_apply()


func _apply() -> void:
	summary.text = String(_view.get("text", "先点几样看看。"))
	var names: Array[String] = []
	for entry in _view.get("ingredients", []):
		names.append(String(entry["name"]))
	ingredients_label.text = " · ".join(names)
	ingredients_label.visible = not names.is_empty()
	summary.visible = names.is_empty()
	var notes: Array[String] = []
	for key in ["portion_text", "data_note"]:
		if not String(_view.get(key, "")).is_empty():
			notes.append(_view[key])
	portion_label.text = " · ".join(notes)
	portion_label.visible = not notes.is_empty()
	var lines: Array[String] = []
	for entry in _view.get("details", []):
		var ingredient_name := String(entry["name"])
		if entry["band"] == "small":
			ingredient_name += "（少量）"
		elif entry["band"] == "trace":
			ingredient_name += "（微量）"
		lines.append(ingredient_name)
	lines.append(String(_view.get("basis_text", "")))
	details_label.text = "\n".join(lines)
	details_button.visible = not _view.is_empty()
	details_button.text = "看配料"
	details_scroll.hide()
	details_scroll.scroll_vertical = 0


func _toggle_details() -> void:
	details_scroll.visible = not details_scroll.visible
	details_button.text = "收起" if details_scroll.visible else "看配料"


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label
