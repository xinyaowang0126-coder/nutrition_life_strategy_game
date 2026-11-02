class_name HouseholdFridgeStage
extends "res://scripts/stories/HouseholdMealStage.gd"

const DOOR_ART := preload("res://assets/generated/stories/props/pantry-fridge-v1.png")
var compartments: HBoxContainer
var fridge_panel: PanelContainer
var tray_panel: PanelContainer
var tray_scroll: ScrollContainer
var _door_tween: Tween


func _ready() -> void:
	super._ready()
	var stack := paper_panel.get_child(0) as VBoxContainer
	var old_heading := stack.get_child(_selected_strip.get_index() - 1)
	var stock_button := old_heading.get_node("Kitchen") as Button
	compartments = HBoxContainer.new()
	compartments.name = "OpenFridge"
	compartments.size_flags_vertical = Control.SIZE_EXPAND_FILL
	compartments.add_theme_constant_override("separation", 14)
	stack.add_child(compartments)
	stack.move_child(compartments, 2)
	fridge_panel = _compartment("FridgeShelf", Color("#e9eee4"))
	tray_panel = _compartment("DoorTray", Color("#eee7d8"))
	var shelf := fridge_panel.get_child(0) as VBoxContainer
	var tray := tray_panel.get_child(0) as VBoxContainer
	shelf.add_child(HouseholdUI.label("冰箱里", 23, HouseholdUI.INK, true))
	_move(food_scroll, shelf)
	_grid.columns = 1
	tray.add_child(HouseholdUI.label("这餐取用", 23, HouseholdUI.INK, true))
	tray_scroll = ScrollContainer.new()
	tray_scroll.name = "SelectedShelf"
	tray_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray_scroll.custom_minimum_size.y = 168
	tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray_scroll.follow_focus = true
	tray.add_child(tray_scroll)
	_selected_strip.columns = 1
	_selected_strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_move(_selected_strip, tray_scroll)
	stock_button.text = "保存记录"
	stock_button.size_flags_horizontal = Control.SIZE_FILL
	_move(stock_button, tray)
	old_heading.get_parent().remove_child(old_heading)
	old_heading.queue_free()
	_move(learning_button, tray)
	learning_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_move(_receipt, tray)
	var old_footer := _footer
	_footer = GridContainer.new()
	_footer.name = "Footer"
	_footer.add_theme_constant_override("h_separation", 8)
	_footer.add_theme_constant_override("v_separation", 8)
	tray.add_child(_footer)
	for button in old_footer.get_children(): _move(button, _footer)
	old_footer.get_parent().remove_child(old_footer)
	old_footer.queue_free()
	apply_selection_layout(_layout_mobile_mode)
	tray_scroll.resized.connect(_fit_tray)
	_open_doors.call_deferred()


func _compartment(id: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", HouseholdUI.paper(color, 12, 12))
	compartments.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	return panel


func _move(control: Node, parent: Node) -> void:
	control.get_parent().remove_child(control)
	parent.add_child(control)


func _update_scene_summary() -> void:
	super._update_scene_summary()
	if tray_scroll == null: return
	_note.text = "从左边取食物，选好后在右边开饭。"
	_confirm.text = "再热并开饭" if _selected_ids.any(func(id: String) -> bool: return (_options.get("batch_notes", {}) as Dictionary).has(id)) else "取出并开饭"
	_fit_tray()


func apply_selection_layout(mobile: bool) -> void:
	if compartments == null:
		super.apply_selection_layout(mobile)
		return
	(_footer as GridContainer).columns = 1 if mobile else 3
	super.apply_selection_layout(mobile)
	fridge_panel.size_flags_stretch_ratio = 1.25 if mobile else 1.35
	tray_panel.size_flags_stretch_ratio = 1.0
	for button: Button in _footer.get_children():
		button.custom_minimum_size.y = 62 if mobile else 54
		button.add_theme_font_size_override("font_size", 18 if mobile else 20)
	_fit_tray()
	_fit_tray.call_deferred()


func _fit_card_layout(revision: int) -> void:
	super._fit_card_layout(revision)
	_fit_tray()


func _fit_tray() -> void:
	if tray_scroll == null: return
	_selected_strip.columns = 1 if _layout_mobile_mode else clampi(floori((tray_scroll.size.x + 10.0) / 122.0), 1, _max_selected)


func _open_doors() -> void:
	for frame in range(2): await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion(): return
	if compartments.size.x <= 1 or compartments.size.y <= 1: return
	var overlay := Control.new()
	overlay.name = "OpeningDoors"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.clip_contents = true
	add_child(overlay)
	overlay.position = compartments.get_global_position() - get_global_position()
	overlay.size = compartments.size
	var split := fridge_panel.size.x + 7.0
	_door_tween = create_tween().set_parallel(true)
	_door_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for side in [0, 1]:
		var crop := AtlasTexture.new()
		crop.atlas = DOOR_ART
		crop.region = Rect2(Vector2(DOOR_ART.get_size()) * Vector2(0.32, 0.09), Vector2(DOOR_ART.get_size()) * Vector2(0.43, 0.36))
		crop.filter_clip = true
		var door := TextureRect.new()
		door.texture = crop
		door.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		door.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		door.mouse_filter = Control.MOUSE_FILTER_IGNORE
		door.flip_h = side == 1
		door.position.x = 0 if side == 0 else split
		door.size = Vector2(split if side == 0 else overlay.size.x - split, overlay.size.y)
		door.pivot_offset = Vector2(0 if side == 0 else door.size.x, door.size.y * 0.5)
		overlay.add_child(door)
		_door_tween.tween_property(door, "scale:x", 0.02, 0.34)
		_door_tween.tween_property(door, "modulate:a", 0.0, 0.18).set_delay(0.16)
	_door_tween.chain().tween_callback(overlay.queue_free)
