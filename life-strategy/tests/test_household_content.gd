@tool
extends McpTestSuite

const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Session := preload("res://scripts/stories/StorySession.gd")
const Kitchen := preload("res://scripts/stories/KitchenStock.gd")
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const Shared := preload("res://scripts/stories/SharedMealPlan.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")


func suite_name() -> String:
	return "household_content"


func _new_game() -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.story_id = "choir_week"
	game._deck_service = Deck.new(42)
	game.start_new_run()
	return game


func _scene() -> GameRootV2:
	Session.request("choir_week")
	var game := Scene.instantiate() as GameRootV2
	track(game)
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	game.new_day_popup.hide_popup(false)
	return game


func test_soft_recipes_share_real_pantry_ingredients_and_have_own_art() -> void:
	var game := _new_game()
	var foods := game._story_food_catalog()
	for id in ["millet_porridge", "steamed_egg", "soft_tofu_greens", "soft_apple"]:
		assert_true(game._story_food_ids("home_kitchen", "breakfast").has(id))
		assert_false(game._story_food_ids("local_market", "breakfast").has(id))
		assert_contains(foods[id]["image"], "stories/foods/" + id)
		assert_true(ResourceLoader.exists(foods[id]["image"]))
	assert_eq(game.kitchen.needs(["steamed_egg", "tomato_egg_stir_fry"], foods), {"egg": 2, "tomato": 1})
	assert_eq(game.kitchen.needs(["soft_tofu_greens"], foods), {"tofu": 1, "greens": 1})
	assert_false(Catalog.content(Catalog.get_story("campus_exam"), "foods").has("soft_apple"))


func test_given_recipe_sodium_and_white_sugar_keep_unknown_scope() -> void:
	var foods := _new_game()._story_food_catalog()
	var facts := Facts.freeze(["tofu", "millet_porridge"], foods, {"seasoning": "light", "added_sugar_g": 4})
	assert_true(Facts.valid(facts))
	assert_eq(facts["sodium_from_added_seasonings_mg"], 750)
	assert_eq(facts["white_sugar_added_g"], 4)
	assert_eq(facts["total_sugars_status"], "unknown")
	assert_eq(facts["ingredient_sodium_status"], "unknown")
	assert_eq(facts["other_added_sugars_status"], "unknown")
	assert_false(facts.has("total_sugars_g"))
	assert_contains(Facts.describe(facts), "不能当成整餐或全天总量")
	assert_true(Facts.freeze(["unknown"], foods, {"seasoning": "none", "added_sugar_g": 0}).is_empty())
	assert_false(Facts.validate({"seasoning": "light", "added_sugar_g": 4}, ["rice_plain"], foods))
	assert_false(Facts.validate({"seasoning": "none", "added_sugar_g": 4.0}, ["millet_porridge"], foods))


func test_two_people_plus_one_saved_portion_charge_three_sets_but_record_one() -> void:
	var game := _new_game()
	var foods := game._story_food_catalog()
	var before := game.kitchen.ingredients.duplicate(true)
	var result := game.kitchen.cook(["rice_plain", "tofu", "oatmeal"], foods, 4, "fridge", 114, {"seasoning": "usual", "added_sugar_g": 8}, 2)
	assert_true(result["ok"])
	assert_eq(result["record"]["served_portions"], 2)
	assert_eq(result["record"]["condiments_used"], {"salt_g": 6, "soy_ml": 30, "sugar_g": 24})
	for id in ["rice_plain", "tofu", "oatmeal"]:
		assert_eq(game.kitchen.ingredients[id], before[id] - 3)
	assert_eq(result["record"]["recipe_facts"]["sodium_from_added_seasonings_mg"], 1500)
	assert_eq(result["record"]["recipe_facts"]["white_sugar_added_g"], 8)
	var saved: Array = result["record"]["prepared"]
	assert_eq(saved.size(), 3)
	assert_eq(saved[0]["recipe_facts"]["sodium_from_added_seasonings_mg"], 0.0)
	assert_eq(saved[0]["recipe_facts"]["white_sugar_added_g"], 0.0)
	assert_eq(saved[1]["recipe_facts"]["sodium_from_added_seasonings_mg"], 1500.0)
	assert_eq(saved[2]["recipe_facts"]["white_sugar_added_g"], 8.0)
	assert_eq(saved[2]["recipe_facts"]["sodium_from_added_seasonings_mg"], 0.0)


