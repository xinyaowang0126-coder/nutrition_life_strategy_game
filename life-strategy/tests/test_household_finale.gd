@tool
extends McpTestSuite

const Finale := preload("res://scripts/stories/HouseholdFinale.gd")
const Presenter := preload("res://scripts/stories/HouseholdFinalePresenter.gd")
const Study := preload("res://scripts/stories/HouseholdMealLearning.gd")
const Prep := preload("res://scripts/stories/HouseholdPreparation.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")


func suite_name() -> String:
	return "household_finale"


func _game(target: int = 7, rehearsals: bool = true) -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.story_id = "choir_week"
	game.health_history_path = ""
	game._deck_service = Deck.new(42)
	game.start_new_run()
	for previous in range(1, target):
		for meal in ["breakfast", "lunch", "dinner"]:
			game._choose_meal_source("breakfast_shop" if meal == "breakfast" else "community_canteen")
			var ids: Array[String] = []
			for id in ["steamed_bun", "millet_porridge", "rice_plain", "oatmeal", "egg", "tofu", "steamed_egg", "soft_tofu_greens", "milk", "greens", "tomato", "banana", "apple"]:
				game.selected_food_ids = ids.duplicate()
				if game.hand.has(id) and game._can_add_food(id): ids.append(id)
				if ids.size() == 2: break
			assert_true(game.confirm_household_food(ids))
			if rehearsals and meal == "breakfast" and game.state["energy"] >= 35: game._apply_action("rehearse")
			elif rehearsals and meal == "lunch" and previous in [3, 5] and game.state["energy"] >= 30: game._apply_action("group_rehearsal")
			else: game._apply_action("nap")
		game._choose_sleep("sleep_early")
		game._on_summary_advanced()
	assert_eq(game.day, target)
	return game


func _scene(save: Dictionary = {}, size: Vector2i = Vector2i(1920, 1080)) -> GameRootV2:
	var stored := _game().capture_game_save() if save.is_empty() else save
	var viewport := SubViewport.new()
	viewport.size = size
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	assert_true(Session.request_saved(stored))
	var game := Scene.instantiate() as GameRootV2
	game.health_history_path = ""
	viewport.add_child(game)
	var callback := Callable(game, "_apply_responsive_profile")
	if viewport.size_changed.is_connected(callback): viewport.size_changed.disconnect(callback)
	game._mobile_mode = size.y > size.x
	game._apply_shell_profile()
	return game

func _meal(game: GameRootV2, ids: Array, source: String = "home_kitchen", storage: String = "eat_now") -> bool:
	game._choose_meal_source(source)
	# A declared real-catalog hand isolates specific preparation facts.
	game.hand.assign(ids)
	game.selected_food_ids.assign(ids)
	return game.confirm_household_food(ids, storage)

func _resources(game: GameRootV2) -> Dictionary:
	return {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "batches": game.kitchen.batches.duplicate(true), "meals": game.today_meal_records.duplicate(true), "history": game.shared_meal.history.duplicate(true)}

func _layout(node: Node) -> void:
	for pass_index in range(7): _sort(node)

func _sort(node: Node) -> void:
	if node is Container: node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children(): _sort(child)
	if node is Label: node.get_line_count()
	if node is Control: node.update_minimum_size()
	if node is Container and node.get_parent() is Control and not node.get_parent() is Container:
		var control := node as Control
		var parent_size := control.get_parent_area_size()
		control.set_size(Vector2(parent_size.x * (control.anchor_right - control.anchor_left) + control.offset_right - control.offset_left, parent_size.y * (control.anchor_bottom - control.anchor_top) + control.offset_bottom - control.offset_top))


func _intro(game: GameRootV2, look: bool = false) -> void:
	game._story_dialog._buttons.get_node("look" if look else "back").pressed.emit()


func _ack(game: GameRootV2) -> void:
	game._story_dialog._buttons.get_node("close").pressed.emit()


func _dinner(game: GameRootV2) -> void:
	for meal in ["breakfast", "lunch", "dinner"]:
		assert_true(_meal(game, ["rice_plain", "egg"]))
		if meal != "dinner": game._apply_action("nap")
	assert_eq(game.phase, "dinner_action")


