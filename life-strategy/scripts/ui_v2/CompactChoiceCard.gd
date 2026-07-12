class_name CompactChoiceCardV2
extends PanelContainer

const TOUCH_TAP_SLOP := 18.0

signal selected(item_id: String)
signal detail_requested(payload: Dictionary, anchor_rect: Rect2, pinned: bool)
signal detail_dismissed(item_id: String)

@onready var kind_label: Label = $Margin/VBox/TopRow/Kind
@onready var cost_label: Label = $Margin/VBox/TopRow/Cost
@onready var info_button: Button = $Margin/VBox/TopRow/InfoButton
@onready var art: TextureRect = $Margin/VBox/Art
@onready var title_label: Label = $Margin/VBox/Title
@onready var primary_stat: Label = $Margin/VBox/QuickStats/Primary
@onready var secondary_stat: Label = $Margin/VBox/QuickStats/Secondary
@onready var tertiary_stat: Label = $Margin/VBox/QuickStats/Tertiary
@onready var select_button: Button = $Margin/VBox/SelectButton
@onready var long_press_timer: Timer = $LongPressTimer

var item_id := ""
var _payload: Dictionary = {}
var _mode := ""
var _enabled := true
var _selected := false
var _stock := -1
var _disabled_reason := ""
var _button_text := ""
var _ready_finished := false
var _hovered := false
var _last_touch_msec := -1000
var _emulated_pointer_until_msec := -1000
var _touch_active := false
var _touch_cancelled := false
var _long_press_triggered := false
var _touch_index := -1
var _touch_start_position := Vector2.ZERO
var _motion_tween: Tween


func _ready() -> void:
	_ready_finished = true
	focus_mode = Control.FOCUS_ALL
	_make_surface_clickable()
	select_button.pressed.connect(_emit_selected)
	info_button.pressed.connect(_request_pinned_detail)
	info_button.focus_entered.connect(_request_preview_detail)
	info_button.focus_exited.connect(_dismiss_detail)
	select_button.focus_entered.connect(_request_preview_detail)
	select_button.focus_exited.connect(_dismiss_detail)
	long_press_timer.timeout.connect(_on_long_press_timeout)
	mouse_entered.connect(_on_hover_started)
	mouse_exited.connect(_on_hover_ended)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)
	resized.connect(_update_pivot)
	_update_pivot()
	if not _payload.is_empty():
		_apply_payload()


func configure(
	payload: Dictionary,
	mode: String,
	is_selected: bool = false,
	enabled: bool = true,
	stock: int = -1,
	disabled_reason: String = "",
	button_text: String = ""
) -> void:
	_payload = payload.duplicate(true)
	item_id = String(_payload.get("id", ""))
	_mode = mode
	_selected = is_selected
	_enabled = enabled
	_stock = stock
	_disabled_reason = disabled_reason
	_button_text = button_text
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
	info_button.disabled = false
	_update_visual_state(false)


func set_stock(value: int) -> void:
	_stock = value
	if _ready_finished:
		cost_label.text = _cost_text()
		cost_label.visible = not cost_label.text.is_empty()


func get_payload() -> Dictionary:
	return _payload.duplicate(true)


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
	title_label.text = String(_payload.get("name", _payload.get("title", "未命名")))
	kind_label.text = _kind_text()
	cost_label.text = _cost_text()
	cost_label.visible = not cost_label.text.is_empty()
	var image_path := String(_payload.get("image", ""))
	art.texture = _load_card_art(image_path)
	art.visible = art.texture != null
	_apply_quick_stats()
	select_button.disabled = not _enabled
	info_button.disabled = false
	_update_button_text()
	_apply_frame_style()
	_update_visual_state(false)
	tooltip_text = ""


