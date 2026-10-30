class_name MealSourceStageV2
extends Control

signal source_selected(source_id: String)
signal skip_requested
signal detail_requested(payload: Dictionary, anchor_rect: Rect2, pinned: bool)
signal detail_dismissed(item_id: String)

const SOURCE_NODE_NAMES := {
	"cafeteria": "CafeteriaProp",
	"takeout": "TakeoutProp",
	"convenience_store": "ConvenienceProp",
	"dorm_storage": "DormProp",
}

@onready var title_label: Label = $PromptTag/VBox/Title
@onready var subtitle_label: Label = $PromptTag/VBox/Subtitle
@onready var prop_layer: Control = $PropLayer
@onready var skip_button: Button = $Footer/SkipButton
@onready var menu_hint_button: Button = $Footer/MenuHintButton

var _sources: Array[Dictionary] = []
var _sources_by_id: Dictionary = {}
var _disabled_reasons: Dictionary = {}
var _meal_label := "这一顿"
var _ready_finished := false
var _has_setup := false
var _prop_tweens: Dictionary = {}
var _prop_base_positions: Dictionary = {}
var _mobile_mode := false
var _action_receipt := ""


func set_action_receipt(text: String) -> void:
	_action_receipt = text
	if _ready_finished: subtitle_label.text = text if not text.is_empty() else ("轻点选择，可查看详情" if _mobile_mode else "悬停看详情")


func setup(sources: Array, meal_label: String = "这一顿", disabled_reasons: Dictionary = {}) -> void:
	_sources.clear()
	_sources_by_id.clear()
	for value in sources:
		if not value is Dictionary:
			continue
		var source: Dictionary = (value as Dictionary).duplicate(true)
		var source_id := String(source.get("id", ""))
		if source_id.is_empty() or not SOURCE_NODE_NAMES.has(source_id):
			continue
		_sources.append(source)
		_sources_by_id[source_id] = source
	_meal_label = meal_label
	_disabled_reasons = disabled_reasons.duplicate(true)
	_has_setup = true
	if _ready_finished:
		_apply_sources()


func set_source_enabled(source_id: String, enabled: bool, reason: String = "") -> void:
	if not _sources_by_id.has(source_id):
		return
	var source: Dictionary = _sources_by_id[source_id]
	source["enabled"] = enabled
	source["disabled_reason"] = reason
	_sources_by_id[source_id] = source
	_disabled_reasons[source_id] = reason
	if _ready_finished:
		_apply_source(source_id)


func _ready() -> void:
	skip_button.pressed.connect(func() -> void: skip_requested.emit())
	menu_hint_button.pressed.connect(_show_help)
	for source_id in SOURCE_NODE_NAMES:
		_bind_prop(String(source_id))
	_ready_finished = true
	if _has_setup:
		_apply_sources()


func _bind_prop(source_id: String) -> void:
	var prop := _prop_for(source_id)
	if prop == null:
		return
	var button := prop.get_node_or_null("Button") as BaseButton
	var info := prop.get_node_or_null("Info") as Button
	var name_label := prop.get_node_or_null("Name") as Label
	if name_label != null:
		var target := Button.new()
		target.name = "NameTarget"
		target.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		target.flat = true
		target.focus_mode = Control.FOCUS_NONE
		target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style in ["normal", "hover", "pressed", "disabled", "focus"]:
			target.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		name_label.add_child(target)
		target.pressed.connect(_choose_source.bind(source_id))
		target.mouse_entered.connect(_show_source_detail.bind(source_id, false))
		target.mouse_exited.connect(_dismiss_source_detail.bind(source_id))
	if button != null:
		button.tooltip_text = ""
		button.pressed.connect(_choose_source.bind(source_id))
		button.mouse_entered.connect(_show_source_detail.bind(source_id, false))
		button.mouse_exited.connect(_dismiss_source_detail.bind(source_id))
		button.mouse_entered.connect(_animate_prop.bind(source_id, true))
		button.mouse_exited.connect(_animate_prop.bind(source_id, false))
		button.button_down.connect(_press_prop.bind(source_id))
		button.focus_entered.connect(_show_source_detail.bind(source_id, false))
		button.focus_exited.connect(_dismiss_source_detail.bind(source_id))
	if info != null:
		info.tooltip_text = ""
		info.pressed.connect(_show_source_detail.bind(source_id, true))
		info.focus_entered.connect(_show_source_detail.bind(source_id, false))
		info.focus_exited.connect(_dismiss_source_detail.bind(source_id))
	prop.resized.connect(_update_prop_pivot.bind(prop))
	_update_prop_pivot(prop)


func _apply_sources() -> void:
	title_label.text = "%s去哪吃？" % _meal_label
	subtitle_label.text = _action_receipt if not _action_receipt.is_empty() else ("轻点选择，可查看详情" if _mobile_mode else "悬停看详情")
	for source_id in SOURCE_NODE_NAMES:
		_apply_source(String(source_id))


