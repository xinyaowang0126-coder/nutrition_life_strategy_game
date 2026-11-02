extends "res://tests/campus_week_visual_probe.gd"

const Journal := preload("res://scripts/stories/CampusStudyJournal.gd")
const Learning := preload("res://scripts/stories/CampusMealLearning.gd")
const Resources := preload("res://scripts/stories/CampusResourcePlan.gd")


func _run() -> void:
	var view_size := Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--width="): view_size.x = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="): view_size.y = int(arg.trim_prefix("--height="))
		elif arg == "--restore-only": restore_only = true
	DirAccess.make_dir_recursive_absolute(output)
	root.size = view_size
	if OS.get_cmdline_user_args().has("--whole-week"):
		for seed_value in [42, 43]: await whole_week(seed_value, reserved_fixture(seed_value))
	elif restore_only:
		var saved_cases := ["reserved", "target-taken", "budget-active"]
		for name in saved_cases:
			var decoded := Codec.decode(FileAccess.get_file_as_string(output.path_join(name + "-save.json")))
			check(decoded["ok"], "Saved case did not decode: " + name)
			if not decoded["ok"]: continue
			var game := await scene(decoded["save"])
			check(game.state == decoded["save"]["payload"]["state"] and game.dorm_inventory == decoded["save"]["payload"]["dorm_inventory"], "Restore changed resources: " + name)
			check(Codec.encode(game.capture_game_save())["ok"], "Restored case did not re-encode: " + name)
			await save("restart-" + name)
			game.queue_free()
			await settle()
	else:
		await normal_meal_case()
		await resource_case()
	var result := {"errors": errors, "cases": cases, "size": str(view_size), "scope": "Native pointer input on actual menus and legal prior-day snapshots; not a physical phone or a human learning study."}
	var file := FileAccess.open(output.path_join("restart-report.json" if restore_only else "report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("CAMPUS_DEPTH_VISUAL=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func notes(game: GameRootV2, button: String) -> void:
	await click(game.menu_button)
	await workspace_click(game, game._workspace.find_child("campus_notes", true, false))
	await workspace_click(game, game._workspace.find_child(button, true, false))


func normal_meal_case() -> void:
	var game := await scene(fixture(1, 42))
	await click(game._active_stage.find_child("CafeteriaProp", true, false))
	await choose_plate(game, [game.hand[0]])
	check(game._active_stage.find_child("CampusStudy", true, false) == null, "Tray exercise entry remained")
	await save("01-normal-tray")
	var balance: int = game.state["balance"]
	var cost := game._selected_meal_total()
	await click(game._active_stage._get_confirm_button())
	check(game.today_meal_records.size() == 1 and game.state["balance"] == balance - cost, "Normal meal did not settle once")
	await save("02-normal-meal-confirmed")
	cases.append({"case": "normal_meal", "cost": cost})
	game.queue_free()
	await settle()


func resource_case() -> void:
	var game := await scene(fixture(1, 42))
	await notes(game, "plan")
	await workspace_click(game, game._workspace.find_child("target_tomorrow", true, false))
	await workspace_click(game, game._workspace.find_child("source_dorm_storage", true, false))
	await workspace_click(game, game._workspace.find_child("reserve_milk", true, false))
	await workspace_click(game, game._workspace.find_child("budget_days_2", true, false))
	await workspace_click(game, game._workspace.find_child("budget_2_40", true, false))
	check(game.state["balance"] == 150 and game._spendable_balance() == 110 and game._stock_count("milk", "dorm_storage") == 0, "Reservation did not protect cash and stock")
	await save("07-reserved-resources")
	store(game, "reserved")
	await click(game._workspace.close_button)
	finish_day(game)
	await settle()
	await save("08-day-one-resource-recap")
	await click(game.daily_summary.next_button)
	check(game.day == 2 and game.campus_week["active"].is_empty(), "Summary forced planning")
	await click(game.new_day_popup.continue_button)
	check(game._spendable_balance() == game.state["balance"] and game._stock_count("milk", "dorm_storage") == 1, "Target day did not unlock resources")
	await save("09-target-breakfast")
	await click(game._active_stage.find_child("DormProp", true, false))
	check(game.hand.has("milk"), "Reserved milk was absent from target hand")
	await choose_plate(game, ["milk"])
	var balance: int = game.state["balance"]
	await click(game._active_stage._get_confirm_button())
	check(game.state["balance"] == balance and game.dorm_inventory["milk"] == 0 and game.campus_week["resources"]["stock"][0]["status"] == "used", "Reserved milk was not used exactly once")
	store(game, "target-taken")
	await reveal(game._active_stage._cards_by_id["restock_pantry"])
	await click(game._active_stage._cards_by_id["restock_pantry"])
	check(Resources.spent(game.campus_week["resources"]["budgets"][0], game.capture_game_save()["payload"]) == 8, "Budget did not count the actual paid action")
	store(game, "budget-active")
	await notes(game, "plan")
	await reveal(game._workspace.find_child("release_budget_1", true, false))
	await save("10-budget-and-actual-spend")
	await click(game._workspace.find_child("release_budget_1", true, false))
	check(game.campus_week["resources"]["budgets"][0]["released"], "Budget release failed")
	cases.append({"case": "resource_planning", "stock": game.campus_week["resources"]["stock"], "budgets": game.campus_week["resources"]["budgets"], "state": game.state})
	game.queue_free()
	await settle()


func reveal(control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(control)
			break
		ancestor = ancestor.get_parent()
	await settle()


func choose_plate(game: GameRootV2, ids: Array) -> void:
	for id in game.selected_food_ids.duplicate():
		if not ids.has(id):
			await reveal(game._active_stage._cards_by_id[id])
			await click(game._active_stage._cards_by_id[id])
	for id in ids:
		if not game.selected_food_ids.has(id):
			await reveal(game._active_stage._cards_by_id[id])
			await click(game._active_stage._cards_by_id[id])


func reserved_fixture(seed_value: int) -> Dictionary:
	var model := Controller.new()
	model._deck_service = Deck.new(seed_value)
	model.health_history_path = ""
	model.start_new_run()
	check(Resources.reserve_stock(model.campus_week["resources"], model.dorm_inventory, "milk", 2, "breakfast", 1, model.phase), "Cannot prepare legal stock reservation")
	check(Resources.reserve_budget(model.campus_week["resources"], 40, 2, 1, model.phase, model.state["balance"]), "Cannot prepare legal budget reservation")
	var snapshot := model.capture_game_save()
	check(Codec.encode(snapshot)["ok"], "Legal reserved opening cannot save")
	model.free()
	return snapshot
