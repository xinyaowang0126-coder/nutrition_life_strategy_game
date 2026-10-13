class_name SelectedFoodCardV2
extends PanelContainer

@onready var empty_label: Label = $Empty
@onready var face: VBoxContainer = $Face
@onready var price_label: Label = $Face/Price
@onready var preview: TextureRect = $Face/Preview
@onready var title_label: Label = $Face/Title
@onready var satiety_label: Label = $Face/Stats/Satiety
@onready var preference_label: Label = $Face/Stats/Preference

var _filled := false
var _title_size := 18


func _ready() -> void:
	resized.connect(_fit_title)
	_apply_frame()


func show_food(food: Dictionary, texture: Texture2D, from_stock: bool) -> void:
	_filled = true
	empty_label.hide()
	face.show()
	preview.texture = texture
	preview.visible = texture != null
	title_label.text = String(food.get("name", ""))
	price_label.text = "×1" if from_stock else "¥%d" % int(food.get("cost", 0))
	satiety_label.text = "饱腹 %+d" % int(food.get("satiety", 0))
	var preference: Dictionary = food.get("food_preference", {})
	preference_label.text = "口味 %+d" % int(preference.get("mood_delta", 0)) if String(preference.get("status", "")) == "known" else "口味未设置"
	_apply_frame()
	_fit_title()


func clear_food() -> void:
	_filled = false
	face.hide()
	empty_label.show()
	preview.texture = null
	preview.hide()
	_apply_frame()


func set_card_size(value: Vector2, mobile: bool) -> void:
	custom_minimum_size = value
	_title_size = 16 if mobile else 18
	price_label.add_theme_font_size_override("font_size", 13 if mobile else 14)
	for label in [satiety_label, preference_label]:
		label.add_theme_font_size_override("font_size", 12 if mobile else 13)
	_fit_title()


func _fit_title() -> void:
	if not is_node_ready():
		return
	var font := title_label.get_theme_font("font")
	var font_size := _title_size
	var available := maxf(1.0, custom_minimum_size.x - 16.0)
	while font_size > 10 and font.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 1
	title_label.add_theme_font_size_override("font_size", font_size)


func _apply_frame() -> void:
	var frame := (get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat)
	frame.set_content_margin_all(8)
	frame.set_corner_radius_all(12)
	frame.bg_color = Color("#f5dbac") if _filled else Color("#efdfbf80")
	frame.border_color = Color("#d18a32") if _filled else Color("#aa8c5f70")
	frame.set_border_width_all(3 if _filled else 2)
	frame.shadow_size = 4 if _filled else 0
	frame.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", frame)
