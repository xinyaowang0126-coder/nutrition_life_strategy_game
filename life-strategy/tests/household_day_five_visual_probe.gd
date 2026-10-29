extends "res://tests/household_study_visual_probe.gd"


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	if OS.get_cmdline_user_args().has("--restore-only"):
		for name in ["intro", "guide", "invitation-reply", "shared-dinner"]:
			var game := await restore(name)
			var before := material_state(game)
			await save("restart-" + name)
			if name == "intro": await click(game._story_dialog._buttons.get_node("back"))
			elif name == "guide":
				await key(KEY_ESCAPE)
				check(game._workspace is CookingPlanStage and game._workspace.storage == "fridge", "Restart lost cooking draft")
			else: await acknowledge(game)
			check(material_state(game) == before, "Restart/return spent resources: " + name)
			cases.append({"case": name, "phase": game.phase, "shared_history": game.shared_meal.history.size(), "meals": game.today_meal_records.size()})
			game.queue_free()
			await process_frame
	else:
		for mode in ["home", "community", "own", "missed"]: await route(mode)
	var result := {"errors": errors, "cases": cases, "window": str(root.size), "scope": "Four actual native day-5 routes from valid prior-day command saves: home/community shared dinner, cancelled invitation/own dinner, changed venue/missed invitation. Intro, recipe guide, actual meals/replies and summary use mouse/key input. Separate restore-only processes verify pending dialogue and draft recovery. Not a seven-day browser run or real phone."}
	var file := FileAccess.open(output.path_join("restart-report.json" if OS.get_cmdline_user_args().has("--restore-only") else "report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_DAY_FIVE_VISUAL=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func material_state(game: GameRootV2) -> Dictionary:
	return {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "batches": game.kitchen.batches.duplicate(true), "meals": game.today_meal_records.duplicate(true), "social": game.shared_meal.history.duplicate(true)}


func route(mode: String) -> void:
	var game := await fixture(5)
	check(game._story_dialog.visible, "Day-five need did not appear")
	var before := material_state(game)
	if mode == "home":
		await save("01-personal-need")
		snapshot(game, "intro")
		await click(game._story_dialog._buttons.get_node("look"))
		await save("02-source-guide")
		await workspace_click(game, game._workspace.find_child("home_kitchen", true, false))
	else:
		await click(game._story_dialog._buttons.get_node("back"))
		await source_pick(game, "home_kitchen")
	check(material_state(game) == before, "Introduction/navigation changed food or money")
	var breakfast: Array = ["rice_plain", "soft_apple"] if mode == "home" else ["rice_plain", "egg"]
	for id in breakfast: await choose_from(game, [id])
	await click(game._active_stage._get_confirm_button())
	if mode == "home":
		await workspace_click(game, game._workspace.option_buttons["storage:fridge"])
		await workspace_click(game, game._workspace.option_buttons["sugar:4"])
		var draft_before := material_state(game)
		await workspace_click(game, game._workspace.learning_button)
		await save("03-real-preparation-guide")
		snapshot(game, "guide")
		await key(KEY_TAB)
		check(game._workspace.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped the preparation guide")
		await key(KEY_ESCAPE)
		check(game._workspace is CookingPlanStage and game._workspace.storage == "fridge" and game._workspace.plan["added_sugar_g"] == 4, "Guide lost recipe or storage")
		check(material_state(game) == draft_before, "Guide consumed food")
	await click(game._workspace.confirm_button)
	if mode == "home": await save("04-actual-meal-response")
	await acknowledge(game)
	await click(game._active_stage.skip_button)
	await source_pick(game, "home_fridge" if mode == "home" else "home_kitchen")
	for id in breakfast: await choose_from(game, [id])
	await click(game._active_stage._get_confirm_button())
	if mode != "home": await click(game._workspace.confirm_button)
	await acknowledge(game)
	check(game.phase == "lunch_action", "Route did not reach the invitation window")
	var invitation_before := material_state(game)
	await action(game, "call_friend")
	if mode == "own":
		await key(KEY_ESCAPE)
		check(game.household_day_five["invite_declined"], "Invitation cancellation was not retained")
		check(material_state(game) == invitation_before, "Cancelling an invitation changed resources")
		await save("08-own-arrangement")
	else:
		await workspace_click(game, game._workspace.find_child("home" if mode == "home" else "community", true, false))
		check(game.shared_meal.history.size() == 1 and game.shared_meal.plan["status"] == "planned", "Invitation became a shared meal too early")
		if mode == "home":
			await save("05-friend-accepted")
			snapshot(game, "invitation-reply")
		await acknowledge(game)
	await action(game, "group_rehearsal")
	var source := "community_canteen" if mode == "community" else "home_kitchen"
	if source == "community_canteen": await outside_source(game, source)
	else: await source_pick(game, source)
	var dinner_foods: Array = ["rice_plain", "soft_tofu_greens"] if mode == "home" else []
	if dinner_foods.is_empty():
		for group in [["rice_plain", "millet_porridge", "egg", "steamed_egg"], ["soft_tofu_greens", "tofu", "greens", "steamed_fish", "soft_apple"]]:
			await choose_from(game, group)
	else:
		for id in dinner_foods: await choose_from(game, [id])
	var ingredients := game.kitchen.ingredients.duplicate(true)
	var money: int = game.state["balance"]
	await click(game._active_stage._get_confirm_button())
	if source == "home_kitchen": await click(game._workspace.confirm_button)
	var meal: Dictionary = game.today_meal_records.back()
	check(meal["day_five_experience"]["shared"] == (mode in ["home", "community"]), "Response invented or lost the companion")
	if mode == "home":
		check(game.kitchen.ingredients["rice_plain"] == ingredients["rice_plain"] - 2 and game.kitchen.ingredients["tofu"] == ingredients["tofu"] - 2, "Home dinner charged wrong portions")
		await save("06-real-shared-dinner")
		snapshot(game, "shared-dinner")
	elif mode == "community": check(game.kitchen.ingredients == ingredients and game.state["balance"] == money - meal["total_cost"], "Community dinner consumed home food or charged twice")
	elif mode == "missed": check(not game._story_dialog._body.text.contains("老陈"), "Changed venue gained a fictional tablemate")
	await acknowledge(game)
	await click(game._active_stage.skip_button)
	var early: Control = game._active_stage._cards_by_id["sleep_early"]
	game._active_stage.sleep_scroll.ensure_control_visible(early)
	await settle()
	await click(early)
	check(game.phase == "summary", "Day-five route did not finish")
	var recap: Dictionary = game.run_history.back()["day_five_recap"]
	check(recap["shared"] == (mode in ["home", "community"]), "Summary companion does not match the meal")
	check(recap["missed"] == (mode == "missed"), "Summary lost a missed invitation")
	await save({"home": "07-shared-summary", "community": "09-community-summary", "own": "10-own-summary", "missed": "11-missed-summary"}[mode])
	cases.append({"case": mode, "phase": game.phase, "recap": recap, "social_events": game.shared_meal.history.size()})
	game.queue_free()
	await process_frame


func acknowledge(game: GameRootV2) -> void:
	check(game._story_dialog.visible and game.household_day_five["pending"] != "", "No pending response to acknowledge")
	await click(game._story_dialog._buttons.get_node("close"))


func action(game: GameRootV2, id: String) -> void:
	var card: Control = game._active_stage._cards_by_id[id]
	game._active_stage.action_scroll.ensure_control_visible(card)
	await settle()
	await click(card)


func outside_source(game: GameRootV2, id: String) -> void:
	await click(game._active_stage._props["go_out"].get_node("Nameplate"))
	check(game._active_stage is HouseholdMarketStage, "Outing did not reach the market")
	await click(game._active_stage._choices[id].get_node("Plaque"))
	check(game._is_meal_phase(), "Market did not open the requested menu")
