extends SceneTree

const Scene := preload("res://tests/preview/G4MealPreview.tscn")
const SIZES := [Vector2i(1920, 1080), Vector2i(720, 1280), Vector2i(780, 1280)]
var output := "res://.godot/g4-preview-visual"
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
		root.mode = Window.MODE_WINDOWED
		root.size = physical
		native._restart()
		await _settle()
		for id in ["fixture_rice", "fixture_egg"]:
			native.content_scroll.ensure_control_visible(native.cards[id])
			await _settle()
			await _click(native.cards[id])
			await _settle()
		_check(native.model.selected.size() == 2, "native selection failed: " + str(physical))
		_check(native.model.balance == 20 and native.model.records.is_empty(), "native preview charged money")
		native.content_scroll.ensure_control_visible(native.suggestion_button)
		await _settle()
		await _click(native.suggestion_button)
		await _settle()
		_check(native.model.selected.has("fixture_vegetable"), "native option failed: " + str(physical))
		await _click(native.confirm_button)
		await _settle()
		_check(native.model.balance == 13 and native.model.records.size() == 1, "native confirmation incorrect: " + str(physical))
		await _click(native.skip_button)
		await _settle()
		await _click(native.diary_button)
		await _settle()
		_check(native.diary_panel.visible and native.model.diary()["observation"] == "午饭没吃。", "native diary failed: " + str(physical))
		_save(root, "%dx%d-native-diary.png" % [physical.x, physical.y])
		native._restart()
		await _settle()
		for id in ["fixture_rice", "fixture_egg"]:
			native.content_scroll.ensure_control_visible(native.cards[id])
			await _settle()
			await _click(native.cards[id])
			await _settle()
		native.content_scroll.ensure_control_visible(native.alternative_toggle)
		await _settle()
		await _click(native.alternative_toggle)
		await _settle()
		_check(native.alternative_button.visible, "native alternative did not unfold: " + str(physical))
		native.content_scroll.ensure_control_visible(native.alternative_button)
		await _settle()
		_save(root, "%dx%d-native-alternative.png" % [physical.x, physical.y])
		await _click(native.alternative_button)
		await _settle()
		_check(native.model.selected.has("fixture_mixed") and native.model.balance == 20, "native alternative charged early")
		await _click(native.confirm_button)
		await _settle()
		_check(native.model.balance == 9 and native.model.records.size() == 1, "native alternative confirmation wrong")
		native._restart()
		native._toggle("fixture_rice")
		native._toggle("fixture_egg")
		native._scroll_to_control(native.dismiss_suggestion_button)
		await _settle()
		await _click(native.dismiss_suggestion_button)
		await _settle()
		native._scroll_to_control(native.dismiss_suggestion_button)
		await _settle()
		await _click(native.dismiss_suggestion_button)
		await _settle()
		_check(native.plan_label.visible, "native dismissed options did not give a plan: %s, receipts=%s, selected=%s, offer=%s" % [physical, native.model.suggestion_history.size(), native.model.selected, native._proposal.get("reason")])
		native.content_scroll.ensure_control_visible(native.plan_label)
		await _settle()
		_save(root, "%dx%d-native-plan.png" % [physical.x, physical.y])
		await _click(native.confirm_button)
		await _settle()
		_check(native.model.balance == 16 and native.model.records.size() == 1, "plan blocked ordinary confirmation")
	native.queue_free()
	await process_frame
	var report := {"valid": errors.is_empty(), "errors": errors, "images": images, "layouts": 6, "native_windows": [[1920, 1080], [390, 640]], "scope": "Isolated development menu with simulated reviews; Label/Button fonts enlarged in test. Native GUI input, not browser or physical phone."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("G4_PREVIEW_VISUAL=" + JSON.stringify({"valid": report["valid"], "errors": errors, "images": images.size(), "layouts": 6}))
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
	preview._layout()
	await _settle()
	var prefix := "%dx%d-%s" % [canvas.x, canvas.y, "130" if enlarged else "100"]
	_check(viewport.get_visible_rect().encloses(preview.balance_label.get_global_rect()), prefix + " balance clipped")
	_check(viewport.get_visible_rect().encloses(preview.confirm_button.get_global_rect()), prefix + " confirm clipped")
	preview._toggle("fixture_rice")
	preview._toggle("fixture_egg")
	await _settle()
	preview.content_scroll.ensure_control_visible(preview.view_panel)
	await _settle()
	_check(preview.content_scroll.get_global_rect().encloses(preview.composition.ingredients_label.get_global_rect()), prefix + " ingredient names not reachable")
	_check(preview.composition.portion_label.text == "份量未标", prefix + " no quantity boundary")
	_save(viewport, prefix + "-menu.png")
	preview.composition.details_button.pressed.emit()
	await _settle()
	preview.content_scroll.ensure_control_visible(preview.composition.details_scroll)
	await _settle()
	_check(preview.composition.details_scroll.visible, prefix + " details did not open")
	_save(viewport, prefix + "-ingredients.png")
	preview.alternative_toggle.set_pressed_no_signal(true)
	preview._toggle_alternative()
	await _settle()
	preview.content_scroll.ensure_control_visible(preview.alternative_button)
	await _settle()
	_check(preview.alternative_button.visible, prefix + " alternative not visible")
	_check(preview.content_scroll.get_global_rect().encloses(preview.alternative_button.get_global_rect()), prefix + " alternative clipped")
	_save(viewport, prefix + "-alternative.png")
	preview.alternative_toggle.set_pressed_no_signal(false)
	preview._toggle_alternative()
	preview.composition.details_button.pressed.emit()
	preview._try_option()
	preview._confirm()
	preview._skip()
	preview._toggle_diary()
	if enlarged:
		_enlarge(preview)
	await _settle()
	_save(viewport, prefix + "-diary.png")
	_check(preview.model.diary()["observation"] == "午饭没吃。", prefix + " wrong record")
	preview._toggle_diary()
	preview._toggle("fixture_low")
	await _settle()
	preview.content_scroll.ensure_control_visible(preview.view_panel)
	await _settle()
	_check(preview.composition.ingredients_label.text.is_empty(), prefix + " unknown exposed ingredients")
	_save(viewport, prefix + "-unknown.png")
	preview._restart()
	preview._toggle("fixture_rice")
	preview._toggle("fixture_egg")
	preview._dismiss_suggestion()
	preview._dismiss_suggestion()
	await _settle()
	preview.content_scroll.ensure_control_visible(preview.plan_label)
	await _settle()
	_check(preview.plan_label.visible and not preview.suggestion_button.visible, prefix + " no-action plan wrong")
	_check(preview.content_scroll.get_global_rect().encloses(preview.plan_label.get_global_rect()), prefix + " plan clipped")
	_save(viewport, prefix + "-plan.png")
	viewport.queue_free()
	await process_frame


func _enlarge(node: Node) -> void:
	if node is Label or node is Button:
		var control := node as Control
		if not control.has_meta("base_font"):
			control.set_meta("base_font", control.get_theme_font_size("font_size"))
		control.add_theme_font_size_override("font_size", ceili(float(control.get_meta("base_font")) * 1.3))
	for child in node.get_children():
		_enlarge(child)


func _click(control: Control) -> void:
	var factor := Vector2(root.size) / root.get_visible_rect().size
	var point := control.get_global_rect().get_center() * factor
	var activated := [false]
	var observe := func() -> void: activated[0] = true
	if control is BaseButton:
		control.pressed.connect(observe)
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
	if control is BaseButton:
		control.pressed.disconnect(observe)
		if not activated[0]:
			var scroll = current_scene.content_scroll
			print("NATIVE_CLICK_MISSED=" + JSON.stringify({"window": root.size, "button": control.name, "point": point, "rect": control.get_global_rect(), "visible_rect": root.get_visible_rect(), "scroll_rect": scroll.get_global_rect(), "scroll_value": scroll.scroll_vertical, "scroll_max": scroll.get_v_scroll_bar().max_value, "scroll_page": scroll.get_v_scroll_bar().page, "columns_rect": current_scene.columns.get_global_rect(), "visible": control.is_visible_in_tree(), "disabled": control.disabled}))


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


func _check(condition: bool, text: String) -> void:
	if not condition:
		errors.append(text)
