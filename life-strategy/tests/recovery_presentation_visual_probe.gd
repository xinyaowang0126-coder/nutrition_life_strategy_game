extends SceneTree

## Rendered layouts and actual GUI input; controlled records are labelled here.
## Normal Godot process required. No browser or physical-phone claims.
const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Data := preload("res://scripts/GameData.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Presenter := preload("res://scripts/systems/RecoveryPresenter.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const InputProbe := preload("res://tests/detail_input_probe.gd")
const CONDITIONS := ["rested", "steady", "strained", "depleted"]
const SIZES := [Vector2i(720, 1280), Vector2i(780, 1280), Vector2i(1920, 1080)]
var errors: Array[String] = []
var images: Array[String] = []
var output_dir := "res://.godot/recovery-presentation"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var cases: Array[Dictionary] = []
	for canvas in SIZES:
		for enlarged in [false, true]:
			cases.append(await _capture_layout(canvas, enlarged))
	var input_reports: Array[Dictionary] = []
	var native_game := GameScene.instantiate() as GameRootV2
	native_game.health_history_path = ""
	root.add_child(native_game)
	current_scene = native_game
	for window_size in [Vector2i(1920, 1080), Vector2i(390, 640)]:
		var input_probe := InputProbe.new()
		var result := await input_probe.run(native_game, window_size, "cafeteria")
		input_reports.append(result)
		_expect(result["valid"], "food input regression at " + str(window_size) + ": " + str(result["errors"]))
		native_game.new_day_popup.hide_popup(false)
		native_game._show_new_day_popup()
		await _settle()
		# Drive the new recovery entry, close, Escape, and repeat using GUI input.
		var before := _snapshot(native_game)
		for repeat in range(2):
			native_game.new_day_popup.body_scroll.ensure_control_visible(native_game.new_day_popup.recovery_details_button)
			await _settle()
			await input_probe._click(input_probe._screen_center(native_game.new_day_popup.recovery_details_button))
			await _settle()
			_expect(native_game.sticky_note.visible and native_game.sticky_note.pinned, "recovery entry did not open at " + str(window_size))
			_expect(native_game.new_day_popup.continue_button.disabled, "underlying new-day action remained enabled")
			if repeat == 0:
				RenderingServer.force_draw()
				_save(root, "%dx%d-native-recovery.png" % [window_size.x, window_size.y])
				await input_probe._click(input_probe._screen_center(native_game.sticky_note.close_button))
			else:
				await input_probe._key(KEY_ESCAPE)
			# Twelve fast frames can be shorter than the 100 ms close animation.
			await create_timer(0.16).timeout
			await _settle()
			_expect(not native_game.sticky_note.visible, "recovery close mode %d failed at %s: pinned=%s payload=%s input=%s" % [repeat, window_size, native_game.sticky_note.pinned, native_game.sticky_note.get_payload().get("id"), native_game.sticky_note.is_processing_input()])
			_expect(before == _snapshot(native_game), "recovery details changed game state")
			_expect(not native_game.new_day_popup.continue_button.disabled, "new-day action was not restored")
		# Use the native physical canvas, including Godot's stretch transform.
		RenderingServer.force_draw()
		_save(root, "%dx%d-native-new-day.png" % [window_size.x, window_size.y])
		input_reports[-1]["recovery_gui_checks"] = ["entry_click", "close_click", "escape", "reopen_readonly", "continue_restored"]
	native_game.queue_free()
	await process_frame
	var report := {"valid": errors.is_empty(), "errors": errors, "cases": cases, "input": input_reports, "images": images, "scope": "Controlled frozen recovery layouts, 130% label fonts, native physical-window input at desktop and 390x640. Not a browser or physical phone."}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("RECOVERY_PRESENTATION_VISUAL_RESULT=" + JSON.stringify({"valid": report["valid"], "errors": errors, "cases": cases.size(), "images": images.size(), "input": input_reports.size()}))
	quit(0 if errors.is_empty() else 1)


func _capture_layout(canvas: Vector2i, enlarged: bool) -> Dictionary:
	var before_errors := errors.size()
	var viewport := SubViewport.new()
	viewport.size = canvas
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game := GameScene.instantiate() as GameRootV2
	game.health_history_path = ""
	viewport.add_child(game)
	var callback := Callable(game, "_apply_responsive_profile")
	if viewport.size_changed.is_connected(callback):
		viewport.size_changed.disconnect(callback)
	game._mobile_mode = canvas.y > canvas.x
	game._apply_shell_profile()
	if enlarged:
		_enlarge_fonts(game)
	var prefix := "%dx%d-%s" % [canvas.x, canvas.y, "130" if enlarged else "100"]
	await _settle()
	if enlarged:
		_enlarge_fonts(game)
		await _settle()
	_expect(game.new_day_popup.status_title.text == "起步状态", prefix + " new run is not explicit")
	_check_modal(game.new_day_popup.paper_host, game.new_day_popup.continue_button, viewport, prefix)
	_save(viewport, prefix + "-new-run.png")
	for condition in CONDITIONS:
		var record := _record(condition)
		game.day = 2
		game._started_day = 1
		game.run_history = [{"day": 1, "recovery_state": record}]
		_expect(game._start_day(), prefix + " preparation failed")
		game._render_phase()
		game._show_new_day_popup()
		await _settle()
		if enlarged:
			_enlarge_fonts(game)
			await _settle()
		_check_modal(game.new_day_popup.paper_host, game.new_day_popup.continue_button, viewport, prefix)
		_expect(game.new_day_popup.status_title.text == Presenter.present(record)["title"], prefix + " wrong title")
		_save(viewport, prefix + "-" + condition + "-new-day.png")
		game.new_day_popup.hide_popup(false)
		await _settle()
		_expect(viewport.get_visible_rect().encloses(game.character_hud.recovery_value.get_global_rect()), prefix + " recovery HUD outside canvas")
		game.character_hud.request_details(true)
		await _settle()
		_check_modal(game.sticky_note, game.sticky_note.close_button, viewport, prefix + " " + condition)
		_expect(game.sticky_note.recovery_section.visible, prefix + " no recovery basis")
		if condition == "depleted":
			_save(viewport, prefix + "-hud-detail.png")
		game.sticky_note.hide_note(false)
	var historical := Recovery.unavailable("legacy_unknown", "LEGACY_RECOVERY_NOT_RECORDED")
	game._show_detail({"id": "old_record", "name": "历史恢复依据", "recovery": Presenter.present(historical)}, Rect2(10, 10, 48, 48), true, "state")
	await _settle()
	_check_modal(game.sticky_note, game.sticky_note.close_button, viewport, prefix + " unknown")
	_expect(game.sticky_note.recovery_text.text.contains("旧记录没有保存"), prefix + " unknown replaced with normal")
	_save(viewport, prefix + "-unknown-history.png")
	game.sticky_note.hide_note(false)
	game.start_new_run()
	game.new_day_popup.hide_popup(false)
	game.state.merge({"energy": 70, "stress": 40, "satiety": 50, "study_progress": 20}, true)
	for meal in ["breakfast", "lunch", "dinner"]:
		var foods: Array[Dictionary] = [Data.get_food("rice_plain"), Data.get_food("egg"), Data.get_food("tomato")]
		game.today_meal_records.append(Resolver.build_record(meal, Data.get_meal_source("cafeteria"), foods))
	game.phase = "sleep"
	game._choose_sleep("sleep_early")
	await _settle()
	if enlarged:
		_enlarge_fonts(game)
		await _settle()
	_check_modal(game.daily_summary.paper_host, game.daily_summary.next_button, viewport, prefix + " daily")
	_save(viewport, prefix + "-day-summary.png")
	game.daily_summary.detail_button.pressed.emit()
	await _settle()
	_check_modal(game.daily_summary.paper_host, game.daily_summary.next_button, viewport, prefix + " expanded")
	_expect(game.daily_summary.detail_label.text.contains("恢复依据"), prefix + " missing summary reasons")
	game.daily_summary.detail_scroll.scroll_vertical = 100000
	await _settle()
	_expect(game.daily_summary.detail_scroll.scroll_vertical > 0, prefix + " details are not scrollable")
	_save(viewport, prefix + "-summary-detail.png")
	game._finish_run("barely_survived")
	await _settle()
	if enlarged:
		_enlarge_fonts(game)
		await _settle()
	_check_modal(game.ending_screen, game.ending_screen.restart_button, viewport, prefix + " ending")
	_expect(not String(game.ending_screen.feedback["summary"]).contains("晚继续复习"), prefix + " ending invented late sleep")
	_save(viewport, prefix + "-ending.png")
	viewport.queue_free()
	await process_frame
	return {"canvas": [canvas.x, canvas.y], "font_percent": 130 if enlarged else 100, "valid": errors.size() == before_errors}


func _record(condition: String) -> Dictionary:
	var sleep_id: String = {"rested": "sleep_early", "steady": "scroll_phone", "strained": "night_study", "depleted": "night_study"}[condition]
	var before: Dictionary = {"rested": {"energy": 45, "stress": 45}, "steady": {"energy": 70, "stress": 42}, "strained": {"energy": 90, "stress": 20}, "depleted": {"energy": 15, "stress": 85}}[condition]
	var card := Data.get_sleep_option(sleep_id)
	var sleep := {"id": sleep_id}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		sleep[key] = card[key]
	return Recovery.settle(1, before, sleep, {})["recovery_state"]


func _enlarge_fonts(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if not label.has_meta("probe_base_font"):
			label.set_meta("probe_base_font", label.get_theme_font_size("font_size"))
		label.add_theme_font_size_override("font_size", ceili(float(label.get_meta("probe_base_font")) * 1.3))
	for child in node.get_children():
		_enlarge_fonts(child)


func _snapshot(game: GameRootV2) -> Dictionary:
	return {"state": game.state.duplicate(true), "phase": game.phase, "stock": game.dorm_inventory.duplicate(true), "history": game.run_history.duplicate(true)}


func _check_modal(panel: Control, button: Control, viewport: Viewport, name: String) -> void:
	_expect(viewport.get_visible_rect().encloses(panel.get_global_rect()), name + " panel outside viewport: " + str(panel.get_global_rect()))
	_expect(panel.get_global_rect().encloses(button.get_global_rect()), name + " button outside panel")


func _settle() -> void:
	for frame in range(12):
		await process_frame
	RenderingServer.force_draw()


func _save(viewport: Viewport, filename: String) -> void:
	RenderingServer.force_draw()
	var path := output_dir.path_join(filename)
	var code := viewport.get_texture().get_image().save_png(path)
	_expect(code == OK, "Cannot save " + filename)
	if code == OK:
		images.append(path)


func _expect(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
