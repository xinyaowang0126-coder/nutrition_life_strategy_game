class_name HouseholdMarketStage
extends Control

signal source_selected(source_id: String)
signal back_requested
signal detail_requested(payload: Dictionary, anchor: Rect2, pinned: bool)
signal detail_dismissed(id: String)

const OUTSIDE_ORDER := ["breakfast_shop", "community_canteen", "local_market"]
const WIDE_PLACES := [Rect2(0.15, 0.24, 0.19, 0.28), Rect2(0.43, 0.28, 0.20, 0.28), Rect2(0.77, 0.34, 0.18, 0.27)]
const PORTRAIT_PLACES := [Rect2(0.05, 0.27, 0.36, 0.25), Rect2(0.43, 0.30, 0.30, 0.25), Rect2(0.70, 0.38, 0.285, 0.23)]
const PROP_TEXTURES := {
	"breakfast_shop": preload("res://assets/generated/stories/props/breakfast-steamer-v1.png"),
	"community_canteen": preload("res://assets/generated/stories/props/homestyle-meal-v1.png"),
	"local_market": preload("res://assets/generated/stories/props/fruit-baskets-v1.png"),
}
static var _texture_cache: Dictionary = {}

var back_button: Button
var _choices: Dictionary = {}
var _sources: Dictionary = {}
var _mobile := false
var _plan_summary := ""
var _tweens: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id: String in OUTSIDE_ORDER:
		var button := HouseholdPropButton.new()
		button.name = id
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "hover_pressed", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		add_child(button)
		var illustration := HouseholdPropArt.new()
		illustration.name = "Illustration"
		illustration.setup(_prop_texture(id))
		button.add_child(illustration)
		var plaque := VBoxContainer.new()
		plaque.name = "Plaque"
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(plaque)
		var title := HouseholdUI.label("", 30, HouseholdUI.INK, true)
		title.name = "Name"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		title.add_theme_stylebox_override("normal", HouseholdUI.paper(Color("#f5ecd9e8"), 5, 12))
		plaque.add_child(title)
		var note := HouseholdUI.label("", 19, HouseholdUI.INK)
		note.name = "Note"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_OFF
		note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		note.add_theme_stylebox_override("normal", HouseholdUI.paper(Color("#f5ecd9dc"), 4, 8))
		plaque.add_child(note)
		button.set_art_target(illustration.get_node("Art"), plaque)
		var info := HouseholdUI.info_button()
		info.pressed.connect(_show_detail.bind(id, true))
		button.add_child(info)
		info.mouse_entered.connect(_preview_detail.bind(id, true))
		info.mouse_exited.connect(_preview_detail.bind(id, false))
		info.focus_entered.connect(_preview_detail.bind(id, true))
		info.focus_exited.connect(_preview_detail.bind(id, false))
		button.mouse_entered.connect(_hover_shop.bind(id, true))
		button.mouse_exited.connect(_hover_shop.bind(id, false))
		button.focus_entered.connect(_hover_shop.bind(id, true))
		button.focus_exited.connect(_hover_shop.bind(id, false))
		button.button_down.connect(_animate_shop.bind(id, Vector2(0.98, 0.98)))
		button.pressed.connect(func() -> void:
			if _can_interact() and not button.disabled:
				detail_dismissed.emit(id)
				source_selected.emit(id)
		)
		_choices[id] = button
	back_button = HouseholdUI.button("回家看看", "BackHome")
	back_button.pressed.connect(func() -> void:
		if _can_interact(): back_requested.emit()
	)
	add_child(back_button)
	resized.connect(_place_shops)
	apply_entry_profile(_mobile)


func setup(sources: Array, _meal: String, reasons: Dictionary = {}, plan: String = "") -> void:
	_sources.clear()
	_plan_summary = plan
	for source in sources:
		if not source is Dictionary or not OUTSIDE_ORDER.has(source.get("id")): continue
		var payload: Dictionary = source.duplicate(true)
		var id := String(payload["id"])
		var reason := String(reasons.get(id, payload.get("disabled_reason", "")))
		payload["disabled_reason"] = reason
		payload["enabled"] = bool(payload.get("enabled", true)) and reason.is_empty()
		_sources[id] = payload
	for id: String in OUTSIDE_ORDER:
		var button := _choices[id] as Button
		var source: Dictionary = _sources.get(id, {})
		button.disabled = not bool(source.get("enabled", false))
		var reason := String(source.get("disabled_reason", ""))
		button.tooltip_text = ""
		(button.get_node("Plaque/Name") as Label).text = String(source.get("name", ""))
		var verb := "挑点水果" if id == "local_market" else "逛逛菜单"
		(button.get_node("Plaque/Note") as Label).text = (String(source.get("hours", "")) if reason.contains("时段") else reason) if not reason.is_empty() else "%s · 耗%d精力" % [verb, maxi(0, -int(source.get("energy", 0)))]
		(button.get_node("Plaque/Note") as Label).add_theme_color_override("font_color", HouseholdUI.MUTED if button.disabled else HouseholdUI.GREEN)
		(button.get_node("Illustration") as Control).modulate = Color(0.72, 0.70, 0.65, 0.8) if button.disabled else Color.WHITE
		if _mobile and reason.is_empty(): (button.get_node("Plaque/Note") as Label).text = "耗%d精力" % maxi(0, -int(source.get("energy", 0)))
	_wire_focus()
	_place_shops()


