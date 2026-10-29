class_name HouseholdSourceStage
extends Control

signal source_selected(source_id: String)
signal skip_requested
signal detail_requested(payload: Dictionary, anchor: Rect2, pinned: bool)
signal detail_dismissed(id: String)
signal notebook_requested
signal outings_requested

const WIDE_SCENE := "res://assets/generated/stories/home_source/zhou-home-source-wide-v1.png"
const PORTRAIT_SCENE := "res://assets/generated/stories/home_source/zhou-home-source-portrait-v1.png"
const SOURCE_ORDER := ["home_kitchen", "breakfast_shop", "community_canteen", "local_market", "home_fridge"]
const HOME_ORDER := ["home_kitchen", "home_fridge", "go_out"]
const OUTSIDE_ORDER := HouseholdMarketStage.OUTSIDE_ORDER
const PROP_ART := preload("res://scripts/stories/HouseholdPropArt.gd")
const PROP_BUTTON := preload("res://scripts/stories/HouseholdPropButton.gd")
const PROP_FOLDER := "res://assets/generated/stories/props/"
const PROP_FILES := {"home_kitchen": "cooking-wok-v1", "home_fridge": "pantry-fridge-v1", "go_out": "outing-tote-v1", "notebook": "notebook-pencil-v1"}
const ENTRY_NAMES := {"home_kitchen": "做饭", "home_fridge": "存粮", "go_out": "去集市"}
# Hotspots describe objects in the same real room, never outdoor appliances.
const DESKTOP_PLACES := [
	Rect2(0.025, 0.27, 0.16, 0.18), Rect2(0.165, 0.14, 0.18, 0.45),
	Rect2(0.80, 0.48, 0.18, 0.23),
]
const MOBILE_PLACES := [
	Rect2(0.035, 0.22, 0.27, 0.15), Rect2(0.265, 0.125, 0.34, 0.34),
	Rect2(0.675, 0.45, 0.30, 0.19),
]
const LABEL_HEIGHTS := {"home_kitchen": 0.18, "home_fridge": 0.89, "go_out": 0.83}
static var _texture_cache: Dictionary = {}

var title_label: Label
var prop_layer: Control
var footer: HBoxContainer
var _heading: PanelContainer
var _hint: Label
var _plan_note: Label
var preparation_note: PanelContainer
var _preparation_text: Label
var _sources_by_id: Dictionary = {}
var _props: Dictionary = {}
var _tweens: Dictionary = {}
var _meal := "早餐"
var _plan_summary := ""
var _preparation_summary := ""
var _mobile := false
var _scene_texture: Texture2D
var _prop_regions: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var regions: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROP_FOLDER + "regions.json"))
	if regions is Dictionary: _prop_regions = regions
	_heading = PanelContainer.new()
	_heading.name = "PromptTag"
	_heading.theme = HouseholdUI.GAME_THEME
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)
	var prompt := VBoxContainer.new()
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	_heading.add_child(prompt)
	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(title_label)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(_hint)
	_plan_note = HouseholdUI.label("有个共餐约定", 21, HouseholdUI.GREEN)
	_plan_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(_plan_note)
	preparation_note = PanelContainer.new()
	preparation_note.name = "PreparationNote"
	preparation_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preparation_note.add_theme_stylebox_override("panel", HouseholdUI.paper(HouseholdUI.PAPER, 14, 12))
	add_child(preparation_note)
	_preparation_text = HouseholdUI.label("", 23, HouseholdUI.GREEN)
	preparation_note.add_child(_preparation_text)
	preparation_note.hide()
	prop_layer = Control.new()
	prop_layer.name = "PropLayer"
	prop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prop_layer)
	prop_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for id: String in HOME_ORDER: _build_prop(id)
	footer = HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 14)
	add_child(footer)
	var notebook := HouseholdUI.button("", "Notebook")
	notebook.pressed.connect(func() -> void:
		if _can_interact(): notebook_requested.emit()
	)
	footer.add_child(notebook)
	var book := PROP_ART.new()
	book.name = "Illustration"
	book.setup(_prop_texture("notebook"))
	notebook.add_child(book)
	_rect(book, Rect2(0.05, 0.0, 0.90, 0.80))
	var book_caption := HouseholdUI.label("记事本", 18, HouseholdUI.INK, true)
	book_caption.name = "Caption"
	book_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notebook.add_child(book_caption)
	book_caption.add_theme_stylebox_override("normal", HouseholdUI.paper(Color("#f5ecd9c0"), 2, 8))
	_rect(book_caption, Rect2(0.23, 0.80, 0.54, 0.20))
	notebook.mouse_entered.connect(_hover_notebook.bind(true))
	notebook.mouse_exited.connect(_hover_notebook.bind(false))
	notebook.focus_entered.connect(_hover_notebook.bind(true))
	notebook.focus_exited.connect(_hover_notebook.bind(false))
	var skip := HouseholdUI.button("先不吃", "skip")
	skip.pressed.connect(func() -> void:
		if _can_interact(): skip_requested.emit()
	)
	footer.add_child(skip)
	resized.connect(_refresh_map_layout)
	apply_entry_profile(_mobile)
	_apply_sources()


