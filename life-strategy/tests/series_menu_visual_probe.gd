extends SceneTree

const Menu := preload("res://scenes/main_menu/MainMenu.tscn")
const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Store := preload("res://scripts/stories/GameSaveStore.gd")
var output := "E:/nutrition_life_strategy_game/.cache/menu-redesign-2026-10-28/desktop"
var errors: Array[String] = []
var cases: Array[Dictionary] = []


func _initialize() -> void:
	Store.memory_for_tests = true
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var menu := Menu.instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	await save("01-title")
	await click(menu._title_start)
	check(menu._page == "characters", "Title did not open selection")
	await save("02-student")
	await click(menu._strips["zhou_huilan_66"])
	check(menu._selected == "choir_week", "Selecting Zhou chose wrong story")
	await save("03-zhou")
	await click(menu._more_info)
	check(menu._dialog.visible, "Life details did not open")
	await save("04-story-info")
	await key(KEY_ESCAPE)
	check(not menu._dialog.visible, "Esc did not close details")
	await click(menu._other_saves)
	await save("05-empty-saves")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(menu._page == "title", "Esc did not return to title")
	await key(KEY_ENTER)
	check(menu._page == "characters" and not menu._starting, "Enter accidentally started a run")
	cases.append({"case": "two-person flow", "story": menu._selected, "page": menu._page})
	menu.queue_free()
	await process_frame
	var future := Menu.instantiate()
	var templates := Catalog.all()
	for i in range(10):
		var story: Dictionary = templates[i % templates.size()].duplicate(true)
		story["id"] = "layout_story_%d" % i
		story["character_id"] = "layout_character_%d" % i
		story["character_name"] = "测试人物%02d" % (i + 1)
		story["character_short_name"] = story["character_name"]
		future._catalog_override.append(story)
	root.add_child(future)
	current_scene = future
	await settle()
	await click(future._title_start)
	await save("06-expansion-first")
	var selected_before_swipe: String = future._selected_character
	await swipe(future._rail)
	check(future._rail.scroll_horizontal > 0, "Touch swipe did not browse the strip rail")
	check(future._selected_character == selected_before_swipe, "Swiping accidentally selected a person")
	for i in range(9): await click(future._next)
	check(future._selected_character == "layout_character_9", "Cannot browse later characters")
	check(future._next.disabled, "Last-character navigation should stop")
	await save("07-expansion-last")
	await key(KEY_LEFT)
	await key(KEY_TAB)
	check(is_instance_valid(root.gui_get_focus_owner()), "Keyboard focus was lost")
	cases.append({"case": "ten-person layout fixture", "count": future._groups.size(), "selected": future._selected_character, "scroll": future._rail.scroll_horizontal, "fixture_only": true})
	future.queue_free()
	await process_frame
	var launch := Menu.instantiate()
	root.add_child(launch)
	current_scene = launch
	await settle()
	await click(launch._title_start)
	await click(launch._strips["zhou_huilan_66"])
	await click(launch._main_start)
	await settle()
	var game := current_scene as GameRootV2
	check(game != null and game.story_id == "choir_week", "Main start did not launch selected character")
	if game != null:
		await save("08-zhou-started")
		cases.append({"case": "start selected story", "story": game.story_id, "day": game.day})
	var report := {"errors": errors, "cases": cases, "window": str(root.size), "scope": "Native mouse/keyboard title, person strips, story details, empty slots, Back/Esc, focus, ten-person layout-only fixture, then actual selected-story launch. Fixture people reuse existing art and are not production characters. Not physical-phone or browser refresh verification."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("SERIES_MENU_VISUAL=" + JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)


func settle() -> void:
	await create_timer(0.35).timeout
	for i in range(3): await process_frame
	RenderingServer.force_draw()


func save(name: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))


func click(control: Control) -> void:
	var available: bool = control != null and control.is_visible_in_tree() and (not control is BaseButton or not control.disabled)
	check(available, "Input target unavailable: " + (String(control.name) if control != null else "null"))
	if not available: return
	var pos := control.get_global_rect().get_center() * (Vector2(root.size) / root.get_visible_rect().size)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = pos
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await settle()


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await settle()


func swipe(control: Control) -> void:
	var rect := control.get_global_rect()
	var scale := Vector2(root.size) / root.get_visible_rect().size
	var from := (rect.position + rect.size * Vector2(0.86,0.4)) * scale
	var to := (rect.position + rect.size * Vector2(0.18,0.4)) * scale
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = from
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	var previous := from
	for i in range(1,13):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = from.lerp(to,float(i)/12.0)
		drag.relative = drag.position - previous
		Input.parse_input_event(drag)
		previous = drag.position
		await process_frame
	touch = touch.duplicate() as InputEventScreenTouch
	touch.position = to
	touch.pressed = false
	Input.parse_input_event(touch)
	await settle()


func check(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
