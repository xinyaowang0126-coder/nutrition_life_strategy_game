class_name NewDayPopupV2
extends Control

signal continue_requested()

@onready var dim: ColorRect = $Dim
@onready var paper_host: Control = $PaperHost
@onready var paper: PanelContainer = $PaperHost/Paper
@onready var day_title: Label = $PaperHost/Paper/Margin/VBox/DayTitle
@onready var day_subtitle: Label = $PaperHost/Paper/Margin/VBox/DaySubtitle
@onready var body_scroll: ScrollContainer = $PaperHost/Paper/Margin/VBox/BodyScroll
@onready var cards_grid: GridContainer = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid
@onready var learning_card: PanelContainer = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/LearningCard
@onready var status_image_frame: PanelContainer = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/LearningCard/Margin/VBox/ImageFrame
@onready var status_image: TextureRect = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/LearningCard/Margin/VBox/ImageFrame/StatusImage
@onready var status_title: Label = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/LearningCard/Margin/VBox/Title
@onready var status_summary: Label = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/LearningCard/Margin/VBox/Summary
@onready var status_effect: Label = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/LearningCard/Margin/VBox/Effect/Label
@onready var event_card: PanelContainer = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/EventCard
@onready var event_image_frame: PanelContainer = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/EventCard/Margin/VBox/ImageFrame
@onready var event_image: TextureRect = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/EventCard/Margin/VBox/ImageFrame/EventImage
@onready var event_title: Label = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/EventCard/Margin/VBox/Title
@onready var event_summary: Label = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/EventCard/Margin/VBox/Summary
@onready var event_effect: Label = $PaperHost/Paper/Margin/VBox/BodyScroll/CardsGrid/EventCard/Margin/VBox/Effect/Label
@onready var continue_button: Button = $PaperHost/Paper/Margin/VBox/ContinueButton

var _payload: Dictionary = {}
var _mobile_mode := false
var _ready_finished := false
var _motion_tween: Tween
var _continue_locked := false


func _ready() -> void:
	_ready_finished = true
	continue_button.pressed.connect(_on_continue_pressed)
	resized.connect(_apply_layout)
	if not _payload.is_empty():
		_apply_payload()
	_apply_layout()


func show_day(payload: Dictionary, mobile: bool = false) -> void:
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	_continue_locked = false
	_payload = payload.duplicate(true)
	_mobile_mode = mobile
	if _ready_finished:
		_reset_visuals()
		continue_button.disabled = false
		_apply_payload()
	visible = true
	move_to_front()
	call_deferred("_finish_show")


func hide_popup(animated: bool = true) -> void:
	if not visible:
		return
	if not _ready_finished:
		visible = false
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


func get_payload() -> Dictionary:
	return _payload.duplicate(true)


func set_mobile_mode(mobile: bool) -> void:
	_mobile_mode = mobile
	if _ready_finished:
		_apply_layout()


func _apply_payload() -> void:
	var day := maxi(1, int(_payload.get("day", 1)))
	day_title.text = String(_payload.get("title", "第 %d 天开始" % day))
	day_subtitle.text = String(_payload.get(
		"subtitle",
		"昨夜的选择留下一点余韵，今天也有新的变化。"
	))
	day_subtitle.visible = not day_subtitle.text.is_empty()

	var learning_state := _dictionary_value("learning_state", "status")
	status_title.text = String(learning_state.get("title", "状态还算平稳"))
	status_summary.text = String(learning_state.get(
		"summary",
		learning_state.get(
			"description",
			"昨天的饮食和休息，让今天的脑子维持在平常水平。"
		)
	))
	status_effect.text = String(_payload.get(
		"status_effect",
		learning_state.get("effect_text", _learning_effect_text(learning_state))
	))

	var event := _dictionary_value("event", "today_event")
	event_title.text = String(event.get("title", event.get("name", "平常的一天")))
	event_summary.text = String(event.get(
		"summary",
		event.get("description", "今天没有额外事件，可以按自己的节奏安排。")
	))
	event_effect.text = String(_payload.get(
		"event_effect",
		event.get("effect_text", "没有额外影响")
	))

	_set_image(status_image, status_image_frame, String(_payload.get("status_image", "")))
	_set_image(event_image, event_image_frame, String(_payload.get("event_image", "")))
	continue_button.text = String(_payload.get("button_text", "开始今天"))
	body_scroll.scroll_vertical = 0
	_apply_layout()


func _dictionary_value(primary_key: String, fallback_key: String) -> Dictionary:
	var value: Variant = _payload.get(primary_key, _payload.get(fallback_key, {}))
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _learning_effect_text(learning_state: Dictionary) -> String:
	if not learning_state.has("study_modifier"):
		return "每次学习效果不变"
	var modifier := int(learning_state.get("study_modifier", 0))
	if modifier == 0:
		return "每次学习效果不变"
	return "每次学习效果 %s%d" % ["+" if modifier > 0 else "", modifier]


func _set_image(texture_rect: TextureRect, frame: Control, path: String) -> void:
	var texture: Texture2D
	if not path.is_empty() and ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			texture = resource as Texture2D
	texture_rect.texture = texture
	texture_rect.visible = texture != null
	frame.visible = texture != null


func _finish_show() -> void:
	if not visible:
		return
	_apply_layout()
	dim.modulate.a = 0.0
	paper_host.modulate.a = 0.0
	paper_host.scale = Vector2(0.92, 0.92)
	if is_instance_valid(_motion_tween):
		_motion_tween.kill()
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(dim, "modulate:a", 1.0, 0.18)
	_motion_tween.tween_property(paper_host, "modulate:a", 1.0, 0.18)
	_motion_tween.tween_property(paper_host, "scale", Vector2.ONE, 0.22)
	continue_button.grab_focus()


func _apply_layout() -> void:
	if not _ready_finished:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var safe_margin := 16.0 if _mobile_mode else 32.0
	var maximum_width := 672.0 if _mobile_mode else 960.0
	var maximum_height := 1060.0 if _mobile_mode else 760.0
	var target_size := Vector2(
		maxf(280.0, minf(maximum_width, viewport_rect.size.x - safe_margin * 2.0)),
		maxf(420.0, minf(maximum_height, viewport_rect.size.y - safe_margin * 2.0))
	)
	paper_host.size = target_size
	paper_host.global_position = viewport_rect.position + (viewport_rect.size - target_size) * 0.5
	paper_host.pivot_offset = target_size * 0.5
	cards_grid.columns = 1 if _mobile_mode else 2
	status_image_frame.custom_minimum_size.y = 140.0 if _mobile_mode else 180.0
	event_image_frame.custom_minimum_size.y = 140.0 if _mobile_mode else 180.0
	learning_card.custom_minimum_size.y = 340.0 if _mobile_mode else 390.0
	event_card.custom_minimum_size.y = 340.0 if _mobile_mode else 390.0
	day_title.add_theme_font_size_override("font_size", 30 if _mobile_mode else 34)
	_sort_container_tree(paper)
	_sort_container_tree(body_scroll)


func _sort_container_tree(container: Container) -> void:
	container.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in container.get_children():
		if child is Container:
			_sort_container_tree(child as Container)


func _on_continue_pressed() -> void:
	if _continue_locked:
		return
	_continue_locked = true
	continue_button.disabled = true
	hide_popup()
	continue_requested.emit()


func _finish_hide() -> void:
	visible = false
	_continue_locked = false
	continue_button.disabled = false
	_reset_visuals()


func _reset_visuals() -> void:
	dim.modulate = Color.WHITE
	paper_host.modulate = Color.WHITE
	paper_host.scale = Vector2.ONE


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_continue_pressed()