func setup(sources: Array, meal: String, reasons: Dictionary = {}, plan_summary: String = "", preparation: String = "") -> void:
	_sources_by_id.clear()
	for value in sources:
		if not value is Dictionary: continue
		var source: Dictionary = value.duplicate(true)
		var id := String(source.get("id", ""))
		if not SOURCE_ORDER.has(id): continue
		var reason := String(reasons.get(id, source.get("disabled_reason", "")))
		source["disabled_reason"] = reason
		source["enabled"] = bool(source.get("enabled", true)) and reason.is_empty()
		_sources_by_id[id] = source
	_meal = meal
	_plan_summary = plan_summary
	_preparation_summary = preparation
	if is_node_ready(): _apply_sources()
	call_deferred("_refresh_map_layout")


func _build_prop(id: String) -> void:
	var prop := Control.new()
	prop.name = id + "Prop"
	prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prop_layer.add_child(prop)
	_props[id] = prop
	var button := PROP_BUTTON.new()
	button.name = id
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "disabled", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	prop.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_choose_source.bind(id))
	button.mouse_entered.connect(_hover_prop.bind(id, true))
	button.mouse_exited.connect(_hover_prop.bind(id, false))
	button.focus_entered.connect(_hover_prop.bind(id, true))
	button.focus_exited.connect(_hover_prop.bind(id, false))
	button.button_down.connect(_press_prop.bind(id))
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#fff3bd88"), Color("#fff3bd00")])
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 256
	glow.height = 256
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1, 0.5)
	var halo := HouseholdUI.image(glow)
	halo.name = "Halo"
	halo.custom_minimum_size = Vector2.ZERO
	halo.modulate.a = 0
	prop.add_child(halo)
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var illustration := PROP_ART.new()
	illustration.name = "Illustration"
	illustration.setup(_prop_texture(id))
	prop.add_child(illustration)
	illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plaque := PanelContainer.new()
	plaque.name = "Nameplate"
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_theme_stylebox_override("panel", HouseholdUI.paper(Color("#f5ecd9e8"), 5, 12))
	prop.add_child(plaque)
	var caption := HouseholdUI.label("", 30, HouseholdUI.INK, true)
	caption.name = "Name"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	plaque.add_child(caption)
	button.set_art_target(illustration.get_node("Art"), plaque)
	var info := HouseholdUI.info_button()
	info.pressed.connect(_show_detail.bind(id))
	info.mouse_entered.connect(_preview_detail.bind(id, true))
	info.mouse_exited.connect(_preview_detail.bind(id, false))
	info.focus_entered.connect(_preview_detail.bind(id, true))
	info.focus_exited.connect(_preview_detail.bind(id, false))
	prop.add_child(info)


func _apply_sources() -> void:
	_preparation_text.text = _preparation_summary
	preparation_note.visible = not _preparation_summary.is_empty()
	_layout_preparation_note()
	title_label.text = "%s去哪吃？" % _meal
	_plan_note.visible = not _plan_summary.is_empty()
	for id: String in HOME_ORDER:
		var prop := _props[id] as Control
		prop.visible = id == "go_out" or _sources_by_id.has(id)
		if not prop.visible: continue
		var enabled := true
		var caption := String(ENTRY_NAMES[id])
		if id != "go_out":
			enabled = bool(_sources_by_id[id].get("enabled", false))
		(prop.get_node(id) as Button).disabled = not enabled
		(prop.get_node("Illustration") as Control).modulate = Color.WHITE if enabled else Color(0.72, 0.70, 0.65, 0.72)
		(prop.get_node("Nameplate/Name") as Label).text = caption
	_wire_focus()


