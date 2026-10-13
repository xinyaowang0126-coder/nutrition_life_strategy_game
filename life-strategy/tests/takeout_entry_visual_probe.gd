extends SceneTree

const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")
const SIZES := [Vector2i(1912, 946), Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(720, 1280), Vector2i(390, 844), Vector2i(390, 640)]
var output := "res://.godot/takeout-entry-visual"
var errors: Array[String] = []
var cases: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in SIZES:
		root.size = resolution
		await _settle()
		_check(DisplayServer.window_get_size() == resolution, "Physical window mismatch: " + str(resolution))
		var game := GameScene.instantiate() as GameRootV2
		game.health_history_path = ""
		root.add_child(game)
		current_scene = game
		await _settle()
		game.new_day_popup.hide_popup(false)
		await _settle()
		var prefix := "%dx%d" % [resolution.x, resolution.y]
		var stage := game._active_stage as MealSourceStageV2
		var card := stage._prop_for("takeout")
		var target := card.get_node("Button") as BaseButton
		var info := card.get_node("Info") as Button
		var initial_balance := int(game.state["balance"])
		_check(target.disabled, prefix + " breakfast ordering must be unavailable")
		_check((card.get_node("ClosedSticker") as Label).text == "早餐未开放", prefix + " unavailable reason is unclear")
		_check((card.get_node("Availability") as Label).text.replace("\n", "") == "午餐、晚餐开放", prefix + " availability differs from configured periods")
		_check_regions(game, stage, card, prefix)
		await _save(prefix + "-breakfast")
		await _click(game, target.get_global_rect().get_center())
		_check(game.phase == "breakfast_source" and int(game.state["balance"]) == initial_balance, prefix + " disabled card changed game state")
		await _click(game, info.get_global_rect().get_center())
		_check(game.sticky_note.visible and game.sticky_note.pinned, prefix + " rules cannot be opened")
		_check(int(game.state["balance"]) == initial_balance, prefix + " viewing rules charged money")
		await _save(prefix + "-rules")
		game.sticky_note.hide_note()
		await _settle()
		game.phase = "lunch_source"
		game._render_phase()
		await _settle()
		stage = game._active_stage as MealSourceStageV2
		card = stage._prop_for("takeout")
		target = card.get_node("Button") as BaseButton
		_check(not target.disabled, prefix + " lunch ordering is unavailable")
		_check((card.get_node("ClosedSticker") as Label).text == "点此选餐", prefix + " available state lacks its action")
		_check_regions(game, stage, card, prefix)
		await _save(prefix + "-lunch")
		# Click the label-side area, not the phone, to verify the whole entry works.
		var click_point := (card.get_node("Name") as Control).get_global_rect().get_center()
		await _click(game, click_point)
		_check(game.phase == "lunch" and game.current_source_id == "takeout", prefix + " whole-card selection failed")
		_check(int(game.state["balance"]) == initial_balance, prefix + " opening ordering charged before confirmation")
		cases.append({"physical_size": [resolution.x, resolution.y], "mobile": game._mobile_mode, "balance": initial_balance})
		game.queue_free()
		await _settle()
	var report := {"valid": errors.is_empty(), "errors": errors, "cases": cases, "note": "Native rendered windows and pointer input; not physical phone hardware."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("TAKEOUT_ENTRY_VISUAL_RESULT=" + JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)


func _check_regions(game: GameRootV2, stage: MealSourceStageV2, card: Control, prefix: String) -> void:
	var bounds := game.get_viewport().get_visible_rect()
	var paper := (card.get_node("Paper") as Control).get_global_rect()
	_check(bounds.encloses(paper), prefix + " card leaves viewport")
	for node_name in ["PhoneIcon", "Name", "Availability", "ClosedSticker", "Info"]:
		var region := (card.get_node(node_name) as Control).get_global_rect()
		_check(paper.encloses(region), prefix + " clipped card content: " + node_name)
	_check(not paper.intersects(game.character_hud.status_board.get_global_rect()), prefix + " card covers the status HUD")
	_check(not paper.intersects((stage.get_node("Footer") as Control).get_global_rect()), prefix + " card covers persistent actions")
	for other in ["cafeteria", "convenience_store", "dorm_storage"]:
		var label := stage._prop_for(other).get_node("Name") as Control
		_check(not paper.intersects(label.get_global_rect()), prefix + " card covers another source: " + other)
	var info := (card.get_node("Info") as Control).get_global_rect()
	_check(not info.intersects((card.get_node("Name") as Control).get_global_rect()), prefix + " title and rules button overlap")
	_check(not info.intersects((card.get_node("Availability") as Control).get_global_rect()), prefix + " rules button covers opening periods")
	if game._mobile_mode:
		var pixels := info.size * (Vector2(root.size) / bounds.size)
		_check(pixels.x >= 44.0 and pixels.y >= 44.0, prefix + " touch target is too small: " + str(pixels))


func _click(game: GameRootV2, position: Vector2) -> void:
	var pixels := position * (Vector2(root.size) / game.get_viewport().get_visible_rect().size)
	var motion := InputEventMouseMotion.new()
	motion.position = pixels
	motion.global_position = pixels
	Input.parse_input_event(motion)
	await _settle()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pixels
		event.global_position = pixels
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _settle() -> void:
	await create_timer(0.35).timeout
	for frame in range(3):
		await process_frame
	RenderingServer.force_draw()


func _save(name: String) -> void:
	RenderingServer.force_draw()
	_check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Screenshot failed: " + name)


func _check(valid: bool, message: String) -> void:
	if not valid:
		errors.append(message)
