@tool
extends McpTestSuite

const Day := preload("res://scripts/stories/HouseholdDayFive.gd")
const Presenter := preload("res://scripts/stories/HouseholdDayFivePresenter.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")


func suite_name() -> String:
	return "household_day_five"


func _game(target: int = 5) -> GameRootV2:
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
			for id in game.hand:
				game.selected_food_ids = ids.duplicate()
				if game._can_add_food(id): ids.append(id)
				if ids.size() == 2: break
			assert_true(game.confirm_household_food(ids))
			game._apply_action("nap")
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


func _intro(game: GameRootV2, look: bool = false) -> void:
	assert_true(game._story_dialog.visible)
	game._story_dialog._buttons.get_node("look" if look else "back").pressed.emit()


func _ack(game: GameRootV2) -> void:
	if is_instance_valid(game._story_dialog) and game._story_dialog.visible: game._story_dialog._buttons.get_node("close").pressed.emit()


func _meal(game: GameRootV2, ids: Array, source: String = "home_kitchen", storage: String = "eat_now") -> bool:
	game._choose_meal_source(source)
	# A declared real-catalog hand isolates specific preparation facts.
	game.hand.assign(ids)
	game.selected_food_ids.assign(ids)
	return game.confirm_household_food(ids, storage)


func _resources(game: GameRootV2) -> Dictionary:
	return {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "batches": game.kitchen.batches.duplicate(true), "meals": game.today_meal_records.duplicate(true), "history": game.shared_meal.history.duplicate(true)}


func _to_lunch_action(game: GameRootV2) -> void:
	assert_true(_meal(game, ["rice_plain", "soft_apple"]))
	_ack(game)
	game._skip_action()
	assert_true(_meal(game, ["rice_plain", "steamed_egg"]))
	_ack(game)
	assert_eq(game.phase, "lunch_action")


func test_day_five_need_and_own_arrangement_are_choices_without_resources_or_meals() -> void:
	var game := _scene()
	var before := _resources(game)
	assert_contains(game._story_dialog._body.text, "硬苹果嚼着费劲")
	assert_contains(game._story_dialog._body.text, "按自己的口味")
	_intro(game)
	assert_eq(game.household_day_five["intent"], "own")
	assert_false(game._story_dialog.visible)
	assert_eq(_resources(game), before)
	assert_true(game.shared_meal.plan.is_empty())
	assert_true(game.household_day_five["acknowledged"].is_empty())


func test_looking_at_sources_does_not_select_food_or_claim_adaptation() -> void:
	var game := _scene()
	var before := _resources(game)
	_intro(game, true)
	assert_eq(game._workspace.name, "DayFiveGuide")
	assert_eq(game.household_day_five["intent"], "look")
	game._workspace.find_child("home_kitchen", true, false).pressed.emit()
	assert_eq(game.phase, "breakfast")
	assert_true(game.selected_food_ids.is_empty())
	assert_eq(_resources(game), before)
	assert_true(game.household_day_five["active"].is_empty())


func test_cooking_guide_preserves_draft_and_does_not_serve_the_preview() -> void:
	var game := _scene()
	_intro(game)
	game._choose_meal_source("home_kitchen")
	game.hand.assign(["soft_apple", "steamed_egg"])
	game.selected_food_ids.assign(["soft_apple", "steamed_egg"])
	game._show_cooking_choice(game.selected_food_ids, "fridge", {"seasoning": "none", "added_sugar_g": 4})
	var before := _resources(game)
	game._workspace.learning_button.pressed.emit()
	assert_eq(game._workspace.name, "DayFiveGuide")
	game._workspace.close_button.pressed.emit()
	assert_true(game._workspace is CookingPlanStage)
	assert_eq(game._workspace.plan, {"seasoning": "none", "added_sugar_g": 4})
	assert_eq(game._workspace.storage, "fridge")
	assert_eq(_resources(game), before)
	assert_true(game.today_meal_records.is_empty())