func apply_entry_profile(mobile: bool) -> void:
	_mobile = mobile
	if not is_instance_valid(_heading): return
	_heading.anchor_left = 0.5
	_heading.anchor_right = 0.5
	_heading.anchor_top = 0
	_heading.anchor_bottom = 0
	_heading.offset_left = -270 if mobile else -300
	_heading.offset_right = 270 if mobile else 300
	_heading.offset_top = 8 if mobile else 18
	_heading.offset_bottom = 104 if mobile else 116
	_hint.text = "轻点选择，可查看详情" if mobile else "悬停看详情"
	_plan_note.add_theme_font_size_override("font_size", 20 if mobile else 23)
	_preparation_text.add_theme_font_size_override("font_size", 23 if mobile else 25)
	_layout_preparation_note()
	_scene_texture = load(PORTRAIT_SCENE if mobile else WIDE_SCENE) as Texture2D
	var places := MOBILE_PLACES if mobile else DESKTOP_PLACES
	for index in range(HOME_ORDER.size()):
		var id: String = HOME_ORDER[index]
		var prop := _props[id] as Control
		_place_on_map(prop, places[index])
		var plaque := prop.get_node("Nameplate") as PanelContainer
		var label_size := 23 if mobile else 26
		var width := 2 * label_size + 24
		plaque.anchor_left = 0.5
		plaque.anchor_right = 0.5
		plaque.anchor_top = LABEL_HEIGHTS[id]
		plaque.anchor_bottom = LABEL_HEIGHTS[id]
		plaque.offset_left = -width * 0.5
		plaque.offset_right = width * 0.5
		plaque.offset_top = -21
		plaque.offset_bottom = 21
		plaque.pivot_offset = Vector2(width * 0.5, 21)
		(plaque.get_node("Name") as Label).add_theme_font_size_override("font_size", label_size)
		var info := prop.get_node_or_null("Info") as Button
		if info == null: continue
		info.anchor_left = 1
		info.anchor_right = 1
		info.anchor_top = 0.17
		info.anchor_bottom = info.anchor_top
		var target := 80.0 if mobile else 50.0
		info.offset_left = -target
		info.offset_right = 0
		info.offset_top = -target * 0.5
		info.offset_bottom = target * 0.5
		info.custom_minimum_size = Vector2(target, target)
		info.add_theme_font_size_override("font_size", 28 if mobile else 25)
	_rect(footer, Rect2(0.54, 0.84, 0.43, 0.145) if mobile else Rect2(0.76, 0.86, 0.22, 0.125))
	footer.add_theme_constant_override("separation", 12 if mobile else 18)
	for button: Button in footer.get_children():
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if button.name == "Notebook":
			button.custom_minimum_size = Vector2(160, 138 if mobile else 116)
			for state in ["normal", "hover", "hover_pressed", "pressed", "focus"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			(button.get_node("Caption") as Label).add_theme_font_size_override("font_size", 18 if mobile else 20)
		else:
			button.custom_minimum_size.y = 46
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.add_theme_font_size_override("font_size", 22)
			button.add_theme_stylebox_override("normal", HouseholdUI.paper(Color("#f5ecd9ed"), 7, 12))
	if is_node_ready(): _apply_sources()
	call_deferred("_refresh_map_layout")


func _wire_focus() -> void:
	var controls: Array[Control] = []
	for id: String in HOME_ORDER:
		var prop := _props[id] as Control
		if not prop.visible: continue
		var button := prop.get_node(id) as Button
		if not button.disabled: controls.append(button)
		var info := prop.get_node_or_null("Info") as Button
		if info != null: controls.append(info)
	for button: Button in footer.get_children(): controls.append(button)
	for index in range(controls.size()):
		controls[index].focus_previous = controls[index].get_path_to(controls[posmod(index - 1, controls.size())])
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])


func _can_interact() -> bool:
	return is_visible_in_tree() and not is_queued_for_deletion()


func _choose_source(id: String) -> void:
	if not _can_interact(): return
	if id == "go_out":
		outings_requested.emit()
		return
	if not _sources_by_id.has(id) or not bool(_sources_by_id[id].get("enabled", false)): return
	detail_dismissed.emit(id)
	source_selected.emit(id)


func _show_detail(id: String, pinned: bool = true) -> void:
	if not _can_interact(): return
	var payload: Dictionary
	if id == "go_out":
		payload = {"id": id, "name": "去集市", "kind": "外出吃饭", "desc": "早餐店、家常小馆和水果摊，看看哪家正开门。", "rule_hint": "点店铺图片看菜单；确认开饭时才付钱、消耗精力。回家看看不消耗资源。"}
	elif _sources_by_id.has(id):
		payload = _sources_by_id[id].duplicate(true)
	else:
		return
	if not _plan_summary.is_empty(): payload["desc"] = String(payload.get("desc", "")) + "\n\n" + _plan_summary
	detail_requested.emit(payload, (_props[id] as Control).get_global_rect(), pinned)


