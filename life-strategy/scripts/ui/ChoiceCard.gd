class_name ChoiceCard
extends PanelContainer

signal chosen(id: String)

@onready var badge_label: Label = $Margin/Content/TopRow/Badge
@onready var cost_label: Label = $Margin/Content/TopRow/Cost
@onready var card_image: TextureRect = $Margin/Content/Image
@onready var title_label: Label = $Margin/Content/Title
@onready var summary_label: Label = $Margin/Content/Summary
@onready var action_button: Button = $Margin/Content/Action

var item_id := ""
var _enabled := true
var _mode := ""
var _normal_style := _make_style(Color(0.99, 0.96, 0.87, 0.98), Color(0.62, 0.48, 0.29, 0.65), 1)
var _selected_style := _make_style(Color(1.0, 0.92, 0.78, 1.0), Color(0.84, 0.31, 0.18, 0.95), 3)
var _disabled_style := _make_style(Color(0.77, 0.75, 0.69, 0.94), Color(0.45, 0.43, 0.39, 0.55), 1)


func _ready() -> void:
	_bind_nodes()
	action_button.pressed.connect(func(): chosen.emit(item_id))
	mouse_entered.connect(_on_hover_started)
	mouse_exited.connect(_on_hover_ended)
	resized.connect(_update_pivot)
	_update_pivot()


func configure(
	payload: Dictionary,
	mode: String,
	button_text: String,
	enabled: bool = true,
	disabled_reason: String = "",
	stock: int = -1
) -> void:
	_bind_nodes()
	item_id = String(payload.get("id", ""))
	_mode = mode
	_enabled = enabled
	title_label.text = String(payload.get("name", ""))
	badge_label.text = _badge_text(payload, mode)
	cost_label.text = _cost_text(payload, mode, stock)
	summary_label.text = _summary_text(payload, mode)
	action_button.text = button_text
	action_button.disabled = not enabled
	var image_path := String(payload.get("image", ""))
	card_image.texture = load(image_path) if not image_path.is_empty() else null
	card_image.visible = card_image.texture != null
	tooltip_text = _tooltip_text(payload, mode, disabled_reason, stock)
	add_theme_stylebox_override("panel", _normal_style if enabled else _disabled_style)
	modulate = Color.WHITE if enabled else Color(0.82, 0.82, 0.79, 1.0)


func set_selected(selected: bool) -> void:
	_bind_nodes()
	if not _enabled:
		return
	add_theme_stylebox_override("panel", _selected_style if selected else _normal_style)
	action_button.text = "移除" if selected else "选这个"


func set_portrait_mode(enabled: bool) -> void:
	_bind_nodes()
	var desktop_height := 330 if _mode == "source" else 350
	var desktop_image_height := 130 if _mode == "source" else 150
	var desktop_summary_height := 32 if _mode == "source" else 48
	custom_minimum_size = Vector2(0, 720 if enabled else desktop_height)
	card_image.custom_minimum_size.y = 360 if enabled else desktop_image_height
	badge_label.add_theme_font_size_override("font_size", 48 if enabled else 16)
	cost_label.add_theme_font_size_override("font_size", 52 if enabled else 18)
	title_label.add_theme_font_size_override("font_size", 72 if enabled else 26)
	summary_label.add_theme_font_size_override("font_size", 48 if enabled else 18)
	summary_label.custom_minimum_size.y = 120 if enabled else desktop_summary_height
	action_button.add_theme_font_size_override("font_size", 58 if enabled else 20)
	action_button.custom_minimum_size.y = 140 if enabled else 52


func _bind_nodes() -> void:
	if badge_label != null:
		return
	badge_label = get_node("Margin/Content/TopRow/Badge") as Label
	cost_label = get_node("Margin/Content/TopRow/Cost") as Label
	card_image = get_node("Margin/Content/Image") as TextureRect
	title_label = get_node("Margin/Content/Title") as Label
	summary_label = get_node("Margin/Content/Summary") as Label
	action_button = get_node("Margin/Content/Action") as Button


func _badge_text(payload: Dictionary, mode: String) -> String:
	if mode == "food":
		return String(payload.get("kind", "食物"))
	if mode == "source":
		return "地点"
	if mode == "sleep":
		return "今晚"
	return "安排"


func _cost_text(payload: Dictionary, mode: String, stock: int) -> String:
	if stock >= 0:
		return "存量 ×%d" % stock
	if mode == "source":
		var fee := int(payload.get("fee", 0))
		return "无额外费" if fee <= 0 else "另付 ¥%d" % fee
	if mode == "food":
		return "¥%d" % int(payload.get("cost", 0))
	return ""


func _summary_text(payload: Dictionary, mode: String) -> String:
	if mode == "source":
		return "最多 %d 种" % int(payload.get("hand_size", 0))
	if mode == "food":
		return "饱腹 %s · 精力 %s · 心情 %s" % [
			_delta(int(payload.get("satiety", 0))),
			_delta(int(payload.get("energy", 0))),
			_delta(int(payload.get("mood", 0))),
		]
	if mode == "action":
		return "精力 %s · 压力 %s · 复习 %s" % [
			_delta(int(payload.get("energy", 0))),
			_delta(int(payload.get("stress", 0))),
			_delta(int(payload.get("study", 0))),
		]
	return "精力 %s · 心情 %s · 压力 %s" % [
		_delta(int(payload.get("energy", 0))),
		_delta(int(payload.get("mood", 0))),
		_delta(int(payload.get("stress", 0))),
	]


func _tooltip_text(payload: Dictionary, mode: String, disabled_reason: String, stock: int) -> String:
	var lines: Array[String] = [String(payload.get("name", ""))]
	if not disabled_reason.is_empty():
		lines.append(disabled_reason)
	if mode == "food":
		lines.append("饱腹 %s　精力 %s　心情 %s" % [
			_delta(int(payload.get("satiety", 0))),
			_delta(int(payload.get("energy", 0))),
			_delta(int(payload.get("mood", 0))),
		])
		lines.append("压力 %s　身体负担 %s" % [
			_delta(int(payload.get("stress", 0))),
			_delta(int(payload.get("burden", 0))),
		])
		if stock >= 0:
			lines.append("宿舍还剩 %d 份" % stock)
	elif mode == "action" or mode == "sleep":
		lines.append("精力 %s　心情 %s　压力 %s　复习 %s" % [
			_delta(int(payload.get("energy", 0))),
			_delta(int(payload.get("mood", 0))),
			_delta(int(payload.get("stress", 0))),
			_delta(int(payload.get("study", 0))),
		])
	else:
		lines.append("可看到 %d 种选择" % int(payload.get("hand_size", 0)))
	lines.append(String(payload.get("desc", "")))
	return "\n".join(lines)


func _make_custom_tooltip(for_text: String) -> Object:
	var label := Label.new()
	label.text = for_text
	var line_count := maxi(3, for_text.count("\n") + 1)
	label.custom_minimum_size = Vector2(380, 26 * line_count + 24)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	return label


func _on_hover_started() -> void:
	if not _enabled:
		return
	z_index = 4
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.025, 1.025), 0.12)


func _on_hover_ended() -> void:
	z_index = 0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _delta(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


static func _make_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.08, 0.06, 0.04, 0.20)
	style.shadow_size = 5
	return style