func test_confirmed_soft_food_gets_a_frozen_personal_response_not_a_health_reward() -> void:
	var game := _scene()
	_intro(game)
	assert_true(_meal(game, ["rice_plain", "soft_apple"]))
	assert_eq(game.phase, "breakfast_action")
	var experience: Dictionary = game.today_meal_records[0]["day_five_experience"].duplicate(true)
	assert_contains(experience["response"], "煮软苹果")
	assert_contains(experience["response"], "顺口")
	assert_false(experience["shared"])
	assert_eq(game.household_day_five["pending"], "breakfast")
	var before := _resources(game)
	var stale: Button = game._story_dialog._buttons.get_node("close")
	stale.pressed.emit()
	stale.pressed.emit()
	assert_eq(game.household_day_five["acknowledged"], ["breakfast"])
	assert_eq(_resources(game), before)
	game.kitchen.history[0]["recipe_facts"]["recipes"][1]["method"] = "changed"
	assert_eq(game.today_meal_records[0]["day_five_experience"], experience)


func test_regular_food_and_missing_preparation_are_not_reported_as_adapted() -> void:
	var game := _game()
	assert_true(_meal(game, ["rice_plain", "egg"]))
	var first: Dictionary = game.today_meal_records[0]["day_five_experience"]
	assert_false(first["methods"].any(func(row: Dictionary) -> bool: return Day.is_adapted(row)))
	assert_false(first["response"].contains("老陈"))
	game._skip_action()
	assert_true(_meal(game, ["soft_apple"], "home_kitchen", "fridge"))
	game._skip_action()
	game.kitchen.batches.back()["recipe_facts"]["recipes"][0].erase("method")
	assert_true(_meal(game, ["soft_apple"], "home_fridge"))
	var unknown: Dictionary = game.today_meal_records.back()["day_five_experience"]
	assert_eq(unknown["methods"][0]["basis"], "unrecorded")
	assert_false(Day.is_adapted(unknown["methods"][0]))
	var recap := Day.recap(game.today_meal_records, game.household_day_five, game.shared_meal.history)
	assert_eq(recap["unrecorded_methods"], 1)
	assert_contains(recap["text"], "部分做法未记录")
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_cancelled_invitation_is_not_an_invitation_or_a_meal_and_can_change_later() -> void:
	var game := _scene()
	_intro(game)
	_to_lunch_action(game)
	var before := _resources(game)
	game._apply_action("call_friend")
	game._workspace.close_button.pressed.emit()
	assert_true(game.household_day_five["invite_declined"])
	assert_true(game.shared_meal.plan.is_empty())
	assert_eq(game.actions_used_today, 0)
	assert_eq(_resources(game), before)
	assert_true(game.plan_shared_meal("community"))
	assert_eq(game.shared_meal.plan["status"], "planned")
	assert_eq(game.household_day_five["pending"], "invitation")


func test_friend_accepts_the_plan_once_before_any_actual_shared_dinner() -> void:
	var game := _scene()
	_intro(game)
	_to_lunch_action(game)
	var before := game.state.duplicate(true)
	assert_true(game.plan_shared_meal("home"))
	assert_contains(game._story_dialog._body.text, "今晚去你家")
	assert_eq(game.shared_meal.history.size(), 1)
	assert_eq(game.shared_meal.plan["status"], "planned")
	assert_false(game.plan_shared_meal("community"))
	_ack(game)
	assert_eq(game.state, before)
	assert_eq(game.actions_used_today, 0)
	assert_false(game.shared_meal.history.any(func(row: Dictionary) -> bool: return row["kind"] == "shared_meal"))


