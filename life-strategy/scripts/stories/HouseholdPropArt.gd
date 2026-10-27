class_name HouseholdPropArt
extends Control

const TINT_SHADER := preload("res://scripts/stories/PropTint.gdshader")
var _texture: Texture2D


func setup(texture: Texture2D) -> void:
	_texture = texture
	if is_node_ready():
		for child: TextureRect in get_children(): child.texture = texture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry in [{"name": "Shadow", "tint": Color("#38241442")}, {"name": "Rim", "tint": Color("#fff4dfeb")}, {"name": "Art"}]:
		var picture := HouseholdUI.image(_texture)
		picture.name = entry["name"]
		picture.custom_minimum_size = Vector2.ZERO
		if entry.has("tint"):
			var material := ShaderMaterial.new()
			material.shader = TINT_SHADER
			material.set_shader_parameter("tint", entry["tint"])
			picture.material = material
		add_child(picture)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	pivot_offset = size * 0.5
	for child: TextureRect in get_children():
		child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var margin := 6.0 if child.name == "Rim" else 8.0
		var shift := Vector2(4, 8) if child.name == "Shadow" else Vector2.ZERO
		child.offset_left = margin + shift.x
		child.offset_top = margin + shift.y
		child.offset_right = -margin + shift.x
		child.offset_bottom = -margin + shift.y


func set_focus_highlight(active: bool) -> void:
	if not is_node_ready(): return
	(get_node("Rim").material as ShaderMaterial).set_shader_parameter("tint", Color("#76966bd9") if active else Color("#fff4dfeb"))
