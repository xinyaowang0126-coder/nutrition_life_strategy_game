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
	var ids: Array = _options.get("used_action_ids", []) as Array
	var slot_nodes := used_slots.get_children()
	for index in range(slot_nodes.size()):
		var slot := slot_nodes[index] as PanelContainer
		var label := slot.get_node_or_null("Text") as Label
		var preview := slot.get_node_or_null("Preview") as TextureRect
		if index < ids.size():
			var action := _action_payload(String(ids[index]))
			var texture := _action_preview_texture(action)
			if preview != null:
				preview.texture = texture
				preview.visible = texture != null
			if label != null:
				label.visible = texture == null
				label.text = String(names[index]) if index < names.size() else "?"
		else:
			if preview != null:
				preview.texture = null
				preview.visible = false
			if label != null:
				label.visible = true
				label.text = "+"
				label.modulate = Color(1.0, 1.0, 1.0, 0.62)


func _action_payload(action_id: String) -> Dictionary:
	for payload in _items:
		if String(payload.get("id", "")) == action_id:
			return payload
	return {}


func _action_preview_texture(action: Dictionary) -> Texture2D:
	var image_path := String(action.get("image", ""))
	if image_path.is_empty() or not ResourceLoader.exists(image_path):
		return null
	var source := load(image_path) as Texture2D
	if source == null or image_path.contains("/ui_v2/card_art/"):
		return source
	if not image_path.contains("/generated/actions/"):
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(98, 103, 316, 294)
	atlas.filter_clip = true
	return atlas


func _on_action_pressed(action_id: String) -> void:
	if not _cards_by_id.has(action_id):
		return
	var card := _cards_by_id[action_id] as CompactChoiceCardV2
	if not is_instance_valid(card):
		return
	card.set_selected(true, true)
	action_selected.emit(action_id)


func _forward_detail(payload: Dictionary, anchor_rect: Rect2, pinned: bool) -> void:
	detail_requested.emit(payload, anchor_rect, pinned)


func _forward_detail_dismissed(item_id: String) -> void:
	detail_dismissed.emit(item_id)
