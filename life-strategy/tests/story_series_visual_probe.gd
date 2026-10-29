extends SceneTree

const Menu := preload("res://scenes/main_menu/MainMenu.tscn")
var output := "res://.godot/story-series-visual"
var errors: Array[String] = []


func _initialize() -> void:
	preload("res://scripts/stories/GameSaveStore.gd").memory_for_tests = true
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var menu := Menu.instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	await save("01-menu")
	await click(menu._title_start)
	await click(menu._strips["zhou_huilan_66"])
	await click(menu._more_info)
	check(menu._dialog.visible, "Story card did not open introduction")
	await save("02-intro")
	await click(menu._dialog._buttons.get_node("back"))
	await click(menu._main_start)
	await settle()
	var game := current_scene as GameRootV2
	check(game != null and game.story_id == "choir_week", "Wrong story after selection")
	if game == null:
		quit(1)
		return
	await save("03-new-day")
	await click(game.new_day_popup.continue_button)
	await finish_household_opening(game)
	await settle()
	check(not is_instance_valid(game._workspace), "Entering the day must leave the destination scene clear")
	await source_tool(game, "kitchen")
	check(is_instance_valid(game._workspace) and game._workspace.visible, "Explicit stock entry did not open")
	await save("04-leftovers")
	await click(game._workspace.find_child("before_week_greens", true, false))
	await click(game._workspace.close_button)
	await settle()
	check(game.kitchen.batches[0]["quantity"] == 0, "Unsafe leftovers not discarded once")
	await save("05-sources")
	var source_button: Button = game._active_stage.find_child("home_kitchen", true, false)
	await click(source_button)
	await settle()
	game._on_food_toggled("rice_plain")
	game._on_food_toggled("egg")
	await settle()
	await save("06-cooking-menu")
	await click(game._active_stage._get_confirm_button())
	await settle()
	check(game._workspace.visible, "Cooking decision did not appear")
	check(game.today_meal_records.size() == 0, "Preview paid or consumed a meal")
	await save("07-storage-choice")
	await workspace_click(game, game._workspace.option_buttons["storage:fridge"])
	await click(game._workspace.confirm_button)
	await settle()
	check(game.phase == "breakfast_action", "Cooking did not settle the meal")
	check(game.kitchen.ingredients["egg"] == 3, "Cooking extra portion charged wrong ingredients")
	await save("08-actions")
	game._apply_action("rehearse")
	await settle()
	await click(game._active_stage.find_child("home_fridge", true, false))
	await settle()
	game._on_food_toggled("rice_plain")
	game._on_food_toggled("egg")
	await settle()
	await save("09-fridge-meal")
	await click(game._active_stage._get_confirm_button())
	await settle()
	check(game.phase == "lunch_action", "Fridge consumption did not settle")
	check(game.kitchen.available("egg", 1) == 0, "Reheated batch remains available")
	check(game.recovery_diagnostics.is_empty(), "Runtime recovery error")
	var result := {"errors": errors, "story_id": game.story_id, "phase": game.phase, "meals": game.today_meal_records.size(), "goal": game.state.get("goal_progress", -1), "window": str(DisplayServer.window_get_size())}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("STORY_VISUAL_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func settle() -> void:
	await create_timer(0.4).timeout
	for i in range(3):
		await process_frame
	RenderingServer.force_draw()


func finish_household_opening(game: GameRootV2) -> void:
	# Existing probes explicitly take the non-disposal route before testing
	# their own feature. The learning probe captures and checks both choices.
	if game.household_learning.get("opening_stage") == "decision":
		await click(game._story_dialog._buttons.get_node("back"))
	if game.household_learning.get("opening_stage") == "breakfast":
		await click(game._story_dialog._buttons.get_node("close"))


func source_tool(game: GameRootV2, id: String) -> void:
	await click(game._active_stage.find_child("Notebook", true, false))
	await click(game._story_dialog._buttons.get_node(id))


func save(name: String) -> void:
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Screenshot failed")


func click(control: Control) -> void:
	var available: bool = control != null and control.is_visible_in_tree() and (not control is Button or not (control as Button).disabled)
	check(available, "Control unavailable: " + (String(control.name) if control != null else "null"))
	if not available:
		return
	var rect := control.get_global_rect()
	check(root.get_visible_rect().encloses(rect), "Control outside viewport: " + String(control.name))
	var position := rect.get_center() * (Vector2(root.size) / root.get_visible_rect().size)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()


func check(condition: bool, text: String) -> void:
	if not condition:
		errors.append(text)


func workspace_click(game: GameRootV2, control: Control) -> void:
	game._workspace.scroll.ensure_control_visible(control)
	await settle()
	await click(control)
