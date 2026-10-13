@tool
extends McpTestSuite

const GameDataScript := preload("res://scripts/GameData.gd")
const GameRootV2Script := preload("res://scripts/ui_v2/GameRootV2.gd")
const MealDeckServiceScript := preload("res://scripts/systems/MealDeckService.gd")
const RecoveryService := preload("res://scripts/systems/RecoveryStateService.gd")
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
	assert_eq(int(game.state["study_progress"]), 8)

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
	assert_true(game.summary_payload.has("record_summary"))
	var meal_stamps: Array = game.summary_payload.get("meal_stamps", [])
	assert_eq(meal_stamps.size(), 3)
	assert_eq(String((meal_stamps[0] as Dictionary).get("state", "")), "missing")
	assert_eq(String((meal_stamps[2] as Dictionary).get("state", "")), "eaten")
	assert_contains(String((meal_stamps[2] as Dictionary).get("text", "")), "方便面")
	var visible_summary := (
		String(game.summary_payload.get("record_summary", ""))
		+ "\n"
		+ String((game.summary_payload.get("nutrition", {}) as Dictionary).get("detail_text", ""))
	)
	assert_false(visible_summary.contains("营养评分"))
	assert_false(visible_summary.contains("/100"))
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
	game.run_history.append({"day": 3, "recovery_state": _recovery_record(3, "sleep_early", 40, 50)})
	game._start_day()
	assert_eq(String(game.current_event.get("id", "")), "delivery_coupon")
	assert_eq(int(game._effective_meal_source("takeout")["fee"]), 1)

	game.phase = "breakfast_action"
	var balance_before := int(game.state["balance"])
	var oatmeal_before := int(game.dorm_inventory.get("oatmeal", 0))
	game._apply_action("restock_pantry")
	assert_eq(game.phase, "lunch_source")
	assert_eq(int(game.state["balance"]), balance_before - 8)
	assert_eq(int(game.dorm_inventory.get("oatmeal", 0)), oatmeal_before + 1)
	assert_eq(game.today_action_records.size(), 1)

	game.phase = "lunch_action"
	game._apply_action("restock_pantry")
	assert_eq(game.phase, "lunch_action", "restocking twice in one day must be rejected")
	assert_contains(game._action_disabled_reason(game._effective_action("restock_pantry")), "已经补过")


func test_previous_day_learning_state_changes_visible_study_yield() -> void:
	var game := _new_controller()
	game.phase = "breakfast_action"
	game.run_history.append({"day": 1, "recovery_state": _recovery_record(1, "sleep_early", 40, 50)})
	game.day = 2
	game._start_day()
	game.phase = "breakfast_action"
	var focused := game._effective_action("study")
	assert_eq(int(focused["study"]), 11)
	assert_contains(String(focused["rule_hint"]), "恢复充分")
	var study_card := CompactCardScene.instantiate() as CompactChoiceCardV2
	study_card.configure(focused, "action")
	_add_to_test_tree(study_card)
	assert_eq(study_card.primary_stat.text, "复习 +11")
	game._apply_action("study")
	assert_eq(int(game.state["study_progress"]), 11)

	var tired_game := _new_controller()
	tired_game.phase = "breakfast_action"
	tired_game.run_history.append({"day": 1, "recovery_state": _recovery_record(1, "scroll_phone", 20, 95)})
	tired_game.day = 2
	tired_game._start_day()
	tired_game.phase = "breakfast_action"
	assert_eq(int(tired_game._effective_action("study")["study"]), 4)
	tired_game.state["energy"] = 7
	tired_game._apply_action("study")
	assert_eq(tired_game.phase, "breakfast_action", "study should not run below its energy floor")
	assert_eq(int(tired_game.state["study_progress"]), 0)


