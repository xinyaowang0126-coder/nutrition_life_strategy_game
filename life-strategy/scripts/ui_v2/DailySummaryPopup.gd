class_name DailySummaryPopupV2
extends Control

signal record_book_requested()

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
@onready var meal_trail_title: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/MealTrailTitle
@onready var meal_trail: GridContainer = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/MealTrail
@onready var meal_stamp_panels: Array[PanelContainer] = [
	$PaperHost/Paper/Margin/VBox/ContentScroll/Content/MealTrail/Breakfast,
	$PaperHost/Paper/Margin/VBox/ContentScroll/Content/MealTrail/Lunch,
	$PaperHost/Paper/Margin/VBox/ContentScroll/Content/MealTrail/Dinner,
]
@onready var meal_stamp_labels: Array[Label] = [
	$PaperHost/Paper/Margin/VBox/ContentScroll/Content/MealTrail/Breakfast/Label,
	$PaperHost/Paper/Margin/VBox/ContentScroll/Content/MealTrail/Lunch/Label,
	$PaperHost/Paper/Margin/VBox/ContentScroll/Content/MealTrail/Dinner/Label,
]
@onready var journal_note: PanelContainer = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/JournalNote
@onready var record_kicker: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/JournalNote/Margin/VBox/RecordKicker
@onready var advice_kicker: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/JournalNote/Margin/VBox/AdviceKicker
@onready var record_summary_label: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/JournalNote/Margin/VBox/RecordSummary
@onready var advice_label: Label = $PaperHost/Paper/Margin/VBox/ContentScroll/Content/JournalNote/Margin/VBox/Advice
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
var _next_locked := false
var _detail_closed_text := "查看三餐详情"
var _detail_open_text := "收起三餐详情"
var record_book_button: Button


func _ready() -> void:
	_ready_finished = true
	content_scroll.follow_focus = true
	next_button.pressed.connect(_on_next_pressed)
	detail_button.pressed.connect(_toggle_nutrition_detail)
	record_book_button = Button.new()
	record_book_button.text = "查看选餐记录"
	record_book_button.custom_minimum_size.y = 48
	record_book_button.add_theme_font_size_override("font_size", 20)
	record_book_button.hide()
	detail_button.get_parent().add_child(record_book_button)
	detail_button.get_parent().move_child(record_book_button, detail_button.get_index() + 1)
	record_book_button.pressed.connect(func() -> void: record_book_requested.emit())
	resized.connect(_on_popup_resized)
	if not _summary.is_empty():
		_apply_summary()


func configure(summary: Dictionary, mobile: bool = false) -> void:
	_summary = summary.duplicate(true)
	_mobile_mode = mobile
	if _ready_finished:
		_apply_summary()


func show_summary(summary: Dictionary, mobile: bool = false) -> void:
	if is_instance_valid(_motion_tween): _motion_tween.kill()
	_next_locked = false
	if _ready_finished: next_button.disabled = false
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
	day_title.text = String(_summary.get("title", "第 %d 天，收工" % day))
	stability_value.text = "余力 %d" % int(stats.get("stability", 0))
	study_value.text = "%s %d/%d" % [
		String(stats.get("goal_label", "复习")),
		int(stats.get("study_progress", stats.get("study", 0))),
		int(stats.get("study_target", _summary.get("study_target", 70))),
	]
	balance_value.text = "余额 ¥%d" % int(stats.get("balance", 0))
	var record_text: Variant = _summary.get("record_summary")
	record_summary_label.text = record_text if record_text is String and not record_text.strip_edges().is_empty() else _default_record_summary()
	var recovery: Dictionary = _summary.get("recovery", {})
	if not recovery.is_empty():
		record_summary_label.text += "\n\n%s\n%s\n%s" % [recovery["label"], recovery["summary"], recovery["effect_text"]]
	advice_label.text = String(_summary.get("advice", _summary.get("summary", _default_advice(stats))))
	_apply_meal_stamps(_summary.get("meal_stamps", []))
	var image_path := String(_summary.get("ending_image", ""))
	ending_image.visible = not image_path.is_empty() and ResourceLoader.exists(image_path)
	if ending_image.visible:
		ending_image.texture = load(image_path) as Texture2D
	else:
		ending_image.texture = null
	var detail_value: Variant = _summary.get("detail")
	var detail: Dictionary = detail_value if detail_value is Dictionary else {}
	var detail_text: String = detail.get("detail_text", "") if detail.get("detail_text", "") is String else ""
	_detail_closed_text = String(_summary.get("detail_button_text", "查看三餐详情"))
	_detail_open_text = String(_summary.get("detail_button_open_text", "收起三餐详情"))
	detail_button.visible = not detail_text.is_empty()
	detail_button.text = _detail_closed_text
	detail_panel.visible = false
	detail_label.text = detail_text
	basis_label.text = detail.get("basis", "") if detail.get("basis", "") is String else ""
	basis_label.visible = not basis_label.text.is_empty()
	next_button.text = String(_summary.get("button_text", "睡到明天"))
	record_book_button.visible = bool(_summary.get("record_book_available", false))
	content_scroll.scroll_vertical = 0
	detail_scroll.scroll_vertical = 0


