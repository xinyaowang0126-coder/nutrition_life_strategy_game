@tool
extends McpTestSuite

const GameDataScript := preload("res://scripts/GameData.gd")
const GameRootV2Script := preload("res://scripts/ui_v2/GameRootV2.gd")
const MealDeckServiceScript := preload("res://scripts/systems/MealDeckService.gd")
const GameRootV2Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const SourceStageScene := preload("res://scenes/game_v2/stages/MealSourceStage.tscn")
const CafeteriaStageScene := preload("res://scenes/game_v2/stages/CafeteriaMealStage.tscn")
const TakeoutStageScene := preload("res://scenes/game_v2/stages/TakeoutMealStage.tscn")
const ConvenienceStageScene := preload("res://scenes/game_v2/stages/ConvenienceMealStage.tscn")
const DormStageScene := preload("res://scenes/game_v2/stages/DormPantryStage.tscn")
const ActionStageScene := preload("res://scenes/game_v2/stages/ActionStage.tscn")
const SleepStageScene := preload("res://scenes/game_v2/stages/SleepStage.tscn")
const CompactCardScene := preload("res://scenes/game_v2/components/CompactChoiceCard.tscn")
const TakeoutRowScene := preload("res://scenes/game_v2/components/TakeoutFoodRowCard.tscn")


func suite_name() -> String:
	return "v2_flow"


func suite_setup(_ctx: Dictionary) -> void:
	GameDataScript.ensure_loaded()


func test_source_rules_and_meal_action_transitions() -> void:
	var game := _new_controller()
	game._choose_meal_source("takeout")
	assert_eq(game.phase, "breakfast_source", "takeout must remain closed at breakfast")
	assert_eq(game.current_source_id, "")

	game._choose_meal_source("cafeteria")
	assert_eq(game.phase, "breakfast")
	assert_eq(game.current_source_id, "cafeteria")
	assert_true(game.hand.has("rice_plain"))
	assert_true(game.hand.has("egg"))
	assert_true(game.hand.has("tomato"))

	var opening_balance := int(game.state["balance"])
	game._confirm_food(["rice_plain", "egg", "tomato"])
	assert_eq(game.phase, "breakfast_action")
	assert_eq(game.today_meal_records.size(), 1)
	assert_eq(int(game.state["balance"]), opening_balance - 7)
	assert_true(game.combos_today.has("meal_group_mix"))

	game._apply_action("study")
	assert_eq(game.phase, "lunch_source")
	assert_eq(game.actions_used_today, 1)
	assert_eq(game.used_action_names, ["晨读"])
	assert_eq(int(game.state["study_progress"]), 10)

	game._choose_meal_source("takeout")
	assert_eq(game.phase, "lunch")
	assert_eq(game.current_source_id, "takeout")
	assert_gt(game.hand.size(), 0)
	var affordable := _first_affordable_food(game)
	assert_false(affordable.is_empty(), "takeout hand should include an affordable item")
	game._confirm_food([affordable])
	assert_eq(game.phase, "lunch_action")
	assert_eq(game.today_meal_records.size(), 2)
	game._skip_action()
	assert_eq(game.phase, "dinner_source")


func test_dorm_stock_is_consumed_and_persists_next_day() -> void:
	var game := _new_controller()
	game.phase = "dinner_source"
	var before := int(game.dorm_inventory.get("instant_noodles", 0))
	assert_gt(before, 0)
	game._choose_meal_source("dorm_storage")
	assert_eq(game.phase, "dinner")
	assert_true(game.hand.has("instant_noodles"))
	game._confirm_food(["instant_noodles"])
	assert_eq(game.phase, "dinner_action")
	assert_eq(int(game.dorm_inventory.get("instant_noodles", 0)), before - 1)
	assert_eq(int(game.today_meal_records[0]["total_cost"]), 0)
	assert_true(bool(game.today_meal_records[0]["uses_stock"]))

	game._skip_action()
	assert_eq(game.phase, "sleep")
	game._choose_sleep("sleep_early")
	assert_eq(game.phase, "summary")
	assert_eq(int(game.summary_payload["day"]), 1)
	game._on_summary_advanced()
	assert_eq(game.day, 2)
	assert_eq(game.phase, "breakfast_source")
	assert_eq(game.today_meal_records.size(), 0)
	assert_eq(int(game.dorm_inventory.get("instant_noodles", 0)), before - 1)


