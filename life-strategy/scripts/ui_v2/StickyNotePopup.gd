class_name StickyNotePopupV2
extends PanelContainer

signal closed()
signal action_requested(item_id: String, payload: Dictionary)

@onready var title_label: Label = $Margin/VBox/TitleRow/Title
@onready var cost_label: Label = $Margin/VBox/TitleRow/Cost
@onready var close_button: Button = $Margin/VBox/TitleRow/CloseButton
@onready var kind_tag: Label = $Margin/VBox/KindTag
@onready var rule_hint: Label = $Margin/VBox/RuleHint
@onready var satiety_metric: Label = $Margin/VBox/MetricGrid/Satiety
@onready var energy_metric: Label = $Margin/VBox/MetricGrid/Energy
@onready var mood_metric: Label = $Margin/VBox/MetricGrid/Mood
@onready var stress_metric: Label = $Margin/VBox/MetricGrid/Stress
@onready var burden_metric: Label = $Margin/VBox/MetricGrid/Burden
@onready var study_metric: Label = $Margin/VBox/MetricGrid/Study
@onready var description_label: Label = $Margin/VBox/Description
@onready var disabled_reason_label: Label = $Margin/VBox/DisabledReason
@onready var action_button: Button = $Margin/VBox/ActionButton

var pinned := false
var _payload: Dictionary = {}
var _mode := ""
var _disabled_reason := ""
var _action_text := ""
var _stock := -1
var _anchor_rect := Rect2()
var _mobile_mode := false
var _ready_finished := false
var _motion_tween: Tween


func _ready() -> void:
	_ready_finished = true
	close_button.pressed.connect(_on_close_pressed)
	action_button.pressed.connect(_on_action_pressed)
	resized.connect(_update_pivot)
	if not _payload.is_empty():
		_apply_payload()
	_update_pivot()


func setup(
	payload: Dictionary,
	mode: String = "",
	disabled_reason: String = "",
	action_text: String = "",
	stock: int = -1
) -> void:
	_payload = payload.duplicate(true)
	_mode = mode
	_disabled_reason = disabled_reason
	_action_text = action_text
	_stock = stock
	if _ready_finished:
		_apply_payload()


func present(
	payload: Dictionary,
	mode: String,
	anchor_rect: Rect2,
	is_pinned: bool = false,
	disabled_reason: String = "",
	action_text: String = "",
	mobile: bool = false,
	stock: int = -1
) -> void:
	setup(payload, mode, disabled_reason, action_text, stock)
	show_at(anchor_rect, mobile, is_pinned)


func show_at(anchor_rect: Rect2, mobile: bool = false, is_pinned: bool = false) -> void:
	_anchor_rect = anchor_rect
	_mobile_mode = mobile
	pinned = is_pinned
	visible = true
	move_to_front()
	reset_size()
	call_deferred("_finish_show")


func hide_note(animated: bool = true) -> void:
	if not visible:
		return
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	if not animated:
		visible = false
		modulate = Color.WHITE
		scale = Vector2.ONE
		return
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(self, "modulate:a", 0.0, 0.10)
	_motion_tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.10)
	_motion_tween.chain().tween_callback(_finish_hide)


func is_showing_item(item_id: String) -> bool:
	return visible and String(_payload.get("id", "")) == item_id


func get_payload() -> Dictionary:
	return _payload.duplicate(true)


