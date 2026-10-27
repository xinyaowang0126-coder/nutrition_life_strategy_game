class_name MealStageBaseV2
extends Control

signal food_toggled(food_id: String)
signal confirm_requested(food_ids: Array)
signal back_requested
signal skip_requested
signal detail_requested(payload: Dictionary, anchor_rect: Rect2, pinned: bool)
signal detail_dismissed(item_id: String)

const CARD_SCENE := preload("res://scenes/game_v2/components/CompactChoiceCard.tscn")
const DESKTOP_CARD_AREA := Rect2(0.20, 0.11, 0.76, 0.47)
const DESKTOP_SELECTED_AREA := Rect2(0.44, 0.60, 0.40, 0.31)
const MOBILE_CARD_AREA := Rect2(0.02, 0.10, 0.96, 0.44)
const MOBILE_SELECTED_AREA := Rect2(0.29, 0.56, 0.69, 0.30)

var _foods: Array[Dictionary] = []
var _foods_by_id: Dictionary = {}
var _cards_by_id: Dictionary = {}
var _selected_ids: Array[String] = []
var _options: Dictionary = {}
var _stock_by_id: Dictionary = {}
var _max_selected := 3
var _source_fee := 0
var _balance := -1
var _payment_mode := "cash"
var _meal_label := "这一顿"
var _ready_finished := false
var _has_setup := false
var _layout_mobile_mode := false
var _cost_preview_label: Label
var _last_cost_preview: Dictionary = {}
var _cost_layout_revision := 0


func setup(foods: Array, selected_ids: Array = [], options: Dictionary = {}) -> void:
	_foods.clear()
	_foods_by_id.clear()
	for value in foods:
		if not value is Dictionary:
			continue
		var food: Dictionary = (value as Dictionary).duplicate(true)
		var food_id := String(food.get("id", ""))
		if food_id.is_empty() or _foods_by_id.has(food_id):
			continue
		_foods.append(food)
		_foods_by_id[food_id] = food

	_options = options.duplicate(true)
	_max_selected = maxi(1, int(_options.get("max_selected", _default_max_selected())))
	_source_fee = maxi(0, int(_options.get("source_fee", 0)))
	_balance = int(_options.get("balance", -1))
	_payment_mode = String(_options.get("payment_mode", _default_payment_mode()))
	_meal_label = String(_options.get("meal_label", "这一顿"))
	_stock_by_id = (_options.get("stock_by_id", {}) as Dictionary).duplicate(true)
	_selected_ids = _sanitize_selection(selected_ids)
	_has_setup = true
	if _ready_finished:
		_populate_cards()


func set_selection(selected_ids: Array, animate: bool = false) -> void:
	_selected_ids = _sanitize_selection(selected_ids)
	if not _ready_finished:
		return
	_apply_selection(animate)


func get_selected_ids() -> Array[String]:
	return _selected_ids.duplicate()


func set_balance(value: int) -> void:
	_balance = value
	if _ready_finished:
		_refresh_card_availability()
		_update_scene_summary()
		_update_cost_preview()


func set_stock(stock_by_id: Dictionary) -> void:
	_stock_by_id = stock_by_id.duplicate(true)
	if _ready_finished:
		for food_id in _cards_by_id:
			var card: Variant = _cards_by_id[food_id]
			if is_instance_valid(card):
				card.set_stock(_card_stock(String(food_id)))
		_refresh_card_availability()
		_update_scene_summary()
		_update_cost_preview()


func _bind_meal_controls(
	back_button: Button,
	skip_button: Button,
	confirm_button: Button,
	_scroll: ScrollContainer
) -> void:
	_scroll.follow_focus = true
	back_button.pressed.connect(_emit_back)
	skip_button.pressed.connect(_emit_skip)
	confirm_button.pressed.connect(_emit_confirm)
	for slot: SelectedFoodCardV2 in _get_slot_nodes():
		slot.remove_requested.connect(_remove_from_slot.bind(slot))


func _remove_from_slot(food_id: String, slot: SelectedFoodCardV2) -> void:
	if not is_visible_in_tree() or is_queued_for_deletion() or not slot.is_visible_in_tree() or slot.item_id != food_id: return
	var index := _selected_ids.find(food_id)
	if index < 0: return
	var next_id := _selected_ids[(index + 1) % _selected_ids.size()] if _selected_ids.size() > 1 else ""
	var restore_focus := slot.remove_button.has_focus()
	_on_card_selected(food_id)
	if restore_focus: call_deferred("_restore_slot_focus", next_id, food_id)