func test_source_identity_action_limits_and_pantry_restock_are_enforced() -> void:
	var game := _new_controller()
	assert_eq(game._source_selection_limit("cafeteria"), 3)
	assert_eq(game._source_selection_limit("takeout"), 2)
	assert_eq(game._source_selection_limit("convenience_store"), 2)
	assert_eq(game._source_selection_limit("dorm_storage"), 2)

	game.day = 4
	game._start_day()
	assert_eq(String(game.current_event.get("id", "")), "delivery_coupon")
	assert_eq(int(game._effective_meal_source("takeout")["fee"]), 1)

	game.phase = "breakfast_action"
	var balance_before := int(game.state["balance"])
	var oatmeal_before := int(game.dorm_inventory.get("oatmeal", 0))
	game._apply_action("restock_pantry")
	assert_eq(game.phase, "lunch_source")
	assert_eq(int(game.state["balance"]), balance_before - 10)
	assert_eq(int(game.dorm_inventory.get("oatmeal", 0)), oatmeal_before + 1)
	assert_eq(game.today_action_records.size(), 1)

	game.phase = "lunch_action"
	game._apply_action("restock_pantry")
	assert_eq(game.phase, "lunch_action", "restocking twice in one day must be rejected")
	assert_contains(game._action_disabled_reason(game._effective_action("restock_pantry")), "已经补过")


func test_previous_day_learning_state_changes_visible_study_yield() -> void:
	var game := _new_controller()
	game.phase = "breakfast_action"
	game.current_learning_state = {
		"id": "clear_focus",
		"title": "脑子很清醒",
		"study_modifier": 3,
	}
	var focused := game._effective_action("study")
	assert_eq(int(focused["study"]), 13)
	assert_contains(String(focused["rule_hint"]), "脑子很清醒")
	var study_card := CompactCardScene.instantiate() as CompactChoiceCardV2
	study_card.configure(focused, "action")
	_add_to_test_tree(study_card)
	assert_eq(study_card.primary_stat.text, "复习 +13")
	game._apply_action("study")
	assert_eq(int(game.state["study_progress"]), 13)

	var tired_game := _new_controller()
	tired_game.phase = "breakfast_action"
	tired_game.current_learning_state = {
		"id": "brain_fog",
		"title": "脑子像蒙着一层雾",
		"study_modifier": -4,
	}
	assert_eq(int(tired_game._effective_action("study")["study"]), 6)
	tired_game.state["energy"] = 7
	tired_game._apply_action("study")
	assert_eq(tired_game.phase, "breakfast_action", "study should not run below its energy floor")
	assert_eq(int(tired_game.state["study_progress"]), 0)


func test_normal_starting_budget_can_reach_seventh_day_ending() -> void:
	var game := _new_controller()
	while game.phase != "ending":
		_play_affordable_study_day(game)
		if game.phase == "summary":
			game._on_summary_advanced()
		if game.day > GameDataScript.TOTAL_DAYS:
			break
	assert_eq(game.day, GameDataScript.TOTAL_DAYS)
	assert_eq(game.phase, "ending")
	assert_eq(game.ending_id, "stable_endurance")
	assert_eq(int(game.state["balance"]), 20)
	assert_eq(game.today_meal_records.size(), 3)
	assert_eq(game.run_history.size(), GameDataScript.TOTAL_DAYS)
	assert_eq(int(game.run_history[6]["day"]), 7)
	assert_true((game.run_history[6]["nutrition"] as Dictionary).has("score"))


func test_skipping_everything_can_trigger_early_collapse() -> void:
	var game := _new_controller()
	var guard := 0
	while game.phase != "ending" and guard < 30:
		guard += 1
		match game.phase:
			"breakfast_source", "lunch_source", "dinner_source":
				game._skip_meal()
			"breakfast_action", "lunch_action", "dinner_action":
				game._skip_action()
			"sleep":
				game._choose_sleep("night_study")
			"summary":
				game._on_summary_advanced()
			_:
				break
	assert_eq(game.phase, "ending")
	assert_eq(game.ending_id, "collapsed")
	assert_true(game.day <= GameDataScript.TOTAL_DAYS)


