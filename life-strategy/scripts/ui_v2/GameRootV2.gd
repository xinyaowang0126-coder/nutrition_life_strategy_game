class_name GameRootV2
extends Control

const GameDataScript := preload("res://scripts/GameData.gd")
const MealDeckServiceScript := preload("res://scripts/systems/MealDeckService.gd")
const MealResolverScript := preload("res://scripts/systems/MealResolver.gd")
const DecisionPreviewScript := preload("res://scripts/ui_v2/DecisionCostPreview.gd")
const BalanceRules := preload("res://scripts/systems/GameplayBalanceRules.gd")
const NutritionLedgerScript := preload("res://scripts/systems/NutritionLedger.gd")
const WeeklyEventServiceScript := preload("res://scripts/systems/WeeklyEventService.gd")
const RecoveryStateServiceScript := preload("res://scripts/systems/RecoveryStateService.gd")
const RecoveryGameplayServiceScript := preload("res://scripts/systems/RecoveryGameplayService.gd")
const RecoveryPresenterScript := preload("res://scripts/systems/RecoveryPresenter.gd")
const HealthGuidanceFeatureFlagsScript := preload("res://scripts/health/HealthGuidanceFeatureFlags.gd")
const HealthDataStoreScript := preload("res://scripts/health/HealthDataStore.gd")
const HealthDataValidatorScript := preload("res://scripts/health/HealthDataValidator.gd")
const MealHealthSnapshotScript := preload("res://scripts/health/MealHealthSnapshot.gd")
const MealHealthArchiveScript := preload("res://scripts/health/MealHealthArchive.gd")
const FoodPreferenceServiceScript := preload("res://scripts/systems/FoodPreferenceService.gd")
const DEFAULT_HEALTH_HISTORY_PATH := "user://health_guidance/latest_meals.json"
const MealRecordPresenterScript := preload("res://scripts/systems/MealRecordPresenter.gd")
const RECORD_BOOK_SCENE := preload("res://scenes/game_v2/components/MealRecordBookPopup.tscn")

const SOURCE_STAGE_SCENE := preload("res://scenes/game_v2/stages/MealSourceStage.tscn")
const CAFETERIA_STAGE_SCENE := preload("res://scenes/game_v2/stages/CafeteriaMealStage.tscn")
const TAKEOUT_STAGE_SCENE := preload("res://scenes/game_v2/stages/TakeoutMealStage.tscn")
const CONVENIENCE_STAGE_SCENE := preload("res://scenes/game_v2/stages/ConvenienceMealStage.tscn")
const DORM_STAGE_SCENE := preload("res://scenes/game_v2/stages/DormPantryStage.tscn")
const ACTION_STAGE_SCENE := preload("res://scenes/game_v2/stages/ActionStage.tscn")
const SLEEP_STAGE_SCENE := preload("res://scenes/game_v2/stages/SleepStage.tscn")

const StoryCatalogScript := preload("res://scripts/stories/StoryCatalog.gd")
const StorySessionScript := preload("res://scripts/stories/StorySession.gd")
const KitchenScript := preload("res://scripts/stories/KitchenStock.gd")
const StoryEducationScript := preload("res://scripts/stories/StoryEducation.gd")
const StoryDialogScript := preload("res://scripts/stories/StoryDialog.gd")
const MealFactsScript := preload("res://scripts/stories/HouseholdMealFacts.gd")
const SharedMealScript := preload("res://scripts/stories/SharedMealPlan.gd")
const HouseholdLearningScript := preload("res://scripts/stories/HouseholdLearningFlow.gd")
const HouseholdLearningPresenterScript := preload("res://scripts/stories/HouseholdLearningPresenter.gd")
const HouseholdMealLearningScript := preload("res://scripts/stories/HouseholdMealLearning.gd")
const HouseholdStudyPresenterScript := preload("res://scripts/stories/HouseholdStudyPresenter.gd")
const HouseholdDayFiveScript := preload("res://scripts/stories/HouseholdDayFive.gd")
const HouseholdDayFivePresenterScript := preload("res://scripts/stories/HouseholdDayFivePresenter.gd")
const HouseholdPreparationScript := preload("res://scripts/stories/HouseholdPreparation.gd")
const HouseholdPreparationPresenterScript := preload("res://scripts/stories/HouseholdPreparationPresenter.gd")
const HouseholdFinaleScript := preload("res://scripts/stories/HouseholdFinale.gd")
const HouseholdFinalePresenterScript := preload("res://scripts/stories/HouseholdFinalePresenter.gd")
const SaveCodecScript := preload("res://scripts/stories/GameSaveCodec.gd")
const SaveStoreScript := preload("res://scripts/stories/GameSaveStore.gd")
const HOUSEHOLD_SOURCE_SCENE := preload("res://scenes/stories/HouseholdSourceStage.tscn")
const HOUSEHOLD_MEAL_SCENE := preload("res://scenes/stories/HouseholdMealStage.tscn")
const WorktopScript := preload("res://scripts/stories/HouseholdWorktop.gd")
const CookingPlanScript := preload("res://scripts/stories/CookingPlanStage.gd")
const KitchenStageScript := preload("res://scripts/stories/KitchenStockStage.gd")
const MarketStageScript := preload("res://scripts/stories/HouseholdMarketStage.gd")
const LocationsScript := preload("res://scripts/stories/HouseholdLocations.gd")
const HOUSEHOLD_HOME_NIGHT := "res://assets/generated/stories/night/zhou_home_night-v1.png"
const HOUSEHOLD_SLEEP_ART := {
	"sleep_early": "res://assets/generated/stories/night/zhou_sleep_early-v1.png",
	"night_study": "res://assets/generated/stories/night/zhou_review_score-v1.png",
	"scroll_phone": "res://assets/generated/stories/night/zhou_scroll_phone-v1.png",
}

const MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const DEFAULT_BACKGROUND := "res://assets/generated/backgrounds/dorm_background.png"
const SOURCE_MAP := "res://assets/generated/ui_v3/backgrounds/campus_map.png"
const SOURCE_MAP_MOBILE := "res://assets/generated/ui_v3/backgrounds/campus_map_portrait.png"
const ACTION_BACKGROUNDS := {
	"breakfast_action": "res://assets/generated/ui_v3/backgrounds/dorm_morning.png",
	"lunch_action": "res://assets/generated/ui_v3/backgrounds/campus_afternoon.png",
	"dinner_action": "res://assets/generated/ui_v3/backgrounds/campus_evening.png",
	"sleep": "res://assets/generated/backgrounds/dorm_background.png",
	"summary": "res://assets/generated/backgrounds/dorm_background.png",
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
@onready var week_ribbon: HBoxContainer = $HUD/HUDRoot/TopSafeArea/TopHUD/TopSpacer
@onready var character_anchor: Control = $HUD/HUDRoot/CharacterAnchor
@onready var character_hud: CharacterHUDV2 = $HUD/HUDRoot/CharacterAnchor/CharacterSlot/CharacterHUD
@onready var toast_anchor: Control = $HUD/HUDRoot/ToastAnchor
@onready var toast_feed: ToastFeedV2 = $HUD/HUDRoot/ToastAnchor/ToastFeed
@onready var sticky_note: StickyNotePopupV2 = $HUD/HUDRoot/DetailLayer/StickyNote
@onready var daily_summary: DailySummaryPopupV2 = $HUD/HUDRoot/ModalLayer/DailySummary
@onready var new_day_popup: NewDayPopupV2 = $HUD/HUDRoot/ModalLayer/NewDayPopup

var story_id := "campus_exam"
var story: Dictionary = {}
var kitchen := KitchenScript.new()
var shared_meal := SharedMealScript.new()
var performed := false
var _story_dialog: StoryDialog
var _story_choice_handler: Callable
var _workspace: HouseholdWorktop
var _household_market_context := ""
var _workspace_restore: Dictionary = {}
var _lesson_seen: Dictionary = {}
var household_learning: Dictionary = {}
var household_lessons: Dictionary = {}
var household_day_five: Dictionary = {}
var household_preparation: Dictionary = {}
var household_finale: Dictionary = {}

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
var today_period_records: Array[Dictionary] = []
var combos_today: Array[String] = []
var summary_payload: Dictionary = {}
var health_guidance_flags: Dictionary = {}
var food_preferences: Dictionary = {}
var health_profiles_path := HealthDataStoreScript.DEFAULT_PROFILES_PATH
var health_history_path := DEFAULT_HEALTH_HISTORY_PATH
var health_history_diagnostics: Array[Dictionary] = []
var ending_id := ""
var low_stability_days := 0
var run_history: Array[Dictionary] = []
var current_event: Dictionary = {}
var current_learning_state: Dictionary = {}
var pending_learning_state: Dictionary = {}
var pending_recovery_state: Dictionary = RecoveryStateServiceScript.new_run()
var current_recovery_state: Dictionary = RecoveryStateServiceScript.new_run()
var _current_recovery_effect: Dictionary = {"study_modifier": 0, "opening_delta": {}}
var _recovery_display_record: Dictionary = {}
var _started_day := 0
var recovery_diagnostics: Array[Dictionary] = []
var _day_start_state: Dictionary = {}
var chosen_sleep_id := ""
var chosen_sleep_name := ""
var _recovery_before_sleep: Dictionary = {}
var _recovery_sleep_snapshot: Dictionary = {}
var _day_settlement_effects: Array[Dictionary] = []
var _day_settled := false

var _deck_service: RefCounted
var _active_stage: Control
var _mobile_mode := false
var _profile_initialized := false
var _applying_profile := false
var _background_path := ""
var _background_mobile := false
var _background_a_is_front := true
var _background_tween: Tween
var _health_archive: RefCounted
var _health_catalog: Dictionary = {}
var _health_catalog_loaded := false
var _record_book: MealRecordBookPopupV2
var _record_input_restore: Dictionary = {}
var _story_input_restore: Dictionary = {}
var _new_day_pending := false
var _save_store: RefCounted
var _autosave_queued := false
var _autosave_busy := false
var _save_generation := 0
var _save_status: Label
var save_diagnostics: Array[Dictionary] = []


func _ready() -> void:
	story_id = StorySessionScript.take_request()
	story = StoryCatalogScript.get_story(story_id)
	GameDataScript.ensure_loaded()
	health_guidance_flags = HealthGuidanceFeatureFlagsScript.current()
	HealthGuidanceFeatureFlagsScript.warn_for_invalid(health_guidance_flags)
	_deck_service = MealDeckServiceScript.new()
	menu_button.pressed.connect(_show_game_menu)
	character_hud.details_requested.connect(_show_detail.bind("state"))
	character_hud.detail_dismissed.connect(_dismiss_detail)
	sticky_note.closed.connect(_restore_detail_input)
	daily_summary.next_day_requested.connect(_on_summary_advanced)
	daily_summary.record_book_requested.connect(_show_meal_record_book)
	new_day_popup.continue_requested.connect(_on_new_day_continue)
	new_day_popup.recovery_details_requested.connect(_show_recovery_detail)
	get_viewport().size_changed.connect(_apply_responsive_profile)
	_apply_responsive_profile()
	_save_store = SaveStoreScript.new()
	_save_status = Label.new()
	_save_status.name = "SaveStatus"
	_save_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_status.add_theme_font_size_override("font_size", 22)
	_save_status.add_theme_color_override("font_color", Color("#f1dfbd"))
	_save_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_save_status.offset_left = 18
	_save_status.offset_top = -36
	_save_status.offset_right = 220
	_save_status.offset_bottom = -6
	$HUD/HUDRoot.add_child(_save_status)
	var saved := StorySessionScript.take_saved()
	if saved.is_empty():
		start_new_run()
	else:
		var restored := restore_game_save(saved)
		if not restored["ok"]:
			_show_story_dialog("进度未能读取", restored["message"], [{"id": "menu", "text": "回到故事选择"}], func(_id: String) -> void: _go_main_menu())


func start_new_run() -> void:
	_household_market_context = ""
	_save_generation += 1
	_new_day_pending = false
	if _record_book_active():
		_record_book.close_book()
	var requested_story := StoryCatalogScript.get_story(story_id)
	if requested_story.is_empty():
		story_id = String(story.get("id", "campus_exam"))
		return
	story = requested_story
	food_preferences = FoodPreferenceServiceScript.load_profile(String(story["preferences"]))
	performed = false
	_lesson_seen.clear()
	household_learning = HouseholdLearningScript.initial_state() if _household() else {}
	household_lessons = HouseholdMealLearningScript.initial_state() if _household() else {}
	household_day_five = HouseholdDayFiveScript.initial_state() if _household() else {}
	household_preparation = HouseholdPreparationScript.initial_state() if _household() else {}
	household_finale = HouseholdFinaleScript.initial_state() if _household() else {}
	kitchen.reset()
	shared_meal.reset()
	if is_instance_valid(_story_dialog):
		_story_dialog.hide()
	_story_choice_handler = Callable()
	if is_node_ready():
		character_hud.set_portrait(String(story["portrait"]))
	if _health_archive != null:
		_health_archive.clear()
	_health_catalog.clear()
	_health_catalog_loaded = false
	health_history_diagnostics.clear()
	state = StoryCatalogScript.initial_stats(story)
	day = 1
	low_stability_days = 0
	dorm_inventory = {} if _household() else GameDataScript.get_initial_dorm_inventory()
	ending_id = ""
	run_history.clear()
	current_event.clear()
	pending_recovery_state = RecoveryStateServiceScript.new_run()
	current_recovery_state = pending_recovery_state.duplicate(true)
	_current_recovery_effect = pending_recovery_state["next_day_effect"].duplicate(true)
	_started_day = 0
	pending_learning_state = RecoveryGameplayServiceScript.learning_state(pending_recovery_state)["learning_state"]
	recovery_diagnostics.clear()
	if _household():
		_update_stability(current_recovery_state)
	if is_node_ready():
		daily_summary.hide_summary(false)
		new_day_popup.hide_popup(false)
		sticky_note.hide_note(false)
	_start_day()
	_render_phase()
	_show_new_day_popup()


func _start_day() -> bool:
	if _started_day == day:
		return true
	var previous: Variant = pending_recovery_state if day == 1 else null
	if day > 1 and not run_history.is_empty() and run_history.back().get("day") == day - 1:
		previous = run_history.back().get("recovery_state")
	var prepared := RecoveryGameplayServiceScript.prepare_day(previous, day - 1)
	if not prepared["valid"]:
		_record_recovery_error("recovery_opening_invalid", prepared["errors"])
		return false
	_day_start_state = state.duplicate(true)
	current_recovery_state = prepared["recovery_state"].duplicate(true)
	_recovery_display_record = current_recovery_state.duplicate(true)
	_current_recovery_effect = current_recovery_state["next_day_effect"].duplicate(true)
	current_learning_state = prepared["learning_state"].duplicate(true)
	_apply_stat_delta(_current_recovery_effect["opening_delta"])
	current_event = _story_event(day)
	if not _household():
		state = WeeklyEventServiceScript.apply_opening_state(day, state)
	else:
		kitchen.refresh(day)
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
	today_period_records.clear()
	combos_today.clear()
	summary_payload.clear()
	chosen_sleep_id = ""
	chosen_sleep_name = ""
	_recovery_before_sleep.clear()
	_recovery_sleep_snapshot.clear()
	_day_settlement_effects.clear()
	_day_settled = false
	_started_day = day
	return true


func _render_phase() -> void:
	if not is_node_ready() or state.is_empty():
		return
	sticky_note.hide_note(false)
	# Source and food cards need this space; confirmed-meal feedback appears
	# when the player reaches the following action phase.
	_update_toast_visibility()
	_update_shell()
	_update_background()
	character_hud.update_stats(_hud_stats(), true)
	character_hud.update_recovery(_recovery_display_record)
	_queue_autosave()
	if phase == "summary":
		_clear_stage()
		daily_summary.show_summary(_story_view(summary_payload), _mobile_mode)
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
	var stage: Control
	if _market_is_open():
		stage = MarketStageScript.new()
		stage.back_requested.connect(_return_from_market)
	elif _household():
		stage = HOUSEHOLD_SOURCE_SCENE.instantiate()
		stage.notebook_requested.connect(_show_source_notebook)
		stage.outings_requested.connect(_show_outing_choices)
	else:
		stage = SOURCE_STAGE_SCENE.instantiate()
	_install_stage(stage)
	var sources: Array[Dictionary] = []
	var disabled_reasons := {}
	var meal := _current_meal_phase()
	for source_id in _story_source_ids():
		var source := _effective_meal_source(source_id)
		var reason := _source_disabled_reason(source_id, meal)
		source["enabled"] = reason.is_empty()
		source["disabled_reason"] = reason
		sources.append(source)
		disabled_reasons[source_id] = reason
	stage.source_selected.connect(func(source_id: String) -> void:
		if stage == _active_stage:
			_choose_meal_source(source_id)
	)
	if stage.has_signal("skip_requested"): stage.skip_requested.connect(_skip_meal)
	stage.detail_requested.connect(_show_detail.bind("source"))
	stage.detail_dismissed.connect(_dismiss_detail)
	if _household():
		var plan_note := shared_meal.summary() if shared_meal.plan.get("status") == "planned" else ""
		if stage is HouseholdSourceStage:
			var effort := maxi(0, -int(_effective_meal_source("home_fridge").get("energy", 0)))
			var preparation_note := HouseholdLearningScript.preparation_notice(kitchen, _story_food_catalog(), day, _story_clock(), effort)
			var intention := HouseholdPreparationScript.notice(household_preparation, day, meal)
			if not intention.is_empty(): preparation_note = intention + ("\n" + preparation_note if not preparation_note.is_empty() else "")
			stage.setup(sources, String(PHASE_NAMES[meal]), disabled_reasons, plan_note, preparation_note)
		else:
			stage.setup(sources, String(PHASE_NAMES[meal]), disabled_reasons, plan_note)
	else:
		stage.setup(sources, String(PHASE_NAMES[meal]), disabled_reasons)


func _show_meal_stage() -> void:
	var scene: PackedScene
	match String(_effective_meal_source(current_source_id).get("stage_kind", current_source_id)):
		"takeout":
			scene = TAKEOUT_STAGE_SCENE
		"convenience_store":
			scene = CONVENIENCE_STAGE_SCENE
		"dorm_storage":
			scene = DORM_STAGE_SCENE
		"cook", "fridge", "purchase":
			scene = HOUSEHOLD_MEAL_SCENE
		_:
			scene = CAFETERIA_STAGE_SCENE
	var stage := scene.instantiate() as MealStageBaseV2
	_install_stage(stage)
	var foods: Array[Dictionary] = []
	for food_id in hand:
		foods.append(get_food_for_character(food_id))
	var source := _effective_meal_source(current_source_id)
	var options := {
		"max_selected": _source_selection_limit(current_source_id),
		"source_fee": int(source.get("fee", 0)),
		"balance": int(state.get("balance", 0)),
		"payment_mode": String(source.get("payment_mode", "cash")),
		"meal_label": String(PHASE_NAMES[phase]),
		"location_name": String(source.get("name", "食堂窗口")) if _household() else "食堂窗口",
		"return_label": "回集市" if _household() and HouseholdMarketStage.OUTSIDE_ORDER.has(current_source_id) else "换个地方",
		"stock_by_id": _visible_stock(),
		"meal_kind": String(source.get("stage_kind", "")),
		"batch_notes": _household_batch_notes(),
		"cost_preview_builder": Callable(self, "preview_meal_cost"),
		"learning_day": day if _household() else 0,
	}
	if stage is HouseholdMealStage:
		(stage as HouseholdMealStage).kitchen_requested.connect(_show_kitchen)
		(stage as HouseholdMealStage).study_requested.connect(func(ids: Array) -> void:
			if stage != _active_stage: return
			if day == 5: HouseholdDayFivePresenterScript.open_guide(self, ids)
			elif day == 6: HouseholdPreparationPresenterScript.open_planner(self, ids)
			elif day == 7: HouseholdFinalePresenterScript.open_plan(self)
			else: HouseholdStudyPresenterScript.open_selection(self, ids)
		)
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
	for action_id in _story_action_ids(phase):
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
	stage.finale_requested.connect(func() -> void:
		if stage == _active_stage: HouseholdFinalePresenterScript.open_plan(self)
	)
	stage.setup(actions, {
		"time_label": String(PHASE_NAMES[phase]),
		"prompt": _phase_prompt(),
		"slots_used": actions_used_today,
		"max_slots": MAX_DAILY_ACTIONS,
		"water_count": drink_water_used,
		"water_max": 2,
		"used_action_names": used_action_names,
		"used_action_ids": used_action_ids.filter(func(id: String) -> bool: return int(_story_action(id).get("slots", 1)) > 0),
		"story_note": _household_action_note() if _household() else "",
		"show_finale": _household() and day == 7,
	})


func _show_sleep_stage() -> void:
	var stage := SLEEP_STAGE_SCENE.instantiate() as SleepStageV2
	_install_stage(stage)
	var options_list: Array[Dictionary] = []
	for option_id in GameDataScript.get_sleep_option_ids_for_scene("sleep"):
		options_list.append(_story_sleep(option_id))
	var tomorrow_preview := _story_preview(day)
	var tomorrow_text := "周末就要到了"
	if not tomorrow_preview.is_empty():
		tomorrow_text = "%s · %s" % [
			String(tomorrow_preview.get("title", "明日安排")),
			String(tomorrow_preview.get("summary", "")),
		]
	if _household(): tomorrow_text = _household_night_note()
	stage.sleep_selected.connect(_choose_sleep)
	stage.detail_requested.connect(_show_detail.bind("sleep"))
	stage.detail_dismissed.connect(_dismiss_detail)
	stage.setup(options_list, {
		"prompt": ("回到家，今晚怎么收尾？" if performed else "夜深了，今晚怎么歇？") if _household() else "夜深了，几点睡？",
		"sub_prompt": ("按自己的节奏，安顿好今天。" if day == _total_days() else "把今天放下，给明天留点精神。") if _household() else "闹钟还没响，先把今晚定下来。",
		"tomorrow_text": tomorrow_text,
		"hint": ("睡前把今天安顿好，再翻翻这一周的记录。" if day == _total_days() else "点卡片问号，看看今晚不同安排的代价。") if _household() else "点小圆标看清代价，再决定。",
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
	_close_workspace(false)
	if is_instance_valid(_active_stage):
		# Retired stages remain alive until frame end; silence every outgoing
		# command, including skip/back, before another stage can accept input.
		_active_stage.set_block_signals(true)
		_active_stage.hide()
		_active_stage.queue_free()
	_active_stage = null
	for child in stage_host.get_children():
		if child != _active_stage and not child.is_queued_for_deletion():
			child.queue_free()


func _choose_meal_source(source_id: String) -> void:
	if _record_book_active():
		return
	# A removed source stage can still emit until queue_free() completes.
	# Never reopen a settled meal from its action/summary phase.
	if not _is_source_phase():
		return
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
	if _record_book_active():
		return
	# The outgoing stage is freed at the end of the frame.  Ignore a second
	# click/tap from that stale stage instead of producing e.g.
	# `breakfast_source_source`.
	if not _is_meal_phase():
		return
	_household_market_context = "%d:%s" % [day, phase] if _household() and HouseholdMarketStage.OUTSIDE_ORDER.has(current_source_id) else ""
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
		var available := _story_food_ids(source_id, meal)
		for value in cached:
			var food_id := String(value)
			if available.has(food_id) and (String(_effective_meal_source(source_id).get("payment_mode", "cash")) != "stock" or _stock_count(food_id, source_id) > 0):
				valid_cached.append(food_id)
		if not valid_cached.is_empty(): return valid_cached
	var source := _effective_meal_source(source_id)
	var candidates := _story_food_ids(source_id, meal)
	var uses_stock := String(source.get("payment_mode", "cash")) == "stock"
	var built: Array[String] = _deck_service.build_hand(
		candidates,
		int(source.get("hand_size", 4)),
		_visible_stock(source_id),
		uses_stock
	)
	if not uses_stock:
		_ensure_affordable_in_source_hand(built, candidates, int(source.get("fee", 0)))
	source_hands[cache_key] = built.duplicate()
	return built


func _ensure_affordable_in_source_hand(built: Array[String], candidates: Array[String], fee: int) -> void:
	for food_id in built:
		if int(_story_food(food_id)["cost"]) + fee <= int(state["balance"]):
			return
	var cheapest_id := ""
	var cheapest_cost := 100000
	for food_id in candidates:
		var cost := int(_story_food(food_id)["cost"])
		if cost < cheapest_cost and cost + fee <= int(state["balance"]):
			cheapest_cost = cost
			cheapest_id = food_id
	if not cheapest_id.is_empty():
		if built.is_empty():
			built.append(cheapest_id)
		else:
			built[built.size() - 1] = cheapest_id


func _source_disabled_reason(source_id: String, meal: String) -> String:
	if not _story_source_available(source_id, meal):
		return "这个时段还没营业。"
	var source := _effective_meal_source(source_id)
	var candidates := _story_food_ids(source_id, meal)
	if String(source.get("payment_mode", "cash")) == "stock":
		for food_id in candidates:
			if _stock_count(food_id, source_id) > 0:
				return ""
		return "柜子已经空了。"
	var fee := int(source.get("fee", 0))
	for food_id in candidates:
		if int(_story_food(food_id)["cost"]) + fee <= int(state["balance"]):
			return ""
	return "余额不够在这里买一份。"


func _on_food_toggled(food_id: String) -> void:
	if _record_book_active():
		if is_instance_valid(_active_stage) and _active_stage.has_method("set_selection"):
			_active_stage.call("set_selection", selected_food_ids, false)
		return
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
		if _household() and current_source_id == "home_kitchen":
			return kitchen.can_cook(selected_food_ids + [food_id], _story_food_catalog(), _served_portions())
		return _stock_count(food_id, current_source_id) > 0
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
		total += int(_story_food(food_id).get("cost", 0))
	return total


func preview_meal_cost(food_ids: Array) -> Dictionary:
	if current_source_id.is_empty() or not _is_meal_phase() or food_ids.is_empty(): return {}
	var foods: Array[Dictionary] = []
	var seen := {}
	for value in food_ids:
		var id := String(value)
		if not hand.has(id) or seen.has(id): return {}
		seen[id] = true
		foods.append(_story_food(id))
	var source := _effective_meal_source(current_source_id)
	var record := MealResolverScript.build_record(phase, source, foods, food_preferences)
	var inventory := {}
	var caption := "库存取用"
	var recipe_next := _household() and current_source_id == "home_kitchen"
	if recipe_next:
		caption = "当餐食材"
		var needed := kitchen.needs(food_ids, _story_food_catalog())
		for key in needed: inventory[_ingredient_name(String(key))] = int(needed[key]) * _served_portions()
	elif bool(record["uses_stock"]):
		for food in foods: inventory[String(food["name"])] = int(inventory.get(String(food["name"]), 0)) + 1
	return DecisionPreviewScript.meal(record, source, inventory, caption, recipe_next)


func _confirm_food(food_ids: Array) -> void:
	if _record_book_active():
		return
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
	if _household():
		if current_source_id == "home_kitchen" and is_node_ready():
			_show_cooking_choice(safe_ids)
		else:
			confirm_household_food(safe_ids)
		return
	var foods: Array[Dictionary] = []
	for food_id in safe_ids:
		foods.append(_story_food(food_id))
	var source := _effective_meal_source(current_source_id)
	var record := MealResolverScript.build_record(phase, source, foods, food_preferences)
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
	if _record_book_active():
		return
	# Stage replacement uses queue_free(), so a rapid second tap can still emit
	# from the old source/meal stage during this frame.  Only the active meal
	# entry points are allowed to create a skipped record.
	if not _is_source_phase() and not _is_meal_phase():
		return
	var meal := _current_meal_phase()
	var record := MealResolverScript.build_skipped_record(meal)
	_apply_meal_record(record)
	_post("%s没吃。" % String(PHASE_NAMES[meal]), "warning")
	selected_food_ids.clear()
	hand.clear()
	current_source_id = ""
	phase = meal
	_advance_from_meal()


func _apply_meal_record(record: Dictionary) -> void:
	state["balance"] = int(state["balance"]) - int(record["total_cost"])
	_apply_stat_delta(record["stat_delta"])
	if bool(record["uses_stock"]) and not _household():
		for food_id in record["food_ids"]:
			var key := String(food_id)
			dorm_inventory[key] = maxi(0, int(dorm_inventory.get(key, 0)) - 1)
	_capture_health_snapshot(record)
	today_meal_records.append(record.duplicate(true))
	_check_meal_combos(record)
	_clamp_stats()
	_update_stability()


func get_meal_guidance_input() -> Dictionary:
	# Explicit, detached read for G4 adapters/shadow diagnostics. It neither
	# builds a hand nor loads health data when the feature flags are closed.
	return {
		"day": day, "phase": phase, "source_id": current_source_id,
		"balance": state.get("balance", 0), "hand_ids": hand.duplicate(),
		"selected_ids": selected_food_ids.duplicate(),
		"inventory": dorm_inventory.duplicate(true),
	}


func get_meal_record_book() -> Dictionary:
	return MealRecordPresenterScript.capture(run_history, today_meal_records, day)


func _record_book_active() -> bool:
	return (is_instance_valid(_record_book) and _record_book.visible) or (is_instance_valid(_story_dialog) and _story_dialog.visible) or (is_instance_valid(_workspace) and _workspace.visible)


func _show_meal_record_book() -> void:
	if not is_node_ready() or _record_book_active():
		return
	if not is_instance_valid(_record_book):
		_record_book = RECORD_BOOK_SCENE.instantiate() as MealRecordBookPopupV2
		daily_summary.get_parent().add_child(_record_book)
		_record_book.closed.connect(_on_meal_record_book_closed)
		_record_book.main_menu_requested.connect(func() -> void:
			_record_book.close_book()
			_request_main_menu()
		)
	var detail_was_visible := sticky_note.visible
	sticky_note.hide_note(false)
	if detail_was_visible:
		_restore_detail_input()
	_record_input_restore = {
		"summary_keys": daily_summary.is_processing_unhandled_key_input(),
		"summary_button": daily_summary.next_button.disabled,
		"new_day_keys": new_day_popup.is_processing_unhandled_key_input(),
		"new_day_button": new_day_popup.continue_button.disabled,
	}
	daily_summary.set_process_unhandled_key_input(false)
	daily_summary.next_button.disabled = true
	new_day_popup.set_process_unhandled_key_input(false)
	new_day_popup.continue_button.disabled = true
	var return_text := "回到结局" if phase == "ending" else ("回到小结" if phase == "summary" else "继续安排")
	_record_book.show_book(get_meal_record_book(), return_text)


func _on_meal_record_book_closed() -> void:
	if _record_input_restore.is_empty():
		return
	daily_summary.set_process_unhandled_key_input(_record_input_restore["summary_keys"])
	daily_summary.next_button.disabled = _record_input_restore["summary_button"]
	new_day_popup.set_process_unhandled_key_input(_record_input_restore["new_day_keys"])
	new_day_popup.continue_button.disabled = _record_input_restore["new_day_button"]
	_record_input_restore.clear()
	if is_instance_valid(_active_stage) and _active_stage.has_method("set_selection"):
		_active_stage.call("set_selection", selected_food_ids, false)
	if daily_summary.visible:
		daily_summary.next_button.grab_focus()
	elif new_day_popup.visible:
		new_day_popup.continue_button.grab_focus()
	else:
		menu_button.grab_focus()


func _restore_detail_input() -> void:
	if _record_book_active():
		return
	new_day_popup.set_process_unhandled_key_input(true)
	if new_day_popup.visible:
		new_day_popup.continue_button.disabled = false
		new_day_popup.recovery_details_button.grab_focus()


func get_food_for_character(food_id: String) -> Dictionary:
	return FoodPreferenceServiceScript.decorate_food(_story_food(food_id), food_preferences)


func set_food_preferences(profile: Dictionary) -> void:
	food_preferences = profile.duplicate(true)
	if is_node_ready():
		sticky_note.hide_note(false)
		if _is_meal_phase():
			_render_phase()


func get_health_snapshots() -> Array[Dictionary]:
	if not _health_data_enabled() or _health_archive == null:
		return []
	return _health_archive.get_snapshots()


func save_health_history(path: String) -> Dictionary:
	if not _health_data_enabled():
		return {"ok": false, "error": "health_data_disabled"}
	_ensure_health_archive()
	return _health_archive.save_file(path)


func load_health_history(path: String) -> Dictionary:
	if not _health_data_enabled():
		return {"ok": false, "error": "health_data_disabled"}
	# Historical inspection is separate from the active run. Loading yesterday's
	# archive must not mix its meals into new submissions or restore game stats.
	var archive := MealHealthArchiveScript.new()
	var result: Dictionary = archive.load_file(path)
	if bool(result.get("ok", false)):
		result["snapshots"] = archive.get_snapshots()
	return result


func _health_data_enabled() -> bool:
	return not _household() and HealthGuidanceFeatureFlagsScript.is_enabled(health_guidance_flags, "data")


func _ensure_health_archive() -> void:
	if _health_archive == null:
		_health_archive = MealHealthArchiveScript.new()


func _load_health_catalog() -> Dictionary:
	if _health_catalog_loaded:
		return _health_catalog
	_health_catalog_loaded = true
	var store := HealthDataStoreScript.new()
	var catalog: Dictionary = store.load_catalog(health_profiles_path)
	var validation := HealthDataValidatorScript.validate(catalog, {
		"known_food_ids": GameDataScript.CardDataStoreScript.food_ids,
	})
	if not bool(validation.get("valid", false)):
		health_history_diagnostics.append({
			"code": "health_catalog_unavailable",
			"path": health_profiles_path,
			"status": String(catalog.get("status", "unknown")),
			"errors": validation.get("errors", []).duplicate(true),
		})
		_health_catalog = {}
	else:
		_health_catalog = catalog
	return _health_catalog


func _capture_health_snapshot(record: Dictionary) -> void:
	if not _health_data_enabled():
		return
	var snapshot := MealHealthSnapshotScript.build(day, record, _load_health_catalog())
	_ensure_health_archive()
	var result: Dictionary = _health_archive.append_snapshot(snapshot)
	if not bool(result.get("ok", false)):
		health_history_diagnostics.append({"code": "snapshot_rejected", "result": result})
		return
	# Keep the settled record and archive independent of each other's mutations.
	record["health_snapshot"] = snapshot.duplicate(true)
	_autosave_health_history()


func _autosave_health_history() -> void:
	if health_history_path.is_empty():
		return
	if health_history_path == DEFAULT_HEALTH_HISTORY_PATH:
		var directory_error := DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://health_guidance")
		)
		if directory_error != OK:
			health_history_diagnostics.append({
				"code": "history_directory_failed", "error": directory_error,
			})
			return
	var result := save_health_history(health_history_path)
	if not bool(result.get("ok", false)):
		health_history_diagnostics.append({"code": "history_save_failed", "result": result})


func _check_meal_combos(record: Dictionary) -> void:
	if not combos_today.has("meal_group_mix") and MealResolverScript.has_meal_group_combination(record):
		combos_today.append("meal_group_mix")
	if not combos_today.has("comfort_chain") and MealResolverScript.comfort_meal_count(today_meal_records) >= 2:
		combos_today.append("comfort_chain")
		state["mood"] = int(state["mood"]) + 2
		_post("今天已有两餐合口味，心情 +2（游戏）。", "info")
	if String(record["phase"]) == "dinner" and not combos_today.has("budget_saver"):
		var all_eaten := today_meal_records.size() >= 3
		for meal_record in today_meal_records:
			if bool(meal_record.get("skipped", false)) or int(meal_record.get("stat_delta", {}).get("satiety", 0)) < 20:
				all_eaten = false
		if all_eaten and MealResolverScript.total_spend(today_meal_records) <= 18:
			combos_today.append("budget_saver")
			state["stress"] = int(state["stress"]) - 2
			_post("三餐各补充至少 20 饱腹且合计不超过 ¥18，压力 -2（游戏）。", "good")


func _advance_from_meal() -> void:
	match phase:
		"breakfast": phase = "breakfast_action"
		"lunch": phase = "lunch_action"
		_: phase = "dinner_action"
	_render_phase()
	HouseholdPreparationPresenterScript.after_meal(self)


func _apply_action(action_id: String) -> void:
	if _record_book_active():
		return
	if not _is_action_phase():
		return
	if not _story_action_ids(phase).has(action_id):
		return
	var action := _effective_action(action_id)
	if not _can_use_action(action):
		var reason := _action_disabled_reason(action)
		if not reason.is_empty():
			_post(reason, "warning")
		return
	if action_id == "call_friend":
		_show_shared_meal_invitation()
		return
	if int(action.get("slots", 1)) > 0: HouseholdFinaleScript.capture(self, action_id)
	var display_key := "name_%s" % phase
	var display_name := String(action.get(display_key, action.get("name", action_id)))
	actions_used_today += int(action.get("slots", 1))
	if action_id == "perform":
		performed = true
	if action_id == "drink_water":
		drink_water_used += 1
	if int(action.get("slots", 1)) > 0:
		used_action_names.append(display_name)
	used_action_ids.append(action_id)
	state["balance"] = int(state["balance"]) - int(action.get("cost", 0))
	var delta := {
		"energy": int(action.get("energy", 0)),
		"mood": int(action.get("mood", 0)),
		"stress": int(action.get("stress", 0)),
		"study_progress": int(action.get("study", 0)),
		"satiety": int(action.get("satiety", 0)),
	}
	_apply_stat_delta(delta)
	var stock_added := _apply_action_stock(action)
	if action_id == "shop_ingredients":
		for ingredient in ["rice_plain", "egg", "tofu", "greens", "tomato", "millet"]:
			kitchen.ingredients[ingredient] = int(kitchen.ingredients.get(ingredient, 0)) + 2
			stock_added[ingredient] = 2
	if action_id == "shop_condiments":
		for key in {"salt_g": 20, "soy_ml": 60, "sugar_g": 20}:
			var amount: int = {"salt_g": 20, "soy_ml": 60, "sugar_g": 20}[key]
			kitchen.condiments[key] += amount
			stock_added[key] = amount
	today_action_records.append({
		"id": action_id,
		"name": display_name,
		"cost": int(action.get("cost", 0)),
		"slots": int(action.get("slots", 1)),
		"stat_delta": delta.duplicate(true),
		"stock_added": stock_added,
	})
	_clamp_stats()
	_update_stability()
	if stock_added.is_empty():
		_post(display_name, "info")
	else:
		_post(("小份食材已放好。" if _household() else "%s：燕麦、牛奶和苹果放进柜子了。" % display_name), "good")
	if int(action.get("slots", 1)) == 0:
		_render_phase()
	else:
		_advance_after_action()


func _skip_action() -> void:
	if _record_book_active():
		return
	if not _is_action_phase():
		return
	HouseholdFinaleScript.capture(self, "skip")
	_post("%s没有再排事情。" % String(PHASE_NAMES.get(phase, "餐后")), "info")
	_advance_after_action()


func _advance_after_action() -> void:
	if not _is_action_phase():
		return
	var period_delta := BalanceRules.period_delta()
	var period_record := {"phase": phase, "stat_delta": period_delta.duplicate(true)}
	if _household() and day == 7 and phase == "dinner_action" and not household_finale["outcome"].is_empty(): period_record["finale_context"] = household_finale["outcome"].duplicate(true)
	today_period_records.append(period_record)
	_apply_stat_delta(period_delta)
	_clamp_stats()
	_update_stability()
	match phase:
		"breakfast_action": phase = "lunch_source"
		"lunch_action": phase = "dinner_source"
		_: phase = "sleep"
	_render_phase()
	HouseholdFinalePresenterScript.after_action(self)


func _can_use_action(action: Dictionary) -> bool:
	if _household() and not _household_action_reason(action).is_empty():
		return false
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
	if _household() and not _household_action_reason(action).is_empty():
		return _household_action_reason(action)
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
	if _household():
		return _household_action(action_id)
	var base_action := _story_action(action_id)
	var action := WeeklyEventServiceScript.apply_action(
		day,
		action_id,
		base_action
	)
	if int(action.get("slots", 1)) > 0:
		action["rule_hint"] = String(action.get("rule_hint", "")) + "\n" + BalanceRules.PERIOD_HINT
	if action_id != "study":
		return action
	var carryover_modifier := int(_current_recovery_effect["study_modifier"])
	var live_penalty := BalanceRules.study_penalty(state)
	var live_modifier: int = live_penalty["modifier"]
	var live_reasons: Array[String] = live_penalty["reasons"]
	var total_modifier := carryover_modifier + live_modifier
	if total_modifier != 0:
		action["study"] = maxi(1, int(action.get("study", 0)) + total_modifier)
	var notes: Array[String] = []
	var carryover_text := "不变" if carryover_modifier == 0 else _signed_delta(carryover_modifier)
	notes.append("昨夜恢复：%s（每次复习 %s）" % [
		String(RecoveryPresenterScript.present(_recovery_display_record)["title"]),
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
		if amount <= 0 or _story_food(food_id).is_empty():
			continue
		dorm_inventory[food_id] = int(dorm_inventory.get(food_id, 0)) + amount
		added[food_id] = amount
	return added


func _choose_sleep(option_id: String) -> void:
	if _record_book_active():
		return
	if phase != "sleep" or _day_settled:
		return
	if not GameDataScript.get_sleep_option_ids_for_scene("sleep").has(option_id):
		return
	var option := _story_sleep(option_id)
	chosen_sleep_id = option_id
	chosen_sleep_name = String(option.get("name", option_id))
	_recovery_before_sleep = {"energy": state.get("energy"), "stress": state.get("stress")}
	_recovery_sleep_snapshot = {"id": option_id}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		# Freeze exactly the integer deltas used by this execution, not a later
		# lookup of the sleep card or its legacy burden field.
		_recovery_sleep_snapshot[key] = int(option.get(key, 0))
	_apply_stat_delta({
		"energy": _recovery_sleep_snapshot["energy"],
		"mood": _recovery_sleep_snapshot["mood"],
		"stress": _recovery_sleep_snapshot["stress"],
		"study_progress": _recovery_sleep_snapshot["study"],
		"satiety": _recovery_sleep_snapshot["satiety"],
	})
	_post("夜里：%s" % chosen_sleep_name, "info")
	_finish_day()


func _finish_day() -> void:
	if _day_settled:
		return
	_day_settled = true
	var nutrition_summary: Dictionary = NutritionLedgerScript.summarize(today_meal_records)
	if int(state["satiety"]) < 20:
		_apply_day_settlement_effect("low_satiety", {"energy": -8, "stress": 8, "mood": -5})
	if int(state["satiety"]) > 92:
		_apply_day_settlement_effect("high_satiety", {"energy": -3})
	var remaining_days := maxi(0, _total_days() - day)
	if remaining_days > 0 and int(state["balance"]) < remaining_days * 14:
		_apply_day_settlement_effect("tight_budget", {"stress": 5, "mood": -2})
	var study_pace := mini(
		_goal_target(),
		day * 10
	)
	if int(state[_goal_key()]) < study_pace:
		_apply_day_settlement_effect("study_behind", {"stress": 3})
	else:
		_apply_day_settlement_effect("study_on_pace", {"mood": 2})
	_clamp_stats()
	_settle_recovery_record()
	var stability_valid := _update_stability(pending_recovery_state)
	var next_learning := RecoveryGameplayServiceScript.learning_state(pending_recovery_state)
	pending_learning_state = next_learning["learning_state"]
	if stability_valid and int(state["stability"]) <= 15:
		low_stability_days += 1
	elif stability_valid:
		low_stability_days = 0
	var day_record := _build_day_record(nutrition_summary)
	if _household():
		shared_meal.finish_day(day)
		day_record["story_context"] = story_identity()
		day_record["kitchen_history"] = kitchen.history.filter(func(item: Dictionary) -> bool: return int(item.get("day", -1)) == day).duplicate(true)
		day_record["performed"] = performed
		day_record["recipe_summary"] = MealFactsScript.summarize(today_meal_records)
		day_record["shared_meal_history"] = shared_meal.history.filter(func(item: Dictionary) -> bool: return item.get("day") == day).duplicate(true)
		day_record["household_recap"] = HouseholdLearningScript.day_recap(kitchen, household_learning, day, _story_clock())
		day_record["learning_observation"] = HouseholdMealLearningScript.day_observation(today_meal_records, day)
		if day == 5: day_record["day_five_recap"] = HouseholdDayFiveScript.recap(today_meal_records, household_day_five, shared_meal.history)
		if day in [6, 7]: day_record["preparation_recap"] = HouseholdPreparationScript.recap(household_preparation)
	run_history.append(day_record)
	var detail_text := "%s\n\n本局变化\n%s" % [
		String(nutrition_summary.get("detail_text", "")),
		_day_change_text(day_record),
	]
	var recovery_view := RecoveryPresenterScript.present(pending_recovery_state, "final" if day >= _total_days() else "settled")
	var summary_detail := {"detail_text": detail_text + "\n\n恢复依据\n" + String(recovery_view["detail_text"]), "basis": String(nutrition_summary.get("basis", ""))}
	if _household():
		summary_detail["detail_text"] += "\n\n配方与共同进餐\n" + String(day_record["recipe_summary"]["text"]) + "\n" + shared_meal.summary()
	summary_payload = {
		"record_book_available": true,
		"day": day,
		"title": "第 %d 天，收工" % day,
		"stats": state.duplicate(true),
		"record_summary": String(nutrition_summary["observation"]),
		"meal_stamps": _build_meal_stamps(),
		"advice": "%s\n%s\n%s" % [
			String(nutrition_summary["action"]),
			_day_strategy_advice(study_pace, remaining_days),
			_next_day_preview_text(),
		],
		"nutrition": nutrition_summary,
		"recovery": recovery_view,
		"detail": summary_detail,
		"detail_button_text": "查看三餐与恢复依据",
		"detail_button_open_text": "收起三餐与恢复依据",
		"button_text": "睡到第 %d 天" % (day + 1),
	}
	if _household():
		summary_payload["record_summary"] = day_record["household_recap"]["text"]
		summary_payload["detail"]["detail_text"] += "\n\n厨房回顾\n" + String(day_record["household_recap"]["text"])
		if not day_record["learning_observation"].is_empty():
			var observation := String(day_record["learning_observation"]["text"]) + "\n" + String(day_record["learning_observation"]["next_step"])
			summary_payload["record_summary"] = observation + "\n\n" + String(summary_payload["record_summary"])
			summary_payload["detail"]["detail_text"] += "\n\n这一餐的观察\n" + observation
		if day == 5:
			summary_payload["record_summary"] = String(day_record["day_five_recap"]["text"]) + "\n\n" + String(summary_payload["record_summary"])
			summary_payload["detail"]["detail_text"] += "\n\n今天的做法与同桌\n" + String(day_record["day_five_recap"]["text"])
		if day in [6, 7]:
			summary_payload["record_summary"] = String(day_record["preparation_recap"]["text"]) + "\n\n" + String(summary_payload["record_summary"])
			summary_payload["detail"]["detail_text"] += "\n\n备餐计划与实际取用\n" + String(day_record["preparation_recap"]["text"])
	if not stability_valid or not next_learning["valid"]:
		phase = "summary"
		_render_phase()
		_post("恢复记录暂时不可用，请通过菜单重新开始这一周。", "warning")
	elif low_stability_days >= 2:
		_finish_run("collapsed")
	elif day >= _total_days():
		_finish_run(_select_story_ending())
	else:
		phase = "summary"
		_render_phase()


func _apply_day_settlement_effect(source_id: String, delta: Dictionary) -> void:
	_apply_stat_delta(delta)
	var recorded_delta := {}
	for key in RecoveryStateServiceScript.DELTA_KEYS:
		if delta.has(key) and state.has(key):
			recorded_delta[key] = delta[key]
	_day_settlement_effects.append({"source_id": source_id, "requested_delta": recorded_delta})


func _settle_recovery_record() -> void:
	var action_counts := {}
	for action in today_action_records:
		var action_id: Variant = action.get("id")
		if _household():
			if action_id == "call_friend":
				continue
			action_id = {"rehearse": "study", "group_rehearsal": "study", "perform": "allow_imperfection", "shop_ingredients": "allow_imperfection", "shop_condiments": "allow_imperfection"}.get(action_id, action_id)
		action_counts[action_id] = int(action_counts.get(action_id, 0)) + 1
	var result := RecoveryStateServiceScript.settle(
		day, _recovery_before_sleep, _recovery_sleep_snapshot,
		action_counts, _day_settlement_effects
	)
	if result["valid"] and result["recovery_state"]["end_of_day"] != {"energy": state.get("energy"), "stress": state.get("stress")}:
		result = {
			"valid": false, "errors": ["Recovery trace does not match settled gameplay state"],
			"recovery_state": RecoveryStateServiceScript.unavailable("invalid", "RECOVERY_TRACE_MISMATCH"),
		}
	pending_recovery_state = result["recovery_state"].duplicate(true)
	if not result["valid"]:
		recovery_diagnostics.append({"day": day, "code": "recovery_settlement_invalid", "errors": result["errors"].duplicate()})


func get_pending_recovery_state() -> Dictionary:
	return pending_recovery_state.duplicate(true)


func get_current_recovery_state() -> Dictionary:
	return current_recovery_state.duplicate(true)


func _record_recovery_error(code: String, errors: Array) -> void:
	for entry in recovery_diagnostics:
		if entry.get("day") == day and entry.get("code") == code:
			return
	recovery_diagnostics.append({"day": day, "code": code, "errors": errors.duplicate(true)})


func _on_summary_advanced() -> void:
	if _record_book_active():
		return
	if phase == "ending":
		start_new_run()
	elif phase == "summary":
		_next_day()


func _next_day() -> void:
	if _record_book_active():
		return
	if phase != "summary" or not _day_settled or day >= _total_days():
		return
	day += 1
	if not _start_day():
		day -= 1
		_post("恢复记录暂时不可用，请通过菜单重新开始这一周。", "warning")
		return
	_render_phase()
	_show_new_day_popup()


func _show_new_day_popup() -> void:
	if not is_node_ready():
		return
	_new_day_pending = true
	_update_toast_visibility()
	var display_event := current_event.duplicate(true)
	if display_event.is_empty():
		display_event = _quiet_day_event()
	var event_id := String(display_event.get("id", "quiet_day"))
	var display_learning_state := RecoveryPresenterScript.present(_recovery_display_record)
	var learning_id := String(RecoveryGameplayServiceScript.learning_state(_recovery_display_record)["learning_state"].get("id", "recovery_unavailable"))
	new_day_popup.show_day(_story_view({
		"day": day,
		"title": "第 %d 天开始" % day,
		"subtitle": (
			"用现有预算安排这一周的三餐、复习和休息，先从早餐开始。"
			if day == 1
			else "昨夜的恢复影响今天的复习节奏；今天的事件也会改变可用策略。"
		),
		"learning_state": display_learning_state,
		"recovery": display_learning_state,
		"status_effect": display_learning_state["effect_text"],
		"event": display_event,
		"status_image": String(story["portrait"]) if _household() else String(LEARNING_STATE_IMAGES.get(
			learning_id,
			LEARNING_STATE_IMAGES["steady"]
		)) if display_learning_state["available"] else "",
		"event_image": String(story["background"]) if _household() else String(EVENT_IMAGES.get(event_id, EVENT_IMAGES["quiet_day"])),
		"event_effect": String(display_event.get("effect_text", "")) if _household() else String(EVENT_EFFECT_TEXT.get(
			event_id,
			EVENT_EFFECT_TEXT["quiet_day"]
		)),
		"button_text": "进入第 %d 天" % day,
	}), _mobile_mode)


func _quiet_day_event() -> Dictionary:
	if day == 1:
		return {
			"id": "quiet_day",
			"title": "新的一周开始了",
			"summary": "今天没有额外限制，先按自己的节奏安排三餐与学习。",
		}
	if day >= _total_days():
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
	_new_day_pending = false
	_update_toast_visibility()
	_queue_autosave()
	if _household() and day == 1 and household_learning.get("opening_stage") in ["pending", "decision", "breakfast"]:
		new_day_popup.hide_popup(false)
		HouseholdLearningPresenterScript.resume(self)
	elif _household() and day == 5:
		new_day_popup.hide_popup(false)
		HouseholdDayFivePresenterScript.resume(self)
	elif _household() and day == 6:
		new_day_popup.hide_popup(false)
		HouseholdPreparationPresenterScript.resume(self)
	elif _household() and day == 7:
		new_day_popup.hide_popup(false)
		HouseholdFinalePresenterScript.resume(self)
	# The popup owns its closing animation; the playable stage is already
	# rendered underneath so continuing never incurs another scene rebuild.


func _update_toast_visibility() -> void:
	if phase in ["summary", "ending"]: toast_feed.clear_all(true)
	toast_anchor.visible = not _new_day_pending and phase not in ["summary", "ending"] and not (_household() and (_is_source_phase() or _is_meal_phase()))


func _show_recovery_detail() -> void:
	var view := RecoveryPresenterScript.present(_recovery_display_record)
	sticky_note.get_parent().move_to_front()
	new_day_popup.set_process_unhandled_key_input(false)
	new_day_popup.continue_button.disabled = true
	_show_detail({"id": "recovery_details", "name": "恢复依据", "kind": "游戏恢复", "recovery": view}, new_day_popup.paper_host.get_global_rect(), true, "state")


func _finish_run(result: String) -> void:
	ending_id = result
	phase = "ending"
	if _household(): household_finale["review"] = HouseholdFinaleScript.review(capture_game_save()["payload"])
	_render_phase()


func _show_ending_summary() -> void:
	var ending := _story_ending(ending_id)
	var recap := _build_week_recap()
	var ending_summary := {
		"day": day,
		"title": String(ending.get("title", "这一周结束了")),
		"stats": state.duplicate(true),
		"record_summary": RecoveryPresenterScript.ending_text(ending_id, run_history),
		"advice": "目标复习 %d，完成 %d；本周记录了 %d 天，手里还剩 ¥%d。" % [
			_goal_target(),
			int(state[_goal_key()]),
			int(recap.get("played_days", 0)),
			int(state["balance"]),
		],
		"ending_image": String(ending.get("image", "")),
		"layout": "ending",
		"record_book_available": true,
		"detail": recap,
		"detail_button_text": "查看本周轨迹",
		"detail_button_open_text": "收起本周轨迹",
		"button_text": "再来一周",
	}
	if _household():
		var review: Dictionary = household_finale["review"] if not household_finale["review"].is_empty() else HouseholdFinaleScript.review(capture_game_save()["payload"])
		ending_summary["ending_image"] = "res://assets/generated/stories/actions/zhou_perform-v1.png" if review["counts"]["performances"] > 0 else String(story["background"])
		if review["counts"]["performances"] > 0: ending_summary["title"] = "把歌唱完了"
		elif household_finale["outcome"].get("kind") == "other_choice": ending_summary["title"] = "这一周，按自己的安排"
		elif performed: ending_summary["title"] = "这一周，按实际记录回看"
		ending_summary["record_summary"] = review["outcome_text"] + "\n" + review["highlights"][0]["text"]
		ending_summary["advice"] = "排练 %d/%d｜实际参演：%s｜余额 ¥%d" % [int(state.get("goal_progress", 0)), _goal_target(), "已记录" if review["counts"]["performances"] > 0 else "未记录", int(state.get("balance", 0))]
		ending_summary["advice"] += "\n" + review["next_step"]
		ending_summary["detail"]["detail_text"] = "这一周真正留下的事\n" + HouseholdFinaleScript.review_text(review) + "\n\n逐日轨迹\n" + String(ending_summary["detail"]["detail_text"]) + "\n\n" + shared_meal.summary() + "\n" + _recipe_history_text()
	daily_summary.show_summary(_story_view(ending_summary), _mobile_mode)


func _build_day_record(nutrition_summary: Dictionary) -> Dictionary:
	var action_spend := 0
	for record in today_action_records:
		action_spend += int(record.get("cost", 0))
	return {
		"day": day,
		"event": current_event.duplicate(true),
		"learning_state": current_learning_state.duplicate(true),
		"next_learning_state": pending_learning_state.duplicate(true),
		"recovery_state": pending_recovery_state.duplicate(true),
		"start_state": _day_start_state.duplicate(true),
		"end_state": state.duplicate(true),
		"meals": today_meal_records.duplicate(true),
		"actions": today_action_records.duplicate(true),
		"periods": today_period_records.duplicate(true),
		"balance_version": BalanceRules.VERSION,
		"sleep": {"id": chosen_sleep_id, "name": chosen_sleep_name},
		"spend": MealResolverScript.total_spend(today_meal_records) + action_spend,
		"combos": combos_today.duplicate(),
		"nutrition": nutrition_summary.duplicate(true),
	}


func _build_meal_stamps() -> Array[Dictionary]:
	var stamps: Array[Dictionary] = []
	var book := get_meal_record_book()
	if not book.get("valid", false):
		return stamps
	for row in book["days"][day - 1]["rows"]:
		var status: String = row["status"]
		var text: String = row["text"]
		if status == "eaten":
			var names := text.split("、")
			text = "、".join(names.slice(0, 2)) + ("等" if names.size() > 2 else "")
			text = "%s · %s" % [row["source"], text]
		stamps.append({
			"title": PHASE_NAMES[row["phase"]],
			"text": "没有记录" if status == "unrecorded" else text,
			"state": "missing" if status == "unrecorded" else status,
		})
	return stamps


func _day_change_text(record: Dictionary) -> String:
	var start: Dictionary = record.get("start_state", {})
	var finish: Dictionary = record.get("end_state", {})
	return "今日变化：余力 %s｜复习 %s｜余额 %s" % [
		_signed_delta(int(finish.get("stability", 0)) - int(start.get("stability", 0))),
		_signed_delta(int(finish.get(_goal_key(), 0)) - int(start.get(_goal_key(), 0))),
		_signed_delta(int(finish.get("balance", 0)) - int(start.get("balance", 0))),
	]


func _day_strategy_advice(study_pace: int, remaining_days: int) -> String:
	if int(state.get("satiety", 0)) < 20:
		return "饱腹偏低，先留出一顿够吃的餐，再排其他事情。"
	var study_gap := study_pace - int(state.get(_goal_key(), 0))
	if study_gap > 0:
		return "今天离复习计划还差 %d。明天看看精力，再安排下一段。" % study_gap
	if int(state.get("energy", 0)) <= 25:
		return "复习进度跟上了，不过电量见底；明天先缓一缓再开书。"
	if remaining_days > 0 and int(state.get("balance", 0)) < remaining_days * 10:
		return "进度跟上了。余下 %d 天，存粮和食堂能帮钱包多撑一会儿。" % remaining_days
	return "复习进度跟上了，也给明天留出了调整空间。"


func _next_day_preview_text() -> String:
	var recovery_view := RecoveryPresenterScript.present(pending_recovery_state, "settled")
	if not recovery_view["available"]:
		return "恢复记录暂时不可用，请通过菜单重新开始这一周。"
	if day >= _total_days():
		return "本周已经走完，看看七天里哪些选择真正留下了余力。"
	var preview := _story_preview(day)
	return "明天的事件：" + String(preview.get("title", "照常安排"))


func _build_week_recap() -> Dictionary:
	var lines: Array[String] = ["本周轨迹："]
	var total_spend := 0
	var book := get_meal_record_book()
	if not book.get("valid", false):
		return {"detail_text": "本周选餐记录暂时不可用。", "basis": "只整理已确认的游戏内选择。", "played_days": 0}
	var records_by_day := {}
	for record in run_history:
		var record_day: Variant = record.get("day")
		if typeof(record_day) != TYPE_INT or record_day < 1 or record_day > day:
			continue
		if not records_by_day.has(record_day) or (not records_by_day[record_day].get("meals") is Array and record.get("meals") is Array):
			records_by_day[record_day] = record
	var recorded_days: Array = records_by_day.keys()
	recorded_days.sort()
	for record_day in recorded_days:
		var record: Dictionary = records_by_day[record_day]
		var meal_facts: Dictionary = book["days"][record_day - 1]
		var meal_count: String = ("%d/3" % meal_facts["eaten"]) if record.get("meals") is Array else "未记"
		var start: Dictionary = record.get("start_state", {})
		var finish: Dictionary = record.get("end_state", {})
		var recovery_view := RecoveryPresenterScript.present(record.get("recovery_state"), "final" if record_day >= _total_days() else "settled")
		total_spend += int(record.get("spend", 0))
		lines.append("第 %d 天｜进餐记录 %s｜复习 %s｜花费 ¥%d\n收工后：%s\n%s" % [
			int(record.get("day", 0)),
			meal_count,
			_signed_delta(int(finish.get(_goal_key(), 0)) - int(start.get(_goal_key(), 0))),
			int(record.get("spend", 0)),
			String(recovery_view["title"]),
			String(recovery_view["summary"]),
		])
		if record.get("household_recap") is Dictionary:
			lines.append(String(record["household_recap"].get("text", "")))
		if record.get("learning_observation") is Dictionary and not record["learning_observation"].is_empty():
			lines.append(String(record["learning_observation"]["text"]))
		if record.get("day_five_recap") is Dictionary: lines.append(String(record["day_five_recap"]["text"]))
	var played_days := recorded_days.size()
	if book.get("valid", false):
		for note in MealRecordPresenterScript.view(book, day, true)["notes"]:
			lines.append(String(note))
	lines.append("合计｜%d 天花费 ¥%d" % [
		played_days,
		total_spend,
	])
	return {
		"detail_text": "\n".join(lines),
		"basis": "本周轨迹只整理游戏内选择与次日游戏状态，不构成健康评分或医学判断。",
		"played_days": played_days,
	}


func _signed_delta(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _apply_stat_delta(delta: Dictionary) -> void:
	for raw_key in delta.keys():
		var key: String = _goal_key() if raw_key == "study_progress" else String(raw_key)
		if key in ["burden", "diet_burden", "character_health"]:
			continue
		if state.has(key):
			state[key] = int(state[key]) + int(delta[raw_key])


func _update_stability(recovery_record: Variant = null) -> bool:
	if today_meal_records.is_empty() and recovery_record == null:
		return true
	var record: Variant = current_recovery_state if recovery_record == null else recovery_record
	var result := RecoveryGameplayServiceScript.calculate_stability_from_recovery(
		StoryCatalogScript.resource_projection(state, story),
		day,
		_total_days(),
		record
	)
	if not result["valid"]:
		_record_recovery_error("recovery_stability_invalid", result["errors"])
		return false
	state["stability"] = result["stability"]
	return true


func _clamp_stats() -> void:
	for key in ["burden", "diet_burden", "character_health"]:
		state.erase(key)
	for key in ["stability", "energy", "mood", "satiety", "stress", _goal_key()]:
		state[key] = clampi(int(state[key]), 0, 100)
	state["balance"] = clampi(int(state["balance"]), 0, 999)


func _update_shell() -> void:
	day_label.text = "第 %d 天 / 第 %d 天" % [day, _total_days()]
	phase_label.text = String(PHASE_NAMES.get(phase, phase))
	balance_label.text = "¥%d" % int(state.get("balance", 0))
	if is_instance_valid(week_ribbon):
		week_ribbon.call("update_day", day, _total_days())


func _show_detail(payload: Dictionary, anchor_rect: Rect2, pinned: bool, mode: String) -> void:
	if _record_book_active():
		return
	if sticky_note.visible and sticky_note.pinned and not pinned:
		return
	if mode == "food":
		payload = FoodPreferenceServiceScript.decorate_food(payload, food_preferences)
	var reason := String(payload.get("disabled_reason", ""))
	var stock := -1
	if mode == "food" and _source_uses_stock():
		stock = _stock_count(String(payload.get("id", "")), current_source_id)
	payload = _story_view(payload)
	sticky_note.present(payload, mode, anchor_rect, pinned, reason, "", _mobile_mode, stock)


func _dismiss_detail(item_id: String) -> void:
	if sticky_note.pinned:
		return
	if sticky_note.is_showing_item(item_id):
		sticky_note.hide_note()


func _post(message: String, tone: String = "info") -> void:
	if is_instance_valid(toast_feed):
		toast_feed.push(message, tone)
		# Current errors remain visible; routine feedback from the preceding
		# meal is cleared when entering the summary or ending.
		if phase in ["summary", "ending"] and tone in ["warning", "danger", "error"] and not _record_book_active(): toast_anchor.show()


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
	if _household():
		return StoryCatalogScript.content(story, "sources").get(source_id, {})
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
	_save_to_slot("auto", true)


func _go_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _update_background() -> void:
	var target_path := _background_path_for_phase()
	if (target_path == _background_path and _background_mobile == _mobile_mode) or not ResourceLoader.exists(target_path):
		_update_time_grade()
		return
	_background_path = target_path
	_background_mobile = _mobile_mode
	if is_instance_valid(_background_tween):
		_background_tween.kill()
	var front := background_a if _background_a_is_front else background_b
	var back := background_b if _background_a_is_front else background_a
	back.texture = LocationsScript.texture_for(target_path, _mobile_mode) if _household() else load(target_path) as Texture2D
	front.modulate.a = 1.0
	back.modulate.a = 0.0
	_background_a_is_front = not _background_a_is_front
	_background_tween = create_tween().set_parallel(true)
	_background_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_background_tween.tween_property(front, "modulate:a", 0.0, 0.30)
	_background_tween.tween_property(back, "modulate:a", 1.0, 0.30)
	_update_time_grade()


func _background_path_for_phase() -> String:
	if _household():
		if is_instance_valid(_workspace) and _workspace.visible:
			if _workspace is KitchenStockStage: return LocationsScript.meal_background("home_fridge")
			if _workspace is CookingPlanStage: return LocationsScript.meal_background("home_kitchen", _mobile_mode)
		if _is_source_phase():
			if _market_is_open(): return LocationsScript.MARKET_PORTRAIT if _mobile_mode else LocationsScript.MARKET_WIDE
			return HouseholdSourceStage.PORTRAIT_SCENE if _mobile_mode else HouseholdSourceStage.WIDE_SCENE
		if _is_meal_phase() and LocationsScript.MEAL_BACKGROUNDS.has(current_source_id):
			return LocationsScript.meal_background(current_source_id, _mobile_mode)
		if performed and phase == "ending": return "res://assets/generated/stories/choir_stage.png"
		if phase in ["sleep", "summary", "ending"]: return HOUSEHOLD_HOME_NIGHT
		return String(story["background"])
	if _is_source_phase() and ResourceLoader.exists(SOURCE_MAP):
		if _mobile_mode and ResourceLoader.exists(SOURCE_MAP_MOBILE):
			return SOURCE_MAP_MOBILE
		return SOURCE_MAP
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
	var physical_size := get_window().size
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
		if is_instance_valid(_workspace):
			_workspace.apply_profile(_mobile_mode)
			if is_instance_valid(_active_stage): _apply_stage_profile(_active_stage)
			_update_background()
		else:
			call_deferred("_render_phase")


func _apply_shell_profile() -> void:
	var mobile := _mobile_mode
	week_ribbon.visible = not mobile
	for panel in [day_tag, phase_tag, balance_chip]:
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color("#e7d5b0f5")
		frame.border_color = Color("#9b784d")
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(10)
		frame.content_margin_left = 12
		frame.content_margin_right = 12
		frame.content_margin_top = 8
		frame.content_margin_bottom = 8
		frame.shadow_color = Color(0.12, 0.08, 0.03, 0.20)
		frame.shadow_size = 5
		frame.shadow_offset = Vector2(0, 3)
		if panel == phase_tag:
			frame.bg_color = Color("#d2d2abf5")
		panel.add_theme_stylebox_override("panel", frame)
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
	if stage is HouseholdMarketStage:
		(stage as HouseholdMarketStage).apply_entry_profile(_mobile_mode)
		return
	if stage is HouseholdSourceStage:
		(stage as HouseholdSourceStage).apply_entry_profile(_mobile_mode)
		return
	if stage is HouseholdWorktop:
		(stage as HouseholdWorktop).apply_profile(_mobile_mode)
		return
	if stage is MealStageBaseV2:
		(stage as MealStageBaseV2).apply_selection_layout(_mobile_mode)
		return
	if stage is MealSourceStageV2:
		(stage as MealSourceStageV2).apply_entry_profile(_mobile_mode)
		_set_rect(stage.get_node("Footer") as Control, 1, 1, 1, 1, -298 if _mobile_mode else -358, -90 if _mobile_mode else -72, -8 if _mobile_mode else -18, -30 if _mobile_mode else -12)
		for button_name in ["SkipButton", "MenuHintButton"]:
			var button := stage.get_node("Footer/" + button_name) as Button
			var width := (110 if _mobile_mode else 140) if button_name == "SkipButton" else (170 if _mobile_mode else 190)
			button.custom_minimum_size = Vector2(width, 60)
			button.add_theme_font_size_override("font_size", 18 if _mobile_mode else 20)
	if stage is ActionStageV2 or stage is SleepStageV2:
		var cards := MealStageBaseV2.MOBILE_CARD_AREA if _mobile_mode else MealStageBaseV2.DESKTOP_CARD_AREA
		var selection := MealStageBaseV2.MOBILE_SELECTED_AREA if _mobile_mode else MealStageBaseV2.DESKTOP_SELECTED_AREA
		var rail_path := "Layout/ActionRail" if stage is ActionStageV2 else "Layout/SleepRail"
		var note_path := "Layout/PlannerNote" if stage is ActionStageV2 else "Layout/AlarmNote"
		_set_rect(stage.get_node(rail_path) as Control, cards.position.x, cards.position.y, cards.end.x, cards.end.y, 0, 0, 0, 0)
		_set_rect(stage.get_node(note_path) as Control, selection.position.x, selection.position.y, selection.end.x, selection.end.y, 0, 0, 0, 0)
		if stage is ActionStageV2:
			_set_rect(stage.get_node("Layout/SkipButton") as Control, 1, 1, 1, 1, -178 if _mobile_mode else -208, -90 if _mobile_mode else -72, -8 if _mobile_mode else -18, -30 if _mobile_mode else -12)
			(stage.get_node("Layout/SkipButton") as Button).custom_minimum_size.x = 170 if _mobile_mode else 190
	if not _mobile_mode:
		return
	if stage is MealSourceStageV2:
		_mobile_source_layout(stage)
	elif stage is ActionStageV2:
		_mobile_action_layout(stage)
	elif stage is SleepStageV2:
		_mobile_sleep_layout(stage)


func _mobile_source_layout(stage: Control) -> void:
	_set_rect(stage.get_node("PromptTag") as Control, 0.5, 0.0, 0.5, 0.0, -270, 8, 270, 88)
	var positions := {
		"CafeteriaProp": Vector2(0.25, 0.22),
		"ConvenienceProp": Vector2(0.75, 0.33),
		"DormProp": Vector2(0.79, 0.62),
	}
	for prop_name in positions:
		var prop := stage.get_node("PropLayer/%s" % prop_name) as Control
		var point: Vector2 = positions[prop_name]
		_set_rect(prop, point.x, point.y, point.x, point.y, -94, -88, 94, 110)
		(prop.get_node("Name") as Label).add_theme_font_size_override("font_size", 26)
	var takeout := stage.get_node("PropLayer/TakeoutProp") as Control
	# Keep the personal phone beside the student and above the action row.
	_set_rect(takeout, 0.5, 1.0, 0.5, 1.0, -122, -512, 42, -118)




func _mobile_action_layout(stage: Control) -> void:
	_set_rect(stage.get_node("Layout/Header") as Control, 0.5, 0, 0.5, 0, -330, 6, 330, 74)
	stage.get_node("Layout/Header/TimeTag").custom_minimum_size = Vector2(120, 64)
	stage.get_node("Layout/Header/PromptTag").custom_minimum_size = Vector2(300, 64)
	stage.get_node("Layout/Header/SlotsTag").custom_minimum_size = Vector2(120, 64)
	for slot in stage.get_node("Layout/PlannerNote/PlannerMargin/Planner/UsedSlots").get_children():
		(slot as Control).custom_minimum_size = Vector2(76, 110)


func _mobile_sleep_layout(stage: Control) -> void:
	_set_rect(stage.get_node("Layout/PromptTag") as Control, 0.5, 0, 0.5, 0, -320, 8, 320, 90)
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


func _household() -> bool:
	return story.get("mechanics", "campus") == "household"


func _goal_key() -> String:
	return "goal_progress" if _household() else "study_progress"


func _goal_target() -> int:
	return int(story.get("goal_target", GameDataScript.STUDY_TARGET))


func _total_days() -> int:
	return int(story.get("days", 7))


func story_identity() -> Dictionary:
	return {"story_id": story_id, "story_version": story.get("version", 1), "character_id": story.get("character_id", "campus_student"), "character_version": story.get("character_version", 1)}


func _story_clock() -> int:
	return day * 24 + int({"breakfast": 8, "lunch": 13, "dinner": 18}.get(_current_meal_phase(), 18))


func _story_food_catalog() -> Dictionary:
	return StoryCatalogScript.content(story, "foods")


func _story_food(id: String) -> Dictionary:
	return _story_food_catalog().get(id, {}).duplicate(true) if _household() else GameDataScript.get_food(id)


func _story_source_ids() -> Array[String]:
	if not _household():
		return GameDataScript.get_meal_source_ids()
	var result: Array[String] = []
	for id in StoryCatalogScript.content(story, "sources"):
		result.append(String(id))
	return result


func _story_source_available(id: String, meal: String) -> bool:
	if not _household():
		return GameDataScript.is_meal_source_available(id, meal)
	var source: Dictionary = StoryCatalogScript.content(story, "sources").get(id, {})
	return not source.is_empty() and source.get("scenes", []).has(meal)


func _story_food_ids(source: String, meal: String) -> Array[String]:
	if not _household():
		return GameDataScript.get_food_ids_for_context(source, meal)
	var result: Array[String] = []
	for food in _story_food_catalog().values():
		if food.get("sources", []).has(source) and food.get("scenes", []).has(meal):
			result.append(String(food["id"]))
	return result


func _story_action_ids(action_phase: String) -> Array[String]:
	if not _household():
		return GameDataScript.get_action_ids_for_scene(action_phase)
	var result: Array[String] = []
	for action in StoryCatalogScript.content(story, "actions").values():
		if action.get("scenes", []).has(action_phase):
			result.append(String(action["id"]))
	return result


func _story_action(id: String) -> Dictionary:
	return StoryCatalogScript.content(story, "actions").get(id, {}).duplicate(true) if _household() else GameDataScript.get_action(id)


func _story_sleep(id: String) -> Dictionary:
	var option := GameDataScript.get_sleep_option(id)
	if _household():
		option["image"] = String(HOUSEHOLD_SLEEP_ART.get(id, option.get("image", "")))
		option["goal_label"] = "排练"
		if id == "night_study":
			option["name"] = "再看一遍歌谱"
			option["desc"] = "把没记牢的词再过一遍。"
		option = _story_view(option)
	return option


func _story_event(event_day: int) -> Dictionary:
	if not _household():
		return WeeklyEventServiceScript.event_for_day(event_day)
	var lesson := StoryEducationScript.lesson(event_day)
	return {"id": "choir_day_%d" % event_day, "day": event_day, "title": lesson.get("title", "照常安排"), "summary": lesson.get("line", ""), "preview": lesson.get("line", ""), "effect_text": "周三、周五午后集体排练；周日晚饭后汇演。"}


func _story_preview(current_day: int) -> Dictionary:
	if not _household():
		return WeeklyEventServiceScript.next_day_preview(current_day, _total_days())
	return {} if current_day >= _total_days() else _story_event(current_day + 1)


func _hud_stats() -> Dictionary:
	var result := StoryCatalogScript.resource_projection(state, story)
	if _household():
		result["goal_label"] = "排练"
	return result


func _story_view(value: Variant) -> Variant:
	if not _household():
		return value
	if value is String:
		return String(value).replace("复习", "排练").replace("学习", "练歌").replace("宿舍", "家里").replace("开书", "练歌")
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _story_view(value[key])
		if result.has("goal_progress"):
			result["study_progress"] = result["goal_progress"]
			result["study_target"] = _goal_target()
		result["goal_label"] = "排练"
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_story_view(item))
		return result
	return value


func _stock_count(food_id: String, source_id: String) -> int:
	if not _household():
		return int(dorm_inventory.get(food_id, 0))
	if source_id == "home_kitchen":
		var required := kitchen.needs([food_id], _story_food_catalog())
		var count := 999
		for id in required:
			count = mini(count, int(int(kitchen.ingredients.get(id, 0)) / int(required[id])))
		return int(count / _served_portions())
	if source_id == "home_fridge":
		return kitchen.available(food_id, day, _story_clock())
	return 0


func _visible_stock(source_id: String = "") -> Dictionary:
	if not _household():
		return dorm_inventory.duplicate(true)
	var result := {}
	for food_id in _story_food_catalog():
		result[food_id] = _stock_count(String(food_id), source_id if not source_id.is_empty() else current_source_id)
	return result


func _household_action_reason(action: Dictionary) -> String:
	var id := String(action.get("id", ""))
	if id == "call_friend":
		if day not in [4, 5, 6] or phase != "lunch_action":
			return "第4至6天午饭后可以约当日晚饭。"
		if not shared_meal.plan.is_empty():
			return "晚饭已经约好，或本周已经一起吃过饭。"
		if used_action_ids.has(id):
			return "今天已经打过电话了。"
	if id == "shop_condiments" and used_action_ids.has(id):
		return "今天已经补过一次调味料。"
	if id == "rehearse" and used_action_ids.count(id) >= 2:
		return "今天已经自己练过两段。"
	if id == "group_rehearsal":
		if day not in [3, 5] or phase != "lunch_action":
			return "周三、周五午饭后有集体排练。"
		if used_action_ids.has(id):
			return "今天的集体排练已经参加过了。"
	if id == "perform":
		if day != 7 or phase != "dinner_action":
			return "周日晚饭后才轮到我们上台。"
		if performed:
			return "汇演已经完成。"
		if int(state.get("goal_progress", 0)) < _goal_target():
			return "排练还未达到%d。" % _goal_target()
	return ""


func _household_action(id: String) -> Dictionary:
	var action := _story_action(id)
	action["goal_label"] = "排练"
	if id == "rehearse":
		action["study"] = 4 if used_action_ids.count(id) == 1 else 8
	if id in ["rehearse", "group_rehearsal"]:
		var penalty: Dictionary = BalanceRules.study_penalty(state)
		action["study"] = maxi(1, int(action["study"]) + int(_current_recovery_effect.get("study_modifier", 0)) + int(penalty["modifier"]))
		action["rule_hint"] = String(action.get("rule_hint", "")) + "\n本次排练收益已计入昨夜恢复与当前状态。"
	if int(action.get("slots", 1)) > 0:
		action["rule_hint"] = String(action.get("rule_hint", "")) + "\n" + BalanceRules.PERIOD_HINT
	return action


func _household_action_note() -> String:
	if performed: return "汇演已完成，今晚回家好好休息。"
	if day == _total_days():
		var concert := _story_action("perform")
		var minimum := int(concert.get("min_energy", 0))
		if phase == "dinner_action":
			var missing: Array[String] = []
			var rehearsal_gap := maxi(0, _goal_target() - int(state.get("goal_progress", 0)))
			var energy_gap := maxi(0, minimum - int(state.get("energy", 0)))
			if rehearsal_gap > 0: missing.append("排练%d" % rehearsal_gap)
			if energy_gap > 0: missing.append("精力%d" % energy_gap)
			if not missing.is_empty(): return "今晚汇演 · 还差" + "、".join(missing)
			var reason := _action_disabled_reason(concert)
			return "今晚汇演 · " + reason if not reason.is_empty() else "准备好了 · 选择“去参加汇演”上台。"
		return "今晚汇演 · 排练达到%d，演前保留%d精力。" % [_goal_target(), minimum]
	if shared_meal.plan.get("status") == "planned" and phase == "lunch_action": return shared_meal.summary()
	if day == 5 and phase == "lunch_action" and _household_action_reason(_story_action("call_friend")).is_empty():
		return "今天午后合练 · 可先问老陈的晚饭安排，约饭不占整段时间。"
	if day in [3, 5] and phase == "lunch_action":
		var reason := _action_disabled_reason(_story_action("group_rehearsal"))
		return "今天午后合练 · " + reason if not reason.is_empty() else "今天午后有集体排练，可以和大家合一遍。"
	if day in [4, 5, 6] and phase == "lunch_action" and _household_action_reason(_story_action("call_friend")).is_empty():
		return "午后可以约老陈，晚上在家或食堂一起吃。"
	return "周三、周五午后合练 · 周日晚饭后汇演。"


func _household_night_note() -> String:
	if day >= _total_days():
		return "这一周唱完了，今晚回家歇一歇。" if performed else "本周最后一晚，收好歌谱再回看这一周。"
	var tomorrow := day + 1
	if tomorrow == _total_days():
		return "明晚社区汇演 · 排练%d，演前保留%d精力。" % [_goal_target(), int(_story_action("perform").get("min_energy", 0))]
	if tomorrow in [3, 5]: return "明天午饭后，和大家一起集体排练。"
	return "明天照常安排，吃好饭再留一段练歌时间。"


func _select_story_ending() -> String:
	if not _household():
		return MealResolverScript.select_ending(state, true)
	if int(state.get("stability", 0)) <= 15:
		return "collapsed"
	return "stable_endurance" if performed else "study_shortfall"


func _story_ending(id: String) -> Dictionary:
	var ending := GameDataScript.get_ending(id)
	if _household():
		ending["image"] = String(story["background"])
		ending["title"] = "把歌唱完了" if performed else ("先歇一会儿" if id == "collapsed" else "这次没赶上舞台")
		ending["subtitle"] = "这周的排练和生活都留在记录里。"
	return ending


func _show_story_dialog(title: String, body: String, choices: Array, handler: Callable) -> void:
	if not is_node_ready():
		return
	_close_workspace(false)
	if not is_instance_valid(_story_dialog):
		_story_dialog = StoryDialogScript.new()
		_story_dialog.name = "StoryDialog"
		$HUD/HUDRoot/ModalLayer.add_child(_story_dialog)
		_story_dialog.visibility_changed.connect(func() -> void:
			if not _story_dialog.visible: _restore_story_dialog_input()
		)
		_story_dialog.chosen.connect(func(choice: String) -> void:
			var callback := _story_choice_handler
			_story_choice_handler = Callable()
			if callback.is_valid():
				callback.call(choice)
		)
	_story_choice_handler = handler
	_suspend_story_input()
	_story_dialog.present(title, body, choices)


func _restore_story_dialog_input() -> void:
	if is_instance_valid(_workspace) and _workspace.visible: return
	if _story_input_restore.is_empty(): return
	daily_summary.set_process_unhandled_key_input(_story_input_restore["summary_keys"])
	daily_summary.next_button.disabled = _story_input_restore["summary_button"]
	new_day_popup.set_process_unhandled_key_input(_story_input_restore["new_day_keys"])
	new_day_popup.continue_button.disabled = _story_input_restore["new_day_button"]
	_story_input_restore.clear()




func _suspend_story_input() -> void:
	if _story_input_restore.is_empty():
		_story_input_restore = {"summary_keys": daily_summary.is_processing_unhandled_key_input(), "summary_button": daily_summary.next_button.disabled, "new_day_keys": new_day_popup.is_processing_unhandled_key_input(), "new_day_button": new_day_popup.continue_button.disabled}
	new_day_popup.set_process_unhandled_key_input(false)
	new_day_popup.continue_button.disabled = true
	daily_summary.set_process_unhandled_key_input(false)
	daily_summary.next_button.disabled = true


func _present_workspace(page: HouseholdWorktop, close_handler: Callable = Callable()) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	var stage_focus := _active_stage.get_path_to(owner) if is_instance_valid(_active_stage) and owner != null and _active_stage.is_ancestor_of(owner) else NodePath()
	_close_workspace(false)
	if is_instance_valid(_story_dialog): _story_dialog.hide()
	sticky_note.hide_note()
	_workspace_restore = {"new_day": new_day_popup.visible and _new_day_pending, "summary": daily_summary.visible, "toasts": toast_anchor.visible, "focus": weakref(owner) if owner != null else null, "stage_focus": stage_focus, "focus_name": String(owner.name) if owner != null else ""}
	new_day_popup.hide()
	daily_summary.hide()
	toast_anchor.hide()
	if is_instance_valid(_active_stage): _active_stage.hide()
	_workspace = page
	page.modal_input_enabled = true
	stage_host.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.apply_profile(_mobile_mode)
	page.close_requested.connect(func() -> void:
		if page == _workspace and page.visible:
			if close_handler.is_valid(): close_handler.call()
			else: _close_workspace()
	)
	_suspend_story_input()
	_update_background()
	page.close_button.call_deferred("grab_focus")


func _close_workspace(refresh: bool = true) -> void:
	if not is_instance_valid(_workspace): return
	var return_focus: WeakRef = _workspace_restore.get("focus")
	var stage_focus: NodePath = _workspace_restore.get("stage_focus", NodePath())
	var focus_name: String = _workspace_restore.get("focus_name", "")
	_workspace.modal_input_enabled = false
	_workspace.hide()
	_workspace.set_block_signals(true)
	_workspace.queue_free()
	_workspace = null
	if is_instance_valid(_active_stage) and not _active_stage.is_queued_for_deletion(): _active_stage.show()
	new_day_popup.visible = bool(_workspace_restore.get("new_day", false))
	daily_summary.visible = bool(_workspace_restore.get("summary", false))
	toast_anchor.visible = bool(_workspace_restore.get("toasts", false))
	_workspace_restore.clear()
	_restore_story_dialog_input()
	_update_background()
	if refresh:
		_render_phase()
		var owner := return_focus.get_ref() as Control if return_focus != null else null
		if not stage_focus.is_empty() and is_instance_valid(_active_stage):
			owner = _active_stage.get_node_or_null(stage_focus) as Control
			# Generated container names change when the stage is rebuilt. Only
			# reuse a named control when it identifies one unambiguous target.
			if owner == null and not focus_name.is_empty():
				var matches := _active_stage.find_children(focus_name, "Control", true, false)
				if matches.size() == 1: owner = matches[0] as Control
		if not is_instance_valid(owner) or not owner.is_visible_in_tree() or owner.is_queued_for_deletion() or (owner is BaseButton and (owner as BaseButton).disabled):
			owner = daily_summary.next_button if daily_summary.visible else (new_day_popup.continue_button if new_day_popup.visible else menu_button)
		owner.grab_focus()


func _household_batch_notes() -> Dictionary:
	var notes := {}
	if not _household(): return notes
	for batch in kitchen.batches:
		if int(batch.get("quantity", 0)) > 0 and batch.get("status") == "needs_reheat":
			notes[batch["food_id"]] = "第%d天备好 · 连续冷藏 · 再热一次" % int(batch["day"])
	return notes


func _show_education() -> void:
	var lesson := StoryEducationScript.lesson(day)
	_lesson_seen[day] = true
	_queue_autosave()
	if _household() and day == 5 and HouseholdDayFivePresenterScript.open_guide(self, selected_food_ids): return
	if _household() and day == 6 and HouseholdPreparationPresenterScript.open_planner(self, selected_food_ids): return
	if _household() and day == 7 and HouseholdFinalePresenterScript.open_plan(self): return
	if _household() and day in HouseholdMealLearningScript.DAYS:
		if HouseholdStudyPresenterScript.open_reference(self): return
		_show_story_dialog(String(lesson["title"]), String(lesson["body"]) + "\n\n选好食物后，可从菜单的‘看看这一餐’入口练习；做饭时也可对照本次配方。", [{"id": "close", "text": "回到这一餐"}], func(_id: String) -> void: pass)
		return
	var exercise := StoryEducationScript.exercise(day)
	if not exercise.is_empty():
		var choices: Array = exercise["choices"].duplicate(true)
		choices.append({"id": "skip", "text": "直接查看依据"})
		_show_story_dialog(String(lesson["title"]), "教学情境，标签为给定数据：\n\n" + String(exercise["question"]) + "\n\n查看或作答不会改变预算、精力和目标进度。", choices, func(choice: String) -> void:
			var feedback := "" if choice == "skip" else ("这次判断正确。\n" if choice == exercise["correct"] else "再看看份量和记录口径。\n")
			_show_story_dialog(String(lesson["title"]), feedback + String(exercise["explanation"]) + "\n\n" + String(lesson["body"]), [{"id": "close", "text": "回到这一餐"}], func(_id: String) -> void: pass)
		)
		return
	_show_story_dialog(String(lesson["title"]), String(lesson["body"]), [{"id": "close", "text": "回到这一餐"}], func(_choice: String) -> void: pass)


func _show_outing_choices() -> void:
	if not _household() or not _is_source_phase() or _record_book_active(): return
	_household_market_context = "%d:%s" % [day, _current_meal_phase()]
	_render_phase()
	if _active_stage is HouseholdMarketStage:
		(_active_stage as HouseholdMarketStage).back_button.grab_focus()


func _market_is_open() -> bool:
	return _household() and _is_source_phase() and _household_market_context == "%d:%s" % [day, _current_meal_phase()]


func _return_from_market() -> void:
	if not _market_is_open() or _record_book_active(): return
	_household_market_context = ""
	_render_phase()
	if _active_stage is HouseholdSourceStage:
		(_active_stage.find_child("go_out", true, false) as Button).grab_focus()


func _show_source_notebook() -> void:
	if not _household() or _record_book_active(): return
	var choices := [{"id": "kitchen", "text": "冰箱与存粮"}, {"id": "recipe", "text": "配方记录"}, {"id": "education", "text": "科普参考"}, {"id": "close", "text": "回到这一餐"}]
	_show_story_dialog("随身记事本", shared_meal.summary() if shared_meal.plan.get("status") == "planned" else "", choices, func(choice: String) -> void:
		match choice:
			"kitchen": _show_kitchen()
			"recipe": _show_recipe_records()
			"education": _show_education()
	)


func _show_kitchen() -> void:
	if not _household() or not is_node_ready(): return
	kitchen.refresh(day, _story_clock())
	var page := KitchenStageScript.new()
	_present_workspace(page)
	page.setup(kitchen, _story_food_catalog(), day)
	page.discard_requested.connect(func(batch_id: String) -> void:
		if page != _workspace or not page.visible: return
		if kitchen.discard(batch_id, day):
			source_hands.clear()
			_queue_autosave()
			page.refresh()
	)


func _show_cooking_choice(ids: Array[String], storage: String = "eat_now", selected_plan: Dictionary = {}) -> void:
	if not is_node_ready(): return
	var expected := "%d:%s:%s" % [day, phase, current_source_id]
	var page := CookingPlanScript.new()
	_present_workspace(page)
	var source_effort := {
		"cook": maxi(0, -int(_effective_meal_source("home_kitchen").get("energy", 0))),
		"reheat": maxi(0, -int(_effective_meal_source("home_fridge").get("energy", 0))),
		"can_use_later": day < _total_days() or phase != "dinner",
	}
	page.setup(ids, _story_food_catalog(), kitchen, _served_portions(), String(PHASE_NAMES[phase]), storage, selected_plan, source_effort)
	page.configure_learning(day)
	page.study_requested.connect(func(food_ids: Array, keep: String, recipe: Dictionary) -> void:
		if page != _workspace or not page.visible or expected != "%d:%s:%s" % [day, phase, current_source_id]: return
		if day == 5: HouseholdDayFivePresenterScript.open_guide(self, food_ids, keep, recipe)
		elif day == 6: HouseholdPreparationPresenterScript.open_planner(self, food_ids, keep, recipe)
		elif day == 7: HouseholdFinalePresenterScript.open_plan(self, food_ids, keep, recipe)
		else: HouseholdStudyPresenterScript.open_cooking(self, food_ids, keep, recipe)
	)
	page.confirm_requested.connect(func(food_ids: Array, keep: String, recipe: Dictionary) -> void:
		if page != _workspace or not page.visible or expected != "%d:%s:%s" % [day, phase, current_source_id]: return
		_close_workspace(false)
		if not confirm_household_food(food_ids, keep, recipe): _render_phase()
	)


func confirm_household_food(ids: Array, storage: String = "eat_now", plan: Dictionary = {}) -> bool:
	if not _household() or _record_book_active() or not _is_meal_phase() or ids.is_empty():
		return false
	if not _story_source_available(current_source_id, phase):
		return false
	var unique := {}
	var foods: Array[Dictionary] = []
	for id in ids:
		if not hand.has(id) or unique.has(id) or foods.size() >= _source_selection_limit(current_source_id):
			return false
		unique[id] = true
		foods.append(_story_food(String(id)))
	var source := _effective_meal_source(current_source_id)
	var record := MealResolverScript.build_record(phase, source, foods, food_preferences)
	if int(record["total_cost"]) > int(state["balance"]):
		return false
	var transaction := {"ok": true}
	if current_source_id == "home_kitchen":
		transaction = kitchen.cook(ids, _story_food_catalog(), day, storage, _story_clock(), plan, _served_portions())
	elif current_source_id == "home_fridge":
		transaction = kitchen.consume(ids, day, _story_clock())
	if not transaction.get("ok", false):
		_post("食材或合规熟食不够，先换一份。", "warning")
		return false
	record["story_context"] = story_identity()
	record["kitchen_transaction"] = transaction.get("record", {}).duplicate(true)
	record["goal_label"] = "排练"
	if current_source_id == "home_kitchen":
		record["recipe_facts"] = transaction["record"]["recipe_facts"].duplicate(true)
	elif current_source_id == "home_fridge":
		var frozen_facts := MealFactsScript.from_batches(transaction["record"]["batches"])
		if not frozen_facts.is_empty():
			record["recipe_facts"] = frozen_facts
	var shared_completed := shared_meal.complete(day, record)
	if day in HouseholdMealLearningScript.DAYS:
		record["learning_facts"] = HouseholdMealLearningScript.context(day, phase, current_source_id, ids, _story_food_catalog(), "confirmed", record.get("recipe_facts", {}))
	if day == 5: record["day_five_experience"] = HouseholdDayFiveScript.freeze(record, _story_food_catalog())
	_apply_meal_record(record)
	_post("和老陈一起吃了晚饭：%s" % "、".join(record["food_names"]) if shared_completed else "%s：%s" % [PHASE_NAMES[phase], "、".join(record["food_names"])], "meal")
	selected_food_ids.clear()
	hand.clear()
	current_source_id = ""
	_advance_from_meal()
	if day == 5: HouseholdDayFivePresenterScript.after_meal(self, record)
	return true


func _served_portions() -> int:
	return 2 if shared_meal.matches(day, phase, current_source_id) and current_source_id == "home_kitchen" else 1


func _ingredient_name(id: String) -> String:
	return String({"rice_plain": "米", "egg": "蛋", "tofu": "豆腐", "greens": "青菜", "tomato": "番茄", "oatmeal": "燕麦", "millet": "小米", "apple": "苹果", "fish": "鱼"}.get(id, id))


func plan_shared_meal(venue: String) -> bool:
	if not _household() or _record_book_active() or phase != "lunch_action" or used_action_ids.has("call_friend"):
		return false
	if not shared_meal.invite(day, venue):
		return false
	used_action_ids.append("call_friend")
	today_action_records.append({"id": "call_friend", "name": "约老陈一起吃晚饭", "cost": 0, "slots": 0, "stat_delta": {}, "stock_added": {}, "plan": shared_meal.plan.duplicate(true)})
	_post("晚饭约好了，别忘了准备。", "info")
	_render_phase()
	if day == 5: HouseholdDayFivePresenterScript.after_invitation(self)
	return true


func _show_shared_meal_invitation() -> void:
	var expected_day := day
	var expected_phase := phase
	var page := WorktopScript.new()
	var close_handler := Callable()
	if day == 5:
		close_handler = func() -> void:
			if page != _workspace or not page.visible: return
			household_day_five["invite_declined"] = true
			_queue_autosave()
			_close_workspace()
	_present_workspace(page, close_handler)
	page.title_label.text = "老陈，晚上一起吃？"
	page.subtitle_label.text = "先问问他有没有空，再定个地点。"
	page.close_button.text = "这次先不约"
	if day == 5:
		page.close_button.text = "今天先自己安排"
		page.body.add_child(HouseholdUI.label("周阿姨：‘练完想和老陈吃个小份，先问问有没有空。’", 23))
	HouseholdUI.note(page.body, "约好还不算完成，实际同桌才写进这一周。")
	for choice in [{"id": "community", "text": "在家常小馆见", "hint": "各付自己的饭钱，照常搭配自己的餐盘。"}, {"id": "home", "text": "请老陈来家里", "hint": "当餐按两人份备料，只记录自己吃的一份。"}]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", HouseholdUI.paper(HouseholdUI.TILE, 18, 12))
		page.body.add_child(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 14)
		card.add_child(stack)
		stack.add_child(HouseholdUI.label(String(choice["text"]), 29, HouseholdUI.INK, true))
		stack.add_child(HouseholdUI.label(String(choice["hint"]), 23, HouseholdUI.MUTED))
		var button := HouseholdUI.button("就约在这里", String(choice["id"]), true)
		stack.add_child(button)
		button.pressed.connect(func() -> void:
			if page != _workspace or not page.visible or day != expected_day or phase != expected_phase: return
			_close_workspace(false)
			plan_shared_meal(String(choice["id"]))
		)


func _recipe_history_text() -> String:
	var lines: Array[String] = []
	for day_record in run_history:
		if day_record.has("recipe_summary"):
			lines.append("第%d天：%s" % [int(day_record["day"]), String(day_record["recipe_summary"]["text"])])
	for meal in today_meal_records:
		if meal.has("recipe_facts"):
			lines.append("%s：%s\n%s" % [PHASE_NAMES.get(meal.get("phase"), "这一餐"), "、".join(meal.get("food_names", [])), MealFactsScript.describe(meal["recipe_facts"])])
	return "\n\n".join(lines) if not lines.is_empty() else "还没有已确认的配方记录。"


func _show_recipe_records() -> void:
	if not _household() or not is_node_ready(): return
	var page := WorktopScript.new()
	_present_workspace(page)
	page.title_label.text = "这一周的餐桌"
	page.subtitle_label.text = "只记录已经确认的饭和实际发生的安排"
	HouseholdUI.section(page.body, "今天的配方")
	if today_meal_records.is_empty(): HouseholdUI.note(page.body, "今天还没有确认的餐次。先为自己安排一顿饭。")
	for meal in today_meal_records:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", HouseholdUI.paper(HouseholdUI.TILE, 14, 12))
		page.body.add_child(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 10)
		card.add_child(stack)
		stack.add_child(HouseholdUI.label("%s · %s" % [PHASE_NAMES.get(meal.get("phase"), "这一餐"), "、".join(meal.get("food_names", []))], 27, HouseholdUI.INK, true))
		stack.add_child(HouseholdUI.label(MealFactsScript.describe(meal["recipe_facts"]) if meal.has("recipe_facts") else "这顿饭没有配方调味记录，数值保持未知。", 22, HouseholdUI.MUTED))
		if meal.has("day_five_experience"):
			stack.add_child(HouseholdUI.label(String(meal["day_five_experience"]["response"]), 22, HouseholdUI.GREEN))
	HouseholdUI.section(page.body, "一起吃饭")
	HouseholdUI.note(page.body, shared_meal.summary())
	if not household_preparation.get("plans", []).is_empty():
		HouseholdUI.section(page.body, "备餐计划的后续")
		HouseholdUI.note(page.body, HouseholdPreparationScript.recap(household_preparation)["text"])
	if not run_history.is_empty():
		HouseholdUI.section(page.body, "前几天")
		for record in run_history:
			if record.has("recipe_summary"):
				HouseholdUI.note(page.body, "第%d天\n%s" % [int(record["day"]), String(record["recipe_summary"]["text"])])
			if record.has("day_five_recap"): HouseholdUI.note(page.body, String(record["day_five_recap"]["text"]))
			if record.has("preparation_recap"): HouseholdUI.note(page.body, String(record["preparation_recap"]["text"]))
	HouseholdUI.note(page.body, "配方数值是本关给定规格，未经测定的食材本底保持未知。")


func capture_game_save() -> Dictionary:
	return SaveCodecScript.capture(self)


func restore_game_save(envelope: Dictionary) -> Dictionary:
	var checked := SaveCodecScript.validate(SaveCodecScript.normalize(envelope))
	if not checked["ok"]:
		return checked
	var saved: Dictionary = checked["save"]
	var p: Dictionary = saved["payload"]
	var archive := MealHealthArchiveScript.new()
	var archive_result := archive.load_data(p["health_archive"])
	if not archive_result["ok"]:
		return SaveCodecScript.failure("invalid_archive", "冻结档案无法读取。")
	_save_generation += 1
	if is_node_ready():
		_close_workspace(false)
		if is_instance_valid(_record_book):
			_record_book.close_book()
		_record_input_restore.clear()
		if is_instance_valid(_story_dialog):
			_story_dialog.hide()
		_story_choice_handler = Callable()
		sticky_note.hide_note(false)
		daily_summary.hide_summary(false)
		new_day_popup.hide_popup(false)
	story_id = saved["story_id"]
	story = StoryCatalogScript.get_story(story_id)
	for key in SaveCodecScript.FIELD_TYPES:
		if get(key) is Array:
			get(key).assign(p[key])
		else:
			set(key, p[key].duplicate(true) if p[key] is Dictionary else p[key])
	_lesson_seen.clear()
	for key in p["_lesson_seen"]:
		_lesson_seen[int(key)] = p["_lesson_seen"][key]
	kitchen.ingredients = p["kitchen"]["ingredients"].duplicate(true)
	kitchen.condiments = p["kitchen"]["condiments"].duplicate(true)
	kitchen.batches.assign(p["kitchen"]["batches"])
	kitchen.history.assign(p["kitchen"]["history"])
	kitchen._serial = p["kitchen"]["serial"]
	shared_meal.plan = p["shared_meal"]["plan"].duplicate(true)
	shared_meal.history.assign(p["shared_meal"]["history"])
	_deck_service = MealDeckServiceScript.new(0)
	_deck_service.restore_state(p["deck"])
	_new_day_pending = p["new_day_pending"]
	_health_archive = archive
	_health_catalog.clear()
	_health_catalog_loaded = false
	health_history_diagnostics.clear()
	if is_node_ready():
		character_hud.set_portrait(String(story["portrait"]))
		_render_phase()
		if _new_day_pending:
			_show_new_day_popup()
		elif not HouseholdStudyPresenterScript.resume(self) and not HouseholdDayFivePresenterScript.resume(self) and not HouseholdPreparationPresenterScript.resume(self) and not HouseholdFinalePresenterScript.resume(self):
			HouseholdLearningPresenterScript.resume(self)
	return {"ok": true}


func _queue_autosave() -> void:
	if not is_node_ready() or _save_store == null:
		return
	_autosave_queued = true
	if not _autosave_busy:
		call_deferred("_flush_autosave")


func _flush_autosave() -> void:
	if _autosave_busy or not _autosave_queued or _save_store == null:
		return
	_autosave_busy = true
	while _autosave_queued:
		_autosave_queued = false
		var generation := _save_generation
		var snapshot := capture_game_save()
		if is_instance_valid(_save_status):
			_save_status.text = "正在保存…"
		var result: Dictionary = await _save_store.write_save(snapshot)
		if generation == _save_generation:
			_set_save_result(result)
	_autosave_busy = false


func _set_save_result(result: Dictionary) -> void:
	if is_instance_valid(_save_status):
		_save_status.text = "已保存" if result.get("ok", false) else "尚未保存 · 可导出备份"
	if not result.get("ok", false):
		save_diagnostics.append(result.duplicate(true))


func _show_game_menu() -> void:
	if _record_book_active() or not is_node_ready(): return
	var page := WorktopScript.new()
	_present_workspace(page)
	page.title_label.text = "这一周"
	page.subtitle_label.text = "第%d天 · %s · %s" % [day, PHASE_NAMES.get(phase, "安排生活"), String(story.get("character_name", ""))]
	page.close_button.text = "继续安排"
	HouseholdUI.note(page.body, "本周目标：%s\n%s %d/%d · 余额 ¥%d" % [story.get("goal", ""), story.get("goal_label", "复习"), state.get("goal_progress", state.get("study_progress", 0)), _goal_target(), state["balance"]])
	var progress := _save_status.text if is_instance_valid(_save_status) else ""
	HouseholdUI.section(page.body, "记录与进度")
	var choices := [{"id": "records", "text": "餐次记录", "hint": "回看这一周实际吃了什么"}, {"id": "save", "text": "保存当前进度", "hint": progress + " · 可另存三个位置"}, {"id": "load", "text": "读取已有进度", "hint": "从选择的位置继续安排"}, {"id": "export", "text": "导出存档文件", "hint": "下载备份，也可换设备继续"}, {"id": "import", "text": "导入存档文件", "hint": "预览后选择保存位置"}, {"id": "menu", "text": "回到故事选择", "hint": "先保存这一周的自动进度"}]
	for choice in choices:
		var button := HouseholdUI.button(String(choice["text"]) + "\n" + String(choice["hint"]), String(choice["id"]))
		button.custom_minimum_size.y = 84
		page.body.add_child(button)
		button.pressed.connect(func() -> void:
			if page != _workspace or not page.visible: return
			_close_workspace(false)
			match String(choice["id"]):
				"records":
					if _household(): _show_recipe_records()
					else: _show_meal_record_book()
				"save": _show_save_slots(false)
				"load": _show_save_slots(true)
				"export": _export_progress()
				"import": _import_progress()
				"menu": _save_to_slot("auto", true)
		)


func _show_save_slots(reading: bool) -> void:
	if not is_node_ready(): return
	var page := WorktopScript.new()
	_present_workspace(page)
	page.title_label.text = "读取进度" if reading else "保存进度"
	page.subtitle_label.text = "选一份进度，从这里继续。" if reading else "把现在的安排记在一个位置。"
	page.close_button.text = "返回菜单"
	for connection in page.close_requested.get_connections(): page.close_requested.disconnect(connection["callable"])
	page.close_requested.connect(func() -> void:
		if page != _workspace: return
		_close_workspace(false)
		_show_game_menu()
	)
	for slot in SaveStoreScript.SLOTS:
		if not reading and slot == "auto": continue
		var result: Dictionary = _save_store.read_save(story_id, slot)
		var label := "自动存档" if slot == "auto" else "存档 " + String(slot).trim_prefix("manual_")
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", HouseholdUI.paper(HouseholdUI.TILE, 16, 12))
		page.body.add_child(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 12)
		card.add_child(stack)
		stack.add_child(HouseholdUI.label(label, 28, HouseholdUI.INK, true))
		var detail := SaveCodecScript.summary(result["save"]) + ("\n来自上一份有效备份" if result.get("backup", false) else "") if result["ok"] else ("空位置" if result.get("error") == "empty_slot" else String(result.get("message", "暂时无法读取")))
		stack.add_child(HouseholdUI.label(detail, 22, HouseholdUI.MUTED))
		var button := HouseholdUI.button("继续这份进度" if reading else ("保存到这里" if not _save_store.slot_has_data(story_id, slot) else "替换这份存档"), String(slot), true)
		button.disabled = not result["ok"] if reading else false
		stack.add_child(button)
		button.pressed.connect(func() -> void:
			if page != _workspace or not page.visible: return
			_close_workspace(false)
			_select_save_slot(String(slot), reading)
		)


func _select_save_slot(slot: String, reading: bool) -> void:
	var result: Dictionary = _save_store.read_save(story_id, slot)
	if reading:
		if not result["ok"]: return
		var snapshot: Dictionary = result["save"].duplicate(true)
		_show_story_dialog("继续这份进度？", SaveCodecScript.summary(snapshot), [{"id": "read", "text": "读取这份进度"}, {"id": "back", "text": "返回存档列表"}], func(choice: String) -> void:
			if choice == "read": _set_save_result(restore_game_save(snapshot))
			else: _show_save_slots(true)
		)
	elif result["ok"] or _save_store.slot_has_data(story_id, slot):
		var summary := SaveCodecScript.summary(result["save"]) if result["ok"] else "这个位置有暂时无法读取的存档。"
		_show_story_dialog("替换这份存档？", summary + "\n\n这个位置将保存现在的进度。", [{"id": "save", "text": "替换这份存档"}, {"id": "back", "text": "返回存档列表"}], func(choice: String) -> void:
			if choice == "save": _save_to_slot(slot)
			else: _show_save_slots(false)
		)
	else: _save_to_slot(slot)


func _save_to_slot(slot: String, return_to_menu: bool = false) -> void:
	var snapshot := capture_game_save()
	_show_story_dialog("正在保存进度", "请稍候。", [], func(_choice: String) -> void: pass)
	var result: Dictionary = await _save_store.write_save(snapshot, slot)
	_set_save_result(result)
	if result["ok"]:
		if return_to_menu:
			_go_main_menu()
		else:
			_show_story_dialog("进度已保存", SaveCodecScript.summary(result["save"]), [{"id": "close", "text": "继续安排"}], func(_choice: String) -> void: pass)
	else:
		_show_story_dialog("尚未保存", String(result.get("message", "可重试或导出备份。")), [{"id": "retry", "text": "重新保存"}, {"id": "export", "text": "导出备份"}, {"id": "close", "text": "继续安排"}], func(choice: String) -> void:
			if choice == "retry":
				_save_store.retry()
				_save_to_slot(slot, return_to_menu)
			elif choice == "export": _export_progress()
		)


func _export_progress() -> void:
	var snapshot := capture_game_save()
	var encoded := SaveCodecScript.encode(snapshot)
	if not encoded["ok"]:
		_show_save_error(encoded)
		return
	if OS.has_feature("web"):
		var result: Dictionary = _save_store.export_web(snapshot)
		if not result["ok"]: _show_save_error({"message": "文件下载未能启动。"})
		else: _show_story_dialog("存档已交给浏览器下载", "保存好这份文件，可用于备份或在另一台设备继续。", [{"id": "close", "text": "继续安排"}], func(_choice: String) -> void: pass)
	else:
		var picker := FileDialog.new()
		picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		picker.access = FileDialog.ACCESS_FILESYSTEM
		picker.filters = PackedStringArray(["*.json ; 游戏存档"])
		picker.current_file = "nutrition-life-" + story_id + ".json"
		picker.file_selected.connect(func(path: String) -> void:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null: _show_save_error({"message": "文件无法写入。"})
			else:
				file.store_string(encoded["text"])
				file.close()
			picker.queue_free()
		)
		picker.canceled.connect(picker.queue_free)
		add_child(picker)
		picker.popup_centered(Vector2i(680, 480))


func _import_progress() -> void:
	if OS.has_feature("web"):
		var result: Dictionary = await _save_store.pick_web_file()
		if result.get("ok", false): _preview_import(String(result["text"]))
		elif result.get("error") != "cancelled": _show_save_error({"message": "文件未能读取。可以重新选择。"})
	else:
		var picker := FileDialog.new()
		picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		picker.access = FileDialog.ACCESS_FILESYSTEM
		picker.filters = PackedStringArray(["*.json ; 游戏存档"])
		picker.file_selected.connect(func(path: String) -> void:
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null or file.get_length() > SaveCodecScript.MAX_BYTES: _show_save_error({"message": "文件无法读取或过大。"})
			else: _preview_import(file.get_as_text())
			picker.queue_free()
		)
		picker.canceled.connect(picker.queue_free)
		add_child(picker)
		picker.popup_centered(Vector2i(680, 480))


func _preview_import(text: String) -> void:
	var result := SaveCodecScript.decode(text)
	if not result["ok"]:
		_show_save_error(result)
		return
	var snapshot: Dictionary = result["save"]
	var choices: Array = []
	for slot in ["manual_1", "manual_2", "manual_3"]:
		choices.append({"id": slot, "text": "导入到存档 " + slot.trim_prefix("manual_")})
	choices.append({"id": "cancel", "text": "取消导入"})
	_show_story_dialog("导入这份进度？", SaveCodecScript.summary(snapshot) + "\n\n选择目标位置，确认后可从这份进度继续。", choices, func(slot: String) -> void:
		if slot == "cancel": return
		var existing: Dictionary = _save_store.read_save(snapshot["story_id"], slot)
		if existing["ok"] or _save_store.slot_has_data(snapshot["story_id"], slot):
			var old_summary := SaveCodecScript.summary(existing["save"]) if existing["ok"] else "这个位置有暂时无法读取的存档。"
			_show_story_dialog("替换这个位置？", old_summary + "\n\n将被导入的进度替换。", [{"id": "import", "text": "替换并继续"}, {"id": "cancel", "text": "取消导入"}], func(choice: String) -> void:
				if choice == "import": _finish_import(snapshot, slot)
			)
		else: _finish_import(snapshot, slot)
	)


func _finish_import(snapshot: Dictionary, slot: String) -> void:
	_show_story_dialog("正在导入进度", "请稍候。", [], func(_choice: String) -> void: pass)
	var result: Dictionary = await _save_store.write_save(snapshot, slot)
	if not result["ok"]:
		_show_save_error(result)
		return
	_set_save_result(restore_game_save(snapshot))


func _show_save_error(result: Dictionary) -> void:
	_show_story_dialog("进度未能处理", String(result.get("message", "可以稍后重试。")), [{"id": "close", "text": "继续安排"}], func(_choice: String) -> void: pass)
