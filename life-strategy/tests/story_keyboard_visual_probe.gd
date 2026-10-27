extends "res://tests/story_series_visual_probe.gd"

const Game := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	Session.request("choir_week")
	var game := Game.instantiate() as GameRootV2
	root.add_child(game)
	current_scene = game
	await settle()
	game.new_day_popup.hide_popup(false)
	game._new_day_pending = false
	game._choose_meal_source("home_kitchen")
	var rice := game._active_stage._cards_by_id["rice_plain"] as HouseholdFoodCard
	game._active_stage.food_scroll.ensure_control_visible(rice)
	await settle()
	rice.info_button.grab_focus()
	await key(KEY_ENTER)
	check(game.sticky_note.visible and game.sticky_note.pinned, "Enter must open the focused food details")
	await key(KEY_TAB)
	check(game.sticky_note.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped pinned food details")
	await key(KEY_ESCAPE)
	check(root.gui_get_focus_owner() == rice.info_button, "Closing food details must restore their info button")
	check(game.selected_food_ids.is_empty(), "Opening or closing details selected a food")
	game._on_food_toggled("rice_plain")
	game._on_food_toggled("soft_tofu_greens")
	await settle()
	game._active_stage._get_confirm_button().grab_focus()
	await key(KEY_ENTER)
	var page := game._workspace as CookingPlanStage
	check(is_instance_valid(page), "Enter must open the cooking preview")
	if not is_instance_valid(page):
		quit(1)
		return
	var pantry := game.kitchen.ingredients.duplicate(true)
	for index in range(14):
		await key(KEY_TAB)
		check(page.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped the cooking worktop at step %d" % index)
	for index in range(14):
		await key(KEY_TAB, true)
		check(page.is_ancestor_of(root.gui_get_focus_owner()), "Shift+Tab escaped the cooking worktop at step %d" % index)
	for code in [KEY_UP, KEY_LEFT, KEY_RIGHT, KEY_DOWN]:
		await key(code)
		check(page.is_ancestor_of(root.gui_get_focus_owner()), "Arrow key escaped the cooking worktop")
	await save("01-cooking-keyboard-focus")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(game._workspace), "Escape must return from cooking preview")
	check(game.selected_food_ids == ["rice_plain", "soft_tofu_greens"], "Escape lost selected recipes")
	check(game.kitchen.ingredients == pantry and game.today_meal_records.is_empty(), "Escape consumed ingredients or settled breakfast")
	check(root.gui_get_focus_owner() == game._active_stage._get_confirm_button(), "Closing preview must restore the preparation button focus")
	# Continue after a failed baseline check so every missing behavior is recorded.
	if is_instance_valid(game._workspace): game._close_workspace()
	game.menu_button.grab_focus()
	await key(KEY_ENTER)
	page = null
	var menu := game._workspace
	check(is_instance_valid(menu), "Enter must open the week menu")
	if not is_instance_valid(menu):
		quit(1)
		return
	var import_button := menu.find_child("import", true, false) as Button
	menu.scroll.scroll_vertical = 0
	import_button.grab_focus()
	await settle()
	check(menu.scroll.get_global_rect().encloses(import_button.get_global_rect()), "Keyboard focus must reveal an offscreen menu action")
	await save("02-menu-focused-import")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(game._workspace), "Escape must close the week menu")
	check(root.gui_get_focus_owner() == game.menu_button, "Closing menu must restore the menu button focus")
	if is_instance_valid(game._workspace): game._close_workspace()
	var choices: Array[String] = []
	game._show_story_dialog("替换这份存档？", "取消后保留已有进度。", [{"id": "save", "text": "替换这份存档"}, {"id": "back", "text": "返回存档列表"}], func(id: String) -> void: choices.append(id))
	await settle()
	for index in range(5):
		await key(KEY_TAB)
		check(game._story_dialog.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped the save confirmation")
	await key(KEY_ESCAPE)
	check(choices == ["back"], "Escape must choose the explicit cancel action exactly once")
	check(root.gui_get_focus_owner() == game.menu_button, "Closing confirmation must restore the opener focus")
	check(game.kitchen.ingredients == pantry and game.today_meal_records.is_empty(), "Dialog navigation changed the run")
	game._show_story_dialog("正在保存进度", "请稍候。", [], func(id: String) -> void: choices.append(id))
	await settle()
	await key(KEY_ESCAPE)
	await key(KEY_ENTER)
	check(game._story_dialog.visible and choices == ["back"], "Busy dialog must not close or activate background controls")
	game._show_story_dialog("读取进度", "选择一份可用进度。", [{"id": "auto", "text": "自动存档", "enabled": false}, {"id": "back", "text": "返回存档列表"}], func(id: String) -> void: choices.append(id))
	await settle()
	check(root.gui_get_focus_owner() == game._story_dialog._buttons.get_node("back"), "Initial focus must skip disabled slots")
	await save("03-dialog-first-enabled")
	await key(KEY_ESCAPE)
	var result := {"errors": errors, "window": str(DisplayServer.window_get_size()), "scope": "Native rendered game with InputEventKey Tab, Shift+Tab, Enter and Escape; in-memory saves only."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("STORY_KEYBOARD_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)


func key(code: Key, shift: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()