func test_forged_or_empty_meal_confirmation_cannot_advance() -> void:
	var game := _new_controller()
	game._choose_meal_source("cafeteria")
	game._confirm_food([])
	assert_eq(game.phase, "breakfast")
	game._confirm_food(["not_a_food"])
	assert_eq(game.phase, "breakfast")
	assert_eq(game.today_meal_records.size(), 0)


func test_every_v2_stage_reaches_ready_with_real_data() -> void:
	var source_stage := SourceStageScene.instantiate() as MealSourceStageV2
	var sources: Array[Dictionary] = []
	for source_id in GameDataScript.get_meal_source_ids():
		sources.append(GameDataScript.get_meal_source(source_id))
	source_stage.setup(sources, "早餐", {"takeout": "这个时段还没营业。"})
	_add_to_test_tree(source_stage)
	assert_true(source_stage.is_node_ready(), "source stage must enter the tree ready")
	assert_eq(source_stage._sources_by_id.size(), 4)

	var cafeteria := CafeteriaStageScene.instantiate() as CafeteriaMealStageV2
	cafeteria.setup(_foods(["rice_plain", "egg", "tomato"]), [], _cash_options("早餐"))
	_add_to_test_tree(cafeteria)
	assert_true(cafeteria.is_node_ready(), "cafeteria stage must enter the tree ready")
	assert_eq(cafeteria._cards_by_id.size(), 3)
	for card in cafeteria._cards_by_id.values():
		assert_true(card is CompactChoiceCardV2, "cafeteria must use compact choice cards")
	cafeteria._on_card_selected("rice_plain")
	var cafeteria_preview := cafeteria.get_node(
		"TrayDropZone/TrayMargin/VBox/SelectedSlots/Slot1/Preview"
	) as TextureRect
	assert_true(cafeteria_preview.visible, "cafeteria tray must reveal the selected food image")
	assert_true(cafeteria_preview.texture != null, "cafeteria tray preview must have a texture")
	assert_false((cafeteria_preview.get_parent().get_node("Empty") as Label).visible)
	_assert_scroll_contract(cafeteria.get_node("FoodRail") as ScrollContainer, true)

	var takeout := TakeoutStageScene.instantiate() as TakeoutMealStageV2
	takeout.setup(_foods(["sandwich", "bubble_tea"]), [], _cash_options("午餐", 3))
	_add_to_test_tree(takeout)
	assert_true(takeout.is_node_ready(), "takeout stage must enter the tree ready")
	assert_eq(takeout._cards_by_id.size(), 2)
	for card in takeout._cards_by_id.values():
		assert_true(card is TakeoutFoodRowCardV2, "takeout must use its horizontal phone row card")
	takeout._on_card_selected("sandwich")
	assert_eq(takeout.bag_label.text, "购物袋 1/3")
	_assert_scroll_contract(takeout.menu_scroll, false)

	var convenience := ConvenienceStageScene.instantiate() as ConvenienceMealStageV2
	convenience.setup(_foods(["apple", "banana", "milk"]), [], _cash_options("午餐"))
	_add_to_test_tree(convenience)
	assert_true(convenience.is_node_ready(), "convenience stage must enter the tree ready")
	assert_eq(convenience._cards_by_id.size(), 3)
	convenience._on_card_selected("apple")
	assert_true((convenience.get_node(
		"Layout/BasketPanel/BasketMargin/Basket/SelectedSlots/Slot1/Preview"
	) as TextureRect).visible, "convenience basket must reveal the selected food image")
	_assert_scroll_contract(convenience.get_node(
		"Layout/ShelfPanel/ShelfMargin/Shelf/ShelfScroll"
	) as ScrollContainer, true)

	var dorm := DormStageScene.instantiate() as DormPantryStageV2
	dorm.setup(_foods(["oatmeal", "instant_noodles"]), [], {
		"max_selected": 3,
		"balance": 0,
		"meal_label": "晚餐",
		"stock_by_id": {"oatmeal": 1, "instant_noodles": 2},
	})
	_add_to_test_tree(dorm)
	assert_true(dorm.is_node_ready(), "dorm stage must enter the tree ready")
	assert_eq(dorm._cards_by_id.size(), 2)
	assert_eq(dorm._disabled_reason("oatmeal"), "", "available dorm stock must be selectable")
	dorm._on_card_selected("oatmeal")
	assert_eq(dorm._selected_ids, ["oatmeal"], "dorm tap must add available stock to the bowl")
	assert_true((dorm.get_node(
		"Layout/BowlPanel/BowlMargin/Bowl/SelectedSlots/Slot1/Preview"
	) as TextureRect).visible, "dorm bowl must reveal the selected food image")
	_assert_scroll_contract(dorm.get_node(
		"Layout/PantryPanel/PantryMargin/Pantry/PantryScroll"
	) as ScrollContainer, false)

	var action_stage := ActionStageScene.instantiate() as ActionStageV2
	var actions: Array[Dictionary] = []
	for action_id in GameDataScript.get_action_ids_for_scene("breakfast_action"):
		actions.append(GameDataScript.get_action(action_id))
	action_stage.setup(actions, {
		"slots_used": 1,
		"max_slots": 3,
		"used_action_ids": ["study"],
		"used_action_names": ["晨读"],
	})
	_add_to_test_tree(action_stage)
	assert_true(action_stage.is_node_ready(), "action stage must enter the tree ready")
	assert_eq(action_stage._cards_by_id.size(), actions.size())
	assert_true((action_stage.get_node(
		"Layout/PlannerNote/PlannerMargin/Planner/UsedSlots/Slot1/Preview"
	) as TextureRect).visible, "action planner must reveal the arranged action image")
	_assert_scroll_contract(action_stage.action_scroll, true)

	var sleep_stage := SleepStageScene.instantiate() as SleepStageV2
	var sleep_options: Array[Dictionary] = []
	for option_id in GameDataScript.get_sleep_option_ids_for_scene("sleep"):
		sleep_options.append(GameDataScript.get_sleep_option(option_id))
	sleep_stage.setup(sleep_options)
	_add_to_test_tree(sleep_stage)
	assert_true(sleep_stage.is_node_ready(), "sleep stage must enter the tree ready")
	assert_eq(sleep_stage._cards_by_id.size(), sleep_options.size())
	_assert_scroll_contract(sleep_stage.sleep_scroll, true)


