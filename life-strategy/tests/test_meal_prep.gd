@tool
extends McpTestSuite

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const PLATE := ["rice_plain", "soft_tofu_greens"]


func suite_name() -> String:
	return "meal_prep"


func _game(seed_value: int = 42) -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.story_id = "choir_week"
	game.health_history_path = ""
	game._deck_service = Deck.new(seed_value)
	game.start_new_run()
	return game


func _scene() -> GameRootV2:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	Session.request("choir_week")
	var game := Scene.instantiate() as GameRootV2
	game.health_history_path = ""
	viewport.add_child(game)
	game.new_day_popup.hide_popup(false)
	game._new_day_pending = false
	return game


func _two_meals(batch: bool, starting_energy: int = 60) -> GameRootV2:
	var game := _game()
	game.state["energy"] = starting_energy
	game._choose_meal_source("home_kitchen")
	assert_true(game.confirm_household_food(PLATE, "fridge" if batch else "eat_now"))
	game._skip_action()
	game._choose_meal_source("home_fridge" if batch else "home_kitchen")
	assert_true(game.confirm_household_food(PLATE))
	return game


func test_two_meals_save_five_energy_with_equal_food_and_condiment_costs() -> void:
	var fresh := _two_meals(false)
	var batch := _two_meals(true)
	assert_eq(batch.state["energy"] - fresh.state["energy"], 5)
	assert_eq(batch.kitchen.ingredients, fresh.kitchen.ingredients)
	assert_eq(batch.kitchen.condiments, fresh.kitchen.condiments)
	assert_eq(batch.today_meal_records.size(), 2)
	for key in ["recipes", "salt_g", "soy_ml", "sodium_from_added_seasonings_mg", "white_sugar_added_g", "ingredient_sodium_status", "total_sugars_status"]:
		assert_eq(batch.today_meal_records[0]["recipe_facts"][key], batch.today_meal_records[1]["recipe_facts"][key])
	for index in range(2):
		assert_eq(batch.today_meal_records[index]["food_ids"], fresh.today_meal_records[index]["food_ids"])
	var batch_other := batch.state.duplicate(true)
	var fresh_other := fresh.state.duplicate(true)
	# Reserve is derived partly from energy, so its corresponding improvement
	# is expected; independent money, mood and food effects must stay equal.
	assert_gt(batch.state["stability"], fresh.state["stability"])
	batch_other.erase("energy")
	fresh_other.erase("energy")
	batch_other.erase("stability")
	fresh_other.erase("stability")
	assert_eq(batch_other, fresh_other)
	assert_eq(batch.kitchen.available("soft_tofu_greens", 1), 0)


func test_preparing_a_portion_does_not_credit_a_bonus_before_it_is_used() -> void:
	var fresh := _game()
	var batch := _game()
	for game in [fresh, batch]: game._choose_meal_source("home_kitchen")
	assert_true(fresh.confirm_household_food(PLATE))
	assert_true(batch.confirm_household_food(PLATE, "fridge"))
	assert_eq(batch.state, fresh.state)
	assert_eq(batch.today_meal_records.size(), 1)
	assert_eq(fresh.kitchen.ingredients["tofu"] - batch.kitchen.ingredients["tofu"], 1)
	assert_eq(fresh.kitchen.condiments["soy_ml"] - batch.kitchen.condiments["soy_ml"], 5)
	assert_eq(batch.kitchen.available("soft_tofu_greens", 1), 1)


func test_five_saved_energy_can_keep_a_rehearsal_option_available() -> void:
	# A declared low-energy boundary isolates the action consequence.
	var fresh := _two_meals(false, 22)
	var batch := _two_meals(true, 22)
	assert_eq(fresh.state["energy"], 8)
	assert_eq(batch.state["energy"], 13)
	assert_false(fresh._can_use_action(fresh._effective_action("rehearse")))
	assert_true(batch._can_use_action(batch._effective_action("rehearse")))
	assert_contains(fresh._action_disabled_reason(fresh._effective_action("rehearse")), "精力")


