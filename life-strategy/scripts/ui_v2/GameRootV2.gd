class_name GameRootV2
extends Control

const GameDataScript := preload("res://scripts/GameData.gd")
const MealDeckServiceScript := preload("res://scripts/systems/MealDeckService.gd")
const MealResolverScript := preload("res://scripts/systems/MealResolver.gd")
const NutritionLedgerScript := preload("res://scripts/systems/NutritionLedger.gd")
const WeeklyEventServiceScript := preload("res://scripts/systems/WeeklyEventService.gd")
const DayCarryoverServiceScript := preload("res://scripts/systems/DayCarryoverService.gd")

const SOURCE_STAGE_SCENE := preload("res://scenes/game_v2/stages/MealSourceStage.tscn")
const CAFETERIA_STAGE_SCENE := preload("res://scenes/game_v2/stages/CafeteriaMealStage.tscn")
const TAKEOUT_STAGE_SCENE := preload("res://scenes/game_v2/stages/TakeoutMealStage.tscn")
const CONVENIENCE_STAGE_SCENE := preload("res://scenes/game_v2/stages/ConvenienceMealStage.tscn")
const DORM_STAGE_SCENE := preload("res://scenes/game_v2/stages/DormPantryStage.tscn")
const ACTION_STAGE_SCENE := preload("res://scenes/game_v2/stages/ActionStage.tscn")
const SLEEP_STAGE_SCENE := preload("res://scenes/game_v2/stages/SleepStage.tscn")

const MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const DEFAULT_BACKGROUND := "res://assets/generated/backgrounds/dorm_background.png"
const ACTION_BACKGROUNDS := {
	"breakfast_action": "res://assets/generated/ui_v2/backgrounds/action_morning_16x9.png",
	"lunch_action": "res://assets/generated/ui_v2/backgrounds/action_noon_16x9.png",
	"dinner_action": "res://assets/generated/ui_v2/backgrounds/action_evening_16x9.png",
	"sleep": "res://assets/generated/ui_v2/backgrounds/action_evening_16x9.png",
	"summary": "res://assets/generated/ui_v2/backgrounds/action_evening_16x9.png",
}
const ACTION_BACKGROUNDS_MOBILE := {
	"breakfast_source": "res://assets/generated/ui_v2/backgrounds/action_morning_9x16.png",
	"breakfast": "res://assets/generated/ui_v2/backgrounds/action_morning_9x16.png",
	"breakfast_action": "res://assets/generated/ui_v2/backgrounds/action_morning_9x16.png",
	"lunch_source": "res://assets/generated/ui_v2/backgrounds/action_noon_9x16.png",
	"lunch": "res://assets/generated/ui_v2/backgrounds/action_noon_9x16.png",
	"lunch_action": "res://assets/generated/ui_v2/backgrounds/action_noon_9x16.png",
	"dinner_source": "res://assets/generated/ui_v2/backgrounds/action_evening_9x16.png",
	"dinner": "res://assets/generated/ui_v2/backgrounds/action_evening_9x16.png",
	"dinner_action": "res://assets/generated/ui_v2/backgrounds/action_evening_9x16.png",
	"sleep": "res://assets/generated/ui_v2/backgrounds/action_evening_9x16.png",
	"summary": "res://assets/generated/ui_v2/backgrounds/action_evening_9x16.png",
}
const LEARNING_STATE_IMAGES := {
	"clear_focus": "res://assets/generated/ui_v2/day_popup/states/clear_focus.png",
	"steady": "res://assets/generated/endings/stable_endurance.png",
	"fatigued": "res://assets/generated/endings/barely_survived.png",
	"brain_fog": "res://assets/generated/ui_v2/card_art/sleep/night_study_art.png",
}
const EVENT_IMAGES := {
	"quiet_day": "res://assets/generated/ui_v2/backgrounds/action_morning_16x9.png",
	"clear_skies": "res://assets/generated/actions/walk.png",
	"cafeteria_rotation": "res://assets/generated/backgrounds/cafeteria_background.png",
	"delivery_coupon": "res://assets/generated/backgrounds/takeout_background.png",
	"mock_exam_notice": "res://assets/generated/ui_v2/day_popup/events/mock_exam_notice.png",
	"rainy_day": "res://assets/generated/ui_v2/day_popup/events/rainy_day.png",
}
const EVENT_EFFECT_TEXT := {
	"clear_skies": "心情 +3｜压力 -2｜散步恢复增强",
	"cafeteria_rotation": "食堂候选菜品 +2",
	"delivery_coupon": "外卖配送费 -2｜候选餐品 +1",
	"mock_exam_notice": "复习收益 +3｜额外精力 -2、压力 +1",
	"rainy_day": "心情 -2｜压力 +2｜外卖费 +2，散步恢复减弱",
	"quiet_day": "没有额外规则变化",
}

const MAX_FOODS_PER_MEAL := 3
const MAX_DAILY_ACTIONS := 3
const MEAL_PHASES := ["breakfast", "lunch", "dinner"]
const PHASE_NAMES := {
	"breakfast_source": "早餐",
	"breakfast": "早餐",
	"breakfast_action": "早餐后",
	"lunch_source": "午餐",
	"lunch": "午餐",
	"lunch_action": "午餐后",
	"dinner_source": "晚餐",
	"dinner": "晚餐",
	"dinner_action": "晚餐后",
	"sleep": "夜里",
	"summary": "今日小结",
	"ending": "周末",
}

@onready var background_a: TextureRect = $BackgroundStack/BackgroundA
@onready var background_b: TextureRect = $BackgroundStack/BackgroundB
@onready var time_grade: ColorRect = $BackgroundStack/TimeGrade
@onready var stage_safe_area: MarginContainer = $WorldStage/StageSafeArea
@onready var stage_host: Control = $WorldStage/StageSafeArea/StageHost
@onready var top_safe_area: MarginContainer = $HUD/HUDRoot/TopSafeArea
@onready var day_label: Label = $HUD/HUDRoot/TopSafeArea/TopHUD/DayTag/DayLabel
@onready var day_tag: PanelContainer = $HUD/HUDRoot/TopSafeArea/TopHUD/DayTag
@onready var phase_label: Label = $HUD/HUDRoot/TopSafeArea/TopHUD/PhaseTag/PhaseLabel
@onready var phase_tag: PanelContainer = $HUD/HUDRoot/TopSafeArea/TopHUD/PhaseTag
@onready var balance_label: Label = $HUD/HUDRoot/TopSafeArea/TopHUD/BalanceChip/BalanceLabel
@onready var balance_chip: PanelContainer = $HUD/HUDRoot/TopSafeArea/TopHUD/BalanceChip
@onready var menu_button: Button = $HUD/HUDRoot/TopSafeArea/TopHUD/MenuButton
@onready var character_anchor: Control = $HUD/HUDRoot/CharacterAnchor
@onready var character_hud: CharacterHUDV2 = $HUD/HUDRoot/CharacterAnchor/CharacterSlot/CharacterHUD
@onready var toast_anchor: Control = $HUD/HUDRoot/ToastAnchor
@onready var toast_feed: ToastFeedV2 = $HUD/HUDRoot/ToastAnchor/ToastFeed
@onready var sticky_note: StickyNotePopupV2 = $HUD/HUDRoot/DetailLayer/StickyNote
@onready var daily_summary: DailySummaryPopupV2 = $HUD/HUDRoot/ModalLayer/DailySummary
@onready var new_day_popup: NewDayPopupV2 = $HUD/HUDRoot/ModalLayer/NewDayPopup

