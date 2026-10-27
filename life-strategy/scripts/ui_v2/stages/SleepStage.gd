class_name SleepStageV2
extends Control

signal sleep_selected(sleep_id: String)
signal detail_requested(payload: Dictionary, anchor_rect: Rect2, pinned: bool)
signal detail_dismissed(item_id: String)

const CARD_SCENE := preload("res://scenes/game_v2/components/CompactChoiceCard.tscn")

@onready var prompt_label: Label = $Layout/PromptTag/PromptBox/Prompt
@onready var sub_prompt_label: Label = $Layout/PromptTag/PromptBox/SubPrompt
@onready var sleep_scroll: ScrollContainer = $Layout/SleepRail
@onready var choices_container: HBoxContainer = $Layout/SleepRail/Choices
@onready var tomorrow_label: Label = $Layout/AlarmNote/AlarmMargin/Alarm/AlarmText/Tomorrow
@onready var hint_label: Label = $Layout/AlarmNote/AlarmMargin/Alarm/AlarmText/Hint
@onready var clock_label: Label = $Layout/AlarmNote/AlarmMargin/Alarm/Clock

var _items: Array[Dictionary] = []
var _options: Dictionary = {}
var _cards_by_id: Dictionary = {}
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


func _ready() -> void:
	sleep_scroll.follow_focus = true
	# The previous clock character depended on an installed fallback font.
	# Canvas lines keep the same symbol readable in the exported Web build.
	clock_label.text = ""
	clock_label.custom_minimum_size = Vector2(44, 44)
	clock_label.draw.connect(_draw_clock)
	clock_label.resized.connect(clock_label.queue_redraw)
	_ready_finished = true
	if _has_setup:
		_apply_setup()


func _draw_clock() -> void:
	var center := clock_label.size * 0.5
	var radius := minf(clock_label.size.x, clock_label.size.y) * 0.4
	var ink := clock_label.get_theme_color("font_color")
	clock_label.draw_arc(center, radius, 0, TAU, 48, ink, 2.4, true)
	clock_label.draw_line(center, center + Vector2(0, -radius * 0.65), ink, 2.4, true)
	clock_label.draw_line(center, center + Vector2(radius * 0.55, radius * 0.25), ink, 2.4, true)


func _apply_setup() -> void:
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
	_cards_by_id.clear()
	for payload in _items:
		var sleep_id := String(payload.get("id", ""))
		var enabled := bool(payload.get("enabled", true))
		var reason := String(payload.get("disabled_reason", ""))
		var card := CARD_SCENE.instantiate() as CompactChoiceCardV2
		if card == null:
			continue
		choices_container.add_child(card)
		_cards_by_id[sleep_id] = card
		card.configure(payload, "sleep", false, enabled, -1, reason, "就这样")
		card.selected.connect(_on_sleep_pressed)
		card.detail_requested.connect(_forward_detail)
		card.detail_dismissed.connect(_forward_detail_dismissed)
	prompt_label.text = String(_options.get("prompt", "夜深了，几点睡？"))
	sub_prompt_label.text = String(_options.get("sub_prompt", "明天的状态，从今晚开始。"))
	tomorrow_label.text = String(_options.get("tomorrow_text", "明早还有安排"))
	hint_label.text = String(_options.get("hint", "点小圆标看清代价，再做决定。"))


func _on_sleep_pressed(sleep_id: String) -> void:
	if not _cards_by_id.has(sleep_id):
		return
	var card := _cards_by_id[sleep_id] as CompactChoiceCardV2
	if not is_instance_valid(card):
		return
	card.set_selected(true, true)
	sleep_selected.emit(sleep_id)


func _forward_detail(payload: Dictionary, anchor_rect: Rect2, pinned: bool) -> void:
	detail_requested.emit(payload, anchor_rect, pinned)


func _forward_detail_dismissed(item_id: String) -> void:
	detail_dismissed.emit(item_id)
