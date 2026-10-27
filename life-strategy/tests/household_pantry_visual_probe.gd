extends "res://tests/story_keyboard_visual_probe.gd"


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	Session.request("choir_week")
	var game := Game.instantiate() as GameRootV2
	game.health_history_path = ""
	root.add_child(game)
	current_scene = game
	await settle()
	game.new_day_popup.continue_button.grab_focus()
	await key(KEY_ENTER)
	await click(game._active_stage.find_child("home_kitchen", true, false))
	for id in ["rice_plain", "soft_tofu_greens", "soft_apple"]: await choose_food(game, id)
	await save("01-selected-recipes")
	await click(game._active_stage._get_confirm_button())
	var plan := game._workspace as CookingPlanStage
	check(plan != null, "Cooking plan did not open")
	if plan == null:
		quit(1)
		return
	var before := {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "batches": game.kitchen.batches.duplicate(true)}
	await save("02-plan-top")
	await workspace_click(game, plan._details_button)
	check(plan._seasoning_details.is_visible_in_tree(), "Recipe details did not expand")
	await save("02a-seasoning-details")
	await workspace_click(game, plan._details_button)
	check(not plan._seasoning_details.visible, "Recipe details did not collapse")
	await workspace_click(game, plan.option_buttons["storage:fridge"])
	check(plan._commit_summary.text.contains("当餐1份＋冷藏1份"), "Commit summary lost the saved portion")
	await save("03-plan-cold-portion")
	# Declared shortage fixture; restore stock before any actual commitment.
	game.kitchen.ingredients["tofu"] = 1
	game.kitchen.condiments["soy_ml"] = 7
	game.kitchen.condiments["sugar_g"] = 2
	await workspace_click(game, plan.option_buttons["sugar:4"])
	check(plan._shortage_note.text.contains("豆腐1份") and plan._shortage_note.text.contains("酱油3毫升") and plan._shortage_note.text.contains("白糖6克"), "Shortage quantities are incorrect")
	check(plan.confirm_button.disabled, "Shortage allowed commitment")
	await save("04-shortage-bottom")
	plan.scroll.scroll_vertical = 0
	await settle()
	check(plan.paper_panel.get_global_rect().encloses(plan._shortage_note.get_global_rect()), "Pinned shortage left the paper")
	check(plan.scroll.get_global_rect().end.y <= plan._shortage_note.get_global_rect().position.y, "Recipe scroll covers shortage")
	await save("05-shortage-top")
	game.kitchen.ingredients = before["ingredients"].duplicate(true)
	game.kitchen.condiments = before["condiments"].duplicate(true)
	await workspace_click(game, plan.option_buttons["sugar:0"])
	check(not plan.confirm_button.disabled, "Restored stock did not enable cooking")
	await key(KEY_ESCAPE)
	check(game.selected_food_ids == ["rice_plain", "soft_tofu_greens", "soft_apple"], "Returning from plan lost selected dishes")
	await click(game._active_stage.find_child("Kitchen", true, false))
	var stock := game._workspace as KitchenStockStage
	check(stock != null, "Stock page did not open")
	if stock == null:
		quit(1)
		return
	await save("06-stock-cooked")
	await workspace_click(game, stock.find_child("Details_before_week_greens", true, false))
	check(stock.find_child("Record_before_week_greens", true, false).is_visible_in_tree(), "Preservation details did not expand")
	await save("07-preservation-details")
	await click(stock._tab_buttons["ingredients"])
	check(stock._tab_pages["ingredients"].is_visible_in_tree() and not stock._tab_pages["cooked"].visible, "Stock tab did not change")
	await save("08-stock-ingredients")
	stock.scroll.scroll_vertical = int(stock.scroll.get_v_scroll_bar().max_value)
	await settle()
	await save("09-stock-condiments")
	check(stock.paper_panel.get_global_rect().encloses(stock._tab_buttons["cooked"].get_global_rect()), "Stock tabs scrolled offscreen")
	await click(stock._tab_buttons["cooked"])
	check(stock.scroll.scroll_vertical == 0, "Changing stock tabs retained the old scroll offset")
	check(stock.find_child("Record_before_week_greens", true, false).visible, "Changing tabs lost expanded details")
	for index in range(9):
		await key(KEY_TAB)
		check(stock.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped the stock modal")
	check(game.state == before["state"] and game.kitchen.ingredients == before["ingredients"] and game.kitchen.condiments == before["condiments"] and game.kitchen.batches == before["batches"] and game.today_meal_records.is_empty(), "Looking at pantry or changing recipe spent resources")
	await workspace_click(game, stock.find_child("before_week_greens", true, false))
	check(game.kitchen.batches[0]["quantity"] == 0, "Discard failed")
	check(root.gui_get_focus_owner() == stock._tab_buttons["cooked"], "Discarded card left keyboard focus behind")
	await save("10-stock-empty")
	await key(KEY_ESCAPE)
	await click(game._active_stage._get_confirm_button())
	plan = game._workspace as CookingPlanStage
	await workspace_click(game, plan.option_buttons["storage:fridge"])
	await click(plan.confirm_button)
	check(game.phase == "breakfast_action" and game.today_meal_records.size() == 1, "Cooking did not settle exactly one meal")
	await click(game._active_stage.skip_button)
	await source_tool(game, "kitchen")
	stock = game._workspace as KitchenStockStage
	check(stock.subtitle_label.text.contains("待再热3份"), "Stock count did not include the cooked dishes")
	await save("11-stock-ready")
	await workspace_click(game, stock.find_child("Details_batch_2", true, false))
	var record := stock.find_child("Record_batch_2", true, false) as Control
	check((record.get_child(1) as Label).text.contains("750"), "Stored batch did not preserve recipe quantities")
	await save("12-frozen-recipe-details")
	await key(KEY_ESCAPE)
	await click(game._active_stage.find_child("home_fridge", true, false))
	for id in ["rice_plain", "soft_tofu_greens", "soft_apple"]: await choose_food(game, id)
	await save("13-reheat-selection")
	await click(game._active_stage._get_confirm_button())
	check(game.phase == "lunch_action" and game.today_meal_records.size() == 2, "Reheat did not settle exactly one meal")
	check(game.today_meal_records.back()["recipe_facts"]["sodium_from_added_seasonings_mg"] == 750, "Reheat changed the frozen recipe")
	for batch in game.kitchen.batches: check(int(batch["quantity"]) == 0, "Reheated stock remains available")
	check(game.recovery_diagnostics.is_empty(), "Recovery diagnostics in cooking route")
	var result := {"errors": errors, "window": str(DisplayServer.window_get_size()), "phase": game.phase, "meals": game.today_meal_records.size(), "scope": "Independent native window, actual viewport mouse and keyboard events. First-day cooking, safe cold storage and next-meal reheat; explicit temporary shortage fixture restored before cooking. No browser or real-device claim."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_PANTRY_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func choose_food(game: GameRootV2, id: String) -> void:
	var card := game._active_stage._cards_by_id.get(id) as Control
	if card == null:
		check(false, "Missing food " + id)
		return
	game._active_stage.food_scroll.ensure_control_visible(card)
	await settle()
	await click(card)