func test_condiment_shortage_and_invalid_plan_do_not_partially_spend() -> void:
	var game := _new_game()
	game._choose_meal_source("home_kitchen")
	game.kitchen.condiments["soy_ml"] = 4
	var ingredients := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	var batches := game.kitchen.batches.duplicate(true)
	assert_false(game.confirm_household_food(["tofu"], "fridge", {"seasoning": "light", "added_sugar_g": 0}))
	assert_false(game.confirm_household_food(["tofu"], "eat_now", {"seasoning": "none", "added_sugar_g": 999}))
	assert_eq(game.kitchen.ingredients, ingredients)
	assert_eq(game.kitchen.condiments, condiments)
	assert_eq(game.kitchen.batches, batches)
	assert_true(game.kitchen.history.is_empty())
	assert_true(game.today_meal_records.is_empty())
	assert_eq(game.phase, "breakfast")
	assert_true(game.confirm_household_food(["tofu"], "eat_now", {"seasoning": "none", "added_sugar_g": 0}))


func test_saved_recipe_is_frozen_and_unknown_items_are_not_zero() -> void:
	var game := _new_game()
	game._choose_meal_source("home_kitchen")
	assert_true(game.confirm_household_food(["tofu", "millet_porridge"], "fridge", {"seasoning": "usual", "added_sugar_g": 8}))
	var first_facts: Dictionary = game.today_meal_records[0]["recipe_facts"].duplicate(true)
	game.kitchen.history[0]["recipe_facts"]["white_sugar_added_g"] = 999
	assert_eq(game.today_meal_records[0]["recipe_facts"], first_facts)
	game._skip_action()
	game._choose_meal_source("home_fridge")
	assert_true(game.confirm_household_food(["tofu", "millet_porridge", "milk"]))
	var served: Dictionary = game.today_meal_records.back()["recipe_facts"]
	assert_eq(served["sodium_from_added_seasonings_mg"], 1500.0)
	assert_eq(served["white_sugar_added_g"], 8.0)
	assert_eq(served["unrecorded_items"], 1)
	assert_contains(Facts.describe(served), "1项食物没有配方调味记录")
	assert_eq(game.kitchen.available("tofu", 1), 0)
	var summary := Facts.summarize(game.today_meal_records + [{"phase": "dinner", "food_ids": ["milk"]}])
	assert_eq(summary["known_seasoning_sodium_mg"], 3000.0)
	assert_eq(summary["known_white_sugar_g"], 16.0)
	assert_eq(summary["meals_without_recipe_facts"], 1)
	assert_contains(summary["text"], "这不是全天总摄入")


func test_recipe_quantity_changes_do_not_claim_health_or_change_goal_resources() -> void:
	var light := _new_game()
	var usual := _new_game()
	for game in [light, usual]:
		game._choose_meal_source("home_kitchen")
	assert_true(light.confirm_household_food(["tofu", "millet_porridge"], "eat_now", {"seasoning": "none", "added_sugar_g": 0}))
	assert_true(usual.confirm_household_food(["tofu", "millet_porridge"], "eat_now", {"seasoning": "usual", "added_sugar_g": 8}))
	assert_eq(light.state, usual.state)
	assert_eq(light.today_meal_records[0]["stat_delta"], usual.today_meal_records[0]["stat_delta"])
	assert_ne(light.today_meal_records[0]["recipe_facts"], usual.today_meal_records[0]["recipe_facts"])
	assert_false(usual.today_meal_records[0].has("health_snapshot"))
	var forged: Dictionary = usual.today_meal_records[0]["recipe_facts"].duplicate(true)
	forged["total_sugars_status"] = "known"
	assert_false(Facts.valid(forged))
	forged = usual.today_meal_records[0]["recipe_facts"].duplicate(true)
	forged["sodium_from_added_seasonings_mg"] = NAN
	assert_false(Facts.valid(forged))