func test_intro_uses_actual_state_without_arranging_or_performing() -> void:
	var game := _scene()
	var before := _resources(game)
	assert_contains(game._story_dialog._body.text, "晚饭后")
	_intro(game, true)
	assert_eq(game._workspace.name, "FinalePlan")
	assert_eq(_resources(game), before)
	assert_false(game.performed)
	assert_true(game.household_finale["outcome"].is_empty())
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_cooking_plan_returns_raw_sugar_and_storage_without_settling() -> void:
	var game := _scene()
	_intro(game)
	game._choose_meal_source("home_kitchen")
	game.hand.assign(["rice_plain", "soft_apple"])
	game.selected_food_ids.assign(["rice_plain", "soft_apple"])
	game._show_cooking_choice(game.selected_food_ids, "fridge", {"seasoning": "none", "added_sugar_g": 4})
	var before := _resources(game)
	game._workspace.learning_button.pressed.emit()
	game._workspace.close_button.pressed.emit()
	assert_eq(game._workspace.plan, {"seasoning": "none", "added_sugar_g": 4})
	assert_eq(game._workspace.storage, "fridge")
	assert_eq(_resources(game), before)


func test_action_planner_can_execute_one_real_rehearsal() -> void:
	var game := _scene(_game(7, false).capture_game_save())
	_intro(game)
	assert_true(_meal(game, ["rice_plain", "egg"]))
	assert_true(game._active_stage.finale_button.visible)
	var before := _resources(game)
	game._active_stage.finale_button.pressed.emit()
	assert_eq(_resources(game), before)
	game._workspace.find_child("rehearse", true, false).pressed.emit()
	assert_eq(game.phase, "lunch_source")
	assert_eq(game.today_action_records.size(), 1)
	assert_eq(game.today_action_records[0]["id"], "rehearse")
	assert_gt(game.state["goal_progress"], 0)
	assert_false(game.performed)
	assert_true(game.household_finale["outcome"].is_empty())


func test_perform_before_the_dinner_window_is_rejected_without_outcome() -> void:
	var game := _game()
	assert_true(_meal(game, ["rice_plain", "egg"]))
	var before := _resources(game)
	game._apply_action("perform")
	assert_eq(_resources(game), before)
	assert_true(game.household_finale["outcome"].is_empty())


func test_actual_performance_freezes_before_cost_and_reply_does_not_repeat_it() -> void:
	var game := _scene()
	_intro(game)
	_dinner(game)
	var energy: int = game.state["energy"]
	assert_true(game._can_use_action(game._story_action("perform")))
	game._apply_action("perform")
	assert_eq(game.phase, "sleep")
	assert_true(game.performed)
	assert_eq(game.household_finale["outcome"]["kind"], "performed")
	assert_eq(game.household_finale["outcome"]["energy"], energy)
	assert_eq(game.today_period_records.back()["finale_context"], game.household_finale["outcome"])
	assert_contains(game._story_dialog._body.text, "最后一句唱完")
	var before := _resources(game)
	var button: Button = game._story_dialog._buttons.get_node("close")
	button.pressed.emit()
	button.pressed.emit()
	game._apply_action("perform")
	assert_eq(_resources(game), before)
	assert_true(game.household_finale["acknowledged"])
	assert_false(game.household_finale["pending"])
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_unprepared_skip_records_the_actual_gap_without_inventing_motives() -> void:
	var game := _scene(_game(7, false).capture_game_save())
	_intro(game)
	_dinner(game)
	game._skip_action()
	assert_eq(game.household_finale["outcome"]["kind"], "unready")
	assert_contains(game.household_finale["outcome"]["reason"], "排练0/70")
	assert_false(game.performed)
	assert_false(game._story_dialog._body.text.contains("最后一句唱完"))
	assert_false(game._story_dialog._body.text.contains("害怕"))
	_ack(game)
	game._choose_sleep("sleep_early")
	assert_contains(game.household_finale["review"]["outcome_text"], "排练0/70")


func test_low_energy_snapshot_does_not_turn_into_a_post_sleep_reason() -> void:
	var game := _scene()
	_intro(game)
	_dinner(game)
	# Declared boundary fixture; not a balance or legal-route claim.
	game.state["energy"] = 24
	game._skip_action()
	assert_contains(game.household_finale["outcome"]["reason"], "演前精力24")
	_ack(game)
	game._choose_sleep("sleep_early")
	assert_contains(game.household_finale["review"]["outcome_text"], "演前精力24")
	assert_eq(game.household_finale["outcome"]["energy"], 24)


