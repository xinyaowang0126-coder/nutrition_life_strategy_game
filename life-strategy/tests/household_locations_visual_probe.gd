extends "res://tests/household_source_visual_probe.gd"


func _run() -> void:
	var resolution := Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			resolution = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(output)
	root.size = resolution
	await settle()
	Session.request("choir_week")
	var game := Game.instantiate() as GameRootV2
	game.health_history_path = ""
	root.add_child(game)
	current_scene = game
	await settle()
	game._apply_responsive_profile()
	await settle()
	check(root.size == resolution, "Window differs from requested size")
	await click(game.new_day_popup.continue_button)
	await save("01-home")
	var before := {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "batches": game.kitchen.batches.duplicate(true)}
	await click(game._active_stage._props["home_kitchen"].get_node("Illustration/Art"))
	check(game._background_path_for_phase().contains("zhou-kitchen"), "Cooking still shows the living room")
	await save("02-kitchen")
	var stage := game._active_stage as HouseholdMealStage
	var first := stage._cards_by_id[game.hand[0]] as HouseholdFoodCard
	stage.food_scroll.ensure_control_visible(first)
	first.grab_focus()
	await key(KEY_ENTER)
	check(game.selected_food_ids.size() == 1, "Keyboard did not select a recipe card")
	await click(stage._get_confirm_button())
	check(game._workspace is CookingPlanStage, "Recipe did not open preparation preview")
	check(game._background_path_for_phase().contains("zhou-kitchen"), "Preparation left the kitchen")
	await save("03-cooking-plan")
	await key(KEY_ESCAPE)
	await click(game._active_stage.find_child("Kitchen", true, false))
	check(game._background_path_for_phase().contains("zhou-open-fridge"), "Stock view did not open the fridge")
	await save("04-open-stock")
	await key(KEY_ESCAPE)
	check(game._background_path_for_phase().contains("zhou-kitchen"), "Closing stock did not restore cooking")
	await click(game._active_stage.find_child("BackButton", true, false))
	await click(game._active_stage.find_child("home_fridge", true, false))
	check(game._background_path_for_phase().contains("zhou-open-fridge"), "Fridge menu still shows the living room")
	await save("05-fridge-foods")
	await click(game._active_stage.find_child("BackButton", true, false))
	await click(game._active_stage.find_child("go_out", true, false))
	var market := game._active_stage as HouseholdMarketStage
	check(market != null, "Going out did not open the market")
	check(game._background_path_for_phase() == (HouseholdLocations.MARKET_PORTRAIT if game._mobile_mode else HouseholdLocations.MARKET_WIDE), "Wrong market background")
	check(market._choices["community_canteen"].disabled, "Diner open at breakfast")
	check(not market._choices["breakfast_shop"].disabled, "Breakfast shop closed at breakfast")
	for id: String in HouseholdMarketStage.OUTSIDE_ORDER:
		var choice := market._choices[id] as Button
		check(root.get_visible_rect().encloses(choice.get_global_rect()), id + " hotspot outside viewport")
		check(choice.get_global_rect().encloses(choice.get_node("Plaque").get_global_rect()), id + " label escapes hotspot")
	await move_mouse(Vector2(8, 80))
	await save("06-market-breakfast")
	await click(market._choices["breakfast_shop"])
	check(game.current_source_id == "breakfast_shop", "Breakfast hotspot did not open its menu")
	await save("07-breakfast-shop")
	await click(game._active_stage.find_child("BackButton", true, false))
	check(game._active_stage is HouseholdMarketStage, "Shop return skipped the market")
	await click(game._active_stage._choices["local_market"])
	check(game.hand.size() == 2 and game.hand.has("apple") and game.hand.has("banana"), "Fruit stall has unrelated dishes")
	await save("08-fruit-stall")
	await click(game._active_stage.find_child("BackButton", true, false))
	await key(KEY_ESCAPE)
	check(game._active_stage is HouseholdSourceStage, "Escape from market did not return home")
	check(root.gui_get_focus_owner() == game._active_stage.find_child("go_out", true, false), "Return lost outing focus")
	check(game.state == before["state"] and game.kitchen.ingredients == before["ingredients"] and game.kitchen.batches == before["batches"], "Browsing spent resources")
	check(game.today_meal_records.is_empty(), "Browsing recorded a meal")
	# Lunch is an explicit fixture, so both opening-hours states are visible.
	game.phase = "lunch_source"
	game._render_phase()
	await settle()
	await click(game._active_stage.find_child("go_out", true, false))
	market = game._active_stage as HouseholdMarketStage
	check(market._choices["breakfast_shop"].disabled, "Breakfast shop open at lunch")
	check(not market._choices["community_canteen"].disabled, "Diner closed at lunch")
	await save("09-market-lunch")
	market._choices["community_canteen"].grab_focus()
	await key(KEY_ENTER)
	check(game.current_source_id == "community_canteen", "Keyboard did not enter the diner")
	check(game._background_path_for_phase().contains("zhou-homestyle-diner"), "Diner reuses the campus cafeteria")
	await save("10-homestyle-diner")
	stage = game._active_stage as HouseholdMealStage
	first = stage._cards_by_id[game.hand[0]] as HouseholdFoodCard
	stage.food_scroll.ensure_control_visible(first)
	first.grab_focus()
	await key(KEY_ENTER)
	var expected_cost := int(game._story_food(first.item_id)["cost"])
	await click(stage._get_confirm_button())
	check(game.phase == "lunch_action", "Purchase did not advance the meal")
	check(game.today_meal_records.size() == 1 and game.today_meal_records[0]["source_name"] == "家常小馆", "Confirmed record has old source name")
	check(int(game.state["balance"]) == int(before["state"]["balance"]) - expected_cost, "Purchase charged the wrong amount")
	check(game.kitchen.ingredients == before["ingredients"], "Purchased meal used pantry ingredients")
	await save("11-purchased-action")
	game.queue_free()
	await process_frame
	Session.request("campus_exam")
	game = Game.instantiate() as GameRootV2
	game.health_history_path = ""
	root.add_child(game)
	current_scene = game
	await settle()
	await click(game.new_day_popup.continue_button)
	game._choose_meal_source("cafeteria")
	await settle()
	check(game.current_source_id == "cafeteria" and not game._background_path_for_phase().contains("/locations/"), "Household locations leaked into campus story")
	await save("12-campus-regression")
	var result := {"errors": errors, "window": str(root.size), "mobile": game._mobile_mode, "scope": "Independent native window; viewport mouse and keyboard exercise home, kitchen, cooking preview, fridge inventory, market, every outlet and return. Lunch is a declared phase fixture; one diner purchase is confirmed. Campus source is a declared fixture. No full-day run claimed."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_LOCATIONS_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