func test_shared_meal_requires_food_correct_time_venue_and_only_completes_once() -> void:
	var shared := Shared.new()
	assert_false(shared.invite(3, "home"))
	assert_true(shared.invite(4, "community"))
	var meal := {"phase": "dinner", "source_id": "community_canteen", "food_ids": ["tofu"], "food_names": ["豆腐"]}
	assert_false(shared.complete(5, meal))
	assert_false(shared.complete(4, {"phase": "dinner", "source_id": "community_canteen"}))
	assert_false(shared.complete(4, {"phase": "dinner", "source_id": "home_fridge", "food_ids": ["tofu"]}))
	assert_false(shared.complete(4, {"phase": "dinner", "source_id": "community_canteen", "food_ids": ["tofu"], "skipped": true}))
	assert_eq(shared.plan["status"], "planned")
	assert_true(shared.complete(4, meal))
	assert_eq(meal["companions"][0]["name"], "老陈")
	assert_false(shared.complete(4, meal))
	assert_eq(shared.history.size(), 2)
	assert_contains(shared.summary(), "一起吃了晚饭")


func test_invitation_does_not_spend_and_home_dinner_charges_two_people() -> void:
	var game := _new_game()
	game.day = 4
	game.phase = "lunch_action"
	var before := game.state.duplicate(true)
	assert_true(game.plan_shared_meal("home"))
	assert_eq(game.phase, "lunch_action")
	assert_eq(game.state, before)
	assert_eq(game.actions_used_today, 0)
	assert_false(game.plan_shared_meal("community"))
	game._skip_action()
	game._choose_meal_source("home_kitchen")
	assert_eq(game._served_portions(), 2)
	assert_true(game.confirm_household_food(["rice_plain", "soft_tofu_greens"], "eat_now", {"seasoning": "light", "added_sugar_g": 0}))
	assert_eq(game.kitchen.ingredients["rice_plain"], 6)
	assert_eq(game.kitchen.ingredients["tofu"], 3)
	assert_eq(game.kitchen.condiments["soy_ml"], 50)
	var meal: Dictionary = game.today_meal_records.back()
	assert_eq(meal["recipe_facts"]["sodium_from_added_seasonings_mg"], 750)
	assert_eq(meal["companions"][0]["id"], "chen_friend")
	assert_eq(game.shared_meal.plan["status"], "completed")


func test_missed_invitation_remains_missed_and_restart_clears_plans_and_condiments() -> void:
	var game := _new_game()
	game.day = 4
	game.phase = "lunch_action"
	assert_true(game.plan_shared_meal("community"))
	game._skip_action()
	game._skip_meal()
	assert_eq(game.shared_meal.plan["status"], "planned")
	game.shared_meal.finish_day(4)
	assert_true(game.shared_meal.plan.is_empty())
	assert_eq(game.shared_meal.history.back()["kind"], "missed")
	assert_contains(game.shared_meal.summary(), "还没有共同进餐记录")
	game.kitchen.condiments["soy_ml"] = 0
	game.start_new_run()
	assert_true(game.shared_meal.plan.is_empty())
	assert_true(game.shared_meal.history.is_empty())
	assert_eq(game.kitchen.condiments["soy_ml"], 60)


func test_preview_toggle_cancel_and_stale_confirm_cannot_spend() -> void:
	var game := _scene()
	assert_false(game.toast_anchor.visible)
	game._choose_meal_source("home_kitchen")
	assert_false(game.toast_anchor.visible)
	var before := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	game._confirm_food(["tofu", "millet_porridge"])
	var old_confirm: Button = game._story_dialog._buttons.get_node("confirm")
	game._story_dialog._buttons.get_node("sugar").pressed.emit()
	old_confirm.pressed.emit()
	assert_true(game._story_dialog.visible)
	assert_true(game.today_meal_records.is_empty())
	assert_eq(game.kitchen.ingredients, before)
	assert_eq(game.kitchen.condiments, condiments)
	game._story_dialog._buttons.get_node("cancel").pressed.emit()
	assert_false(game._story_dialog.visible)
	assert_eq(game.phase, "breakfast")
	game._confirm_food(["tofu", "millet_porridge"])
	game._story_dialog._buttons.get_node("sugar").pressed.emit()
	game._story_dialog._buttons.get_node("confirm").pressed.emit()
	assert_eq(game.phase, "breakfast_action")
	assert_true(game.toast_anchor.visible)
	assert_eq(game.today_meal_records[0]["recipe_facts"]["white_sugar_added_g"], 4)
	assert_eq(game.kitchen.condiments["sugar_g"], 36)