func _load_card_art(image_path: String) -> Texture2D:
	if image_path.is_empty() or not ResourceLoader.exists(image_path):
		return null
	var source := load(image_path) as Texture2D
	if source == null or image_path.contains("/ui_v2/card_art/"):
		return source
	var region := Rect2()
	if image_path.contains("/generated/cards/"):
		# Existing food files contain a baked card frame. AtlasTexture keeps only
		# the painted food panel so Godot remains the single owner of all borders.
		region = Rect2(130, 112, 252, 288)
	elif image_path.contains("/generated/actions/"):
		# Likewise strip the old action badge/footer without creating cropped
		# derivative files that can drift out of sync.
		region = Rect2(98, 103, 316, 294)
	else:
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	atlas.filter_clip = true
	return atlas


func _apply_quick_stats() -> void:
	primary_stat.visible = false
	secondary_stat.visible = false
	tertiary_stat.visible = false
	match _mode:
		"source":
			_set_quick_stat(primary_stat, "可看 ", int(_payload.get("hand_size", 0)), false)
		"action", "sleep":
			_apply_strongest_stat([
				["精力 ", int(_payload.get("energy", 0)), Color("#387f4a")],
				["压力 ", int(_payload.get("stress", 0)), Color("#b45c64")],
				["复习 ", int(_payload.get("study", 0)), Color("#4d739f")],
				["心情 ", int(_payload.get("mood", 0)), Color("#b06f32")],
			])
		_:
			primary_stat.add_theme_color_override("font_color", Color("#387f4a"))
			_set_quick_stat(primary_stat, "饱腹 ", int(_payload.get("satiety", 0)))


func _apply_strongest_stat(stats: Array) -> void:
	var best: Array = []
	var best_weight := -1
	for stat_variant in stats:
		var stat: Array = stat_variant
		var weight: int = abs(int(stat[1]))
		if weight > best_weight:
			best = stat
			best_weight = weight
	if best.is_empty():
		return
	primary_stat.add_theme_color_override("font_color", best[2] as Color)
	_set_quick_stat(primary_stat, String(best[0]), int(best[1]))


func _set_quick_stat(label: Label, caption: String, value: int, signed: bool = true) -> void:
	label.visible = true
	label.text = "%s%s" % [caption, _delta(value) if signed else str(value)]


func _kind_text() -> String:
	if _payload.has("kind") and not String(_payload["kind"]).is_empty():
		return String(_payload["kind"])
	match _mode:
		"source":
			return "去处"
		"action":
			return "行动"
		"sleep":
			return "今晚"
		_:
			return "食物"


func _cost_text() -> String:
	if _stock >= 0:
		return "×%d" % _stock
	if _mode == "source":
		var fee := int(_payload.get("fee", 0))
		return "不加价" if fee <= 0 else "+¥%d" % fee
	if _payload.has("cost"):
		var cost := int(_payload.get("cost", 0))
		return "免费" if cost <= 0 else "¥%d" % cost
	return ""


func _update_button_text() -> void:
	var base_text := _button_text
	if base_text.is_empty():
		match _mode:
			"source":
				base_text = "去这里"
			"action":
				base_text = "安排"
			"sleep":
				base_text = "就这样"
			_:
				base_text = "加入"
	select_button.text = "移出" if _selected else base_text


func _update_visual_state(animate: bool) -> void:
	var target_color := Color.WHITE
	if not _enabled:
		target_color = Color(0.68, 0.68, 0.65, 0.88)
	elif _selected:
		target_color = Color(1.0, 0.88, 0.68, 1.0)
	self_modulate = target_color
	_apply_frame_style()
	_animate_scale(_target_scale(), 0.14 if animate else 0.0)


