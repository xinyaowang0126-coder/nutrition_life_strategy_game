@tool
extends McpTestSuite

const Builder := preload("res://scripts/systems/EndingFeedbackBuilder.gd")
const Trace := preload("res://scripts/systems/ActionFeedbackTrace.gd")
const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Screen := preload("res://scenes/game_v2/components/EndingScreen.tscn")
var _owned: Array[Node] = []


func suite_name() -> String:
	return "ending_feedback"


func teardown() -> void:
	for node in _owned:
		if is_instance_valid(node): node.free()
	_owned.clear()


func _model(household: bool = false) -> GameRootV2:
	var game := Controller.new()
	game.story_id = "choir_week" if household else "campus_exam"
	game.health_history_path = ""
	game._deck_service = Deck.new(42)
	game.start_new_run()
	_owned.append(game)
	return game


func _view(game: GameRootV2, id: String) -> Dictionary:
	return Builder.build(game.story, id, game.capture_game_save()["payload"])


func test_student_goal_and_reserve_gaps_have_distinct_responses() -> void:
	var game := _model()
	game.day = 7
	game.state["study_progress"] = 55
	game.state["stability"] = 80
	var goal := _view(game, "barely_survived")
	assert_eq(goal["kind"], "goal_gap")
	assert_contains(goal["summary"], "还差15")
	assert_false(goal["summary"].contains("已经完成"))
	game.state["study_progress"] = 77
	game.state["stability"] = 40
	var reserve := _view(game, "barely_survived")
	assert_eq(reserve["kind"], "reserve_gap")
	assert_contains(reserve["summary"], "已经完成")
	assert_contains(reserve["summary"], "还差20")
	assert_ne(goal["next_try_id"], reserve["next_try_id"])


func test_early_stop_explains_actual_days_without_inventing_a_full_week() -> void:
	var game := _model()
	game.day = 3
	game.low_stability_days = 2
	var view := _view(game, "collapsed")
	assert_contains(view["summary"], "停在第3天")
	assert_contains(view["summary"], "第2、3天")
	assert_false(view["summary"].contains("走完7天"))
	game.day = 7
	game.low_stability_days = 1
	game.state["stability"] = 24
	view = _view(game, "collapsed")
	assert_contains(view["summary"], "余力24")
	assert_false(view["summary"].contains("连续"))


func test_zhou_uses_frozen_preflight_instead_of_sleep_recovery() -> void:
	var game := _model(true)
	game.day = 7
	game.state["energy"] = 100
	game.state["goal_progress"] = 69
	game.household_finale["outcome"] = {"kind": "unready", "progress": 63, "energy": 21, "slots": 3, "trigger": "skip", "reason": ""}
	var view := _view(game, "study_shortfall")
	assert_eq(view["kind"], "unready")
	assert_contains(view["summary"], "排练63/70，还差7")
	assert_contains(view["summary"], "精力21/25，还差4")
	assert_contains(view["summary"], "没有可用安排位")
	assert_eq(view["next_try_id"], "preflight")


func test_actual_performance_and_later_low_reserve_are_both_acknowledged() -> void:
	var game := _model(true)
	game.day = 7
	game.low_stability_days = 2
	game.state["stability"] = 10
	game.run_history.assign([{"day": 7, "actions": [{"id": "perform"}], "meals": []}])
	var view := _view(game, "collapsed")
	assert_eq(view["kind"], "performed")
	assert_eq(view["title"], "把歌唱完了")
	assert_contains(view["summary"], "已参加")
	assert_contains(view["summary"], "提前收束")
	assert_eq(view["next_try_id"], "rest")


func test_ready_other_choice_has_its_own_scene_and_no_invented_motive() -> void:
	var game := _model(true)
	game.day = 7
	game.household_finale["outcome"] = {"kind": "other_choice", "progress": 70, "energy": 25, "slots": 2, "trigger": "nap", "reason": ""}
	game.today_action_records.assign([{"id": "nap", "name": "歇一会儿"}])
	var view := _view(game, "study_shortfall")
	assert_eq(view["kind"], "other_choice")
	assert_contains(view["summary"], "具备参演条件")
	assert_contains(view["summary"], "歇一会儿")
	assert_eq(view["next_try_id"], "own_choice")
	assert_contains(view["image"], "zhou_other_choice")
	assert_false(view["voice"].contains("遗憾"))


