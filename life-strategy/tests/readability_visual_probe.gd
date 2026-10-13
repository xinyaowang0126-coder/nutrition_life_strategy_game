extends SceneTree

## Run from a normal game process, not the editor's placeholder-script context:
## await load("res://tests/readability_visual_probe.gd").capture(get_tree(), output_dir, Vector2i(720, 1280))
## Uses actual rendered SubViewports; never claims these are physical phone tests.

const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")
const SIZES := [Vector2i(720, 1280), Vector2i(803, 1280), Vector2i(1920, 1080)]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := "res://.godot/ux03-ux04-visual"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	var summaries: Array[Dictionary] = []
	var valid := true
	for requested_size in SIZES:
		var report := await capture(self, output_dir, requested_size)
		valid = valid and bool(report["valid"])
		summaries.append({
			"canvas_size": [requested_size.x, requested_size.y],
			"valid": report["valid"], "errors": report["errors"],
			"rows": report.get("rows", []).size(), "images": report.get("images", []).size(),
		})
	print("READABILITY_VISUAL_RESULT=" + JSON.stringify({"valid": valid, "cases": summaries}))
	quit(0 if valid else 1)


static func capture(tree: SceneTree, output_dir: String, requested_size: Vector2i = Vector2i(720, 1280)) -> Dictionary:
	var errors: Array[String] = []
	var rows: Array[Dictionary] = []
	var image_paths: Array[String] = []
	var physical_size := tree.root.size
	var original_scale_size := tree.root.content_scale_size
	var original_scale_mode := tree.root.content_scale_mode
	var original_scale_aspect := tree.root.content_scale_aspect
	var create_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if create_error != OK:
		return {"valid": false, "errors": ["Cannot create output directory: %d" % create_error]}
	var capture_sizes := [requested_size] if requested_size != Vector2i.ZERO else SIZES
	for logical_size in capture_sizes:
		var viewport := SubViewport.new()
		viewport.size = logical_size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		tree.root.add_child(viewport)
		var game := GameScene.instantiate() as GameRootV2
		game.health_history_path = ""
		viewport.add_child(game)
		var responsive_callback := Callable(game, "_apply_responsive_profile")
		if viewport.size_changed.is_connected(responsive_callback):
			viewport.size_changed.disconnect(responsive_callback)
		game._mobile_mode = logical_size.y > logical_size.x
		game._apply_shell_profile()
		game.new_day_popup.set_mobile_mode(game._mobile_mode)
		await _settle(tree)
		var prefix := "%dx%d" % [logical_size.x, logical_size.y]
		_check(not game.new_day_popup.status_summary.text.contains("昨日"), errors, prefix + " first day refers to prior records")
		_check(not game.new_day_popup.status_summary.text.contains("昨天"), errors, prefix + " first day refers to yesterday")
		await _save(viewport, output_dir.path_join(prefix + "-first-day.png"), image_paths, errors)
		game.new_day_popup.hide()
		game.phase = "dinner_source"
		game._render_phase()
		await _settle(tree)
		await _save(viewport, output_dir.path_join(prefix + "-night-sources.png"), image_paths, errors)
		var sources := game._active_stage as MealSourceStageV2
		for source_id in sources.SOURCE_NODE_NAMES:
			var label := sources._prop_for(String(source_id)).get_node("Name") as Label
			_check(viewport.get_visible_rect().encloses(label.get_global_rect()), errors, prefix + " source name outside viewport: " + String(source_id))
		game.phase = "breakfast_source"
		game._render_phase()
		game._choose_meal_source("dorm_storage")
		await _settle(tree)
		var pantry := game._active_stage as DormPantryStageV2
		var visible_area := pantry.pantry_scroll.get_global_rect()
		var cards := pantry.stock_grid.get_children()
		_check(not cards.is_empty(), errors, prefix + " pantry has no cards")
		for index in range(mini(2, cards.size())):
			var card := cards[index] as CompactChoiceCardV2
			_check(visible_area.encloses(card.title_label.get_global_rect()), errors, prefix + " first-row title clipped")
			_check(visible_area.encloses(card.primary_stat.get_global_rect()), errors, prefix + " first-row stats clipped")
		var bowl := pantry.get_node("Layout/BowlPanel") as Control
		_check(bowl.get_global_rect().end.y <= pantry.confirm_button.get_global_rect().position.y, errors, prefix + " bowl covers confirmation")
		_check(viewport.get_visible_rect().encloses(pantry.confirm_button.get_global_rect()), errors, prefix + " confirmation outside viewport")
		await _save(viewport, output_dir.path_join(prefix + "-pantry-top.png"), image_paths, errors)
		pantry.pantry_scroll.scroll_vertical = int(pantry.stock_grid.size.y)
		await _settle(tree)
		if not cards.is_empty():
			var last_card := cards.back() as CompactChoiceCardV2
			_check(visible_area.encloses(last_card.title_label.get_global_rect()), errors, prefix + " last pantry title unreachable by scrolling")
			_check(visible_area.encloses(last_card.primary_stat.get_global_rect()), errors, prefix + " last pantry stats unreachable by scrolling")
		await _save(viewport, output_dir.path_join(prefix + "-pantry-bottom.png"), image_paths, errors)
		for day in range(1, 8):
			game.day = day
			game.phase = "sleep"
			game._render_phase()
			await _settle(tree)
			var sleep := game._active_stage as SleepStageV2
			var note := sleep.get_node("Layout/AlarmNote") as Control
			var note_rect := note.get_global_rect()
			_check(viewport.get_visible_rect().encloses(note_rect), errors, "%s day %d event note outside viewport" % [prefix, day])
			_check(note_rect.encloses(sleep.tomorrow_label.get_global_rect()), errors, "%s day %d event text outside note" % [prefix, day])
			_check(note_rect.encloses(sleep.hint_label.get_global_rect()), errors, "%s day %d hint outside note" % [prefix, day])
			rows.append({"canvas_size": [logical_size.x, logical_size.y], "day": day, "note_rect": str(note_rect), "tomorrow": sleep.tomorrow_label.text})
			if day == 4:
				await _save(viewport, output_dir.path_join(prefix + "-sleep-preview.png"), image_paths, errors)
		viewport.queue_free()
		await tree.process_frame
	tree.root.content_scale_size = original_scale_size
	tree.root.content_scale_mode = original_scale_mode
	tree.root.content_scale_aspect = original_scale_aspect
	var report := {
		"valid": errors.is_empty(), "errors": errors, "rows": rows, "images": image_paths,
		"scope": "Rendered SubViewports; health output off, no history writes, not physical-device verification",
		"physical_window_size": [physical_size.x, physical_size.y],
	}
	var report_path := output_dir.path_join("report-%dx%d.json" % [requested_size.x, requested_size.y])
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	else:
		errors.append("Cannot write visual report: " + report_path)
		report["valid"] = false
	return report


static func _settle(tree: SceneTree) -> void:
	for frame in range(8):
		await tree.process_frame
	# Draw the always-updating SubViewport even if the native helper window
	# becomes occluded while the browser is being tested.
	RenderingServer.force_draw()


static func _save(viewport: SubViewport, path: String, image_paths: Array[String], errors: Array[String]) -> void:
	RenderingServer.force_draw()
	var save_error := viewport.get_texture().get_image().save_png(path)
	if save_error == OK:
		image_paths.append(path)
	else:
		errors.append("Screenshot failed: %s (%d)" % [path, save_error])


static func _check(condition: bool, errors: Array[String], message: String) -> void:
	if not condition:
		errors.append(message)
