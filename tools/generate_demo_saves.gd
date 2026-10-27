extends SceneTree

## Generate classroom checkpoints by playing the normal rules with a fixed seed.
## Run with Godot --headless --path life-strategy --script ../tools/generate_demo_saves.gd
##   -- --output=E:/path/to/demo-saves
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")

var output := ""
var checkpoints: Array = []
var errors: Array[String] = []


func _initialize() -> void:
	preload("res://scripts/stories/GameSaveStore.gd").memory_for_tests = true
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("An explicit writable --output directory is required")
		quit(1)
		return
	_play_household()
	_play_student()
	var report := {"errors": errors, "checkpoints": checkpoints, "seed": 42,
		"scope": "Normal rule/controller actions, no edits to resources or game stats. Each file passes the production save encoder and restores into a fresh controller. Scripted choices, not human playtesting."}
	var file := FileAccess.open(output.path_join("generation-report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("DEMO_SAVE_RESULT=" + JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)


func _new_game(story_id: String) -> GameRootV2:
	var game := Controller.new()
	game.story_id = story_id
	game.health_history_path = ""
	game._deck_service = Deck.new(42)
	game.start_new_run()
	return game


func _save(game: GameRootV2, filename: String) -> void:
	var encoded := Codec.encode(game.capture_game_save())
	if not encoded["ok"]:
		errors.append(filename + ": " + str(encoded))
		return
	var restored := Controller.new()
	var result := restored.restore_game_save(encoded["save"])
	if not result["ok"] or Codec.normalize(restored.capture_game_save()["payload"]) != encoded["save"]["payload"]:
		errors.append(filename + ": fresh-controller restore differs")
	restored.free()
	var file := FileAccess.open(output.path_join(filename), FileAccess.WRITE)
	if file == null:
		errors.append(filename + ": cannot write file")
		return
	file.store_string(encoded["text"])
	checkpoints.append({"file": filename, "story": game.story_id, "day": game.day,
		"phase": game.phase, "balance": game.state["balance"],
		"goal": game.state.get("goal_progress", game.state.get("study_progress", 0)), "performed": game.performed})


func _home_plate(game: GameRootV2) -> Array[String]:
	for grain in ["rice_plain", "oatmeal", "millet_porridge"]:
		for side in ["egg", "tofu", "soft_tofu_greens", "steamed_fish", "soft_apple", "greens", "tomato"]:
			var plate: Array[String] = [grain, side]
			if game.kitchen.can_cook(plate, game._story_food_catalog(), 2): return plate
	return []


func _menu_plate(game: GameRootV2) -> Array[String]:
	var plate: Array[String] = []
	for id in ["rice_plain", "oatmeal", "millet_porridge", "egg", "tofu", "steamed_egg", "soft_tofu_greens", "tomato_egg_stir_fry", "greens", "tomato", "milk", "soft_apple", "steamed_fish", "plain_yogurt", "apple", "banana"]:
		game.selected_food_ids = plate.duplicate()
		if game.hand.has(id) and game._can_add_food(id): plate.append(id)
		if plate.size() == 2: break
	return plate


func _play_household() -> void:
	var game := _new_game("choir_week")
	_save(game, "01-周阿姨-第一天备餐.json")
	for run_day in range(1, 8):
		if run_day == 3: _save(game, "02-周阿姨-第三天钠标签练习.json")
		if run_day == 4: _save(game, "03-周阿姨-第四天糖标签与邀约.json")
		var home_plate := _home_plate(game)
		if home_plate.is_empty():
			errors.append("No legal home plate on day %d" % run_day)
			break
		for meal in ["breakfast", "lunch", "dinner"]:
			if game.phase != meal + "_source": errors.append("Unexpected household phase: " + game.phase)
			var source := "community_canteen" if meal == "dinner" else ("home_fridge" if meal == "lunch" else "home_kitchen")
			game._choose_meal_source(source)
			var plate := _menu_plate(game) if meal == "dinner" else home_plate.duplicate()
			if not game.confirm_household_food(plate, "fridge" if meal == "breakfast" else "eat_now"):
				errors.append("Household confirmation failed on day %d %s" % [run_day, meal])
			if run_day == 7 and meal == "dinner":
				_save(game, "04-周阿姨-第七天汇演前.json")
				game._apply_action("perform")
			elif meal == "breakfast" and int(game.state["goal_progress"]) < 70 and int(game.state["energy"]) >= 35: game._apply_action("rehearse")
			elif meal == "lunch" and run_day in [3, 5] and int(game.state["energy"]) >= 30: game._apply_action("group_rehearsal")
			elif meal == "dinner" and run_day < 7 and _home_plate(game).is_empty(): game._apply_action("shop_ingredients")
			else: game._apply_action("nap")
		game._choose_sleep("sleep_early")
		if run_day < 7: game._on_summary_advanced()
	if not game.performed or game.phase != "ending" or game.run_history.size() != 7:
		errors.append("Household route did not finish all seven days and perform")
	if not game.recovery_diagnostics.is_empty(): errors.append("Household recovery diagnostics are nonempty")
	_save(game, "05-周阿姨-完整一周回顾.json")
	game.free()


func _play_student() -> void:
	var game := _new_game("campus_exam")
	for meal in ["breakfast", "lunch", "dinner"]:
		game._choose_meal_source("cafeteria")
		game._confirm_food(_menu_plate(game))
		game._apply_action("study" if meal == "breakfast" else "nap")
	game._choose_sleep("sleep_early")
	game._on_summary_advanced()
	if game.day != 2 or game.phase != "breakfast_source": errors.append("Student day-2 checkpoint failed")
	if not game.recovery_diagnostics.is_empty(): errors.append("Student recovery diagnostics are nonempty")
	_save(game, "06-学生-第二天恢复与选餐.json")
	game.free()
