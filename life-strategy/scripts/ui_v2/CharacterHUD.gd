class_name CharacterHUDV2
extends Control

signal details_requested(payload: Dictionary, anchor_rect: Rect2, pinned: bool)
signal detail_dismissed(source_id: String)

const DETAIL_SOURCE_ID := "character_status"
const DESKTOP_STATUS_TOP := -310.0
const DESKTOP_STATUS_BOTTOM := -90.0
const DESKTOP_STATUS_LEFT := 300.0
const DESKTOP_STATUS_RIGHT := 780.0
const MOBILE_STATUS_TOP := -250.0
const MOBILE_STATUS_BOTTOM := -20.0
const MOBILE_STATUS_LEFT := 226.0
const MOBILE_STATUS_RIGHT := 706.0
const DESKTOP_DETAILS_LEFT := 720.0
const DESKTOP_DETAILS_RIGHT := 770.0
const MOBILE_DETAILS_LEFT := 646.0
const MOBILE_DETAILS_RIGHT := 696.0
const DESKTOP_PORTRAIT_RECT := Rect2(0.0, -630.0, 430.0, 650.0)
const MOBILE_PORTRAIT_RECT := Rect2(-92.0, -630.0, 430.0, 650.0)
const DESKTOP_SHADOW_RECT := Rect2(12.0, -620.0, 430.0, 650.0)
const MOBILE_SHADOW_RECT := Rect2(-80.0, -620.0, 430.0, 650.0)

@onready var portrait: TextureRect = $Portrait
@onready var portrait_shadow: TextureRect = $PortraitShadow
@onready var status_board: PanelContainer = $StatusBoard
@onready var stability_icon: Label = $StatusBoard/Margin/VBox/StabilityRow/StabilityIcon
@onready var stability_label: Label = $StatusBoard/Margin/VBox/StabilityRow/StabilityLabel
@onready var stability_value: Label = $StatusBoard/Margin/VBox/StabilityRow/StabilityValue
@onready var energy_value: Label = $StatusBoard/Margin/VBox/StatGrid/EnergyChip/Value
@onready var mood_value: Label = $StatusBoard/Margin/VBox/StatGrid/MoodChip/Value
@onready var satiety_value: Label = $StatusBoard/Margin/VBox/StatGrid/SatietyChip/Value
@onready var stress_value: Label = $StatusBoard/Margin/VBox/StatGrid/StressChip/Value
@onready var burden_value: Label = $StatusBoard/Margin/VBox/StatGrid/BurdenChip/Value
@onready var study_value: Label = $StatusBoard/Margin/VBox/StatGrid/StudyChip/Value
@onready var details_button: Button = $DetailsButton

var _stats: Dictionary = {}
var _portrait_texture: Texture2D
var _ready_finished := false
var _hover_tween: Tween
var _value_tween: Tween
var _status_controls: Array[Control] = []
var _status_mouse_filters: Array[int] = []


func _ready() -> void:
	_ready_finished = true
	_cache_status_mouse_filters()
	details_button.pressed.connect(_request_pinned_details)
	details_button.focus_entered.connect(_request_preview_details)
	details_button.focus_exited.connect(_dismiss_preview_details)
	status_board.mouse_entered.connect(_on_status_hover_started)
	status_board.mouse_exited.connect(_on_status_hover_ended)
	status_board.resized.connect(_update_board_pivot)
	_update_board_pivot()
	if _portrait_texture != null:
		portrait.texture = _portrait_texture
	if not _stats.is_empty():
		_apply_stats(false)


