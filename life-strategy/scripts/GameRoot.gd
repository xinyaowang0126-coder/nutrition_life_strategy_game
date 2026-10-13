extends Control

const GameDataScript := preload("res://scripts/GameData.gd")
const MealDeckServiceScript := preload("res://scripts/systems/MealDeckService.gd")
const MealResolverScript := preload("res://scripts/systems/MealResolver.gd")
const NutritionLedgerScript := preload("res://scripts/systems/NutritionLedger.gd")
const BalanceRules := preload("res://scripts/systems/GameplayBalanceRules.gd")
const FoodPreferenceServiceScript := preload("res://scripts/systems/FoodPreferenceService.gd")
const RecoveryStateServiceScript := preload("res://scripts/systems/RecoveryStateService.gd")
const RecoveryGameplayServiceScript := preload("res://scripts/systems/RecoveryGameplayService.gd")
const RecoveryPresenterScript := preload("res://scripts/systems/RecoveryPresenter.gd")
const WeeklyEventServiceScript := preload("res://scripts/systems/WeeklyEventService.gd")
const CHOICE_CARD_SCENE := preload("res://scenes/game/components/ChoiceCard.tscn")
const PHASE_VIEW_SCENE := preload("res://scenes/game/components/PhaseChoiceView.tscn")
const MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const DEFAULT_BACKGROUND := "res://assets/generated/backgrounds/dorm_background.png"
const PORTRAIT_PATH := "res://assets/generated/characters/student_portrait.png"
const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Bold.otf"
const GAME_THEME_PATH := "res://scenes/game/components/GameTheme.tres"

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
	"summary": "日结",
	"ending": "周末",
}
const STAT_ORDER := ["stability", "energy", "mood", "satiety", "stress", "study_progress"]

const COLOR_TEXT := Color(0.20, 0.17, 0.13)
const COLOR_SOFT := Color(0.34, 0.28, 0.21)
const COLOR_MUTED := Color(0.43, 0.36, 0.27)
const COLOR_HEADING := Color(0.13, 0.18, 0.14)
const COLOR_HEADER := Color(1.0, 0.94, 0.76)

@onready var background: TextureRect = $Background
@onready var shade: ColorRect = $Shade
@onready var root_margin: MarginContainer = $RootMargin
@onready var header_label: Label = $RootMargin/RootBox/HeaderPanel/HeaderRow/HeaderLabel
@onready var phase_label: Label = $RootMargin/RootBox/HeaderPanel/HeaderRow/PhaseLabel
@onready var restart_button: Button = $RootMargin/RootBox/HeaderPanel/HeaderRow/RestartButton
@onready var menu_button: Button = $RootMargin/RootBox/HeaderPanel/HeaderRow/MenuButton
@onready var left_panel: PanelContainer = $RootMargin/RootBox/Body/LeftPanel
@onready var left_content: VBoxContainer = $RootMargin/RootBox/Body/LeftPanel/LeftContent
@onready var center_content: VBoxContainer = $RootMargin/RootBox/Body/CenterPanel/CenterContent
@onready var right_panel: PanelContainer = $RootMargin/RootBox/Body/RightPanel
@onready var right_content: VBoxContainer = $RootMargin/RootBox/Body/RightPanel/RightContent
@onready var toast_feed: Node = get_node_or_null("ToastFeed")

var state: Dictionary = {}
var food_preferences: Dictionary = {}
var day := 1
var phase := "breakfast_source"
var hand: Array[String] = []
var selected_food_indices: Array[int] = []
var current_source_id := ""
var source_hands: Dictionary = {}
var dorm_inventory: Dictionary = {}
var today_meal_records: Array[Dictionary] = []
var today_food_spend := 0
var actions_used_today := 0
var drink_water_used := 0
var combos_today: Array[String] = []
var log_entries: Array[String] = []
var daily_summary := ""
var ending_id := ""
var low_stability_days := 0
var guide_visible := false
var portrait_mode := false
var compact_mode := false
var _current_background_path := ""
var _deck_service: RefCounted
var current_recovery_state: Dictionary = RecoveryStateServiceScript.new_run()
var pending_recovery_state: Dictionary = RecoveryStateServiceScript.new_run()
var _current_recovery_effect: Dictionary = {"study_modifier": 0, "opening_delta": {}}
var _recovery_display_record: Dictionary = {}
var run_history: Array[Dictionary] = []
var today_action_records: Array[Dictionary] = []
var recovery_diagnostics: Array[Dictionary] = []
var chosen_sleep_id := ""
var chosen_sleep_name := ""
var _recovery_before_sleep: Dictionary = {}
var _recovery_sleep_snapshot: Dictionary = {}
var _day_settlement_effects: Array[Dictionary] = []
var _day_settled := false
var _started_day := 0


func _ready() -> void:
	GameDataScript.ensure_loaded()
	_deck_service = MealDeckServiceScript.new()
	_apply_theme()
	_setup_scene_shell()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	start_new_run()


