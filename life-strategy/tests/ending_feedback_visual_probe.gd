extends SceneTree

const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
var routes_dir := "E:/nutrition_life_strategy_game/.cache/ending-implementation-2026-10-29/routes"
var output := ""
var errors: Array[String] = []
var rows: Array = []
var restore_only := false
var only_case := ""


func _initialize() -> void:
	preload("res://scripts/stories/GameSaveStore.gd").memory_for_tests = true
	call_deferred("_run")


func _run() -> void:
	var width := 1280
	var height := 720
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--routes="): routes_dir = arg.trim_prefix("--routes=")
		elif arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="): height = int(arg.trim_prefix("--height="))
		elif arg.begins_with("--only="): only_case = arg.trim_prefix("--only=")
	if output.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(width, height)
	restore_only = OS.get_cmdline_user_args().has("--restore-only")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(routes_dir.path_join("routes.json")))
	for route in report["cases"]:
		if not only_case.is_empty() and route["name"] != only_case: continue
		var save := Codec.decode(FileAccess.get_file_as_string(routes_dir.path_join(route["name"] + ("-ending.json" if restore_only else "-before.json"))))
		if not save["ok"]: errors.append(route["name"] + ": decode failed"); continue
		Session.request_saved(save["save"])
		var game := Scene.instantiate() as GameRootV2
		game.health_history_path = ""
		root.add_child(game)
		current_scene = game
		await settle()
		if not restore_only:
			check(game.phase == "sleep" and game._active_stage is SleepStageV2, route["name"] + ": sleep checkpoint missing")
			if not game._active_stage is SleepStageV2: game.free(); continue
			var sleep_id := String(route["steps"].back()["args"][0])
			var sleep_stage := game._active_stage as SleepStageV2
			var card: Control = sleep_stage._cards_by_id[sleep_id]
			sleep_stage.sleep_scroll.ensure_control_visible(card)
			await settle()
			await click(card)
		check(game.phase == "ending" and game.state == Codec.normalize(route["state"]), route["name"] + ": UI settlement differs from legal route")
		var screen := game.ending_screen as EndingScreenV2
		check(screen != null and screen.visible and not game.daily_summary.visible, route["name"] + ": independent ending missing")
		if screen == null: game.free(); continue
		check(screen.feedback["kind"] == route["kind"], route["name"] + ": wrong branch")
		var before: Dictionary = game.capture_game_save()["payload"]
		var encoded := Codec.encode(game.capture_game_save())
		check(encoded["ok"], route["name"] + ": native ending save invalid")
		if encoded["ok"]:
			var ending_file := FileAccess.open(output.path_join(route["name"] + "-ending.json"), FileAccess.WRITE)
			ending_file.store_string(encoded["text"])
		await capture(route["name"] + "-main")
		var title_bounds := screen.title_label.get_global_rect()
		var retry_bounds := screen.restart_button.get_global_rect()
		check(root.get_visible_rect().encloses(title_bounds), route["name"] + ": title clipped")
		check(root.get_visible_rect().encloses(retry_bounds), route["name"] + ": restart outside viewport")
		await click(screen.review_button)
		check(screen.review_open, route["name"] + ": pointer did not open review")
		check(_scroll_count(screen) == 1, route["name"] + ": nested scrolls")
		await capture(route["name"] + "-review")
		var meals := screen.button_for("Meals")
		await click(meals)
		check(is_instance_valid(game._record_book) and game._record_book.visible, route["name"] + ": record entry failed")
		if not is_instance_valid(game._record_book): game.free(); continue
		game._on_ending_restart_requested()
		check(game.phase == "ending", route["name"] + ": late restart escaped modal")
		await click(game._record_book.return_button)
		check(not game._record_book.visible and screen.review_open, route["name"] + ": record return lost review")
		await key(KEY_ESCAPE)
		check(not screen.review_open, route["name"] + ": Escape did not return to ending")
		check(game.capture_game_save()["payload"] == before, route["name"] + ": reading changed the run")
		var feedback_before: Dictionary = screen.feedback.duplicate(true)
		if not screen.feedback["moments"].is_empty():
			var moment_button := screen.button_for("Moment_" + String(screen.feedback["moments"][0]["id"]))
			screen.main_scroll.ensure_control_visible(moment_button)
			await settle()
			await click(moment_button)
			check(screen.review_open, route["name"] + ": moment link failed")
			await key(KEY_ESCAPE)
		game._show_ending_summary()
		check(screen.feedback == feedback_before, route["name"] + ": repeated feedback changed")
		await click(screen.restart_button)
		check(game.day == 1 and game.phase == "breakfast_source" and not screen.visible, route["name"] + ": restart failed")
		rows.append({"name": route["name"], "kind": route["kind"], "window": [width, height], "title": str(title_bounds), "restart": str(retry_bounds), "input": "native pointer and keyboard events", "moments": feedback_before["moments"].size()})
		game.free()
		await process_frame
	var routes_file := FileAccess.open(output.path_join("routes.json"), FileAccess.WRITE)
	routes_file.store_string(JSON.stringify(report, "\t"))
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"errors": errors, "cases": rows, "restore_only": restore_only, "scope": "Validated normal-command checkpoints; native pointer chooses the final sleep card and confirms the same outcome/state. Review, meal records, read-only checks and restart use real pointer/key dispatch. Restore-only runs consume endings saved by a separate native process. Not browser, physical-phone or continuous seven-day human play."}, "\t"))
	print("ENDING_VISUAL_RESULT=" + JSON.stringify({"cases": rows.size(), "window": [width, height], "errors": errors}))
	quit(0 if errors.is_empty() else 1)


func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		print("CHECK_FAILED=" + message)


func settle() -> void:
	for frame in range(5): await process_frame
	await create_timer(0.15).timeout


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Screenshot failed: " + name)


func click(control: Control) -> void:
	if control == null or not control.is_visible_in_tree(): errors.append("Missing pointer target"); return
	var bounds := control.get_global_rect()
	check(root.get_visible_rect().encloses(bounds), "Pointer target outside viewport: " + String(control.name))
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = bounds.get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()


func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()


func _scroll_count(node: Node) -> int:
	var count := 1 if node is ScrollContainer else 0
	for child in node.get_children(): count += _scroll_count(child)
	return count
