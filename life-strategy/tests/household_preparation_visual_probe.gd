extends "res://tests/household_study_visual_probe.gd"

const Prep := preload("res://scripts/stories/HouseholdPreparation.gd")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	if OS.get_cmdline_user_args().has("--restore-only"):
		for name in ["intro", "planner", "response", "day6-summary", "day7-response"]:
			var game := await restore(name)
			var before := material_state(game)
			await save("restart-" + name)
			if name == "intro": await click(game._story_dialog._buttons.get_node("back"))
			elif name == "planner":
				await key(KEY_ESCAPE)
				check(game._workspace is CookingPlanStage and game._workspace.storage == "fridge" and game._workspace.plan["added_sugar_g"] == 4, "Restart lost the recipe draft")
			elif name != "day6-summary": await acknowledge(game)
			check(material_state(game) == before, "Restart/return changed material facts: " + name)
			cases.append({"case": name, "day": game.day, "phase": game.phase, "plans": game.household_preparation["plans"]})
			game.queue_free()
			await process_frame
	else:
		for mode in ["used", "changed", "counter"]: await route(mode)
	var result := {"errors": errors, "cases": cases, "window": str(root.size), "scope": "Actual native mouse/key day-6 routes from valid prior-day command saves: planned cold portion used, changed arrangement, unsafe counter portion not counted. Cold route continues through day-6 summary and day-7 breakfast. Separate restore-only process checks five saved pages. Not a continuous seven-day UI/browser run or a physical phone."}
	var file := FileAccess.open(output.path_join("restart-report.json" if OS.get_cmdline_user_args().has("--restore-only") else "report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_PREPARATION_VISUAL=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func material_state(game: GameRootV2) -> Dictionary:
	return {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "batches": game.kitchen.batches.duplicate(true), "meals": game.today_meal_records.duplicate(true), "social": game.shared_meal.history.duplicate(true)}


func route(mode: String) -> void:
	var game := await fixture(6)
	var before := material_state(game)
	if mode == "used":
		await save("01-next-meal-need")
		snapshot(game, "intro")
		await click(game._story_dialog._buttons.get_node("look"))
		await save("02-live-inventory")
		await key(KEY_ESCAPE)
	else: await click(game._story_dialog._buttons.get_node("back"))
	check(material_state(game) == before, "Intro/planner spent resources")
	await source_pick(game, "home_kitchen")
	for id in ["rice_plain", "soft_apple"]: await choose_from(game, [id])
	await click(game._active_stage._get_confirm_button())
	await workspace_click(game, game._workspace.option_buttons["storage:counter" if mode == "counter" else "storage:fridge"])
	await workspace_click(game, game._workspace.option_buttons["sugar:4"])
	before = material_state(game)
	await workspace_click(game, game._workspace.learning_button)
	await study_click(game, "stock")
	check(material_state(game) == before, "Planning generated a prepared meal")
	if mode == "used":
		await save("03-recipe-and-plan")
		snapshot(game, "planner")
	elif mode == "counter": await save("10-counter-is-not-cold-preparation")
	await key(KEY_TAB)
	check(game._workspace.is_ancestor_of(root.gui_get_focus_owner()), "Planner Tab escaped the modal")
	await key(KEY_ESCAPE)
	check(game._workspace is CookingPlanStage and game._workspace.plan["added_sugar_g"] == 4, "Planner return lost raw recipe")
	check(material_state(game) == before, "Planner return spent resources")
	await workspace_click(game, game._workspace.confirm_button)
	await click(game._active_stage.skip_button)
	if mode == "used": await save("04-plan-at-next-meal")
	await source_pick(game, "home_kitchen" if mode == "changed" else "home_fridge")
	for id in (["rice_plain", "egg"] if mode == "changed" else (["milk", "apple"] if mode == "counter" else ["rice_plain", "soft_apple"])): await choose_from(game, [id])
	await click(game._active_stage._get_confirm_button())
	if mode == "changed": await workspace_click(game, game._workspace.confirm_button)
	var outcome: Dictionary = Prep.entry(game.household_preparation, "breakfast")["result"]
	check(outcome["status"] == {"used": "used", "changed": "changed", "counter": "not_prepared"}[mode], "Wrong actual plan outcome: " + mode)
	if mode == "used":
		await save("05-actual-take-and-response")
		snapshot(game, "response")
	elif mode == "changed": await save("11-changed-arrangement")
	else: await save("12-pantry-does-not-prove-preparation")
	await acknowledge(game)
	await click(game._active_stage.skip_button)
	await source_pick(game, "home_kitchen")
	for id in ["rice_plain", "soft_tofu_greens"]: await choose_from(game, [id])
	await click(game._active_stage._get_confirm_button())
	if mode == "used":
		await workspace_click(game, game._workspace.option_buttons["storage:fridge"])
		await workspace_click(game, game._workspace.learning_button)
		await study_click(game, "stock")
		await save("06-plan-for-tomorrow")
		await key(KEY_ESCAPE)
	await workspace_click(game, game._workspace.confirm_button)
	await click(game._active_stage.skip_button)
	var early: Control = game._active_stage._cards_by_id["sleep_early"]
	game._active_stage.sleep_scroll.ensure_control_visible(early)
	await settle()
	await click(early)
	check(game.phase == "summary", "Day six did not reach summary")
	var frozen: Dictionary = game.run_history.back()["preparation_recap"].duplicate(true)
	if mode == "used":
		await save("07-day-six-summary")
		snapshot(game, "day6-summary")
		await click(game.daily_summary.next_button)
		if game._new_day_pending: await click(game.new_day_popup.continue_button)
		await settle()
		if game.household_finale.get("intro") == "details": await click(game._story_dialog._buttons.get_node("back"))
		await save("08-next-day-plan-and-stock")
		await source_pick(game, "home_fridge")
		for id in ["rice_plain", "soft_tofu_greens"]: await choose_from(game, [id])
		await click(game._active_stage._get_confirm_button())
		check(Prep.entry(game.household_preparation, "dinner")["result"]["status"] == "used", "Overnight plan did not resolve from actual batches")
		check(game.run_history.back()["preparation_recap"] == frozen, "Tomorrow rewrote yesterday's pending recap")
		await save("09-next-day-actual-use")
		snapshot(game, "day7-response")
		await acknowledge(game)
	cases.append({"case": mode, "day": game.day, "phase": game.phase, "plans": game.household_preparation["plans"], "day_six_recap": frozen})
	game.queue_free()
	await process_frame


func acknowledge(game: GameRootV2) -> void:
	check(game._story_dialog.visible and game.household_preparation["pending"] != "", "Missing actual preparation response")
	var before := material_state(game)
	await click(game._story_dialog._buttons.get_node("close"))
	check(material_state(game) == before, "Closing response repeated material effects")


func workspace_click(game: GameRootV2, control: Control) -> void:
	if game._workspace.scroll.is_ancestor_of(control): game._workspace.scroll.ensure_control_visible(control)
	await settle()
	await click(control)