var state: Dictionary = {}
var day := 1
var phase := "breakfast_source"
var hand: Array[String] = []
var selected_food_ids: Array[String] = []
var current_source_id := ""
var source_hands: Dictionary = {}
var dorm_inventory: Dictionary = {}
var today_meal_records: Array[Dictionary] = []
var actions_used_today := 0
var drink_water_used := 0
var used_action_names: Array[String] = []
var used_action_ids: Array[String] = []
var today_action_records: Array[Dictionary] = []
var combos_today: Array[String] = []
var summary_payload: Dictionary = {}
var ending_id := ""
var low_stability_days := 0
var run_history: Array[Dictionary] = []
var current_event: Dictionary = {}
var current_learning_state: Dictionary = {}
var pending_learning_state: Dictionary = {}
var _day_start_state: Dictionary = {}
var chosen_sleep_id := ""
var chosen_sleep_name := ""

var _deck_service: RefCounted
var _active_stage: Control
var _mobile_mode := false
var _profile_initialized := false
var _applying_profile := false
var _background_path := ""
var _background_a_is_front := true


func _ready() -> void:
	GameDataScript.ensure_loaded()
	_deck_service = MealDeckServiceScript.new()
	menu_button.pressed.connect(_request_main_menu)
	character_hud.details_requested.connect(_show_detail.bind("state"))
	character_hud.detail_dismissed.connect(_dismiss_detail)
	sticky_note.closed.connect(func() -> void: pass)
	daily_summary.next_day_requested.connect(_on_summary_advanced)
	new_day_popup.continue_requested.connect(_on_new_day_continue)
	get_viewport().size_changed.connect(_apply_responsive_profile)
	_apply_responsive_profile()
	start_new_run()


func start_new_run() -> void:
	state = GameDataScript.get_starting_stats()
	day = 1
	low_stability_days = 0
	dorm_inventory = GameDataScript.get_initial_dorm_inventory()
	ending_id = ""
	run_history.clear()
	current_event.clear()
	current_learning_state = DayCarryoverServiceScript.STEADY.duplicate(true)
	pending_learning_state = current_learning_state.duplicate(true)
	daily_summary.hide_summary(false)
	new_day_popup.hide_popup(false)
	sticky_note.hide_note(false)
	_start_day()
	_render_phase()
	_show_new_day_popup()


func _start_day() -> void:
	_day_start_state = state.duplicate(true)
	current_learning_state = pending_learning_state.duplicate(true)
	_apply_stat_delta(current_learning_state.get("opening_delta", {}))
	current_event = WeeklyEventServiceScript.event_for_day(day)
	state = WeeklyEventServiceScript.apply_opening_state(day, state)
	_clamp_stats()
	phase = "breakfast_source"
	hand.clear()
	selected_food_ids.clear()
	current_source_id = ""
	source_hands.clear()
	today_meal_records.clear()
	actions_used_today = 0
	drink_water_used = 0
	used_action_names.clear()
	used_action_ids.clear()
	today_action_records.clear()
	combos_today.clear()
	summary_payload.clear()
	chosen_sleep_id = ""
	chosen_sleep_name = ""


func _render_phase() -> void:
	if not is_node_ready() or state.is_empty():
		return
	sticky_note.hide_note(false)
	_update_shell()
	_update_background()
	character_hud.update_stats(state, true)
	if phase == "summary":
		_clear_stage()
		daily_summary.show_summary(summary_payload, _mobile_mode)
		return
	if phase == "ending":
		_clear_stage()
		_show_ending_summary()
		return
	daily_summary.hide_summary(false)
	if _is_source_phase():
		_show_source_stage()
	elif _is_meal_phase():
		_show_meal_stage()
	elif _is_action_phase():
		_show_action_stage()
	elif phase == "sleep":
		_show_sleep_stage()


func _show_source_stage() -> void:
	var stage := SOURCE_STAGE_SCENE.instantiate() as MealSourceStageV2
	_install_stage(stage)
	var sources: Array[Dictionary] = []
	var disabled_reasons := {}
	var meal := _current_meal_phase()
	for source_id in GameDataScript.get_meal_source_ids():
		var source := _effective_meal_source(source_id)
		var reason := _source_disabled_reason(source_id, meal)
		source["enabled"] = reason.is_empty()
		source["disabled_reason"] = reason
		sources.append(source)
		disabled_reasons[source_id] = reason
	stage.source_selected.connect(_choose_meal_source)
	stage.skip_requested.connect(_skip_meal)
	stage.detail_requested.connect(_show_detail.bind("source"))
	stage.detail_dismissed.connect(_dismiss_detail)
	stage.setup(sources, String(PHASE_NAMES[meal]), disabled_reasons)


func _show_meal_stage() -> void:
	var scene: PackedScene
	match current_source_id:
		"takeout":
			scene = TAKEOUT_STAGE_SCENE
		"convenience_store":
			scene = CONVENIENCE_STAGE_SCENE
		"dorm_storage":
			scene = DORM_STAGE_SCENE
		_:
			scene = CAFETERIA_STAGE_SCENE
	var stage := scene.instantiate() as MealStageBaseV2
	_install_stage(stage)
	var foods: Array[Dictionary] = []
	for food_id in hand:
		foods.append(GameDataScript.get_food(food_id))
	var source := _effective_meal_source(current_source_id)
	var options := {
		"max_selected": _source_selection_limit(current_source_id),
		"source_fee": int(source.get("fee", 0)),
		"balance": int(state.get("balance", 0)),
		"payment_mode": String(source.get("payment_mode", "cash")),
		"meal_label": String(PHASE_NAMES[phase]),
		"stock_by_id": dorm_inventory,
	}
	stage.food_toggled.connect(_on_food_toggled)
	stage.confirm_requested.connect(_confirm_food)
	stage.back_requested.connect(_change_meal_source)
	stage.skip_requested.connect(_skip_meal)
	stage.detail_requested.connect(_show_detail.bind("food"))
	stage.detail_dismissed.connect(_dismiss_detail)
	stage.setup(foods, selected_food_ids, options)


func _show_action_stage() -> void:
	var stage := ACTION_STAGE_SCENE.instantiate() as ActionStageV2
	_install_stage(stage)
	var actions: Array[Dictionary] = []
	for action_id in GameDataScript.get_action_ids_for_scene(phase):
		var action := _effective_action(action_id)
		var display_key := "name_%s" % phase
		if action.has(display_key):
			action["name"] = String(action[display_key])
		var reason := _action_disabled_reason(action)
		action["enabled"] = reason.is_empty()
		action["disabled_reason"] = reason
		actions.append(action)
	stage.action_selected.connect(_apply_action)
	stage.skip_requested.connect(_skip_action)
	stage.detail_requested.connect(_show_detail.bind("action"))
	stage.detail_dismissed.connect(_dismiss_detail)
	stage.setup(actions, {
		"time_label": String(PHASE_NAMES[phase]),
		"prompt": _phase_prompt(),
		"slots_used": actions_used_today,
		"max_slots": MAX_DAILY_ACTIONS,
		"water_count": drink_water_used,
		"water_max": 2,
		"used_action_names": used_action_names,
		"used_action_ids": used_action_ids,
	})