func test_shared_meal_dialog_cancel_and_double_tap_keep_plan_truthful() -> void:
	var game := _scene()
	game.day = 4
	game.phase = "lunch_action"
	game._apply_action("call_friend")
	assert_true(game._story_dialog.visible)
	assert_false(game.plan_shared_meal("home"))
	game._story_dialog._buttons.get_node("cancel").pressed.emit()
	assert_true(game.shared_meal.plan.is_empty())
	assert_true(game.today_action_records.is_empty())
	game._apply_action("call_friend")
	var invite: Button = game._story_dialog._buttons.get_node("home")
	invite.pressed.emit()
	invite.pressed.emit()
	assert_eq(game.shared_meal.history.size(), 1)
	assert_eq(game.today_action_records.size(), 1)
	assert_eq(game.shared_meal.plan["status"], "planned")
	assert_eq(game.phase, "lunch_action")


func test_full_week_with_soft_recipe_restock_shared_dinner_and_real_performance() -> void:
	var game := _new_game()
	for run_day in range(1, 8):
		for meal in ["breakfast", "lunch", "dinner"]:
			var home: bool = meal == "breakfast" or (run_day == 4 and meal == "dinner")
			game._choose_meal_source("home_kitchen" if home else "community_canteen")
			var plate: Array[String] = []
			if home:
				plate.assign(["rice_plain", "soft_tofu_greens"] if meal == "dinner" else ["rice_plain", "steamed_egg"])
			else:
				for id in ["rice_plain", "oatmeal", "egg", "tofu", "tomato_egg_stir_fry", "steamed_fish", "millet_porridge", "steamed_egg", "soft_tofu_greens", "greens", "tomato", "soft_apple", "banana", "milk", "apple", "plain_yogurt"]:
					if game.hand.has(id):
						game.selected_food_ids = plate.duplicate()
						if game._can_add_food(id):
							plate.append(id)
					if plate.size() >= 2:
						break
			assert_true(game.confirm_household_food(plate), "day %d %s" % [run_day, meal])
			if run_day == 4 and meal == "lunch":
				assert_true(game.plan_shared_meal("home"))
			if run_day == 7 and meal == "dinner":
				game._apply_action("perform")
			elif meal == "breakfast":
				game._apply_action("rehearse")
			elif meal == "lunch" and run_day in [3, 5]:
				game._apply_action("group_rehearsal")
			elif run_day == 2 and meal == "dinner":
				game._apply_action("shop_ingredients")
			else:
				game._apply_action("nap")
		game._choose_sleep("sleep_early")
		if run_day < 7:
			game._on_summary_advanced()
	assert_eq(game.run_history.size(), 7)
	assert_true(game.performed)
	assert_eq(game.ending_id, "stable_endurance")
	assert_eq(game.shared_meal.plan["status"], "completed")
	assert_eq(game.shared_meal.history.back()["day"], 4)
	assert_eq(game.run_history[3]["shared_meal_history"].size(), 2)
	assert_eq(game.run_history[3]["recipe_summary"]["known_seasoning_sodium_mg"], 750.0)
	assert_eq(game.recovery_diagnostics.size(), 0)


func test_condiment_purchase_charges_once_and_preserves_recipe_history() -> void:
	var game := _new_game()
	game.phase = "breakfast_action"
	game.kitchen.condiments["soy_ml"] = 0
	game._apply_action("shop_condiments")
	assert_eq(game.phase, "lunch_source")
	assert_eq(game.state["balance"], 206)
	assert_eq(game.kitchen.condiments["soy_ml"], 60)
	assert_eq(game.today_action_records[0]["stock_added"]["salt_g"], 20)
	game._choose_meal_source("home_kitchen")
	assert_true(game.confirm_household_food(["tofu"]))
	game._apply_action("shop_condiments")
	assert_eq(game.phase, "lunch_action")
	assert_eq(game.state["balance"], 206)
	assert_eq(game.kitchen.condiments["soy_ml"], 55)
	assert_eq(game.today_action_records.size(), 1)