func test_home_shared_dinner_uses_two_portions_and_only_then_gets_both_speakers() -> void:
	var game := _scene()
	_intro(game)
	_to_lunch_action(game)
	assert_true(game.plan_shared_meal("home"))
	_ack(game)
	game._apply_action("group_rehearsal")
	var rice: int = game.kitchen.ingredients["rice_plain"]
	var tofu: int = game.kitchen.ingredients["tofu"]
	assert_true(_meal(game, ["rice_plain", "soft_tofu_greens"]))
	assert_eq(game.kitchen.ingredients["rice_plain"], rice - 2)
	assert_eq(game.kitchen.ingredients["tofu"], tofu - 2)
	var response: Dictionary = game.today_meal_records.back()["day_five_experience"]
	assert_true(response["shared"])
	assert_eq(response["venue"], "home")
	assert_contains(response["response"], "老陈")
	assert_eq(game.shared_meal.plan["status"], "completed")
	assert_false(game.confirm_household_food(["rice_plain", "soft_tofu_greens"]))
	_ack(game)
	game._skip_action()
	game._choose_sleep("sleep_early")
	assert_true(game.run_history.back()["day_five_recap"]["shared"])
	assert_contains(game.summary_payload["record_summary"], "在家和老陈同桌")


func test_community_dinner_pays_own_food_and_does_not_consume_home_ingredients() -> void:
	var game := _game()
	_to_lunch_action(game)
	assert_true(game.plan_shared_meal("community"))
	game._skip_action()
	var before := game.kitchen.ingredients.duplicate(true)
	var balance: int = game.state["balance"]
	assert_true(_meal(game, ["rice_plain", "soft_tofu_greens"], "community_canteen"))
	assert_eq(game.kitchen.ingredients, before)
	assert_eq(game.state["balance"], balance - 8)
	assert_true(game.today_meal_records.back()["day_five_experience"]["shared"])
	assert_eq(game.today_meal_records.back()["day_five_experience"]["venue"], "community")


func test_changed_venue_and_skipped_dinner_never_gain_a_shared_meal() -> void:
	for skipped in [false, true]:
		var game := _game()
		_to_lunch_action(game)
		assert_true(game.plan_shared_meal("community"))
		game._skip_action()
		if skipped: game._skip_meal()
		else: assert_true(_meal(game, ["rice_plain", "egg"]))
		game._skip_action()
		game._choose_sleep("sleep_early")
		var recap: Dictionary = game.run_history.back()["day_five_recap"]
		assert_false(recap["shared"])
		assert_true(recap["missed"])
		assert_contains(recap["text"], "没吃" if skipped else "改选家里做饭")
		if skipped: assert_false(game.today_meal_records.back().has("day_five_experience"))


func test_intro_guide_and_response_resume_from_json_without_new_effects() -> void:
	var intro := _scene()
	var pending := Codec.encode(intro.capture_game_save())
	assert_true(pending["ok"], str(pending))
	var restored := _scene(Codec.decode(pending["text"])["save"])
	assert_contains(restored._story_dialog._body.text, "硬苹果")
	_intro(restored, true)
	var guide := Codec.encode(restored.capture_game_save())
	assert_true(guide["ok"], str(guide))
	var guide_restored := _scene(Codec.decode(guide["text"])["save"])
	assert_eq(guide_restored._workspace.name, "DayFiveGuide")
	guide_restored._workspace.close_button.pressed.emit()
	assert_true(_meal(guide_restored, ["rice_plain", "soft_apple"]))
	var before := _resources(guide_restored)
	var response := Codec.encode(guide_restored.capture_game_save())
	assert_true(response["ok"], str(response))
	var meal_restored := _scene(Codec.decode(response["text"])["save"])
	assert_eq(meal_restored.household_day_five["pending"], "breakfast")
	assert_eq(_resources(meal_restored), before)
	_ack(meal_restored)
	assert_eq(_resources(meal_restored), before)
	assert_true(Codec.encode(meal_restored.capture_game_save())["ok"])


func test_legacy_saves_do_not_replay_or_fabricate_a_conversation() -> void:
	var original := _game().capture_game_save()
	original["payload"].erase("household_day_five")
	var decoded := Codec.decode(JSON.stringify(original))
	assert_true(decoded["ok"], str(decoded))
	assert_false(original["payload"].has("household_day_five"))
	var game := _scene(decoded["save"])
	assert_eq(game.household_day_five, Day.initial_state(true))
	assert_false(is_instance_valid(game._story_dialog) and game._story_dialog.visible)
	assert_true(game.today_meal_records.is_empty())