func test_touch_contract_tap_swipe_and_long_press() -> void:
	var card := CompactCardScene.instantiate() as CompactChoiceCardV2
	card.configure(GameDataScript.get_food("apple"), "food")
	_add_to_test_tree(card)
	var selections: Array[String] = []
	var details: Array[String] = []
	var dismissals: Array[String] = []
	card.selected.connect(func(item_id: String) -> void: selections.append(item_id))
	card.detail_requested.connect(func(payload: Dictionary, _rect: Rect2, pinned: bool) -> void:
		details.append("%s:%s" % [String(payload.get("id", "")), str(pinned)])
	)
	card.detail_dismissed.connect(func(item_id: String) -> void: dismissals.append(item_id))
	assert_eq(card.long_press_timer.wait_time, 0.48)
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_PASS)

	card._on_gui_input(_touch_event(true, Vector2(20, 20)))
	card._on_gui_input(_mouse_event(false, Vector2(24, 22), InputEvent.DEVICE_ID_EMULATION))
	card._on_gui_input(_touch_event(false, Vector2(24, 22)))
	assert_eq(selections, ["apple"], "emulated mouse plus touch must select exactly once")

	card._on_gui_input(_touch_event(true, Vector2(20, 20)))
	card._on_gui_input(_drag_event(Vector2(72, 20)))
	card._on_gui_input(_mouse_event(false, Vector2(72, 20), InputEvent.DEVICE_ID_EMULATION))
	card._on_gui_input(_touch_event(false, Vector2(72, 20)))
	assert_eq(selections, ["apple"], "a swipe must scroll without selecting")

	card._on_gui_input(_touch_event(true, Vector2(20, 20)))
	card._on_long_press_timeout()
	assert_eq(details, ["apple:false"], "long press should mirror an unpinned desktop hover")
	card._on_gui_input(_touch_event(false, Vector2(20, 20)))
	assert_eq(selections, ["apple"], "long press must not also select")
	assert_eq(dismissals, ["apple"], "releasing a long press should dismiss its preview")
	card._on_gui_input(_mouse_event(false, Vector2(20, 20), 0))
	assert_eq(selections, ["apple", "apple"], "a physical mouse release must still select")

	var row := TakeoutRowScene.instantiate() as TakeoutFoodRowCardV2
	row.configure(GameDataScript.get_food("sandwich"), "food")
	_add_to_test_tree(row)
	assert_eq(row.long_press_timer.wait_time, 0.48)
	assert_eq(row.mouse_filter, Control.MOUSE_FILTER_PASS)
	var row_selections: Array[String] = []
	row.selected.connect(func(item_id: String) -> void: row_selections.append(item_id))
	row._on_gui_input(_touch_event(true, Vector2(30, 30)))
	row._on_gui_input(_mouse_event(false, Vector2(30, 30), InputEvent.DEVICE_ID_EMULATION))
	row._on_gui_input(_touch_event(false, Vector2(30, 30)))
	assert_eq(row_selections, ["sandwich"], "takeout rows must also ignore emulated mouse selection")