func test_normal_starting_budget_can_reach_seventh_day_ending() -> void:
	var game := _new_controller()
	for _day_step in range(GameDataScript.TOTAL_DAYS):
		if game.phase == "ending":
			break
		_play_affordable_study_day(game)
		if game.phase == "summary":
			game._on_summary_advanced()
		if game.day > GameDataScript.TOTAL_DAYS:
			break
	assert_eq(game.day, GameDataScript.TOTAL_DAYS)
	assert_eq(game.phase, "ending")
	assert_true(["stable_endurance", "barely_survived"].has(game.ending_id), "a legal paced route reaches a non-collapse ending")
	assert_gt(int(game.state["balance"]), 0)
	assert_eq(game.today_meal_records.size(), 3)
	assert_eq(game.run_history.size(), GameDataScript.TOTAL_DAYS)
	assert_eq(int(game.run_history[6]["day"]), 7)
	assert_false((game.run_history[6]["nutrition"] as Dictionary).has("score"))
	assert_eq(game.run_history[6]["nutrition"]["metrics"]["eaten_meals"], 3)
	var recap := game._build_week_recap()
	assert_false(String(recap["detail_text"]).contains("｜饮食 "))
	assert_false(recap.has("average_nutrition"))


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
		"TrayDropZone/TrayMargin/VBox/SelectedSlots/Slot1/Face/Preview"
	) as TextureRect
	assert_true(cafeteria_preview.visible, "cafeteria tray must reveal the selected food image")
	assert_true(cafeteria_preview.texture != null, "cafeteria tray preview must have a texture")
	assert_false((cafeteria_preview.get_parent().get_parent().get_node("Empty") as Label).visible)
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
		"Layout/BasketPanel/BasketMargin/Basket/SelectedSlots/Slot1/Face/Preview"
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
		"Layout/BowlPanel/BowlMargin/Bowl/SelectedSlots/Slot1/Face/Preview"
	) as TextureRect).visible, "dorm bowl must reveal the selected food image")
	_assert_scroll_contract(dorm.get_node(
		"Layout/PantryPanel/PantryMargin/Pantry/PantryScroll"
	) as ScrollContainer, false, 1)

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
	assert_false(game.new_day_popup.status_summary.text.contains("昨日"), "a new run has no prior-day record")
	assert_false(game.new_day_popup.status_summary.text.contains("昨天"))
	assert_false(game.new_day_popup.day_subtitle.text.contains("昨天"))
	var initial_learning_state := game.current_learning_state.duplicate(true)
	var initial_game_state := game.state.duplicate(true)
	game._show_new_day_popup()
	assert_eq(game.current_learning_state, initial_learning_state, "initial explanation must not rewrite gameplay carryover")
	assert_eq(game.state, initial_game_state, "reopening first-day instructions must not settle a day")
	assert_true(game.new_day_popup.status_image.visible)
	assert_true(game.new_day_popup.event_image.visible)

	game.day = 5
	var sleep := GameDataScript.get_sleep_option("sleep_early")
	var sleep_snapshot := {"id": "sleep_early"}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		sleep_snapshot[key] = sleep[key]
	var recovery := RecoveryService.settle(4, {"energy": 45, "stress": 45}, sleep_snapshot, {})
	game.run_history.append({"day": 4, "recovery_state": recovery["recovery_state"]})
	assert_true(game._start_day())
	game.current_event = {
		"id": "mock_exam_notice",
		"title": "小测提醒",
		"summary": "群里发来了小测范围。",
	}
	game._show_new_day_popup()
	game.new_day_popup._finish_show()
	assert_eq(game.new_day_popup.status_title.text, "恢复充分")
	assert_contains(game.new_day_popup.status_effect.text, "每次复习收益 +3")
	assert_contains(game.new_day_popup.status_summary.text, "早点睡")
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
	var reference := {}
	for packed in [CafeteriaStageScene, TakeoutStageScene, ConvenienceStageScene, DormStageScene]:
		var stage := packed.instantiate() as MealStageBaseV2
		_add_to_test_tree(stage)
		var paths := stage._get_layout_paths()
		_force_container_layout(stage.get_node(String(paths["footer"])) as Container)
		var area := stage.get_selection_layout_rects()
		var cards: Rect2 = area["cards"]
		var selected_area: Rect2 = area["selection"]
		var footer: Rect2 = area["footer"]
		assert_true(cards.end.y <= selected_area.position.y, "cards must remain above the selected-food panel")
		assert_true(selected_area.position.x > cards.position.x, "selected food must keep the shared lower-right position")
		assert_true(selected_area.end.y <= footer.position.y, "selected food must not cover confirmation")
		assert_true((stage.get_node(String(paths["selection"])) as Control).anchor_left >= 0.40, "selected food must leave the character safe zone")
		if reference.is_empty():
			reference = area
		else:
			for key in ["cards", "selection"]:
				assert_true((area[key] as Rect2).is_equal_approx(reference[key]), "meal sources must share the %s region: %s %s versus %s" % [key, stage.name, area[key], reference[key]])
		var footer_node := stage.get_node(String(paths["footer"])) as Control
		# Headless tests run synchronously; button font/minimum-size changes are
		# queued. Assert the placement contract here, and final geometry in the
		# rendered multi-size probe after layout frames have completed.
		assert_eq(Vector2(footer_node.offset_left, footer_node.offset_top), Vector2(-528, -72))
		assert_eq(Vector2(footer_node.offset_right, footer_node.offset_bottom), Vector2(-18, -12))
	var action := ActionStageScene.instantiate() as ActionStageV2
	assert_eq((action.get_node("Layout/PlannerNote") as Control).anchor_top, MealStageBaseV2.DESKTOP_SELECTED_AREA.position.y)
	assert_eq(
		(action.get_node("Layout/PlannerNote/PlannerMargin/Planner/UsedSlots/Slot1") as Control).custom_minimum_size,
		Vector2(120, 110),
		"action previews must use the same selected-card size"
	)
	action.free()