func _restore_slot_focus(next_id: String, removed_id: String) -> void:
	if not is_visible_in_tree() or is_queued_for_deletion(): return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and not is_ancestor_of(owner): return
	for slot: SelectedFoodCardV2 in _get_slot_nodes():
		if not next_id.is_empty() and slot.item_id == next_id:
			slot.remove_button.grab_focus()
			return
	var card := _cards_by_id.get(removed_id) as Control
	if is_instance_valid(card): card.grab_focus()


func _finish_ready() -> void:
	_ready_finished = true
	_create_cost_preview()
	apply_selection_layout(_layout_mobile_mode)
	if _has_setup:
		_populate_cards()
	else:
		_update_scene_summary()


func _populate_cards() -> void:
	var container := _get_card_container()
	if container == null:
		push_error("%s 没有可用的卡片容器。" % name)
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	_cards_by_id.clear()

	for food in _foods:
		var food_id := String(food.get("id", ""))
		var card: Variant = _create_card()
		if card == null:
			continue
		container.add_child(card)
		_prepare_card(card)
		_cards_by_id[food_id] = card
		var reason := _disabled_reason(food_id)
		card.configure(
			food,
			"food",
			_selected_ids.has(food_id),
			reason.is_empty(),
			_card_stock(food_id),
			reason,
			_card_button_text()
		)
		card.selected.connect(_on_card_selected)
		card.detail_requested.connect(_forward_detail)
		card.detail_dismissed.connect(_forward_detail_dismissed)
	_apply_selection(false)


func _apply_selection(animate: bool) -> void:
	for food_id in _cards_by_id:
		var card: Variant = _cards_by_id[food_id]
		if is_instance_valid(card):
			card.set_selected(_selected_ids.has(String(food_id)), animate)
	_refresh_card_availability()
	_update_slot_labels(animate)
	_update_scene_summary()
	_update_cost_preview()
	var confirm := _get_confirm_button()
	if confirm != null:
		confirm.disabled = _selected_ids.is_empty()


func _create_cost_preview() -> void:
	var paths := _get_layout_paths()
	if not paths.has("selection_box"): return
	var box := get_node(String(paths["selection_box"])) as VBoxContainer
	_cost_preview_label = HouseholdUI.label("", 18, HouseholdUI.MUTED)
	_cost_preview_label.name = "DecisionCosts"
	_cost_preview_label.hide()
	box.add_child(_cost_preview_label)
	box.move_child(_cost_preview_label, 1)
	_cost_preview_label.minimum_size_changed.connect(_queue_cost_layout)
	_cost_preview_label.resized.connect(_queue_cost_layout)


func _get_cost_preview_label() -> Label:
	return _cost_preview_label


func _cost_preview_text(preview: Dictionary) -> String:
	return String(preview.get("text", ""))


func _update_cost_preview() -> void:
	var label := _get_cost_preview_label()
	if label == null: return
	var builder: Callable = _options.get("cost_preview_builder", Callable())
	if not builder.is_valid(): return
	_last_cost_preview = builder.call(_selected_ids)
	label.text = _cost_preview_text(_last_cost_preview)
	label.tooltip_text = String(_last_cost_preview.get("detail", ""))
	label.visible = not label.text.is_empty()
	_queue_cost_layout()


func get_cost_preview() -> Dictionary:
	return _last_cost_preview.duplicate(true)


func _queue_cost_layout() -> void:
	if _cost_preview_label == null or not is_inside_tree(): return
	_cost_layout_revision += 1
	_fit_cost_layout.call_deferred(_cost_layout_revision)


func _fit_cost_layout(revision: int) -> void:
	for frame in range(3):
		if not is_inside_tree() or not visible or is_queued_for_deletion(): return
		await get_tree().process_frame
	if revision == _cost_layout_revision and is_inside_tree() and visible and not is_queued_for_deletion():
		apply_selection_layout(_layout_mobile_mode)


func _refresh_card_availability() -> void:
	for food_id_value in _cards_by_id:
		var food_id := String(food_id_value)
		var card: Variant = _cards_by_id[food_id]
		if not is_instance_valid(card):
			continue
		var reason := _disabled_reason(food_id)
		card.set_enabled(reason.is_empty(), reason)
		card.set_stock(_card_stock(food_id))


