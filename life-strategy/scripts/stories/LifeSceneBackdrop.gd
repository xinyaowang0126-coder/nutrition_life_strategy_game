class_name LifeSceneBackdrop
extends Control

signal scene_changed(index: int, scene: Dictionary)
const Catalog := preload("res://scripts/stories/LifeSceneCatalog.gd")
const INTERVAL := 10.0
var scenes: Array[Dictionary] = []
var current := 0
var paused := false
var enabled := true
var mobile := false
var _elapsed := 0.0
var _layers: Array[TextureRect] = []
var _front := 0
var _fade: Tween


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(2):
		var image := TextureRect.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
		_layers.append(image)
	scenes = Catalog.all()
	resized.connect(_layout)
	if not scenes.is_empty(): select_scene(0, false)


func _process(delta: float) -> void:
	if not enabled or paused or scenes.size() < 2: return
	_elapsed += delta
	if _elapsed >= INTERVAL: select_scene((current + 1) % scenes.size())


func select_scene(index: int, fade: bool = true) -> void:
	if scenes.is_empty() or _layers.is_empty(): return
	current = posmod(index, scenes.size())
	_elapsed = 0
	if is_instance_valid(_fade): _fade.kill()
	var previous := _front
	_front = 1 - _front
	_layers[_front].texture = load(scenes[current]["image"]) as Texture2D
	_layers[_front].modulate.a = 0 if fade else 1
	_layers[_front].move_to_front()
	_layout()
	if fade:
		_fade = create_tween()
		_fade.tween_property(_layers[_front], "modulate:a", 1.0, 0.8)
	else: _layers[previous].modulate.a = 0
	scene_changed.emit(current, scenes[current].duplicate(true))


func set_mobile(value: bool) -> void:
	mobile = value
	_layout()


func _layout() -> void:
	if scenes.is_empty(): return
	for layer in _layers:
		if layer.texture == null: continue
		var source := layer.texture.get_size()
		var factor := maxf(size.x / source.x, size.y / source.y)
		var scaled := source * factor
		var focus := Vector2(0.5, 0.5)
		if mobile:
			# Each generated scene keeps the person at its own focal point.
			for row in scenes:
				if row["image"] == layer.texture.resource_path:
					focus = Vector2(row.get("mobile_focus_x", 0.72), row.get("mobile_focus_y", 0.5))
		layer.size = scaled
		layer.position = Vector2(clampf(size.x * 0.5 - scaled.x * focus.x, size.x - scaled.x, 0), clampf(size.y * 0.5 - scaled.y * focus.y, size.y - scaled.y, 0))
