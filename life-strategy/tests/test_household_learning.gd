@tool
extends McpTestSuite

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Flow := preload("res://scripts/stories/HouseholdLearningFlow.gd")
const Presenter := preload("res://scripts/stories/HouseholdLearningPresenter.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")


func suite_name() -> String:
	return "household_learning"


func _game(story: String = "choir_week") -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.story_id = story
	game.health_history_path = ""
	game._deck_service = Deck.new(42)
	game.start_new_run()
	return game


func _scene(size: Vector2i = Vector2i(1920, 1080)) -> GameRootV2:
	var viewport := SubViewport.new()
	viewport.size = size
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	Session.request("choir_week")
	var game := Scene.instantiate() as GameRootV2
	game.health_history_path = ""
	viewport.add_child(game)
	var callback := Callable(game, "_apply_responsive_profile")
	if viewport.size_changed.is_connected(callback): viewport.size_changed.disconnect(callback)
	game._mobile_mode = size.y > size.x
	game._apply_shell_profile()
	return game


func _opening(game: GameRootV2, discard: bool = false) -> void:
	game.new_day_popup.continue_button.pressed.emit()
	assert_eq(game.household_learning["opening_stage"], "decision")
	game._story_dialog._buttons.get_node("discard" if discard else "back").pressed.emit()
	assert_eq(game.household_learning["opening_stage"], "breakfast")


func test_opening_is_a_real_choice_without_spending_or_forcing_disposal() -> void:
	var game := _scene()
	var before := game.state.duplicate(true)
	var ingredients := game.kitchen.ingredients.duplicate(true)
	game.new_day_popup.continue_button.pressed.emit()
	assert_true(game._story_dialog.visible)
	assert_contains(game._story_dialog._body.text, "常温12小时")
	assert_contains(game._story_dialog._body.text, "闻着正常")
	game._choose_meal_source("home_kitchen")
	game._skip_meal()
	assert_eq(game.phase, "breakfast_source")
	game._story_dialog._buttons.get_node("back").pressed.emit()
	assert_eq(game.household_learning["opening_choice"], "leave")
	assert_eq(game.kitchen.batches[0]["quantity"], 1)
	assert_eq(game.kitchen.available("greens", 1), 0)
	assert_true(game.kitchen.history.is_empty())
	assert_eq(game.state, before)
	assert_eq(game.kitchen.ingredients, ingredients)
	assert_true(game.today_meal_records.is_empty())


func test_discard_and_stale_confirm_only_record_one_disposal() -> void:
	var game := _scene()
	game.new_day_popup.continue_button.pressed.emit()
	var stale: Button = game._story_dialog._buttons.get_node("discard")
	stale.pressed.emit()
	stale.pressed.emit()
	assert_eq(game.kitchen.history.size(), 1)
	assert_eq(game.kitchen.batches[0]["quantity"], 0)
	assert_eq(game.household_learning["opening_choice"], "discard")
	assert_eq(game.state["balance"], 210)
	assert_false(Presenter.resolve_opening(game, "discard"))


func test_breakfast_links_use_the_live_menu_and_do_not_select_or_pay() -> void:
	var game := _scene()
	_opening(game)
	var before := game.state.duplicate(true)
	var ingredients := game.kitchen.ingredients.duplicate(true)
	var menu: Array = game.source_hands["breakfast:breakfast_shop"].duplicate()
	var options := Presenter.breakfast_choices(game)
	assert_eq(options.size(), 3)
	assert_contains(options[1]["text"], "¥2")
	game._story_dialog._buttons.get_node("breakfast_shop").pressed.emit()
	assert_eq(game.phase, "breakfast")
	assert_eq(game.hand, menu)
	assert_true(game.selected_food_ids.is_empty())
	assert_true(game.today_meal_records.is_empty())
	assert_eq(game.state, before)
	assert_eq(game.kitchen.ingredients, ingredients)
	game._change_meal_source()
	Presenter.resume(game)
	assert_false(game._story_dialog.visible)
	assert_eq(game.household_learning["opening_stage"], "done")


func test_breakfast_options_are_filtered_by_stock_and_budget() -> void:
	var game := _game()
	game.state["balance"] = 0
	for key in game.kitchen.ingredients: game.kitchen.ingredients[key] = 0
	assert_true(Presenter.breakfast_choices(game).is_empty())
	game.kitchen.ingredients["egg"] = 1
	var options := Presenter.breakfast_choices(game)
	assert_eq(options.size(), 1)
	assert_eq(options[0]["id"], "home_kitchen")
	assert_contains(options[0]["text"], "鸡蛋可做1份")
	assert_eq(game.kitchen.ingredients["egg"], 1)
	assert_eq(game.phase, "breakfast_source")