func test_v2_root_scene_starts_at_breakfast_source() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	assert_true(game.is_node_ready())
	assert_eq(game.day, 1)
	assert_eq(game.phase, "breakfast_source")
	assert_eq(game.day_label.text, "第 1 天 / 第 7 天")
	assert_eq(game.character_hud.study_value.text, "复习 0/70")
	assert_true(game._active_stage is MealSourceStageV2)
	var hud_font_path := "res://assets/fonts/NotoSansCJKsc-Bold.otf"
	for node_path in [
		"HUD/HUDRoot/TopSafeArea/TopHUD/DayTag/DayLabel",
		"HUD/HUDRoot/TopSafeArea/TopHUD/PhaseTag/PhaseLabel",
		"HUD/HUDRoot/TopSafeArea/TopHUD/BalanceChip/BalanceLabel",
		"HUD/HUDRoot/TopSafeArea/TopHUD/MenuButton",
	]:
		var top_control := game.get_node(node_path) as Control
		assert_eq(
			top_control.get_theme_font("font").resource_path,
			hud_font_path,
			"top HUD fonts must be explicit because CanvasLayer breaks theme inheritance"
		)


func test_new_day_popup_uses_live_state_event_rules_and_art() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	assert_true(game.new_day_popup.visible)
	assert_eq(game.new_day_popup.day_title.text, "第 1 天开始")
	assert_true(game.new_day_popup.status_image.visible)
	assert_true(game.new_day_popup.event_image.visible)

	game.day = 5
	game.current_learning_state = {
		"id": "clear_focus",
		"title": "脑子很清醒",
		"summary": "三餐接住了，昨晚也睡得早。",
		"study_modifier": 3,
	}
	game.current_event = {
		"id": "mock_exam_notice",
		"title": "小测提醒",
		"summary": "群里发来了小测范围。",
	}
	game._show_new_day_popup()
	game.new_day_popup._finish_show()
	assert_eq(game.new_day_popup.status_title.text, "脑子很清醒")
	assert_eq(game.new_day_popup.status_effect.text, "每次学习效果 +3")
	assert_eq(game.new_day_popup.event_title.text, "小测提醒")
	assert_contains(game.new_day_popup.event_effect.text, "复习收益 +3")
	assert_eq(
		game.new_day_popup.status_image.texture.resource_path,
		"res://assets/generated/ui_v2/day_popup/states/clear_focus.png"
	)
	assert_eq(
		game.new_day_popup.event_image.texture.resource_path,
		"res://assets/generated/ui_v2/day_popup/events/mock_exam_notice.png"
	)
	assert_eq(game.new_day_popup.cards_grid.columns, 2)
	game.new_day_popup.set_mobile_mode(true)
	assert_eq(game.new_day_popup.cards_grid.columns, 1)
	assert_true(
		game.new_day_popup.paper_host.get_global_rect().encloses(
			game.new_day_popup.continue_button.get_global_rect()
		),
		"new-day continue button must remain inside the modal on mobile"
	)


