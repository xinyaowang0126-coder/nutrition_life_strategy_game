class_name DailySummaryPopupV2
extends Control

signal next_day_requested()

@onready var dim: ColorRect = $Dim
@onready var paper_host: Control = $PaperHost
@onready var paper: PanelContainer = $PaperHost/Paper
@onready var paper_margin: MarginContainer = $PaperHost/Paper/Margin
@onready var root_stack: VBoxContainer = $PaperHost/Paper/Margin/VBox
@onready var content_scroll: ScrollContainer = $PaperHost/Paper/Margin/VBox/ContentScroll
@onready var content_stack: VBoxContainer = $PaperHost/Paper/Margin/VBox/ContentScroll/Content
@onready var day_title: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/DayTitle
@onready var ending_image: TextureRect = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/EndingImage
@onready var core_stats: GridContainer = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/CoreStats
@onready var stability_chip: PanelContainer = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/CoreStats/StabilityChip
@onready var study_chip: PanelContainer = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/CoreStats/StudyChip
@onready var balance_chip: PanelContainer = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/CoreStats/BalanceChip
@onready var stability_value: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/CoreStats/StabilityChip/Value
@onready var study_value: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/CoreStats/StudyChip/Value
@onready var balance_value: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/CoreStats/BalanceChip/Value
@onready var quality_label: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/Quality
@onready var advice_label: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/Advice
@onready var detail_button: Button = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/DetailButton
@onready var detail_panel: PanelContainer = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/DetailPanel
@onready var detail_scroll: ScrollContainer = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/DetailPanel/Margin/DetailScroll
@onready var detail_label: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/DetailPanel/Margin/DetailScroll/DetailContent/Detail
@onready var basis_label: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/DetailPanel/Margin/DetailScroll/DetailContent/Basis
@onready var next_button: Button = $PaperHost/Paper/Margin/VBox/NextButton

var _summary: Dictionary = {}
var _mobile_mode := false
var _ready_finished := false
var _motion_tween: Tween
var _detail_closed_text := "查看今日膳食记录"
var _detail_open_text := "收起膳食记录"


func _ready() -> void:
	_ready_finished = true
	next_button.pressed.connect(_on_next_pressed)
	detail_button.pressed.connect(_toggle_nutrition_detail)
	resized.connect(_on_popup_resized)
	if not _summary.is_empty():
		_apply_summary()


func configure(summary: Dictionary, mobile: bool = false) -> void:
	_summary = summary.duplicate(true)
	_mobile_mode = mobile
	if _ready_finished:
		_apply_summary()


func show_summary(summary: Dictionary, mobile: bool = false) -> void:
	detail_panel.visible = false
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
	study_value.text = "复习 %d/%d" % [
		int(stats.get("study_progress", stats.get("study", 0))),
		int(stats.get("study_target", _summary.get("study_target", 70))),
	]
	balance_value.text = "余额 ¥%d" % int(stats.get("balance", 0))
	quality_label.text = String(_summary.get("quality", _summary.get("meal_quality", _default_quality(stats))))
	advice_label.text = String(_summary.get("advice", _summary.get("summary", _default_advice(stats))))
	var image_path := String(_summary.get("ending_image", ""))
	ending_image.visible = not image_path.is_empty() and ResourceLoader.exists(image_path)
	if ending_image.visible:
		ending_image.texture = load(image_path) as Texture2D
	else:
		ending_image.texture = null
	var detail: Dictionary = _summary.get("detail", _summary.get("nutrition", {}))
	var detail_text := String(detail.get("detail_text", ""))
	_detail_closed_text = String(_summary.get("detail_button_text", "查看今日膳食记录"))
	_detail_open_text = String(_summary.get("detail_button_open_text", "收起膳食记录"))
	detail_button.visible = not detail_text.is_empty()
	detail_button.text = _detail_closed_text
	detail_panel.visible = false
	detail_label.text = detail_text
	basis_label.text = String(detail.get("basis", ""))
	basis_label.visible = not basis_label.text.is_empty()
	next_button.text = String(_summary.get("button_text", "睡到明天"))
	content_scroll.scroll_vertical = 0
	detail_scroll.scroll_vertical = 0


