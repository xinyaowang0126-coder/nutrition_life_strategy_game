class_name HouseholdPropButton
extends Button

var _picture: TextureRect
var _caption: Control
var _mask: Image
static var _mask_cache: Dictionary = {}


func set_art_target(picture: TextureRect, caption: Control) -> void:
	_picture = picture
	_caption = caption
	if picture.texture == null: return
	var key := picture.texture.resource_path
	if picture.texture is AtlasTexture:
		var atlas := picture.texture as AtlasTexture
		key = atlas.atlas.resource_path + ":" + str(atlas.region)
	if not _mask_cache.has(key): _mask_cache[key] = picture.texture.get_image()
	_mask = _mask_cache[key] as Image


func _has_point(point: Vector2) -> bool:
	if not is_instance_valid(_picture) or _picture.texture == null:
		return Rect2(Vector2.ZERO, size).has_point(point)
	var canvas_point := get_global_transform() * point
	for child in get_children():
		if child is BaseButton and child.is_visible_in_tree() and child.get_global_rect().has_point(canvas_point): return true
	if is_instance_valid(_caption) and _caption.get_global_rect().has_point(canvas_point): return true
	var picture_point := _picture.get_global_transform().affine_inverse() * canvas_point
	var image_size := _picture.texture.get_size()
	var fit := minf(_picture.size.x / image_size.x, _picture.size.y / image_size.y)
	var drawing := Rect2((_picture.size - image_size * fit) * 0.5, image_size * fit)
	if not drawing.has_point(picture_point): return false
	if _mask == null or _mask.is_empty(): return true
	var uv := (picture_point - drawing.position) / drawing.size
	var x := clampi(int(uv.x * _mask.get_width()), 0, _mask.get_width() - 1)
	var y := clampi(int(uv.y * _mask.get_height()), 0, _mask.get_height() - 1)
	return _mask.get_pixel(x, y).a > 0.18