func test_pending_decision_and_breakfast_resume_from_encoded_saves() -> void:
	for stage in ["decision", "breakfast", "done"]:
		var previous := _game()
		previous.household_learning["opening_stage"] = "decision"
		if stage != "decision": assert_true(Presenter.resolve_opening(previous, "discard"))
		if stage == "done": previous.household_learning["opening_stage"] = "done"
		var encoded := Codec.encode(previous.capture_game_save())
		assert_true(encoded["ok"], str(encoded))
		var restored := _scene()
		assert_true(restored.restore_game_save(Codec.decode(encoded["text"])["save"])["ok"])
		assert_eq(restored.household_learning["opening_stage"], stage)
		assert_eq(restored.kitchen.history.size(), 0 if stage == "decision" else 1)
		assert_eq(is_instance_valid(restored._story_dialog) and restored._story_dialog.visible, stage != "done")
		if stage == "breakfast": assert_contains(restored._story_dialog._title.text, "早餐")


func test_legacy_saves_stay_valid_without_fabricating_or_replaying_choices() -> void:
	for id in ["campus_exam", "choir_week"]:
		var previous := _game(id)
		var old := previous.capture_game_save()
		old["payload"].erase("household_learning")
		var checked := Codec.validate(Codec.normalize(old))
		assert_true(checked["ok"], str(checked))
		assert_false(old["payload"].has("household_learning"))
		assert_true(previous.restore_game_save(checked["save"])["ok"])
		if id == "choir_week":
			assert_eq(previous.household_learning, Flow.legacy_state())
			var restored := _scene()
			assert_true(restored.restore_game_save(checked["save"])["ok"])
			assert_false(is_instance_valid(restored._story_dialog) and restored._story_dialog.visible)
		else: assert_true(previous.household_learning.is_empty())


func test_invalid_learning_progress_cannot_mutate_a_running_game() -> void:
	var game := _game()
	var before := game.capture_game_save()
	for invalid in [{}, {"version": 1, "opening_stage": "done", "opening_choice": ""}, {"version": 1, "opening_stage": "decision", "opening_choice": "discard"}, {"version": 2, "opening_stage": "pending", "opening_choice": ""}]:
		var forged := before.duplicate(true)
		forged["payload"]["household_learning"] = invalid
		assert_false(game.restore_game_save(forged)["ok"])
		assert_eq(game.household_learning, before["payload"]["household_learning"])
		assert_eq(game.kitchen.history, before["payload"]["kitchen"]["history"])


func test_preparation_notice_requires_real_safe_unconsumed_food_at_a_later_meal() -> void:
	var game := _game()
	var foods := game._story_food_catalog()
	assert_eq(Flow.preparation_notice(game.kitchen, foods, 1, 37, 1), "")
	game._choose_meal_source("home_kitchen")
	assert_true(game.confirm_household_food(["rice_plain", "egg"], "fridge"))
	assert_eq(Flow.preparation_notice(game.kitchen, foods, 1, 32, 1), "")
	assert_contains(Flow.preparation_notice(game.kitchen, foods, 1, 37, 1), "白米饭")
	assert_contains(Flow.preparation_notice(game.kitchen, foods, 1, 37, 1), "白米饭×1")
	assert_contains(Flow.preparation_notice(game.kitchen, foods, 1, 37, 3), "耗3精力")
	var saved := Codec.encode(game.capture_game_save())
	assert_true(saved["ok"])
	assert_true(game.restore_game_save(Codec.decode(saved["text"])["save"])["ok"])
	game._skip_action()
	game._choose_meal_source("home_fridge")
	assert_true(game.confirm_household_food(["rice_plain", "egg"]))
	assert_eq(Flow.preparation_notice(game.kitchen, foods, 1, 42, 1), "")
	assert_false(game.kitchen.consume(["rice_plain", "egg"], 1, 42)["ok"])


func test_unknown_expired_and_counter_batches_never_generate_a_reheat_notice() -> void:
	var game := _game()
	var foods := game._story_food_catalog()
	assert_true(game.kitchen.cook(["tofu"], foods, 1, "counter", 32)["ok"])
	assert_eq(Flow.preparation_notice(game.kitchen, foods, 1, 37, 1), "")
	assert_true(game.kitchen.cook(["egg"], foods, 1, "fridge", 32)["ok"])
	assert_eq(Flow.preparation_notice(game.kitchen, foods, 5, 128, 1), "")
	game.kitchen.batches.back().erase("fridge_max_c")
	assert_eq(Flow.preparation_notice(game.kitchen, foods, 1, 37, 1), "")


