extends "res://tests/story_series_visual_probe.gd"

const Game := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	Session.request("choir_week")
	var game := Game.instantiate() as GameRootV2
	root.add_child(game)
	current_scene = game
	await settle()
	await click(game.new_day_popup.continue_button)
	await source_tool(game, "kitchen")
	await click(game._workspace.find_child("before_week_greens", true, false))
	await click(game._workspace.close_button)
	await click(game._active_stage.find_child("home_kitchen", true, false))
	await save("01-home-menu")
	for id in ["millet_porridge", "steamed_egg", "soft_tofu_greens", "soft_apple"]:
		var card: Control = game._active_stage._cards_by_id[id]
		game._active_stage.food_scroll.ensure_control_visible(card)
		await settle()
		await save("02-food-" + id)
	for id in ["millet_porridge", "soft_tofu_greens", "steamed_egg"]:
		await choose_food(game, id)
	var before := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	await click(game._active_stage._get_confirm_button())
	await save("03-recipe-default")
	await workspace_click(game, game._workspace.option_buttons["seasoning:usual"])
	await workspace_click(game, game._workspace.option_buttons["sugar:4"])
	await workspace_click(game, game._workspace.option_buttons["storage:fridge"])
	await save("04-recipe-adjusted")
	check(game.kitchen.ingredients == before and game.kitchen.condiments == condiments, "Preview spent pantry")
	await click(game._workspace.close_button)
	check(game.today_meal_records.is_empty(), "Cancel settled a meal")
	await click(game._active_stage._get_confirm_button())
	await workspace_click(game, game._workspace.option_buttons["sugar:4"])
	await workspace_click(game, game._workspace.option_buttons["storage:fridge"])
	await click(game._workspace.confirm_button)
	check(game.phase == "breakfast_action", "Configured cooking did not settle")
	check(game.kitchen.condiments["soy_ml"] == 50 and game.kitchen.condiments["sugar_g"] == 32, "Configured portion charges wrong")
	await click(game._active_stage.skip_button)
	await settle()
	await source_tool(game, "recipe")
	await save("05-confirmed-recipe-record")
	await click(game._workspace.close_button)
	await click(game._active_stage.find_child("home_fridge", true, false))
	for id in ["millet_porridge", "soft_tofu_greens", "steamed_egg"]:
		await choose_food(game, id)
	await save("06-fridge-new-foods")
	await click(game._active_stage._get_confirm_button())
	check(game.today_meal_records.back()["recipe_facts"]["white_sugar_added_g"] == 4, "Reheat changed frozen sugar")
	check(game.today_meal_records.back()["recipe_facts"]["sodium_from_added_seasonings_mg"] == 750, "Reheat changed frozen seasoning")
	await settle()

	# A declared day-4 fixture isolates this branch; seven-day routes are tested
	# separately by story_series. All choices below use actual UI mouse input.
	game.day = 4
	game.phase = "lunch_action"
	game.used_action_ids.clear()
	game.used_action_names.clear()
	game.actions_used_today = 0
	game._render_phase()
	await settle()
	var call_card: Control = game._active_stage._cards_by_id["call_friend"]
	game._active_stage.action_scroll.ensure_control_visible(call_card)
	await settle()
	await click(call_card)
	await save("07-shared-invitation")
	await workspace_click(game, game._workspace.find_child("home", true, false))
	check(game.shared_meal.plan.get("status") == "planned", "Invitation not saved as pending")
	await click(game._active_stage.skip_button)
	await save("08-dinner-plan")
	await click(game._active_stage.find_child("home_kitchen", true, false))
	for id in ["rice_plain", "soft_tofu_greens"]:
		await choose_food(game, id)
	await click(game._active_stage._get_confirm_button())
	await save("09-two-person-recipe")
	await click(game._workspace.confirm_button)
	check(game.shared_meal.plan.get("status") == "completed", "Real dinner did not complete invitation")
	check(game.today_meal_records.back().get("companions", []).size() == 1, "Real dinner has no companion")
	game._show_recipe_records()
	await settle()
	await save("10-shared-completed-record")
	check(game.recovery_diagnostics.is_empty(), "Recovery diagnostics in content flow")
	var result := {"errors": errors, "phase": game.phase, "shared_status": game.shared_meal.plan.get("status"), "window": str(DisplayServer.window_get_size()), "scope": "Actual native clicks for cooking and records; declared day-4 fixture for shared-meal branch."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_VISUAL_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func choose_food(game: GameRootV2, id: String) -> void:
	check(game._active_stage._cards_by_id.has(id), "Food not available: " + id)
	if not game._active_stage._cards_by_id.has(id):
		return
	var card: Control = game._active_stage._cards_by_id[id]
	game._active_stage.food_scroll.ensure_control_visible(card)
	await settle()
	await click(card)
