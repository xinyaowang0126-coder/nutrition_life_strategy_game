extends "res://tests/story_series_visual_probe.gd"

const Session := preload("res://scripts/stories/StorySession.gd")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var menu := Menu.instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	await save("01-story-menu")
	var card: Control = menu._grid.get_node("choir_week")
	(menu._margin.get_child(0) as ScrollContainer).ensure_control_visible(card)
	await settle()
	await click(card.find_child("ChooseStory", true, false))
	await save("02-story-intro")
	await click(menu._dialog._buttons.get_node("start"))
	await settle()
	var game := current_scene as GameRootV2
	if game == null:
		check(false, "No story game")
		quit(1)
		return
	await save("03-new-day")
	await click(game.new_day_popup.continue_button)
	await finish_household_opening(game)
	check(not is_instance_valid(game._workspace), "Kitchen must not open automatically before a destination is chosen")
	await source_tool(game, "kitchen")
	await save("04-unsafe-leftovers")
	await workspace_click(game, game._workspace.find_child("before_week_greens", true, false))
	check(game.kitchen.batches[0]["quantity"] == 0, "Discard failed")
	await click(game._workspace.close_button)
	check(not game.new_day_popup.visible, "Closing stock page repeated new day")
	await save("05-meal-sources")
	await source_click(game, "home_kitchen")
	await choose_food(game, "rice_plain")
	await choose_food(game, "soft_tofu_greens")
	await save("06-selected-recipes")
	var ingredients := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	await click(game._active_stage._get_confirm_button())
	await save("07-cooking-plan-top")
	var plan := game._workspace as CookingPlanStage
	await workspace_click(game, plan.option_buttons["storage:counter"])
	await save("08-counter-warning")
	await workspace_click(game, plan.option_buttons["storage:fridge"])
	check(plan.ingredients_needed == {"rice_plain": 2, "tofu": 2, "greens": 2}, "Extra portion preview incorrect")
	check(game.kitchen.ingredients == ingredients and game.kitchen.condiments == condiments, "Preview charged inventory")
	await save("09-cooking-plan-bottom")
	await click(plan.close_button)
	check(game.selected_food_ids == ["rice_plain", "soft_tofu_greens"], "Back lost selection")
	await click(game._active_stage._get_confirm_button())
	plan = game._workspace as CookingPlanStage
	await workspace_click(game, plan.option_buttons["storage:fridge"])
	await click(plan.confirm_button)
	check(game.phase == "breakfast_action", "Cooking did not settle")
	check(game.today_meal_records.size() == 1, "Meal settlement count wrong")
	check(game.kitchen.ingredients["rice_plain"] == 6, "Extra portion not charged")
	await click(game.menu_button)
	await save("10-week-menu")
	await workspace_click(game, game._workspace.find_child("save", true, false))
	await save("11-save-slots")
	await workspace_click(game, game._workspace.find_child("manual_1", true, false))
	check(game._save_store.read_save("choir_week", "manual_1")["ok"], "Manual save failed")
	await click(game._story_dialog._buttons.get_node("close"))
	await click(game.menu_button)
	await workspace_click(game, game._workspace.find_child("load", true, false))
	await save("12-load-slots")
	await workspace_click(game, game._workspace.find_child("manual_1", true, false))
	await click(game._story_dialog._buttons.get_node("read"))
	check(game.phase == "breakfast_action" and game.today_meal_records.size() == 1, "Save restore lost stage or meal")
	await click(game.menu_button)
	await workspace_click(game, game._workspace.find_child("records", true, false))
	await save("13-recipe-records")
	await click(game._workspace.close_button)
	await click(game._active_stage.skip_button)
	await source_click(game, "home_fridge")
	await choose_food(game, "rice_plain")
	await choose_food(game, "soft_tofu_greens")
	await save("14-fridge-meal")
	await click(game._active_stage._get_confirm_button())
	check(game.phase == "lunch_action", "Reheat did not settle")
	check(game.today_meal_records.back()["recipe_facts"]["sodium_from_added_seasonings_mg"] == 750, "Reheat altered frozen recipe")
	# Declared fixture for the day-4 invitation; real seven-day routes live in suites.
	game.day = 4
	game.phase = "lunch_action"
	game.used_action_ids.clear()
	game.used_action_names.clear()
	game.actions_used_today = 0
	game._render_phase()
	await settle()
	var friend: Control = game._active_stage._cards_by_id["call_friend"]
	game._active_stage.action_scroll.ensure_control_visible(friend)
	await settle()
	await click(friend)
	await save("15-shared-invitation")
	await workspace_click(game, game._workspace.find_child("home", true, false))
	check(game.shared_meal.plan.get("status") == "planned", "Invitation not planned")
	await click(game._active_stage.skip_button)
	await source_click(game, "home_kitchen")
	await choose_food(game, "rice_plain")
	await choose_food(game, "soft_tofu_greens")
	await click(game._active_stage._get_confirm_button())
	plan = game._workspace as CookingPlanStage
	await workspace_click(game, plan.option_buttons["storage:fridge"])
	await save("16-two-people-and-one-saved")
	check(plan.ingredients_needed == {"rice_plain": 3, "tofu": 3, "greens": 3}, "Shared meal and saved portion mismatch")
	check(not plan.confirm_button.disabled, "Available pantry should allow three sets")
	await workspace_click(game, plan.option_buttons["storage:eat_now"])
	await click(plan.confirm_button)
	check(game.shared_meal.plan.get("status") == "completed", "Actual shared dinner not completed")
	check(game.recovery_diagnostics.is_empty(), "Recovery diagnostics in UI route")
	var result := {"errors": errors, "phase": game.phase, "window": str(DisplayServer.window_get_size()), "scope": "Native rendered game, actual mouse clicks and scroll-container navigation; declared day-4 branch fixture."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_UI_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func workspace_click(game: GameRootV2, control: Control) -> void:
	if control == null:
		check(false, "Missing workspace control")
		return
	game._workspace.scroll.ensure_control_visible(control)
	await settle()
	await click(control)


func source_click(game: GameRootV2, id: String) -> void:
	var control: Control = game._active_stage.find_child(id, true, false)
	await settle()
	await click(control)


func choose_food(game: GameRootV2, id: String) -> void:
	if not game._active_stage._cards_by_id.has(id):
		check(false, "Missing food " + id)
		return
	var card: Control = game._active_stage._cards_by_id[id]
	game._active_stage.food_scroll.ensure_control_visible(card)
	await settle()
	await click(card)
