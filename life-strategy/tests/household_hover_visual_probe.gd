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
	# Start at meal choice; the day-introduction flow has its own probe.
	game.new_day_popup.hide_popup(false)
	game._new_day_pending = false
	await settle()
	var before := {"state": game.state.duplicate(true), "pantry": game.kitchen.ingredients.duplicate(true), "batches": game.kitchen.batches.duplicate(true)}
	var home := game._active_stage as HouseholdSourceStage
	await move_mouse(Vector2(8, 90))
	await save("home-prompt")
	var outing_info := home._props["go_out"].get_node("Info") as Button
	check(outing_info != null and outing_info.is_visible_in_tree(), "Outing details button is missing")
	if game._mobile_mode:
		await tap(outing_info)
	else:
		await click(outing_info)
	check(game.sticky_note.is_showing_item("go_out") and game.sticky_note.pinned, "Outing details did not pin")
	check(game._active_stage == home, "Reading outing details entered the market")
	check(game.state == before["state"], "Outing details spent resources")
	await save("outing-details")
	await key(KEY_ESCAPE)
	check(root.gui_get_focus_owner() == outing_info, "Closing outing details lost the details-button focus")
	outing_info.release_focus()
	await move_mouse(Vector2(8, 90))
	if not game._mobile_mode:
		for id: String in HouseholdSourceStage.HOME_ORDER:
			await move_mouse(home._props[id].get_node("Illustration/Art").get_global_rect().get_center())
			check(game.sticky_note.is_showing_item(id) and not game.sticky_note.pinned, "Home hover did not show " + id)
			check(game.sticky_note.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Preview intercepts input")
			await save("home-hover-" + id)
			await move_mouse(Vector2(8, 90))
			check(not game.sticky_note.visible, "Home preview stayed after exit: " + id)
	await click(home._props["home_kitchen"].get_node("Illustration/Art"))
	var meal := game._active_stage as HouseholdMealStage
	var card := meal._cards_by_id["egg"] as HouseholdFoodCard
	meal.food_scroll.ensure_control_visible(card)
	await settle()
	if not game._mobile_mode:
		await move_mouse(card.get_global_rect().get_center())
		check(game.sticky_note.is_showing_item("egg") and not game.sticky_note.pinned, "Food hover did not show details")
		await save("food-hover")
		await move_mouse(Vector2(8, 90))
		check(not game.sticky_note.visible, "Food preview stayed after exit")
		card.grab_focus()
		await settle()
		check(game.sticky_note.is_showing_item("egg"), "Keyboard focus did not preview food")
		card.release_focus()
	await click(card.info_button)
	check(game.sticky_note.is_showing_item("egg") and game.sticky_note.pinned, "Food details button did not pin")
	await key(KEY_ESCAPE)
	check(game.selected_food_ids.is_empty(), "Reading food details selected food")
	await click(meal.find_child("BackButton", true, false))
	await click(game._active_stage.find_child("go_out", true, false))
	var market := game._active_stage as HouseholdMarketStage
	await move_mouse(Vector2(8, 90))
	await save("market-breakfast")
	for id: String in HouseholdMarketStage.OUTSIDE_ORDER:
		var choice := market._choices[id] as Button
		var photo := choice.get_node("Illustration/Art") as TextureRect
		check(photo.texture != null and photo.is_visible_in_tree(), "Missing shop picture: " + id)
		for part: Control in [photo, choice.get_node("Plaque"), choice.get_node("Info")]:
			check(choice.get_global_rect().encloses(part.get_global_rect()), "Shop content escapes: " + id + "/" + String(part.name))
		check(not choice.get_global_rect().intersects(game.character_hud.status_board.get_global_rect()), "Shop overlaps status: " + id)
		if not game._mobile_mode:
			await move_mouse(photo.get_global_rect().get_center())
			check(game.sticky_note.is_showing_item(id) and not game.sticky_note.pinned, "Shop hover missing, including closed shops: " + id)
			check(root.get_visible_rect().encloses(game.sticky_note.get_global_rect()), "Shop preview escapes viewport: " + id)
			await save("market-hover-" + id)
			await move_mouse(Vector2(8, 90))
			check(not game.sticky_note.visible, "Shop preview stayed after exit: " + id)
	var closed := market._choices["community_canteen"] as Button
	check(closed.disabled, "Diner should be closed at breakfast")
	await click(closed.get_node("Info"))
	check(game.sticky_note.pinned and game.sticky_note.is_showing_item("community_canteen"), "Closed shop details did not pin")
	check(not game.sticky_note.disabled_reason_label.text.is_empty(), "Closed shop has no reason")
	await save("closed-shop-details")
	await key(KEY_ESCAPE)
	if game._mobile_mode:
		await tap(market._choices["breakfast_shop"].get_node("Illustration/Art"))
	else:
		await click(market._choices["breakfast_shop"].get_node("Illustration/Art"))
	check(game.current_source_id == "breakfast_shop", "Breakfast picture did not enter menu")
	await save("breakfast-menu")
	await click(game._active_stage.find_child("BackButton", true, false))
	market = game._active_stage as HouseholdMarketStage
	await click(market._choices["local_market"].get_node("Plaque/Name"))
	check(game.current_source_id == "local_market", "Fruit name did not enter the same menu as its image")
	await click(game._active_stage.find_child("BackButton", true, false))
	await key(KEY_ESCAPE)
	check(game._active_stage is HouseholdSourceStage, "Escape did not return home")
	check(game.state == before["state"] and game.kitchen.ingredients == before["pantry"] and game.kitchen.batches == before["batches"], "Browsing or details spent resources")
	check(game.today_meal_records.is_empty(), "Browsing recorded a meal")
	game.phase = "lunch_source"
	game._render_phase()
	await settle()
	await click(game._active_stage.find_child("go_out", true, false))
	market = game._active_stage as HouseholdMarketStage
	check(market._choices["breakfast_shop"].disabled, "Breakfast shop should be closed at lunch")
	check(not market._choices["community_canteen"].disabled, "Diner should be open at lunch")
	await move_mouse(Vector2(8, 90))
	await save("market-lunch")
	market._choices["community_canteen"].grab_focus()
	await key(KEY_ENTER)
	check(game.current_source_id == "community_canteen", "Keyboard did not enter diner")
	var result := {"errors": errors, "window": str(root.size), "mobile": game._mobile_mode, "scope": "Independent native window; actual mouse and keyboard check home/food/shop previews, dismissal, pictures and names, pinned closed-shop details, return navigation and lunch opening hours. Raw ScreenTouch taps the breakfast picture on mobile. In-memory saves, first-day intro and lunch are declared fixtures, no purchases or day progression."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_HOVER_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func move_mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point * (Vector2(root.size) / root.get_visible_rect().size)
	event.global_position = event.position
	Input.parse_input_event(event)
	await settle()


func click(control: Control) -> void:
	check(control != null and control.is_visible_in_tree(), "Missing click target")
	if control == null: return
	var point := control.get_global_rect().get_center() * (Vector2(root.size) / root.get_visible_rect().size)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()


func key(code: Key, shift: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()


func tap(control: Control) -> void:
	var point := control.get_global_rect().get_center() * (Vector2(root.size) / root.get_visible_rect().size)
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()