func _apply_frame_style() -> void:
	var inherited := get_theme_stylebox("panel")
	var frame: StyleBoxFlat
	if inherited is StyleBoxFlat:
		frame = (inherited as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		frame = StyleBoxFlat.new()
		frame.bg_color = Color("#fff3dded")
		frame.set_corner_radius_all(16)
		frame.set_content_margin_all(10)
	var border_color := Color("#8da36b")
	match _mode:
		"action": border_color = Color("#6683a8")
		"sleep": border_color = Color("#766f9c")
		"source": border_color = Color("#ae824d")
	if _selected:
		border_color = Color("#d18a32")
	elif not _enabled:
		border_color = Color("#9a968c")
	frame.border_color = border_color
	frame.set_border_width_all(4 if _selected else 3)
	frame.shadow_color = Color(0.12, 0.08, 0.04, 0.22)
	frame.shadow_size = 8
	frame.shadow_offset = Vector2(0, 5)
	add_theme_stylebox_override("panel", frame)


func _target_scale() -> Vector2:
	if _hovered and _enabled:
		return Vector2(1.045, 1.045)
	if _selected and _enabled:
		return Vector2(1.018, 1.018)
	return Vector2.ONE


func _animate_scale(target: Vector2, duration: float = 0.12) -> void:
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	if duration <= 0.0:
		scale = target
		return
	_motion_tween = create_tween()
	_motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", target, duration)


func _emit_selected() -> void:
	if _enabled:
		selected.emit(item_id)


func _request_pinned_detail() -> void:
	request_detail(true)


func _request_preview_detail() -> void:
	request_detail(false)


func _dismiss_detail() -> void:
	detail_dismissed.emit(item_id)


func _on_hover_started() -> void:
	if _should_ignore_pointer_preview():
		return
	_hovered = true
	z_index = 4
	request_detail(false)
	_animate_scale(_target_scale())


func _on_hover_ended() -> void:
	_hovered = false
	z_index = 0
	detail_dismissed.emit(item_id)
	_animate_scale(_target_scale())


func _on_focus_entered() -> void:
	if _should_ignore_pointer_preview():
		return
	request_detail(false)
	_animate_scale(Vector2(1.035, 1.035))


func _on_focus_exited() -> void:
	detail_dismissed.emit(item_id)
	_animate_scale(_target_scale())


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_active and touch.index != _touch_index:
				return
			_touch_active = true
			_touch_cancelled = false
			_long_press_triggered = false
			_touch_index = touch.index
			_touch_start_position = touch.position
			long_press_timer.start()
		else:
			if not _touch_active or touch.index != _touch_index:
				return
			var is_tap := (
				_touch_active
				and not _touch_cancelled
				and not _long_press_triggered
				and not touch.canceled
				and touch.position.distance_to(_touch_start_position) <= TOUCH_TAP_SLOP
			)
			var was_long_press := _long_press_triggered
			long_press_timer.stop()
			_touch_active = false
			_touch_index = -1
			_last_touch_msec = Time.get_ticks_msec()
			if was_long_press:
				accept_event()
				detail_dismissed.emit(item_id)
				z_index = 0
				_animate_scale(_target_scale())
			elif is_tap:
				accept_event()
				_emit_selected()
			_long_press_triggered = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if (
			_touch_active
			and drag.index == _touch_index
			and drag.position.distance_to(_touch_start_position) > TOUCH_TAP_SLOP
		):
			_touch_cancelled = true
			long_press_timer.stop()
			if _long_press_triggered:
				_long_press_triggered = false
				detail_dismissed.emit(item_id)
				z_index = 0
				_animate_scale(_target_scale())
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
			accept_event()
			_emit_selected()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.is_action_pressed("ui_accept"):
			accept_event()
			_emit_selected()


func _on_long_press_timeout() -> void:
	if not _touch_active or _touch_cancelled or _payload.is_empty():
		return
	_long_press_triggered = true
	z_index = 5
	request_detail(false)
	_animate_scale(Vector2(1.045, 1.045), 0.12)


func _input(event: InputEvent) -> void:
	# Web touch generates an emulated mouse stream before the raw touch stream.
	# Remember that source before GUI hover/focus callbacks run so a finger-down
	# cannot masquerade as desktop hover.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		_emulated_pointer_until_msec = Time.get_ticks_msec() + 500


func _should_ignore_pointer_preview() -> bool:
	var now := Time.get_ticks_msec()
	return (
		_touch_active
		or now <= _emulated_pointer_until_msec
		or now - _last_touch_msec <= 300
	)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _make_surface_clickable() -> void:
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or control == info_button or control == select_button:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _delta(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