func _update_slot_labels(animate: bool) -> void:
	var slots: Array = _get_slot_nodes()
	for index in range(slots.size()):
		var slot := slots[index] as SelectedFoodCardV2
		if slot == null:
			continue
		slot.visible = index < _max_selected
		if index < _selected_ids.size():
			var food_id := _selected_ids[index]
			var food: Dictionary = _foods_by_id.get(food_id, {})
			slot.show_food(food, _food_preview_texture(food), _payment_mode == "stock")
			if animate:
				_pulse_slot(slot)
		else:
			slot.clear_food()


func _food_preview_texture(food: Dictionary) -> Texture2D:
	var image_path := String(food.get("image", ""))
	if image_path.is_empty() or not ResourceLoader.exists(image_path):
		return null
	var source := load(image_path) as Texture2D
	if source == null or image_path.contains("/ui_v2/card_art/"):
		return source
	if not image_path.contains("/generated/cards/"):
		return source
	# Legacy food assets include a baked card frame.  Reuse only their painted
	# center in the scene-authored tray/basket/bowl TextureRect.
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(130, 112, 252, 288)
	atlas.filter_clip = true
	return atlas


func _on_card_selected(food_id: String) -> void:
	if not _foods_by_id.has(food_id):
		return
	var was_selected := _selected_ids.has(food_id)
	if was_selected:
		_selected_ids.erase(food_id)
	else:
		var reason := _disabled_reason(food_id)
		if not reason.is_empty():
			var blocked_card: Variant = _cards_by_id.get(food_id)
			if is_instance_valid(blocked_card):
				blocked_card.request_detail(true)
			return
		_selected_ids.append(food_id)
	_apply_selection(true)
	food_toggled.emit(food_id)


func _disabled_reason(food_id: String) -> String:
	if not _foods_by_id.has(food_id):
		return "这张卡暂时不可用。"
	var food: Dictionary = _foods_by_id[food_id]
	var base_enabled := bool(food.get("enabled", true))
	var base_reason := String(food.get("disabled_reason", ""))
	if not base_enabled:
		return base_reason if not base_reason.is_empty() else "现在还不能选它。"
	if _selected_ids.has(food_id):
		return ""
	if _selected_ids.size() >= _max_selected:
		return "已经放满了，先移出一样。"
	if _payment_mode == "stock" and _card_stock(food_id) <= 0:
		return "柜子里已经没有了。"
	if (
		_payment_mode != "stock"
		and _balance >= 0
		and _selection_total() + int(food.get("cost", 0)) > _balance
	):
		return "余额不够，再换一样吧。"
	return base_reason


func _sanitize_selection(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var food_id := String(value)
		if _foods_by_id.has(food_id) and not result.has(food_id):
			result.append(food_id)
			if result.size() >= _max_selected:
				break
	return result


func _selection_total() -> int:
	var total := _source_fee
	if _payment_mode == "stock":
		return total
	for food_id in _selected_ids:
		var food: Dictionary = _foods_by_id.get(food_id, {})
		total += int(food.get("cost", 0))
	return total


func _card_stock(food_id: String) -> int:
	# Inventory belongs to pantry payment. Cash sources keep their price even
	# when the character owns, consumes or replenishes the same food elsewhere.
	if _payment_mode != "stock":
		return -1
	if _stock_by_id.has(food_id):
		return int(_stock_by_id[food_id])
	var food: Dictionary = _foods_by_id.get(food_id, {})
	return int(food.get("stock", 0))


func _selected_names() -> Array[String]:
	var result: Array[String] = []
	for food_id in _selected_ids:
		var food: Dictionary = _foods_by_id.get(food_id, {})
		result.append(String(food.get("name", food_id)))
	return result


func _emit_back() -> void:
	back_requested.emit()


func _emit_skip() -> void:
	skip_requested.emit()


func _emit_confirm() -> void:
	if not _selected_ids.is_empty():
		confirm_requested.emit(_selected_ids.duplicate())


func _forward_detail(payload: Dictionary, anchor_rect: Rect2, pinned: bool) -> void:
	detail_requested.emit(payload, anchor_rect, pinned)


func _forward_detail_dismissed(item_id: String) -> void:
	detail_dismissed.emit(item_id)


func _pulse_slot(slot: Control) -> void:
	slot.pivot_offset = slot.size * 0.5
	slot.scale = Vector2(0.96, 0.96)
	var tween := slot.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.18)


