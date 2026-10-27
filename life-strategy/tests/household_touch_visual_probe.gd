extends "res://tests/story_series_visual_probe.gd"

const Game := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	Session.request("choir_week")
	var game := Game.instantiate() as GameRootV2
	root.add_child(game)
	current_scene = game
	await settle()
	game.new_day_popup.hide_popup(false)
	game._new_day_pending = false
	game._choose_meal_source("home_kitchen")
	await settle()
	var stage := game._active_stage as HouseholdMealStage
	var rice: Control = stage._cards_by_id["rice_plain"]
	stage.food_scroll.ensure_control_visible(rice)
	await settle()
	await touch_tap(rice)
	check(game.selected_food_ids == ["rice_plain"], "Touch tap must select exactly once")
	var tofu: Control = stage._cards_by_id["soft_tofu_greens"]
	stage.food_scroll.ensure_control_visible(tofu)
	await settle()
	await touch_swipe(tofu)
	check(game.selected_food_ids == ["rice_plain"], "Touch scroll must not choose a food")
	stage.food_scroll.ensure_control_visible(tofu)
	await settle()
	tofu.grab_focus()
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = down
		Input.parse_input_event(key)
		await process_frame
	await settle()
	check(game.selected_food_ids.has("soft_tofu_greens"), "Keyboard Enter must select focused food")
	var remove := stage.find_child("Remove_rice_plain", true, false) as Button
	var pantry := game.kitchen.ingredients.duplicate(true)
	await touch_tap(remove)
	check(game.selected_food_ids == ["soft_tofu_greens"], "Touch remove must change the selection exactly once")
	check(game.kitchen.ingredients == pantry and game.today_meal_records.is_empty(), "Touch removal must not spend stock or settle a meal")
	await save("01-touch-and-keyboard")
	var result := {"errors": errors, "selected": game.selected_food_ids, "window": str(DisplayServer.window_get_size()), "scope": "Native InputEventScreenTouch, ScreenDrag and keyboard events; browser touch handling remains separate."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_TOUCH_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func screen_point(control: Control) -> Vector2:
	return control.get_global_rect().get_center() * (Vector2(root.size) / root.get_visible_rect().size)


func touch_event(point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame


func touch_tap(control: Control) -> void:
	var point := screen_point(control)
	await touch_event(point, true)
	await touch_event(point, false)
	await settle()


func touch_swipe(control: Control) -> void:
	var point := screen_point(control)
	await touch_event(point, true)
	for step in range(1, 6):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = point + Vector2(0, -32 * step)
		drag.relative = Vector2(0, -32)
		Input.parse_input_event(drag)
		await process_frame
	await touch_event(point + Vector2(0, -160), false)
	await settle()
