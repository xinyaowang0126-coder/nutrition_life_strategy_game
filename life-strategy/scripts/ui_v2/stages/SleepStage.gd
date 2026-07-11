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

var _items: Array[Dictionary] = []
var _options: Dictionary = {}
var _cards_by_id: Dictionary = {}
var _ready_finished := false
var _has_setup := false
var _scrolling := false


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
	_bind_scroll_guard()
	_ready_finished = true
	if _has_setup:
		_apply_setup()


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
	if _is_scroll_gesture() or not _cards_by_id.has(sleep_id):
		return
	var card := _cards_by_id[sleep_id] as CompactChoiceCardV2
	if not is_instance_valid(card):
		return
	card.set_selected(true, true)
	sleep_selected.emit(sleep_id)


func _bind_scroll_guard() -> void:
	if sleep_scroll.has_signal("scroll_started"):
		sleep_scroll.connect("scroll_started", func() -> void:
			_scrolling = true
		)
	if sleep_scroll.has_signal("scroll_ended"):
		sleep_scroll.connect("scroll_ended", func() -> void:
			_scrolling = false
		)


func _is_scroll_gesture() -> bool:
	# CompactChoiceCard performs its own touch-slop check.  A recent scrollbar
	# value change is not proof of a drag (hover scaling can cause one).
	return _scrolling


func _forward_detail(payload: Dictionary, anchor_rect: Rect2, pinned: bool) -> void:
	detail_requested.emit(payload, anchor_rect, pinned)


func _forward_detail_dismissed(item_id: String) -> void:
	detail_dismissed.emit(item_id)