func _apply_theme() -> void:
	var game_theme: Theme = load(GAME_THEME_PATH).duplicate(true)
	var font_resource: Font = load(FONT_PATH)
	if font_resource != null:
		var font_variation := FontVariation.new()
		font_variation.base_font = font_resource
		font_variation.variation_embolden = 0.16
		font_variation.variation_opentype = {"wght": 700.0}
		game_theme.default_font = font_variation
	game_theme.default_font_size = 18
	theme = game_theme
	header_label.add_theme_color_override("font_color", COLOR_HEADER)
	phase_label.add_theme_color_override("font_color", Color(0.94, 0.89, 0.78))


func _setup_scene_shell() -> void:
	restart_button.pressed.connect(_request_restart)
	menu_button.pressed.connect(_request_main_menu)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	portrait_mode = viewport_size.y > viewport_size.x * 1.20
	compact_mode = portrait_mode or viewport_size.x < 1500.0
	left_panel.visible = not portrait_mode
	right_panel.visible = not compact_mode
	root_margin.add_theme_constant_override("margin_left", 12 if compact_mode else 28)
	root_margin.add_theme_constant_override("margin_right", 12 if compact_mode else 28)
	root_margin.add_theme_constant_override("margin_top", 12 if compact_mode else 24)
	root_margin.add_theme_constant_override("margin_bottom", 12 if compact_mode else 24)
	header_label.add_theme_font_size_override("font_size", 82 if portrait_mode else 38)
	phase_label.add_theme_font_size_override("font_size", 52 if portrait_mode else 22)
	restart_button.add_theme_font_size_override("font_size", 48 if portrait_mode else 18)
	menu_button.add_theme_font_size_override("font_size", 48 if portrait_mode else 18)
	restart_button.custom_minimum_size = Vector2(250, 120) if portrait_mode else Vector2(150, 52)
	menu_button.custom_minimum_size = Vector2(220, 120) if portrait_mode else Vector2(118, 52)
	if not state.is_empty():
		_refresh_all()


func start_new_run() -> void:
	food_preferences = FoodPreferenceServiceScript.default_profile()
	state = GameDataScript.get_starting_stats()
	day = 1
	low_stability_days = 0
	dorm_inventory = GameDataScript.get_initial_dorm_inventory()
	log_entries.clear()
	ending_id = ""
	guide_visible = false
	run_history.clear()
	recovery_diagnostics.clear()
	pending_recovery_state = RecoveryStateServiceScript.new_run()
	current_recovery_state = pending_recovery_state.duplicate(true)
	_current_recovery_effect = pending_recovery_state["next_day_effect"].duplicate(true)
	_started_day = 0
	_start_day()
	_add_log("第一天。先吃点早饭。")
	_refresh_all()


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
	current_recovery_state = prepared["recovery_state"].duplicate(true)
	_recovery_display_record = current_recovery_state.duplicate(true)
	_current_recovery_effect = current_recovery_state["next_day_effect"].duplicate(true)
	_apply_stat_delta(_current_recovery_effect["opening_delta"])
	state = WeeklyEventServiceScript.apply_opening_state(day, state)
	_clamp_stats()
	phase = "breakfast_source"
	hand.clear()
	selected_food_indices.clear()
	current_source_id = ""
	source_hands.clear()
	today_meal_records.clear()
	today_food_spend = 0
	actions_used_today = 0
	drink_water_used = 0
	combos_today.clear()
	daily_summary = ""
	today_action_records.clear()
	chosen_sleep_id = ""
	chosen_sleep_name = ""
	_recovery_before_sleep.clear()
	_recovery_sleep_snapshot.clear()
	_day_settlement_effects.clear()
	_day_settled = false
	_started_day = day
	return true


func _refresh_all() -> void:
	if not is_node_ready():
		return
	_refresh_header()
	_rebuild_left()
	_rebuild_center()
	_rebuild_right()
	_update_background()


func _refresh_header() -> void:
	header_label.text = "第 %d 天 / %d" % [day, GameDataScript.TOTAL_DAYS]
	phase_label.text = "%s · 余 ¥%d · 今日安排 %d/%d" % [
		String(PHASE_NAMES.get(phase, phase)),
		int(state["balance"]),
		actions_used_today,
		MAX_DAILY_ACTIONS,
	]


func _rebuild_left() -> void:
	_clear_children(left_content)
	_add_heading(left_content, "此刻", 30)
	var portrait := TextureRect.new()
	portrait.texture = load(PORTRAIT_PATH)
	portrait.custom_minimum_size = Vector2(0, 150)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	left_content.add_child(portrait)
	for key in STAT_ORDER:
		_add_stat_bar(key)
	var recovery_view := RecoveryPresenterScript.present(_recovery_display_record)
	var recovery_label := Label.new()
	recovery_label.text = String(recovery_view["label"])
	recovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recovery_label.add_theme_font_size_override("font_size", 18)
	left_content.add_child(recovery_label)

	var remaining: int = max(0, MAX_DAILY_ACTIONS - actions_used_today)
	var detail := Label.new()
	detail.text = "今天花了 ¥%d\n还可安排 %d 件事" % [today_food_spend, remaining]
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_color_override("font_color", COLOR_SOFT)
	left_content.add_child(detail)

	var hint := Label.new()
	hint.text = _left_hint()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	left_content.add_child(hint)

	var guide_button := Button.new()
	guide_button.text = "状态怎么看"
	guide_button.custom_minimum_size = Vector2(0, 48)
	guide_button.pressed.connect(_open_metrics_guide)
	left_content.add_child(guide_button)


