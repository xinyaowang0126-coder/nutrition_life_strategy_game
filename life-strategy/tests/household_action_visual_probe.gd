extends "res://tests/story_keyboard_visual_probe.gd"


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var game := await new_story("choir_week")
	await fixture(game, 1, "breakfast_action", 0, 60, false, "01-choir-morning")
	await fixture(game, 3, "lunch_action", 0, 60, false, "02-choir-group")
	await fixture(game, 4, "lunch_action", 0, 60, false, "03-choir-invite")
	await fixture(game, 7, "dinner_action", 62, 24, false, "04-choir-performance-locked")
	await fixture(game, 7, "dinner_action", 70, 40, false, "05-choir-performance-ready")
	await fixture(game, 1, "sleep", 0, 60, false, "06-choir-night")
	await fixture(game, 7, "sleep", 70, 40, true, "07-choir-final-night")
	game.queue_free()
	await process_frame
	game = await new_story("campus_exam")
	await fixture(game, 1, "breakfast_action", 0, 60, false, "08-campus-action")
	await fixture(game, 1, "sleep", 0, 60, false, "09-campus-night")
	game.queue_free()
	await process_frame
	if not OS.get_cmdline_user_args().has("--capture-only"):
		await verify_interactions()
	var result := {"errors": errors, "window": str(DisplayServer.window_get_size()), "scope": "Independent native window. Paired declared action/night/day-7 fixtures for both stories. Optional actual native mouse/key interactions verify drinking, rehearsing, invitation, performance and a separate first-day-to-next-day route; not a complete week or real device."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("HOUSEHOLD_ACTION_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func new_story(id: String) -> GameRootV2:
	Session.request(id)
	var game := Game.instantiate() as GameRootV2
	game.health_history_path = ""
	root.add_child(game)
	current_scene = game
	await settle()
	game.new_day_popup.hide_popup(false)
	game._new_day_pending = false
	return game


func fixture(game: GameRootV2, day: int, phase: String, progress: int, energy: int, performed: bool, name: String) -> void:
	game.day = day
	game.phase = phase
	game.state[game._goal_key()] = progress
	game.state["energy"] = energy
	game.performed = performed
	game._render_phase()
	await settle()
	await save(name)
	if game._active_stage is ActionStageV2:
		var stage := game._active_stage as ActionStageV2
		check(root.get_visible_rect().encloses(stage.get_node("Layout/PlannerNote").get_global_rect()), name + " planner outside viewport")
		check(stage.action_scroll.get_global_rect().end.y <= stage.get_node("Layout/PlannerNote").get_global_rect().position.y, name + " planner overlaps action cards")
		if stage.get("story_note") != null and stage.story_note.visible:
			check(stage.get_node("Layout/PlannerNote").get_global_rect().encloses(stage.story_note.get_global_rect()), name + " schedule note leaves planner")
	else:
		var stage := game._active_stage as SleepStageV2
		check(stage.get_node("Layout/AlarmNote").get_global_rect().encloses(stage.tomorrow_label.get_global_rect()), name + " night text outside its note")


func action_click(game: GameRootV2, id: String, info: bool = false) -> void:
	var stage := game._active_stage as ActionStageV2
	var card := stage._cards_by_id.get(id) as CompactChoiceCardV2
	check(card != null, "Missing action " + id)
	if card == null: return
	stage.action_scroll.ensure_control_visible(card)
	await settle()
	await click(card.info_button if info else card)


func verify_interactions() -> void:
	var game := await new_story("choir_week")
	game._skip_meal()
	await settle()
	var before := game.state.duplicate(true)
	await action_click(game, "rehearse", true)
	check(game.sticky_note.visible and game.sticky_note.pinned, "Rehearsal details did not open")
	await save("10-rehearsal-details")
	await key(KEY_ESCAPE)
	check(game.state == before and game.phase == "breakfast_action", "Looking at rehearsal details spent state")
	await action_click(game, "drink_water")
	check(game.drink_water_used == 1 and game.actions_used_today == 0 and game.phase == "breakfast_action", "Drinking consumed an action period")
	check(game.state["energy"] == before["energy"], "Drinking consumed period energy")
	await action_click(game, "rehearse")
	check(game.phase == "lunch_source" and game.used_action_ids == ["drink_water", "rehearse"], "Rehearsal did not settle once")
	check(int(game.state["goal_progress"]) > 0, "Rehearsal did not advance the goal")
	# Complete this first day through the actual current stages; skipping
	# later meals is a stated route, not a nutritional recommendation.
	await click(game._active_stage.find_child("skip", true, false))
	await click(game._active_stage.skip_button)
	await click(game._active_stage.find_child("skip", true, false))
	await click(game._active_stage.skip_button)
	var sleep := game._active_stage as SleepStageV2
	check(sleep != null, "Day route did not reach the night")
	if sleep != null:
		var early := sleep._cards_by_id["sleep_early"] as CompactChoiceCardV2
		sleep.sleep_scroll.ensure_control_visible(early)
		await settle()
		await click(early)
		check(game.phase == "summary" and game.run_history.size() == 1, "Night did not settle one day")
		await click(game.daily_summary.next_button)
		check(game.day == 2 and game.new_day_popup.visible, "Summary did not advance to day two")
		await save("11-next-day")
	game.queue_free()
	await process_frame
	# Separate state fixtures for the scheduled community events.
	game = await new_story("choir_week")
	await fixture(game, 3, "lunch_action", 0, 60, false, "12-group-before")
	await action_click(game, "group_rehearsal")
	check(game.phase == "dinner_source" and game.used_action_ids == ["group_rehearsal"], "Group rehearsal did not settle once")
	game.queue_free()
	await process_frame
	game = await new_story("choir_week")
	await fixture(game, 4, "lunch_action", 20, 60, false, "13-invite-before")
	before = game.state.duplicate(true)
	await action_click(game, "call_friend")
	check(is_instance_valid(game._workspace), "Invitation did not open")
	if is_instance_valid(game._workspace):
		await workspace_click(game, game._workspace.find_child("home", true, false))
		check(game.shared_meal.plan.get("status") == "planned", "Invitation did not persist")
		check(game.state == before and game.actions_used_today == 0 and game.phase == "lunch_action", "Invitation consumed an action or state")
		await save("14-invitation-planned")
	game.queue_free()
	await process_frame
	game = await new_story("choir_week")
	await fixture(game, 7, "dinner_action", 62, 24, false, "15-performance-locked")
	var blocked := game._active_stage._cards_by_id["perform"] as CompactChoiceCardV2
	check(blocked.select_button.disabled, "Unprepared performance was enabled")
	await action_click(game, "perform", true)
	await save("16-performance-details")
	await key(KEY_ESCAPE)
	check(not game.performed and game.phase == "dinner_action", "Details performed the concert")
	await fixture(game, 7, "dinner_action", 70, 40, false, "17-performance-ready")
	await action_click(game, "perform")
	check(game.performed and game.phase == "sleep" and game.used_action_ids == ["perform"], "Actual performance did not settle once")
	check(game._background_path_for_phase() == GameRootV2.HOUSEHOLD_HOME_NIGHT, "Performed evening did not return to the same home at night")
	check(not (game._active_stage as SleepStageV2).tomorrow_label.text.contains("周末就要到了"), "Final night promised a future weekend")
	await save("18-after-performance")
	game.queue_free()
	await process_frame