func test_desktop_stage_panels_leave_character_safe_zone() -> void:
	var cafeteria := CafeteriaStageScene.instantiate() as CafeteriaMealStageV2
	assert_true(is_equal_approx((cafeteria.get_node("TrayDropZone") as Control).anchor_left, 0.44))
	assert_eq(
		(cafeteria.get_node("TrayDropZone/TrayMargin/VBox/SelectedSlots/Slot1") as Control).custom_minimum_size,
		Vector2(132, 170)
	)
	var takeout := TakeoutStageScene.instantiate() as TakeoutMealStageV2
	assert_true(is_equal_approx((takeout.get_node("Layout/PhoneShell") as Control).anchor_left, 0.58))
	var convenience := ConvenienceStageScene.instantiate() as ConvenienceMealStageV2
	assert_true(is_equal_approx((convenience.get_node("Layout/BasketPanel") as Control).anchor_left, 0.43))
	var dorm := DormStageScene.instantiate() as DormPantryStageV2
	assert_true(is_equal_approx((dorm.get_node("Layout/PantryPanel") as Control).anchor_bottom, 0.70))
	var action := ActionStageScene.instantiate() as ActionStageV2
	assert_true(is_equal_approx((action.get_node("Layout/PlannerNote") as Control).anchor_top, 0.68))
	assert_eq(
		(action.get_node("Layout/PlannerNote/PlannerMargin/Planner/UsedSlots/Slot1") as Control).custom_minimum_size,
		Vector2(150, 120),
		"desktop action previews must remain legible"
	)
	for node in [cafeteria, takeout, convenience, dorm, action]:
		node.free()


func test_mobile_baseline_is_720_by_1280_without_forcing_desktop_window() -> void:
	assert_eq(
		int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)),
		0,
		"the checked-in project must not force the desktop window to mobile width"
	)
	assert_eq(
		int(ProjectSettings.get_setting("display/window/size/window_height_override", 0)),
		0,
		"the checked-in project must not force the desktop window to mobile height"
	)
	var controller_source := FileAccess.get_file_as_string("res://scripts/ui_v2/GameRootV2.gd")
	assert_contains(
		controller_source,
		"Vector2i(720, 1280)",
		"mobile content scale must use the 720×1280 baseline"
	)


func test_v2_theme_bundles_chinese_font_for_web() -> void:
	var ui_theme := load("res://scenes/game_v2/V2Theme.tres") as Theme
	assert_true(ui_theme != null)
	assert_true(ui_theme.default_font != null, "V2 theme must not depend on an OS fallback font")
	assert_eq(
		ui_theme.default_font.resource_path,
		"res://assets/fonts/NotoSansCJKsc-Bold.otf",
		"the bundled static bold Chinese font must be used by desktop and Web exports"
	)
	assert_true(ui_theme.default_font is FontFile)
	assert_eq(ui_theme.get_font("font", "Label"), ui_theme.default_font)
	assert_eq(ui_theme.get_font("font", "Button"), ui_theme.default_font)