func _add_stat_bar(key: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	left_content.add_child(row)
	var display_value := int(state[key])
	var label := Label.new()
	label.text = "%s  %d" % [GameDataScript.STAT_LABELS[key], display_value]
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", _stat_color(key, display_value))
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = float(display_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 7)
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.70, 0.65, 0.55, 0.72)))
	bar.add_theme_stylebox_override("fill", _bar_style(_stat_color(key, display_value)))
	row.add_child(bar)


func _rebuild_center() -> void:
	_clear_children(center_content)
	if guide_visible:
		_build_metrics_guide()
	elif phase == "ending":
		_build_ending_view()
	elif phase == "summary":
		_build_summary_view()
	elif _is_source_phase():
		_build_source_choices()
	elif _is_meal_phase():
		_build_food_choices()
	elif _is_action_phase():
		_build_action_choices()
	elif phase == "sleep":
		_build_sleep_choices()


func _new_phase_view(title: String, prompt: String, status: String, columns: int) -> PhaseChoiceView:
	var view: PhaseChoiceView = PHASE_VIEW_SCENE.instantiate() as PhaseChoiceView
	center_content.add_child(view)
	view.setup(title, prompt, status, columns)
	view.set_portrait_mode(portrait_mode)
	return view


func _new_choice_card(
	payload: Dictionary,
	mode: String,
	button_text: String,
	enabled: bool,
	disabled_reason: String = "",
	stock: int = -1
) -> ChoiceCard:
	var card: ChoiceCard = CHOICE_CARD_SCENE.instantiate() as ChoiceCard
	card.configure(payload, mode, button_text, enabled, disabled_reason, stock)
	card.set_portrait_mode(portrait_mode)
	return card


func _build_source_choices() -> void:
	var meal := _current_meal_phase()
	var view := _new_phase_view(
		"%s · 去哪里吃？" % String(PHASE_NAMES[meal]),
		"先选个地方。详细规则可以悬停查看。",
		"换地方不会扣钱，确认吃下去才结账。",
		1 if portrait_mode else 2
	)
	view.configure_footer("", "先不吃", "")
	view.secondary_pressed.connect(_skip_meal)
	for id in GameDataScript.get_meal_source_ids():
		var source := _effective_meal_source(id)
		var reason := _source_disabled_reason(id, meal)
		var enabled := reason.is_empty()
		var button_text := "去看看" if enabled else ("未营业" if not GameDataScript.is_meal_source_available(id, meal) else "不可用")
		var card := _new_choice_card(source, "source", button_text, enabled, reason)
		card.chosen.connect(_choose_meal_source)
		view.add_card(card)


func _build_food_choices() -> void:
	var source := _effective_meal_source(current_source_id)
	var total := _selected_meal_total()
	var view := _new_phase_view(
		"%s · %s" % [String(PHASE_NAMES[phase]), String(source["name"])],
		"",
		"已选 %d/%d · 合计 ¥%d" % [selected_food_indices.size(), MAX_FOODS_PER_MEAL, total],
		_grid_columns()
	)
	view.configure_footer("换个地方", "先不吃", "就吃这些")
	view.back_pressed.connect(_change_meal_source)
	view.secondary_pressed.connect(_skip_meal)
	view.primary_pressed.connect(_confirm_food)
	view.set_primary_enabled(not selected_food_indices.is_empty())

	for index in range(hand.size()):
		var food := FoodPreferenceServiceScript.decorate_food(
			GameDataScript.get_food(hand[index]), food_preferences
		)
		var can_toggle := selected_food_indices.has(index) or _can_add_food(index)
		var stock := int(dorm_inventory.get(hand[index], 0)) if _source_uses_stock() else -1
		var card := _new_choice_card(
			food,
			"food",
			_food_button_text(index),
			can_toggle,
			"钱不够，或者已经选满了。" if not can_toggle else "",
			stock
		)
		card.set_selected(selected_food_indices.has(index))
		card.chosen.connect(func(_id: String): _toggle_food_selection(index))
		view.add_card(card)


func _build_action_choices() -> void:
	var remaining: int = max(0, MAX_DAILY_ACTIONS - actions_used_today)
	var view := _new_phase_view(
		String(PHASE_NAMES.get(phase, "餐后")),
		_phase_prompt(),
		"今天还可安排 %d 件事。" % remaining,
		_grid_columns()
	)
	view.configure_footer("", "不安排", "")
	view.secondary_pressed.connect(_skip_action)
	for id in GameDataScript.get_action_ids_for_scene(phase):
		var action := _effective_action(id)
		var can_use := _can_use_action(action)
		var card := _new_choice_card(action, "action", "就做这个", can_use, _action_disabled_reason(action))
		card.chosen.connect(_apply_action)
		view.add_card(card)