func test_selected_food_card_keeps_full_face_and_clears_stale_food() -> void:
	for packed in [CafeteriaStageScene, TakeoutStageScene, ConvenienceStageScene, DormStageScene]:
		var stage := packed.instantiate() as MealStageBaseV2
		var options := _cash_options("午餐")
		options["stock_by_id"] = {"rice_plain": 1, "tomato": 1}
		stage.setup(_foods(["rice_plain", "tomato"]), [], options)
		_add_to_test_tree(stage)
		stage._on_card_selected("rice_plain")
		var selected_card := stage._get_slot_nodes()[0] as SelectedFoodCardV2
		assert_true(selected_card.face.visible, "selected food must show a full card face")
		assert_eq(selected_card.title_label.text, String(GameDataScript.get_food("rice_plain")["name"]))
		assert_true(selected_card.preview.texture != null, "selected card must keep its food artwork")
		assert_eq(selected_card.price_label.text, "×1" if stage is DormPantryStageV2 else "¥2")
		stage._on_card_selected("rice_plain")
		assert_true(selected_card.empty_label.visible, "removing food must restore the empty slot")
		assert_false(selected_card.face.visible, "removing food must hide its name and stats")
		assert_true(selected_card.preview.texture == null, "removing food must clear its artwork")
		assert_true(stage._get_confirm_button().disabled, "an empty tray cannot be confirmed")
		stage._on_card_selected("tomato")
		assert_eq(selected_card.title_label.text, String(GameDataScript.get_food("tomato")["name"]))
		assert_false(stage._get_confirm_button().disabled)