func _show_sleep_stage() -> void:
	var stage := SLEEP_STAGE_SCENE.instantiate() as SleepStageV2
	_install_stage(stage)
	var options_list: Array[Dictionary] = []
	for option_id in GameDataScript.get_sleep_option_ids_for_scene("sleep"):
		options_list.append(GameDataScript.get_sleep_option(option_id))
	var tomorrow_preview := WeeklyEventServiceScript.next_day_preview(day, GameDataScript.TOTAL_DAYS)
	var tomorrow_text := "周末就要到了"
	if not tomorrow_preview.is_empty():
		tomorrow_text = "%s · %s" % [
			String(tomorrow_preview.get("title", "明日安排")),
			String(tomorrow_preview.get("summary", "")),
		]
	stage.sleep_selected.connect(_choose_sleep)
	stage.detail_requested.connect(_show_detail.bind("sleep"))
	stage.detail_dismissed.connect(_dismiss_detail)
	stage.setup(options_list, {
		"prompt": "夜深了，几点睡？",
		"sub_prompt": "闹钟还没响，先把今晚定下来。",
		"tomorrow_text": tomorrow_text,
		"hint": "点小圆标看清代价，再决定。",
	})


func _install_stage(stage: Control) -> void:
	_clear_stage()
	_active_stage = stage
	stage_host.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_stage_profile(stage)
	stage.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(stage, "modulate:a", 1.0, 0.18)


func _clear_stage() -> void:
	if is_instance_valid(_active_stage):
		_active_stage.queue_free()
	_active_stage = null
	for child in stage_host.get_children():
		if child != _active_stage and not child.is_queued_for_deletion():
			child.queue_free()


func _choose_meal_source(source_id: String) -> void:
	var meal := _current_meal_phase()
	var reason := _source_disabled_reason(source_id, meal)
	if not reason.is_empty():
		_post(reason, "warning")
		return
	current_source_id = source_id
	hand = _hand_for_source(source_id, meal)
	selected_food_ids.clear()
	phase = meal
	_render_phase()


func _change_meal_source() -> void:
	# The outgoing stage is freed at the end of the frame.  Ignore a second
	# click/tap from that stale stage instead of producing e.g.
	# `breakfast_source_source`.
	if not _is_meal_phase():
		return
	phase = "%s_source" % phase
	current_source_id = ""
	hand.clear()
	selected_food_ids.clear()
	_render_phase()


func _hand_for_source(source_id: String, meal: String) -> Array[String]:
	var cache_key := "%s:%s" % [meal, source_id]
	if source_hands.has(cache_key):
		var cached: Array = source_hands[cache_key]
		var valid_cached: Array[String] = []
		for value in cached:
			var food_id := String(value)
			if source_id != "dorm_storage" or int(dorm_inventory.get(food_id, 0)) > 0:
				valid_cached.append(food_id)
		return valid_cached
	var source := _effective_meal_source(source_id)
	var candidates := GameDataScript.get_food_ids_for_context(source_id, meal)
	var uses_stock := String(source.get("payment_mode", "cash")) == "stock"
	var built: Array[String] = _deck_service.build_hand(
		candidates,
		int(source.get("hand_size", 4)),
		dorm_inventory,
		uses_stock
	)
	if not uses_stock:
		_ensure_affordable_in_source_hand(built, candidates, int(source.get("fee", 0)))
	source_hands[cache_key] = built.duplicate()
	return built


func _ensure_affordable_in_source_hand(built: Array[String], candidates: Array[String], fee: int) -> void:
	for food_id in built:
		if int(GameDataScript.get_food(food_id)["cost"]) + fee <= int(state["balance"]):
			return
	var cheapest_id := ""
	var cheapest_cost := 100000
	for food_id in candidates:
		var cost := int(GameDataScript.get_food(food_id)["cost"])
		if cost < cheapest_cost and cost + fee <= int(state["balance"]):
			cheapest_cost = cost
			cheapest_id = food_id
	if not cheapest_id.is_empty():
		if built.is_empty():
			built.append(cheapest_id)
		else:
			built[built.size() - 1] = cheapest_id


func _source_disabled_reason(source_id: String, meal: String) -> String:
	if not GameDataScript.is_meal_source_available(source_id, meal):
		return "这个时段还没营业。"
	var source := _effective_meal_source(source_id)
	var candidates := GameDataScript.get_food_ids_for_context(source_id, meal)
	if String(source.get("payment_mode", "cash")) == "stock":
		for food_id in candidates:
			if int(dorm_inventory.get(food_id, 0)) > 0:
				return ""
		return "柜子已经空了。"
	var fee := int(source.get("fee", 0))
	for food_id in candidates:
		if int(GameDataScript.get_food(food_id)["cost"]) + fee <= int(state["balance"]):
			return ""
	return "余额不够在这里买一份。"


func _on_food_toggled(food_id: String) -> void:
	if selected_food_ids.has(food_id):
		selected_food_ids.erase(food_id)
	elif _can_add_food(food_id):
		selected_food_ids.append(food_id)
	if is_instance_valid(_active_stage) and _active_stage.has_method("set_selection"):
		_active_stage.call("set_selection", selected_food_ids, false)


func _can_add_food(food_id: String) -> bool:
	if not hand.has(food_id):
		return false
	if selected_food_ids.has(food_id):
		return true
	if selected_food_ids.size() >= _source_selection_limit(current_source_id):
		return false
	if _source_uses_stock():
		return int(dorm_inventory.get(food_id, 0)) > 0
	return _selected_meal_total(food_id) <= int(state["balance"])


func _selected_meal_total(extra_food_id: String = "") -> int:
	if current_source_id.is_empty() or _source_uses_stock():
		return 0
	var ids: Array[String] = selected_food_ids.duplicate()
	if not extra_food_id.is_empty() and not ids.has(extra_food_id):
		ids.append(extra_food_id)
	if ids.is_empty():
		return 0
	var source := _effective_meal_source(current_source_id)
	var total := int(source.get("fee", 0))
	for food_id in ids:
		total += int(GameDataScript.get_food(food_id).get("cost", 0))
	return total


func _confirm_food(food_ids: Array) -> void:
	if current_source_id.is_empty() or not _is_meal_phase():
		return
	var safe_ids: Array[String] = []
	for value in food_ids:
		var food_id := String(value)
		if hand.has(food_id) and not safe_ids.has(food_id):
			safe_ids.append(food_id)
		if safe_ids.size() >= _source_selection_limit(current_source_id):
			break
	if safe_ids.is_empty():
		return
	selected_food_ids = safe_ids
	var foods: Array[Dictionary] = []
	for food_id in safe_ids:
		foods.append(GameDataScript.get_food(food_id))
	var source := _effective_meal_source(current_source_id)
	var record := MealResolverScript.build_record(phase, source, foods)
	if int(record["total_cost"]) > int(state["balance"]):
		_post("余额不够，先拿掉一样。", "warning")
		return
	if bool(record["uses_stock"]):
		for food_id in record["food_ids"]:
			if int(dorm_inventory.get(String(food_id), 0)) <= 0:
				_post("这份存粮刚好吃完了。", "warning")
				return
	_apply_meal_record(record)
	var names: Array = record["food_names"]
	_post("%s：%s" % [String(PHASE_NAMES[phase]), "、".join(names)], "meal")
	selected_food_ids.clear()
	hand.clear()
	current_source_id = ""
	_advance_from_meal()


func _skip_meal() -> void:
	# Stage replacement uses queue_free(), so a rapid second tap can still emit
	# from the old source/meal stage during this frame.  Only the active meal
	# entry points are allowed to create a skipped record.
	if not _is_source_phase() and not _is_meal_phase():
		return
	var meal := _current_meal_phase()
	var record := MealResolverScript.build_skipped_record(meal)
	_apply_meal_record(record)
	_post("%s没顾上吃。" % String(PHASE_NAMES[meal]), "warning")
	selected_food_ids.clear()
	hand.clear()
	current_source_id = ""
	phase = meal
	_advance_from_meal()


