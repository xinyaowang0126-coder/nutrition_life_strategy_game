@tool
extends McpTestSuite

const Game := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")


func suite_name() -> String:
	return "shared_card_flow"


func _game(story_id: String) -> GameRootV2:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	Session.request(story_id)
	var game := Game.instantiate() as GameRootV2
	game.health_history_path = ""
	viewport.add_child(game)
	game.new_day_popup.hide_popup(false)
	game._new_day_pending = false
	game._deck_service.set_seed(20261015)
	game._render_phase()
	return game


func _select_source(game: GameRootV2, source: String) -> MealStageBaseV2:
	game.phase = "lunch_source" if source in ["takeout", "community_canteen"] else "breakfast_source"
	game._render_phase()
	game._choose_meal_source(source)
	return game._active_stage as MealStageBaseV2


func test_all_sources_use_removable_selected_cards_without_spending() -> void:
	for story in ["campus_exam", "choir_week"]:
		var game := _game(story)
		var sources := ["cafeteria", "takeout", "convenience_store", "dorm_storage"] if story == "campus_exam" else ["home_kitchen", "community_canteen", "local_market", "home_fridge", "breakfast_shop"]
		for source: String in sources:
			var stage := _select_source(game, source)
			var before := {"state": game.state.duplicate(true), "pantry": game.kitchen.ingredients.duplicate(true), "dorm": game.dorm_inventory.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true)}
			var id := String(game.hand[0])
			stage._on_card_selected(id)
			var card := stage._get_slot_nodes()[0] as SelectedFoodCardV2
			assert_true(card != null, story + "/" + source + " must use the shared card scene")
			assert_eq(card.item_id, id)
			assert_true(card.face.visible and card.preview.texture != null)
			var remove := card.remove_button
			remove.pressed.emit()
			remove.pressed.emit()
			assert_true(game.selected_food_ids.is_empty(), source + " repeated stale signal must not remove another item or re-add food")
			assert_true(stage._get_confirm_button().disabled)
			assert_eq(game.state, before["state"])
			assert_eq(game.kitchen.ingredients, before["pantry"])
			assert_eq(game.dorm_inventory, before["dorm"])
			assert_eq(game.kitchen.condiments, before["condiments"])
			assert_true(game.today_meal_records.is_empty())
			for scroll: ScrollContainer in stage.find_children("*", "ScrollContainer", true, false):
				assert_true(scroll.follow_focus)


func test_persistent_campus_slot_does_not_remove_the_next_food_twice() -> void:
	var game := _game("campus_exam")
	var stage := _select_source(game, "cafeteria")
	var ids: Array[String] = [game.hand[0], game.hand[1]]
	for id in ids: stage._on_card_selected(id)
	var slot := stage._get_slot_nodes()[0] as SelectedFoodCardV2
	slot.remove_button.pressed.emit()
	slot.remove_button.pressed.emit()
	assert_eq(game.selected_food_ids, [ids[1]])
	assert_eq(slot.item_id, ids[1])
	assert_true(slot.face.visible)
	assert_true(game.today_meal_records.is_empty())


func test_recipe_and_stock_cards_use_badges_without_inventing_cash_prices() -> void:
	var game := _game("choir_week")
	for source in ["home_kitchen", "home_fridge", "local_market"]:
		var stage := _select_source(game, source)
		stage._on_card_selected(game.hand[0])
		var card := stage._get_slot_nodes()[0] as SelectedFoodCardV2
		if source == "home_kitchen": assert_eq(card.price_label.text, "菜谱")
		elif source == "home_fridge": assert_eq(card.price_label.text, "库存")
		else: assert_true(card.price_label.text.begins_with("¥"))


func test_both_stories_keep_action_and_sleep_cards_with_focus_scrolling() -> void:
	for story in ["campus_exam", "choir_week"]:
		var game := _game(story)
		game.phase = "breakfast_action"
		game._render_phase()
		var actions := game._active_stage as ActionStageV2
		assert_true(actions.action_scroll.follow_focus)
		assert_gt(actions._cards_by_id.size(), 0)
		for card in actions._cards_by_id.values(): assert_true(card is CompactChoiceCardV2)
		game.phase = "sleep"
		game._render_phase()
		var sleep := game._active_stage as SleepStageV2
		assert_true(sleep.sleep_scroll.follow_focus)
		assert_eq(sleep._cards_by_id.size(), 3)
		for card in sleep._cards_by_id.values(): assert_true(card is CompactChoiceCardV2)


func test_both_stories_hide_and_clear_old_toasts_during_summary_and_ending() -> void:
	for story in ["campus_exam", "choir_week"]:
		var game := _game(story)
		for meal in range(3):
			game._skip_meal()
			game._skip_action()
		game._choose_sleep("sleep_early")
		assert_eq(game.phase, "summary")
		assert_false(game.toast_anchor.visible)
		assert_true(game.toast_feed._active.is_empty())
		game._on_summary_advanced()
		assert_true(game.new_day_popup.visible)
		assert_false(game.toast_anchor.visible)
		game.new_day_popup.continue_button.pressed.emit()
		assert_eq(game.toast_anchor.visible, story == "campus_exam")
		assert_true(game.toast_feed._active.is_empty())
		game._post("测试中的旧时段反馈。")
		game._finish_run("stable_endurance")
		assert_false(game.toast_anchor.visible)
		assert_true(game.toast_feed._active.is_empty())


func test_record_overlay_rejects_a_late_removal_without_changing_selection() -> void:
	var game := _game("campus_exam")
	var stage := _select_source(game, "cafeteria")
	var id := String(game.hand[0])
	stage._on_card_selected(id)
	var slot := stage._get_slot_nodes()[0] as SelectedFoodCardV2
	game._show_meal_record_book()
	slot.remove_button.pressed.emit()
	assert_eq(game.selected_food_ids, [id])
	assert_eq(stage.get_selected_ids(), [id])
	assert_eq(game.get_viewport().gui_get_focus_owner(), game._record_book.close_button)
	assert_true(game.today_meal_records.is_empty())


func test_current_summary_errors_remain_visible_after_old_feedback_is_cleared() -> void:
	for story in ["campus_exam", "choir_week"]:
		var game := _game(story)
		for meal in range(3):
			game._skip_meal()
			game._skip_action()
		game._choose_sleep("sleep_early")
		assert_false(game.toast_anchor.visible)
		game._post("测试中的恢复记录需要重试。", "warning")
		assert_true(game.toast_anchor.visible)
		assert_eq(game.toast_feed._active.size(), 1)
