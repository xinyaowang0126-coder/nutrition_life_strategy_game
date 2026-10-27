class_name SelectedFoodCardV2
extends PanelContainer

signal remove_requested(item_id: String)

@onready var empty_label: Label = $Empty
@onready var face: VBoxContainer = $Face
@onready var price_label: Label = $Face/Header/Price
@onready var remove_button: Button = $Face/Header/RemoveButton
@onready var preview: TextureRect = $Face/Preview
@onready var title_label: Label = $Face/Title
@onready var satiety_label: Label = $Face/Stats/Satiety
@onready var preference_label: Label = $Face/Stats/Preference

var _filled := false
var _title_size := 18
var item_id := ""
var _revision := 0
var _remove_pending := false
var _pointer_active := false
var _pointer_start := Vector2.ZERO
var _pointer_revision := 0


func _ready() -> void:
	resized.connect(_fit_title)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	remove_button.pressed.connect(request_remove)
	remove_button.focus_entered.connect(_apply_frame)
	remove_button.focus_exited.connect(_apply_frame)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := remove_button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if style != null:
			style.set_content_margin_all(4)
			style.set_corner_radius_all(7)
			remove_button.add_theme_stylebox_override(state, style)
	gui_input.connect(_on_surface_input)
	_apply_frame()


func show_food(food: Dictionary, texture: Texture2D, from_stock: bool, badge: String = "") -> void:
	_revision += 1
	_pointer_active = false
	item_id = String(food.get("id", ""))
	_filled = true
	empty_label.hide()
	face.show()
	preview.texture = texture
	preview.visible = texture != null
	title_label.text = String(food.get("name", ""))
	price_label.text = "×1" if from_stock else "¥%d" % int(food.get("cost", 0))
	if not badge.is_empty(): price_label.text = badge
	remove_button.name = "Remove_" + item_id
	remove_button.disabled = false
	tooltip_text = "移出" + String(food.get("name", ""))
	remove_button.tooltip_text = tooltip_text
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	satiety_label.text = "饱腹 %+d" % int(food.get("satiety", 0))
	var preference: Dictionary = food.get("food_preference", {})
	preference_label.text = "口味 %+d" % int(preference.get("mood_delta", 0)) if String(preference.get("status", "")) == "known" else "口味未设置"
	_apply_frame()
	_fit_title()


func clear_food() -> void:
	_revision += 1
	_pointer_active = false
	item_id = ""
	_filled = false
	face.hide()
	empty_label.show()
	preview.texture = null
	preview.hide()
	remove_button.disabled = true
	tooltip_text = ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_apply_frame()


func set_card_size(value: Vector2, mobile: bool) -> void:
	custom_minimum_size = value
	_title_size = 16 if mobile else 18
	remove_button.text = "×" if value.x > 0 and value.x < 96 else "移出"
	remove_button.custom_minimum_size = Vector2(28 if value.x > 0 and value.x < 96 else 36, 30)
	price_label.add_theme_font_size_override("font_size", 13 if mobile else 14)
	for label in [satiety_label, preference_label]:
		label.add_theme_font_size_override("font_size", 12 if mobile else 13)
	_fit_title()


func _fit_title() -> void:
	if not is_node_ready():
		return
	var font := title_label.get_theme_font("font")
	var font_size := _title_size
	var available := maxf(1.0, (size.x if size.x > 0 else custom_minimum_size.x) - 16.0)
	while font_size > 12 and font.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available * 2.0:
		font_size -= 1
	title_label.add_theme_font_size_override("font_size", font_size)


func _apply_frame() -> void:
	var frame := (get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat)
	frame.set_content_margin_all(8)
	frame.set_corner_radius_all(12)
	frame.bg_color = Color("#f5dbac") if _filled else Color("#efdfbf80")
	frame.border_color = Color("#d18a32") if _filled else Color("#aa8c5f70")
	frame.set_border_width_all(4 if remove_button.has_focus() else (3 if _filled else 2))
	frame.shadow_size = 4 if _filled else 0
	frame.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", frame)


func request_remove() -> void:
	if not _filled or _remove_pending or not is_visible_in_tree() or is_queued_for_deletion(): return
	_remove_pending = true
	remove_requested.emit(item_id)
	call_deferred("_release_remove_guard")


func _release_remove_guard() -> void:
	_remove_pending = false


func _on_surface_input(event: InputEvent) -> void:
	if not _filled: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION: return
		if event.pressed:
			_pointer_active = true
			_pointer_start = event.position
			_pointer_revision = _revision
			remove_button.grab_focus()
		else:
			var tapped := _pointer_active and _pointer_revision == _revision and _pointer_start.distance_to(event.position) <= 18.0 and Rect2(Vector2.ZERO, size).has_point(event.position)
			_pointer_active = false
			if tapped: request_remove()
		accept_event()
	elif event is InputEventMouseMotion and _pointer_active and _pointer_start.distance_to(event.position) > 18.0:
		_pointer_active = false
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pointer_active = true
			_pointer_start = event.position
			_pointer_revision = _revision
			remove_button.grab_focus()
		else:
			var tapped := _pointer_active and _pointer_revision == _revision and _pointer_start.distance_to(event.position) <= 18.0 and Rect2(Vector2.ZERO, size).has_point(event.position)
			_pointer_active = false
			if tapped: request_remove()
		accept_event()
	elif event is InputEventScreenDrag and _pointer_active and _pointer_start.distance_to(event.position) > 18.0:
		_pointer_active = false