func apply_entry_profile(mobile: bool) -> void:
	_mobile = mobile
	if not is_instance_valid(back_button): return
	for id: String in OUTSIDE_ORDER:
		(_choices[id].get_node("Plaque/Name") as Label).add_theme_font_size_override("font_size", 28 if mobile else 32)
		(_choices[id].get_node("Plaque/Note") as Label).add_theme_font_size_override("font_size", 22 if mobile else 21)
		var info := _choices[id].get_node("Info") as Button
		info.custom_minimum_size = Vector2(80, 80) if mobile else Vector2(54, 54)
	back_button.anchor_left = 0.65 if mobile else 0.81
	back_button.anchor_right = 0.98
	back_button.anchor_top = 0.88
	back_button.anchor_bottom = 0.98
	for side in ["left", "right", "top", "bottom"]: back_button.set("offset_" + side, 0)
	call_deferred("_place_shops")


func _place_shops() -> void:
	var canvas := get_viewport_rect().size
	var places := PORTRAIT_PLACES if _mobile else WIDE_PLACES
	for i in range(OUTSIDE_ORDER.size()):
		var button := _choices[OUTSIDE_ORDER[i]] as Button
		var uv: Rect2 = places[i]
		var bounds := Rect2(uv.position * canvas, uv.size * canvas)
		button.position = bounds.position - get_global_position()
		button.size = bounds.size
		var plaque := button.get_node("Plaque") as Control
		var plaque_height := ceilf(plaque.get_combined_minimum_size().y)
		var illustration := button.get_node("Illustration") as Control
		illustration.position = Vector2.ZERO
		illustration.size = Vector2(button.size.x, maxf(60, button.size.y - plaque_height - 2))
		var info := button.get_node("Info") as Button
		var info_size := info.get_combined_minimum_size()
		plaque.position = Vector2(0, button.size.y - plaque_height)
		plaque.size = Vector2(button.size.x, plaque_height)
		info.position = Vector2(button.size.x - info_size.x, 0)
		info.size = info_size


func _wire_focus() -> void:
	var controls: Array[Control] = []
	for id: String in OUTSIDE_ORDER:
		if not (_choices[id] as Button).disabled: controls.append(_choices[id])
		controls.append(_choices[id].get_node("Info"))
	controls.append(back_button)
	for i in range(controls.size()):
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[posmod(i - 1, controls.size())])


func _can_interact() -> bool:
	return is_visible_in_tree() and not is_queued_for_deletion()


func _show_detail(id: String, pinned: bool) -> void:
	if not _can_interact() or not _sources.has(id): return
	var payload: Dictionary = _sources[id].duplicate(true)
	if not _plan_summary.is_empty(): payload["desc"] = String(payload.get("desc", "")) + "\n\n" + _plan_summary
	detail_requested.emit(payload, (_choices[id] as Control).get_global_rect(), pinned)


func _preview_detail(id: String, active: bool) -> void:
	if active:
		if not _mobile: _show_detail(id, false)
	else:
		detail_dismissed.emit(id)


func _hover_shop(id: String, active: bool) -> void:
	if not _can_interact(): return
	var button := _choices[id] as Button
	(button.get_node("Illustration") as HouseholdPropArt).set_focus_highlight(button.has_focus())
	_animate_shop(id, Vector2(1.055, 1.055) if active else Vector2.ONE)
	_preview_detail(id, active)


func _animate_shop(id: String, target: Vector2) -> void:
	var previous := _tweens.get(id) as Tween
	if is_instance_valid(previous): previous.kill()
	var illustration := _choices[id].get_node("Illustration") as Control
	var tween := illustration.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_parallel(true)
	tween.tween_property(illustration, "scale", target, 0.14)
	tween.tween_property(illustration, "position:y", -6.0 if target.x > 1.0 else (2.0 if target.x < 1.0 else 0.0), 0.14)
	_tweens[id] = tween


func _prop_texture(id: String) -> Texture2D:
	if _texture_cache.has(id): return _texture_cache[id] as Texture2D
	var texture := PROP_TEXTURES[id] as Texture2D
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = texture.get_image().get_used_rect()
	cropped.filter_clip = true
	_texture_cache[id] = cropped
	return cropped


func _unhandled_key_input(event: InputEvent) -> void:
	if _can_interact() and event.is_action_pressed("ui_cancel", true):
		get_viewport().set_input_as_handled()
		if not event.is_echo(): back_requested.emit()
