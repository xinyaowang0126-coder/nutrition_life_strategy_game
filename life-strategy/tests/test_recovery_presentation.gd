@tool
extends McpTestSuite

const Presenter := preload("res://scripts/systems/RecoveryPresenter.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Data := preload("res://scripts/GameData.gd")
const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")
const NoteScene := preload("res://scenes/game_v2/components/StickyNotePopup.tscn")


func suite_name() -> String:
	return "recovery_presentation"


func test_new_run_has_no_fictional_prior_sleep_or_recovery_bonus() -> void:
	var view := Presenter.present(Recovery.new_run())
	assert_true(view["available"])
	assert_eq(view["title"], "起步状态")
	assert_contains(view["summary"], "还没有昨夜")
	assert_false(view["effect_text"].contains("+3"))
	assert_false(view["detail_text"].contains("精力 0"))


func test_four_conditions_have_factual_reasons_and_frozen_effects() -> void:
	var titles := {"rested": "恢复充分", "steady": "状态照常", "strained": "有些疲惫", "depleted": "需要缓缓"}
	for condition in titles:
		var record := _record(condition)
		var view := Presenter.present(record)
		assert_true(view["available"])
		assert_eq(view["title"], titles[condition])
		assert_contains(view["detail_text"], "游戏规则")
		assert_contains(view["detail_text"], "判断依据")
		assert_contains(view["effect_text"], "今天")
		for internal_id in record["reason_ids"]:
			assert_false(view["detail_text"].contains(internal_id))


func test_phone_is_a_fact_without_a_guaranteed_penalty() -> void:
	var view := Presenter.present(_record("steady"))
	assert_contains(view["summary"], "恢复仍看实际精力")
	assert_contains(view["effect_text"], "复习收益不变")


func test_early_sleep_does_not_override_severe_end_state() -> void:
	var view := Presenter.present(_settle("sleep_early", {"energy": 0, "stress": 95}))
	assert_eq(view["title"], "需要缓缓")
	assert_contains(view["summary"], "虽然早点睡了")


func test_trace_separates_sleep_other_effects_and_clamp() -> void:
	var record := _settle("sleep_early", {"energy": 95, "stress": 15}, [{"source_id": "high_satiety", "requested_delta": {"energy": -3}}])
	var view := Presenter.present(record, "settled")
	assert_contains(view["detail_text"], "精力 95 → 117 → 100")
	assert_contains(view["detail_text"], "高饱腹日终效果：精力 -3")
	assert_contains(view["detail_text"], "这次调整：精力 -14")
	assert_contains(view["effect_text"], "明天每次复习收益 +3")


func test_presentation_does_not_evaluate_or_mutate_frozen_history() -> void:
	var record := _record("steady")
	# Validation permits historical outcomes without evaluating rules again.
	record["condition"] = "rested"
	record["reason_ids"] = ["EARLY_SLEEP_READY"]
	record["matched_rule_ids"] = ["EARLY_SLEEP_READY"]
	record["next_day_effect"] = {"study_modifier": 3, "opening_delta": {"energy": 3, "mood": 1, "stress": -2}}
	var original := record.duplicate(true)
	var view := Presenter.present(record)
	assert_eq(view["title"], "恢复充分")
	assert_eq(record, original)
	view["title"] = "changed"
	assert_eq(Presenter.present(record)["title"], "恢复充分")


func test_legacy_invalid_and_future_records_never_show_neutral_effects() -> void:
	for status in ["legacy_unknown", "invalid", "unsupported_version"]:
		var view := Presenter.present(Recovery.unavailable(status, "test"))
		assert_false(view["available"])
		assert_false(view["effect_text"].contains("不变"))
		assert_false(view["title"] == "状态照常")
	var future := _record("steady")
	future["schema_version"] = 2
	assert_contains(Presenter.present(future)["title"], "版本")
	assert_false(Presenter.present({"diet_burden": 0})["available"])


func test_final_day_has_no_promise_of_unused_opening_effects() -> void:
	var view := Presenter.present(_record("rested"), "final")
	assert_contains(view["effect_text"], "不再应用")
	assert_false(view["effect_text"].contains("+3"))
	assert_false(view["detail_text"].contains("明天"))


func test_ending_narrative_counts_only_executed_meals_and_sleep() -> void:
	var history := [{"day": 1, "sleep": {"id": "sleep_early"}, "meals": [{"phase": "breakfast", "skipped": false, "food_names": ["白米饭"]}, {"phase": "lunch", "skipped": false, "food_names": ["面包"]}, {"phase": "dinner", "skipped": false, "food_names": ["方便面"]}]}]
	var view := Presenter.ending_text("barely_survived", history)
	assert_contains(view, "3 餐")
	assert_false(view.contains("晚继续复习"))
	assert_false(view.contains("跳过了"))
	assert_false(view.contains("熬了"))
	assert_false(view.contains("交卷"))
	history[0]["meals"][1]["skipped"] = true
	history[0]["meals"][1]["food_names"] = []
	history[0]["sleep"]["id"] = "night_study"
	view = Presenter.ending_text("barely_survived", history)
	assert_contains(view, "2 餐")
	assert_contains(view, "跳过了 1 餐")
	assert_contains(view, "1 晚继续复习")


func test_hud_and_new_day_use_consumed_record_not_mutable_display_aliases() -> void:
	var game := _game()
	game.day = 2
	game.run_history.append({"day": 1, "recovery_state": _record("rested")})
	assert_true(game._start_day())
	game.current_learning_state["title"] = "假标题"
	game.current_recovery_state["condition"] = "depleted"
	game._render_phase()
	game._show_new_day_popup()
	assert_contains(game.character_hud.recovery_value.text, "恢复充分")
	assert_eq(game.new_day_popup.status_title.text, "恢复充分")
	assert_contains(game.new_day_popup.status_effect.text, "+3")
	assert_false(game._effective_action("study")["rule_hint"].contains("假标题"))


func test_reopening_recovery_details_cannot_reapply_effects_or_change_inventory() -> void:
	var game := _game()
	var before := game.state.duplicate(true)
	var stock := game.dorm_inventory.duplicate(true)
	var history := game.run_history.duplicate(true)
	for repeat in range(3):
		game._show_recovery_detail()
		assert_true(game.sticky_note.pinned)
		assert_true(game.new_day_popup.continue_button.disabled)
		game.sticky_note._on_close_pressed()
		assert_false(game.new_day_popup.continue_button.disabled)
		game._show_new_day_popup()
	assert_eq(game.state, before)
	assert_eq(game.dorm_inventory, stock)
	assert_eq(game.run_history, history)


func test_state_detail_shows_absolute_values_and_card_effects_show_deltas() -> void:
	var note = NoteScene.instantiate()
	track(note)
	(Engine.get_main_loop() as SceneTree).root.add_child(note)
	note.setup({"name": "当前状态", "energy": 50}, "state")
	assert_eq(note.energy_metric.text, "精力 50")
	note.setup({"name": "行动", "energy": 5}, "action")
	assert_eq(note.energy_metric.text, "精力 +5")
	assert_eq(note.metric_heading.text, "游戏即时效果")
	assert_false(note.description_label.text.contains("健康评价"))


func test_sleep_details_do_not_predict_a_condition_before_settlement() -> void:
	var game := _game()
	game._show_detail(Data.get_sleep_option("sleep_early"), Rect2(0, 0, 10, 10), true, "sleep")
	assert_false(game.sticky_note.recovery_section.visible)
	assert_contains(game.sticky_note.description_label.text, "收工后")
	assert_false(game.sticky_note.description_label.text.contains("必定"))


func test_week_recap_reads_recovery_records_instead_of_legacy_aliases() -> void:
	var game := _game()
	game.day = 7
	game.run_history.append({"day": 7, "recovery_state": Recovery.unavailable("legacy_unknown", "LEGACY_RECOVERY_NOT_RECORDED"), "next_learning_state": {"title": "状态平稳", "id": "steady"}})
	var recap := game._build_week_recap()
	assert_contains(recap["detail_text"], "这段历史没有恢复记录")
	assert_false(recap["detail_text"].contains("次日 状态平稳"))


func _record(condition: String) -> Dictionary:
	var sleep_id: String = {"rested": "sleep_early", "steady": "scroll_phone", "strained": "night_study", "depleted": "night_study"}[condition]
	var before: Dictionary = {"rested": {"energy": 45, "stress": 45}, "steady": {"energy": 70, "stress": 42}, "strained": {"energy": 90, "stress": 20}, "depleted": {"energy": 15, "stress": 85}}[condition]
	return _settle(sleep_id, before)


func _settle(sleep_id: String, before: Dictionary, effects: Array = []) -> Dictionary:
	var sleep := Data.get_sleep_option(sleep_id)
	var snapshot := {"id": sleep_id}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		snapshot[key] = sleep[key]
	return Recovery.settle(1, before, snapshot, {}, effects)["recovery_state"]


func _game() -> GameRootV2:
	var game := GameScene.instantiate() as GameRootV2
	track(game)
	game.health_history_path = ""
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	return game