func _finish_show() -> void:
	if not visible:
		return
	_layout_popup()
	content_scroll.scroll_vertical = 0
	detail_scroll.scroll_vertical = 0
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


func _toggle_nutrition_detail() -> void:
	if not detail_button.visible:
		return
	detail_panel.visible = not detail_panel.visible
	detail_button.text = _detail_open_text if detail_panel.visible else _detail_closed_text
	detail_scroll.scroll_vertical = 0
	_layout_popup()
	if detail_panel.visible:
		call_deferred("_reveal_detail")
	else:
		content_scroll.scroll_vertical = 0


func _layout_popup() -> void:
	if not _ready_finished:
		return
	var target_size := _target_popup_size(get_viewport().get_visible_rect().size)
	paper_host.size = target_size
	paper.position = Vector2.ZERO
	paper.size = target_size
	_apply_responsive_profile(target_size)
	_center_paper()


func _target_popup_size(viewport_size: Vector2) -> Vector2:
	var ending_layout := String(_summary.get("layout", "")) == "ending"
	var desired_width := 672.0 if _mobile_mode else 780.0
	var desired_height := 0.0
	if detail_panel.visible:
		if _mobile_mode:
			desired_height = 1060.0 if ending_layout else 960.0
		else:
			desired_height = 980.0 if ending_layout else 900.0
	elif ending_layout:
		desired_height = 700.0 if _mobile_mode else 650.0
	elif detail_button.visible:
		desired_height = 600.0 if _mobile_mode else 560.0
	else:
		desired_height = 480.0 if _mobile_mode else 430.0
	var horizontal_inset := 24.0 if _mobile_mode else 48.0
	var vertical_inset := 24.0 if _mobile_mode else 48.0
	return Vector2(
		minf(desired_width, maxf(1.0, viewport_size.x - horizontal_inset)),
		minf(desired_height, maxf(1.0, viewport_size.y - vertical_inset))
	)


func _apply_responsive_profile(target_size: Vector2) -> void:
	var compact := _mobile_mode or target_size.x < 620.0 or target_size.y < 650.0
	var outer_margin := 18 if compact else 34
	var vertical_margin := 16 if compact else 28
	paper_margin.add_theme_constant_override("margin_left", outer_margin)
	paper_margin.add_theme_constant_override("margin_top", vertical_margin)
	paper_margin.add_theme_constant_override("margin_right", outer_margin)
	paper_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	root_stack.add_theme_constant_override("separation", 12 if compact else 16)
	content_stack.add_theme_constant_override("separation", 12 if compact else 16)
	day_title.add_theme_font_size_override("font_size", 28 if compact else 34)
	quality_label.add_theme_font_size_override("font_size", 20 if compact else 23)
	advice_label.add_theme_font_size_override("font_size", 18 if compact else 20)
	detail_button.add_theme_font_size_override("font_size", 18 if compact else 20)
	next_button.add_theme_font_size_override("font_size", 21 if compact else 23)
	ending_image.custom_minimum_size.y = 108.0 if compact else 132.0
	detail_button.custom_minimum_size.y = 48.0 if compact else 50.0
	next_button.custom_minimum_size.y = 56.0 if compact else 64.0

	core_stats.columns = 1 if target_size.x < 430.0 else 3
	var chip_height := 54.0 if compact else 66.0
	var chip_width := 0.0 if compact else 150.0
	for chip: PanelContainer in [stability_chip, study_chip, balance_chip]:
		chip.custom_minimum_size = Vector2(chip_width, chip_height)
	for value: Label in [stability_value, study_value, balance_value]:
		value.add_theme_font_size_override("font_size", 18 if compact else 22)

	var ideal_detail_height := 340.0 if _mobile_mode else 310.0
	var available_detail_height := maxf(150.0, target_size.y * 0.42)
	detail_panel.custom_minimum_size.y = minf(ideal_detail_height, available_detail_height)


func _reveal_detail() -> void:
	if visible and detail_panel.visible:
		content_scroll.ensure_control_visible(detail_panel)


func _on_popup_resized() -> void:
	if visible and _ready_finished:
		call_deferred("_layout_popup")


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