func test_selection_colour_survives_availability_refresh_and_deselection() -> void:
	for packed in [CompactCardScene, TakeoutRowScene]:
		var card: Variant = packed.instantiate()
		_add_to_test_tree(card)
		card.configure(GameDataScript.get_food("rice_plain"), "food")
		var initial_tint: Color = card.self_modulate
		var initial_paper: Color = (card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
		card.set_selected(true, false)
		card.set_enabled(true)
		assert_true(card.self_modulate != initial_tint, "selected cards must visibly change colour")
		assert_true((card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color != initial_paper, "selected card paper must remain distinct after refresh")
		card.set_selected(false, false)
		assert_eq(card.self_modulate, initial_tint, "removing food must restore the normal card colour")
		assert_eq((card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, initial_paper)


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
	assert_eq(status_board.offset_top, CharacterHUDV2.MOBILE_STATUS_TOP)
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
	assert_eq(status_board.offset_top, CharacterHUDV2.DESKTOP_STATUS_TOP)
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
		"record_summary": "三餐都吃了，今天先记到这里。",
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


func test_daily_summary_can_expand_explicit_meal_record_detail() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	var popup := game.daily_summary
	popup.show_summary({
		"day": 1,
		"record_summary": "三餐都吃了，今天先记到这里。",
		"advice": "明天继续照预算、时间和口味做选择。",
		"meal_stamps": [
			{"title": "早餐", "text": "食堂 · 白米饭、鸡蛋", "state": "eaten"},
			{"title": "午餐", "text": "便利店 · 苹果", "state": "eaten"},
			{"title": "晚餐", "text": "没吃", "state": "skipped"},
		],
		"detail": {
			"detail_text": "选餐记录\n早餐｜食堂｜白米饭、鸡蛋\n午餐｜便利店｜苹果\n晚餐｜跳过",
			"basis": "成分与份量尚未核对，暂不作营养评价。",
		},
		"stats": {"stability": 64, "study_progress": 10, "balance": 108},
	}, true)
	popup._finish_show()

	assert_true(popup.detail_button.visible)
	assert_false(popup.detail_panel.visible)
	assert_true(popup.meal_trail.visible)
	assert_contains(popup.meal_stamp_labels[0].text, "白米饭")
	assert_contains(popup.meal_stamp_labels[2].text, "没吃")
	assert_eq(popup.detail_button.text, "查看三餐详情")
	popup.detail_button.pressed.emit()
	assert_true(popup.detail_panel.visible)
	assert_eq(popup.detail_button.text, "收起三餐详情")
	assert_contains(popup.detail_label.text, "早餐｜食堂｜白米饭、鸡蛋")
	assert_contains(popup.basis_label.text, "尚未核对")
	assert_false(popup.record_summary_label.text.contains("今日饮食结构记录"))
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.next_button.get_global_rect()),
		"expanded meal records must keep the next-day button inside the paper"
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
			"detail_text": "第 1 天｜进餐记录 3/3｜复习 +10",
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


func test_stale_source_stage_cannot_reopen_or_select_another_meal() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	game.health_guidance_flags = {}
	game.health_history_path = ""
	var breakfast_source := game._active_stage as MealSourceStageV2

	# Emit before a frame boundary, while the outgoing source still exists.
	breakfast_source.skip_requested.emit()
	assert_true(breakfast_source.is_queued_for_deletion())
	var settled_state := game.state.duplicate(true)
	breakfast_source.source_selected.emit("cafeteria")
	game._choose_meal_source("cafeteria")
	assert_eq(game.phase, "breakfast_action")
	assert_eq(game.today_meal_records.size(), 1)
	assert_eq(game.state, settled_state)
	assert_eq(game.current_source_id, "")

	game._skip_action()
	assert_eq(game.phase, "lunch_source")
	var lunch_source := game._active_stage as MealSourceStageV2
	breakfast_source.source_selected.emit("cafeteria")
	breakfast_source.skip_requested.emit()
	assert_eq(game.phase, "lunch_source", "old source must not select the next meal")
	assert_eq(game._active_stage, lunch_source)

	lunch_source.source_selected.emit("cafeteria")
	assert_eq(game.phase, "lunch", "the current source must remain usable")
	lunch_source.source_selected.emit("convenience_store")
	assert_eq(game.current_source_id, "cafeteria")
	game._confirm_food([_first_affordable_food(game)])
	assert_eq(game.phase, "lunch_action")
	assert_eq(game.today_meal_records.size(), 2)
	assert_eq(game.today_meal_records[0]["phase"], "breakfast")
	assert_eq(game.today_meal_records[1]["phase"], "lunch")


func test_pinned_details_survive_other_previews_and_close_without_settlement() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	game.health_history_path = ""
	_add_to_test_tree(game)
	game.new_day_popup.hide()
	var phase_before := game.phase
	var state_before := game.state.duplicate(true)
	var stock_before := game.dorm_inventory.duplicate(true)
	var first_food := GameDataScript.get_food("rice_plain")
	var other_food := GameDataScript.get_food("tomato")
	var anchor := Rect2(40, 100, 210, 330)
	game._show_detail(first_food, anchor, true, "food")
	game._show_detail(other_food, anchor, false, "food")
	game._dismiss_detail("rice_plain")
	assert_true(game.sticky_note.pinned)
	assert_eq(game.sticky_note.get_payload()["id"], "rice_plain")
	game._show_detail(other_food, anchor, true, "food")
	assert_eq(game.sticky_note.get_payload()["id"], "tomato", "explicit information requests can replace pinned details")
	game.sticky_note._on_close_pressed()
	assert_eq(game.phase, phase_before)
	assert_eq(game.state, state_before)
	assert_eq(game.dorm_inventory, stock_before)
	assert_eq(game.today_meal_records.size(), 0)
	assert_eq(game.selected_food_ids.size(), 0)


func test_cash_stages_keep_prices_when_pantry_stock_changes() -> void:
	var cases := [
		{"scene": CafeteriaStageScene, "food": "oatmeal", "fee": 0},
		{"scene": ConvenienceStageScene, "food": "apple", "fee": 0},
		{"scene": TakeoutStageScene, "food": "sandwich", "fee": 3},
	]
	for case in cases:
		var food_id := String(case["food"])
		var food := GameDataScript.get_food(food_id)
		var cost := int(food["cost"])
		var fee := int(case["fee"])
		var stage := (case["scene"] as PackedScene).instantiate() as MealStageBaseV2
		var options := _cash_options("午餐", fee)
		options["stock_by_id"] = {food_id: 2}
		stage.setup([food], [], options)
		_add_to_test_tree(stage)
		var card: Variant = stage._cards_by_id[food_id]
		for inventory in [{food_id: 2}, {food_id: 0}, {}, {food_id: 8}]:
			stage.set_stock(inventory)
			assert_eq(_meal_card_price(card), "¥%d" % cost)
			assert_false(card.select_button.disabled, "pantry stock must not affect cash availability")
		stage._on_card_selected(food_id)
		assert_eq(stage._selection_total(), cost + fee)
		stage.set_selection([])
		stage.set_balance(cost + fee - 1)
		assert_true(card.select_button.disabled, "cash availability still depends on total price")


func test_pantry_cards_show_zero_or_live_stock_instead_of_cash_prices() -> void:
	var stage := DormStageScene.instantiate() as DormPantryStageV2
	stage.setup(_foods(["oatmeal", "milk"]), [], {
		"balance": 0, "stock_by_id": {"oatmeal": 2, "milk": 0},
	})
	_add_to_test_tree(stage)
	var oatmeal: Variant = stage._cards_by_id["oatmeal"]
	var milk: Variant = stage._cards_by_id["milk"]
	assert_eq(_meal_card_price(oatmeal), "×2")
	assert_false(oatmeal.select_button.disabled)
	assert_eq(_meal_card_price(milk), "×0")
	assert_true(milk.select_button.disabled)
	stage.set_stock({"oatmeal": 0, "milk": 3})
	assert_eq(_meal_card_price(oatmeal), "×0")
	assert_true(oatmeal.select_button.disabled)
	assert_eq(_meal_card_price(milk), "×3")
	assert_false(milk.select_button.disabled)
	stage.set_stock({})
	assert_eq(_meal_card_price(oatmeal), "×0", "missing pantry entries must not fall back to cash prices")
	assert_eq(_meal_card_price(milk), "×0")
	assert_true(oatmeal.select_button.disabled)
	assert_true(milk.select_button.disabled)


func test_cash_meal_charges_its_price_without_consuming_pantry_stock() -> void:
	var game := _new_controller()
	game._choose_meal_source("cafeteria")
	# A deterministic legal cafeteria hand isolates the payment contract.
	game.hand = ["oatmeal"]
	game.dorm_inventory["oatmeal"] = 0
	var balance_before := int(game.state["balance"])
	var cost := int(GameDataScript.get_food("oatmeal")["cost"])
	game._confirm_food(["oatmeal"])
	assert_eq(game.phase, "breakfast_action")
	assert_eq(int(game.state["balance"]), balance_before - cost)
	assert_eq(int(game.dorm_inventory["oatmeal"]), 0)
	assert_eq(game.today_meal_records.size(), 1)
	assert_eq(int(game.today_meal_records[0]["total_cost"]), cost)
	assert_false(bool(game.today_meal_records[0]["uses_stock"]))


func _meal_card_price(card: Variant) -> String:
	if card is TakeoutFoodRowCardV2:
		return card.price_label.text
	return card.cost_label.text


func _recovery_record(day: int, id: String, energy: int, stress: int) -> Dictionary:
	var card := GameDataScript.get_sleep_option(id)
	var snapshot := {"id": id}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		snapshot[key] = card[key]
	return RecoveryService.settle(day, {"energy": energy, "stress": stress}, snapshot, {})["recovery_state"]


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


func _assert_scroll_contract(scroll: ScrollContainer, horizontal: bool, visible_mode: int = 3) -> void:
	assert_eq(scroll.scroll_deadzone, 18)
	assert_eq(scroll.horizontal_scroll_mode, visible_mode if horizontal else 0)
	assert_eq(scroll.vertical_scroll_mode, 0 if horizontal else visible_mode)


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
		if game.phase == "ending":
			return
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
		game._apply_action({"breakfast": "study", "lunch": "walk", "dinner": "nap"}[meal])
	assert_eq(game.phase, "sleep")
	game._choose_sleep("sleep_early")