func _apply_meal_record(record: Dictionary) -> void:
	state["balance"] = int(state["balance"]) - int(record["total_cost"])
	_apply_stat_delta(record["stat_delta"])
	if bool(record["uses_stock"]):
		for food_id in record["food_ids"]:
			var key := String(food_id)
			dorm_inventory[key] = maxi(0, int(dorm_inventory.get(key, 0)) - 1)
	today_meal_records.append(record.duplicate(true))
	_check_meal_combos(record)
	_clamp_stats()
	_update_stability()


func _check_meal_combos(record: Dictionary) -> void:
	if not combos_today.has("meal_group_mix") and MealResolverScript.has_meal_group_combination(record):
		combos_today.append("meal_group_mix")
		state["energy"] = int(state["energy"]) + 5
		state["mood"] = int(state["mood"]) + 3
		state["diet_burden"] = int(state["diet_burden"]) - 2
		_post("这餐同时包含谷薯类、蔬菜类和蛋白质食物来源。", "good")
	if not combos_today.has("comfort_chain") and MealResolverScript.comfort_meal_count(today_meal_records) >= 2:
		combos_today.append("comfort_chain")
		state["mood"] = int(state["mood"]) + 4
		state["diet_burden"] = int(state["diet_burden"]) + 3
		_post("喜欢的东西吃多了些，心情好了，身体也有点沉。", "info")
	if String(record["phase"]) == "dinner" and not combos_today.has("budget_saver"):
		var all_eaten := today_meal_records.size() >= 3
		for meal_record in today_meal_records:
			if bool(meal_record.get("skipped", false)):
				all_eaten = false
		if all_eaten and MealResolverScript.total_spend(today_meal_records) <= 12:
			combos_today.append("budget_saver")
			state["stress"] = int(state["stress"]) - 3
			_post("三餐一共没花多少，明天的预算宽一点。", "good")


func _advance_from_meal() -> void:
	match phase:
		"breakfast": phase = "breakfast_action"
		"lunch": phase = "lunch_action"
		_: phase = "dinner_action"
	_render_phase()


func _apply_action(action_id: String) -> void:
	if not _is_action_phase():
		return
	if not GameDataScript.get_action_ids_for_scene(phase).has(action_id):
		return
	var action := _effective_action(action_id)
	if not _can_use_action(action):
		var reason := _action_disabled_reason(action)
		if not reason.is_empty():
			_post(reason, "warning")
		return
	var display_key := "name_%s" % phase
	var display_name := String(action.get(display_key, action.get("name", action_id)))
	actions_used_today += int(action.get("slots", 1))
	if action_id == "drink_water":
		drink_water_used += 1
	used_action_names.append(display_name)
	used_action_ids.append(action_id)
	state["balance"] = int(state["balance"]) - int(action.get("cost", 0))
	var delta := {
		"energy": int(action.get("energy", 0)),
		"mood": int(action.get("mood", 0)),
		"stress": int(action.get("stress", 0)),
		"study_progress": int(action.get("study", 0)),
		"satiety": int(action.get("satiety", 0)),
		"diet_burden": int(action.get("burden", 0)),
	}
	_apply_stat_delta(delta)
	var stock_added := _apply_action_stock(action)
	today_action_records.append({
		"id": action_id,
		"name": display_name,
		"cost": int(action.get("cost", 0)),
		"stat_delta": delta.duplicate(true),
		"stock_added": stock_added,
	})
	_clamp_stats()
	_update_stability()
	if stock_added.is_empty():
		_post(display_name, "info")
	else:
		_post("%s：燕麦、牛奶和苹果放进柜子了。" % display_name, "good")
	_advance_after_action()


func _skip_action() -> void:
	if not _is_action_phase():
		return
	_post("%s没有再排事情。" % String(PHASE_NAMES.get(phase, "餐后")), "info")
	_advance_after_action()


func _advance_after_action() -> void:
	match phase:
		"breakfast_action": phase = "lunch_source"
		"lunch_action": phase = "dinner_source"
		_: phase = "sleep"
	_render_phase()


func _can_use_action(action: Dictionary) -> bool:
	if not _is_action_phase():
		return false
	if actions_used_today + int(action.get("slots", 1)) > MAX_DAILY_ACTIONS:
		return false
	if int(action.get("cost", 0)) > int(state["balance"]):
		return false
	if int(state.get("energy", 0)) < int(action.get("min_energy", 0)):
		return false
	if String(action.get("id", "")) == "drink_water" and drink_water_used >= 2:
		return false
	if _action_is_once_per_day(action) and used_action_ids.has(String(action.get("id", ""))):
		return false
	return true


func _action_disabled_reason(action: Dictionary) -> String:
	if String(action.get("id", "")) == "drink_water" and drink_water_used >= 2:
		return "今天已经接过两杯水。"
	if _action_is_once_per_day(action) and used_action_ids.has(String(action.get("id", ""))):
		return "今天已经补过一次存粮。"
	if actions_used_today + int(action.get("slots", 1)) > MAX_DAILY_ACTIONS:
		return "今天的安排位已经用完。"
	if int(action.get("cost", 0)) > int(state["balance"]):
		return "余额不够。"
	var min_energy := int(action.get("min_energy", 0))
	if int(state.get("energy", 0)) < min_energy:
		return "至少需要 %d 精力，现在先缓一缓。" % min_energy
	return ""


func _effective_action(action_id: String) -> Dictionary:
	var base_action := GameDataScript.get_action(action_id)
	var action := WeeklyEventServiceScript.apply_action(
		day,
		action_id,
		base_action
	)
	if action_id != "study":
		return action
	var carryover_modifier := int(current_learning_state.get("study_modifier", 0))
	var live_modifier := 0
	var live_reasons: Array[String] = []
	if int(state.get("energy", 0)) < 25:
		live_modifier -= 3
		live_reasons.append("精力偏低")
	if int(state.get("stress", 0)) >= 70:
		live_modifier -= 2
		live_reasons.append("压力偏高")
	var total_modifier := carryover_modifier + live_modifier
	if total_modifier != 0:
		action["study"] = maxi(1, int(action.get("study", 0)) + total_modifier)
	var notes: Array[String] = []
	var carryover_text := "不变" if carryover_modifier == 0 else _signed_delta(carryover_modifier)
	notes.append("今日学习状态：%s（每次复习 %s）" % [
		String(current_learning_state.get("title", "状态平稳")),
		carryover_text,
	])
	var event_modifier := int(action.get("study", 0)) - int(base_action.get("study", 0)) - total_modifier
	if event_modifier != 0:
		notes.append("今日事件：复习收益 %s" % _signed_delta(event_modifier))
	if live_modifier != 0:
		notes.append("当前%s：临时 %s" % [
			"且".join(live_reasons),
			_signed_delta(live_modifier),
		])
	var existing := String(action.get("rule_hint", ""))
	var state_notes := "\n".join(notes)
	action["rule_hint"] = "%s\n%s" % [existing, state_notes] if not existing.is_empty() else state_notes
	return action


func _action_is_once_per_day(action: Dictionary) -> bool:
	var raw: Variant = action.get("once_per_day", false)
	if raw is bool:
		return raw
	return String(raw).to_lower() == "true"


