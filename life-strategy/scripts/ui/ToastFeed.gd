class_name ToastFeed
extends VBoxContainer

const MAX_VISIBLE := 4


func push_message(message: String, tone: String = "neutral") -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_stylebox_override("panel", _toast_style(tone))
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	panel.add_child(label)
	add_child(panel)
	panel.modulate.a = 0.0

	while get_child_count() > MAX_VISIBLE:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(3.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.55)
	tween.tween_callback(panel.queue_free)


func _toast_style(tone: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.16, 0.13, 0.94)
	if tone == "warning":
		style.border_color = Color(0.87, 0.47, 0.25, 0.95)
	elif tone == "good":
		style.border_color = Color(0.48, 0.70, 0.47, 0.95)
	else:
		style.border_color = Color(0.86, 0.69, 0.42, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.02, 0.02, 0.02, 0.34)
	style.shadow_size = 6
	return style