func apply_responsive_profile(mobile: bool) -> void:
	_apply_control_rect(portrait, MOBILE_PORTRAIT_RECT if mobile else DESKTOP_PORTRAIT_RECT)
	_apply_control_rect(portrait_shadow, MOBILE_SHADOW_RECT if mobile else DESKTOP_SHADOW_RECT)
	status_board.offset_left = MOBILE_STATUS_LEFT if mobile else DESKTOP_STATUS_LEFT
	status_board.offset_right = MOBILE_STATUS_RIGHT if mobile else DESKTOP_STATUS_RIGHT
	status_board.offset_top = MOBILE_STATUS_TOP if mobile else DESKTOP_STATUS_TOP
	status_board.offset_bottom = MOBILE_STATUS_BOTTOM if mobile else DESKTOP_STATUS_BOTTOM
	details_button.offset_left = MOBILE_DETAILS_LEFT if mobile else DESKTOP_DETAILS_LEFT
	details_button.offset_right = MOBILE_DETAILS_RIGHT if mobile else DESKTOP_DETAILS_RIGHT
	_set_status_mouse_passthrough(mobile)
	if mobile:
		if is_instance_valid(_hover_tween):
			_hover_tween.kill()
		status_board.scale = Vector2.ONE


func _apply_control_rect(control: Control, rect: Rect2) -> void:
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y


func configure(stats: Dictionary, animate: bool = false) -> void:
	update_stats(stats, animate)


func update_stats(stats: Dictionary, animate: bool = true) -> void:
	var previous := _stats.duplicate(true)
	_stats = stats.duplicate(true)
	if not _ready_finished:
		return
	_apply_stats(animate, previous)


func set_portrait(value: Variant) -> void:
	var texture: Texture2D = null
	if value is Texture2D:
		texture = value as Texture2D
	elif value is String and not String(value).is_empty() and ResourceLoader.exists(String(value)):
		texture = load(String(value)) as Texture2D
	_portrait_texture = texture
	if _ready_finished:
		portrait.texture = _portrait_texture


func request_details(pinned: bool = true) -> void:
	if not _ready_finished:
		return
	details_requested.emit(_make_detail_payload(), status_board.get_global_rect(), pinned)


func get_state() -> Dictionary:
	return _stats.duplicate(true)


func _apply_stats(animate: bool, previous: Dictionary = {}) -> void:
	var labels: Dictionary = {
		"stability": stability_value,
		"energy": energy_value,
		"mood": mood_value,
		"satiety": satiety_value,
		"stress": stress_value,
		"diet_burden": burden_value,
		"study_progress": study_value,
	}
	var prefixes := {
		"stability": "",
		"energy": "精力 ",
		"mood": "心情 ",
		"satiety": "饱腹 ",
		"stress": "压力 ",
		"diet_burden": "负担 ",
		"study_progress": "复习 ",
	}
	var changed_labels: Array[Label] = []
	for key: String in labels:
		var label := labels[key] as Label
		var value := _stat_value(key)
		label.text = "%s%d" % [String(prefixes[key]), value]
		if animate and int(previous.get(key, _alias_value(previous, key))) != value:
			changed_labels.append(label)
	_apply_status_colors(labels)
	if not changed_labels.is_empty():
		_animate_changed_values(changed_labels)


func _apply_status_colors(labels: Dictionary) -> void:
	for key: String in labels:
		if key == "stability":
			continue
		var value := _stat_value(key)
		var tone := _status_tone(key, value)
		var label := labels[key] as Label
		label.add_theme_color_override("font_color", tone.darkened(0.18))
		var chip := label.get_parent() as PanelContainer
		if chip != null:
			chip.add_theme_stylebox_override("panel", _status_chip_style(tone))
	var stability_tone := _status_tone("stability", _stat_value("stability"))
	stability_icon.add_theme_color_override("font_color", stability_tone)
	stability_label.add_theme_color_override("font_color", stability_tone.darkened(0.22))
	stability_value.add_theme_color_override("font_color", stability_tone.darkened(0.22))
	status_board.add_theme_stylebox_override("panel", _status_board_style(stability_tone))


func _status_tone(key: String, value: int) -> Color:
	if key == "study_progress":
		return Color("#597ba7")
	var danger := false
	var warning := false
	match key:
		"stress", "diet_burden":
			danger = value >= 75
			warning = value >= 50
		"satiety":
			danger = value <= 20 or value >= 92
			warning = value <= 35 or value >= 80
		_:
			danger = value <= 25
			warning = value <= 50
	if danger:
		return Color("#c65449")
	if warning:
		return Color("#c4862f")
	return Color("#4d9062")


