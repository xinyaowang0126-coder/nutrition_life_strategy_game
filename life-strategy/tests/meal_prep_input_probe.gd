extends "res://tests/story_keyboard_visual_probe.gd"

var cases: Array[Dictionary] = []


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(640, 960), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		await settle()
		Session.request("choir_week")
		var game := Game.instantiate() as GameRootV2
		game.health_history_path = ""
		root.add_child(game)
		current_scene = game
		await settle()
		game.new_day_popup.hide_popup(false)
		game._new_day_pending = false
		game._choose_meal_source("home_kitchen")
		var ids: Array[String] = ["rice_plain", "soft_tofu_greens"]
		game._confirm_food(ids)
		await settle()
		var prefix := "%dx%d" % [resolution.x, resolution.y]
		var page := game._workspace as CookingPlanStage
		var pantry := game.kitchen.ingredients.duplicate(true)
		var condiments := game.kitchen.condiments.duplicate(true)
		await save(prefix + "-01-current-meal")
		await workspace_click(game, page.option_buttons["storage:fridge"])
		check(page._effort_note.text.contains("6＋1＝7") and page._effort_note.text.contains("现做12，省5"), prefix + ": missing real preparation comparison")
		check(page.scroll.get_global_rect().grow(1).encloses(page._effort_note.get_global_rect()), prefix + ": preparation benefit not fully visible after selecting storage")
		check(page.scroll.get_global_rect().grow(1).encloses(page._storage_note.get_global_rect()), prefix + ": storage guidance not fully visible after selecting storage")
		check(game.kitchen.ingredients == pantry and game.kitchen.condiments == condiments and game.today_meal_records.is_empty(), prefix + ": preview spent resources")
		await save(prefix + "-02-extra-portion")
		await workspace_click(game, page.option_buttons["storage:counter"])
		check(not page._effort_note.text.contains("省") and page._effort_note.text.contains("不能用于下一餐"), prefix + ": unsafe storage advertises a saving")
		await save(prefix + "-03-counter-warning")
		await workspace_click(game, page.option_buttons["storage:fridge"])
		await click(page.confirm_button)
		check(game.phase == "breakfast_action", prefix + ": bulk cooking did not advance once")
		check(game.state["energy"] == 57, prefix + ": bulk cooking charged a second preparation or credited an immediate bonus")
		for id in ["rice_plain", "tofu", "greens"]: check(game.kitchen.ingredients[id] == pantry[id] - 2, prefix + ": bulk ingredients not charged for two portions")
		var cooked_pantry := game.kitchen.ingredients.duplicate(true)
		var cooked_condiments := game.kitchen.condiments.duplicate(true)
		game._skip_action()
		game._choose_meal_source("home_fridge")
		var stage := game._active_stage as HouseholdMealStage
		for id in ids:
			var card := stage._cards_by_id[id] as HouseholdFoodCard
			stage.food_scroll.ensure_control_visible(card)
			await settle()
			await click(card)
		await save(prefix + "-04-next-meal-cards")
		await click(stage._get_confirm_button())
		check(game.phase == "lunch_action" and game.state["energy"] == 51, prefix + ": reheat effort differs from the displayed comparison")
		check(game.kitchen.ingredients == cooked_pantry and game.kitchen.condiments == cooked_condiments, prefix + ": reheating charged raw materials again")
		check(game.today_meal_records.size() == 2 and game.kitchen.available("soft_tofu_greens", 1) == 0, prefix + ": a saved portion was duplicated")
		await save(prefix + "-05-after-reheat")
		# Declared last-dinner fixture checks that the UI does not invent a
		# future benefit. The two meals above were confirmed through native UI.
		game.day = 7
		game.phase = "dinner_source"
		game._render_phase()
		game._choose_meal_source("home_kitchen")
		game._confirm_food(ids)
		await settle()
		page = game._workspace as CookingPlanStage
		await workspace_click(game, page.option_buttons["storage:fridge"])
		check(page._effort_note.text.contains("最后一餐") and not page._effort_note.text.contains("省"), prefix + ": last dinner promises a future saving")
		await save(prefix + "-06-last-dinner")
		cases.append({"window": str(resolution), "first_two_meal_energy": 51, "raw_materials_charged_once": game.kitchen.ingredients == cooked_pantry, "last_dinner_is_fixture": true})
		game.queue_free()
		await process_frame
	var result := {"errors": errors, "cases": cases, "scope": "Two native window sizes. Declared first-breakfast plate; storage and confirmation use actual mouse events, next-meal stored cards are selected and reheated through native UI. Day-7 dinner is an explicit fixture. In-memory saves only; not a full seven-day UI playthrough."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("MEAL_PREP_INPUT_RESULT=" + JSON.stringify({"errors": errors, "cases": cases.size()}))
	quit(0 if errors.is_empty() else 1)
