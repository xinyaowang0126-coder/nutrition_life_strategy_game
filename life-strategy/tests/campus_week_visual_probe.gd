extends "res://tests/story_series_visual_probe.gd"

const Game := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Presenter := preload("res://scripts/stories/CampusPresenter.gd")
const Week := preload("res://scripts/stories/CampusWeek.gd")
var cases: Array[Dictionary] = []
var restore_only := false


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
		await whole_week(42)
		await whole_week(43)
	elif restore_only:
		for name in ["study", "plan"]:
			var decoded := Codec.decode(FileAccess.get_file_as_string(output.path_join(name + "-save.json")))
			check(decoded["ok"], "Stored exercise/plan did not decode")
			var game := await scene(decoded["save"])
			check((game._story_dialog.visible if name == "study" else is_instance_valid(game._workspace)), "Stored panel did not resume")
			await save("restart-" + name)
			if name == "study":
				await click(game._story_dialog._buttons.get_node("back"))
				check(not game.selected_food_ids.is_empty(), "Restart lost selected food")
			else:
				var balance: int = game.state["balance"]
				await click(game._workspace.close_button)
				await click(game.daily_summary.next_button)
				check(game.day == 2 and game.state["balance"] == balance, "Restart consumed a plan")
			game.queue_free()
			await settle()
	else:
		var game := await scene(fixture(1, 42))
		game._show_new_day_popup()
		await settle()
		await save("01-xiaolin-opening")
		await click(game.new_day_popup.continue_button)
		await click(game._active_stage.find_child("CafeteriaProp", true, false))
		var id: String = game.hand[0]
		await click(game._active_stage._cards_by_id[id])
		check(game.selected_food_ids.has(id), "Native input did not select a meal")
		await save("02-menu-ingredients")
		check(game._active_stage.find_child("CampusStudy", true, false) == null, "Removed tray exercise entry remained")
		await click(game.menu_button)
		await workspace_click(game, game._workspace.find_child("campus_notes", true, false))
		await workspace_click(game, game._workspace.find_child("study", true, false))
		check(game._story_dialog.visible, "Study entry did not open")
		await save("03-real-menu-study")
		store(game, "study")
		await click(game._story_dialog._buttons.get_node("explain"))
		await save("04-study-explanation")
		await click(game._story_dialog._buttons.get_node("back"))
		await click(game._active_stage._get_confirm_button())
		check(game.phase == "breakfast_action", "Study did not return to the meal")
		cases.append({"case": "study", "selected": id, "records": game.today_meal_records.size()})
		game.queue_free()
		await settle()
		game = await scene(fixture(2, 42))
		game.restore_game_save(day_one_summary())
		await settle()
		await click(game.daily_summary.planning_button)
		check(game.campus_week["active"].get("kind") == "plan", "Optional plan did not open")
		await save("05-next-breakfast-plan")
		store(game, "plan")
		var balance: int = game.state["balance"]
		await workspace_click(game, game._workspace.find_child("source_dorm_storage", true, false))
		await click(game._workspace.close_button)
		await click(game.daily_summary.next_button)
		check(game.day == 2 and game.state["balance"] == balance and game.today_meal_records.is_empty(), "Planning spent or ate a meal")
		await click(game.new_day_popup.continue_button)
		await save("06-plan-is-an-intention")
		game.queue_free()
		await settle()
		for seed_value in [42, 43]:
			game = await scene(fixture(3, seed_value))
			game._show_new_day_popup()
			await settle()
			await save("07-maintenance-variant-%d" % (seed_value & 1))
			await click(game.new_day_popup.continue_button)
			var meal := Week.limited_meal(game.campus_week)
			await reach_meal(game, meal)
			await click(game._active_stage.find_child("CafeteriaProp", true, false))
			check(game._source_selection_limit("cafeteria") == 2, "Maintenance meal limit wrong")
			await save("08-limited-menu-variant-%d" % (seed_value & 1))
			cases.append({"case": "maintenance", "variant": seed_value & 1, "meal": meal, "hand": game.hand.duplicate()})
			game.queue_free()
			await settle()
		game = await scene(fixture(5, 42))
		await reach_meal(game, "lunch")
		choose_meal(game)
		await settle()
		await save("09-peer-review-choice")
		var peer := game._active_stage._cards_by_id.get("study") as Control
		await click(peer)
		check(game.today_action_records.back().get("campus_event") == "peer_review", "Peer bonus was not executed by a real card")
		await save("10-peer-review-receipt")
		cases.append({"case": "peer_review", "trace": game.today_action_records.back()["feedback_trace"]})
		game.queue_free()
		await settle()
		game = await scene(fixture(6, 42))
		game._show_new_day_popup()
		await settle()
		await save("11-rain-tradeoffs")
		game.queue_free()
		await settle()
	var result := {"errors": errors, "cases": cases, "size": str(view_size), "scope": "Native viewport input on legal prior-day saves; not a physical-phone or human learning study."}
	var file := FileAccess.open(output.path_join("restart-report.json" if restore_only else "report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("CAMPUS_VISUAL_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func scene(snapshot: Dictionary) -> GameRootV2:
	Session.request("campus_exam")
	var game := Game.instantiate() as GameRootV2
	root.add_child(game)
	current_scene = game
	await settle()
	var checked := game.restore_game_save(snapshot)
	check(checked["ok"], "Fixture did not restore: " + str(checked))
	await settle()
	return game


func fixture(day: int, seed_value: int) -> Dictionary:
	var model := Controller.new()
	model._deck_service = Deck.new(seed_value)
	model.health_history_path = ""
	model.start_new_run()
	for previous_day in range(1, day):
		finish_day(model)
		model._on_summary_advanced()
	var snapshot := model.capture_game_save()
	check(Codec.validate(snapshot)["ok"], "Illegal prior-day commands")
	model.free()
	return snapshot


func day_one_summary() -> Dictionary:
	var model := Controller.new()
	model._deck_service = Deck.new(42)
	model.health_history_path = ""
	model.start_new_run()
	finish_day(model)
	var snapshot := model.capture_game_save()
	model.free()
	return snapshot


func finish_day(game: GameRootV2) -> void:
	for meal in ["breakfast", "lunch", "dinner"]:
		choose_meal(game)
		choose_action(game, meal)
	game._choose_sleep("sleep_early")


func choose_meal(game: GameRootV2) -> void:
	game._choose_meal_source("cafeteria")
	var plate: Array[String] = []
	for id in ["rice_plain", "oatmeal", "egg", "tofu", "greens"]:
		if game.hand.has(id) and plate.size() < game._source_selection_limit("cafeteria"): plate.append(id)
	if plate.is_empty() and not game.hand.is_empty(): plate.append(game.hand[0])
	if plate.is_empty(): game._skip_meal()
	else: game._confirm_food(plate)


func choose_action(game: GameRootV2, meal: String) -> void:
	var id: String = {"breakfast": "study", "lunch": "walk", "dinner": "nap"}[meal]
	if game._can_use_action(game._effective_action(id)): game._apply_action(id)
	else: game._skip_action()


func reach_meal(game: GameRootV2, target: String) -> void:
	while game.phase != target + "_source":
		var meal: String = game._current_meal_phase()
		choose_meal(game)
		choose_action(game, meal)
		await settle()


func store(game: GameRootV2, name: String) -> void:
	var result := Codec.encode(game.capture_game_save())
	check(result["ok"], "Probe save did not encode")
	if result["ok"]:
		var file := FileAccess.open(output.path_join(name + "-save.json"), FileAccess.WRITE)
		file.store_string(result["text"])


func whole_week(seed_value: int, initial: Dictionary = {}) -> void:
	var game := await scene(fixture(1, seed_value) if initial.is_empty() else initial)
	var days: Array = []
	for day in range(1, 8):
		check(game.day == day, "Continuous UI skipped or repeated a day")
		if game._new_day_pending:
			game.new_day_popup.continue_button.pressed.emit()
			await settle()
		for meal in ["breakfast", "lunch", "dinner"]:
			game._active_stage.source_selected.emit("cafeteria")
			await process_frame
			if not game._is_meal_phase():
				check(false, "Continuous UI could not open a meal")
				break
			var plate := affordable_plate(game)
			if plate.is_empty(): game._active_stage.skip_requested.emit()
			else:
				for id in plate: game._active_stage.food_toggled.emit(id)
				game._active_stage.confirm_requested.emit(plate)
			await process_frame
			var action: String = {"breakfast": "study", "lunch": "walk", "dinner": "nap"}[meal]
			if day == 5 and game.phase == Week.peer_phase(game.campus_week): action = "study"
			if not game._can_use_action(game._effective_action(action)): action = "nap"
			game._active_stage.action_selected.emit(action)
			await process_frame
		if game.phase != "sleep":
			check(false, "Continuous UI did not reach sleep")
			break
		game._active_stage.sleep_selected.emit("sleep_early")
		await settle()
		check(Codec.encode(game.capture_game_save())["ok"], "Continuous scene save failed")
		days.append({"day": game.day, "phase": game.phase, "balance": game.state["balance"], "progress": game.state["study_progress"]})
		if day == 3: await save("whole-week-%d-day3" % seed_value)
		if day < 7:
			if game.phase != "summary":
				check(false, "Continuous route ended early")
				break
			game.daily_summary.next_button.pressed.emit()
			await settle()
			check(game.campus_week["active"].is_empty(), "Day advance forced a planning page")
	check(game.phase == "ending" and game.run_history.size() == 7, "Continuous UI failed to finish seven days")
	await save("whole-week-%d-ending" % seed_value)
	store(game, "whole-week-%d-ending" % seed_value)
	cases.append({"case": "continuous_scene_week", "seed": seed_value, "days": days, "plans": game.campus_week["plans"].duplicate(true), "resources": game.campus_week.get("resources", {}).duplicate(true)})
	game.queue_free()
	await settle()


func affordable_plate(game: GameRootV2) -> Array[String]:
	var best: Array[String] = []
	var best_score := -100000.0
	for mask in range(1, 1 << game.hand.size()):
		var plate: Array[String] = []
		var cost := 0
		var satiety := 0
		for index in range(game.hand.size()):
			if mask & (1 << index):
				var id: String = game.hand[index]
				plate.append(id)
				cost += int(game._story_food(id)["cost"])
				satiety += int(game._story_food(id)["satiety"])
		if plate.size() > game._source_selection_limit("cafeteria") or cost > int(game.state["balance"]): continue
		var score: float = (1000.0 if satiety >= 26 else 0.0) + mini(satiety, 32) - cost * 4.0
		if score > best_score:
			best_score = score
			best = plate
	return best
