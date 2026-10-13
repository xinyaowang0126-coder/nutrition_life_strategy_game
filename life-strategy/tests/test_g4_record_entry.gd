@tool
extends McpTestSuite

const Presenter := preload("res://scripts/systems/MealRecordPresenter.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Data := preload("res://scripts/GameData.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")


func suite_name() -> String:
	return "g4_record_entry"


func test_settled_day_is_not_counted_again_from_today() -> void:
	var records := [_record("breakfast", ["rice_plain"]), Resolver.build_skipped_record("lunch"), _record("dinner", ["egg"])]
	var book := Presenter.capture([{"day": 1, "meals": records}], records, 1)
	var view := Presenter.view(book, 1, true)
	assert_eq(view["days"].size(), 1)
	assert_eq(view["days"][0]["eaten"], 2)
	assert_eq(view["days"][0]["skipped"], 1)
	assert_eq(view["days"][0]["rows"].size(), 3)
	assert_contains(view["summary"], "2 餐")


func test_unfinished_run_keeps_future_and_unrecorded_slots_separate() -> void:
	var book := Presenter.capture([], [_record("breakfast", ["egg"])], 1)
	assert_eq(book["last_day"], 1)
	assert_eq(book["days"].size(), 1)
	assert_eq(book["days"][0]["unrecorded"], 2)
	assert_eq(book["days"][0]["skipped"], 0)
	assert_false(Presenter.view(book, 2)["valid"])
	assert_eq(book["days"][0]["rows"][1]["text"], "未记")


func test_frozen_names_source_and_cash_stock_are_not_live_card_lookups() -> void:
	var record := _record("breakfast", ["rice_plain"])
	record["food_names"] = ["当时的名字"]
	record["source_name"] = "当时的窗口"
	record["total_cost"] = 9
	var stock := _record("lunch", ["oatmeal"], "dorm_storage")
	var book := Presenter.capture([], [record, stock], 1)
	assert_eq(book["days"][0]["rows"][0]["text"], "当时的名字")
	assert_eq(book["days"][0]["rows"][0]["source"], "当时的窗口")
	assert_eq(book["days"][0]["rows"][0]["payment"], "¥9")
	assert_eq(book["days"][0]["rows"][1]["payment"], "使用存粮")
	record["food_names"].clear()
	assert_eq(book["days"][0]["rows"][0]["text"], "当时的名字")


func test_old_incomplete_malformed_and_contradictory_records_are_unknown() -> void:
	for names in [[123], "鸡蛋", null]:
		var book := Presenter.capture([], [{"phase": "breakfast", "skipped": true, "food_names": names, "food_ids": []}], 1)
		assert_eq(book["days"][0]["rows"][0]["status"], "unknown")
		assert_eq(book["days"][0]["skipped"], 0)
	var legacy := {"phase": "breakfast", "food_names": ["旧面包"], "food_ids": ["bread"], "quality": 99}
	var book := Presenter.capture([], [legacy], 1)
	assert_eq(book["days"][0]["unknown"], 1)
	assert_contains(Presenter.view(book, 1)["notes"], "旧记录的信息不全，配料保持未知。")
	var contradictory := Resolver.build_skipped_record("lunch")
	contradictory["food_names"] = ["面包"]
	assert_eq(Presenter.capture([], [contradictory], 1)["days"][0]["rows"][1]["status"], "unknown")


func test_unplaced_legacy_is_not_silently_lost_or_assigned_a_meal() -> void:
	var book := Presenter.capture([{"day": 1, "meals": [{"skipped": false, "food_names": ["旧面包"]}]}], [], 1)
	assert_eq(book["days"][0]["unplaced"], 1)
	assert_eq(book["days"][0]["unrecorded"], 3)
	assert_contains(Presenter.view(book, 1)["notes"], "1 条旧记录没标餐次，未排进早午晚。")
	assert_false(Presenter.capture(null, [], 1)["valid"])
	assert_false(Presenter.capture([], [], 8)["valid"])


func test_legacy_quality_and_health_payload_cannot_affect_record_facts() -> void:
	var record := _record("breakfast", ["rice_plain"])
	var first := Presenter.capture([], [record], 1)
	record["quality"] = 0
	record["food_groups"] = ["vegetables"]
	record["health_snapshot"] = {"approved": true, "ingredients": [{"name": "伪造配料"}]}
	record["nutrition_score"] = 100
	assert_eq(Presenter.capture([], [record], 1), first)
	var copied := record.duplicate(true)
	copied["quality"] = 100
	assert_eq(Presenter.capture([], [record, copied], 1)["days"][0]["eaten"], 1)
	_assert_no_nutrition(Presenter.view(first, 1))


func test_conflicting_duplicates_and_unknown_payment_never_choose_a_convenient_price() -> void:
	var first := _record("breakfast", ["rice_plain"])
	var second := first.duplicate(true)
	second["total_cost"] = 80
	var book := Presenter.capture([], [first, second], 1)
	assert_eq(book["days"][0]["rows"][0]["status"], "unknown")
	assert_eq(book["days"][0]["rows"][0]["payment"], "")
	first["total_cost"] = "free"
	assert_eq(Presenter.capture([], [first], 1)["days"][0]["rows"][0]["payment"], "消费未记")


func test_views_and_reading_real_game_are_detached_and_do_not_load_health_data() -> void:
	var game := Controller.new() as GameRootV2
	track(game)
	game._deck_service = Deck.new(73)
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game.start_new_run()
	game._choose_meal_source("cafeteria")
	game._confirm_food([game.hand[0]])
	var before := _state(game)
	var book := game.get_meal_record_book()
	assert_eq(book["days"][0]["eaten"], 1)
	var view := Presenter.view(book, 1)
	view["days"].clear()
	book["days"][0]["rows"].clear()
	assert_eq(_state(game), before)
	assert_false(game._health_catalog_loaded)
	assert_eq(game._health_archive, null)
	assert_eq(game.get_health_snapshots(), [])


func test_menu_entry_and_close_do_not_confirm_charge_or_change_selection() -> void:
	var game := _live_game()
	game._choose_meal_source("cafeteria")
	game._on_food_toggled(game.hand[0])
	var before := _state(game)
	game.menu_button.pressed.emit()
	assert_true(game._record_book.visible)
	assert_eq(game._record_book._book["days"][0]["eaten"], 0)
	game._confirm_food(game.selected_food_ids.duplicate())
	game._skip_meal()
	game._apply_action("study")
	game._choose_sleep("sleep_early")
	assert_eq(_state(game), before)
	game._record_book.close_book()
	assert_false(game._record_book.visible)
	assert_eq(_state(game), before)
	game._confirm_food(game.selected_food_ids.duplicate())
	assert_eq(game.today_meal_records.size(), 1)


func test_summary_late_signal_and_enter_cannot_hide_or_advance_under_record_book() -> void:
	var game := _live_game()
	for phase in ["breakfast", "lunch", "dinner"]:
		game._skip_meal()
		game._skip_action()
	game._choose_sleep("sleep_early")
	assert_eq(game.phase, "summary")
	assert_true(game.daily_summary.record_book_button.visible)
	var before := _state(game)
	game.daily_summary.record_book_button.pressed.emit()
	assert_true(game._record_book.visible)
	assert_false(game.daily_summary.is_processing_unhandled_key_input())
	game.daily_summary.next_button.pressed.emit()
	assert_true(game.daily_summary.visible)
	game._on_summary_advanced()
	game._next_day()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	game._record_book._unhandled_key_input(enter)
	assert_eq(_state(game), before)
	game._record_book.close_book()
	assert_true(game.daily_summary.visible)
	assert_false(game.daily_summary.next_button.disabled)
	assert_true(game.daily_summary.is_processing_unhandled_key_input())
	assert_eq(_state(game), before)
	game._on_summary_advanced()
	assert_eq(game.day, 2)


func test_recovery_detail_to_book_restores_new_day_continue_and_late_signals_are_blocked() -> void:
	var game := _live_game(false)
	game._show_recovery_detail()
	assert_true(game.sticky_note.visible)
	assert_true(game.new_day_popup.continue_button.disabled)
	game._show_meal_record_book()
	assert_true(game._record_book.visible)
	assert_false(game.sticky_note.visible)
	game.new_day_popup.continue_button.pressed.emit()
	assert_true(game.new_day_popup.visible)
	game._record_book.close_book()
	assert_false(game.new_day_popup.continue_button.disabled)
	assert_true(game.new_day_popup.is_processing_unhandled_key_input())
	game.new_day_popup._on_continue_pressed()
	assert_true(game.new_day_popup._continue_locked)


func test_ending_entry_and_restart_clear_records_without_health_switch_changes() -> void:
	var game := _live_game()
	game._skip_meal()
	game._finish_run("collapsed")
	assert_true(game.daily_summary.record_book_button.visible)
	game._show_meal_record_book()
	assert_eq(game._record_book.return_button.text, "回到结局")
	game._record_book._select_week()
	assert_eq(game._record_book._book["last_day"], 1)
	game._record_book.close_book()
	game.start_new_run()
	assert_eq(game.get_meal_record_book()["days"][0]["eaten"], 0)
	assert_eq(game.get_meal_record_book()["days"][0]["skipped"], 0)
	for flag in ["data", "engine", "ui", "weekly"]:
		assert_false(bool(game.health_guidance_flags[flag]))


func _record(phase: String, ids: Array, source: String = "cafeteria") -> Dictionary:
	var foods: Array[Dictionary] = []
	for id in ids:
		foods.append(Data.get_food(id))
	return Resolver.build_record(phase, Data.get_meal_source(source), foods)


func _live_game(hide_new_day: bool = true) -> GameRootV2:
	var game := GameScene.instantiate() as GameRootV2
	track(game)
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	if hide_new_day:
		game.new_day_popup.hide_popup(false)
	return game


func _state(game: GameRootV2) -> Dictionary:
	return {"day": game.day, "phase": game.phase, "state": game.state.duplicate(true), "hand": game.hand.duplicate(), "selected": game.selected_food_ids.duplicate(), "stock": game.dorm_inventory.duplicate(true), "records": game.today_meal_records.duplicate(true), "history": game.run_history.duplicate(true), "source_hands": game.source_hands.duplicate(true), "rng": game._deck_service._rng.state}


func _assert_no_nutrition(value: Variant) -> void:
	if value is Dictionary:
		for key in value:
			assert_false(key in ["quality", "score", "rating", "nutrition_score", "health_score", "health_snapshot", "ingredients", "guidance", "factor_snapshot"])
			_assert_no_nutrition(value[key])
	elif value is Array:
		for row in value:
			_assert_no_nutrition(row)