func _apply_source(source_id: String) -> void:
	var prop := _prop_for(source_id)
	if prop == null:
		return
	var exists := _sources_by_id.has(source_id)
	prop.visible = exists
	if not exists:
		return
	var source: Dictionary = _sources_by_id[source_id]
	var reason := _source_disabled_reason(source_id)
	var enabled := bool(source.get("enabled", true)) and reason.is_empty()
	var button := prop.get_node_or_null("Button") as BaseButton
	var name_label := prop.get_node_or_null("Name") as Label
	if button != null:
		button.disabled = not enabled
		button.modulate = Color.WHITE if enabled or source_id == "takeout" else Color(0.56, 0.55, 0.51, 0.78)
		var image_path := String(source.get("image", ""))
		if button is TextureButton and not image_path.is_empty() and ResourceLoader.exists(image_path):
			var texture := load(image_path) as Texture2D
			(button as TextureButton).texture_normal = texture
			for shadow_name in ["ShadowSoft", "Shadow"]:
				var shadow := prop.get_node_or_null(shadow_name) as TextureRect
				if shadow != null:
					shadow.texture = texture
					var idle_alpha := 0.24 if shadow_name == "ShadowSoft" else 0.36
					shadow.modulate.a = idle_alpha if enabled else 0.08
	if name_label != null:
		name_label.text = String(source.get("name", source_id))
		name_label.modulate = Color.WHITE if enabled or source_id == "takeout" else Color(0.60, 0.57, 0.51, 1.0)
		var name_target := name_label.get_node_or_null("NameTarget") as Button
		if name_target != null:
			name_target.disabled = not enabled
	var phone := prop.get_node_or_null("PhoneIcon") as TextureRect
	if phone != null:
		phone.modulate = Color.WHITE if enabled else Color(0.88, 0.85, 0.78, 1.0)
	var availability := prop.get_node_or_null("Availability") as Label
	if availability != null:
		availability.text = _opening_periods_text(source)
		if _mobile_mode and availability.text.ends_with("开放"):
			availability.text = availability.text.trim_suffix("开放") + "\n开放"
	var closed_sticker := prop.get_node_or_null("ClosedSticker") as Label
	if closed_sticker != null:
		closed_sticker.visible = source_id == "takeout" or not enabled
		if source_id == "takeout" and enabled:
			closed_sticker.text = "点此选餐"
		elif source_id == "takeout" and reason.contains("时段"):
			closed_sticker.text = "%s未开放" % _meal_label
		else:
			closed_sticker.text = _short_disabled_reason(reason)


func apply_entry_profile(mobile: bool) -> void:
	_mobile_mode = mobile
	subtitle_label.text = _action_receipt if not _action_receipt.is_empty() else ("轻点选择，可查看详情" if mobile else "悬停看详情")
	var prop := _prop_for("takeout")
	if prop == null:
		return
	var phone := prop.get_node("PhoneIcon") as Control
	phone.offset_left = 32.0 if mobile else 4.0
	phone.offset_top = 54.0 if mobile else 0.0
	phone.offset_right = 132.0
	phone.offset_bottom = 174.0 if mobile else 180.0
	var name_label := prop.get_node("Name") as Label
	name_label.offset_left = 12.0 if mobile else 132.0
	name_label.offset_top = 10.0 if mobile else 18.0
	name_label.offset_right = -12.0 if mobile else -70.0
	name_label.offset_bottom = 50.0 if mobile else 58.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if mobile else HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", 30 if mobile else 32)
	var availability := prop.get_node("Availability") as Label
	availability.offset_left = 12.0 if mobile else 132.0
	availability.offset_top = 178.0 if mobile else 66.0
	availability.offset_right = -12.0 if mobile else -16.0
	availability.offset_bottom = 250.0 if mobile else 98.0
	availability.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if mobile else HORIZONTAL_ALIGNMENT_LEFT
	availability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if mobile else TextServer.AUTOWRAP_OFF
	availability.add_theme_font_size_override("font_size", 24)
	var status := prop.get_node("ClosedSticker") as Label
	status.offset_left = 12.0 if mobile else 132.0
	status.offset_top = 254.0 if mobile else 116.0
	status.offset_right = -12.0 if mobile else -20.0
	status.offset_bottom = 292.0 if mobile else 160.0
	status.add_theme_font_size_override("font_size", 20 if mobile else 22)
	var info := prop.get_node("Info") as Button
	var target := 90.0 if mobile else 50.0
	info.custom_minimum_size = Vector2(target, target)
	info.anchor_left = 0.0 if mobile else 1.0
	info.offset_left = 12.0 if mobile else -62.0
	info.offset_top = 296.0 if mobile else 12.0
	info.offset_right = -10.0 if mobile else -12.0
	info.offset_bottom = info.offset_top + target
	info.add_theme_font_size_override("font_size", 20 if mobile else 22)
	info.text = "详情" if mobile else "?"
	info.flat = mobile
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		if mobile:
			info.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		else:
			info.remove_theme_stylebox_override(style_name)
	if mobile:
		info.add_theme_color_override("font_color", Color(0.29, 0.22, 0.14))
		info.add_theme_color_override("font_hover_color", Color(0.22, 0.16, 0.1))
		info.add_theme_color_override("font_pressed_color", Color(0.22, 0.16, 0.1))
	else:
		for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
			info.remove_theme_color_override(color_name)
	if _has_setup:
		_apply_source("takeout")