func test_ready_person_can_choose_rest_and_is_not_reported_as_unprepared() -> void:
	var game := _scene()
	_intro(game)
	_dinner(game)
	assert_true(game._can_use_action(game._story_action("perform")))
	game._apply_action("nap")
	assert_eq(game.household_finale["outcome"]["kind"], "other_choice")
	assert_eq(game.household_finale["outcome"]["trigger"], "nap")
	assert_contains(game.household_finale["outcome"]["reason"], "参演条件已满足")
	assert_false(game.performed)
	_ack(game)
	game._choose_sleep("sleep_early")
	assert_eq(game.daily_summary._summary["title"], "这一周，按自己的安排")


func test_slot_limit_and_multiple_missing_conditions_are_kept_separate() -> void:
	var row := Finale.outcome(20, 12, 3, "skip", 70, 25, 3)
	assert_eq(row["kind"], "unready")
	for text in ["排练20/70", "精力12", "安排位已用完"]: assert_contains(row["reason"], text)


func test_pending_reply_restores_from_json_without_replaying_performance() -> void:
	var game := _scene()
	_intro(game)
	_dinner(game)
	game._apply_action("perform")
	var encoded := Codec.encode(game.capture_game_save())
	assert_true(encoded["ok"], str(encoded))
	var restored := _scene(Codec.decode(encoded["text"])["save"])
	var before := _resources(restored)
	assert_true(restored.household_finale["pending"])
	assert_contains(restored._story_dialog._body.text, "最后一句唱完")
	_ack(restored)
	assert_eq(_resources(restored), before)
	assert_eq(restored.today_action_records.filter(func(row: Dictionary) -> bool: return row["id"] == "perform").size(), 1)


func test_intro_and_active_planner_restore_without_extra_actions() -> void:
	var game := _scene()
	var restored := _scene(Codec.decode(Codec.encode(game.capture_game_save())["text"])["save"])
	assert_true(restored._story_dialog.visible)
	_intro(restored, true)
	var active := _scene(Codec.decode(Codec.encode(restored.capture_game_save())["text"])["save"])
	assert_eq(active._workspace.name, "FinalePlan")
	var before := _resources(active)
	active._workspace.close_button.pressed.emit()
	assert_eq(_resources(active), before)


func test_legacy_missing_state_does_not_replay_or_invent_a_reason() -> void:
	var save := _game().capture_game_save()
	save["payload"].erase("household_finale")
	var decoded := Codec.decode(JSON.stringify(save))
	assert_true(decoded["ok"])
	var game := _scene(decoded["save"])
	assert_eq(game.household_finale, Finale.initial_state(true))
	assert_false(is_instance_valid(game._story_dialog) and game._story_dialog.visible)
	assert_true(game.household_finale["outcome"].is_empty())


func test_forged_reply_and_performance_context_are_rejected_transactionally() -> void:
	var game := _scene()
	_intro(game)
	_dinner(game)
	game._apply_action("perform")
	var original := game.capture_game_save()
	for field in ["reason", "energy", "period", "performance"]:
		var forged := original.duplicate(true)
		if field == "reason": forged["payload"]["household_finale"]["outcome"]["reason"] = "invented"
		elif field == "energy": forged["payload"]["household_finale"]["outcome"]["energy"] = 0
		elif field == "period": forged["payload"]["today_period_records"].back().erase("finale_context")
		else: forged["payload"]["performed"] = false
		assert_false(game.restore_game_save(forged)["ok"])
		assert_eq(game.household_finale, original["payload"]["household_finale"])
		assert_eq(game.state, original["payload"]["state"])


func test_frozen_week_review_and_counts_restore_without_recalculation_effects() -> void:
	var game := _scene()
	_intro(game)
	_dinner(game)
	game._apply_action("perform")
	_ack(game)
	game._choose_sleep("sleep_early")
	assert_eq(game.phase, "ending")
	var review: Dictionary = game.household_finale["review"].duplicate(true)
	assert_eq(review["counts"]["days"], 7)
	assert_eq(review["counts"]["meals"], 21)
	assert_eq(review["counts"]["performances"], 1)
	assert_eq(game.daily_summary.ending_image.texture.resource_path, "res://assets/generated/stories/actions/zhou_perform-v1.png")
	assert_eq(game.daily_summary.record_kicker.text, "本周小记")
	assert_eq(game.daily_summary.advice_kicker.text, "下次")
	var encoded := Codec.encode(game.capture_game_save())
	assert_true(encoded["ok"], str(encoded))
	var restored := _scene(Codec.decode(encoded["text"])["save"])
	assert_eq(restored.household_finale["review"], review)
	var before := _resources(restored)
	restored._show_ending_summary()
	assert_eq(_resources(restored), before)
	assert_eq(restored.household_finale["review"], review)
	var forged := restored.capture_game_save()
	forged["payload"]["household_finale"]["review"]["counts"]["performances"] = 99
	assert_false(restored.restore_game_save(forged)["ok"])
	assert_eq(restored.household_finale["review"], review)


