extends SceneTree

## Legal controller commands from default new runs. No state/hand/ending edits.
## --output=<absolute directory> writes reproducible routes and valid checkpoints.
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Data := preload("res://scripts/GameData.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Feedback := preload("res://scripts/systems/EndingFeedbackBuilder.gd")
const CASES := [
	{"name": "student-steady", "story": "campus_exam", "policy": "paced", "kind": "steady"},
	{"name": "student-barely", "story": "campus_exam", "policy": "five_study", "kind": "goal_gap"},
	{"name": "student-barely-reserve", "story": "campus_exam", "policy": "last_push", "kind": "reserve_gap"},
	{"name": "student-shortfall", "story": "campus_exam", "policy": "no_study", "kind": "study_gap"},
	{"name": "student-rest", "story": "campus_exam", "policy": "skip", "kind": "campus_rest"},
	{"name": "zhou-performed", "story": "choir_week", "policy": "perform", "kind": "performed"},
	{"name": "zhou-unready", "story": "choir_week", "policy": "no_study", "kind": "unready"},
	{"name": "zhou-other-choice", "story": "choir_week", "policy": "own", "kind": "other_choice"},
	{"name": "zhou-rest", "story": "choir_week", "policy": "skip", "kind": "zhou_rest"},
]
var output := ""
var errors: Array[String] = []
var steps: Array = []


func _initialize() -> void:
	preload("res://scripts/stories/GameSaveStore.gd").memory_for_tests = true
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("An explicit writable output directory is required")
		quit(1)
		return
	var rows: Array = []
	for route in CASES: rows.append(_play(route))
	var report := {"seed": 42, "cases": rows, "errors": errors,
		"scope": "Eight main endings plus the reserve-gap variant, from nine new runs using actual menus, costs, stock, action availability, periods and recovery. Scripted controller commands, not a human playtest or full seven-day browser UI run. Dialogue/lesson presentation is not driven by this model probe; checkpoint restoration and UI controls are verified separately."}
	_write("routes.json", report)
	print("ENDING_ROUTES_RESULT=" + JSON.stringify({"cases": rows.size(), "errors": errors}))
	quit(0 if errors.is_empty() else 1)


func _play(route: Dictionary) -> Dictionary:
	steps.clear()
	var game := Controller.new()
	game.story_id = route["story"]
	game.health_history_path = ""
	game._deck_service = Deck.new(42)
	game.start_new_run()
	var checkpoint := {}
	var count := 0
	while game.phase != "ending" and count < 160:
		count += 1
		var previous := "%d:%s" % [game.day, game.phase]
		if game.phase.ends_with("_source"):
			if route["policy"] == "skip":
				_step(game, "skip_meal", [])
				game._skip_meal()
			else: _meal(game)
		elif game.phase.ends_with("_action"):
			_action(game, route["policy"])
		elif game.phase == "sleep":
			checkpoint = game.capture_game_save()
			var sleep := "night_study" if route["policy"] == "skip" or (route["policy"] == "last_push" and game.day == 7) else "sleep_early"
			_step(game, "sleep", [sleep])
			game._choose_sleep(sleep)
		elif game.phase == "summary":
			_step(game, "next_day", [])
			game._on_summary_advanced()
		else: break
		if previous == "%d:%s" % [game.day, game.phase]:
			errors.append(route["name"] + ": no progress at " + previous)
			break
	var feedback := Feedback.build(game.story, game.ending_id, game.capture_game_save()["payload"])
	if game.phase != "ending" or feedback["kind"] != route["kind"]:
		errors.append("%s: expected %s, got %s at %s" % [route["name"], route["kind"], feedback["kind"], game.phase])
	var before := Codec.encode(checkpoint)
	var ended := Codec.encode(game.capture_game_save())
	if not before["ok"]: errors.append(route["name"] + ": checkpoint " + str(before))
	if not ended["ok"]: errors.append(route["name"] + ": ending " + str(ended))
	if before["ok"]: _write_text(route["name"] + "-before.json", before["text"])
	if ended["ok"]:
		_write_text(route["name"] + "-ending.json", ended["text"])
		var restored := Controller.new()
		if not restored.restore_game_save(ended["save"])["ok"] or Feedback.build(restored.story, restored.ending_id, restored.capture_game_save()["payload"]) != feedback:
			errors.append(route["name"] + ": restored feedback differs")
		restored.free()
	var result := {"name": route["name"], "story": route["story"], "expected_kind": route["kind"], "kind": feedback["kind"], "title": feedback["title"], "ending_id": game.ending_id, "day": game.day, "state": game.state.duplicate(true), "outcome": game.household_finale.get("outcome", {}).duplicate(true), "steps": steps.duplicate(true), "checkpoint_valid": before["ok"], "ending_valid": ended["ok"]}
	game.free()
	return result


func _step(game: GameRootV2, command: String, args: Array) -> void:
	steps.append({"day": game.day, "phase": game.phase, "command": command, "args": args.duplicate(true)})


func _meal(game: GameRootV2) -> void:
	var household := game._household()
	var source := ("breakfast_shop" if game.phase == "breakfast_source" else "community_canteen") if household else "cafeteria"
	_step(game, "source", [source])
	game._choose_meal_source(source)
	var plate: Array[String] = []
	if household:
		for id in ["steamed_bun", "millet_porridge", "rice_plain", "oatmeal", "egg", "tofu", "steamed_egg", "soft_tofu_greens", "tomato_egg_stir_fry", "steamed_fish", "milk", "greens", "tomato", "banana", "apple", "plain_yogurt"]:
			game.selected_food_ids = plate.duplicate()
			if game.hand.has(id) and game._can_add_food(id): plate.append(id)
			if plate.size() == 2: break
	else:
		plate = _campus_plate(game)
	_step(game, "meal", plate)
	if household:
		if not game.confirm_household_food(plate): errors.append("Household meal rejected")
	else: game._confirm_food(plate)


func _campus_plate(game: GameRootV2) -> Array[String]:
	var best: Array[String] = []
	var best_score := -INF
	for mask in range(1, 1 << game.hand.size()):
		var plate: Array[String] = []
		var cost := 0
		var satiety := 0
		var energy := 0
		for index in range(game.hand.size()):
			if mask & (1 << index):
				var food := Data.get_food(game.hand[index])
				plate.append(game.hand[index])
				cost += int(food.get("cost", 0))
				satiety += int(food.get("satiety", 0))
				energy += int(food.get("energy", 0))
		if plate.size() > game._source_selection_limit("cafeteria") or cost > int(game.state["balance"]): continue
		var score := (100.0 if satiety >= 26 else 0.0) + mini(satiety, 32) + mini(energy, 4) - cost * 4.0
		if score > best_score:
			best_score = score
			best = plate
	return best


func _action(game: GameRootV2, policy: String) -> void:
	var action := ""
	if game._household():
		if policy == "skip": action = "rehearse"
		elif policy == "no_study": action = "nap"
		elif game.day == 7 and game.phase == "dinner_action": action = "perform" if policy == "perform" else "nap"
		elif game.phase == "breakfast_action" and int(game.state["energy"]) >= 35: action = "rehearse"
		elif game.phase == "lunch_action" and game.day in [3, 5] and int(game.state["energy"]) >= 30: action = "group_rehearsal"
		else: action = "nap"
	elif policy != "skip":
		var omit_study := policy == "no_study" or (policy == "five_study" and game.day > 5)
		action = "study" if policy == "last_push" and game.day == 7 else {"breakfast_action": "nap" if omit_study else "study", "lunch_action": "walk", "dinner_action": "nap"}[game.phase]
		if policy == "last_push" and game.day == 6 and game.phase == "dinner_action": action = "study"
	if not action.is_empty() and game._can_use_action(game._effective_action(action)):
		_step(game, "action", [action])
		game._apply_action(action)
	else:
		_step(game, "skip_action", [])
		game._skip_action()


func _write(name: String, value: Dictionary) -> void:
	_write_text(name, JSON.stringify(value, "\t"))


func _write_text(name: String, value: String) -> void:
	var file := FileAccess.open(output.path_join(name), FileAccess.WRITE)
	if file == null:
		errors.append("Cannot write " + name)
		return
	file.store_string(value)