func test_character_hud_mobile_profile_keeps_footer_clear_and_clickable() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	game._mobile_mode = true
	game._apply_shell_profile()

	var status_board := game.character_hud.status_board
	assert_eq(game.character_hud.portrait.offset_left, -92.0)
	assert_eq(game.character_hud.portrait.offset_right, 338.0)
	assert_eq(game.character_hud.portrait_shadow.offset_left, -80.0)
	assert_eq(
		game.character_hud.portrait.texture.resource_path,
		"res://assets/generated/ui_v2/characters/student_bust.png",
		"mobile layout must move the original texture node instead of cropping the image"
	)
	assert_eq(status_board.offset_top, -250.0)
	assert_eq(status_board.offset_bottom, -20.0)
	assert_eq(game.character_hud.pivot_offset.y, game.character_anchor.size.y)
	assert_eq(status_board.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node in status_board.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_ne(game.character_hud.details_button.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	# The stage reserves 225 logical pixels at the bottom.  The mobile board may
	# visually overlap that boundary by a small amount, but its whole subtree is
	# input-transparent so the footer remains actionable.
	var anchor_height := game.character_anchor.size.y
	var local_board_top := anchor_height + status_board.offset_top
	var visual_board_top := (
		game.character_hud.pivot_offset.y
		+ (local_board_top - game.character_hud.pivot_offset.y)
		* game.character_hud.scale.y
	)
	var board_top_distance_from_bottom := anchor_height - visual_board_top
	assert_true(
		board_top_distance_from_bottom - 225.0 <= 32.0,
		"mobile status board extends too far into the stage: %.1f px" % (
			board_top_distance_from_bottom - 225.0
		)
	)

	game._mobile_mode = false
	game._apply_shell_profile()
	assert_eq(game.character_hud.portrait.offset_left, 0.0)
	assert_eq(game.character_hud.portrait_shadow.offset_left, 12.0)
	assert_eq(status_board.offset_top, -310.0)
	assert_eq(status_board.offset_bottom, -90.0)
	assert_eq(game.character_hud.pivot_offset, Vector2.ZERO)
	assert_ne(status_board.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_mobile_daily_summary_is_compact_and_actionable() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	var popup := game.daily_summary
	var advance_events: Array[String] = []
	popup.next_day_requested.connect(func() -> void: advance_events.append("next"))
	popup.show_summary({
		"day": 1,
		"title": "第 1 天，过去了",
		"quality": "三顿饭都接住了。",
		"advice": "今天先放到这里，剩下的交给明天。",
		"stats": {
			"stability": 64,
			"study_progress": 10,
			"balance": 108,
		},
	}, true)
	popup._finish_show()

	assert_true(popup.visible, "mobile daily summary should be visible")
	assert_eq(popup.paper_host.size.y, 480.0, "mobile paper host must stay compact")
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.next_button.get_global_rect()),
		"next-day button should remain inside the clipped paper host"
	)
	assert_true(popup.next_button.is_visible_in_tree(), "next-day button should be visible")
	assert_false(popup.next_button.disabled, "next-day button should be enabled")
	assert_ne(
		popup.next_button.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"next-day button must receive pointer input"
	)
	assert_true(
		popup.next_button.get_combined_minimum_size().y >= 48.0,
		"next-day touch target should be at least 48px"
	)

	popup.next_button.pressed.emit()
	assert_eq(advance_events.size(), 1, "pressing next-day should emit exactly once")


func test_daily_summary_can_expand_optional_nutrition_detail() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	var popup := game.daily_summary
	popup.show_summary({
		"day": 1,
		"quality": "三餐都接住了，其中 1 顿的餐盘构成比较完整。",
		"advice": "下一餐可以补一份蔬菜。",
		"nutrition": {
			"detail_text": "进餐规律：已进餐 3/3 餐\n食物类别分布：谷薯类、蔬菜类、蛋类\n重点营养素来源：膳食纤维、优质蛋白质",
			"basis": "依据膳食指南进行游戏化反馈，仅用于健康教育。",
		},
		"stats": {"stability": 64, "study_progress": 10, "balance": 108},
	}, true)
	popup._finish_show()

	assert_true(popup.detail_button.visible)
	assert_false(popup.detail_panel.visible)
	assert_eq(popup.detail_button.text, "查看今日膳食记录")
	popup.detail_button.pressed.emit()
	assert_true(popup.detail_panel.visible)
	assert_eq(popup.detail_button.text, "收起膳食记录")
	assert_contains(popup.detail_label.text, "重点营养素来源")
	assert_contains(popup.basis_label.text, "仅用于健康教育")
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.next_button.get_global_rect()),
		"expanded nutrition detail must keep the next-day button inside the paper"
	)


func test_ending_summary_shows_art_and_week_recap() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	var popup := game.daily_summary
	popup.show_summary({
		"day": 7,
		"title": "稳稳到了周末",
		"layout": "ending",
		"ending_image": "res://assets/generated/endings/stable_endurance.png",
		"detail_button_text": "查看本周轨迹",
		"detail_button_open_text": "收起本周轨迹",
		"detail": {
			"detail_text": "第 1 天｜饮食 72｜复习 +10",
			"basis": "由七天记录生成。",
		},
		"stats": {"stability": 64, "study_progress": 70, "study_target": 70, "balance": 20},
	}, true)
	popup._finish_show()
	assert_true(popup.ending_image.visible)
	assert_eq(popup.ending_image.texture.resource_path, "res://assets/generated/endings/stable_endurance.png")
	assert_eq(popup.study_value.text, "复习 70/70")
	assert_eq(popup.detail_button.text, "查看本周轨迹")
	popup.detail_button.pressed.emit()
	assert_eq(popup.detail_button.text, "收起本周轨迹")
	assert_contains(popup.detail_label.text, "第 1 天")
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.next_button.get_global_rect()),
		"expanded week recap must keep the replay button inside the paper"
	)