func _apply_action_stock(action: Dictionary) -> Dictionary:
	var added := {}
	for raw_item in action.get("stock_items", []):
		var parts := String(raw_item).split(":", false, 1)
		if parts.is_empty():
			continue
		var food_id := String(parts[0])
		var amount := int(parts[1]) if parts.size() > 1 else 1
		if amount <= 0 or GameDataScript.get_food(food_id).is_empty():
			continue
		dorm_inventory[food_id] = int(dorm_inventory.get(food_id, 0)) + amount
		added[food_id] = amount
	return added


func _choose_sleep(option_id: String) -> void:
	if phase != "sleep":
		return
	if not GameDataScript.get_sleep_option_ids_for_scene("sleep").has(option_id):
		return
	var option := GameDataScript.get_sleep_option(option_id)
	chosen_sleep_id = option_id
	chosen_sleep_name = String(option.get("name", option_id))
	_apply_stat_delta({
		"energy": int(option.get("energy", 0)),
		"mood": int(option.get("mood", 0)),
		"stress": int(option.get("stress", 0)),
		"study_progress": int(option.get("study", 0)),
		"satiety": int(option.get("satiety", 0)),
		"diet_burden": int(option.get("burden", 0)),
	})
	_post("夜里：%s" % chosen_sleep_name, "info")
	_finish_day()


func _finish_day() -> void:
	var nutrition_summary: Dictionary = NutritionLedgerScript.summarize(today_meal_records)
	var nutrition_score := int(nutrition_summary.get(
		"score",
		MealResolverScript.day_quality(today_meal_records)
	))
	if nutrition_score >= 66:
		state["energy"] = int(state["energy"]) + 4
		state["mood"] = int(state["mood"]) + 4
		state["diet_burden"] = int(state["diet_burden"]) - 2
	elif nutrition_score < 42:
		state["stress"] = int(state["stress"]) + 5
		state["diet_burden"] = int(state["diet_burden"]) + 4
	if int(state["satiety"]) < 20:
		state["stress"] = int(state["stress"]) + 8
		state["mood"] = int(state["mood"]) - 5
	if int(state["satiety"]) > 92:
		state["diet_burden"] = int(state["diet_burden"]) + 4
		state["energy"] = int(state["energy"]) - 3
	var remaining_days := maxi(0, GameDataScript.TOTAL_DAYS - day)
	if remaining_days > 0 and int(state["balance"]) < remaining_days * 8:
		state["stress"] = int(state["stress"]) + 5
		state["mood"] = int(state["mood"]) - 2
	var study_pace := mini(
		GameDataScript.STUDY_TARGET,
		day * GameDataScript.DAILY_STUDY_PACE
	)
	if int(state["study_progress"]) < study_pace:
		state["stress"] = int(state["stress"]) + 3
	else:
		state["mood"] = int(state["mood"]) + 2
	state["diet_burden"] = int(state["diet_burden"]) - 3
	state["satiety"] = int(state["satiety"]) - 6
	_clamp_stats()
	_update_stability()
	if int(state["stability"]) <= 15:
		low_stability_days += 1
	else:
		low_stability_days = 0
	pending_learning_state = DayCarryoverServiceScript.evaluate_day(
		nutrition_summary,
		today_action_records,
		chosen_sleep_id,
		state
	)
	var day_record := _build_day_record(nutrition_summary)
	run_history.append(day_record)
	var detail_text := "营养评分：%d/100 · %s\n%s\n%s" % [
		nutrition_score,
		String(nutrition_summary.get("rating", "")),
		String(nutrition_summary.get("detail_text", "")),
		_day_change_text(day_record),
	]
	nutrition_summary["detail_text"] = detail_text
	summary_payload = {
		"day": day,
		"title": "第 %d 天结束" % day,
		"stats": state.duplicate(true),
		"quality": "饮食 %d 分 · %s\n%s" % [
			nutrition_score,
			String(nutrition_summary.get("rating", "")),
			String(nutrition_summary["observation"]),
		],
		"advice": "%s\n%s\n%s" % [
			String(nutrition_summary["action"]),
			_day_strategy_advice(study_pace, remaining_days),
			_next_day_preview_text(),
		],
		"nutrition": nutrition_summary,
		"button_text": "睡到第 %d 天" % (day + 1),
	}
	if low_stability_days >= 2:
		_finish_run("collapsed")
	elif day >= GameDataScript.TOTAL_DAYS:
		_finish_run(MealResolverScript.select_ending(state))
	else:
		phase = "summary"
		_render_phase()


func _on_summary_advanced() -> void:
	if phase == "ending":
		start_new_run()
	elif phase == "summary":
		_next_day()


func _next_day() -> void:
	day += 1
	_start_day()
	_render_phase()
	_show_new_day_popup()


func _show_new_day_popup() -> void:
	if not is_node_ready():
		return
	var display_event := current_event.duplicate(true)
	if display_event.is_empty():
		display_event = _quiet_day_event()
	var event_id := String(display_event.get("id", "quiet_day"))
	var learning_id := String(current_learning_state.get("id", "steady"))
	new_day_popup.show_day({
		"day": day,
		"title": "第 %d 天开始" % day,
		"subtitle": (
			"新的一周从今天开始，先看看今天的状态与安排。"
			if day == 1
			else "昨天的饮食与休息留在今天，新的事件也会改变可用策略。"
		),
		"learning_state": current_learning_state.duplicate(true),
		"event": display_event,
		"status_image": String(LEARNING_STATE_IMAGES.get(
			learning_id,
			LEARNING_STATE_IMAGES["steady"]
		)),
		"event_image": String(EVENT_IMAGES.get(event_id, EVENT_IMAGES["quiet_day"])),
		"event_effect": String(EVENT_EFFECT_TEXT.get(
			event_id,
			EVENT_EFFECT_TEXT["quiet_day"]
		)),
		"button_text": "进入第 %d 天" % day,
	}, _mobile_mode)


func _quiet_day_event() -> Dictionary:
	if day == 1:
		return {
			"id": "quiet_day",
			"title": "新的一周开始了",
			"summary": "今天没有额外限制，先按自己的节奏安排三餐与学习。",
		}
	if day >= GameDataScript.TOTAL_DAYS:
		return {
			"id": "quiet_day",
			"title": "周末就在眼前",
			"summary": "今天没有额外变化，把这一周最后的安排稳稳接住。",
		}
	return {
		"id": "quiet_day",
		"title": "照常安排",
		"summary": "今天没有额外变化，可以按自己的节奏来。",
	}


func _on_new_day_continue() -> void:
	# The popup owns its closing animation; the playable stage is already
	# rendered underneath so continuing never incurs another scene rebuild.
	pass


func _finish_run(result: String) -> void:
	ending_id = result
	phase = "ending"
	_render_phase()


func _show_ending_summary() -> void:
	var ending := GameDataScript.get_ending(ending_id)
	var recap := _build_week_recap()
	var ending_summary := {
		"day": day,
		"title": String(ending.get("title", "这一周结束了")),
		"stats": state.duplicate(true),
		"quality": String(ending.get("subtitle", "这一周结束了。")),
		"advice": "目标复习 %d，完成 %d；平均饮食 %d 分，手里还剩 ¥%d。" % [
			GameDataScript.STUDY_TARGET,
			int(state["study_progress"]),
			int(recap.get("average_nutrition", 0)),
			int(state["balance"]),
		],
		"ending_image": String(ending.get("image", "")),
		"layout": "ending",
		"detail": recap,
		"detail_button_text": "查看本周轨迹",
		"detail_button_open_text": "收起本周轨迹",
		"button_text": "再来一周",
	}
	daily_summary.show_summary(ending_summary, _mobile_mode)