func test_legacy_success_flag_alone_does_not_invent_a_performance() -> void:
	var game := _model(true)
	game.day = 7
	game.performed = true
	var view := _view(game, "stable_endurance")
	assert_eq(view["kind"], "legacy")
	assert_eq(view["title"], "这一周，按实际记录回看")
	assert_contains(view["summary"], "没有实际参演记录")
	assert_false(view["image"].contains("zhou_perform"))


func test_action_trace_reports_capped_actual_gain_and_excludes_period_drain() -> void:
	var game := _model()
	game._skip_meal()
	game.state["study_progress"] = 98
	var energy: int = game.state["energy"]
	game._apply_action("study")
	var row: Dictionary = game.today_action_records[0]
	var trace: Dictionary = row["feedback_trace"]
	assert_true(Trace.valid(trace, row, 1, 1, game.current_learning_state))
	assert_eq(trace["actual"]["progress"], 2)
	assert_true(trace["requested"]["progress"] > 2)
	assert_eq(trace["actual"]["energy"], -10)
	assert_eq(game.state["energy"], energy - 10 - 8)
	assert_contains(Trace.receipt(row, "复习"), "+2")


func test_trace_roundtrip_and_forgery_rejection_preserve_current_run() -> void:
	var game := _model()
	game._skip_meal()
	game._apply_action("study")
	var encoded := Codec.encode(game.capture_game_save())
	assert_true(encoded["ok"], str(encoded))
	var decoded := Codec.decode(encoded["text"])
	assert_true(decoded["ok"])
	var restored := _model()
	assert_true(restored.restore_game_save(decoded["save"])["ok"])
	assert_eq(restored.today_action_records, game.today_action_records)
	var original: Dictionary = restored.capture_game_save()["payload"]
	var forged: Dictionary = decoded["save"].duplicate(true)
	forged["payload"]["today_action_records"][0]["feedback_trace"]["actual"]["progress"] += 1
	assert_false(restored.restore_game_save(forged)["ok"])
	assert_eq(restored.capture_game_save()["payload"], original)


func test_historical_trace_is_checked_and_old_records_still_load() -> void:
	var game := _model()
	for meal in ["breakfast", "lunch", "dinner"]:
		game._skip_meal()
		game._apply_action("nap")
	game._choose_sleep("sleep_early")
	var encoded := Codec.encode(game.capture_game_save())
	assert_true(encoded["ok"], str(encoded))
	var forged: Dictionary = encoded["save"].duplicate(true)
	forged["payload"]["run_history"][0]["actions"][0]["feedback_trace"]["sequence"] = 8
	assert_false(Codec.validate(forged)["ok"])
	var legacy: Dictionary = encoded["save"].duplicate(true)
	for row in legacy["payload"]["today_action_records"]: row.erase("feedback_trace")
	for day_record in legacy["payload"]["run_history"]:
		for row in day_record["actions"]: row.erase("feedback_trace")
	assert_true(Codec.validate(legacy)["ok"])


func test_feedback_is_deterministic_readonly_and_does_not_consume_randomness() -> void:
	var game := _model()
	game._skip_meal()
	game._apply_action("study")
	var before: Dictionary = game.capture_game_save()["payload"]
	var first := _view(game, "collapsed")
	assert_eq(_view(game, "collapsed"), first)
	assert_eq(game.capture_game_save()["payload"], before)
	assert_true(first["moments"].size() <= 2)


func test_invitation_and_unopened_pantry_are_not_shared_or_reheated_moments() -> void:
	var game := _model(true)
	game.shared_meal.plan = {"status": "planned", "day": 5}
	game.kitchen.history.append({"action": "reheat_and_eat", "day": 2, "batches": [{"kind": "ready_pantry", "food_id": "milk"}]})
	var view := _view(game, "collapsed")
	assert_true(view["moments"].all(func(moment: Dictionary) -> bool: return moment["category"] not in ["together", "kitchen"]))
	for moment in view["moments"]:
		assert_false(moment["category"] in ["together", "kitchen"])


func _screen() -> EndingScreenV2:
	var screen := Screen.instantiate() as EndingScreenV2
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	_owned.append(screen)
	var game := _model()
	game.state["study_progress"] = 77
	game.state["stability"] = 88
	screen.present(_view(game, "stable_endurance"))
	return screen


