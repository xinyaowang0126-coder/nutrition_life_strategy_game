@tool
extends McpTestSuite

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Legacy := preload("res://scripts/GameRoot.gd")
const Data := preload("res://scripts/GameData.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Balance := preload("res://scripts/systems/GameplayBalanceRules.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Rules := preload("res://scripts/systems/RecoveryRules.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")


func suite_name() -> String:
	return "gameplay_balance"


func test_water_is_limited_auxiliary_input_without_food_or_time_gain() -> void:
	var game := _game()
	game.phase = "breakfast_action"
	var before := game.state.duplicate(true)
	game._apply_action("drink_water")
	game._apply_action("drink_water")
	assert_eq(game.phase, "breakfast_action")
	assert_eq(game.actions_used_today, 0)
	assert_eq(game.today_period_records.size(), 0)
	assert_eq(game.state["satiety"], before["satiety"])
	assert_eq(game.state["energy"], before["energy"])
	assert_eq(game.state["stress"], before["stress"] - 2)
	assert_true(game.used_action_names.is_empty())
	var after := game.state.duplicate(true)
	game._apply_action("drink_water")
	assert_eq(game.state, after)
	assert_eq(game.today_action_records.size(), 2)
	game._apply_action("study")
	assert_eq(game.phase, "lunch_source")
	assert_eq(game.actions_used_today, 1)
	assert_eq(game.used_action_names, ["晨读"])


func test_auxiliary_water_and_three_main_actions_form_a_valid_frozen_day() -> void:
	var game := _game()
	game.phase = "breakfast_action"
	game._apply_action("drink_water")
	game._apply_action("drink_water")
	for phase_name in ["breakfast_action", "lunch_action", "dinner_action"]:
		game.phase = phase_name
		game._apply_action("study")
	assert_eq(game.actions_used_today, 3)
	assert_eq(game.today_action_records.size(), 5)
	assert_eq(game.today_period_records.size(), 3)
	game._choose_sleep("sleep_early")
	var frozen := game.get_pending_recovery_state()
	assert_true(Recovery.validate(frozen)["valid"])
	assert_eq(frozen["inputs"]["action_counts"], {"study": 3, "drink_water": 2})
	assert_eq(frozen["condition"], "depleted", "water cannot hide an exhausting schedule")
	assert_false(Rules.evaluate({"energy": 60, "stress": 40, "sleep_id": "sleep_early", "action_counts": {"study": 3, "nap": 1, "drink_water": 2}})["valid"])


func test_skipping_still_passes_one_period_and_stale_advance_cannot_repeat_it() -> void:
	var game := _game()
	game.phase = "breakfast_action"
	game._skip_action()
	assert_eq(game.state["energy"], 52)
	assert_eq(game.state["satiety"], 20)
	assert_eq(game.state["stress"], 50)
	assert_eq(game.today_period_records.size(), 1)
	assert_eq(game.actions_used_today, 0)
	var after := game.state.duplicate(true)
	game._advance_after_action()
	assert_eq(game.state, after)
	assert_eq(game.today_period_records.size(), 1)


func test_leave_time_has_a_time_cost_without_erasing_learned_progress() -> void:
	var game := _game()
	game.state["study_progress"] = 25
	game.phase = "breakfast_action"
	game._apply_action("allow_imperfection")
	assert_eq(game.state["study_progress"], 25)
	assert_eq(game.state["energy"], 56)
	assert_eq(game.state["stress"], 38)
	assert_eq(game.phase, "lunch_source")
	assert_eq(game.actions_used_today, 1)


func test_study_hunger_penalty_has_an_exact_boundary_and_combines_with_fatigue() -> void:
	assert_eq(Balance.study_penalty({"energy": 25, "stress": 69, "satiety": 20})["modifier"], 0)
	assert_eq(Balance.study_penalty({"energy": 25, "stress": 69, "satiety": 19})["modifier"], -2)
	var result := Balance.study_penalty({"energy": 24, "stress": 70, "satiety": 19})
	assert_eq(result["modifier"], -7)
	assert_eq(result["reasons"], ["精力偏低", "压力偏高", "饱腹偏低"])


func test_initial_reserve_matches_the_game_formula_without_a_first_meal_drop() -> void:
	var start := Data.get_starting_stats()
	assert_eq(Resolver.calculate_stability(start, 20, 1, 7, 7), start["stability"])
	var game := _game()
	game.source_hands["breakfast:cafeteria"] = ["rice_plain", "egg", "tomato"]
	game._choose_meal_source("cafeteria")
	game._confirm_food(["rice_plain", "egg"])
	assert_gt(game.state["stability"], start["stability"])


func test_diet_quality_and_plate_composition_cannot_grant_resource_bonuses() -> void:
	var low := _settlement_game(20)
	var high := _settlement_game(95)
	for game in [low, high]:
		game._choose_sleep("sleep_early")
	assert_eq(low.state, high.state)
	assert_eq(low.get_pending_recovery_state(), high.get_pending_recovery_state())
	assert_eq(Resolver.calculate_stability(high.state, 20, 1, 7, 10), Resolver.calculate_stability(high.state, 95, 1, 7, 10))
	var before := high.state.duplicate(true)
	high.combos_today.clear()
	high._check_meal_combos(high.today_meal_records[0])
	assert_eq(high.state, before, "a composition badge has no extra energy or mood gain")


func test_insufficient_food_has_a_recorded_cost_and_price_bonus_requires_a_meal() -> void:
	var game := _settlement_game(70)
	game.state["satiety"] = 18
	game._choose_sleep("sleep_early")
	var frozen := game.get_pending_recovery_state()
	assert_true(Recovery.validate(frozen)["valid"])
	assert_eq(frozen["after_sleep"]["energy"], 82)
	assert_eq(frozen["end_of_day"]["energy"], 74)
	assert_eq(frozen["settlement_effects"][0]["source_id"], "low_satiety")
	var drinks := _game()
	for phase_name in ["breakfast", "lunch", "dinner"]:
		drinks.today_meal_records.append(Resolver.build_record(phase_name, {}, [Data.get_food("coffee")]))
	drinks._check_meal_combos(drinks.today_meal_records.back())
	assert_false(drinks.combos_today.has("budget_saver"))
	var starved := {"energy": 100, "mood": 100, "stress": 0, "satiety": 0, "study_progress": 100, "balance": 150}
	starved["stability"] = Resolver.calculate_stability(starved, 95, 7, 7, 10)
	assert_eq(starved["stability"], 55)
	assert_ne(Resolver.select_ending(starved), "stable_endurance", "other full bars cannot hide an empty satiety bar")


func test_final_night_study_can_finish_a_gap_with_a_visible_recovery_cost() -> void:
	var game := _settlement_game(70)
	game.day = 7
	game.state.merge({"energy": 80, "satiety": 60, "study_progress": 60}, true)
	game._choose_sleep("night_study")
	assert_eq(game.state["study_progress"], 70)
	assert_eq(game.state["energy"], 86)
	assert_eq(game.get_pending_recovery_state()["condition"], "strained")
	assert_eq(game.ending_id, "stable_endurance")


func test_v1_and_v2_apply_the_same_period_and_auxiliary_water_rules() -> void:
	var current := _game()
	var legacy := Legacy.new()
	track(legacy)
	legacy._deck_service = Deck.new(0)
	legacy.start_new_run()
	for game in [current, legacy]:
		game.phase = "breakfast_action"
		game._apply_action("drink_water")
		game._apply_action("study")
	assert_eq(current.state, legacy.state)
	assert_eq(current.actions_used_today, legacy.actions_used_today)
	assert_eq(current.phase, legacy.phase)


func test_rendered_water_button_keeps_the_planner_free_and_updates_its_limit() -> void:
	var game := Scene.instantiate() as GameRootV2
	track(game)
	game.health_history_path = ""
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	game.new_day_popup.hide_popup(false)
	game.phase = "breakfast_action"
	game._render_phase()
	var stage := game._active_stage as ActionStageV2
	stage._on_action_pressed("drink_water")
	stage = game._active_stage as ActionStageV2
	assert_eq(stage.slots_label.text, "安排 0/3")
	assert_eq(stage.water_count_label.text, "水杯 1/2")
	assert_eq(game.phase, "breakfast_action")
	stage._on_action_pressed("drink_water")
	stage = game._active_stage as ActionStageV2
	assert_eq(stage.water_count_label.text, "水杯 2/2")
	assert_false(stage._items.filter(func(item: Dictionary) -> bool: return item["id"] == "drink_water")[0]["enabled"])
	stage._on_action_pressed("study")
	assert_eq(game.phase, "lunch_source")
	assert_eq(game.used_action_names, ["晨读"])


func _game() -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game._deck_service = Deck.new(0)
	game.start_new_run()
	return game


func _settlement_game(quality: int) -> GameRootV2:
	var game := _game()
	game.state.merge({"energy": 60, "stress": 40, "mood": 60, "satiety": 50, "study_progress": 70}, true)
	for phase_name in ["breakfast", "lunch", "dinner"]:
		var record := Resolver.build_record(phase_name, Data.get_meal_source("cafeteria"), [Data.get_food("rice_plain"), Data.get_food("egg"), Data.get_food("tomato")])
		record["quality"] = quality
		game.today_meal_records.append(record)
	game.phase = "sleep"
	return game
