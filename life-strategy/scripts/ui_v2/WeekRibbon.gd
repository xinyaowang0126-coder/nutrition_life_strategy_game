extends HBoxContainer

var _day := 1
var _total := 7


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	update_day(_day, _total)


func update_day(day: int, total: int = 7) -> void:
	_total = maxi(total, 1)
	_day = clampi(day, 1, _total)
	while get_child_count() < _total:
		var step := Label.new()
		step.custom_minimum_size = Vector2(40, 38)
		step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step.mouse_filter = Control.MOUSE_FILTER_IGNORE
		step.add_theme_font_size_override("font_size", 18)
		add_child(step)
	for index in range(get_child_count()):
		var step := get_child(index) as Label
		step.visible = index < _total
		if not step.visible:
			continue
		step.text = "%02d" % (index + 1)
		var current := index + 1 == _day
		var complete := index + 1 < _day
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color("#8e673b") if current else (Color("#ced2ac") if complete else Color("#e8d6b4"))
		frame.border_color = Color("#987a50")
		frame.set_border_width_all(2 if current else 1)
		frame.set_corner_radius_all(8)
		frame.set_content_margin_all(6)
		step.add_theme_stylebox_override("normal", frame)
		step.add_theme_color_override("font_color", Color("#fff1d6") if current else Color("#715a3e"))