func _apply_meal_stamps(value: Variant) -> void:
	var entries: Array = []
	if value is Array:
		entries = value as Array
	meal_trail.visible = not entries.is_empty()
	meal_trail_title.visible = meal_trail.visible
	if not meal_trail.visible:
		return
	var fallback_titles := ["早餐", "午餐", "晚餐"]
	for index in range(meal_stamp_panels.size()):
		var entry: Dictionary = {}
		if index < entries.size() and entries[index] is Dictionary:
			entry = entries[index] as Dictionary
		var title := String(entry.get("title", fallback_titles[index]))
		var text := String(entry.get("text", "没有记录"))
		var state := String(entry.get("state", "missing"))
		meal_stamp_labels[index].text = "%s\n%s" % [title, text]
		meal_stamp_labels[index].add_theme_color_override(
			"font_color",
			Color("#6f6252") if state != "eaten" else Color("#4f3d2b")
		)
		meal_stamp_panels[index].add_theme_stylebox_override(
			"panel",
			_meal_stamp_style(index, state)
		)


func _meal_stamp_style(index: int, state: String) -> StyleBoxFlat:
	var colors := [Color("#f6d899"), Color("#cfe4bf"), Color("#cbd4ea")]
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ddd3c4") if state != "eaten" else colors[index % colors.size()]
	style.border_color = Color("#9d7d54") if state == "eaten" else Color("#a89b89")
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.12, 0.08, 0.04, 0.15)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	return style


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
	journal_note.pivot_offset = journal_note.size * 0.5
	journal_note.scale = Vector2(0.97, 0.97)
	_motion_tween.tween_property(journal_note, "scale", Vector2.ONE, 0.24)
	for stamp in meal_stamp_panels:
		stamp.pivot_offset = stamp.size * 0.5
		stamp.scale = Vector2(0.94, 0.94) if meal_trail.visible else Vector2.ONE
		if meal_trail.visible:
			_motion_tween.tween_property(stamp, "scale", Vector2.ONE, 0.24)
	if not next_button.disabled: next_button.grab_focus()


func _toggle_nutrition_detail() -> void:
	if not detail_button.visible:
		return
	detail_panel.visible = not detail_panel.visible
	detail_button.text = _detail_open_text if detail_panel.visible else _detail_closed_text
	detail_scroll.scroll_vertical = 0
	_layout_popup()
	if detail_panel.visible:
		detail_panel.pivot_offset = detail_panel.size * 0.5
		detail_panel.modulate.a = 0.0
		detail_panel.scale = Vector2(0.98, 0.98)
		var reveal_tween := create_tween().set_parallel(true)
		reveal_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(detail_panel, "modulate:a", 1.0, 0.14)
		reveal_tween.tween_property(detail_panel, "scale", Vector2.ONE, 0.16)
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
		if meal_trail.visible:
			desired_height = 700.0 if _mobile_mode else 840.0
		else:
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
	record_summary_label.add_theme_font_size_override("font_size", 20 if compact else 23)
	advice_label.add_theme_font_size_override("font_size", 18 if compact else 20)
	record_kicker.add_theme_font_size_override("font_size", 15 if compact else 16)
	advice_kicker.add_theme_font_size_override("font_size", 15 if compact else 16)
	meal_trail_title.add_theme_font_size_override("font_size", 16 if compact else 17)
	detail_button.add_theme_font_size_override("font_size", 18 if compact else 20)
	next_button.add_theme_font_size_override("font_size", 21 if compact else 23)
	ending_image.custom_minimum_size.y = 108.0 if compact else 132.0
	detail_button.custom_minimum_size.y = 48.0 if compact else 50.0
	next_button.custom_minimum_size.y = 56.0 if compact else 64.0

	core_stats.columns = 1 if target_size.x < 430.0 else 3
	meal_trail.columns = 1 if target_size.x < 430.0 else 3
	for index in range(meal_stamp_panels.size()):
		meal_stamp_panels[index].custom_minimum_size.y = 64.0 if compact else 78.0
		meal_stamp_labels[index].add_theme_font_size_override("font_size", 16 if compact else 17)
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
	_scroll_detail_to_end()
	call_deferred("_settle_detail_scroll")


func _settle_detail_scroll() -> void:
	# Container sorting updates the scroll range after the expansion request.
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll_detail_to_end()


func _scroll_detail_to_end() -> void:
	if visible and detail_panel.visible:
		content_scroll.ensure_control_visible(detail_panel)
		var scroll_bar := content_scroll.get_v_scroll_bar()
		content_scroll.scroll_vertical = maxi(0, int(scroll_bar.max_value - scroll_bar.page))


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
	if not is_visible_in_tree() or next_button.disabled or _next_locked:
		return
	_next_locked = true
	next_button.disabled = true
	hide_summary()
	next_day_requested.emit()


func _finish_hide() -> void:
	visible = false
	_reset_visuals()


func _reset_visuals() -> void:
	dim.modulate = Color.WHITE
	paper_host.modulate = Color.WHITE
	paper_host.scale = Vector2.ONE
	journal_note.scale = Vector2.ONE
	detail_panel.modulate = Color.WHITE
	detail_panel.scale = Vector2.ONE
	for stamp in meal_stamp_panels:
		stamp.scale = Vector2.ONE


func _default_record_summary() -> String:
	return "选餐记录暂时不可用。"


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
		var owner := get_viewport().gui_get_focus_owner()
		if owner != null and owner != next_button: return
		get_viewport().set_input_as_handled()
		_on_next_pressed()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not is_processing_unhandled_key_input() or next_button.disabled: return
	if event.is_action_pressed("ui_cancel", true):
		get_viewport().set_input_as_handled()
		if not event.is_echo() and detail_panel.visible:
			_toggle_nutrition_detail()
			detail_button.grab_focus()
	elif HouseholdUI.handle_modal_key(self, event, true):
		get_viewport().set_input_as_handled()
