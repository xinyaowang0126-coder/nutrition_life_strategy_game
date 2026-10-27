extends "res://tests/story_keyboard_visual_probe.gd"


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
	game.source_hands["breakfast:local_market"] = ["rice_plain", "oatmeal", "milk", "tomato_egg_stir_fry", "plain_yogurt", "apple", "steamed_fish", "tofu"]
	game._choose_meal_source("local_market")
	for id in ["milk", "tomato_egg_stir_fry", "plain_yogurt"]: game._on_food_toggled(id)
	await settle()
	var stage := game._active_stage as HouseholdMealStage
	var before := {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true)}
	check(game.selected_food_ids.size() == 3, "Three-food shopping fixture is incomplete")
	await save("01-three-selected")
	for card: HouseholdFoodCard in stage._cards_by_id.values():
		check(card.get_global_rect().encloses(card._status.get_global_rect()), "Food status is clipped: " + card.item_id)
	game._on_food_toggled("milk")
	game._on_food_toggled("apple")
	var milk := stage._cards_by_id["milk"] as HouseholdFoodCard
	stage.food_scroll.ensure_control_visible(milk)
	await settle()
	await save("02-blocked-food")
	check(milk.get_global_rect().encloses(milk._status.get_global_rect()), "Unavailable milk status is clipped")
	milk.info_button.grab_focus()
	await key(KEY_ENTER)
	check(game.sticky_note.visible and game.sticky_note.disabled_reason_label.visible, "Blocked food details must show the current selection limit")
	check(game.sticky_note.disabled_reason_label.text == milk._reason, "Details and card disagree about why selection is blocked")
	await save("03-blocked-details")
	await key(KEY_ESCAPE)
	var remove := stage.find_child("Remove_apple", true, false) as Button
	check(remove != null, "Selected foods need an explicit remove action")
	if remove != null:
		await click(remove)
		check(game.selected_food_ids == ["tomato_egg_stir_fry", "plain_yogurt"], "Remove changed the wrong selection")
		check(not milk.disabled, "Removing a food must re-enable available cards")
		milk.info_button.grab_focus()
		await key(KEY_ENTER)
		check(not game.sticky_note.disabled_reason_label.visible, "Reopened details retained an old blocked reason")
		await key(KEY_ESCAPE)
		var next_remove := stage.find_child("Remove_tomato_egg_stir_fry", true, false) as Button
		next_remove.grab_focus()
		await key(KEY_ENTER)
		check(game.selected_food_ids == ["plain_yogurt"], "Keyboard remove changed the wrong food")
		check(root.gui_get_focus_owner() == stage.find_child("Remove_plain_yogurt", true, false), "Keyboard removal must keep focus on the next selected food")
		await save("04-after-removal")
		await key(KEY_ENTER)
		check(game.selected_food_ids.is_empty() and stage._get_confirm_button().disabled, "Removing the last food must disable confirmation")
		check(root.gui_get_focus_owner() == stage._cards_by_id["plain_yogurt"], "Removing the last food must restore its card focus")
		await save("05-empty-selection")
		await key(KEY_ENTER)
		check(game.selected_food_ids == ["plain_yogurt"], "The focused food card must remain usable after removing the last item")
	var first_window := DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(1280, 720) if first_window.y > first_window.x else Vector2i(390, 844))
	await settle()
	stage = game._active_stage as HouseholdMealStage
	for card: HouseholdFoodCard in stage._cards_by_id.values():
		check(card.get_global_rect().encloses(card._status.get_global_rect()), "Food status clipped after resizing: " + card.item_id)
	check(stage.paper_panel.get_global_rect().encloses(stage._footer.get_global_rect()), "Resizing pushed the footer out of the paper")
	await save("06-resized-selection")
	check(game.state == before["state"] and game.kitchen.ingredients == before["ingredients"] and game.kitchen.condiments == before["condiments"], "Editing selections spent money or stock")
	check(game.today_meal_records.is_empty() and game.phase == "breakfast", "Editing selections settled a meal")
	var result := {"errors": errors, "window": str(first_window), "resized_to": str(DisplayServer.window_get_size()), "scope": "Declared market hand with eight real market foods and three selected items; real native mouse and key input for details and removal, plus live window resizing. No purchase or stock consumption."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_SELECTION_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
