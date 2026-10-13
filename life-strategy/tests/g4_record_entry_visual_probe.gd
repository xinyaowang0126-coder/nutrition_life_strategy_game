extends SceneTree

const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const SIZES := [Vector2i(1920, 1080), Vector2i(720, 1280), Vector2i(780, 1280)]
var output := "res://.godot/g4-record-entry"
var errors: Array[String] = []
var images: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	for canvas in SIZES:
		for enlarged in [false, true]:
			await _canvas(canvas, enlarged)
	var game = Scene.instantiate()
	root.add_child(game)
	current_scene = game
	for physical in [Vector2i(1920, 1080), Vector2i(390, 640)]:
		root.size = physical
		game.start_new_run()
		game.new_day_popup.hide_popup(false)
		await _settle()
		await _click(game.menu_button)
		await _settle()
		_check(game._record_book_active(), "native menu failed " + str(physical))
		var before := _state(game)
		await _click(game._record_book.week_button)
		await _settle()
		_check(game._record_book._weekly, "native week tab failed")
		_check(_state(game) == before, "native read changed state")
		await _click(game._record_book.close_button)
		await _settle()
		_check(not game._record_book_active(), "native close failed")
		_settle_day(game)
		await _settle()
		game.daily_summary.content_scroll.ensure_control_visible(game.daily_summary.detail_button)
		await _settle()
		before = _state(game)
		await _click(game.daily_summary.detail_button)
		await _settle()
		_check(game.daily_summary.detail_panel.visible, "native detail did not open")
		_check(game.daily_summary.content_scroll.get_global_rect().encloses(game.daily_summary.detail_panel.get_global_rect()), "native detail did not scroll into view " + str(physical))
		_check(_state(game) == before, "native detail changed gameplay")
		_save(root, "%dx%d-native-summary-detail.png" % [physical.x, physical.y])
		game.daily_summary.content_scroll.ensure_control_visible(game.daily_summary.record_book_button)
		await _settle()
		before = _state(game)
		await _click(game.daily_summary.record_book_button)
		await _settle()
		_check(game._record_book_active(), "native summary entry failed")
		_save(root, "%dx%d-native-summary-records.png" % [physical.x, physical.y])
		await _click(game._record_book.return_button)
		await _settle()
		_check(game.daily_summary.visible and game.phase == "summary", "native close lost summary")
		_check(_state(game) == before, "native summary entry advanced")
	game.queue_free()
	await process_frame
	var report := {"valid": errors.is_empty(), "errors": errors, "images": images, "layouts": 6, "native_windows": [[1920, 1080], [390, 640]], "scope": "Real normal V2 facts with health flags off; logical canvases/native windows, not physical phone/browser acceptance."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("G4_RECORD_ENTRY_VISUAL=" + JSON.stringify({"valid": report["valid"], "errors": errors, "images": images.size()}))
	quit(0 if errors.is_empty() else 1)


func _canvas(canvas: Vector2i, enlarged: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = canvas
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = Scene.instantiate()
	viewport.add_child(game)
	game.new_day_popup.hide_popup(false)
	game._choose_meal_source("cafeteria")
	game._on_food_toggled(game.hand[0])
	var before := _state(game)
	game._show_meal_record_book()
	if enlarged:
		_enlarge(game._record_book)
	await _settle()
	var prefix := "%dx%d-%s" % [canvas.x, canvas.y, "130" if enlarged else "100"]
	_check(viewport.get_visible_rect().encloses(game._record_book.paper.get_global_rect()), prefix + " paper clipped")
	_check(game._record_book.paper.get_global_rect().encloses(game._record_book.return_button.get_global_rect()), prefix + " footer clipped")
	_check(_state(game) == before, prefix + " opening changed selection")
	_save(viewport, prefix + "-unconfirmed.png")
	game._record_book.close_book()
	game._confirm_food(game.selected_food_ids.duplicate())
	game._skip_action()
	game._skip_meal()
	game._skip_action()
	game._choose_meal_source("dorm_storage")
	if not game.hand.is_empty():
		game._confirm_food([game.hand[0]])
	else:
		game._skip_meal()
	game._skip_action()
	game._choose_sleep("sleep_early")
	before = _state(game)
	game._show_meal_record_book()
	if enlarged:
		_enlarge(game._record_book)
	await _settle()
	_check(game._record_book._book["days"][0]["eaten"] <= 2, prefix + " duplicate settled day")
	_check(_state(game) == before, prefix + " summary read changed state")
	_save(viewport, prefix + "-day.png")
	game._record_book._select_week()
	await _settle()
	_save(viewport, prefix + "-week.png")
	game._record_book.close_book()
	_check(game.daily_summary.visible, prefix + " summary did not return")
	game._on_summary_advanced()
	game.new_day_popup.hide_popup(false)
	game._show_meal_record_book()
	if enlarged:
		_enlarge(game._record_book)
	await _settle()
	_check(game._record_book._book["last_day"] == 2, prefix + " second day missing")
	_save(viewport, prefix + "-day2.png")
	viewport.queue_free()
	await process_frame


func _settle_day(game: GameRootV2) -> void:
	for phase in ["breakfast", "lunch", "dinner"]:
		game._skip_meal()
		game._skip_action()
	game._choose_sleep("sleep_early")


func _state(game: GameRootV2) -> Dictionary:
	return {"day": game.day, "phase": game.phase, "state": game.state.duplicate(true), "stock": game.dorm_inventory.duplicate(true), "hand": game.hand.duplicate(), "selection": game.selected_food_ids.duplicate(), "meals": game.today_meal_records.duplicate(true), "history": game.run_history.duplicate(true), "rng": game._deck_service._rng.state}


func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center() * (Vector2(root.size) / root.get_visible_rect().size)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _settle() -> void:
	for frame in range(12):
		await process_frame
	RenderingServer.force_draw()


func _enlarge(node: Node) -> void:
	if node is Label or node is Button:
		var control := node as Control
		if not control.has_meta("base_font"):
			control.set_meta("base_font", control.get_theme_font_size("font_size"))
		control.add_theme_font_size_override("font_size", ceili(float(control.get_meta("base_font")) * 1.3))
	for child in node.get_children():
		_enlarge(child)


func _save(viewport: Viewport, name: String) -> void:
	RenderingServer.force_draw()
	var path := output.path_join(name)
	if viewport.get_texture().get_image().save_png(path) == OK:
		images.append(path)
	else:
		errors.append("cannot save " + name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