func apply_selection_layout(mobile: bool) -> void:
	_layout_mobile_mode = mobile
	if not _ready_finished:
		return
	var paths := _get_layout_paths()
	if paths.is_empty():
		return
	var cards := get_node(String(paths["cards"])) as Control
	var selected_area := get_node(String(paths["selection"])) as Control
	_anchor_region(cards, MOBILE_CARD_AREA if mobile else DESKTOP_CARD_AREA)
	_anchor_region(selected_area, MOBILE_SELECTED_AREA if mobile else DESKTOP_SELECTED_AREA)
	var header := get_node(String(paths["header"])) as Control
	header.anchor_left = 0.5
	header.anchor_right = 0.5
	header.anchor_top = 0.0
	header.anchor_bottom = 0.0
	header.offset_left = -294.0 if mobile else -320.0
	header.offset_right = 294.0 if mobile else 320.0
	header.offset_top = 6.0 if mobile else 18.0
	header.offset_bottom = 70.0 if mobile else 82.0
	var footer := get_node(String(paths["footer"])) as HBoxContainer
	footer.anchor_left = 1.0
	footer.anchor_right = 1.0
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = -428.0 if mobile else -528.0
	footer.offset_right = -8.0 if mobile else -18.0
	footer.offset_top = -90.0 if mobile else -72.0
	footer.offset_bottom = -30.0 if mobile else -12.0
	footer.add_theme_constant_override("separation", 10)
	for button_name in ["BackButton", "SkipButton", "ConfirmButton"]:
		var button := footer.get_node(button_name) as Button
		var width := 170 if mobile else 190
		if button_name == "BackButton":
			width = 120 if mobile else 160
		elif button_name == "SkipButton":
			width = 110 if mobile else 140
		button.custom_minimum_size = Vector2(width, 60)
		button.add_theme_font_size_override("font_size", 18 if mobile else 20)
	for path in paths.get("hide", []):
		(get_node(String(path)) as Control).hide()
	if paths.has("selection_margin"):
		var margin := get_node(String(paths["selection_margin"])) as MarginContainer
		for side in ["margin_left", "margin_right"]:
			margin.add_theme_constant_override(side, 16)
		for side in ["margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(side, 4)
	if paths.has("selection_box"):
		var box := get_node(String(paths["selection_box"])) as VBoxContainer
		box.add_theme_constant_override("separation", 8)
		var selected_header := box.get_child(0) as Control
		selected_header.custom_minimum_size.y = 32
		for child in selected_header.find_children("*", "Label", true, false):
			if (child as Label).visible:
				(child as Label).add_theme_font_size_override("font_size", 24)
	var slots := _get_slot_nodes()
	for index in range(slots.size()):
		var slot := slots[index] as SelectedFoodCardV2
		slot.visible = index < _max_selected
		var row := slot.get_parent() as HBoxContainer
		if row != null:
			var count := mini(slots.size(), _max_selected)
			var card_width := (124 if count >= 5 else 142) if not mobile else (76 if count >= 4 else 106)
			# Reserve the panel padding, one header row, and its gap before sizing
			# full card faces. Short portrait screens have less room than tall ones.
			var preview_height := _cost_preview_label.get_combined_minimum_size().y + 8.0 if _cost_preview_label != null and _cost_preview_label.visible else 0.0
			var area_height := size.y * (MOBILE_SELECTED_AREA.size.y if mobile else DESKTOP_SELECTED_AREA.size.y)
			var card_height := mini(216, floori(area_height - 71.0 - preview_height))
			slot.set_card_size(Vector2(card_width, maxi(128, card_height)), mobile)
			row.alignment = BoxContainer.ALIGNMENT_BEGIN
			row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_theme_constant_override("separation", 10 if mobile else 16)


func get_selection_layout_rects() -> Dictionary:
	var paths := _get_layout_paths()
	var result := {}
	for key in ["cards", "selection", "footer"]:
		result[key] = (get_node(String(paths[key])) as Control).get_global_rect()
	return result


func _anchor_region(control: Control, region: Rect2) -> void:
	control.anchor_left = region.position.x
	control.anchor_top = region.position.y
	control.anchor_right = region.end.x
	control.anchor_bottom = region.end.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func _get_layout_paths() -> Dictionary:
	return {}


func _create_card() -> Variant:
	return CARD_SCENE.instantiate()


func _prepare_card(_card: Control) -> void:
	pass


func _get_card_container() -> Container:
	return null


func _get_slot_nodes() -> Array:
	return []


func _get_confirm_button() -> Button:
	return null


func _update_scene_summary() -> void:
	pass


func _default_max_selected() -> int:
	return 3


func _default_payment_mode() -> String:
	return "cash"


func _card_button_text() -> String:
	return "加入"


func _slot_text(food: Dictionary) -> String:
	return String(food.get("name", "已选"))