func _build_sleep_choices() -> void:
	var view := _new_phase_view("今天就到这里", "睡前，最后选一次。", "", _grid_columns())
	view.configure_footer("", "", "")
	for id in GameDataScript.get_sleep_option_ids_for_scene("sleep"):
		var option := GameDataScript.get_sleep_option(id)
		var card := _new_choice_card(option, "sleep", "就这样", true)
		card.chosen.connect(_choose_sleep)
		view.add_card(card)


func _build_metrics_guide() -> void:
	_add_heading(center_content, "状态怎么看", 34)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_content.add_child(scroll)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22 if not portrait_mode else 58)
	label.text = "余力：这一周还能不能周转得开。\n\n精力：白天还能做多少事。\n\n心情：过日子的兴致。\n\n饱腹：饿着和吃撑都会难受。\n\n压力：越高，越容易顾此失彼。\n\n复习：考试前准备了多少。\n\n一顿最多选 %d 样；三餐后，各能安排一件事。" % MAX_FOODS_PER_MEAL
	label.text += "\n\n" + String(RecoveryPresenterScript.present(_recovery_display_record)["detail_text"])
	scroll.add_child(label)
	var close := Button.new()
	close.text = "回去"
	close.custom_minimum_size = Vector2(180, 56)
	close.pressed.connect(_close_metrics_guide)
	center_content.add_child(close)


func _build_summary_view() -> void:
	_add_heading(center_content, "灯关了", 34)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_content.add_child(scroll)
	var label := Label.new()
	label.text = daily_summary
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 28 if not portrait_mode else 70)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	scroll.add_child(label)
	var next_button := Button.new()
	next_button.text = "开始第 %d 天" % (day + 1)
	next_button.custom_minimum_size = Vector2(220, 58)
	next_button.pressed.connect(_next_day)
	center_content.add_child(next_button)