func test_preview_shows_one_extra_portion_and_costs_from_the_real_sources() -> void:
	var game := _scene()
	game.day = 4
	game.phase = "lunch_action"
	assert_true(game.plan_shared_meal("home"))
	game._skip_action()
	game._choose_meal_source("home_kitchen")
	game._confirm_food(PLATE)
	var page := game._workspace as CookingPlanStage
	var before := {"ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "state": game.state.duplicate(true)}
	page.choose_option("storage", "fridge")
	assert_eq(page.ingredients_needed, {"rice_plain": 3, "tofu": 3, "greens": 3})
	for text in ["米×1", "豆腐×1", "青菜×1", "盐1克", "酱油5毫升", "6＋1＝7", "现做12，省5"]:
		assert_contains(page._effort_note.text, text)
	assert_false(page._effort_note.text.contains("米×2"))
	for character in page._effort_note.text + page._effort_note.tooltip_text:
		if character != "\n": assert_true(HouseholdUI.BODY_FONT.has_char(character.unicode_at(0)), "Missing preparation glyph: " + character)
	page.choose_option("storage", "counter")
	assert_false(page._effort_note.text.contains("省"))
	assert_contains(page._effort_note.text, "不能用于下一餐")
	assert_eq(game.kitchen.ingredients, before["ingredients"])
	assert_eq(game.kitchen.condiments, before["condiments"])
	assert_eq(game.state, before["state"])
	assert_true(game.today_meal_records.is_empty())
	# Alternate source costs must not leave fixed savings copy behind.
	page._source_effort = {"cook": 9, "reheat": 2, "can_use_later": true}
	page.choose_option("storage", "fridge")
	assert_contains(page._effort_note.text, "9＋2＝11")
	assert_contains(page._effort_note.text, "现做18，省7")


func test_final_dinner_does_not_promise_an_unavailable_future_meal_saving() -> void:
	var game := _scene()
	game.day = 7
	game.phase = "dinner_source"
	game._render_phase()
	game._choose_meal_source("home_kitchen")
	game._confirm_food(PLATE)
	var page := game._workspace as CookingPlanStage
	page.choose_option("storage", "fridge")
	assert_contains(page._effort_note.text, "本局已是最后一餐")
	assert_contains(page._effort_note.text, "米×1")
	assert_false(page._effort_note.text.contains("省"))
	page.choose_option("storage", "eat_now")
	assert_false(page._effort_note.text.contains("省"))
	assert_true(game.today_meal_records.is_empty())


func test_fresh_and_batch_week_routes_remain_legal_across_seeds() -> void:
	var rows: Array[Dictionary] = []
	for seed_value in [0, 1, 2, 3, 7, 13, 42, 73, 101, 211]:
		var fresh := _play_week(false, seed_value)
		var batch := _play_week(true, seed_value)
		rows.append(fresh)
		rows.append(batch)
		assert_eq(int(fresh["effort"]) - int(batch["effort"]), 35, "seven reused portions should avoid five effort each")
		assert_eq(fresh["ingredients"], batch["ingredients"])
		assert_eq(fresh["condiments"], batch["condiments"])
	print("MEAL_PREP_WEEK_RESULT=" + JSON.stringify(rows))


func _week_plate(game: GameRootV2) -> Array[String]:
	for grain in ["rice_plain", "oatmeal", "millet_porridge"]:
		for side in ["egg", "tofu", "soft_tofu_greens", "steamed_fish", "soft_apple", "greens", "tomato"]:
			var plate: Array[String] = [grain, side]
			if game.kitchen.can_cook(plate, game._story_food_catalog(), 2): return plate
	return []


func _play_week(batch: bool, seed_value: int) -> Dictionary:
	var game := _game(seed_value)
	var effort := 0
	for run_day in range(1, 8):
		var home_plate := _week_plate(game)
		assert_false(home_plate.is_empty(), "a real pantry plate is required")
		for meal in ["breakfast", "lunch", "dinner"]:
			var source := "community_canteen" if meal == "dinner" else ("home_fridge" if batch and meal == "lunch" else "home_kitchen")
			assert_eq(game.phase, meal + "_source")
			game._choose_meal_source(source)
			var plate := home_plate.duplicate()
			if meal == "dinner":
				plate.clear()
				for id in ["rice_plain", "oatmeal", "millet_porridge", "egg", "tofu", "steamed_egg", "soft_tofu_greens", "tomato_egg_stir_fry", "greens", "tomato", "milk", "soft_apple", "steamed_fish"]:
					game.selected_food_ids = plate.duplicate()
					if game.hand.has(id) and game._can_add_food(id): plate.append(id)
					if plate.size() == 2: break
			assert_true(game.confirm_household_food(plate, "fridge" if batch and meal == "breakfast" else "eat_now"), "%s seed %d day %d %s" % ["batch" if batch else "fresh", seed_value, run_day, meal])
			effort += maxi(0, -int(game._effective_meal_source(source).get("energy", 0)))
			if run_day == 7 and meal == "dinner": game._apply_action("perform")
			elif meal == "breakfast" and int(game.state["goal_progress"]) < 70 and int(game.state["energy"]) >= 35: game._apply_action("rehearse")
			elif meal == "lunch" and run_day in [3, 5] and int(game.state["energy"]) >= 30: game._apply_action("group_rehearsal")
			elif meal == "dinner" and run_day < 7 and _week_plate(game).is_empty(): game._apply_action("shop_ingredients")
			else: game._apply_action("nap")
		game._choose_sleep("sleep_early")
		if run_day < 7: game._on_summary_advanced()
	assert_eq(game.run_history.size(), 7)
	assert_true(game.performed, "both fresh and batch routes must still perform")
	assert_eq(game.ending_id, "stable_endurance")
	assert_true(game.recovery_diagnostics.is_empty())
	return {"seed": seed_value, "policy": "batch" if batch else "fresh", "effort": effort, "goal": game.state["goal_progress"], "energy": game.state["energy"], "balance": game.state["balance"], "performed": game.performed, "ending": game.ending_id, "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true)}