func _opening_periods_text(source: Dictionary) -> String:
	var names := {"breakfast": "早餐", "lunch": "午餐", "dinner": "晚餐"}
	var scenes: Array = source.get("scenes", [])
	if scenes.has("any"):
		return "各餐开放"
	var periods: Array[String] = []
	for key in names:
		if scenes.has(key):
			periods.append(names[key])
	return "、".join(periods) + "开放" if not periods.is_empty() else "查看开放规则"


func _choose_source(source_id: String) -> void:
	if _sources_by_id.has(source_id) and _source_disabled_reason(source_id).is_empty():
		source_selected.emit(source_id)


func _show_source_detail(source_id: String, pinned: bool) -> void:
	if not _sources_by_id.has(source_id):
		return
	var payload: Dictionary = (_sources_by_id[source_id] as Dictionary).duplicate(true)
	var reason := _source_disabled_reason(source_id)
	if not reason.is_empty():
		payload["disabled_reason"] = reason
	var prop := _prop_for(source_id)
	var button := prop.get_node_or_null("Button") as Control if prop != null else null
	var anchor := button.get_global_rect() if button != null else get_global_rect()
	detail_requested.emit(payload, anchor, pinned)


func _dismiss_source_detail(source_id: String) -> void:
	detail_dismissed.emit(source_id)


func _animate_prop(source_id: String, hovered: bool) -> void:
	var prop := _prop_for(source_id)
	if prop == null:
		return
	if hovered and not _prop_base_positions.has(source_id):
		_prop_base_positions[source_id] = prop.position
	var base_position: Vector2 = _prop_base_positions.get(source_id, prop.position)
	var previous := _prop_tweens.get(source_id) as Tween
	if is_instance_valid(previous):
		previous.kill()
	# The visual shadow children use negative relative z values. Keep the prop
	# group itself above the world background so those shadows remain visible.
	prop.z_index = 20 if hovered else 10
	var tween := prop.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(prop, "scale", Vector2(1.055, 1.055) if hovered else Vector2.ONE, 0.14)
	tween.tween_property(prop, "position", base_position + (Vector2.UP * 7.0 if hovered else Vector2.ZERO), 0.14)
	_prop_tweens[source_id] = tween
	if not hovered:
		_prop_base_positions.erase(source_id)


func _press_prop(source_id: String) -> void:
	var prop := _prop_for(source_id)
	if prop == null:
		return
	if not _prop_base_positions.has(source_id):
		_prop_base_positions[source_id] = prop.position
	var base_position: Vector2 = _prop_base_positions[source_id]
	var previous := _prop_tweens.get(source_id) as Tween
	if is_instance_valid(previous):
		previous.kill()
	prop.z_index = 25
	var tween := prop.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_parallel(true)
	tween.tween_property(prop, "scale", Vector2(1.025, 1.025), 0.07)
	tween.tween_property(prop, "position", base_position + Vector2(0.0, -2.0), 0.07)
	_prop_tweens[source_id] = tween


func _update_prop_pivot(prop: Control) -> void:
	prop.pivot_offset = prop.size * 0.5


func _show_help() -> void:
	var payload := {
		"id": "meal_source_help",
		"name": "这一顿怎么玩",
		"kind": "玩法",
		"desc": "食堂把菜放进餐盘；外卖在手机里滑动加购；便利店从货架放进篮子；宿舍会消耗已有存粮。真正确认前都不会扣钱。",
		"rule_hint": "轻点道具进入，点小圆标查看详细规则。",
	}
	detail_requested.emit(payload, menu_hint_button.get_global_rect(), true)


func _source_disabled_reason(source_id: String) -> String:
	if _disabled_reasons.has(source_id):
		var external_reason := String(_disabled_reasons[source_id])
		if not external_reason.is_empty():
			return external_reason
	if not _sources_by_id.has(source_id):
		return ""
	var source: Dictionary = _sources_by_id[source_id]
	if not bool(source.get("enabled", true)):
		return String(source.get("disabled_reason", "暂时不可用"))
	return String(source.get("disabled_reason", ""))


func _short_disabled_reason(reason: String) -> String:
	if reason.contains("时段"):
		return "未营业"
	if reason.is_empty():
		return "暂未开放"
	if reason.length() <= 7:
		return reason
	return "%s…" % reason.left(6)


func _prop_for(source_id: String) -> Control:
	if not SOURCE_NODE_NAMES.has(source_id) or not is_instance_valid(prop_layer):
		return null
	return prop_layer.get_node_or_null(String(SOURCE_NODE_NAMES[source_id])) as Control
