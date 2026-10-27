extends "res://tests/story_keyboard_visual_probe.gd"

var diagnostics: Array[Dictionary] = []


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var menu := Menu.instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	var card: Control = menu._grid.get_node("choir_week")
	(menu._margin.get_child(0) as ScrollContainer).ensure_control_visible(card)
	(card.find_child("ChooseStory", true, false) as Button).grab_focus()
	await key(KEY_ENTER)
	check(menu._dialog.visible, "Enter did not open the story introduction")
	await save("00-story-introduction")
	await key(KEY_ENTER)
	var game := current_scene as GameRootV2
	check(game != null, "Enter did not start the story")
	if game == null:
		print("DAILY_KEYBOARD_RESULT=" + JSON.stringify({"errors": errors, "step": "start"}))
		quit(1)
		return
	diagnostics.append({"step": "new_day", "focus": str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() != null else "none", "keys": game.new_day_popup.is_processing_unhandled_key_input(), "disabled": game.new_day_popup.continue_button.disabled})
	check(root.gui_get_focus_owner() == game.new_day_popup.continue_button, "The new day must start focused on Continue")
	await key(KEY_ENTER)
	check(not is_instance_valid(game._workspace) and game.phase == "breakfast_source", "Enter must open the destination scene without a kitchen panel")
	diagnostics.append({"step": "after_continue", "focus": str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() != null else "none", "keys": game.new_day_popup.is_processing_unhandled_key_input(), "disabled": game.new_day_popup.continue_button.disabled, "pending": game._new_day_pending, "locked": game.new_day_popup._continue_locked, "story": game.story_id})
	if OS.get_cmdline_user_args().has("--diagnose-start"):
		print("DAILY_START_DIAGNOSTICS=" + JSON.stringify(diagnostics))
		quit(0)
		return
	check(not game.new_day_popup.visible, "Continuing must close the new-day popup")
	# Reopen the real new-day payload to inspect its modal controls independently.
	game._show_new_day_popup()
	await settle()
	for index in range(8):
		await key(KEY_TAB)
		check(game.new_day_popup.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped the new-day popup")
	game.new_day_popup.recovery_details_button.grab_focus()
	await key(KEY_ENTER)
	check(game.sticky_note.visible and game.sticky_note.pinned, "Recovery details did not open")
	for index in range(5):
		await key(KEY_TAB)
		check(game.sticky_note.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped pinned recovery details")
	await save("01-recovery-keyboard")
	await key(KEY_ESCAPE)
	check(not game.sticky_note.visible and not game.new_day_popup.continue_button.disabled, "Closing recovery details must re-enable the day")
	check(root.gui_get_focus_owner() == game.new_day_popup.recovery_details_button, "Recovery details must return focus to their opener")
	game.new_day_popup.continue_button.grab_focus()
	await key(KEY_ENTER)
	if is_instance_valid(game._workspace): await key(KEY_ESCAPE)
	# Declared day-completion fixture; all popup interactions use actual keys.
	for meal in range(3):
		game._skip_meal()
		game._skip_action()
	game._choose_sleep("sleep_early")
	await settle()
	check(game.phase == "summary", "Day-completion fixture did not reach the summary")
	for index in range(10):
		await key(KEY_TAB, index % 2 == 0)
		check(game.daily_summary.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped the daily summary")
	game.daily_summary.detail_button.grab_focus()
	await key(KEY_ENTER)
	check(game.daily_summary.detail_panel.visible, "Enter must expand the day details")
	await key(KEY_ESCAPE)
	check(not game.daily_summary.detail_panel.visible and game.phase == "summary", "Escape must collapse details without advancing the day")
	game.daily_summary.record_book_button.grab_focus()
	await key(KEY_ENTER)
	check(is_instance_valid(game._record_book) and game._record_book.visible, "Enter must open the meal record book")
	if not is_instance_valid(game._record_book):
		print("DAILY_KEYBOARD_RESULT=" + JSON.stringify({"errors": errors, "diagnostics": diagnostics, "step": "record_book", "day": game.day, "phase": game.phase}))
		quit(1)
		return
	for index in range(12):
		await key(KEY_TAB)
		check(game._record_book.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped the record book")
	await save("02-record-book-keyboard")
	await key(KEY_ESCAPE)
	check(not game._record_book.visible and game.daily_summary.visible and game.day == 1, "Record book return changed the day or hid the summary")
	check(root.gui_get_focus_owner() == game.daily_summary.next_button, "Record book must restore summary focus")
	await save("03-summary-return")
	await key(KEY_ENTER)
	check(game.day == 2 and game.new_day_popup.visible, "Enter must advance exactly once to day 2")
	await key(KEY_ENTER)
	check(game.day == 2 and not game.new_day_popup.visible, "Enter must begin day 2 without another day advance")
	check(game.run_history.size() == 1, "Keyboard navigation duplicated daily settlement")
	# Isolated component fixture: a replacement summary must survive the old
	# closing animation and accept the next day's input again.
	var popup := preload("res://scenes/game_v2/components/DailySummaryPopup.tscn").instantiate() as DailySummaryPopupV2
	root.add_child(popup)
	var next_events: Array[String] = []
	popup.next_day_requested.connect(func() -> void: next_events.append("next"))
	popup.show_summary({"day": 1}, true)
	await settle()
	popup._on_next_pressed()
	popup.show_summary({"day": 2}, true)
	await settle()
	check(popup.visible and popup.day_title.text == "第 2 天，收工" and not popup.next_button.disabled, "The old close animation hid or locked a replacement summary")
	check(next_events == ["next"], "Reopening the summary emitted another advance request")
	popup.queue_free()
	var result := {"errors": errors, "diagnostics": diagnostics, "window": str(DisplayServer.window_get_size()), "day": game.day, "scope": "Actual native menu/start and popup key events; declared three skipped meals/actions and early-sleep fixture prepares the summary. In-memory saves only."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("DAILY_KEYBOARD_RESULT=" + JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
