class_name MealStageBaseV2
extends Control

signal food_toggled(food_id: String)
signal confirm_requested(food_ids: Array)
signal back_requested
signal skip_requested
signal detail_requested(payload: Dictionary, anchor_rect: Rect2, pinned: bool)
signal detail_dismissed(item_id: String)

const CARD_SCENE := preload("res://scenes/game_v2/components/CompactChoiceCard.tscn")

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
var _scrolling := false
var _last_scroll_motion_msec := -1000


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


func set_stock(stock_by_id: Dictionary) -> void:
	_stock_by_id = stock_by_id.duplicate(true)
	if _ready_finished:
		for food_id in _cards_by_id:
			var card: Variant = _cards_by_id[food_id]
			if is_instance_valid(card):
				card.set_stock(_card_stock(String(food_id)))
		_refresh_card_availability()
		_update_scene_summary()


func _bind_meal_controls(
	back_button: Button,
	skip_button: Button,
	confirm_button: Button,
	scroll: ScrollContainer
) -> void:
	back_button.pressed.connect(_emit_back)
	skip_button.pressed.connect(_emit_skip)
	confirm_button.pressed.connect(_emit_confirm)
	_bind_scroll_guard(scroll)


func _finish_ready() -> void:
	_ready_finished = true
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
	var confirm := _get_confirm_button()
	if confirm != null:
		confirm.disabled = _selected_ids.is_empty()


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
		var slot := slots[index] as PanelContainer
		if slot == null:
			continue
		var label := slot.get_node_or_null("Empty") as Label
		if label == null:
			continue
		if index < _selected_ids.size():
			var food_id := _selected_ids[index]
			var food: Dictionary = _foods_by_id.get(food_id, {})
			label.text = _slot_text(food)
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(0.24, 0.20, 0.15, 1.0))
			slot.self_modulate = Color(1.0, 0.91, 0.73, 1.0)
			if animate:
				_pulse_slot(slot)
		else:
			label.text = "+"
			label.add_theme_font_size_override("font_size", 36)
			label.add_theme_color_override("font_color", Color(0.55, 0.48, 0.40, 0.42))
			slot.self_modulate = Color.WHITE


func _on_card_selected(food_id: String) -> void:
	if _is_scroll_gesture() or not _foods_by_id.has(food_id):
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
	if _balance >= 0 and _selection_total() + int(food.get("cost", 0)) > _balance:
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
	if _stock_by_id.has(food_id):
		return int(_stock_by_id[food_id])
	var food: Dictionary = _foods_by_id.get(food_id, {})
	return int(food.get("stock", -1))


func _selected_names() -> Array[String]:
	var result: Array[String] = []
	for food_id in _selected_ids:
		var food: Dictionary = _foods_by_id.get(food_id, {})
		result.append(String(food.get("name", food_id)))
	return result


func _bind_scroll_guard(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	if scroll.has_signal("scroll_started"):
		scroll.connect("scroll_started", Callable(self, "_on_scroll_started"))
	if scroll.has_signal("scroll_ended"):
		scroll.connect("scroll_ended", Callable(self, "_on_scroll_ended"))
	var horizontal_bar := scroll.get_h_scroll_bar()
	var vertical_bar := scroll.get_v_scroll_bar()
	if horizontal_bar != null:
		horizontal_bar.value_changed.connect(_on_scroll_value_changed)
	if vertical_bar != null:
		vertical_bar.value_changed.connect(_on_scroll_value_changed)


func _on_scroll_started() -> void:
	_scrolling = true
	_last_scroll_motion_msec = Time.get_ticks_msec()


func _on_scroll_ended() -> void:
	_scrolling = false
	_last_scroll_motion_msec = Time.get_ticks_msec()


func _on_scroll_value_changed(_value: float) -> void:
	_last_scroll_motion_msec = Time.get_ticks_msec()


func _is_scroll_gesture() -> bool:
	return _scrolling or Time.get_ticks_msec() - _last_scroll_motion_msec < 140


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