func _build_day_record(nutrition_summary: Dictionary) -> Dictionary:
	var action_spend := 0
	for record in today_action_records:
		action_spend += int(record.get("cost", 0))
	return {
		"day": day,
		"event": current_event.duplicate(true),
		"learning_state": current_learning_state.duplicate(true),
		"next_learning_state": pending_learning_state.duplicate(true),
		"start_state": _day_start_state.duplicate(true),
		"end_state": state.duplicate(true),
		"meals": today_meal_records.duplicate(true),
		"actions": today_action_records.duplicate(true),
		"sleep": {"id": chosen_sleep_id, "name": chosen_sleep_name},
		"spend": MealResolverScript.total_spend(today_meal_records) + action_spend,
		"combos": combos_today.duplicate(),
		"nutrition": nutrition_summary.duplicate(true),
	}


func _day_change_text(record: Dictionary) -> String:
	var start: Dictionary = record.get("start_state", {})
	var finish: Dictionary = record.get("end_state", {})
	return "今日变化：余力 %s｜复习 %s｜余额 %s" % [
		_signed_delta(int(finish.get("stability", 0)) - int(start.get("stability", 0))),
		_signed_delta(int(finish.get("study_progress", 0)) - int(start.get("study_progress", 0))),
		_signed_delta(int(finish.get("balance", 0)) - int(start.get("balance", 0))),
	]


func _day_strategy_advice(study_pace: int, remaining_days: int) -> String:
	var study_gap := study_pace - int(state.get("study_progress", 0))
	if study_gap > 0:
		return "复习比今日节奏少 %d；先恢复状态，比带着脑雾硬撑更有效。" % study_gap
	if int(state.get("energy", 0)) <= 25:
		return "复习进度跟上了，但精力已经偏低，明天的学习效率会受影响。"
	if remaining_days > 0 and int(state.get("balance", 0)) < remaining_days * 10:
		return "进度跟上了；余下 %d 天可以多利用存粮和食堂。" % remaining_days
	return "复习进度跟上了，也给明天留出了调整空间。"


func _next_day_preview_text() -> String:
	if day >= GameDataScript.TOTAL_DAYS:
		return "本周已经走完，看看七天里哪些选择真正留下了余力。"
	var learning_modifier := int(pending_learning_state.get("study_modifier", 0))
	var modifier_text := "不变" if learning_modifier == 0 else _signed_delta(learning_modifier)
	var preview := WeeklyEventServiceScript.next_day_preview(day, GameDataScript.TOTAL_DAYS)
	return "明日学习状态：%s（每次复习 %s）｜事件：%s" % [
		String(pending_learning_state.get("title", "状态平稳")),
		modifier_text,
		String(preview.get("title", "照常安排")),
	]


func _build_week_recap() -> Dictionary:
	var lines: Array[String] = ["本周轨迹："]
	var score_total := 0
	var total_spend := 0
	var clear_days := 0
	var strained_days := 0
	for record in run_history:
		var nutrition: Dictionary = record.get("nutrition", {})
		var score := int(nutrition.get("score", 0))
		var start: Dictionary = record.get("start_state", {})
		var finish: Dictionary = record.get("end_state", {})
		var next_condition: Dictionary = record.get("next_learning_state", {})
		score_total += score
		total_spend += int(record.get("spend", 0))
		if String(next_condition.get("id", "")) == "clear_focus":
			clear_days += 1
		elif ["fatigued", "brain_fog"].has(String(next_condition.get("id", ""))):
			strained_days += 1
		lines.append("第 %d 天｜饮食 %d｜复习 %s｜花费 ¥%d｜次日 %s" % [
			int(record.get("day", 0)),
			score,
			_signed_delta(int(finish.get("study_progress", 0)) - int(start.get("study_progress", 0))),
			int(record.get("spend", 0)),
			String(next_condition.get("title", "状态平稳")),
		])
	var played_days := run_history.size()
	var average_nutrition := int(round(float(score_total) / float(played_days))) if played_days > 0 else 0
	lines.append("合计｜%d 天花费 ¥%d｜清醒加成 %d 次｜疲惫/脑雾 %d 次" % [
		played_days,
		total_spend,
		clear_days,
		strained_days,
	])
	return {
		"detail_text": "\n".join(lines),
		"basis": "次日学习状态由前一天的饮食结构、行动、睡眠以及收尾精力和压力共同决定。",
		"average_nutrition": average_nutrition,
	}


func _signed_delta(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _apply_stat_delta(delta: Dictionary) -> void:
	for key in delta.keys():
		if state.has(key):
			state[key] = int(state[key]) + int(delta[key])


func _update_stability() -> void:
	if today_meal_records.is_empty():
		return
	state["stability"] = MealResolverScript.calculate_stability(
		state,
		MealResolverScript.day_quality(today_meal_records),
		day,
		GameDataScript.TOTAL_DAYS
	)


func _clamp_stats() -> void:
	for key in ["stability", "energy", "mood", "satiety", "stress", "diet_burden", "study_progress"]:
		state[key] = clampi(int(state[key]), 0, 100)
	state["balance"] = clampi(int(state["balance"]), 0, 999)


func _update_shell() -> void:
	day_label.text = "第 %d 天 / 第 %d 天" % [day, GameDataScript.TOTAL_DAYS]
	phase_label.text = String(PHASE_NAMES.get(phase, phase))
	balance_label.text = "¥%d" % int(state.get("balance", 0))


func _show_detail(payload: Dictionary, anchor_rect: Rect2, pinned: bool, mode: String) -> void:
	var reason := String(payload.get("disabled_reason", ""))
	var stock := -1
	if mode == "food" and _source_uses_stock():
		stock = int(dorm_inventory.get(String(payload.get("id", "")), 0))
	sticky_note.present(payload, mode, anchor_rect, pinned, reason, "", _mobile_mode, stock)


func _dismiss_detail(item_id: String) -> void:
	if sticky_note.pinned:
		return
	if sticky_note.is_showing_item(item_id):
		sticky_note.hide_note()


func _post(message: String, tone: String = "info") -> void:
	if is_instance_valid(toast_feed):
		toast_feed.push(message, tone)


func _current_meal_phase() -> String:
	if _is_source_phase():
		return phase.trim_suffix("_source")
	if _is_meal_phase():
		return phase
	if phase.begins_with("breakfast"):
		return "breakfast"
	if phase.begins_with("lunch"):
		return "lunch"
	return "dinner"


func _source_uses_stock() -> bool:
	if current_source_id.is_empty():
		return false
	return String(_effective_meal_source(current_source_id).get("payment_mode", "cash")) == "stock"


func _effective_meal_source(source_id: String) -> Dictionary:
	return WeeklyEventServiceScript.apply_meal_source(
		day,
		source_id,
		GameDataScript.get_meal_source(source_id)
	)


func _source_selection_limit(source_id: String) -> int:
	if source_id.is_empty():
		return MAX_FOODS_PER_MEAL
	return clampi(
		int(_effective_meal_source(source_id).get("selection_limit", MAX_FOODS_PER_MEAL)),
		1,
		MAX_FOODS_PER_MEAL
	)


func _is_source_phase() -> bool:
	return phase.ends_with("_source")


func _is_meal_phase() -> bool:
	return MEAL_PHASES.has(phase)


func _is_action_phase() -> bool:
	return phase.ends_with("_action")


func _phase_prompt() -> String:
	match phase:
		"breakfast_action": return "上午留给哪件事？"
		"lunch_action": return "下午怎么安排？"
		_: return "睡前还做什么？"


func _request_main_menu() -> void:
	if day == 1 and today_meal_records.is_empty():
		_go_main_menu()
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "回到主菜单？\n这一周的进度不会保留。"
	dialog.ok_button_text = "回主菜单"
	dialog.cancel_button_text = "继续"
	dialog.confirmed.connect(func() -> void:
		_go_main_menu()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 220))


