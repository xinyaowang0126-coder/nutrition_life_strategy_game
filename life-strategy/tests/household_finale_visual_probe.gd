extends "res://tests/household_study_visual_probe.gd"

const Prep := preload("res://scripts/stories/HouseholdPreparation.gd")
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	if OS.get_cmdline_user_args().has("--restore-only"):
		for name in ["intro", "action-plan", "cooking-plan", "performed-reply", "ending"]:
			var game := await restore(name)
			var before := material_state(game)
			await save("restart-" + name)
			if name == "intro": await click(game._story_dialog._buttons.get_node("back"))
			elif name in ["action-plan", "cooking-plan"]:
				await key(KEY_ESCAPE)
				if name == "cooking-plan": check(game._workspace is CookingPlanStage and game._workspace.plan["added_sugar_g"] == 4 and game._workspace.storage == "fridge", "Restart lost raw recipe")
			elif name == "performed-reply": await acknowledge(game)
			else:
				game.daily_summary.content_scroll.ensure_control_visible(game.daily_summary.detail_button)
				await settle()
				await click(game.daily_summary.detail_button)
			check(material_state(game) == before, "Restart/close repeated material effects: " + name)
			cases.append({"case": name, "phase": game.phase, "performed": game.performed, "outcome": game.household_finale["outcome"]})
			game.queue_free()
			await process_frame
	else:
		for mode in ["performed", "unready", "other_choice"]: await route(mode)
	var result := {"errors": errors, "cases": cases, "window": str(root.size), "scope": "Three native mouse/key day-7 routes from valid command-generated prior days: real performance, insufficient rehearsal, ready but choosing another arrangement. Prior days include scripted disposal, practice, shared meal and cold preparation, not human learning or a continuous seven-day UI run. Five separate-process JSON restores; no browser or physical-phone claim."}
	var file := FileAccess.open(output.path_join("restart-report.json" if OS.get_cmdline_user_args().has("--restore-only") else "report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_FINALE_VISUAL=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func material_state(game: GameRootV2) -> Dictionary:
	return {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "batches": game.kitchen.batches.duplicate(true), "meals": game.today_meal_records.duplicate(true), "actions": game.today_action_records.duplicate(true), "history": game.run_history.duplicate(true), "performed": game.performed, "review": game.household_finale["review"].duplicate(true)}


func finale_fixture(rehearsals: bool) -> GameRootV2:
	var model := Controller.new()
	model.story_id = "choir_week"
	model.health_history_path = ""
	model._deck_service = Deck.new(42)
	model.start_new_run()
	check(model.kitchen.discard("before_week_greens", 1), "Scripted opening disposal failed")
	model.household_learning = {"version": 1, "opening_stage": "done", "opening_choice": "discard"}
	for previous in range(1, 7):
		for meal in ["breakfast", "lunch", "dinner"]:
			var home: bool = (previous == 3 and meal == "breakfast") or (previous in [5, 6] and meal == "dinner")
			model._choose_meal_source("home_kitchen" if home else ("breakfast_shop" if meal == "breakfast" else "community_canteen"))
			var ids: Array[String] = []
			if home: ids.assign(["rice_plain", "soft_tofu_greens"])
			if not home:
				for id in ["steamed_bun", "millet_porridge", "rice_plain", "oatmeal", "egg", "tofu", "steamed_egg", "milk", "greens", "tomato", "banana", "apple"]:
					model.selected_food_ids = ids.duplicate()
					if model.hand.has(id) and model._can_add_food(id): ids.append(id)
					if ids.size() == 2: break
			if previous in [2, 3, 4] and meal == "breakfast":
				var recipe: Dictionary = Facts.freeze(ids, model._story_food_catalog(), Facts.defaults(ids, model._story_food_catalog())) if home else {}
				var c := Study.context(previous, meal, model.current_source_id, ids, model._story_food_catalog(), "recipe_preview" if home else "selection", recipe)
				check(Study.begin(model.household_lessons, c, {}), "Scripted practice did not begin")
				if previous == 2:
					Study.answer(model.household_lessons, "enough")
					Study.retry(model.household_lessons)
				elif previous == 4:
					Study.explain(model.household_lessons)
					Study.retry(model.household_lessons)
				Study.answer(model.household_lessons, Study.question(c)["correct"])
				Study.close(model.household_lessons)
			if previous == 6 and meal == "dinner": Prep.choose(model.household_preparation, meal, "stock", model.kitchen.batches, model._story_clock())
			check(model.confirm_household_food(ids, "fridge" if previous == 6 and meal == "dinner" else "eat_now"), "Prior meal did not confirm")
			if previous == 5 and meal == "lunch": check(model.plan_shared_meal("home"), "Prior shared dinner invitation failed")
			if rehearsals and meal == "breakfast" and model.state["energy"] >= 35: model._apply_action("rehearse")
			elif rehearsals and meal == "lunch" and previous in [3, 5] and model.state["energy"] >= 30: model._apply_action("group_rehearsal")
			else: model._apply_action("nap")
		model._choose_sleep("sleep_early")
		model._on_summary_advanced()
	check(model.day == 7, "Fixture did not reach day seven")
	var encoded := Codec.encode(model.capture_game_save())
	check(encoded["ok"], "Finale fixture save invalid: " + str(encoded))
	if not encoded["ok"]:
		print("FINALE_FIXTURE_SAVE_ERROR=" + str(encoded))
		model.free()
		return null
	model.free()
	Session.request_saved(Codec.decode(encoded["text"])["save"])
	var game := Game.instantiate() as GameRootV2
	game.health_history_path = ""
	root.add_child(game)
	current_scene = game
	await settle()
	return game


func route(mode: String) -> void:
	var game := await finale_fixture(mode != "unready")
	if game == null: return
	var before := material_state(game)
	if mode == "performed":
		await save("01-day-seven-need")
		snapshot(game, "intro")
		await click(game._story_dialog._buttons.get_node("look"))
		await save("02-live-preflight")
		await key(KEY_TAB)
		check(game._workspace.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped finale plan")
		await key(KEY_ESCAPE)
	else: await click(game._story_dialog._buttons.get_node("back"))
	check(material_state(game) == before, "Opening preflight spent resources")
	await source_pick(game, "home_fridge")
	for id in ["rice_plain", "soft_tofu_greens"]: await choose_from(game, [id])
	await click(game._active_stage._get_confirm_button())
	if game.household_preparation["pending"] != "": await click(game._story_dialog._buttons.get_node("close"))
	if mode == "performed":
		await save("03-action-entry")
		await click(game._active_stage.finale_button)
		snapshot(game, "action-plan")
		await study_click(game, "nap")
	else: await action(game, "nap")
	await source_pick(game, "home_kitchen")
	for id in (["rice_plain", "soft_apple"] if mode == "performed" else ["rice_plain", "egg"]): await choose_from(game, [id])
	await click(game._active_stage._get_confirm_button())
	if mode == "performed":
		await workspace_click(game, game._workspace.option_buttons["storage:fridge"])
		await workspace_click(game, game._workspace.option_buttons["sugar:4"])
		before = material_state(game)
		await workspace_click(game, game._workspace.learning_button)
		await save("04-cooking-plan-return")
		snapshot(game, "cooking-plan")
		await key(KEY_ESCAPE)
		check(game._workspace.storage == "fridge" and game._workspace.plan["added_sugar_g"] == 4, "Plan lost raw cooking draft")
		check(material_state(game) == before, "Cooking preflight spent resources")
	await click(game._workspace.confirm_button)
	await action(game, "nap")
	await source_pick(game, "home_kitchen")
	for id in ["rice_plain", "egg"]: await choose_from(game, [id])
	await click(game._active_stage._get_confirm_button())
	await click(game._workspace.confirm_button)
	if mode != "other_choice":
		await click(game._active_stage.finale_button)
		var perform_button: Button = game._workspace.find_child("perform", true, false)
		check(perform_button.disabled == (mode == "unready"), "Wrong live performance availability")
		await save("05-ready-to-perform" if mode == "performed" else "09-not-ready")
		if mode == "performed": await workspace_click(game, perform_button)
		else:
			await key(KEY_ESCAPE)
			await click(game._active_stage.skip_button)
	else: await action(game, "nap")
	check(game.household_finale["outcome"]["kind"] == mode, "Outcome was invented or lost: " + mode)
	if mode == "performed":
		await save("06-actually-performed")
		snapshot(game, "performed-reply")
	else: await save("10-unready-reply" if mode == "unready" else "12-other-choice-reply")
	await acknowledge(game)
	var early: Control = game._active_stage._cards_by_id["sleep_early"]
	game._active_stage.sleep_scroll.ensure_control_visible(early)
	await settle()
	await click(early)
	check(game.phase == "ending", "Finale route did not end")
	var review: Dictionary = game.household_finale["review"]
	check(review["counts"]["performances"] == (1 if mode == "performed" else 0), "Review performance count incorrect")
	check(review["counts"]["shared"] == 1 and review["counts"]["plans_used"] == 1, "Week facts lost actual prior actions")
	await save({"performed": "07-ending", "unready": "11-unready-ending", "other_choice": "13-other-choice-ending"}[mode])
	if mode == "performed":
		snapshot(game, "ending")
		game.daily_summary.content_scroll.ensure_control_visible(game.daily_summary.detail_button)
		await settle()
		await click(game.daily_summary.detail_button)
		await save("08-week-facts")
	cases.append({"case": mode, "phase": game.phase, "outcome": game.household_finale["outcome"], "review": review})
	game.queue_free()
	await process_frame


func action(game: GameRootV2, id: String) -> void:
	var card: Control = game._active_stage._cards_by_id[id]
	game._active_stage.action_scroll.ensure_control_visible(card)
	await settle()
	await click(card)


func acknowledge(game: GameRootV2) -> void:
	check(game.household_finale["pending"] and game._story_dialog.visible, "Missing actual finale reply")
	var before := material_state(game)
	await click(game._story_dialog._buttons.get_node("close"))
	check(material_state(game) == before, "Closing finale reply repeated settlement")


func workspace_click(game: GameRootV2, control: Control) -> void:
	if game._workspace.scroll.is_ancestor_of(control): game._workspace.scroll.ensure_control_visible(control)
	await settle()
	await click(control)
