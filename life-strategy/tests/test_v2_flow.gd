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
	assert_true(game.combos_today.has("balanced_plate"))

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
	assert_eq(int(game.state["balance"]), 22)
	assert_eq(game.today_meal_records.size(), 3)


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
	assert_true(source_stage.is_node_ready())
	assert_eq(source_stage._sources_by_id.size(), 4)

	var cafeteria := CafeteriaStageScene.instantiate() as CafeteriaMealStageV2
	cafeteria.setup(_foods(["rice_plain", "egg", "tomato"]), [], _cash_options("早餐"))
	_add_to_test_tree(cafeteria)
	assert_true(cafeteria.is_node_ready())
	assert_eq(cafeteria._cards_by_id.size(), 3)

	var takeout := TakeoutStageScene.instantiate() as TakeoutMealStageV2
	takeout.setup(_foods(["sandwich", "bubble_tea"]), [], _cash_options("午餐", 3))
	_add_to_test_tree(takeout)
	assert_true(takeout.is_node_ready())
	assert_eq(takeout._cards_by_id.size(), 2)

	var convenience := ConvenienceStageScene.instantiate() as ConvenienceMealStageV2
	convenience.setup(_foods(["apple", "banana", "milk"]), [], _cash_options("午餐"))
	_add_to_test_tree(convenience)
	assert_true(convenience.is_node_ready())
	assert_eq(convenience._cards_by_id.size(), 3)

	var dorm := DormStageScene.instantiate() as DormPantryStageV2
	dorm.setup(_foods(["oatmeal", "instant_noodles"]), [], {
		"max_selected": 3,
		"balance": 0,
		"meal_label": "晚餐",
		"stock_by_id": {"oatmeal": 1, "instant_noodles": 2},
	})
	_add_to_test_tree(dorm)
	assert_true(dorm.is_node_ready())
	assert_eq(dorm._cards_by_id.size(), 2)

	var action_stage := ActionStageScene.instantiate() as ActionStageV2
	var actions: Array[Dictionary] = []
	for action_id in GameDataScript.get_action_ids_for_scene("breakfast_action"):
		actions.append(GameDataScript.get_action(action_id))
	action_stage.setup(actions, {"slots_used": 0, "max_slots": 3})
	_add_to_test_tree(action_stage)
	assert_true(action_stage.is_node_ready())
	assert_eq(action_stage._cards_by_id.size(), actions.size())

	var sleep_stage := SleepStageScene.instantiate() as SleepStageV2
	var sleep_options: Array[Dictionary] = []
	for option_id in GameDataScript.get_sleep_option_ids_for_scene("sleep"):
		sleep_options.append(GameDataScript.get_sleep_option(option_id))
	sleep_stage.setup(sleep_options)
	_add_to_test_tree(sleep_stage)
	assert_true(sleep_stage.is_node_ready())
	assert_eq(sleep_stage._cards_by_id.size(), sleep_options.size())


func test_v2_root_scene_starts_at_breakfast_source() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	assert_true(game.is_node_ready())
	assert_eq(game.day, 1)
	assert_eq(game.phase, "breakfast_source")
	assert_eq(game.day_label.text, "第 1 天 / 第 7 天")
	assert_true(game._active_stage is MealSourceStageV2)


func test_mobile_baseline_is_720_by_1280() -> void:
	assert_eq(
		int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)),
		720,
		"mobile QA window width must stay at 720"
	)
	assert_eq(
		int(ProjectSettings.get_setting("display/window/size/window_height_override", 0)),
		1280,
		"mobile QA window height must stay at 1280 (9:16)"
	)
	var controller_source := FileAccess.get_file_as_string("res://scripts/ui_v2/GameRootV2.gd")
	assert_contains(
		controller_source,
		"Vector2i(720, 1280)",
		"mobile content scale must use the 720×1280 baseline"
	)


func test_character_hud_mobile_profile_keeps_footer_clear_and_clickable() -> void:
	var game := GameRootV2Scene.instantiate() as GameRootV2
	_add_to_test_tree(game)
	game._mobile_mode = true
	game._apply_shell_profile()

	var status_board := game.character_hud.status_board
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
		var plate: Array[String]
		if meal == "breakfast":
			plate = ["rice_plain", "egg"]
		else:
			plate = ["rice_plain", "tofu"]
		game._confirm_food(plate)
		assert_eq(game.phase, "%s_action" % meal)
		game._apply_action("study")
	assert_eq(game.phase, "sleep")
	game._choose_sleep("sleep_early")
