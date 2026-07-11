class_name ToastFeedV2
extends VBoxContainer

const TOAST_ITEM_SCENE := preload("res://scenes/game_v2/components/ToastItem.tscn")

@export_range(1, 6, 1) var visible_limit := 3
@export_range(0.6, 8.0, 0.1) var default_duration := 2.8

var _active: Array[Control] = []


func push(message: String, tone: String = "info", duration: float = -1.0) -> Control:
	_prune_active()
	var item := TOAST_ITEM_SCENE.instantiate() as PanelContainer
	if item == null:
		return null
	add_child(item)
	_set_mouse_passthrough(item)
	_active.append(item)
	var icon := item.get_node("Margin/Row/Icon") as Label
	var message_label := item.get_node("Margin/Row/Message") as Label
	icon.text = _tone_icon(tone)
	icon.add_theme_color_override("font_color", _tone_color(tone))
	message_label.text = message
	item.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_fade_in_then_out(item, default_duration if duration < 0.0 else duration)
	_trim_overflow()
	return item


func show_toast(message: String, tone: String = "info", duration: float = -1.0) -> Control:
	return push(message, tone, duration)


func post(message: String, tone: String = "info", duration: float = -1.0) -> Control:
	return push(message, tone, duration)


func clear_all(immediate: bool = false) -> void:
	_prune_active()
	for item in _active.duplicate():
		if immediate:
			item.queue_free()
		else:
			_fade_out(item, 0.16)
	_active.clear()


func _fade_in_then_out(item: Control, hold_duration: float) -> void:
	var tween := item.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "modulate:a", 1.0, 0.16)
	tween.tween_interval(maxf(0.3, hold_duration))
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(item, "modulate:a", 0.0, 0.42)
	tween.tween_callback(_release_item.bind(item))


func _fade_out(item: Control, duration: float) -> void:
	if not is_instance_valid(item):
		return
	var tween := item.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(item, "modulate:a", 0.0, duration)
	tween.tween_callback(_release_item.bind(item))


func _trim_overflow() -> void:
	_prune_active()
	while _active.size() > visible_limit:
		var oldest := _active.pop_front() as Control
		_fade_out(oldest, 0.12)


func _release_item(item: Control) -> void:
	_active.erase(item)
	if is_instance_valid(item):
		item.queue_free()


func _prune_active() -> void:
	for index in range(_active.size() - 1, -1, -1):
		if not is_instance_valid(_active[index]):
			_active.remove_at(index)


func _set_mouse_passthrough(root: Control) -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _tone_icon(tone: String) -> String:
	match tone:
		"success", "good":
			return "✓"
		"warning":
			return "!"
		"danger", "error":
			return "×"
		"meal":
			return "●"
		_:
			return "•"


func _tone_color(tone: String) -> Color:
	match tone:
		"success", "good":
			return Color(0.25, 0.55, 0.34, 1.0)
		"warning":
			return Color(0.82, 0.49, 0.16, 1.0)
		"danger", "error":
			return Color(0.72, 0.25, 0.23, 1.0)
		"meal":
			return Color(0.45, 0.35, 0.62, 1.0)
		_:
			return Color(0.30, 0.47, 0.57, 1.0)