func _go_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _update_background() -> void:
	var target_path := _background_path_for_phase()
	if target_path == _background_path or not ResourceLoader.exists(target_path):
		_update_time_grade()
		return
	_background_path = target_path
	var front := background_a if _background_a_is_front else background_b
	var back := background_b if _background_a_is_front else background_a
	back.texture = load(target_path) as Texture2D
	back.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(front, "modulate:a", 0.0, 0.30)
	tween.tween_property(back, "modulate:a", 1.0, 0.30)
	tween.chain().tween_callback(func() -> void: _background_a_is_front = not _background_a_is_front)
	_update_time_grade()


func _background_path_for_phase() -> String:
	if _mobile_mode and ACTION_BACKGROUNDS_MOBILE.has(phase):
		var mobile_path := String(ACTION_BACKGROUNDS_MOBILE[phase])
		if ResourceLoader.exists(mobile_path):
			return mobile_path
	if ACTION_BACKGROUNDS.has(phase):
		var action_path := String(ACTION_BACKGROUNDS[phase])
		if ResourceLoader.exists(action_path):
			return action_path
	if not current_source_id.is_empty():
		var configured := String(_effective_meal_source(current_source_id).get("background", ""))
		if ResourceLoader.exists(configured):
			return configured
	return DEFAULT_BACKGROUND


func _update_time_grade() -> void:
	if phase.begins_with("breakfast"):
		time_grade.color = Color(0.16, 0.11, 0.04, 0.08)
	elif phase.begins_with("lunch"):
		time_grade.color = Color(0.04, 0.10, 0.07, 0.10)
	elif phase.begins_with("dinner"):
		time_grade.color = Color(0.08, 0.06, 0.15, 0.20)
	else:
		time_grade.color = Color(0.04, 0.05, 0.12, 0.24)


func _apply_responsive_profile() -> void:
	if _applying_profile:
		return
	_applying_profile = true
	var physical_size := DisplayServer.window_get_size()
	var next_mobile := physical_size.y > physical_size.x * 1.18
	var profile_changed := not _profile_initialized or next_mobile != _mobile_mode
	_mobile_mode = next_mobile
	_profile_initialized = true
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var target_size := Vector2i(720, 1280) if _mobile_mode else Vector2i(1920, 1080)
	if window.content_scale_size != target_size:
		window.content_scale_size = target_size
	_apply_shell_profile()
	_applying_profile = false
	if profile_changed and not state.is_empty():
		call_deferred("_render_phase")


func _apply_shell_profile() -> void:
	var mobile := _mobile_mode
	if is_instance_valid(new_day_popup):
		new_day_popup.set_mobile_mode(mobile)
	top_safe_area.add_theme_constant_override("margin_left", 14 if mobile else 24)
	top_safe_area.add_theme_constant_override("margin_right", 14 if mobile else 24)
	top_safe_area.add_theme_constant_override("margin_top", 12 if mobile else 18)
	stage_safe_area.add_theme_constant_override("margin_left", 12 if mobile else 28)
	stage_safe_area.add_theme_constant_override("margin_right", 12 if mobile else 28)
	stage_safe_area.add_theme_constant_override("margin_top", 94 if mobile else 90)
	stage_safe_area.add_theme_constant_override("margin_bottom", 225 if mobile else 24)
	day_tag.custom_minimum_size = Vector2(194, 64) if mobile else Vector2(250, 54)
	phase_tag.custom_minimum_size = Vector2(150, 64) if mobile else Vector2(190, 54)
	balance_chip.custom_minimum_size = Vector2(105, 64) if mobile else Vector2(150, 54)
	menu_button.custom_minimum_size = Vector2(82, 64) if mobile else Vector2(106, 54)
	day_label.add_theme_font_size_override("font_size", 22 if mobile else 28)
	phase_label.add_theme_font_size_override("font_size", 18 if mobile else 22)
	balance_label.add_theme_font_size_override("font_size", 20 if mobile else 24)
	menu_button.add_theme_font_size_override("font_size", 18 if mobile else 20)
	character_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if mobile:
		character_anchor.offset_left = 4.0
		character_anchor.offset_top = -590.0
		character_anchor.offset_right = 720.0
		character_anchor.offset_bottom = 0.0
		character_hud.pivot_offset = Vector2(0.0, character_anchor.size.y)
		# CharacterHUD lives under a Container; explicit scaling would be reset by
		# the layout pass. Mobile uses its own offsets instead of a fragile scale.
		character_hud.scale = Vector2.ONE
		toast_anchor.anchor_left = 0.0
		toast_anchor.anchor_right = 1.0
		toast_anchor.offset_left = 18.0
		toast_anchor.offset_top = 88.0
		toast_anchor.offset_right = -18.0
		toast_anchor.offset_bottom = 360.0
	else:
		character_anchor.offset_left = -32.0
		character_anchor.offset_top = -690.0
		character_anchor.offset_right = 736.0
		character_anchor.offset_bottom = 0.0
		character_hud.pivot_offset = Vector2.ZERO
		character_hud.scale = Vector2.ONE
		toast_anchor.anchor_left = 1.0
		toast_anchor.anchor_right = 1.0
		toast_anchor.offset_left = -470.0
		toast_anchor.offset_top = 88.0
		toast_anchor.offset_right = -20.0
		toast_anchor.offset_bottom = 430.0
	character_hud.apply_responsive_profile(mobile)


func _apply_stage_profile(stage: Control) -> void:
	if not _mobile_mode:
		return
	if stage is MealSourceStageV2:
		_mobile_source_layout(stage)
	elif stage is CafeteriaMealStageV2:
		_mobile_cafeteria_layout(stage)
	elif stage is TakeoutMealStageV2:
		_mobile_takeout_layout(stage)
	elif stage is ConvenienceMealStageV2:
		_mobile_convenience_layout(stage)
	elif stage is DormPantryStageV2:
		_mobile_dorm_layout(stage)
	elif stage is ActionStageV2:
		_mobile_action_layout(stage)
	elif stage is SleepStageV2:
		_mobile_sleep_layout(stage)


func _mobile_source_layout(stage: Control) -> void:
	_set_rect(stage.get_node("PromptTag") as Control, 0.5, 0.0, 0.5, 0.0, -270, 8, 270, 88)
	var positions := {
		"CafeteriaProp": Vector2(0.24, 0.24),
		"TakeoutProp": Vector2(0.75, 0.29),
		"ConvenienceProp": Vector2(0.28, 0.53),
		"DormProp": Vector2(0.76, 0.57),
	}
	for prop_name in positions:
		var prop := stage.get_node("PropLayer/%s" % prop_name) as Control
		var point: Vector2 = positions[prop_name]
		_set_rect(prop, point.x, point.y, point.x, point.y, -94, -88, 94, 110)
	_set_rect(stage.get_node("Footer") as Control, 1, 1, 1, 1, -342, -126, -8, -64)


