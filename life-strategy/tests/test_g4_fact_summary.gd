@tool
extends McpTestSuite

const Ledger := preload("res://scripts/systems/NutritionLedger.gd")
const Records := preload("res://scripts/systems/MealRecordPresenter.gd")
const PopupScene := preload("res://scenes/game_v2/components/DailySummaryPopup.tscn")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const LegacyController := preload("res://scripts/GameRoot.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Gameplay := preload("res://scripts/systems/RecoveryGameplayService.gd")
const RecoveryCopy := preload("res://scripts/systems/RecoveryPresenter.gd")


func suite_name() -> String:
	return "g4_fact_summary"


func test_legacy_scores_and_tags_cannot_change_any_daily_output() -> void:
	var records: Array[Dictionary] = [_meal("breakfast")]
	var before := records.duplicate(true)
	var expected := Ledger.summarize(records)
	for value in [0, 100, "旧营养评级", ["坏评分"], {"score": 100}]:
		var poisoned: Array[Dictionary] = records.duplicate(true)
		poisoned[0].merge({"quality": value, "score": value, "rating": value, "food_groups": 100, "nutrient_tags": null, "limit_tags": {"high_sodium": true}, "health_snapshot": {"score": 100}}, true)
		assert_eq(Ledger.summarize(poisoned), expected)
	assert_eq(records, before)
	_assert_no_old_metrics(expected)


func test_duplicate_fact_delivery_is_one_meal_even_with_different_legacy_scores() -> void:
	var first := _meal("breakfast")
	var duplicate := first.duplicate(true)
	duplicate["quality"] = 100
	duplicate["nutrient_tags"] = ["calcium_source"]
	var view := Ledger.summarize([first, duplicate])
	assert_eq(view["metrics"]["eaten_meals"], 1)
	assert_eq(view["metrics"]["unknown_meals"], 0)
	assert_eq(view["metrics"]["unrecorded_meals"], 2)
	assert_false(view["observation"].contains("三顿都吃"))


func test_conflicting_meal_facts_are_unknown_in_both_summary_and_book() -> void:
	var first := _meal("breakfast")
	var conflict := first.duplicate(true)
	conflict["total_cost"] = 99
	var view := Ledger.summarize([first, conflict])
	var book := Records.capture([], [first, conflict], 1)
	assert_eq(view["metrics"]["eaten_meals"], book["days"][0]["eaten"])
	assert_eq(view["metrics"]["eaten_meals"], 0)
	assert_eq(view["metrics"]["unknown_meals"], 1)
	assert_contains(view["detail_text"], "记录不一致")
	assert_false(view["detail_text"].contains("¥99"))


func test_missing_skipped_marker_does_not_become_an_eaten_or_skipped_meal() -> void:
	var old := _meal("breakfast")
	old.erase("skipped")
	var view := Ledger.summarize([old])
	assert_eq(view["metrics"]["eaten_meals"], 0)
	assert_eq(view["metrics"]["skipped_meals"], 0)
	assert_eq(view["metrics"]["unknown_meals"], 1)
	assert_eq(view["metrics"]["unrecorded_meals"], 2)
	assert_contains(view["detail_text"], "未记的餐次，不能当成没吃")


func test_malformed_lists_and_skipped_values_keep_unknown_counts() -> void:
	for field in ["food_ids", "food_names"]:
		for value in [null, "白米饭", [42], [""]]:
			var old := _meal("breakfast")
			old[field] = value
			var view := Ledger.summarize([old])
			assert_eq(view["metrics"]["unknown_meals"], 1)
			assert_eq(view["metrics"]["skipped_meals"], 0)
	var old := _meal("breakfast")
	old["skipped"] = "false"
	assert_eq(Ledger.summarize([old])["metrics"]["unknown_meals"], 1)


func test_records_without_meal_phases_remain_visible_as_unplaced() -> void:
	var unplaced := _meal("breakfast")
	unplaced.erase("phase")
	var view := Ledger.summarize([_meal("breakfast"), unplaced, {"quality": 90}])
	assert_eq(view["metrics"]["eaten_meals"], 1)
	assert_eq(view["metrics"]["unplaced_records"], 2)
	assert_contains(view["detail_text"], "2 条旧记录没标餐次")
	assert_contains(view["observation"], "未记清")


func test_details_use_frozen_names_sources_and_cash_or_stock_facts() -> void:
	var cash := _meal("breakfast")
	var stock := _meal("lunch")
	stock.merge({"source_name": "宿舍旧存粮", "uses_stock": true, "total_cost": 0}, true)
	var missing := _meal("dinner")
	missing.erase("food_names")
	missing.erase("source_name")
	missing.erase("total_cost")
	var view := Ledger.summarize([cash, stock, missing])
	assert_contains(view["detail_text"], "早餐｜确认时的食堂｜冻结白米饭｜¥2")
	assert_contains(view["detail_text"], "午餐｜宿舍旧存粮｜冻结白米饭｜使用存粮")
	assert_contains(view["detail_text"], "晚餐｜来源未记｜食物名称未记｜消费未记")
	assert_eq(view["metrics"]["eaten_meals"], 3)


func test_popup_ignores_legacy_quality_and_nutrition_fallback_fields() -> void:
	var popup := _popup()
	for old_value in [95, "旧营养评分 95", [95], {"score": 95}]:
		popup.configure({"quality": old_value, "meal_quality": "旧餐食评级", "nutrition": {"detail_text": "旧营养评级", "basis": "旧评分依据"}})
		assert_eq(popup.record_summary_label.text, "选餐记录暂时不可用。")
		assert_false(popup.detail_button.visible)
		assert_eq(popup.detail_label.text, "")
		assert_false(popup.basis_label.visible)


func test_popup_shows_explicit_facts_without_using_legacy_payload_aliases() -> void:
	var popup := _popup()
	popup.configure({"record_summary": "已记下 1 餐。", "detail": {"detail_text": "早餐｜冻结白米饭｜¥2", "basis": "成分与份量尚未核对。"}, "quality": "旧营养评分", "nutrition": {"detail_text": "旧营养评级"}, "button_text": "继续"})
	assert_eq(popup.record_summary_label.text, "已记下 1 餐。")
	assert_true(popup.detail_button.visible)
	assert_eq(popup.detail_label.text, "早餐｜冻结白米饭｜¥2")
	assert_eq(popup.next_button.text, "继续")


func test_malformed_explicit_popup_fields_return_to_unavailable_text() -> void:
	var popup := _popup()
	for value in [null, 95, [], {}, "", "  "]:
		popup.configure({"record_summary": value, "detail": value})
		assert_eq(popup.record_summary_label.text, "选餐记录暂时不可用。")
		assert_false(popup.detail_button.visible)
	popup.configure({"detail": {"detail_text": 95, "basis": ["旧评分"]}})
	assert_false(popup.detail_button.visible)
	assert_false(popup.basis_label.visible)


func test_v2_settlement_is_independent_of_legacy_meal_score_fields() -> void:
	var baseline = _game(false)
	var poisoned = _game(false)
	_skip_day(baseline, false)
	_skip_day(poisoned, true)
	assert_eq(poisoned.state, baseline.state)
	assert_eq(poisoned.pending_recovery_state, baseline.pending_recovery_state)
	assert_eq(poisoned.summary_payload, baseline.summary_payload)
	assert_eq(poisoned.phase, "summary")
	_assert_no_old_metrics(poisoned.run_history[0]["nutrition"])


func test_v1_settlement_and_text_are_independent_of_legacy_meal_scores() -> void:
	var baseline = _game(true)
	var poisoned = _game(true)
	_skip_day(baseline, false)
	_skip_day(poisoned, true)
	assert_eq(poisoned.state, baseline.state)
	assert_eq(poisoned.pending_recovery_state, baseline.pending_recovery_state)
	assert_eq(poisoned.daily_summary, baseline.daily_summary)
	assert_contains(poisoned.daily_summary, "三顿都没吃")


func test_current_recovery_api_preserves_existing_balance_formula() -> void:
	var game = _game(false)
	_skip_day(game, false)
	for energy in [0, 25, 100]:
		var state: Dictionary = game.state.duplicate(true)
		state["energy"] = energy
		var current := Gameplay.calculate_stability_from_recovery(state, 1, 7, game.pending_recovery_state)
		assert_true(current["valid"])
		for old_score in [0, 25, 100]:
			assert_eq(current, Gameplay.calculate_stability(state, old_score, 1, 7, game.pending_recovery_state))


func test_archived_legacy_nutrition_summary_is_not_an_ending_copy_source() -> void:
	var game = _game(false)
	_skip_day(game, false)
	game.run_history[0]["nutrition"] = {"score": 100, "rating": "旧营养评级", "detail_text": "旧营养评级", "metrics": {"eaten_meals": 99, "expected_meals": 99}}
	game._finish_run("barely_survived")
	assert_false(game.summary_payload["record_summary"].contains("旧营养评级"))
	assert_false(game.summary_payload["detail"]["detail_text"].contains("旧营养评级"))
	var recap: Dictionary = game._build_week_recap()
	assert_contains(recap["detail_text"], "进餐记录 0/3")
	assert_false(recap["detail_text"].contains("99/99"))
	assert_eq(game.get_meal_record_book()["days"][0]["skipped"], 3)
	game.run_history.append({"day": 7, "meals": [_meal("breakfast")]})
	recap = game._build_week_recap()
	assert_eq(recap["played_days"], 1)
	assert_false(recap["detail_text"].contains("第 7 天"))


func test_meal_stamps_share_unknown_conflicts_and_frozen_history_with_the_book() -> void:
	var game = _game(false)
	var original := _meal("breakfast")
	var conflict := original.duplicate(true)
	conflict["total_cost"] = 99
	var old := _meal("lunch")
	old.erase("skipped")
	var records: Array[Dictionary] = [original, conflict, old, {"phase": "dinner", "skipped": true}]
	game.today_meal_records = records
	var stamps: Array = game._build_meal_stamps()
	assert_eq(stamps[0]["state"], "unknown")
	assert_eq(stamps[1]["state"], "unknown")
	assert_eq(stamps[2]["state"], "skipped")
	assert_eq(game.get_meal_record_book()["days"][0]["unknown"], 2)
	game.run_history.append({"day": 1, "meals": [original.duplicate(true)]})
	game.today_meal_records[0]["food_names"] = ["后来改过的名字"]
	stamps = game._build_meal_stamps()
	assert_contains(stamps[0]["text"], "冻结白米饭")
	assert_false(stamps[0]["text"].contains("后来改过"))


func test_ending_counts_ignore_duplicates_and_keep_incomplete_meals_unknown() -> void:
	var old := _meal("lunch")
	old.erase("skipped")
	var settled := {"day": 1, "meals": [_meal("breakfast"), old, {"phase": "dinner", "skipped": true}, {"quality": 99}], "sleep": {"id": "sleep_early"}}
	var history := [settled, settled.duplicate(true)]
	var before := history.duplicate(true)
	var text := RecoveryCopy.ending_text("barely_survived", history)
	assert_contains(text, "这 1 天已确认 1 餐")
	assert_contains(text, "另外跳过了 1 餐")
	assert_contains(text, "未记全，不能当成没吃")
	assert_false(text.contains("这 2 天"))
	assert_eq(history, before)


func _meal(phase: String) -> Dictionary:
	return {"phase": phase, "skipped": false, "food_ids": ["rice_plain"], "food_names": ["冻结白米饭"], "source_name": "确认时的食堂", "uses_stock": false, "total_cost": 2}


func _popup() -> DailySummaryPopupV2:
	var popup := PopupScene.instantiate() as DailySummaryPopupV2
	track(popup)
	(Engine.get_main_loop() as SceneTree).root.add_child(popup)
	return popup


func _game(legacy: bool):
	var game = LegacyController.new() if legacy else Controller.new()
	track(game)
	if not legacy:
		game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
		game.health_history_path = ""
	game._deck_service = Deck.new(42)
	game.start_new_run()
	return game


func _skip_day(game, poison: bool) -> void:
	for phase in ["breakfast", "lunch", "dinner"]:
		game._skip_meal()
		if poison:
			game.today_meal_records.back()["quality"] = {"score": "旧营养评级"}
		game._skip_action()
	game._choose_sleep("sleep_early")


func _assert_no_old_metrics(value: Dictionary) -> void:
	for key in ["score", "rating", "quality", "nutrition_score", "health_score"]:
		assert_false(value.has(key))
	var expected := ["expected_meals", "eaten_meals", "skipped_meals", "unknown_meals", "unrecorded_meals", "unplaced_records"]
	assert_eq(value["metrics"].size(), expected.size())
	for key in expected:
		assert_true(value["metrics"].has(key))
