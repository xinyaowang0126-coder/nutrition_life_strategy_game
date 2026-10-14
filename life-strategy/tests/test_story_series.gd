@tool
extends McpTestSuite

const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Session := preload("res://scripts/stories/StorySession.gd")
const Kitchen := preload("res://scripts/stories/KitchenStock.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")


func suite_name() -> String:
	return "story_series"


func _new_story(id: String = "choir_week", seed_value: int = 42) -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.story_id = id
	game._deck_service = Deck.new(seed_value)
	game.start_new_run()
	return game


func test_story_catalog_and_request_isolation() -> void:
	assert_eq(Catalog.all().size(), 2)
	assert_false(Session.request("not_a_story"))
	assert_true(Session.request("choir_week"))
	assert_eq(Session.take_request(), "choir_week")
	assert_eq(Session.take_request(), "campus_exam")
	var story := Catalog.get_story("choir_week")
	story["goal_target"] = 999
	assert_eq(Catalog.get_story("choir_week")["goal_target"], 70)
	assert_true(Catalog.get_story("not_a_story").is_empty())


func test_character_goal_and_sources_are_separate() -> void:
	var elder := _new_story()
	assert_eq(elder.state["balance"], 210)
	assert_true(elder.state.has("goal_progress"))
	assert_false(elder.state.has("study_progress"))
	assert_false(elder._story_source_available("community_canteen", "breakfast"))
	assert_false(elder._story_source_available("takeout", "lunch"))
	assert_true(elder._story_source_available("home_kitchen", "breakfast"))
	assert_false(elder._health_data_enabled())
	var student := _new_story("campus_exam")
	assert_eq(student.state["balance"], 150)
	assert_true(student.state.has("study_progress"))
	assert_false(student.state.has("goal_progress"))
	assert_false(student._story_source_available("home_kitchen", "breakfast"))
	assert_ne(elder.food_preferences["id"], student.food_preferences["id"])


func test_recipe_transaction_and_duplicate_confirmation() -> void:
	var game := _new_story()
	game._choose_meal_source("home_kitchen")
	var rice_before: int = game.kitchen.ingredients["rice_plain"]
	var egg_before: int = game.kitchen.ingredients["egg"]
	assert_true(game.confirm_household_food(["rice_plain", "egg"], "fridge"))
	assert_eq(game.kitchen.ingredients["rice_plain"], rice_before - 2)
	assert_eq(game.kitchen.ingredients["egg"], egg_before - 2)
	assert_eq(game.state["balance"], 210)
	assert_eq(game.today_meal_records.size(), 1)
	assert_false(game.confirm_household_food(["rice_plain", "egg"], "fridge"))
	assert_eq(game.kitchen.batches.size(), 3)
	assert_eq(game.today_meal_records[0]["story_context"]["story_id"], "choir_week")
	assert_true(game.dorm_inventory.is_empty())


func test_shared_ingredient_shortage_is_atomic() -> void:
	var game := _new_story()
	game.kitchen.ingredients["egg"] = 1
	game._choose_meal_source("home_kitchen")
	var before := game.kitchen.ingredients.duplicate(true)
	assert_false(game.confirm_household_food(["egg", "tomato_egg_stir_fry"]))
	assert_eq(game.kitchen.ingredients, before)
	assert_eq(game.today_meal_records.size(), 0)
	assert_eq(game.phase, "breakfast")


func test_leftover_rules_and_unknown_are_not_safe() -> void:
	var game := _new_story()
	assert_eq(Kitchen.classify(game.kitchen.batches[0], 1), "discard_required")
	assert_eq(game.kitchen.available("greens", 1), 0)
	assert_eq(Kitchen.classify({"storage": "fridge"}, 1), "history_unknown")
	var cooked := game.kitchen.cook(["tofu"], game._story_food_catalog(), 1, "fridge")
	assert_true(cooked["ok"])
	var batch: Dictionary = game.kitchen.batches.back().duplicate(true)
	assert_eq(Kitchen.classify(batch, 2), "needs_reheat")
	batch["danger_minutes"] = 720
	assert_eq(Kitchen.classify(batch, 2), "discard_required")
	batch["danger_minutes"] = 60
	batch["reheat_count"] = 1
	assert_eq(Kitchen.classify(batch, 2), "discard_required")
	batch["reheat_count"] = 0
	assert_eq(Kitchen.classify(batch, 5), "discard_required")
	batch.erase("fridge_max_c")
	assert_eq(Kitchen.classify(batch, 2), "history_unknown")
	batch["fridge_max_c"] = "not_recorded"
	assert_eq(Kitchen.classify(batch, 2), "history_unknown")
	batch["fridge_max_c"] = NAN
	assert_eq(Kitchen.classify(batch, 2), "history_unknown")
	batch["fridge_max_c"] = 4
	batch["cooled_after_minutes"] = "60"
	assert_eq(Kitchen.classify(batch, 2), "history_unknown")


func test_reheated_batch_consumes_once_and_does_not_reset_history() -> void:
	var game := _new_story()
	game._choose_meal_source("home_kitchen")
	assert_true(game.confirm_household_food(["tofu"], "fridge"))
	game._skip_action()
	game._choose_meal_source("home_fridge")
	assert_true(game.hand.has("tofu"))
	assert_true(game.confirm_household_food(["tofu"]))
	assert_eq(game.kitchen.available("tofu", 1), 0)
	assert_eq(game.today_meal_records.back()["kitchen_transaction"]["batches"][0]["reheat_count"], 1)
	assert_false(game.kitchen.consume(["tofu"], 1)["ok"])