func test_review_escape_returns_to_ending_without_restarting() -> void:
	var screen := _screen()
	var events: Array[String] = []
	screen.restart_requested.connect(func() -> void: events.append("restart"))
	screen.review_button.pressed.emit()
	assert_true(screen.review_open)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen._input(escape)
	assert_false(screen.review_open)
	assert_true(screen.visible)
	assert_true(events.is_empty())


func test_modal_blocks_late_restart_and_double_click_only_emits_once() -> void:
	var screen := _screen()
	var events: Array[String] = []
	screen.restart_requested.connect(func() -> void: events.append("restart"))
	screen.set_modal_blocked(true)
	screen.restart_button.pressed.emit()
	assert_true(events.is_empty())
	screen.set_modal_blocked(false)
	screen.restart_button.pressed.emit()
	screen.restart_button.pressed.emit()
	assert_eq(events, ["restart"])


func test_full_review_has_only_one_scroll_container() -> void:
	var screen := _screen()
	screen.open_review()
	assert_eq(_scroll_count(screen), 1)


func test_ending_copy_has_bundled_body_glyphs() -> void:
	var missing := ""
	for path in ["res://scripts/systems/EndingFeedbackBuilder.gd", "res://scripts/ui_v2/EndingFeedbackCopy.gd", "res://scripts/ui_v2/EndingScreen.gd"]:
		for character in FileAccess.get_file_as_string(path):
			var code := character.unicode_at(0)
			if code >= 0x3400 and code <= 0x9fff and not HouseholdUI.BODY_FONT.has_char(code) and not missing.contains(character): missing += character
	assert_eq(missing, "", "Missing ending glyphs: " + missing)


func test_next_try_names_a_day_with_recorded_other_arrangements() -> void:
	var game := _model()
	game.day = 7
	game.state["study_progress"] = 55
	game.state["stability"] = 80
	for day in range(1, 8):
		game.run_history.append({"day": day, "meals": [], "actions": [{"id": "study" if day <= 5 else "nap"}]})
	var view := _view(game, "barely_survived")
	assert_eq(view["next_try_id"], "study_day")
	assert_contains(view["next_try"], "第6天")
	assert_contains(view["next_try"], "餐后复习")
	for row in game.run_history: row["actions"] = []
	view = _view(game, "barely_survived")
	assert_false(view["next_try"].contains("第6天"), "Empty legacy action records cannot establish a missed study date")


func test_after_target_study_surfaces_actual_cost_even_when_progress_is_capped() -> void:
	var game := _model()
	game._skip_meal()
	game.state["study_progress"] = 100
	game._apply_action("study")
	game.state["stability"] = 40
	game.run_history.assign([{"day": 1, "actions": game.today_action_records.duplicate(true), "learning_state": game.current_learning_state.duplicate(true), "meals": []}])
	var view := _view(game, "barely_survived")
	assert_eq(view["moments"].size(), 1)
	assert_contains(view["moments"][0]["title"], "目标到位后")
	assert_contains(view["moments"][0]["text"], "精力-10")
	assert_contains(view["moments"][0]["text"], "没有再增加")
	assert_contains(view["moments"][0]["basis"], "公共消耗另计")
	assert_eq(view["next_try_id"], "rest_day")
	assert_contains(view["next_try"], "把一段复习换成休息")


func test_large_rehearsal_gap_suggests_earlier_practice_instead_of_one_last_session() -> void:
	var game := _model(true)
	game.day = 7
	game.household_finale["outcome"] = {"kind": "unready", "progress": 0, "energy": 80, "slots": 2, "trigger": "skip", "reason": ""}
	var view := _view(game, "study_shortfall")
	assert_eq(view["next_try_id"], "rehearsal_time")
	assert_contains(view["next_try"], "前几天")
	assert_false(view["next_try"].contains("一次补练"))


func test_a_walk_after_the_goal_is_not_mislabeled_as_more_study() -> void:
	var game := _model()
	game._skip_meal()
	game.state["study_progress"] = 100
	game._apply_action("walk")
	game.state["stability"] = 40
	game.run_history.assign([{"day": 1, "actions": game.today_action_records.duplicate(true), "learning_state": game.current_learning_state.duplicate(true), "meals": []}])
	var view := _view(game, "barely_survived")
	assert_eq(view["moments"].size(), 0)
	assert_ne(view["next_try_id"], "rest_day")


func _scroll_count(node: Node) -> int:
	if node.is_queued_for_deletion(): return 0
	var total := 1 if node is ScrollContainer else 0
	for child in node.get_children(): total += _scroll_count(child)
	return total
