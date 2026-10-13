extends SceneTree

const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")
var _output := "res://.godot/character-hud-visual"
var _errors: Array[String] = []
var _cases: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(_output)
	var game := GameScene.instantiate() as GameRootV2
	game.health_history_path = ""
	root.add_child(game)
	current_scene = game
	await _settle()
	game.new_day_popup.hide_popup(false)
	game._choose_meal_source("cafeteria")
	await _settle()
	var hud := game.character_hud
	var original := game.state.duplicate(true)
	var original_stock := game.dorm_inventory.duplicate(true)
	var source := "mobile" if game._mobile_mode else "desktop"
	var before_size := hud.status_board.get_global_rect().size
	var samples := {
		"normal": {"stability": 65, "energy": 52, "mood": 55, "satiety": 58, "stress": 48, "study_progress": 0, "study_target": 70},
		"warning": {"stability": 24, "energy": 19, "mood": 40, "satiety": 95, "stress": 84, "study_progress": 37, "study_target": 70},
		"completed": {"stability": 100, "energy": 100, "mood": 100, "satiety": 100, "stress": 100, "study_progress": 100, "study_target": 100},
	}
	for name in samples:
		hud.update_stats(samples[name], true)
		await _settle()
		var board := hud.status_board.get_global_rect()
		_check(board.size.is_equal_approx(before_size), name + " expanded the compact panel")
		_check(root.get_visible_rect().encloses(board), name + " HUD is outside viewport")
		_check(board.encloses(hud.details_button.get_global_rect()), name + " details button lies outside card")
		for node in [hud.stability_value, hud.energy_value, hud.mood_value, hud.satiety_value, hud.stress_value, hud.recovery_value, hud.study_value, hud.study_track]:
			_check(board.encloses((node as Control).get_global_rect()), name + " clipped " + String(node.name))
		var values := [hud.energy_value, hud.mood_value, hud.satiety_value, hud.stress_value]
		for index in range(1, values.size()):
			_check(is_equal_approx(values[index].get_global_rect().position.y, values[0].get_global_rect().position.y), name + " attributes do not share a row")
		_check(hud.study_track.value == int(samples[name]["study_progress"]), name + " progress does not follow displayed value")
		var button := (game._active_stage as MealStageBaseV2)._get_confirm_button()
		_check(not board.intersects(button.get_global_rect()), name + " HUD covers confirmation")
		if name == "warning":
			_check(hud.energy_value.get_theme_color("font_color") == hud._status_tone("energy", 19).darkened(0.18), "warning colour not applied")
		await _save(name)
		_cases.append({"state": name, "profile": source, "board": str(board), "details": str(hud.details_button.get_global_rect())})
	hud.update_stats(samples["normal"], false)
	await _settle()
	var factor := Vector2(root.size) / root.get_visible_rect().size
	if not game._mobile_mode:
		await _move(hud.status_board.get_global_rect().get_center() * factor)
		_check(game.sticky_note.visible and not game.sticky_note.pinned, "desktop hover did not show read-only details")
		await _move(Vector2(8, 8))
		_check(not game.sticky_note.visible, "desktop hover details did not dismiss")
	await _click(hud.details_button.get_global_rect().get_center() * factor)
	_check(game.sticky_note.visible and game.sticky_note.pinned, "details button did not pin status sheet")
	await _save("details")
	game.sticky_note._on_close_pressed()
	await _settle()
	_check(not game.sticky_note.visible, "status sheet did not close")
	_check(game.state == original, "status review changed game statistics")
	_check(game.dorm_inventory == original_stock, "status review changed inventory")
	await _move(Vector2(8, 8))
	await _save("normal")
	var result := {"valid": _errors.is_empty(), "errors": _errors, "cases": _cases, "physical_size": str(root.size), "scope": "Native Windows rendering and mouse input, not physical-device testing."}
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("CHARACTER_HUD_VISUAL_RESULT=" + JSON.stringify(result))
	quit(0 if _errors.is_empty() else 1)


func _settle() -> void:
	await create_timer(0.35).timeout
	for frame in range(3):
		await process_frame
	RenderingServer.force_draw()


func _save(name: String) -> void:
	RenderingServer.force_draw()
	_check(root.get_texture().get_image().save_png(_output.path_join(name + ".png")) == OK, "Screenshot failed: " + name)


func _move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await _settle()


func _click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _check(value: bool, message: String) -> void:
	if not value:
		_errors.append(message)
