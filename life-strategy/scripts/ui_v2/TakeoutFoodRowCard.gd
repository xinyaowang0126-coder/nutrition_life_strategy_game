class_name TakeoutFoodRowCardV2
extends PanelContainer

const TOUCH_TAP_SLOP := 18.0

signal selected(item_id: String)
signal detail_requested(payload: Dictionary, anchor_rect: Rect2, pinned: bool)
signal detail_dismissed(item_id: String)

@onready var art: TextureRect = $Margin/Row/ArtFrame/Art
@onready var name_label: Label = $Margin/Row/Copy/Name
@onready var quick_stat: Label = $Margin/Row/Copy/QuickStat
@onready var price_label: Label = $Margin/Row/Actions/Price
@onready var info_button: Button = $Margin/Row/Actions/ButtonRow/InfoButton
@onready var select_button: Button = $Margin/Row/Actions/ButtonRow/SelectButton
@onready var long_press_timer: Timer = $LongPressTimer

var item_id := ""
var _payload: Dictionary = {}
var _enabled := true
var _selected := false
var _stock := -1
var _disabled_reason := ""
var _button_text := "加购"
var _ready_finished := false
var _last_touch_msec := -1000
var _touch_active := false
var _touch_cancelled := false
var _long_press_triggered := false
var _touch_start_position := Vector2.ZERO
var _motion_tween: Tween


func _ready() -> void:
	_ready_finished = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_make_surface_clickable()
	select_button.pressed.connect(_emit_selected)
	info_button.pressed.connect(func() -> void: request_detail(true))
	info_button.focus_entered.connect(func() -> void: request_detail(false))
	info_button.focus_exited.connect(func() -> void: detail_dismissed.emit(item_id))
	long_press_timer.timeout.connect(_on_long_press_timeout)
	mouse_entered.connect(_on_hover_started)
	mouse_exited.connect(_on_hover_ended)
	gui_input.connect(_on_gui_input)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5
	if not _payload.is_empty():
		_apply_payload()


func configure(
	payload: Dictionary,
	_mode: String,
	is_selected: bool = false,
	enabled: bool = true,
	stock: int = -1,
	disabled_reason: String = "",
	button_text: String = ""
) -> void:
	_payload = payload.duplicate(true)
	item_id = String(_payload.get("id", ""))
	_selected = is_selected
	_enabled = enabled
	_stock = stock
	_disabled_reason = disabled_reason
	_button_text = button_text if not button_text.is_empty() else "加购"
	if _ready_finished:
		_apply_payload()


func set_selected(value: bool, animate: bool = true) -> void:
	_selected = value
	if not _ready_finished:
		return
	_update_button_text()
	_update_visual_state(animate)


func set_enabled(value: bool, disabled_reason: String = "") -> void:
	_enabled = value
	_disabled_reason = disabled_reason
	if not _ready_finished:
		return
	select_button.disabled = not value
	_update_visual_state(false)


func set_stock(value: int) -> void:
	_stock = value
	if _ready_finished:
		price_label.text = _cost_text()


func request_detail(pinned: bool = false) -> void:
	if not _ready_finished or _payload.is_empty():
		return
	var detail_payload := _payload.duplicate(true)
	if _stock >= 0:
		detail_payload["stock"] = _stock
	if not _disabled_reason.is_empty():
		detail_payload["disabled_reason"] = _disabled_reason
	detail_requested.emit(detail_payload, get_global_rect(), pinned)


func _apply_payload() -> void:
	name_label.text = String(_payload.get("name", "未命名"))
	quick_stat.text = "饱腹 %s" % _delta(int(_payload.get("satiety", 0)))
	price_label.text = _cost_text()
	art.texture = _load_card_art(String(_payload.get("image", "")))
	art.visible = art.texture != null
	select_button.disabled = not _enabled
	_update_button_text()
	_update_visual_state(false)
	tooltip_text = ""


func _load_card_art(image_path: String) -> Texture2D:
	if image_path.is_empty() or not ResourceLoader.exists(image_path):
		return null
	var source := load(image_path) as Texture2D
	if source == null or image_path.contains("/ui_v2/card_art/"):
		return source
	if not image_path.contains("/generated/cards/"):
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(130, 112, 252, 288)
	atlas.filter_clip = true
	return atlas


func _cost_text() -> String:
	if _stock >= 0:
		return "×%d" % _stock
	var cost := int(_payload.get("cost", 0))
	return "免费" if cost <= 0 else "¥%d" % cost


func _update_button_text() -> void:
	select_button.text = "移出" if _selected else _button_text


func _update_visual_state(animate: bool) -> void:
	self_modulate = Color(0.67, 0.67, 0.64, 0.88) if not _enabled else Color.WHITE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#fff3dff2")
	frame.border_color = Color("#d18a32") if _selected else Color("#8da36b")
	frame.set_border_width_all(4 if _selected else 2)
	frame.set_corner_radius_all(16)
	frame.set_content_margin_all(8)
	frame.shadow_color = Color(0.12, 0.08, 0.04, 0.22)
	frame.shadow_size = 8
	frame.shadow_offset = Vector2(0, 5)
	add_theme_stylebox_override("panel", frame)
	_animate_scale(Vector2(1.018, 1.018) if _selected else Vector2.ONE, 0.14 if animate else 0.0)


func _emit_selected() -> void:
	if _enabled:
		selected.emit(item_id)


func _on_hover_started() -> void:
	if _touch_active or Time.get_ticks_msec() - _last_touch_msec <= 300:
		return
	z_index = 4
	request_detail(false)
	_animate_scale(Vector2(1.018, 1.018), 0.12)


func _on_hover_ended() -> void:
	z_index = 0
	detail_dismissed.emit(item_id)
	_animate_scale(Vector2(1.018, 1.018) if _selected else Vector2.ONE, 0.12)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_active = true
			_touch_cancelled = false
			_long_press_triggered = false
			_touch_start_position = touch.position
			long_press_timer.start()
		else:
			var is_tap := (
				_touch_active
				and not _touch_cancelled
				and not _long_press_triggered
				and touch.position.distance_to(_touch_start_position) <= TOUCH_TAP_SLOP
			)
			var was_long_press := _long_press_triggered
			long_press_timer.stop()
			_touch_active = false
			_last_touch_msec = Time.get_ticks_msec()
			if was_long_press:
				accept_event()
				detail_dismissed.emit(item_id)
				z_index = 0
				_animate_scale(Vector2(1.018, 1.018) if _selected else Vector2.ONE, 0.12)
			elif is_tap:
				accept_event()
				_emit_selected()
			_long_press_triggered = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touch_active and drag.position.distance_to(_touch_start_position) > TOUCH_TAP_SLOP:
			_touch_cancelled = true
			long_press_timer.stop()
			if _long_press_triggered:
				_long_press_triggered = false
				detail_dismissed.emit(item_id)
				z_index = 0
				_animate_scale(Vector2(1.018, 1.018) if _selected else Vector2.ONE, 0.12)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed and Time.get_ticks_msec() - _last_touch_msec > 250:
			accept_event()
			_emit_selected()


func _on_long_press_timeout() -> void:
	if not _touch_active or _touch_cancelled or _payload.is_empty():
		return
	_long_press_triggered = true
	z_index = 5
	request_detail(false)
	_animate_scale(Vector2(1.028, 1.028), 0.12)


func _animate_scale(target: Vector2, duration: float) -> void:
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	if duration <= 0.0:
		scale = target
		return
	_motion_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", target, duration)


func _make_surface_clickable() -> void:
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or control == info_button or control == select_button:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _delta(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
