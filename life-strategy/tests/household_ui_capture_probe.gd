extends "res://tests/story_series_visual_probe.gd"

const Game := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var menu := Menu.instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	await save("00-story-menu")
	menu.queue_free()
	await process_frame
	Session.request("choir_week")
	var game := Game.instantiate() as GameRootV2
	root.add_child(game)
	current_scene = game
	await settle()
	game.new_day_popup.hide_popup(false)
	game._new_day_pending = false
	game._choose_meal_source("home_kitchen")
	game._on_food_toggled("rice_plain")
	game._on_food_toggled("soft_tofu_greens")
	game._confirm_food(game.selected_food_ids.duplicate())
	await settle()
	await save("01-cooking-plan-top")
	var page := game._workspace as CookingPlanStage
	await workspace_click(game, page.option_buttons["storage:counter"])
	await save("02-counter-warning")
	await workspace_click(game, page.option_buttons["storage:fridge"])
	await save("03-cooking-plan-bottom")
	await click(page.close_button)
	await save("04-selected-recipes")
	game._show_kitchen()
	await settle()
	await save("05-stock")
	await click(game._workspace.close_button)
	await click(game.menu_button)
	await save("06-week-menu")
	await workspace_click(game, game._workspace.find_child("save", true, false))
	await save("07-save-slots")
	var result := {"errors": errors, "window": str(DisplayServer.window_get_size()), "scope": "Declared first-breakfast fixture for same-state design comparison; option and navigation controls use native input."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_CAPTURE_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