func test_rapid_repeat_inputs_do_not_double_advance_or_settle() -> void:
	var game := _new_controller()
	game._skip_meal()
	assert_eq(game.phase, "breakfast_action")
	assert_eq(game.today_meal_records.size(), 1)
	game._skip_meal()
	assert_eq(game.phase, "breakfast_action")
	assert_eq(game.today_meal_records.size(), 1)

	game._skip_action()
	assert_eq(game.phase, "lunch_source")
	game._skip_action()
	assert_eq(game.phase, "lunch_source")

	game._choose_meal_source("cafeteria")
	game._change_meal_source()
	assert_eq(game.phase, "lunch_source")
	game._change_meal_source()
	assert_eq(game.phase, "lunch_source")

	game.phase = "sleep"
	game._choose_sleep("sleep_early")
	assert_eq(game.phase, "summary")
	var settled_state := game.state.duplicate(true)
	game._choose_sleep("sleep_early")
	assert_eq(game.state, settled_state)

	game._on_summary_advanced()
	assert_eq(game.day, 2)
	assert_eq(game.phase, "breakfast_source")
	game._on_summary_advanced()
	assert_eq(game.day, 2)
	assert_eq(game.phase, "breakfast_source")


func _new_controller() -> GameRootV2:
	var game := GameRootV2Script.new() as GameRootV2
	track(game)
	game.state = GameDataScript.get_starting_stats()
	game.day = 1
	game.low_stability_days = 0
	game.dorm_inventory = GameDataScript.get_initial_dorm_inventory()
	game.ending_id = ""
	game._deck_service = MealDeckServiceScript.new(20260711)
	game._start_day()
	return game


func _first_affordable_food(game: GameRootV2) -> String:
	var source := GameDataScript.get_meal_source(game.current_source_id)
	var fee := int(source.get("fee", 0))
	for food_id in game.hand:
		if int(GameDataScript.get_food(food_id).get("cost", 0)) + fee <= int(game.state["balance"]):
			return food_id
	return ""


func _foods(ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for food_id in ids:
		result.append(GameDataScript.get_food(food_id))
	return result


func _cash_options(meal_label: String, fee: int = 0) -> Dictionary:
	return {
		"max_selected": 3,
		"source_fee": fee,
		"balance": 120,
		"payment_mode": "cash",
		"meal_label": meal_label,
	}


func _assert_scroll_contract(scroll: ScrollContainer, horizontal: bool) -> void:
	assert_eq(scroll.scroll_deadzone, 18)
	assert_eq(scroll.horizontal_scroll_mode, 3 if horizontal else 0)
	assert_eq(scroll.vertical_scroll_mode, 0 if horizontal else 3)


func _touch_event(
	pressed: bool,
	position: Vector2,
	index: int = 0,
	canceled: bool = false
) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	event.index = index
	event.canceled = canceled
	return event


func _drag_event(position: Vector2, index: int = 0) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.position = position
	event.index = index
	return event


func _mouse_event(pressed: bool, position: Vector2, device: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.device = device
	return event


func _add_to_test_tree(node: Node) -> void:
	track(node)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(node)


func _force_container_layout(container: Container) -> void:
	container.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in container.get_children():
		if child is Container:
			_force_container_layout(child as Container)


func _play_affordable_study_day(game: GameRootV2) -> void:
	for meal in ["breakfast", "lunch", "dinner"]:
		assert_eq(game.phase, "%s_source" % meal)
		game._choose_meal_source("cafeteria")
		var preferred: Array[String]
		if meal == "breakfast":
			preferred = ["rice_plain", "egg", "tomato", "mixed_grain_rice"]
		else:
			preferred = ["rice_plain", "tofu", "greens", "tomato", "mixed_grain_rice"]
		var plate: Array[String] = []
		for food_id in preferred:
			if game.hand.has(food_id) and game._selected_meal_total(food_id) <= int(game.state["balance"]):
				plate.append(food_id)
			if plate.size() >= 2:
				break
		if plate.is_empty():
			plate.append(_first_affordable_food(game))
		game._confirm_food(plate)
		assert_eq(game.phase, "%s_action" % meal)
		game._apply_action("study")
	assert_eq(game.phase, "sleep")
	game._choose_sleep("sleep_early")
