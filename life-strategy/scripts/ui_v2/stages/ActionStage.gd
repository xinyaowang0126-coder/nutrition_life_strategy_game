class_name ActionStageV2
extends Control

signal action_selected(action_id: String)
signal skip_requested
signal detail_requested(payload: Dictionary, anchor_rect: Rect2, pinned: bool)
signal detail_dismissed(item_id: String)

const CARD_SCENE := preload("res://scenes/game_v2/components/CompactChoiceCard.tscn")

@onready var time_label: Label = $Layout/Header/TimeTag/TimeLabel
@onready var prompt_label: Label = $Layout/Header/PromptTag/Prompt
@onready var slots_label: Label = $Layout/Header/SlotsTag/Slots
@onready var action_scroll: ScrollContainer = $Layout/ActionRail
@onready var actions_container: HBoxContainer = $Layout/ActionRail/Actions
@onready var water_count_label: Label = $Layout/PlannerNote/PlannerMargin/Planner/PlannerHeader/WaterCount
@onready var used_slots: HBoxContainer = $Layout/PlannerNote/PlannerMargin/Planner/UsedSlots
@onready var skip_button: Button = $Layout/SkipButton

var _items: Array[Dictionary] = []
var _cards_by_id: Dictionary = {}
var _options: Dictionary = {}
var _ready_finished := false
var _has_setup := false
var _scrolling := false
var _last_scroll_motion_msec := -1000


func setup(items: Array, options: Dictionary = {}) -> void:
	_items.clear()
	for value in items:
		if value is Dictionary:
			var payload: Dictionary = (value as Dictionary).duplicate(true)
			if not String(payload.get("id", "")).is_empty():
				_items.append(payload)
	_options = options.duplicate(true)
	_has_setup = true
	if _ready_finished:
		_apply_setup()


func set_usage(used: int, maximum: int, used_names: Array = [], water_count: int = 0, water_max: int = 2) -> void:
	_options["slots_used"] = used
	_options["max_slots"] = maximum
	_options["used_action_names"] = used_names.duplicate()
	_options["water_count"] = water_count
	_options["water_max"] = water_max
	if _ready_finished:
		_update_header()


func _ready() -> void:
	skip_button.pressed.connect(func() -> void: skip_requested.emit())
	_bind_scroll_guard()
	_ready_finished = true
	if _has_setup:
		_apply_setup()


func _apply_setup() -> void:
	for child in actions_container.get_children():
		actions_container.remove_child(child)
		child.queue_free()
	_cards_by_id.clear()
	for payload in _items:
		var action_id := String(payload.get("id", ""))
		var enabled := bool(payload.get("enabled", true))
		var reason := String(payload.get("disabled_reason", ""))
		var card := CARD_SCENE.instantiate() as CompactChoiceCardV2
		if card == null:
			continue
		actions_container.add_child(card)
		_cards_by_id[action_id] = card
		card.configure(payload, "action", false, enabled, -1, reason, "安排")
		card.selected.connect(_on_action_pressed)
		card.detail_requested.connect(_forward_detail)
		card.detail_dismissed.connect(_forward_detail_dismissed)
	_update_header()


func _update_header() -> void:
	var used := maxi(0, int(_options.get("slots_used", 0)))
	var maximum := maxi(1, int(_options.get("max_slots", 3)))
	time_label.text = String(_options.get("time_label", "餐后"))
	prompt_label.text = String(_options.get("prompt", "接下来做点什么？"))
	slots_label.text = "安排 %d/%d" % [used, maximum]
	water_count_label.text = "水杯 %d/%d" % [int(_options.get("water_count", 0)), int(_options.get("water_max", 2))]
	var names: Array = _options.get("used_action_names", []) as Array
	var slot_nodes := used_slots.get_children()
	for index in range(slot_nodes.size()):
		var label := (slot_nodes[index] as Node).get_node_or_null("Text") as Label
		if label != null:
			label.text = String(names[index]) if index < names.size() else "空位"
			label.modulate = Color.WHITE if index < names.size() else Color(1.0, 1.0, 1.0, 0.62)


func _on_action_pressed(action_id: String) -> void:
	if _is_scroll_gesture() or not _cards_by_id.has(action_id):
		return
	var card := _cards_by_id[action_id] as CompactChoiceCardV2
	if not is_instance_valid(card):
		return
	card.set_selected(true, true)
	action_selected.emit(action_id)


func _bind_scroll_guard() -> void:
	if action_scroll.has_signal("scroll_started"):
		action_scroll.connect("scroll_started", func() -> void:
			_scrolling = true
			_last_scroll_motion_msec = Time.get_ticks_msec()
		)
	if action_scroll.has_signal("scroll_ended"):
		action_scroll.connect("scroll_ended", func() -> void:
			_scrolling = false
			_last_scroll_motion_msec = Time.get_ticks_msec()
		)
	action_scroll.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void:
		_last_scroll_motion_msec = Time.get_ticks_msec()
	)


func _is_scroll_gesture() -> bool:
	return _scrolling or Time.get_ticks_msec() - _last_scroll_motion_msec < 140


func _forward_detail(payload: Dictionary, anchor_rect: Rect2, pinned: bool) -> void:
	detail_requested.emit(payload, anchor_rect, pinned)


func _forward_detail_dismissed(item_id: String) -> void:
	detail_dismissed.emit(item_id)
