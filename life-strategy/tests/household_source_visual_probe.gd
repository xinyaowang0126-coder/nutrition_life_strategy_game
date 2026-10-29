extends "res://tests/story_keyboard_visual_probe.gd"

var cases: Array[Dictionary] = []


func _run() -> void:
	var resolutions := [Vector2i(1280, 720), Vector2i(640, 960), Vector2i(390, 640)]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			resolutions = [Vector2i(int(parts[0]), int(parts[1]))]
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in resolutions:
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
		var prefix := "%dx%d-" % [resolution.x, resolution.y]
		check(root.size == resolution, prefix + "window differs from requested size")
		check(game._mobile_mode == (resolution.y > resolution.x * 1.18), prefix + "wrong responsive profile")
		game.new_day_popup.continue_button.grab_focus()
		await key(KEY_ENTER)
		await finish_household_opening(game)
		check(game.phase == "breakfast_source" and not is_instance_valid(game._workspace), prefix + "day entry opened a worktop")
		check(not game._new_day_pending, prefix + "new day did not continue")
		if game._new_day_pending: break
		var stage := game._active_stage as HouseholdSourceStage
		check(stage != null, prefix + "missing home decision stage")
		if stage == null: break
		await move_mouse(Vector2(10, 90))
		await save(prefix + "01-home")
		check(game._background_path_for_phase() == (HouseholdSourceStage.PORTRAIT_SCENE if game._mobile_mode else HouseholdSourceStage.WIDE_SCENE), prefix + "source scene is not the same home")
		for id: String in stage.HOME_ORDER:
			var prop := stage._props[id] as Control
			check(root.get_visible_rect().encloses(prop.get_global_rect()), prefix + id + " outside viewport")
			var plaque := prop.get_node("Nameplate") as Control
			check(not plaque.get_global_rect().intersects(stage.footer.get_global_rect()), prefix + id + " overlaps tools")
			check(prop.get_global_rect().grow(1).encloses(plaque.get_global_rect()), prefix + id + " name is outside its click target")
			var art := prop.get_node("Illustration/Art") as TextureRect
			check(art.texture != null and art.is_visible_in_tree(), prefix + id + " has no visible graphical entry")
			check(prop.get_node(id).get_global_rect().encloses(art.get_global_rect()), prefix + id + " art is outside its clickable body")
			var texture_size := art.texture.get_size()
			var fit := minf(art.size.x / texture_size.x, art.size.y / texture_size.y)
			var corner := (art.size - texture_size * fit) * 0.5 + Vector2(2, 2)
			var target := prop.get_node(id) as HouseholdPropButton
			var local_point := target.get_global_transform().affine_inverse() * (art.get_global_transform() * corner)
			check(not target._has_point(local_point), prefix + id + " transparent pixels block another object")
		await move_mouse(stage._props["home_kitchen"].get_node("Illustration/Art").get_global_rect().get_center())
		check(stage._props["home_kitchen"].get_node("Illustration").scale.x > 1.0, prefix + "hover only changed a text button")
		await save(prefix + "01-cooking-hover")
		await move_mouse(Vector2(10, 90))
		check(stage.find_child("community_canteen", true, false) == null, prefix + "canteen is presented as an indoor object")
		var before := {"state": game.state.duplicate(true), "pantry": game.kitchen.ingredients.duplicate(true), "batches": game.kitchen.batches.duplicate(true)}
		await click(stage.find_child("go_out", true, false))
		check(game._story_dialog.visible, prefix + "shopping tote did not open outings")
		check(game._story_dialog._buttons.get_node("community_canteen").disabled, prefix + "closed canteen is selectable")
		check(game.phase == "breakfast_source" and game.current_source_id.is_empty(), prefix + "opening outings moved the character")
		for id in ["community_canteen", "local_market"]:
			var row := game._story_dialog._buttons.get_node(id) as Button
			check(game._story_dialog._panel.get_global_rect().encloses(row.get_global_rect()), prefix + id + " escapes outing popup")
			check(row.get_global_rect().encloses(row.get_node("LocationPhoto").get_global_rect()), prefix + id + " photo escapes row")
		await save(prefix + "02-outings")
		await key(KEY_ESCAPE)
		check(not game._story_dialog.visible and game.current_source_id.is_empty(), prefix + "cancel did not stay home")
		check(root.gui_get_focus_owner() == stage.find_child("go_out", true, false), prefix + "cancel lost the tote focus")
		await click(stage._props["home_fridge"].get_node("Info"))
		check(game.sticky_note.visible and game.sticky_note.pinned, prefix + "home details did not open")
		await save(prefix + "03-home-details")
		await key(KEY_ESCAPE)
		check(not game.sticky_note.visible, prefix + "Escape did not close home details")
		await click(stage.find_child("Notebook", true, false))
		check(game._story_dialog.visible and not is_instance_valid(game._workspace), prefix + "notebook is not an explicit popup")
		await save(prefix + "04-notebook")
		await key(KEY_ESCAPE)
		await click(stage._props["home_kitchen"].get_node("Illustration/Art"))
		check(game.current_source_id == "home_kitchen" and game.phase == "breakfast", prefix + "clicking the cooking picture did not choose cooking")
		check(not is_instance_valid(game._workspace), prefix + "worktop opened before recipe selection")
		await save(prefix + "05-cooking-foods")
		game._on_food_toggled("rice_plain")
		game._on_food_toggled("soft_tofu_greens")
		await settle()
		await click(game._active_stage._get_confirm_button())
		check(game._workspace is CookingPlanStage, prefix + "selected recipes did not open cooking")
		await save(prefix + "06-cooking-plan")
		await key(KEY_ESCAPE)
		check(game.selected_food_ids == ["rice_plain", "soft_tofu_greens"], prefix + "return lost food selection")
		await click(game._active_stage.find_child("BackButton", true, false))
		check(game._active_stage is HouseholdSourceStage and not is_instance_valid(game._workspace), prefix + "back kept the kitchen panel")
		await click(game._active_stage._props["home_kitchen"].get_node("Nameplate"))
		check(game.current_source_id == "home_kitchen", prefix + "caption and picture did not activate the same choice")
		await click(game._active_stage.find_child("BackButton", true, false))
		await choose_outing(game, "local_market")
		check(game.current_source_id == "local_market" and not is_instance_valid(game._workspace), prefix + "market opened a cooking worktop")
		check(game._background_path_for_phase().contains("convenience_background"), prefix + "selected outing did not show the store")
		await save(prefix + "07-market")
		await click(game._active_stage.find_child("BackButton", true, false))
		check(game._background_path_for_phase() == (HouseholdSourceStage.PORTRAIT_SCENE if game._mobile_mode else HouseholdSourceStage.WIDE_SCENE), prefix + "return from store did not show home")
		await click(game._active_stage.find_child("home_fridge", true, false))
		check(game.current_source_id == "home_fridge" and not is_instance_valid(game._workspace), prefix + "fridge opened cooking")
		await save(prefix + "08-fridge")
		check(game.state == before["state"] and game.kitchen.ingredients == before["pantry"] and game.kitchen.batches == before["batches"], prefix + "navigation spent resources")
		check(game.today_meal_records.is_empty(), prefix + "navigation recorded a meal")
		game.phase = "lunch_source"
		game.current_source_id = ""
		game._render_phase()
		await settle()
		await save(prefix + "09-lunch-home")
		await click(game._active_stage.find_child("go_out", true, false))
		check(not game._story_dialog._buttons.get_node("community_canteen").disabled, prefix + "canteen did not open at lunch")
		await save(prefix + "10-lunch-outings")
		await click(game._story_dialog._buttons.get_node("community_canteen"))
		check(game.current_source_id == "community_canteen" and not is_instance_valid(game._workspace), prefix + "canteen opened cooking")
		check(game._background_path_for_phase().contains("cafeteria_background"), prefix + "canteen still shows the home")
		await save(prefix + "11-canteen")
		game._change_meal_source()
		await settle()
		await click(game._active_stage.find_child("skip", true, false))
		check(game.phase == "lunch_action" and not is_instance_valid(game._workspace), prefix + "skip kept a kitchen panel")
		await save(prefix + "12-action")
		cases.append({"resolution": str(resolution), "actual_window": str(root.size), "mobile": game._mobile_mode, "canvas": str(root.get_visible_rect().size), "phase": game.phase, "meals": game.today_meal_records.size()})
		game.queue_free()
		await process_frame
	var result := {"errors": errors, "cases": cases, "scope": "Independent native windows. Viewport mouse and keyboard input exercises home objects, explicit outings/cancellation, context changes, notebook, cooking preview and return. Food choices and lunch are declared fixtures; no full-day completion is claimed."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_SOURCE_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func choose_outing(game: GameRootV2, id: String) -> void:
	await click(game._active_stage.find_child("go_out", true, false))
	var button := game._story_dialog._buttons.get_node(id) as Button
	button.grab_focus()
	await key(KEY_ENTER)


func move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await settle()


func click(control: Control) -> void:
	var available := control != null and control.is_visible_in_tree() and (not control is Button or not (control as Button).disabled)
	check(available, "Control unavailable: " + (String(control.name) if control != null else "null"))
	if not available: return
	var bounds := control.get_global_rect()
	check(root.get_visible_rect().encloses(bounds), "Control outside viewport: " + String(control.name))
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = bounds.get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()


func key(code: Key, shift: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()
