extends SceneTree

## Native rendering and real GUI input audit for the card-style refinement.
## Run with --script res://tests/card_ui_visual_probe.gd -- --output=<directory>.
## All runs are isolated and health-history writes are disabled.

const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")
const MenuScene := preload("res://scenes/main_menu/MainMenu.tscn")
const SIZES := [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(390, 844)]

var _output := "res://.godot/card-ui-visual"
var _errors: Array[String] = []
var _reports: Array[Dictionary] = []
var _images: Array[String] = []


class StableDetailProbe:
	extends "res://tests/detail_input_probe.gd"

	func _settle(seconds: float) -> void:
		await _tree.create_timer(seconds).timeout
		# Await queued wrapping/layout work before measuring click coordinates.
		for frame in range(3):
			await _tree.process_frame
		RenderingServer.force_draw()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(_output)
	for resolution in SIZES:
		var prefix := "%dx%d" % [resolution.x, resolution.y]
		root.size = resolution
		var menu := MenuScene.instantiate()
		root.add_child(menu)
		current_scene = menu
		await _settle()
		await _save(prefix + "-menu")
		root.remove_child(menu)
		menu.queue_free()
		var game := GameScene.instantiate() as GameRootV2
		game.health_history_path = ""
		root.add_child(game)
		current_scene = game
		game.new_day_popup.hide_popup(false)
		await _settle()
		await _save(prefix + "-map")
		var source_stage := game._active_stage as MealSourceStageV2
		var source_button := source_stage._prop_for("cafeteria").get_node("Button") as Control
		Input.parse_input_event(_motion_event(_screen_center(game, source_button)))
		await _settle()
		if not game.sticky_note.visible:
			_errors.append(prefix + ": map destination hover has no details")
		await _save(prefix + "-map-hover")
		var probe := StableDetailProbe.new()
		for source in ["cafeteria", "convenience_store", "dorm_storage"]:
			var report: Dictionary = await probe.run(game, resolution, source)
			_reports.append(report)
			if not bool(report["valid"]):
				_errors.append(prefix + "/" + source + ": " + str(report["errors"]))
		game.start_new_run()
		game.new_day_popup.hide_popup(false)
		game._choose_meal_source("cafeteria")
		await _settle()
		var stage := game._active_stage as CafeteriaMealStageV2
		var first_id := String(stage._cards_by_id.keys()[0])
		game._on_food_toggled(first_id)
		await _settle()
		var card := stage._cards_by_id[first_id] as CompactChoiceCardV2
		if not card.kind_label.visible or card.kind_label.text != "已选":
			_errors.append(prefix + ": selected card has no readable selection badge")
		await _save(prefix + "-selected")
		Input.parse_input_event(_motion_event(Vector2(8, 8)))
		await _settle()
		Input.parse_input_event(_motion_event(_screen_center(game, card)))
		await _settle()
		if not game.sticky_note.visible or game.sticky_note.pinned:
			_errors.append(prefix + ": actual pointer hover failed to show transient details")
		await _save(prefix + "-hover")
		Input.parse_input_event(_motion_event(Vector2(8, 8)))
		await _settle()
		card.grab_focus()
		await _settle()
		if (card.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left != 5:
			_errors.append(prefix + ": whole-card keyboard focus is not visible")
		await _save(prefix + "-focus")
		root.gui_release_focus()
		game.sticky_note.hide_note(false)
		game._confirm_food([first_id])
		await _settle()
		await _save(prefix + "-morning-actions")
		if resolution == SIZES[0]:
			for phase in ["lunch_action", "dinner_action", "sleep"]:
				game.phase = phase
				game._render_phase()
				await _settle()
				await _save(prefix + "-" + phase)
			game._choose_sleep("sleep_early")
			await _settle()
			await _save(prefix + "-day-summary")
		game.new_day_popup.hide_popup(false)
		game.daily_summary.hide_summary(false)
		game.phase = "lunch_source"
		game.current_source_id = ""
		game._render_phase()
		game._choose_meal_source("takeout")
		await _settle()
		await _save(prefix + "-takeout")
		root.remove_child(game)
		game.queue_free()
		await process_frame
	var result := {"valid": _errors.is_empty(), "errors": _errors, "input_reports": _reports, "images": _images, "scope": "Native Windows rendering and injected GUI events; no physical touch-device claim."}
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
	print("CARD_UI_VISUAL_RESULT=" + JSON.stringify({"valid": result["valid"], "errors": _errors, "input_cases": _reports.size(), "images": _images.size()}))
	quit(0 if _errors.is_empty() else 1)


func _settle() -> void:
	await create_timer(0.4).timeout
	RenderingServer.force_draw()


func _save(label: String) -> void:
	RenderingServer.force_draw()
	var path := _output.path_join(label + ".png")
	var error := root.get_texture().get_image().save_png(path)
	if error == OK:
		_images.append(path)
	else:
		_errors.append("Could not capture " + path)


func _screen_center(game: Control, control: Control) -> Vector2:
	return control.get_global_rect().get_center() * Vector2(root.size) / game.get_viewport().get_visible_rect().size


func _motion_event(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	return event
