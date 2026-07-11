class_name DailySummaryPopupV2
extends Control

signal next_day_requested()

@onready var dim: ColorRect = $Dim
@onready var paper_host: Control = $PaperHost
@onready var paper: PanelContainer = $PaperHost/Paper
@onready var day_title: Label = $PaperHost/Paper/Margin/VBox/DayTitle
@onready var stability_value: Label = $PaperHost/Paper/Margin/VBox/CoreStats/StabilityChip/Value
@onready var study_value: Label = $PaperHost/Paper/Margin/VBox/CoreStats/StudyChip/Value
@onready var balance_value: Label = $PaperHost/Paper/Margin/VBox/CoreStats/BalanceChip/Value
@onready var quality_label: Label = $PaperHost/Paper/Margin/VBox/Quality
@onready var advice_label: Label = $PaperHost/Paper/Margin/VBox/Advice
@onready var next_button: Button = $PaperHost/Paper/Margin/VBox/NextButton

var _summary: Dictionary = {}
var _mobile_mode := false
var _ready_finished := false
var _motion_tween: Tween


func _ready() -> void:
	_ready_finished = true
	next_button.pressed.connect(_on_next_pressed)
	resized.connect(_center_paper)
	if not _summary.is_empty():
		_apply_summary()


func configure(summary: Dictionary, mobile: bool = false) -> void:
	_summary = summary.duplicate(true)
	_mobile_mode = mobile
	if _ready_finished:
		_apply_summary()


func show_summary(summary: Dictionary, mobile: bool = false) -> void:
	configure(summary, mobile)
	visible = true
	move_to_front()
	call_deferred("_finish_show")


func hide_summary(animated: bool = true) -> void:
	if not visible:
		return
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	if not animated:
		visible = false
		_reset_visuals()
		return
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(dim, "modulate:a", 0.0, 0.12)
	_motion_tween.tween_property(paper_host, "modulate:a", 0.0, 0.12)
	_motion_tween.tween_property(paper_host, "scale", Vector2(0.96, 0.96), 0.12)
	_motion_tween.chain().tween_callback(_finish_hide)


func get_summary() -> Dictionary:
	return _summary.duplicate(true)


func _apply_summary() -> void:
	var stats: Dictionary = _summary
	var nested_stats: Variant = _summary.get("stats", null)
	if nested_stats is Dictionary:
		stats = nested_stats as Dictionary
	var day := int(_summary.get("day", 1))
	day_title.text = String(_summary.get("title", "第 %d 天结束" % day))
	stability_value.text = "余力 %d" % int(stats.get("stability", 0))
	study_value.text = "复习 %d" % int(stats.get("study_progress", stats.get("study", 0)))
	balance_value.text = "余额 ¥%d" % int(stats.get("balance", 0))
	quality_label.text = String(_summary.get("quality", _summary.get("meal_quality", _default_quality(stats))))
	advice_label.text = String(_summary.get("advice", _summary.get("summary", _default_advice(stats))))
	next_button.text = String(_summary.get("button_text", "睡到明天"))


func _finish_show() -> void:
	if not visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var target_size := Vector2(780.0, 430.0)
	if _mobile_mode:
		target_size = Vector2(minf(672.0, viewport_size.x - 48.0), 480.0)
	# PanelContainer may retain a stale minimum-height cache after switching
	# viewport profiles. A clipped plain-Control host owns the visible modal
	# size, while the paper continues to lay out its content normally inside.
	paper_host.size = target_size
	paper.position = Vector2.ZERO
	paper.size = target_size
	_center_paper()
	paper_host.pivot_offset = paper_host.size * 0.5
	dim.modulate.a = 0.0
	paper_host.modulate.a = 0.0
	paper_host.scale = Vector2(0.90, 0.90)
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(dim, "modulate:a", 1.0, 0.18)
	_motion_tween.tween_property(paper_host, "modulate:a", 1.0, 0.18)
	_motion_tween.tween_property(paper_host, "scale", Vector2.ONE, 0.22)
	next_button.grab_focus()


func _center_paper() -> void:
	if not _ready_finished:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	paper_host.global_position = viewport_rect.position + (viewport_rect.size - paper_host.size) * 0.5
	paper_host.pivot_offset = paper_host.size * 0.5


func _on_next_pressed() -> void:
	hide_summary()
	next_day_requested.emit()


func _finish_hide() -> void:
	visible = false
	_reset_visuals()


func _reset_visuals() -> void:
	dim.modulate = Color.WHITE
	paper_host.modulate = Color.WHITE
	paper_host.scale = Vector2.ONE


func _default_quality(stats: Dictionary) -> String:
	var satiety := int(stats.get("satiety", 50))
	var burden := int(stats.get("diet_burden", stats.get("burden", 0)))
	if satiety < 25:
		return "今天有一餐没顾上，肚子还空着。"
	if burden >= 70:
		return "吃是吃够了，只是身体有点累。"
	return "几顿饭都接住了，今天还算踏实。"


func _default_advice(stats: Dictionary) -> String:
	var energy := int(stats.get("energy", 50))
	var stress := int(stats.get("stress", 50))
	if energy <= 25:
		return "电量见底了。今晚别再和自己较劲。"
	if stress >= 75:
		return "脑子还没松下来，明天少塞一件事也没关系。"
	return "今天先放到这里。灯一关，剩下的交给明天。"


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_next_pressed()
