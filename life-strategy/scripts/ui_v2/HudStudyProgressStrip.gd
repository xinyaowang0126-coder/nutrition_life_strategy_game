class_name HudStudyProgressStripV2
extends Control

const SEGMENTS := 14
var value := 0
var target := 70


func _ready() -> void:
	resized.connect(queue_redraw)


func set_progress(next_value: int, next_target: int) -> void:
	value = maxi(0, next_value)
	target = maxi(1, next_target)
	queue_redraw()


func _draw() -> void:
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color("#f5e9d5")
	outline.border_color = Color("#a1aec0")
	outline.set_border_width_all(2)
	outline.set_corner_radius_all(6)
	outline.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var inner := Rect2(Vector2(4, 4), Vector2(maxf(0, size.x - 8), maxf(0, size.y - 8)))
	var gap := 2.0
	var cell_width := maxf(0, (inner.size.x - gap * (SEGMENTS - 1)) / SEGMENTS)
	var filled := clampf(float(value) / target, 0.0, 1.0) * SEGMENTS
	for index in range(SEGMENTS):
		var rect := Rect2(inner.position + Vector2(index * (cell_width + gap), 0), Vector2(cell_width, inner.size.y))
		var cell := StyleBoxFlat.new()
		cell.set_corner_radius_all(2)
		cell.bg_color = Color("#cbd0d8")
		cell.draw(get_canvas_item(), rect)
		var fraction := clampf(filled - index, 0.0, 1.0)
		if fraction > 0.0:
			cell.bg_color = Color("#6f8fb5")
			cell.draw(get_canvas_item(), Rect2(rect.position, Vector2(rect.size.x * fraction, rect.size.y)))
