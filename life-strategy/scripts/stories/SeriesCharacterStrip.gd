class_name SeriesCharacterStrip
extends Button

var character_id := ""
var _art: TextureRect
var _name_label: Label
var _story_label: Label
var _selected := false

func setup(group: Dictionary) -> void:
	character_id = group["id"]
	name = character_id
	text = ""
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var story: Dictionary = group["stories"][0]
	tooltip_text = group["name"] + " · " + story["title"]
	for property in get_property_list():
		if property["name"] == "accessibility_name": set("accessibility_name", tooltip_text)
	_art = TextureRect.new()
	_art.name = "CharacterIllustration"
	_art.texture = load(group.get("selection_art", group["portrait"])) as Texture2D
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	resized.connect(_layout_art)
	var shade := TextureRect.new()
	shade.name = "NameShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.62, 1])
	gradient.colors = PackedColorArray([Color(0.12,0.10,0.08,0), Color(0.12,0.10,0.08,0), Color(0.12,0.10,0.08,0.94)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(0,1)
	shade.texture = texture
	add_child(shade)
	var labels := VBoxContainer.new()
	labels.name = "Nameplate"
	labels.anchor_top = 1.0
	labels.anchor_right = 1.0
	labels.anchor_bottom = 1.0
	labels.offset_left = 20
	labels.offset_right = -20
	labels.offset_top = -104
	labels.offset_bottom = -14
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_theme_constant_override("separation", 4)
	add_child(labels)
	_name_label = HouseholdUI.label(group["name"], 38, Color("#fff2d8"), true)
	labels.add_child(_name_label)
	_story_label = HouseholdUI.label(story["title"] if group["stories"].size() == 1 else "%d段生活故事" % group["stories"].size(), 26, Color("#e2cba5"))
	labels.add_child(_story_label)

func configure(selected: bool, mobile: bool, height: float) -> void:
	_selected = selected
	custom_minimum_size = Vector2((328 if selected else 236) if mobile else (440 if selected else 330), height)
	_name_label.add_theme_font_size_override("font_size", 38 if selected else 32)
	_story_label.add_theme_font_size_override("font_size", 27 if selected else 24)
	_art.modulate = Color.WHITE if selected else Color(0.73,0.73,0.70,1)
	_layout_art()
	HouseholdUI.style_button(self, false, selected)
	for state in ["normal", "hover", "hover_pressed", "pressed", "focus"]:
		var style := get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.set_content_margin_all(0)
		style.set_corner_radius_all(0)
		style.set_border_width_all(4 if selected or state == "focus" else 2)
		style.border_color = Color("#d8a771") if selected else Color("#665b4c")
		add_theme_stylebox_override(state, style)


func _layout_art() -> void:
	if _art == null or _art.texture == null or size.x <= 8 or size.y <= 8: return
	var source := _art.texture.get_size()
	var factor := maxf((size.x - 8) / source.x, (size.y - 8) / source.y)
	_art.size = source * factor
	_art.position = Vector2((size.x - _art.size.x) * 0.5, 4)