func test_room_temperature_preparation_stays_unavailable() -> void:
	var game := _new_story()
	assert_true(game.kitchen.cook(["tofu"], game._story_food_catalog(), 1, "counter")["ok"])
	assert_eq(game.kitchen.available("tofu", 2), 0)
	var id := String(game.kitchen.batches.back()["id"])
	assert_true(game.kitchen.discard(id, 2))
	assert_false(game.kitchen.discard(id, 2))
	assert_eq(game.kitchen.history.back()["action"], "discard")


func test_storage_expiry_uses_elapsed_hours_inside_same_calendar_day() -> void:
	var game := _new_story()
	assert_true(game.kitchen.cook(["tofu"], game._story_food_catalog(), 1, "fridge", 32)["ok"])
	var batch: Dictionary = game.kitchen.batches.back()
	assert_eq(Kitchen.classify(batch, 4, 105), "needs_reheat")
	assert_eq(Kitchen.classify(batch, 4, 106), "discard_required")
	assert_eq(game.kitchen.available("tofu", 4, 106), 0)


func test_science_exercises_keep_sugar_scope_explicit() -> void:
	var science := preload("res://scripts/stories/StoryEducation.gd")
	assert_eq(science.exercise(3)["correct"], "700")
	assert_eq(science.exercise(4)["correct"], "total_known")
	assert_contains(science.exercise(4)["explanation"], "添加糖的量仍未知")
	assert_true(science.exercise(1).is_empty())


func test_rehearsal_limits_and_actual_performance_requirement() -> void:
	var game := _new_story()
	game.phase = "breakfast_action"
	assert_false(game._household_action_reason(game._story_action("group_rehearsal")).is_empty())
	game.used_action_ids.assign(["rehearse", "rehearse"])
	assert_false(game._household_action_reason(game._story_action("rehearse")).is_empty())
	game.used_action_ids.clear()
	game.day = 7
	game.phase = "dinner_action"
	game.state["goal_progress"] = 70
	game.state["energy"] = 24
	game._apply_action("perform")
	assert_false(game.performed)
	assert_eq(game._select_story_ending(), "study_shortfall")
	game.state["energy"] = 40
	game._apply_action("perform")
	assert_true(game.performed)
	assert_eq(game.phase, "sleep")
	assert_eq(game._select_story_ending(), "stable_endurance")
	var energy_after := int(game.state["energy"])
	game._apply_action("perform")
	assert_eq(game.state["energy"], energy_after)


func test_restart_and_switch_clear_household_state() -> void:
	var game := _new_story()
	game.kitchen.ingredients["egg"] = 0
	game.performed = true
	game.state["goal_progress"] = 70
	game.start_new_run()
	assert_eq(game.kitchen.ingredients["egg"], 5)
	assert_false(game.performed)
	assert_eq(game.state["goal_progress"], 0)
	game.story_id = "campus_exam"
	game.start_new_run()
	assert_eq(game.state["balance"], 150)
	assert_false(game.state.has("goal_progress"))
	assert_gt(game.dorm_inventory.size(), 0)
	game.story_id = "choir_week"
	game.start_new_run()
	assert_eq(game.state["balance"], 210)
	assert_true(game.dorm_inventory.is_empty())
	var current := game.state.duplicate(true)
	game.story_id = "unknown_story"
	game.start_new_run()
	assert_eq(game.story_id, "choir_week")
	assert_eq(game.state, current)


func test_household_has_a_legal_seven_day_route_across_seeds() -> void:
	for seed_value in [0, 1, 2, 3, 7, 13, 42, 73, 101, 211]:
		var game := _new_story("choir_week", seed_value)
		for run_day in range(1, 8):
			for meal in ["breakfast", "lunch", "dinner"]:
				assert_eq(game.phase, meal + "_source")
				game._choose_meal_source("local_market" if meal == "breakfast" else "community_canteen")
				var plate: Array[String] = []
				for id in ["rice_plain", "oatmeal", "egg", "tofu", "tomato_egg_stir_fry", "steamed_fish", "whole_wheat_bread", "milk", "plain_yogurt", "greens", "tomato", "banana", "apple"]:
					if game.hand.has(id):
						game.selected_food_ids = plate.duplicate()
						if game._can_add_food(id):
							plate.append(id)
					if plate.size() >= 2:
						break
				assert_true(game.confirm_household_food(plate), "seed %d day %d %s" % [seed_value, run_day, meal])
				if run_day == 7 and meal == "dinner":
					game._apply_action("perform")
				elif meal == "breakfast":
					game._apply_action("rehearse")
				elif meal == "lunch" and run_day in [3, 5]:
					game._apply_action("group_rehearsal")
				else:
					game._apply_action("nap")
			game._choose_sleep("sleep_early")
			if run_day < 7:
				assert_eq(game.phase, "summary")
				game._on_summary_advanced()
		assert_eq(game.day, 7)
		assert_true(game.performed, "seed %d must really perform" % seed_value)
		assert_eq(game.ending_id, "stable_endurance")
		assert_eq(game.recovery_diagnostics.size(), 0)


func test_scene_uses_older_portrait_goal_and_modal_input_guard() -> void:
	assert_true(Session.request("choir_week"))
	var game := Scene.instantiate() as GameRootV2
	track(game)
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	game.new_day_popup.hide_popup(false)
	assert_eq(game.story_id, "choir_week")
	assert_contains(game.character_hud.study_value.text, "排练")
	assert_contains(game.character_hud.portrait.texture.resource_path, "zhou_huilan")
	game._show_kitchen()
	assert_true(game._record_book_active())
	var before := game.state.duplicate(true)
	game._choose_meal_source("home_kitchen")
	game._skip_meal()
	assert_eq(game.phase, "breakfast_source")
	assert_eq(game.state, before)
	game._story_dialog.hide()
	game._show_education()
	assert_eq(game.state, before)