func _preview_detail(id: String, active: bool) -> void:
	if active:
		if not _mobile: _show_detail(id, false)
	else:
		detail_dismissed.emit(id)


func _hover_prop(id: String, active: bool) -> void:
	if not _can_interact(): return
	var button := _props[id].get_node(id) as Button
	active = active or button.has_focus() or button.is_hovered()
	_props[id].get_node("Illustration").set_focus_highlight(button.has_focus())
	_animate_prop(id, Vector2(1.045, 1.045) if active else Vector2.ONE)
	_preview_detail(id, active)


func _press_prop(id: String) -> void:
	_animate_prop(id, Vector2(0.985, 0.985))


func _animate_prop(id: String, target: Vector2) -> void:
	var prop := _props[id] as Control
	var previous := _tweens.get(id) as Tween
	if is_instance_valid(previous): previous.kill()
	var tween := prop.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	var illustration := prop.get_node("Illustration") as Control
	var lift := -6.0 if target.x > 1.0 else (2.0 if target.x < 1.0 else 0.0)
	tween.tween_property(illustration, "scale", target, 0.14)
	tween.tween_property(illustration, "position:y", lift, 0.14)
	tween.tween_property(illustration, "rotation", -0.02 if id == "go_out" and target.x > 1.0 else 0.0, 0.14)
	tween.tween_property(prop.get_node("Halo"), "modulate:a", 0.7 if target != Vector2.ONE else 0.0, 0.14)
	_tweens[id] = tween


func _hover_notebook(active: bool) -> void:
	if not _can_interact(): return
	var previous := _tweens.get("notebook") as Tween
	if is_instance_valid(previous): previous.kill()
	var book := footer.get_node("Notebook/Illustration") as Control
	var button := footer.get_node("Notebook") as Button
	active = active or button.has_focus() or button.is_hovered()
	book.set_focus_highlight(button.has_focus())
	var tween := book.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(book, "scale", Vector2(1.06, 1.06) if active else Vector2.ONE, 0.14)
	_tweens["notebook"] = tween


func _prop_texture(id: String) -> Texture2D:
	var key := String(PROP_FILES[id])
	if _texture_cache.has(key): return _texture_cache[key] as Texture2D
	var texture := load(PROP_FOLDER + key + ".png") as Texture2D
	if not _prop_regions.has(key):
		_texture_cache[key] = texture
		return texture
	var bounds: Array = _prop_regions[key]
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = Rect2(bounds[0], bounds[1], bounds[2], bounds[3])
	cropped.filter_clip = true
	_texture_cache[key] = cropped
	return cropped


func _refresh_map_layout() -> void:
	if _scene_texture == null or not is_instance_valid(prop_layer): return
	_layout_preparation_note()
	var places := MOBILE_PLACES if _mobile else DESKTOP_PLACES
	for index in range(HOME_ORDER.size()): _place_on_map(_props[HOME_ORDER[index]], places[index])


func _layout_preparation_note() -> void:
	if _preparation_text == null or size.x <= 1: return
	var bounds := Rect2(0.39, 0.56, 0.29, 0.25) if _mobile else Rect2(0.43, 0.48, 0.35, 0.14)
	# Measure wrapping at the final width before the panel consumes the
	# label's minimum height; a zero-width first layout must not grow it.
	_preparation_text.size.x = maxf(1, size.x * bounds.size.x - 28)
	_preparation_text.get_line_count()
	_rect(preparation_note, bounds)


func _place_on_map(control: Control, uv: Rect2) -> void:
	if _scene_texture == null: return
	var canvas := get_viewport_rect().size
	var image_size := _scene_texture.get_size()
	var zoom := maxf(canvas.x / image_size.x, canvas.y / image_size.y)
	var covered := image_size * zoom
	var origin := (canvas - covered) * 0.5
	var bounds := Rect2(origin + uv.position * covered, uv.size * covered).intersection(Rect2(Vector2.ZERO, canvas))
	var plaque := control.get_node("Nameplate") as Control
	var extra := maxf(0.0, plaque.offset_right - plaque.offset_left - bounds.size.x)
	bounds.position.x -= extra * 0.5
	bounds.size.x += extra
	bounds = bounds.intersection(Rect2(Vector2.ZERO, canvas))
	control.position = bounds.position - get_global_position()
	control.size = bounds.size


func _rect(control: Control, bounds: Rect2) -> void:
	control.anchor_left = bounds.position.x
	control.anchor_top = bounds.position.y
	control.anchor_right = bounds.end.x
	control.anchor_bottom = bounds.end.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0