func _build_ending_view() -> void:
	var ending := GameDataScript.get_ending(ending_id)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	_add_heading(box, String(ending["title"]), 38)
	var image := TextureRect.new()
	image.texture = load(String(ending["image"]))
	image.custom_minimum_size = Vector2(0, 300 if not portrait_mode else 640)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(image)
	var text := Label.new()
	text.text = "%s\n\n余力 %d · 复习 %d · 余额 ¥%d\n\n%s" % [
		RecoveryPresenterScript.ending_text(ending_id, run_history),
		int(state["stability"]),
		int(state["study_progress"]),
		int(state["balance"]),
		daily_summary,
	]
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 22 if not portrait_mode else 56)
	box.add_child(text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var restart := Button.new()
	restart.text = "再来一周"
	restart.pressed.connect(start_new_run)
	buttons.add_child(restart)
	var menu := Button.new()
	menu.text = "回主菜单"
	menu.pressed.connect(_go_main_menu)
	buttons.add_child(menu)


func _rebuild_right() -> void:
	_clear_children(right_content)
	_add_heading(right_content, "今天", 28)
	if today_meal_records.is_empty():
		var empty := Label.new()
		empty.text = "还没开饭。"
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		right_content.add_child(empty)
	else:
		for record in today_meal_records:
			var meal := Label.new()
			meal.text = _record_display_text(record)
			meal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			meal.add_theme_font_size_override("font_size", 18)
			meal.add_theme_color_override("font_color", COLOR_SOFT)
			right_content.add_child(meal)
	_add_heading(right_content, "此刻", 24)
	var hint := Label.new()
	hint.text = _left_hint()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	right_content.add_child(hint)


func _choose_meal_source(id: String) -> void:
	var meal := _current_meal_phase()
	var reason := _source_disabled_reason(id, meal)
	if not reason.is_empty():
		_add_log(reason, "warning")
		return
	current_source_id = id
	hand = _hand_for_source(id, meal)
	selected_food_indices.clear()
	phase = meal
	_refresh_all()


func _change_meal_source() -> void:
	phase = "%s_source" % phase
	current_source_id = ""
	hand.clear()
	selected_food_indices.clear()
	_refresh_all()


func _hand_for_source(source_id: String, meal: String) -> Array[String]:
	var cache_key := "%s:%s" % [meal, source_id]
	if source_hands.has(cache_key):
		var cached: Array = source_hands[cache_key]
		var valid_cached: Array[String] = []
		for value in cached:
			var id := String(value)
			if source_id != "dorm_storage" or int(dorm_inventory.get(id, 0)) > 0:
				valid_cached.append(id)
		return valid_cached

	var source := GameDataScript.get_meal_source(source_id)
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
	for id in built:
		if int(GameDataScript.get_food(id)["cost"]) + fee <= int(state["balance"]):
			return
	var cheapest_id := ""
	var cheapest_cost := 100000
	for id in candidates:
		var cost := int(GameDataScript.get_food(id)["cost"])
		if cost < cheapest_cost and cost + fee <= int(state["balance"]):
			cheapest_cost = cost
			cheapest_id = id
	if not cheapest_id.is_empty():
		if built.is_empty():
			built.append(cheapest_id)
		else:
			built[built.size() - 1] = cheapest_id


func _source_disabled_reason(source_id: String, meal: String) -> String:
	if not GameDataScript.is_meal_source_available(source_id, meal):
		return "这个时段还没有营业。"
	var source := GameDataScript.get_meal_source(source_id)
	var candidates := GameDataScript.get_food_ids_for_context(source_id, meal)
	if String(source.get("payment_mode", "cash")) == "stock":
		for id in candidates:
			if int(dorm_inventory.get(id, 0)) > 0:
				return ""
		return "柜子里已经吃空了。"
	var fee := int(source.get("fee", 0))
	for id in candidates:
		if int(GameDataScript.get_food(id)["cost"]) + fee <= int(state["balance"]):
			return ""
	return "手里的钱不够在这里吃一顿。"


func _toggle_food_selection(index: int) -> void:
	if selected_food_indices.has(index):
		selected_food_indices.erase(index)
	elif _can_add_food(index):
		selected_food_indices.append(index)
	_rebuild_center()


func _can_add_food(index: int) -> bool:
	if index < 0 or index >= hand.size():
		return false
	if selected_food_indices.has(index):
		return true
	if selected_food_indices.size() >= MAX_FOODS_PER_MEAL:
		return false
	if _source_uses_stock():
		return int(dorm_inventory.get(hand[index], 0)) > 0
	return _selected_meal_total(index) <= int(state["balance"])


func _selected_meal_total(extra_index: int = -1) -> int:
	if current_source_id.is_empty() or _source_uses_stock():
		return 0
	var source := _effective_meal_source(current_source_id)
	var total := int(source.get("fee", 0))
	var indices: Array[int] = selected_food_indices.duplicate()
	if extra_index >= 0 and not indices.has(extra_index):
		indices.append(extra_index)
	if indices.is_empty():
		return 0
	for index in indices:
		if index >= 0 and index < hand.size():
			total += int(GameDataScript.get_food(hand[index])["cost"])
	return total


func _food_button_text(index: int) -> String:
	if selected_food_indices.has(index):
		return "移除"
	if selected_food_indices.size() >= MAX_FOODS_PER_MEAL:
		return "已选满"
	if not _can_add_food(index):
		return "不可用"
	return "选这个"


func _confirm_food() -> void:
	if selected_food_indices.is_empty() or current_source_id.is_empty():
		return
	var foods: Array[Dictionary] = []
	for index in selected_food_indices:
		if index >= 0 and index < hand.size():
			foods.append(GameDataScript.get_food(hand[index]))
	if foods.is_empty():
		return
	var source := _effective_meal_source(current_source_id)
	var record := MealResolverScript.build_record(phase, source, foods, food_preferences)
	if int(record["total_cost"]) > int(state["balance"]):
		_add_log("钱不够，得少拿一样。", "warning")
		return
	if bool(record["uses_stock"]):
		for id in record["food_ids"]:
			if int(dorm_inventory.get(String(id), 0)) <= 0:
				_add_log("这份已经吃完了。", "warning")
				return
	_apply_meal_record(record)
	var names: Array = record["food_names"]
	_add_log("%s吃了%s。" % [String(PHASE_NAMES[phase]), "、".join(names)], "good")
	selected_food_indices.clear()
	hand.clear()
	current_source_id = ""
	_advance_from_meal()


func _skip_meal() -> void:
	var meal := _current_meal_phase()
	var record := MealResolverScript.build_skipped_record(meal)
	_apply_meal_record(record)
	_add_log("%s没吃，肚子一直空着。" % String(PHASE_NAMES[meal]), "warning")
	selected_food_indices.clear()
	hand.clear()
	current_source_id = ""
	phase = meal
	_advance_from_meal()


func _apply_meal_record(record: Dictionary) -> void:
	state["balance"] = int(state["balance"]) - int(record["total_cost"])
	_apply_stat_delta(record["stat_delta"])
	if bool(record["uses_stock"]):
		for id in record["food_ids"]:
			var key := String(id)
			dorm_inventory[key] = max(0, int(dorm_inventory.get(key, 0)) - 1)
	today_meal_records.append(record.duplicate(true))
	today_food_spend += int(record["total_cost"])
	_check_meal_combos(record)
	_clamp_stats()
	_update_stability()


func _check_meal_combos(record: Dictionary) -> void:
	if not combos_today.has("meal_group_mix") and MealResolverScript.has_meal_group_combination(record):
		combos_today.append("meal_group_mix")
	if not combos_today.has("comfort_chain") and MealResolverScript.comfort_meal_count(today_meal_records) >= 2:
		combos_today.append("comfort_chain")
		state["mood"] = int(state["mood"]) + 2
		_add_log("今天已有两餐合口味，心情 +2（游戏）。")
	if String(record["phase"]) == "dinner" and not combos_today.has("budget_saver"):
		var all_eaten := today_meal_records.size() >= 3
		for meal_record in today_meal_records:
			if bool(meal_record.get("skipped", false)) or int(meal_record.get("stat_delta", {}).get("satiety", 0)) < 20:
				all_eaten = false
		if all_eaten and MealResolverScript.total_spend(today_meal_records) <= 18:
			combos_today.append("budget_saver")
			state["stress"] = int(state["stress"]) - 2
			_add_log("三餐各补充至少 20 饱腹且合计不超过 ¥18，压力 -2（游戏）。", "good")


func _advance_from_meal() -> void:
	if phase == "breakfast":
		phase = "breakfast_action"
	elif phase == "lunch":
		phase = "lunch_action"
	else:
		phase = "dinner_action"
	_refresh_all()


func _apply_action(id: String) -> void:
	if not _is_action_phase() or not GameDataScript.get_action_ids_for_scene(phase).has(id):
		return
	var action := _effective_action(id)
	if not _can_use_action(action):
		return
	actions_used_today += int(action.get("slots", 1))
	if id == "drink_water":
		drink_water_used += 1
	state["balance"] = int(state["balance"]) - int(action.get("cost", 0))
	var delta := {
		"energy": int(action.get("energy", 0)),
		"mood": int(action.get("mood", 0)),
		"stress": int(action.get("stress", 0)),
		"study_progress": int(action.get("study", 0)),
		"satiety": int(action.get("satiety", 0)),
	}
	_apply_stat_delta(delta)
	var added := {}
	for raw_item in action.get("stock_items", []):
		var parts := String(raw_item).split(":", false)
		if parts.is_empty():
			continue
		var food_id := String(parts[0])
		var amount := int(parts[1]) if parts.size() > 1 else 1
		if amount > 0 and not GameDataScript.get_food(food_id).is_empty():
			dorm_inventory[food_id] = int(dorm_inventory.get(food_id, 0)) + amount
			added[food_id] = amount
	today_action_records.append({"id": id, "name": action.get("name", id), "cost": action.get("cost", 0), "stat_delta": delta.duplicate(true), "stock_added": added})
	_clamp_stats()
	_update_stability()
	_add_log("餐后 · %s" % String(action["name"]))
	if int(action.get("slots", 1)) == 0:
		_refresh_all()
	else:
		_advance_after_action()


func _skip_action() -> void:
	if not _is_action_phase():
		return
	_add_log("%s，没再安排什么。" % String(PHASE_NAMES.get(phase, "餐后")))
	_advance_after_action()


func _advance_after_action() -> void:
	if not _is_action_phase():
		return
	_apply_stat_delta(BalanceRules.period_delta())
	_clamp_stats()
	_update_stability()
	if phase == "breakfast_action":
		phase = "lunch_source"
	elif phase == "lunch_action":
		phase = "dinner_source"
	else:
		phase = "sleep"
	_refresh_all()


func _can_use_action(action: Dictionary) -> bool:
	if not _is_action_phase():
		return false
	if actions_used_today + int(action.get("slots", 1)) > MAX_DAILY_ACTIONS:
		return false
	if int(action.get("cost", 0)) > int(state["balance"]):
		return false
	if int(state.get("energy", 0)) < int(action.get("min_energy", 0)):
		return false
	if str(action.get("once_per_day", false)).to_lower() == "true":
		for record in today_action_records:
			if record.get("id") == action.get("id"):
				return false
	if String(action.get("id", "")) == "drink_water" and drink_water_used >= 2:
		return false
	return true


func _action_disabled_reason(action: Dictionary) -> String:
	if int(state.get("energy", 0)) < int(action.get("min_energy", 0)):
		return "精力不够，先留一点余地。"
	if str(action.get("once_per_day", false)).to_lower() == "true":
		for record in today_action_records:
			if record.get("id") == action.get("id"):
				return "今天已经做过了。"
	if String(action.get("id", "")) == "drink_water" and drink_water_used >= 2:
		return "今天已经喝过两次了。"
	if actions_used_today + int(action.get("slots", 1)) > MAX_DAILY_ACTIONS:
		return "今天已经排满了。"
	if int(action.get("cost", 0)) > int(state["balance"]):
		return "余额不够。"
	return ""


func _choose_sleep(id: String) -> void:
	if phase != "sleep" or _day_settled or not GameDataScript.get_sleep_option_ids_for_scene("sleep").has(id):
		return
	var option := GameDataScript.get_sleep_option(id)
	chosen_sleep_id = id
	chosen_sleep_name = String(option.get("name", id))
	_recovery_before_sleep = {"energy": state.get("energy"), "stress": state.get("stress")}
	_recovery_sleep_snapshot = {"id": id}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		_recovery_sleep_snapshot[key] = int(option.get(key, 0))
	_apply_stat_delta({
		"energy": int(option.get("energy", 0)),
		"mood": int(option.get("mood", 0)),
		"stress": int(option.get("stress", 0)),
		"study_progress": int(option.get("study", 0)),
		"satiety": int(option.get("satiety", 0)),
	})
	_add_log("夜里，%s。" % String(option["name"]))
	_finish_day()


func _finish_day() -> void:
	if _day_settled:
		return
	_day_settled = true
	var meal_facts := NutritionLedgerScript.summarize(today_meal_records)
	if int(state["satiety"]) < 20:
		_apply_day_settlement_effect("low_satiety", {"energy": -8, "stress": 8, "mood": -5})
	if int(state["satiety"]) > 92:
		_apply_day_settlement_effect("high_satiety", {"energy": -3})
	var remaining_days: int = max(0, GameDataScript.TOTAL_DAYS - day)
	if remaining_days > 0 and int(state["balance"]) < remaining_days * 14:
		_apply_day_settlement_effect("tight_budget", {"stress": 5, "mood": -2})
		_add_log("手里的钱不多了，明天得算着花。", "warning")
	if int(state["study_progress"]) < mini(GameDataScript.STUDY_TARGET, day * GameDataScript.DAILY_STUDY_PACE):
		_apply_day_settlement_effect("study_behind", {"stress": 3})
	else:
		_apply_day_settlement_effect("study_on_pace", {"mood": 2})
	_clamp_stats()
	_settle_recovery_record()
	var stability_valid := _update_stability(pending_recovery_state)
	if stability_valid and int(state["stability"]) <= 15:
		low_stability_days += 1
	elif stability_valid:
		low_stability_days = 0
	run_history.append({"day": day, "recovery_state": pending_recovery_state.duplicate(true), "end_state": state.duplicate(true), "actions": today_action_records.duplicate(true), "meals": today_meal_records.duplicate(true), "sleep": {"id": chosen_sleep_id, "name": chosen_sleep_name}})
	daily_summary = "第 %d 天，过去了。\n\n余力 %d · 复习 %d · 余额 ¥%d\n\n%s\n%s" % [
		day,
		int(state["stability"]),
		int(state["study_progress"]),
		int(state["balance"]),
		String(meal_facts["observation"]),
		_summary_advice(),
	]
	var recovery_view := RecoveryPresenterScript.present(pending_recovery_state, "final" if day >= GameDataScript.TOTAL_DAYS else "settled")
	daily_summary += "\n\n" + String(recovery_view["detail_text"])
	if not stability_valid:
		daily_summary = "恢复记录暂时不可用，请通过菜单重新开始这一周。"
		phase = "summary"
		_refresh_all()
	elif low_stability_days >= 2:
		_finish_run("collapsed")
	elif day >= GameDataScript.TOTAL_DAYS:
		_finish_run(MealResolverScript.select_ending(state))
	else:
		phase = "summary"
		_refresh_all()


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


func _effective_meal_source(id: String) -> Dictionary:
	return WeeklyEventServiceScript.apply_meal_source(day, id, GameDataScript.get_meal_source(id))


func _effective_action(id: String) -> Dictionary:
	var action := WeeklyEventServiceScript.apply_action(day, id, GameDataScript.get_action(id))
	if int(action.get("slots", 1)) > 0:
		action["rule_hint"] = String(action.get("rule_hint", "")) + "\n" + BalanceRules.PERIOD_HINT
	if id == "study":
		var modifier := int(_current_recovery_effect["study_modifier"])
		modifier += int(BalanceRules.study_penalty(state)["modifier"])
		action["study"] = maxi(1, int(action.get("study", 0)) + modifier)
	return action


func _next_day() -> void:
	if phase != "summary" or not _day_settled or day >= GameDataScript.TOTAL_DAYS:
		return
	day += 1
	if not _start_day():
		day -= 1
		daily_summary = "恢复记录暂时不可用，请通过菜单重新开始这一周。"
		_refresh_all()
		return
	_add_log("第 %d 天，天亮了。" % day)
	_refresh_all()


func _finish_run(result: String) -> void:
	ending_id = result
	phase = "ending"
	_add_log("周末到了。" if day >= GameDataScript.TOTAL_DAYS else "这一局先停在这里。", "good")
	_refresh_all()


func _apply_stat_delta(delta: Dictionary) -> void:
	for key in delta.keys():
		if key in ["burden", "diet_burden", "character_health"]:
			continue
		if state.has(key):
			state[key] = int(state[key]) + int(delta[key])


func _update_stability(recovery_record: Variant = null) -> bool:
	if today_meal_records.is_empty() and recovery_record == null:
		return true
	var record: Variant = current_recovery_state if recovery_record == null else recovery_record
	var result := RecoveryGameplayServiceScript.calculate_stability_from_recovery(
		state,
		day,
		GameDataScript.TOTAL_DAYS,
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
	for key in ["stability", "energy", "mood", "satiety", "stress", "study_progress"]:
		state[key] = clamp(int(state[key]), 0, 100)
	state["balance"] = clamp(int(state["balance"]), 0, 999)


func _current_meal_phase() -> String:
	if _is_source_phase():
		return phase.substr(0, phase.length() - "_source".length())
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


func _is_source_phase() -> bool:
	return phase.ends_with("_source")


func _is_meal_phase() -> bool:
	return MEAL_PHASES.has(phase)


func _is_action_phase() -> bool:
	return phase.ends_with("_action")


func _grid_columns() -> int:
	if portrait_mode:
		return 1
	if compact_mode:
		return 2
	return 3


func _phase_prompt() -> String:
	if phase == "breakfast_action":
		return "上午还能安排一件事。"
	if phase == "lunch_action":
		return "下午怎么过？"
	return "睡前，还能做一件事。"


func _left_hint() -> String:
	if int(state["stress"]) >= 75:
		return "脑子绷得太紧了。出去走走，或者早点睡。"
	if int(state["balance"]) <= max(8, (GameDataScript.TOTAL_DAYS - day + 1) * 7):
		return "手里的钱不多了。"
	if int(state["study_progress"]) < day * 8:
		return "书还欠着几页，今晚也不一定非得熬。"
	return "今天还有些余地。"


func _summary_advice() -> String:
	if day >= GameDataScript.TOTAL_DAYS:
		return "这一周先记到这里，下次想换个什么安排？"
	if int(state["stability"]) <= 25:
		return "余力不多了，明天的安排可以留点空。"
	if int(state["study_progress"]) < day * 9:
		return "复习进度还没跟上，明天看看精力，再安排一段。"
	for meal in today_meal_records:
		if bool(meal.get("skipped", false)):
			return "明天的安排里，可以先给吃饭留个空档。"
	if int(state["balance"]) < max(10, (GameDataScript.TOTAL_DAYS - day) * 8):
		return "手里的钱不多了，明天得算着花。"
	return "今天还算顺。照这个节奏，慢慢来。"


func _record_display_text(record: Dictionary) -> String:
	var meal_name := String(PHASE_NAMES.get(String(record.get("phase", "")), "这一顿"))
	if bool(record.get("skipped", false)):
		return "%s · 没吃" % meal_name
	var names: Array = record.get("food_names", [])
	return "%s · %s · %s" % [meal_name, String(record.get("source_name", "")), "、".join(names)]


func _open_metrics_guide() -> void:
	guide_visible = true
	_rebuild_center()


func _close_metrics_guide() -> void:
	guide_visible = false
	_rebuild_center()


func _request_restart() -> void:
	if day == 1 and today_meal_records.is_empty():
		start_new_run()
		return
	_show_confirmation("重新开始这一周？\n现在的进度不会保留。", start_new_run)


func _request_main_menu() -> void:
	if day == 1 and today_meal_records.is_empty():
		_go_main_menu()
		return
	_show_confirmation("回到主菜单？\n现在的进度不会保留。", _go_main_menu)


func _show_confirmation(message: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.ok_button_text = "确定"
	dialog.cancel_button_text = "再想想"
	dialog.confirmed.connect(func():
		action.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 220))


func _go_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _update_background() -> void:
	var target_path := DEFAULT_BACKGROUND
	if not current_source_id.is_empty():
		var source := _effective_meal_source(current_source_id)
		var configured := String(source.get("background", ""))
		if not configured.is_empty() and ResourceLoader.exists(configured):
			target_path = configured
	if target_path != _current_background_path:
		_current_background_path = target_path
		var texture: Texture2D = load(target_path)
		var tween := create_tween()
		tween.tween_property(background, "modulate:a", 0.25, 0.12)
		tween.tween_callback(func(): background.texture = texture)
		tween.tween_property(background, "modulate:a", 1.0, 0.24)
	if phase.begins_with("breakfast"):
		shade.color = Color(0.10, 0.08, 0.04, 0.30)
	elif phase.begins_with("lunch"):
		shade.color = Color(0.06, 0.08, 0.06, 0.43)
	elif phase.begins_with("dinner"):
		shade.color = Color(0.07, 0.08, 0.12, 0.53)
	else:
		shade.color = Color(0.04, 0.05, 0.10, 0.61)


func _add_log(message: String, tone: String = "neutral") -> void:
	log_entries.push_front("第 %d 天 · %s" % [day, message])
	while log_entries.size() > 20:
		log_entries.pop_back()
	if toast_feed != null and toast_feed.has_method("push_message"):
		toast_feed.call("push_message", message, tone)


func _add_heading(parent: Control, text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size if not portrait_mode else int(font_size * 2.4))
	label.add_theme_color_override("font_color", COLOR_HEADING)
	parent.add_child(label)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _stat_color(key: String, value: int) -> Color:
	if key == "stress":
		if value >= 75:
			return Color(0.79, 0.25, 0.18)
		if value >= 50:
			return Color(0.76, 0.48, 0.16)
		return Color(0.27, 0.52, 0.38)
	if value <= 25:
		return Color(0.79, 0.25, 0.18)
	if value <= 50:
		return Color(0.76, 0.48, 0.16)
	return Color(0.27, 0.52, 0.38)


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style