func test_first_wrong_retry_and_help_are_not_reported_as_independent_success() -> void:
	var p := _game().capture_game_save()["payload"] as Dictionary
	var journal := Study.initial_state()
	var foods := _game()._story_food_catalog()
	var c := Study.context(2, "breakfast", "home_kitchen", ["rice_plain", "egg"], foods)
	assert_true(Study.begin(journal, c, {"kind": "selection", "day": 2, "meal": "breakfast", "source": "home_kitchen", "ids": ["rice_plain", "egg"], "storage": "eat_now", "plan": {}}))
	assert_true(Study.answer(journal, "enough"))
	assert_true(Study.retry(journal))
	assert_true(Study.answer(journal, "known"))
	Study.close(journal)
	c = Study.context(4, "breakfast", "home_kitchen", ["rice_plain", "soft_apple"], foods)
	assert_true(Study.begin(journal, c, {}))
	assert_true(Study.explain(journal))
	assert_true(Study.retry(journal))
	assert_true(Study.answer(journal, Study.question(c)["correct"]))
	p["household_lessons"] = journal
	var counts: Dictionary = Finale.review(p)["counts"]
	assert_eq(counts["first_wrong"], 1)
	assert_eq(counts["first_correct"], 0)
	assert_eq(counts["first_after_help"], 1)
	assert_eq(counts["attempted_contexts"], 2)


func test_cold_counter_and_pantry_records_are_separate_in_week_review() -> void:
	var game := _game(6)
	assert_true(_meal(game, ["rice_plain", "milk"], "home_kitchen", "fridge"))
	game._apply_action("nap")
	assert_true(_meal(game, ["rice_plain", "milk"], "home_fridge"))
	game._apply_action("nap")
	assert_true(_meal(game, ["egg"], "home_kitchen", "counter"))
	game._apply_action("nap")
	game._choose_sleep("sleep_early")
	game._on_summary_advanced()
	var review := Finale.review(game.capture_game_save()["payload"])
	assert_eq(review["counts"]["prepared_items"], 2)
	assert_eq(review["counts"]["counter_items"], 1)
	assert_eq(review["counts"]["reheated_items"], 1)
	assert_contains(review["highlights"][4]["text"], "不算可用冷藏备餐")


func test_invitation_alone_is_not_counted_as_shared_dining() -> void:
	var game := _game(6)
	for meal in ["breakfast", "lunch"]:
		assert_true(_meal(game, ["rice_plain", "egg"]))
		if meal == "breakfast": game._apply_action("nap")
	assert_true(game.plan_shared_meal("home"))
	game._apply_action("nap")
	assert_true(_meal(game, ["rice_plain", "egg"], "community_canteen"))
	game._apply_action("nap")
	game._choose_sleep("sleep_early")
	game._on_summary_advanced()
	assert_eq(Finale.review(game.capture_game_save()["payload"])["counts"]["shared"], 0)


func test_skipped_meal_is_not_a_nutritional_success_or_an_eaten_meal() -> void:
	var game := _game()
	game._skip_meal()
	game._apply_action("nap")
	for meal in ["lunch", "dinner"]:
		assert_true(_meal(game, ["rice_plain", "egg"]))
		game._apply_action("nap")
	game._choose_sleep("sleep_early")
	var review: Dictionary = game.household_finale["review"]
	assert_eq(review["counts"]["meals"], 20)
	assert_eq(review["counts"]["skipped"], 1)
	assert_contains(review["next_step"], "先为三餐留出安排")
	assert_false(Finale.review_text(review).contains("营养合格"))