func _apply_payload() -> void:
	title_label.text = String(_payload.get("name", _payload.get("title", "详情")))
	kind_tag.text = _kind_text()
	rule_hint.text = _rule_text()
	rule_hint.visible = not rule_hint.text.is_empty()
	description_label.text = String(_payload.get("desc", _payload.get("description", "")))
	description_label.visible = not description_label.text.is_empty()
	cost_label.text = _cost_text()
	cost_label.visible = not cost_label.text.is_empty()
	disabled_reason_label.text = _disabled_reason
	disabled_reason_label.visible = not _disabled_reason.is_empty()
	action_button.text = _action_text
	action_button.visible = not _action_text.is_empty()
	action_button.disabled = not _disabled_reason.is_empty()
	_set_metric(satiety_metric, "饱腹", "satiety")
	_set_metric(energy_metric, "精力", "energy")
	_set_metric(mood_metric, "心情", "mood")
	_set_metric(stress_metric, "压力", "stress")
	_set_metric(burden_metric, "负担", "burden", "diet_burden")
	_set_metric(study_metric, "复习", "study", "study_progress")


func _set_metric(label: Label, caption: String, key: String, alias: String = "") -> void:
	var has_value := _payload.has(key) or (not alias.is_empty() and _payload.has(alias))
	label.visible = has_value
	if not has_value:
		return
	var value := int(_payload.get(key, _payload.get(alias, 0)))
	label.text = "%s %s" % [caption, _delta(value)]


func _kind_text() -> String:
	if _payload.has("kind") and not String(_payload["kind"]).is_empty():
		return String(_payload["kind"])
	match _mode:
		"food":
			return "食物"
		"source":
			return "用餐去处"
		"action":
			return "行动"
		"sleep":
			return "今晚"
		"state":
			return "当前状态"
		_:
			return "详情"


func _rule_text() -> String:
	var explicit := String(_payload.get("rule_hint", ""))
	if not explicit.is_empty():
		return explicit
	match _mode:
		"food":
			return "点一下卡牌，把它加入这一餐。"
		"source":
			return "这里能看到 %d 种选择。" % int(_payload.get("hand_size", 0))
		"action":
			return "会占用 %d 个安排位。" % maxi(1, int(_payload.get("slots", 1)))
		"sleep":
			return "今晚就按这个节奏收尾。"
		_:
			return ""


func _cost_text() -> String:
	if _stock >= 0:
		return "还剩 ×%d" % _stock
	if _mode == "source":
		var fee := int(_payload.get("fee", 0))
		return "不加价" if fee <= 0 else "另付 ¥%d" % fee
	if _payload.has("cost"):
		var cost := int(_payload.get("cost", 0))
		return "免费" if cost <= 0 else "¥%d" % cost
	return ""


func _finish_show() -> void:
	if not visible:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var safe_margin := 24.0
	var minimum := get_combined_minimum_size()
	var target_width := minimum.x
	if _mobile_mode:
		target_width = maxf(320.0, viewport_rect.size.x - safe_margin * 2.0)
	size = Vector2(target_width, minimum.y)
	var target_position: Vector2
	if _mobile_mode:
		target_position = Vector2(
			viewport_rect.position.x + safe_margin,
			viewport_rect.end.y - size.y - safe_margin
		)
	else:
		target_position = Vector2(
			_anchor_rect.end.x + 18.0,
			_anchor_rect.get_center().y - size.y * 0.5
		)
		if target_position.x + size.x > viewport_rect.end.x - safe_margin:
			target_position.x = _anchor_rect.position.x - size.x - 18.0
		target_position.x = clampf(
			target_position.x,
			viewport_rect.position.x + safe_margin,
			viewport_rect.end.x - size.x - safe_margin
		)
		target_position.y = clampf(
			target_position.y,
			viewport_rect.position.y + safe_margin,
			viewport_rect.end.y - size.y - safe_margin
		)
	global_position = target_position
	_update_pivot()
	_play_open_animation()


func _play_open_animation() -> void:
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_motion_tween.tween_property(self, "scale", Vector2.ONE, 0.18)


func _on_close_pressed() -> void:
	pinned = false
	hide_note()
	closed.emit()


func _on_action_pressed() -> void:
	action_requested.emit(String(_payload.get("id", "")), _payload.duplicate(true))


func _finish_hide() -> void:
	visible = false
	modulate = Color.WHITE
	scale = Vector2.ONE


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and pinned and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()


func _delta(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
