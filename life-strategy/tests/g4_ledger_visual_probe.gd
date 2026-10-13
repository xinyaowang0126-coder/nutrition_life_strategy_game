extends SceneTree

const Scene := preload("res://tests/preview/G4RecordPreview.tscn")
const SIZES := [Vector2i(1920, 1080), Vector2i(720, 1280), Vector2i(780, 1280)]
var output := "res://.godot/g4-ledger-visual"
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
			await _capture(canvas, enlarged)
	var native = Scene.instantiate()
	root.add_child(native)
	current_scene = native
	for physical in [Vector2i(1920, 1080), Vector2i(390, 640)]:
		root.size = physical
		await _settle()
		var before: Array[Dictionary] = native.model.ledger.get_entries()
		await _click(native.day_buttons[1])
		await _settle()
		_check(native.model.selected_day == 2, "native day selection failed: " + str(physical))
		_check(native.summary_label.text.contains("午饭没吃"), "native day summary wrong")
		await _click(native.week_button)
		await _settle()
		_check(native.model.weekly, "native week selection failed")
		_check(native.model.ledger.get_entries() == before, "navigation mutated ledger")
		_save(root, "%dx%d-native-week.png" % [physical.x, physical.y])
		await _click(native.clear_button)
		await _settle()
		_check(native.model.ledger.get_entries().is_empty(), "native clear failed")
		await _click(native.restore_button)
		await _settle()
		_check(native.model.ledger.get_entries() == before, "native restore failed")
	native.queue_free()
	await process_frame
	var report := {"valid": errors.is_empty(), "errors": errors, "images": images, "layouts": 6, "native_windows": [[1920, 1080], [390, 640]], "scope": "Isolated synthetic records; native input and logical canvases, not physical phone/browser or production approval."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("G4_LEDGER_VISUAL=" + JSON.stringify({"valid": report["valid"], "errors": errors, "images": images.size(), "layouts": 6}))
	quit(0 if errors.is_empty() else 1)


func _capture(canvas: Vector2i, enlarged: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = canvas
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview = Scene.instantiate()
	viewport.add_child(preview)
	if enlarged:
		_enlarge(preview)
	await _settle()
	var prefix := "%dx%d-%s" % [canvas.x, canvas.y, "130" if enlarged else "100"]
	_check(viewport.get_visible_rect().encloses(preview.title_label.get_global_rect()), prefix + " title clipped")
	_check(viewport.get_visible_rect().encloses(preview.restore_button.get_global_rect()), prefix + " footer clipped")
	_save(viewport, prefix + "-day1.png")
	preview._select_day(2)
	await _settle()
	_save(viewport, prefix + "-unknown.png")
	preview._select_week()
	await _settle()
	_save(viewport, prefix + "-week.png")
	preview.scroll.scroll_vertical = 100000
	await _settle()
	_save(viewport, prefix + "-versions.png")
	_check(viewport.get_visible_rect().encloses(preview.week_button.get_global_rect()), prefix + " week tab clipped")
	viewport.queue_free()
	await process_frame


func _click(control: Control) -> void:
	var factor := Vector2(root.size) / root.get_visible_rect().size
	var point := control.get_global_rect().get_center() * factor
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


func _enlarge(node: Node) -> void:
	if node is Label or node is Button:
		var control := node as Control
		control.add_theme_font_size_override("font_size", ceili(control.get_theme_font_size("font_size") * 1.3))
	for child in node.get_children():
		_enlarge(child)


func _settle() -> void:
	for frame in range(12):
		await process_frame
	RenderingServer.force_draw()


func _save(viewport: Viewport, name: String) -> void:
	RenderingServer.force_draw()
	var path := output.path_join(name)
	if viewport.get_texture().get_image().save_png(path) == OK:
		images.append(path)
	else:
		errors.append("cannot save " + name)


func _check(condition: bool, reason: String) -> void:
	if not condition:
		errors.append(reason)