func test_early_collapse_does_not_invent_day_seven_or_performance() -> void:
	var game := _game(1, false)
	for ignored_day in range(1, 8):
		for meal in ["breakfast", "lunch", "dinner"]:
			game._skip_meal()
			game._skip_action()
		game._choose_sleep("scroll_phone")
		if game.phase == "ending": break
		game._on_summary_advanced()
	assert_eq(game.phase, "ending")
	assert_true(game.day < 7)
	assert_eq(game.household_finale["review"]["counts"]["performances"], 0)
	assert_eq(game.household_finale["review"]["counts"]["days"], game.run_history.size())
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_campus_and_new_run_have_no_finale_progress_or_extra_button() -> void:
	var game := _scene()
	_intro(game)
	game.story_id = "campus_exam"
	game.start_new_run()
	assert_true(game.household_finale.is_empty())
	assert_false(Presenter.resume(game))
	game._skip_meal()
	assert_false(game._active_stage.finale_button.visible)
	game.daily_summary.show_summary({"layout": "ending", "day": 7}, false)
	assert_eq(game.daily_summary.record_kicker.text, "本周小记")
	assert_eq(game.daily_summary.advice_kicker.text, "下次")
	game.daily_summary.show_summary({"day": 1}, false)
	assert_eq(game.daily_summary.record_kicker.text, "今日小记")
	assert_eq(game.daily_summary.advice_kicker.text, "明天")
	game.story_id = "choir_week"
	game.start_new_run()
	assert_eq(game.household_finale, Finale.initial_state())


func test_three_layout_sizes_keep_plan_controls_and_action_entry_visible() -> void:
	for size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _scene({}, size)
		_intro(game, true)
		_layout(game)
		assert_true(game.get_viewport_rect().encloses(game._workspace.paper_panel.get_global_rect()))
		assert_true(game._workspace.paper_panel.get_global_rect().encloses(game._workspace.footer.get_global_rect()))
		game._workspace.close_button.pressed.emit()
		assert_true(_meal(game, ["rice_plain", "egg"]))
		_layout(game)
		assert_true(game.get_viewport_rect().encloses(game._active_stage.finale_button.get_global_rect()))
		assert_false(game._active_stage.finale_button.get_global_rect().intersects(game._active_stage.skip_button.get_global_rect()))


func test_all_finale_copy_glyphs_are_bundled() -> void:
	var missing := ""
	for path in ["res://scripts/stories/HouseholdFinale.gd", "res://scripts/stories/HouseholdFinalePresenter.gd"]:
		for character in FileAccess.get_file_as_string(path):
			var code := character.unicode_at(0)
			if code >= 0x3400 and code <= 0x9fff and not HouseholdUI.BODY_FONT.has_char(code) and not missing.contains(character): missing += character
	assert_eq(missing, "", "Missing finale glyphs: " + missing)


func test_day_six_take_reply_finishes_before_opening_day_seven_preflight() -> void:
	var model := _game(6)
	for meal in ["breakfast", "lunch"]:
		assert_true(_meal(model, ["rice_plain", "egg"]))
		model._apply_action("nap")
	assert_true(Prep.choose(model.household_preparation, "dinner", "stock", model.kitchen.batches, model._story_clock()))
	assert_true(_meal(model, ["rice_plain", "soft_tofu_greens"], "home_kitchen", "fridge"))
	model._apply_action("nap")
	model._choose_sleep("sleep_early")
	model._on_summary_advanced()
	var game := _scene(model.capture_game_save())
	_intro(game)
	assert_true(_meal(game, ["rice_plain", "soft_tofu_greens"], "home_fridge"))
	assert_eq(game.household_preparation["pending"], "dinner")
	assert_false(Presenter.open_plan(game))
	game._story_dialog._buttons.get_node("close").pressed.emit()
	game._active_stage.finale_button.pressed.emit()
	assert_eq(game._workspace.name, "FinalePlan")
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_legacy_performed_flag_without_action_record_does_not_invent_success() -> void:
	var game := _scene()
	_intro(game)
	_dinner(game)
	# Declared old-format compatibility fixture: no stored decision context.
	game._advance_after_action()
	game.household_finale = Finale.initial_state(true)
	game.performed = true
	game._choose_sleep("sleep_early")
	assert_eq(game.household_finale["review"]["counts"]["performances"], 0)
	assert_contains(game.household_finale["review"]["outcome_text"], "原因保持未知")
	assert_eq(game.daily_summary._summary["title"], "这一周，按实际记录回看")
	assert_contains(game.daily_summary._summary["advice"], "实际参演：未记录")
	assert_true(Codec.encode(game.capture_game_save())["ok"])
