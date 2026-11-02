extends "res://tests/story_keyboard_visual_probe.gd"

var pages: Array[Dictionary] = []


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	for view_size in [Vector2i(1280, 720), Vector2i(640, 960)]:
		DisplayServer.window_set_size(view_size)
		await settle()
		Session.request("choir_week")
		var game := Game.instantiate() as GameRootV2
		game.health_history_path = ""
		root.add_child(game)
		current_scene = game
		await settle()
		await click(game.new_day_popup.continue_button)
		var balance: int = game.state["balance"]
		var quantity: int = game.kitchen.ingredients["milk"]
		var source: Control = game._active_stage.find_child("home_fridge", true, false)
		var position := source.get_global_rect().get_center() * (Vector2(root.size) / root.get_visible_rect().size)
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = position
			event.global_position = position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			Input.parse_input_event(event)
		for frame in range(20):
			await process_frame
			if game.current_source_id == "home_fridge" and game._active_stage.find_child("OpeningDoors", true, false) != null: break
		check(game._active_stage.find_child("OpeningDoors", true, false) != null, "Opening doors did not render")
		for frame in range(7):
			await save("%dx%d-opening-frame-%02d" % [view_size.x, view_size.y, frame])
			await create_timer(0.04).timeout
		await save("%dx%d-01-opening" % [view_size.x, view_size.y])
		await settle()
		var stage := game._active_stage as HouseholdMealStage
		check(stage.has_method("_open_doors"), "Fridge did not use its own split layout")
		check(stage.fridge_panel.get_global_rect().end.x <= stage.tray_panel.get_global_rect().position.x, "Fridge compartments overlapped")
		await save("%dx%d-02-open-fridge" % [view_size.x, view_size.y])
		for id in ["milk", "apple"]:
			stage.food_scroll.ensure_control_visible(stage._cards_by_id[id])
			await settle()
			await click(stage._cards_by_id[id])
		check(game.selected_food_ids.size() == 2, "Shelf selections did not reach the tray")
		check(game.state["balance"] == balance and game.kitchen.ingredients["milk"] == quantity and game.today_meal_records.is_empty(), "Opening or selecting consumed resources")
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(16, root.size.y - 12)
		motion.global_position = motion.position
		Input.parse_input_event(motion)
		await settle()
		await save("%dx%d-03-selected" % [view_size.x, view_size.y])
		await click(stage.find_child("Kitchen", true, false))
		await click(game._workspace._tab_buttons["ingredients"])
		await save("%dx%d-04-stock-ingredients" % [view_size.x, view_size.y])
		await click(game._workspace.close_button)
		stage = game._active_stage as HouseholdMealStage
		check(game.selected_food_ids.size() == 2, "Stock inspection lost the selection")
		await click(stage._get_confirm_button())
		check(game.phase == "breakfast_action" and game.today_meal_records.size() == 1, "Fridge meal did not confirm once")
		check(game.state["balance"] == balance and game.kitchen.ingredients["milk"] == quantity - 1, "Fridge consumed the wrong resources")
		pages.append({"size": str(view_size), "meals": game.today_meal_records.size(), "balance": game.state["balance"]})
		game.queue_free()
		await settle()
	var result := {"errors": errors, "pages": pages, "scope": "Native pointer input; split fridge, opening animation, selection, stock inspection and one actual meal. In-memory saves."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_FRIDGE_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