func test_invalid_pending_ack_and_false_companionship_cannot_mutate_the_run() -> void:
	var game := _scene()
	_intro(game)
	assert_true(_meal(game, ["rice_plain", "steamed_egg"]))
	var original := game.capture_game_save()
	var forged := original.duplicate(true)
	forged["payload"]["household_day_five"]["pending"] = "dinner"
	assert_false(game.restore_game_save(forged)["ok"])
	assert_eq(game.household_day_five, original["payload"]["household_day_five"])
	forged = original.duplicate(true)
	forged["payload"]["today_meal_records"][0]["day_five_experience"]["shared"] = true
	assert_false(game.restore_game_save(forged)["ok"])
	assert_eq(game.today_meal_records, original["payload"]["today_meal_records"])
	forged = original.duplicate(true)
	forged["payload"]["household_day_five"]["acknowledged"] = ["dinner"]
	assert_false(game.restore_game_save(forged)["ok"])


func test_campus_and_restart_are_isolated_from_day_five_progress() -> void:
	var game := _scene()
	_intro(game)
	game.household_day_five["invite_declined"] = true
	game.story_id = "campus_exam"
	game.start_new_run()
	assert_true(game.household_day_five.is_empty())
	assert_false(Presenter.resume(game))
	game.story_id = "choir_week"
	game.start_new_run()
	assert_eq(game.household_day_five, Day.initial_state())


func test_new_personal_copy_has_all_bundled_glyphs() -> void:
	var missing := ""
	for path in ["res://scripts/stories/HouseholdDayFive.gd", "res://scripts/stories/HouseholdDayFivePresenter.gd"]:
		for character in FileAccess.get_file_as_string(path):
			var code := character.unicode_at(0)
			if code >= 0x3400 and code <= 0x9fff and not HouseholdUI.BODY_FONT.has_char(code) and not missing.contains(character): missing += character
	assert_eq(missing, "", "Missing day-five glyphs: " + missing)


func test_prior_day_shared_meal_is_not_rewritten_as_a_day_five_invitation() -> void:
	var model := _game(4)
	_to_lunch_action(model)
	assert_true(model.plan_shared_meal("home"))
	model._skip_action()
	assert_true(_meal(model, ["rice_plain", "soft_tofu_greens"]))
	model._skip_action()
	model._choose_sleep("sleep_early")
	model._on_summary_advanced()
	var game := _scene(model.capture_game_save())
	assert_contains(game._story_dialog._body.text, "第4天")
	assert_false(game._story_dialog._body.text.contains("午后想问问"))
	_intro(game)
	_to_lunch_action(game)
	assert_false(game.plan_shared_meal("home"))
	assert_false(game._story_dialog.visible)
	assert_eq(game.shared_meal.plan["day"], 4)


func test_record_page_can_review_the_frozen_personal_response() -> void:
	var game := _scene()
	_intro(game)
	assert_true(_meal(game, ["rice_plain", "soft_apple"]))
	_ack(game)
	game._skip_action()
	game._show_recipe_records()
	var found := false
	for label: Label in game._workspace.find_children("*", "Label", true, false):
		if label.text.contains("我吃着顺口"): found = true
	assert_true(found)
	assert_eq(game.household_day_five["acknowledged"], ["breakfast"])


func test_day_five_guide_and_reply_layouts_keep_controls_in_portrait_and_desktop() -> void:
	for size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _scene({}, size)
		_intro(game, true)
		_layout(game)
		var page := game._workspace
		assert_true(game.get_viewport_rect().encloses(page.paper_panel.get_global_rect()))
		assert_true(page.paper_panel.get_global_rect().encloses(page.footer.get_global_rect()))
		assert_true(page.scroll.get_global_rect().end.y <= page.footer.get_global_rect().position.y)
		page.close_button.pressed.emit()
		assert_true(_meal(game, ["rice_plain", "soft_apple"]))
		_layout(game)
		assert_true(game.get_viewport_rect().encloses(game._story_dialog._panel.get_global_rect()))
		assert_true(game._story_dialog._panel.get_global_rect().encloses(game._story_dialog._buttons.get_global_rect()))


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