func _status_chip_style(tone: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tone.r, tone.g, tone.b, 0.18)
	style.border_color = Color(tone.r, tone.g, tone.b, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _status_board_style(tone: Color) -> StyleBoxFlat:
	var inherited := status_board.get_theme_stylebox("panel")
	var style: StyleBoxFlat
	if inherited is StyleBoxFlat:
		style = (inherited as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
		style.bg_color = Color("#fff4dfea")
		style.set_corner_radius_all(16)
	style.border_color = Color(tone.r, tone.g, tone.b, 0.90)
	style.set_border_width_all(3)
	return style


func _animate_changed_values(labels: Array[Label]) -> void:
	if is_instance_valid(_value_tween):
		_value_tween.kill()
	_value_tween = create_tween().set_parallel(true)
	_value_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for label in labels:
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2(0.86, 0.86)
		label.modulate = Color(1.0, 0.72, 0.34, 1.0)
		_value_tween.tween_property(label, "scale", Vector2.ONE, 0.24)
		_value_tween.tween_property(label, "modulate", Color.WHITE, 0.32)


func _make_detail_payload() -> Dictionary:
	return {
		"id": DETAIL_SOURCE_ID,
		"name": "此刻状态",
		"kind": "状态",
		"rule_hint": _state_hint(),
		"desc": "精力、心情和饱腹越高越从容；压力与身体负担越低越轻松。",
		"stability": _stat_value("stability"),
		"energy": _stat_value("energy"),
		"mood": _stat_value("mood"),
		"satiety": _stat_value("satiety"),
		"stress": _stat_value("stress"),
		"burden": _stat_value("diet_burden"),
		"study": _stat_value("study_progress"),
	}


func _state_hint() -> String:
	var energy := _stat_value("energy")
	var satiety := _stat_value("satiety")
	var stress := _stat_value("stress")
	if satiety <= 25:
		return "肚子已经在提醒你了，下一餐别再拖。"
	if energy <= 25:
		return "今天的电量不多，留一点给真正要紧的事。"
	if stress >= 75:
		return "脑子绷得有点紧，先找机会喘口气。"
	return "目前还稳得住。"


func _stat_value(key: String) -> int:
	if _stats.has(key):
		return int(_stats[key])
	return _alias_value(_stats, key)


func _alias_value(source: Dictionary, key: String) -> int:
	if key == "diet_burden":
		return int(source.get("burden", 0))
	if key == "study_progress":
		return int(source.get("study", 0))
	return int(source.get(key, 0))


func _request_pinned_details() -> void:
	request_details(true)


func _request_preview_details() -> void:
	request_details(false)


func _dismiss_preview_details() -> void:
	detail_dismissed.emit(DETAIL_SOURCE_ID)


func _on_status_hover_started() -> void:
	request_details(false)
	_animate_board(Vector2(1.018, 1.018))


func _on_status_hover_ended() -> void:
	detail_dismissed.emit(DETAIL_SOURCE_ID)
	_animate_board(Vector2.ONE)


func _animate_board(target_scale: Vector2) -> void:
	if is_instance_valid(_hover_tween):
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(status_board, "scale", target_scale, 0.12)


func _update_board_pivot() -> void:
	status_board.pivot_offset = status_board.size * 0.5


func _cache_status_mouse_filters() -> void:
	_status_controls.clear()
	_status_mouse_filters.clear()
	_status_controls.append(status_board)
	_status_mouse_filters.append(status_board.mouse_filter)
	for node in status_board.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null:
			continue
		_status_controls.append(control)
		_status_mouse_filters.append(control.mouse_filter)


func _set_status_mouse_passthrough(enabled: bool) -> void:
	if _status_controls.is_empty():
		_cache_status_mouse_filters()
	for index in range(_status_controls.size()):
		var control := _status_controls[index]
		if not is_instance_valid(control):
			continue
		control.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
			if enabled
			else _status_mouse_filters[index]
		)
