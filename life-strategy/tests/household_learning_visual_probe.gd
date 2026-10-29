extends "res://tests/story_keyboard_visual_probe.gd"

const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
var routes: Array[Dictionary] = []


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	if OS.get_cmdline_user_args().has("--notice-only"):
		var game := await restored("prepared")
		await click(game._active_stage.skip_button)
		check(game._active_stage.preparation_note.visible, "Saved preparation did not produce a notice")
		check_preparation_layout(game)
		await save("09-next-meal-notice")
	elif OS.get_cmdline_user_args().has("--long-notice"):
		var game := await fresh()
		game.new_day_popup.hide_popup(false)
		game._new_day_pending = false
		game._choose_meal_source("home_kitchen")
		game.hand.assign(["soft_tofu_greens", "steamed_fish", "soft_apple"])
		check(game.confirm_household_food(game.hand.duplicate(), "fridge"), "Long-name fixture did not cook")
		game._skip_action()
		await settle()
		check_preparation_layout(game)
		await save("long-preparation-note")
	elif OS.get_cmdline_user_args().has("--restore-only"):
		for name in ["decision", "breakfast"]:
			var game := await restored(name)
			check(game.household_learning["opening_stage"] == name, "Process restart lost " + name)
			check(game._story_dialog.visible, "Process restart did not restore " + name)
			check(game.kitchen.history.size() == (0 if name == "decision" else 1), "Process restart repeated disposal")
			await save("restart-" + name)
			game.queue_free()
			await process_frame
	else:
		await outside_route()
		await cooking_route(false)
		await cooking_route(true)
		var campus := await fresh("campus_exam")
		await click(campus.new_day_popup.continue_button)
		check(not is_instance_valid(campus._story_dialog), "Campus gained the household introduction")
		await click(campus._active_stage._prop_for("cafeteria"))
		check(campus.phase == "breakfast", "Campus could not open its own menu")
		await save("15-campus-menu")
	var report := {"errors": errors, "routes": routes, "window": str(root.size), "scope": "Native mouse/keyboard routes from a new run through the next meal; batch route completes the first day. Restore-only runs in a separate engine process with encoded files. Not browser IndexedDB or a physical phone."}
	var report_name := "long-notice-report.json" if OS.get_cmdline_user_args().has("--long-notice") else ("notice-report.json" if OS.get_cmdline_user_args().has("--notice-only") else ("restart-report.json" if OS.get_cmdline_user_args().has("--restore-only") else "report.json"))
	var file := FileAccess.open(output.path_join(report_name), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("HOUSEHOLD_LEARNING_VISUAL=" + JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)


func fresh(id: String = "choir_week") -> GameRootV2:
	Session.request(id)
	var game := Game.instantiate() as GameRootV2
	game.health_history_path = ""
	root.add_child(game)
	current_scene = game
	await settle()
	return game


func snapshot(game: GameRootV2, name: String) -> void:
	var encoded := Codec.encode(game.capture_game_save())
	check(encoded["ok"], "Save could not encode: " + name)
	if encoded["ok"]:
		var file := FileAccess.open(output.path_join(name + ".json"), FileAccess.WRITE)
		file.store_string(encoded["text"])


func restored(name: String) -> GameRootV2:
	var decoded := Codec.decode(FileAccess.get_file_as_string(output.path_join(name + ".json")))
	check(decoded["ok"], "Save could not decode: " + name)
	Session.request_saved(decoded["save"])
	var game := Game.instantiate() as GameRootV2
	game.health_history_path = ""
	root.add_child(game)
	current_scene = game
	await settle()
	return game


func outside_route() -> void:
	var game := await fresh()
	await click(game.new_day_popup.continue_button)
	await save("01-opening-safety")
	snapshot(game, "decision")
	var baseline := game.state.duplicate(true)
	await key(KEY_ESCAPE)
	check(game.household_learning["opening_choice"] == "leave" and game.kitchen.batches[0]["quantity"] == 1, "Escape did not preserve the unhandled portion")
	await save("02-breakfast-options")
	await click(game._story_dialog._buttons.get_node("breakfast_shop"))
	check(game.state == baseline and game.today_meal_records.is_empty(), "Navigation spent resources")
	await save("03-outside-menu")
	var plate := await pick_plate(game)
	await click(game._active_stage._get_confirm_button())
	check(game.phase == "breakfast_action", "Outside breakfast did not settle")
	await click(game._active_stage.skip_button)
	check(game.phase == "lunch_source", "Outside route did not reach next meal")
	check(not game._active_stage.preparation_note.visible, "Outside route invented prepared food")
	routes.append({"route": "outside", "phase": game.phase, "plate": plate, "balance": game.state["balance"], "opening_quantity": game.kitchen.batches[0]["quantity"]})
	game.queue_free()
	await process_frame


func cooking_route(batch: bool) -> void:
	var game := await fresh()
	await click(game.new_day_popup.continue_button)
	await click(game._story_dialog._buttons.get_node("discard"))
	if batch:
		snapshot(game, "breakfast")
		await save("07-discarded-breakfast-options")
	await click(game._story_dialog._buttons.get_node("home_kitchen"))
	var plate := await pick_plate(game)
	await click(game._active_stage._get_confirm_button())
	var pantry := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	if batch:
		await workspace_click(game, game._workspace.option_buttons["storage:fridge"])
		await save("08-preparation-preview")
		await key(KEY_ESCAPE)
		check(game.kitchen.ingredients == pantry and game.kitchen.condiments == condiments and game.today_meal_records.is_empty(), "Cancelling preparation spent food")
		await click(game._active_stage._get_confirm_button())
		await workspace_click(game, game._workspace.option_buttons["storage:fridge"])
	else:
		await save("04-fresh-preview")
	await click(game._workspace.confirm_button)
	check(game.phase == "breakfast_action", "Cooking did not settle once")
	if batch:
		snapshot(game, "prepared")
		game.queue_free()
		await process_frame
		game = await restored("prepared")
	await click(game._active_stage.skip_button)
	check(game.phase == "lunch_source", "Cooking route did not reach lunch")
	check(game._active_stage.preparation_note.visible == batch, "Preparation notice disagrees with actual stock")
	if batch:
		var note: Control = game._active_stage.preparation_note
		check(root.get_visible_rect().encloses(note.get_global_rect()), "Preparation note is outside the window")
		check(not note.get_global_rect().intersects(game._active_stage.footer.get_global_rect()), "Preparation note overlaps footer")
		for id in HouseholdSourceStage.HOME_ORDER:
			check(not note.get_global_rect().intersects(game._active_stage.find_child(id, true, false).get_global_rect()), "Preparation note overlaps " + id)
		await save("09-next-meal-notice")
		await click(game._active_stage.find_child("home_fridge", true, false))
		for id in plate: await select_food(game, id)
	else:
		await save("05-fresh-next-meal")
		await click(game._active_stage.find_child("home_kitchen", true, false))
		await pick_plate(game)
	await click(game._active_stage._get_confirm_button())
	if not batch: await click(game._workspace.confirm_button)
	check(game.phase == "lunch_action" and game.today_meal_records.size() == 2, "Second meal did not settle")
	if batch:
		await save("10-reheated-meal")
		await click(game._active_stage.skip_button)
		await click(game._active_stage.find_child("home_kitchen", true, false))
		await pick_plate(game)
		await click(game._active_stage._get_confirm_button())
		await click(game._workspace.confirm_button)
		await click(game._active_stage.skip_button)
		var sleep: Control = game._active_stage._cards_by_id["sleep_early"]
		game._active_stage.sleep_scroll.ensure_control_visible(sleep)
		await settle()
		await click(sleep)
		check(game.phase == "summary", "Batch route did not finish the first day")
		check(game.run_history[0]["household_recap"]["reheated_meals"] == 1, "Daily recap lost actual reheating")
		await save("11-first-day-recap")
	routes.append({"route": "batch" if batch else "fresh", "phase": game.phase, "meals": game.today_meal_records.size(), "balance": game.state["balance"], "opening_quantity": game.kitchen.batches[0]["quantity"]})
	game.queue_free()
	await process_frame


func pick_plate(game: GameRootV2) -> Array[String]:
	var chosen: Array[String] = []
	for group in [["rice_plain", "millet_porridge", "oatmeal", "steamed_bun"], ["egg", "tofu", "steamed_egg", "soft_tofu_greens", "milk", "greens", "tomato", "soft_apple"]]:
		for id in group:
			if game.hand.has(id) and game._can_add_food(id):
				await select_food(game, id)
				chosen.append(id)
				break
	check(not chosen.is_empty(), "No legal plate in current menu")
	return chosen


func select_food(game: GameRootV2, id: String) -> void:
	var card: Control = game._active_stage._cards_by_id[id]
	game._active_stage.food_scroll.ensure_control_visible(card)
	await settle()
	await click(card)


func check_preparation_layout(game: GameRootV2) -> void:
	var stage := game._active_stage as HouseholdSourceStage
	var rect := stage.preparation_note.get_global_rect()
	check(root.get_visible_rect().encloses(rect), "Preparation note is outside the window")
	check(rect.encloses(stage._preparation_text.get_global_rect()), "Preparation text left its note")
	check(not rect.intersects(stage.footer.get_global_rect()), "Preparation note overlaps footer")
	for id in HouseholdSourceStage.HOME_ORDER:
		check(not rect.intersects(stage.find_child(id, true, false).get_global_rect()), "Preparation note overlaps " + id)