func test_recap_uses_real_disposal_and_reheat_records_without_crediting_ready_milk() -> void:
	var game := _game()
	game.household_learning["opening_stage"] = "decision"
	assert_true(Presenter.resolve_opening(game, "leave"))
	var left := Flow.day_recap(game.kitchen, game.household_learning, 1, 42)
	assert_contains(left["text"], "暂未处理")
	assert_eq(left["opening_discarded"], 0)
	assert_true(game.kitchen.discard(Flow.OPENING_BATCH, 1))
	assert_true(game.kitchen.cook(["tofu"], game._story_food_catalog(), 1, "fridge", 32)["ok"])
	assert_true(game.kitchen.consume(["tofu", "milk"], 1, 37)["ok"])
	assert_true(game.kitchen.consume(["milk"], 1, 42)["ok"])
	var recap := Flow.day_recap(game.kitchen, game.household_learning, 1, 42)
	assert_eq(recap["cooked"], 1)
	assert_eq(recap["prepared"], 1)
	assert_eq(recap["reheated_meals"], 1)
	assert_eq(recap["opening_discarded"], 1)
	assert_false(recap["text"].contains("暂未处理"))
	assert_contains(recap["text"], "开局前")
	assert_eq(Flow.day_recap(game.kitchen, game.household_learning, 2, 66)["opening_discarded"], 0)


func test_day_recap_is_frozen_in_the_summary_and_saved_history() -> void:
	var game := _game()
	game._choose_meal_source("home_kitchen")
	assert_true(game.confirm_household_food(["rice_plain", "egg"], "fridge"))
	game._skip_action()
	game._choose_meal_source("home_fridge")
	assert_true(game.confirm_household_food(["rice_plain", "egg"]))
	game._skip_action()
	game._skip_meal()
	game._skip_action()
	game._choose_sleep("sleep_early")
	var recap: Dictionary = game.run_history[0]["household_recap"].duplicate(true)
	assert_eq(recap["reheated_meals"], 1)
	assert_eq(game.summary_payload["record_summary"], recap["text"])
	assert_true(Codec.encode(game.capture_game_save())["ok"])
	game.kitchen.history.clear()
	assert_eq(game.run_history[0]["household_recap"], recap)
	assert_eq(game.summary_payload["record_summary"], recap["text"])


func test_campus_is_isolated_and_restart_clears_learning_choices() -> void:
	var game := _game("campus_exam")
	assert_true(game.household_learning.is_empty())
	assert_false(Presenter.resolve_opening(game, "discard"))
	game.story_id = "choir_week"
	game.start_new_run()
	game.household_learning["opening_stage"] = "decision"
	assert_true(Presenter.resolve_opening(game, "discard"))
	game.start_new_run()
	assert_eq(game.household_learning, Flow.initial_state())
	assert_eq(game.kitchen.batches[0]["quantity"], 1)
	assert_true(game.kitchen.history.is_empty())


func test_new_player_copy_has_all_chinese_glyphs_in_the_bundled_body_font() -> void:
	var missing := ""
	for path in ["res://scripts/stories/HouseholdLearningFlow.gd", "res://scripts/stories/HouseholdLearningPresenter.gd"]:
		for character in FileAccess.get_file_as_string(path):
			var code := character.unicode_at(0)
			if code >= 0x3400 and code <= 0x9fff and not HouseholdUI.BODY_FONT.has_char(code) and not missing.contains(character): missing += character
	assert_eq(missing, "", "Missing player-copy glyphs: " + missing)


func test_saved_disposal_choice_must_match_the_actual_batch_history() -> void:
	var game := _game()
	var forged := game.capture_game_save()
	forged["payload"]["household_learning"] = {"version": 1, "opening_stage": "done", "opening_choice": "discard"}
	assert_false(Codec.encode(forged)["ok"])
	game.household_learning["opening_stage"] = "decision"
	assert_true(Presenter.resolve_opening(game, "discard"))
	var saved := game.capture_game_save()
	assert_true(Codec.encode(saved)["ok"])
	saved["payload"]["kitchen"]["history"].clear()
	assert_false(Codec.encode(saved)["ok"])


func test_preparation_note_with_long_names_stays_clear_of_home_controls() -> void:
	for size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _scene(size)
		game.new_day_popup.hide_popup(false)
		game._new_day_pending = false
		game._choose_meal_source("home_kitchen")
		game.hand.assign(["soft_tofu_greens", "steamed_fish", "soft_apple"])
		assert_true(game.confirm_household_food(game.hand.duplicate(), "fridge"))
		game._skip_action()
		var stage := game._active_stage as HouseholdSourceStage
		_layout(game)
		stage._refresh_map_layout()
		_layout(stage)
		var note := stage.preparation_note.get_global_rect()
		assert_true(stage.get_global_rect().encloses(note), "%s stage=%s note=%s" % [size, stage.get_global_rect(), note])
		assert_true(note.encloses(stage._preparation_text.get_global_rect()), "Preparation text escaped at %s" % size)
		assert_false(note.intersects(stage.footer.get_global_rect()), "Preparation note overlaps footer at %s" % size)
		for id in HouseholdSourceStage.HOME_ORDER:
			assert_false(note.intersects(stage.find_child(id, true, false).get_global_rect()), "Preparation note overlaps %s at %s" % [id, size])


func _layout(node: Node) -> void:
	if node is Container: node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children(): _layout(child)
