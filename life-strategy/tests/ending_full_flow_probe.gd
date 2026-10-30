extends SceneTree

## Replay the legal routes in live scenes, including new-day/opening/finale
## dialogs. No numeric state edits, forced hands or forced ending IDs.
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
var source := "E:/nutrition_life_strategy_game/.cache/ending-implementation-2026-10-29/routes"
var output := ""
var errors: Array[String] = []
var cases: Array = []
var only_case := ""


func _initialize() -> void:
	Engine.max_fps = 60
	preload("res://scripts/stories/GameSaveStore.gd").memory_for_tests = true
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--only="): only_case = arg.trim_prefix("--only=")
	if output.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("routes.json")))
	for route in routes["cases"]:
		if not only_case.is_empty() and route["name"] != only_case: continue
		Session.request(route["story"])
		var game := Scene.instantiate() as GameRootV2
		game.health_history_path = ""
		root.add_child(game)
		# _ready creates the deck; seed the new run before any menu is opened.
		game._deck_service.set_seed(42)
		current_scene = game
		await process_frame
		await process_frame
		var actual: Array = []
		var before_ending := {}
		var valid := true
		for step in route["steps"]:
			if not await _dialogs(game, actual):
				valid = false
				break
			if game.day != int(step["day"]) or game.phase != step["phase"]:
				errors.append("%s: expected %s:%s, got %s:%s" % [route["name"], step["day"], step["phase"], game.day, game.phase])
				valid = false
				break
			var args: Array = step["args"]
			var applied_step: Dictionary = step.duplicate(true)
			match String(step["command"]):
				"source":
					if game._household() and args[0] in ["breakfast_shop", "community_canteen", "local_market"]:
						game._show_outing_choices()
						await process_frame
					game._choose_meal_source(args[0])
				"meal":
					for id in args:
						if game.hand.has(id): game._on_food_toggled(id)
					if game._household() and game.selected_food_ids.size() < args.size():
						for id in ["steamed_bun", "millet_porridge", "rice_plain", "oatmeal", "egg", "tofu", "steamed_egg", "soft_tofu_greens", "tomato_egg_stir_fry", "steamed_fish", "milk", "greens", "tomato", "banana", "apple", "plain_yogurt"]:
							if not game.selected_food_ids.has(id) and game._can_add_food(id): game._on_food_toggled(id)
							if game.selected_food_ids.size() == args.size(): break
					applied_step["args"] = game.selected_food_ids.duplicate()
					for frame in range(6): await process_frame
					var confirm := game._active_stage._get_confirm_button() as Button
					if confirm == null or confirm.disabled:
						errors.append(route["name"] + ": confirm unavailable; selected=" + str(game.selected_food_ids) + " wanted=" + str(args) + " hand=" + str(game.hand))
						valid = false
						break
					confirm.pressed.emit()
				"action":
					if args[0] == "perform":
						var before_performance := Codec.encode(game.capture_game_save())
						if before_performance["ok"]: _write(route["name"] + "-performance-before.json", before_performance["text"])
					if not game._can_use_action(game._effective_action(args[0])):
						errors.append(route["name"] + ": action unavailable " + String(args[0]))
						valid = false
						break
					game._apply_action(args[0])
				"skip_meal": game._skip_meal()
				"skip_action": game._skip_action()
				"sleep":
					before_ending = game.capture_game_save()
					if not game._active_stage is SleepStageV2:
						errors.append(route["name"] + ": sleep stage missing")
						valid = false
						break
					game._active_stage._on_sleep_pressed(args[0])
				"next_day": game.daily_summary.next_button.pressed.emit()
			actual.append(applied_step)
			await process_frame
			await process_frame
			if not valid: break
		await _dialogs(game, actual)
		var expected_state: Dictionary = Codec.normalize(route["state"])
		if game.phase != "ending" or not is_instance_valid(game.ending_screen) or game.ending_screen.feedback["kind"] != route["kind"]:
			errors.append(route["name"] + ": live ending differs")
			valid = false
		var ending := Codec.encode(game.capture_game_save())
		var checkpoint := Codec.encode(before_ending)
		if not ending["ok"] or not checkpoint["ok"]:
			errors.append(route["name"] + ": live save rejected")
			valid = false
		if valid:
			_write(route["name"] + "-before.json", checkpoint["text"])
			_write(route["name"] + "-ending.json", ending["text"])
			var completed: Dictionary = route.duplicate(true)
			completed["steps"] = actual
			completed["kind"] = game.ending_screen.feedback["kind"]
			completed["state"] = game.state.duplicate(true)
			completed["outcome"] = game.household_finale.get("outcome", {}).duplicate(true)
			completed["model_state_equal"] = game.state == expected_state
			completed["live_scene"] = true
			completed["opening_choice"] = game.household_learning.get("opening_choice", "")
			completed["intro"] = game.household_finale.get("intro", "")
			cases.append(completed)
		for frame in range(5): await process_frame
		game.free()
		await process_frame
	_write("routes.json", JSON.stringify({"seed": 42, "cases": cases, "errors": errors, "scope": "Nine complete live scene routes from day 1: actual new-day/opening dialogs, source/market/menu handlers, card confirmation, action availability, sleep selection, daily summaries and finale replies. Numeric state, hands and ending IDs are not edited. Signals/normal handlers are driven by script, not a human or every-step physical pointer; separate native pointer and browser checks cover interaction."}, "\t"))
	print("ENDING_FULL_FLOW_RESULT=" + JSON.stringify({"cases": cases.size(), "errors": errors}))
	quit(0 if errors.is_empty() else 1)


func _dialogs(game: GameRootV2, steps: Array) -> bool:
	for attempt in range(90):
		if game.new_day_popup.visible:
			if game._new_day_pending:
				steps.append({"day": game.day, "phase": game.phase, "command": "new_day_continue", "args": []})
				game.new_day_popup.continue_button.pressed.emit()
		elif is_instance_valid(game._story_dialog) and game._story_dialog.visible:
			var chosen: Button
			for id in ["close", "back", "continue", "done", "cancel"]:
				var candidate := game._story_dialog._buttons.get_node_or_null(id) as Button
				if candidate != null and not candidate.disabled:
					chosen = candidate
					break
			if chosen != null:
				steps.append({"day": game.day, "phase": game.phase, "command": "dialog", "args": [String(chosen.name)]})
				chosen.pressed.emit()
		elif is_instance_valid(game._workspace) and game._workspace.visible:
			steps.append({"day": game.day, "phase": game.phase, "command": "close_optional_page", "args": []})
			game._workspace.close_button.pressed.emit()
		else: return true
		await process_frame
	errors.append("Dialog did not settle at %d:%s" % [game.day, game.phase])
	return false


func _write(name: String, text: String) -> void:
	var file := FileAccess.open(output.path_join(name), FileAccess.WRITE)
	if file != null: file.store_string(text)
	else: errors.append("Cannot write " + name)
