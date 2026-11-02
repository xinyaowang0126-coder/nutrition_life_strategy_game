@tool
extends McpTestSuite

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Week := preload("res://scripts/stories/CampusWeek.gd")
const Learning := preload("res://scripts/stories/CampusMealLearning.gd")
const Presenter := preload("res://scripts/stories/CampusPresenter.gd")
const Cards := preload("res://scripts/CardDataStore.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Session := preload("res://scripts/stories/StorySession.gd")
const Flags := preload("res://scripts/health/HealthGuidanceFeatureFlags.gd")


func suite_name() -> String:
	return "campus_week"


func _game(seed_value: int = 42, story_id: String = "campus_exam") -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.story_id = story_id
	game._deck_service = Deck.new(seed_value)
	game.health_history_path = ""
	game.start_new_run()
	return game


func _ui(size: Vector2i = Vector2i(1280, 720), story_id: String = "campus_exam") -> GameRootV2:
	var viewport := SubViewport.new()
	viewport.size = size
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	Session.request(story_id)
	var game := Scene.instantiate() as GameRootV2
	viewport.add_child(game)
	game.new_day_popup.hide_popup(false)
	game._on_new_day_continue()
	return game


func _pick(game: GameRootV2) -> Array[String]:
	game._choose_meal_source("cafeteria")
	var plate: Array[String] = []
	for id in ["rice_plain", "oatmeal", "egg", "tofu", "greens"]:
		if game.hand.has(id) and plate.size() < game._source_selection_limit("cafeteria"):
			plate.append(id)
	if plate.is_empty() and not game.hand.is_empty(): plate.append(game.hand[0])
	return plate


func _day(game: GameRootV2) -> void:
	for meal in ["breakfast", "lunch", "dinner"]:
		if game._new_day_pending:
			game.new_day_popup.hide_popup(false)
			game._on_new_day_continue()
		var plate := _pick(game)
		if plate.is_empty(): game._skip_meal()
		else: game._confirm_food(plate)
		var action: String = {"breakfast": "study", "lunch": "walk", "dinner": "nap"}[meal]
		if game._can_use_action(game._effective_action(action)): game._apply_action(action)
		else: game._skip_action()
	game._choose_sleep("sleep_early")


func test_menu_ingredients_are_deduplicated_and_unspecified_items_stay_unknown() -> void:
	var f := Learning.facts(["egg", "tomato_egg_stir_fry", "rice_plain"])
	assert_eq(f["ingredients"], ["egg", "tomato", "rice"])
	assert_eq(f["unrecorded"], [])
	var missing := Learning.facts(["plain_yogurt", "bubble_tea"])
	assert_true(missing["ingredients"].is_empty())
	assert_eq(missing["unrecorded"], ["plain_yogurt", "bubble_tea"])
	assert_contains(Learning.food_note("plain_yogurt"), "未写明")
	assert_false(Learning.food_note("plain_yogurt").contains("添加糖0"))
	assert_false(Learning.valid_facts({"version": 1, "ingredients": ["rice"], "unrecorded": []}, ["egg"]))
	Cards.ensure_loaded()
	for id in Learning._items:
		assert_true(Cards.foods.has(id))
		assert_false(Learning._items[id].is_empty())
		for ingredient in Learning._items[id]: assert_true(Learning._ingredients.has(ingredient))
	var c := Learning.context(1, "breakfast", "cafeteria", ["egg"], Cards.foods)
	c["food_names"] = ["旧菜单上保存的名称"]
	assert_true(Learning.valid_context(c, Cards.foods, Cards.meal_sources), "frozen display names must survive later copy changes")


func test_event_variants_are_stable_and_match_the_previous_evenings_forecast() -> void:
	var a := Week.initial_state(42)
	var b := Week.initial_state(43)
	assert_eq(Week.limited_meal(a), "lunch")
	assert_eq(Week.limited_meal(b), "dinner")
	assert_eq(Week.peer_phase(a), "lunch_action")
	assert_eq(Week.peer_phase(b), "dinner_action")
	for value in [a, b]:
		for day in [3, 5, 6]:
			var event := Week.event(day, value)
			var preview := Week.preview(day - 1, value)
			assert_eq(preview["summary"], event["preview"])
			assert_eq(preview["event_id"], event["id"])
	assert_eq(Week.event(3, a), Week.event(3, Week.initial_state(42)))
	assert_true(Week.preview(7, a).is_empty())


func test_cafeteria_maintenance_changes_only_the_announced_meal_and_has_alternatives() -> void:
	var game := _game()
	game.day = 3
	game.phase = "lunch_source"
	game.source_hands.clear()
	var before: Dictionary = game._deck_service.capture_state()
	assert_eq(game._effective_meal_source("cafeteria")["selection_limit"], 2)
	assert_eq(game._source_disabled_reason("convenience_store", "lunch"), "")
	assert_eq(game._source_disabled_reason("dorm_storage", "lunch"), "")
	assert_eq(game._source_disabled_reason("takeout", "lunch"), "")
	assert_eq(game._deck_service.capture_state(), before)
	game._choose_meal_source("cafeteria")
	assert_true(game.hand.has("rice_plain"))
	for id in game.hand: assert_true(id in Week.BASIC_MENU)
	assert_true(game.hand.size() <= 4)
	var state_before := game.state.duplicate(true)
	var preview := game.preview_meal_cost([game.hand[0]])
	assert_true(preview.has("menu_facts"))
	assert_eq(game.state, state_before)
	game._confirm_food(game.hand.duplicate())
	assert_eq(game.today_meal_records.back()["food_ids"].size(), 2)
	game.phase = "dinner_source"
	assert_eq(game._effective_meal_source("cafeteria")["selection_limit"], 3)
	assert_true(game._story_food_ids("cafeteria", "dinner").has("tomato_egg_stir_fry"))


func test_peer_review_bonus_requires_actual_study_in_the_announced_slot() -> void:
	var game := _game()
	game.day = 5
	game.phase = "breakfast_action"
	game.state["energy"] = 80
	game.state["stress"] = 20
	game.state["satiety"] = 70
	var alone := game._effective_action("study")
	game.phase = "lunch_action"
	var together := game._effective_action("study")
	assert_eq(together["study"] - alone["study"], 6)
	assert_eq(together["energy"] - alone["energy"], -4)
	assert_eq(together["min_energy"], 14)
	assert_eq(together["name_lunch_action"], "和同学对题")
	var records := game.today_action_records.size()
	game._apply_action("study")
	assert_eq(game.today_action_records.size(), records + 1)
	assert_eq(game.today_action_records.back()["campus_event"], "peer_review")
	assert_eq(game.today_action_records.back()["feedback_trace"]["goal_components"]["event"], 6)
	assert_eq(game.phase, "dinner_source")
	game.phase = "dinner_action"
	assert_eq(game._effective_action("study")["_feedback_components"]["event"], 0)


func test_rain_creates_cash_and_effort_tradeoffs_without_changing_inventory() -> void:
	var game := _game()
	game.day = 6
	var stock := game.dorm_inventory.duplicate(true)
	assert_eq(game._effective_meal_source("takeout")["fee"], 5)
	assert_eq(game._effective_meal_source("cafeteria")["energy"], -5)
	assert_eq(game._effective_meal_source("convenience_store")["energy"], -2)
	assert_eq(game._effective_meal_source("dorm_storage")["energy"], 0)
	assert_eq(game.dorm_inventory, stock)
	assert_contains(game._story_preview(5)["summary"], "存粮够不够")
	assert_contains(Week.action_note(2, "dinner_action", game.state, game.campus_week), "补存粮")
	assert_contains(Week.action_note(5, "dinner_action", game.state, game.campus_week), "明天有雨")


func test_planning_is_free_and_only_confirmed_food_resolves_the_intention() -> void:
	var game := _game()
	var before := game.capture_game_save()
	assert_true(Week.set_plan(game.campus_week, 1, "breakfast", "dorm_storage", 1))
	game._choose_meal_source("cafeteria")
	var plan := Week.plan_for(game.campus_week, 1, "breakfast")
	assert_false(plan["resolved"])
	assert_eq(game.state, before["payload"]["state"])
	assert_eq(game.dorm_inventory, before["payload"]["dorm_inventory"])
	game._confirm_food([game.hand[0]])
	assert_true(plan["resolved"])
	assert_eq(plan["source"], "dorm_storage")
	assert_eq(plan["actual_source"], "cafeteria")
	assert_eq(plan["actual_foods"], game.today_meal_records.back()["food_ids"])
	assert_contains(Week.plan_text(plan, Cards.meal_sources), "实际在食堂")
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_skipping_a_planned_meal_is_recorded_without_inventing_food() -> void:
	var game := _game()
	Week.set_plan(game.campus_week, 1, "breakfast", "cafeteria", 1)
	game._skip_meal()
	var plan := Week.plan_for(game.campus_week, 1, "breakfast")
	assert_true(plan["resolved"])
	assert_true(plan["skipped"])
	assert_true(plan["actual_foods"].is_empty())
	assert_contains(Week.plan_text(plan, Cards.meal_sources), "实际跳过")
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_daily_observation_reads_frozen_ingredients_and_not_food_names_or_health_tags() -> void:
	var meals: Array = [{"phase": "breakfast", "skipped": false, "campus_facts": Learning.facts(["egg"])}, {"phase": "lunch", "skipped": false, "campus_facts": Learning.facts(["tomato_egg_stir_fry"])}]
	var result := Learning.observation(1, meals, [])
	assert_contains(result["text"], "2餐里都有鸡蛋")
	var later := Learning.observation(2, [{"phase": "breakfast", "skipped": false, "campus_facts": Learning.facts(["apple"])}], [{"day": 1, "meals": meals}])
	assert_contains(later["text"], "新出现了苹果")
	var missing := Learning.observation(2, [{"phase": "breakfast", "skipped": false}], [{"day": 1, "meals": meals}])
	assert_true(missing.is_empty())
	var skipped := Learning.observation(2, [{"phase": "breakfast", "skipped": true}], [])
	assert_contains(skipped["text"], "跳过了早餐")
	for key in ["health_score", "quality", "burden"]: assert_false(result.has(key))


func test_legacy_saves_do_not_switch_event_rules_or_replay_planning() -> void:
	var game := _game()
	var save := game.capture_game_save()
	save["payload"].erase("campus_week")
	var checked := Codec.validate(save)
	assert_true(checked["ok"], str(checked))
	assert_false(checked["save"]["payload"]["campus_week"]["enabled"])
	assert_true(game.restore_game_save(save)["ok"])
	game.day = 3
	game.phase = "lunch_source"
	assert_eq(game._effective_meal_source("cafeteria")["selection_limit"], 3)
	assert_eq(game._story_event(3)["title"], "食堂换菜单")
	assert_true(game.campus_week["plans"].is_empty())


func test_corrupt_plan_and_frozen_menu_are_rejected_transactionally() -> void:
	var game := _game()
	Week.set_plan(game.campus_week, 1, "breakfast", "cafeteria", 1)
	var plate := _pick(game)
	game._confirm_food(plate)
	var original := game.capture_game_save()
	var bad := original.duplicate(true)
	bad["payload"]["campus_week"]["plans"][0]["actual_source"] = "dorm_storage"
	assert_false(game.restore_game_save(bad)["ok"])
	assert_eq(game.capture_game_save()["payload"], original["payload"])
	bad = original.duplicate(true)
	bad["payload"]["today_meal_records"][0]["campus_facts"]["ingredients"] = ["invented"]
	assert_false(Codec.validate(bad)["ok"])


func test_complete_week_freezes_story_observations_and_keeps_new_records_loadable() -> void:
	var game := _game()
	for day in range(1, 8):
		assert_eq(game.day, day)
		_day(game)
		assert_true(game.run_history.back().has("campus_voice"))
		assert_true(game.run_history.back().has("campus_observation"))
		var checked := Codec.encode(game.capture_game_save())
		assert_true(checked["ok"], str(checked))
		if day < 7: game._on_summary_advanced()
	assert_eq(game.phase, "ending")
	assert_eq(game.run_history.size(), 7)


func test_learning_preview_and_retries_preserve_resources_and_remember_first_answer() -> void:
	var game := _ui()
	var plate := _pick(game)
	game._on_food_toggled(plate[0])
	var before := game.capture_game_save()
	assert_true(Presenter.open_study(game))
	assert_true(game._story_dialog.visible)
	assert_true(Codec.encode(game.capture_game_save())["ok"])
	var q := Learning.question(game.campus_week["active"]["context"])
	var wrong: String = q["choices"].filter(func(option: Dictionary) -> bool: return option["id"] != q["correct"])[0]["id"]
	game._story_dialog._buttons.get_node(wrong).pressed.emit()
	assert_false(game.campus_week["attempts"][0]["correct"])
	assert_false(game.campus_week["attempts"][0]["after_help"])
	game._story_dialog._buttons.get_node("retry").pressed.emit()
	game._story_dialog._buttons.get_node(q["correct"]).pressed.emit()
	assert_true(game.campus_week["attempts"][1]["correct"])
	assert_true(game.campus_week["attempts"][1]["after_help"])
	game._story_dialog._buttons.get_node("back").pressed.emit()
	assert_true(game.campus_week["active"].is_empty())
	assert_eq(game.state, before["payload"]["state"])
	assert_eq(game.dorm_inventory, before["payload"]["dorm_inventory"])
	assert_eq(game.selected_food_ids, before["payload"]["selected_food_ids"])
	assert_eq(game.today_meal_records, before["payload"]["today_meal_records"])
	assert_eq(game._deck_service.capture_state(), before["payload"]["deck"])
	assert_true(game.get_health_snapshots().is_empty())
	for flag in ["data", "engine", "ui", "weekly"]: assert_false(Flags.is_enabled(Flags.current(), flag))


func test_mid_exercise_save_restores_context_answer_and_return_to_the_same_tray() -> void:
	var game := _ui()
	var plate := _pick(game)
	game._on_food_toggled(plate[0])
	Presenter.open_study(game)
	game._story_dialog._buttons.get_node("explain").pressed.emit()
	var save := Codec.encode(game.capture_game_save())
	assert_true(save["ok"], str(save))
	var restored := _ui(Vector2i(640, 960))
	assert_true(restored.restore_game_save(save["save"])["ok"])
	assert_true(restored._story_dialog.visible)
	assert_eq(restored.campus_week["active"]["page"], "feedback")
	assert_true(restored.campus_week["active"]["help"])
	restored._story_dialog._buttons.get_node("back").pressed.emit()
	assert_eq(restored.selected_food_ids, game.selected_food_ids)
	assert_eq(restored.state, game.state)


func test_summary_plan_is_optional_and_survives_reload_without_advancing() -> void:
	var game := _ui()
	_day(game)
	assert_eq(game.phase, "summary")
	assert_true(game.daily_summary.planning_button.visible)
	game.daily_summary.planning_button.pressed.emit()
	assert_eq(game.day, 1)
	assert_eq(game.campus_week["active"]["kind"], "plan")
	game._workspace.find_child("source_dorm_storage", true, false).pressed.emit()
	var save := Codec.encode(game.capture_game_save())
	assert_true(save["ok"], str(save))
	var restored := _ui()
	assert_true(restored.restore_game_save(save["save"])["ok"])
	assert_true(is_instance_valid(restored._workspace))
	assert_eq(restored.day, 1)
	var balance: int = restored.state["balance"]
	var stock: Dictionary = restored.dorm_inventory.duplicate(true)
	restored._workspace.close_button.pressed.emit()
	assert_true(restored.daily_summary.visible)
	assert_eq(restored.day, 1)
	restored._on_summary_advanced()
	assert_eq(restored.day, 2)
	assert_true(restored._new_day_pending)
	assert_false(is_instance_valid(restored._story_dialog) and restored._story_dialog.visible)
	assert_eq(restored.state["balance"], balance)
	assert_eq(restored.dorm_inventory, stock)
	assert_true(restored.today_meal_records.is_empty())
	assert_false(Week.plan_for(restored.campus_week, 2, "breakfast")["resolved"])
	assert_true(Codec.encode(restored.capture_game_save())["ok"])



func test_household_keeps_its_separate_lessons_events_and_cards() -> void:
	var game := _game(42, "choir_week")
	assert_true(game.campus_week.is_empty())
	assert_contains(game._story_event(3)["id"], "choir_day")
	assert_eq(game._effective_meal_source("home_kitchen")["energy"], -6)
	assert_false(game.get_food_for_character("rice_plain")["desc"].contains("份量、调味"))
	assert_true(Codec.encode(game.capture_game_save())["ok"])