func _mobile_cafeteria_layout(stage: Control) -> void:
	_set_rect(stage.get_node("Header") as Control, 0.5, 0, 0.5, 0, -286, 8, 286, 72)
	_set_rect(stage.get_node("FoodRail") as Control, 0.02, 0.10, 0.98, 0.54, 0, 0, 0, 0)
	_set_rect(stage.get_node("TrayDropZone") as Control, 0.29, 0.55, 0.98, 0.80, 0, 0, 0, 0)
	stage.get_node("TrayDropZone/TrayMargin/VBox/TrayHeader/TrayHint").visible = false
	var tray_margin := stage.get_node("TrayDropZone/TrayMargin") as MarginContainer
	tray_margin.add_theme_constant_override("margin_left", 20)
	tray_margin.add_theme_constant_override("margin_right", 20)
	tray_margin.add_theme_constant_override("margin_top", 14)
	tray_margin.add_theme_constant_override("margin_bottom", 14)
	var selected_slots := stage.get_node("TrayDropZone/TrayMargin/VBox/SelectedSlots") as HBoxContainer
	selected_slots.add_theme_constant_override("separation", 12)
	for slot in stage.get_node("TrayDropZone/TrayMargin/VBox/SelectedSlots").get_children():
		(slot as Control).custom_minimum_size = Vector2(108, 140)
	var footer := stage.get_node("Footer") as HBoxContainer
	footer.add_theme_constant_override("separation", 10)
	(footer.get_node("BackButton") as Button).custom_minimum_size = Vector2(120, 60)
	(footer.get_node("SkipButton") as Button).custom_minimum_size = Vector2(110, 60)
	(footer.get_node("ConfirmButton") as Button).custom_minimum_size = Vector2(170, 60)
	_set_rect(footer, 1, 1, 1, 1, -420, -130, -8, -70)


func _mobile_takeout_layout(stage: Control) -> void:
	_set_rect(stage.get_node("Layout/Header") as Control, 0.5, 0, 0.5, 0, -294, 6, 294, 70)
	_set_rect(stage.get_node("Layout/PhoneShell") as Control, 0.65, 0.53, 0.65, 0.53, -240, -405, 240, 300)
	stage.get_node("Layout/SwipeHint").visible = false
	var footer := stage.get_node("Layout/Footer") as HBoxContainer
	(footer.get_node("BackButton") as Button).custom_minimum_size = Vector2(120, 60)
	(footer.get_node("SkipButton") as Button).custom_minimum_size = Vector2(110, 60)
	_set_rect(footer, 1, 1, 1, 1, -250, -130, -8, -70)


func _mobile_convenience_layout(stage: Control) -> void:
	_set_rect(stage.get_node("Layout/Header") as Control, 0.5, 0, 0.5, 0, -294, 6, 294, 70)
	_set_rect(stage.get_node("Layout/ShelfPanel") as Control, 0.02, 0.11, 0.98, 0.54, 0, 0, 0, 0)
	_set_rect(stage.get_node("Layout/BasketPanel") as Control, 0.25, 0.62, 0.98, 0.84, 0, 0, 0, 0)
	stage.get_node("Layout/BasketPanel/BasketMargin/Basket/BasketHeader/BasketHint").visible = false
	var selected_slots := stage.get_node("Layout/BasketPanel/BasketMargin/Basket/SelectedSlots") as HBoxContainer
	selected_slots.add_theme_constant_override("separation", 8)
	for slot in stage.get_node("Layout/BasketPanel/BasketMargin/Basket/SelectedSlots").get_children():
		(slot as Control).custom_minimum_size = Vector2(76, 76)
	var footer := stage.get_node("Layout/Footer") as HBoxContainer
	(footer.get_node("BackButton") as Button).custom_minimum_size = Vector2(120, 60)
	(footer.get_node("SkipButton") as Button).custom_minimum_size = Vector2(110, 60)
	(footer.get_node("ConfirmButton") as Button).custom_minimum_size = Vector2(170, 60)
	_set_rect(footer, 1, 1, 1, 1, -420, -130, -8, -70)


func _mobile_dorm_layout(stage: Control) -> void:
	_set_rect(stage.get_node("Layout/Header") as Control, 0.5, 0, 0.5, 0, -294, 6, 294, 70)
	_set_rect(stage.get_node("Layout/PantryPanel") as Control, 0.02, 0.10, 0.98, 0.48, 0, 0, 0, 0)
	_set_rect(stage.get_node("Layout/BowlPanel") as Control, 0.25, 0.52, 0.98, 0.78, 0, 0, 0, 0)
	stage.get_node("Layout/BowlPanel/BowlMargin/Bowl/BowlHint").visible = false
	stage.get_node("Layout/BowlPanel/BowlMargin/Bowl/BowlReceipt/FreeTag").visible = false
	var bowl_margin := stage.get_node("Layout/BowlPanel/BowlMargin") as MarginContainer
	bowl_margin.add_theme_constant_override("margin_left", 16)
	bowl_margin.add_theme_constant_override("margin_right", 16)
	bowl_margin.add_theme_constant_override("margin_top", 12)
	bowl_margin.add_theme_constant_override("margin_bottom", 12)
	for slot in stage.get_node("Layout/BowlPanel/BowlMargin/Bowl/SelectedSlots").get_children():
		(slot as Control).custom_minimum_size = Vector2(100, 100)
	var footer := stage.get_node("Layout/Footer") as HBoxContainer
	(footer.get_node("BackButton") as Button).custom_minimum_size = Vector2(120, 60)
	(footer.get_node("SkipButton") as Button).custom_minimum_size = Vector2(110, 60)
	(footer.get_node("ConfirmButton") as Button).custom_minimum_size = Vector2(150, 60)
	_set_rect(footer, 1, 1, 1, 1, -400, -130, -8, -70)


func _mobile_action_layout(stage: Control) -> void:
	_set_rect(stage.get_node("Layout/Header") as Control, 0.5, 0, 0.5, 0, -330, 6, 330, 74)
	stage.get_node("Layout/Header/TimeTag").custom_minimum_size = Vector2(120, 64)
	stage.get_node("Layout/Header/PromptTag").custom_minimum_size = Vector2(300, 64)
	stage.get_node("Layout/Header/SlotsTag").custom_minimum_size = Vector2(120, 64)
	_set_rect(stage.get_node("Layout/ActionRail") as Control, 0.02, 0.13, 0.98, 0.68, 0, 0, 0, 0)
	_set_rect(stage.get_node("Layout/PlannerNote") as Control, 0.43, 0.65, 0.98, 0.82, 0, 0, 0, 0)
	for slot in stage.get_node("Layout/PlannerNote/PlannerMargin/Planner/UsedSlots").get_children():
		(slot as Control).custom_minimum_size = Vector2(90, 90)
	_set_rect(stage.get_node("Layout/SkipButton") as Control, 1, 1, 1, 1, -178, -120, -8, -60)


func _mobile_sleep_layout(stage: Control) -> void:
	_set_rect(stage.get_node("Layout/PromptTag") as Control, 0.5, 0, 0.5, 0, -320, 8, 320, 90)
	_set_rect(stage.get_node("Layout/SleepRail") as Control, 0.02, 0.15, 0.98, 0.66, 0, 0, 0, 0)
	_set_rect(stage.get_node("Layout/AlarmNote") as Control, 0.43, 0.72, 0.98, 0.86, 0, 0, 0, 0)
	(stage.get_node("Layout/AlarmNote/AlarmMargin/Alarm/Clock") as Label).add_theme_font_size_override("font_size", 34)


func _set_rect(
	control: Control,
	left: float,
	top: float,
	right: float,
	bottom: float,
	rect_left: float,
	rect_top: float,
	rect_right: float,
	rect_bottom: float
) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = rect_left
	control.offset_top = rect_top
	control.offset_right = rect_right
	control.offset_bottom = rect_bottom
