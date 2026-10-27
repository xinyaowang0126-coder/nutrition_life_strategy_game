@tool
extends McpTestSuite

const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")


func suite_name() -> String:
	return "household_ui"


func _game(view_size: Vector2i = Vector2i(1920, 1080)) -> GameRootV2:
	var viewport := SubViewport.new()
	viewport.size = view_size
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	Session.request("choir_week")
	var game := Scene.instantiate() as GameRootV2
	game.health_history_path = ""
	viewport.add_child(game)
	var callback := Callable(game, "_apply_responsive_profile")
	if viewport.size_changed.is_connected(callback): viewport.size_changed.disconnect(callback)
	game._mobile_mode = view_size.y > view_size.x
	game._apply_shell_profile()
	game.new_day_popup.hide_popup(false)
	game._render_phase()
	return game


func test_cooking_preview_counts_two_people_plus_saved_portion_without_spending() -> void:
	var game := _game()
	game.day = 4
	game.phase = "lunch_action"
	assert_true(game.plan_shared_meal("home"))
	game._skip_action()
	game._choose_meal_source("home_kitchen")
	game._confirm_food(["rice_plain", "soft_tofu_greens"])
	var page := game._workspace as CookingPlanStage
	var pantry := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	page.option_buttons["storage:fridge"].pressed.emit()
	assert_eq(page.ingredients_needed, {"rice_plain": 3, "tofu": 3, "greens": 3})
	assert_contains(page._portions_label.text, "当餐2人份")
	assert_contains(page._portions_label.text, "共做3份")
	assert_eq(game.kitchen.ingredients, pantry)
	assert_eq(game.kitchen.condiments, condiments)
	page.option_buttons["seasoning:usual"].pressed.emit()
	assert_true(page.option_buttons["seasoning:usual"].button_pressed)
	assert_false(page.option_buttons["seasoning:light"].button_pressed)
	assert_contains(page._sodium_note.text, "1500")
	assert_contains(page._sodium_note.text, "总糖未知")
	assert_contains(page._sodium_note.text, "不是整餐或全天总量")
	assert_eq(game.kitchen.condiments, condiments)
	page.confirm_button.pressed.emit()
	assert_eq(game.phase, "dinner_action")
	assert_eq(game.kitchen.ingredients["tofu"], pantry["tofu"] - 3)
	assert_eq(game.today_meal_records.back()["recipe_facts"]["sodium_from_added_seasonings_mg"], 1500)
	assert_eq(game.shared_meal.plan["status"], "completed")


func test_insufficient_preview_disables_commit_and_cancel_preserves_hand() -> void:
	var game := _game()
	game._choose_meal_source("home_kitchen")
	game.kitchen.ingredients["tofu"] = 1
	game._confirm_food(["soft_tofu_greens"])
	var page := game._workspace as CookingPlanStage
	page.option_buttons["storage:fridge"].pressed.emit()
	assert_true(page.confirm_button.disabled)
	assert_true(page._shortage_note.visible)
	page.confirm_button.pressed.emit()
	assert_eq(game.phase, "breakfast")
	assert_eq(game.kitchen.ingredients["tofu"], 1)
	var hand := game.hand.duplicate()
	page.close_button.pressed.emit()
	assert_eq(game.hand, hand)
	assert_eq(game.selected_food_ids, ["soft_tofu_greens"])
	page.confirm_requested.emit(["soft_tofu_greens"], "eat_now", {"seasoning": "light", "added_sugar_g": 0})
	assert_eq(game.phase, "breakfast")
	assert_true(game.today_meal_records.is_empty())


func test_stock_cards_do_not_allow_unknown_or_unsafe_batches_to_be_eaten() -> void:
	var game := _game()
	game.kitchen.batches.append({"id": "unknown", "food_id": "tofu", "quantity": 1, "status": "history_unknown", "known_history": false, "day": 0, "note": "不知道何时做好和冷藏。"})
	game._show_kitchen()
	var page := game._workspace as KitchenStockStage
	assert_true(page.find_child("before_week_greens", true, false) is Button)
	assert_true(page.find_child("unknown", true, false) is Button)
	var before := game.state.duplicate(true)
	game._skip_meal()
	game._choose_meal_source("home_fridge")
	assert_eq(game.state, before)
	assert_eq(game.phase, "breakfast_source")
	var discard := page.find_child("before_week_greens", true, false) as Button
	discard.pressed.emit()
	discard.pressed.emit()
	assert_eq(game.kitchen.history.size(), 1)
	assert_eq(game.kitchen.batches[0]["quantity"], 0)
	assert_eq(game.state, before)
	page.close_button.pressed.emit()
	game._choose_meal_source("home_fridge")
	assert_false(game.hand.has("tofu"))
	assert_false(game.hand.has("greens"))


func test_worktops_keep_footer_and_hud_visible_at_mobile_and_desktop_sizes() -> void:
	for view_size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _game(view_size)
		game._choose_meal_source("home_kitchen")
		game._confirm_food(["rice_plain", "soft_tofu_greens", "soft_apple"])
		var page := game._workspace as CookingPlanStage
		_layout(game)
		var bounds := game.get_viewport().get_visible_rect()
		assert_true(bounds.encloses(page.paper_panel.get_global_rect()), "paper must stay inside %s: %s" % [view_size, page.paper_panel.get_global_rect()])
		assert_true(page.paper_panel.get_global_rect().encloses(page.confirm_button.get_global_rect()), "confirm must stay inside paper")
		assert_true(bounds.encloses(page.confirm_button.get_global_rect()))
		assert_true(page.scroll.get_global_rect().end.y <= page.confirm_button.get_global_rect().position.y)
		assert_true(page.paper_panel.get_global_rect().position.y >= game.top_safe_area.get_global_rect().end.y)
		assert_true(page.paper_panel.get_global_rect().end.y <= game.character_hud.status_board.get_global_rect().position.y if game._mobile_mode else page.paper_panel.get_global_rect().position.x > 700)
		assert_true(game.menu_button.is_visible_in_tree())


func test_raw_ingredient_atlas_has_every_recipe_ingredient_with_valid_bounds() -> void:
	for id in HouseholdUI.INGREDIENT_IDS:
		var texture := HouseholdUI.ingredient_texture(id) as AtlasTexture
		assert_true(texture != null)
		assert_true(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region))
		assert_true(texture.region.size.x > 100 and texture.region.size.y > 100)


func test_bundled_body_font_covers_the_new_game_controls_without_system_fonts() -> void:
	for character in "备好食材人数与留存库存盐钠酱油糖冷藏保存不当总糖未知读取存档周慧兰66岁℃¥×还缺减少份数调整制作耗精力待再热处理原料用／＋":
		assert_true(HouseholdUI.BODY_FONT.has_char(character.unicode_at(0)), "Missing bundled glyph: " + character)


func test_keyboard_return_from_cooking_keeps_selection_and_inventory() -> void:
	var game := _game()
	game._choose_meal_source("home_kitchen")
	game._active_stage._get_confirm_button().grab_focus()
	game._confirm_food(["rice_plain", "soft_tofu_greens"])
	var page := game._workspace as CookingPlanStage
	var pantry := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	page._input(_cancel_event())
	assert_false(is_instance_valid(game._workspace))
	assert_eq(game.selected_food_ids, ["rice_plain", "soft_tofu_greens"])
	assert_eq(game.kitchen.ingredients, pantry)
	assert_eq(game.kitchen.condiments, condiments)
	assert_true(game.today_meal_records.is_empty())
	assert_eq(game.phase, "breakfast")
	assert_eq(game.get_viewport().gui_get_focus_owner(), game._active_stage._get_confirm_button())
	page.confirm_requested.emit(["rice_plain", "soft_tofu_greens"], "fridge", {})
	assert_eq(game.kitchen.ingredients, pantry)
	assert_true(game.today_meal_records.is_empty())


func test_source_stage_does_not_capture_keys_from_the_new_day_popup() -> void:
	var game := _game()
	game._show_new_day_popup()
	game.new_day_popup._finish_show()
	var source := game._active_stage as HouseholdSourceStage
	assert_false(source.is_processing_input())
	assert_eq(game.get_viewport().gui_get_focus_owner(), game.new_day_popup.continue_button)
	assert_true(game._new_day_pending)
	assert_eq(game.phase, "breakfast_source")
	assert_false(is_instance_valid(game._workspace))
	assert_true(game.today_meal_records.is_empty())


func test_pinned_food_details_restore_the_info_button_without_selecting_food() -> void:
	var game := _game()
	game._choose_meal_source("home_kitchen")
	var card := game._active_stage._cards_by_id["rice_plain"] as HouseholdFoodCard
	card.info_button.grab_focus()
	card.request_detail(true)
	assert_true(game.sticky_note.pinned)
	game.sticky_note.close_button.grab_focus()
	game.sticky_note._on_close_pressed()
	assert_eq(game.get_viewport().gui_get_focus_owner(), card.info_button)
	assert_true(game.selected_food_ids.is_empty())
	assert_true(game.today_meal_records.is_empty())


func test_removing_selected_food_is_idempotent_and_keeps_stock_and_money() -> void:
	var game := _game()
	game._choose_meal_source("home_kitchen")
	for id in ["rice_plain", "soft_tofu_greens", "tomato_egg_stir_fry"]: game._on_food_toggled(id)
	var stage := game._active_stage as HouseholdMealStage
	var pantry := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	var state := game.state.duplicate(true)
	var remove := stage.find_child("Remove_soft_tofu_greens", true, false) as Button
	remove.pressed.emit()
	remove.pressed.emit()
	assert_eq(game.selected_food_ids, ["rice_plain", "tomato_egg_stir_fry"])
	assert_eq(stage.get_selected_ids(), game.selected_food_ids)
	assert_eq(game.kitchen.ingredients, pantry)
	assert_eq(game.kitchen.condiments, condiments)
	assert_eq(game.state, state)
	assert_true(game.today_meal_records.is_empty())
	assert_eq(game.phase, "breakfast")


func test_removing_last_selected_food_disables_confirmation() -> void:
	var game := _game()
	game._choose_meal_source("home_kitchen")
	game._on_food_toggled("rice_plain")
	var stage := game._active_stage as HouseholdMealStage
	(stage.find_child("Remove_rice_plain", true, false) as Button).pressed.emit()
	assert_true(game.selected_food_ids.is_empty())
	assert_true(stage._get_confirm_button().disabled)
	assert_true(stage._remove_buttons.is_empty())
	stage._get_confirm_button().pressed.emit()
	assert_false(is_instance_valid(game._workspace))
	assert_true(game.today_meal_records.is_empty())


func test_unavailable_food_details_update_after_selection_is_removed() -> void:
	var game := _market_fixture()
	var stage := game._active_stage as HouseholdMealStage
	var card := stage._cards_by_id["egg"] as HouseholdFoodCard
	var snapshots: Array[Dictionary] = []
	card.detail_requested.connect(func(payload: Dictionary, _anchor: Rect2, _pinned: bool) -> void: snapshots.append(payload))
	assert_true(card.disabled)
	card.request_detail(true)
	assert_contains(game.sticky_note.disabled_reason_label.text, "已经放满")
	game.sticky_note._on_close_pressed()
	(stage.find_child("Remove_milk", true, false) as Button).pressed.emit()
	assert_false(card.disabled)
	card.request_detail(true)
	assert_false(game.sticky_note.disabled_reason_label.visible)
	assert_contains(snapshots[0]["disabled_reason"], "已经放满")
	assert_eq(snapshots[1]["disabled_reason"], "")


func test_three_selected_foods_keep_remove_actions_and_footer_in_bounds() -> void:
	for view_size in [Vector2i(720, 1558), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _market_fixture(view_size)
		var stage := game._active_stage as HouseholdMealStage
		_layout(game)
		var paper := stage.paper_panel.get_global_rect()
		assert_true(paper.encloses(stage._selected_strip.get_global_rect()))
		assert_true(paper.encloses(stage._footer.get_global_rect()))
		assert_true(stage.food_scroll.get_global_rect().end.y <= stage._selected_strip.get_global_rect().position.y)
		for button: Button in stage._remove_buttons.values():
			assert_true(paper.encloses(button.get_global_rect()))
		for tile: SelectedFoodCardV2 in stage._selected_strip.get_children():
			assert_true(tile.size.y >= 194.0, "the whole selected card is a large removal target")
			for control: Control in [tile.remove_button, tile.title_label, tile.preview]:
				assert_true(tile.get_global_rect().encloses(control.get_global_rect()), "selected food content overlaps its card at %s" % view_size)
		for card: HouseholdFoodCard in stage._cards_by_id.values():
			assert_true(card.get_global_rect().encloses(card._status.get_global_rect()), "status clipped at %s for %s" % [view_size, card.item_id])
		game._on_food_toggled("milk")
		game._on_food_toggled("egg")
		_layout(game)
		var milk := stage._cards_by_id["milk"] as HouseholdFoodCard
		assert_true(milk.disabled)
		assert_true(milk.get_global_rect().encloses(milk._status.get_global_rect()), "wrapped unavailable milk status clipped at %s" % view_size)


func _market_fixture(view_size: Vector2i = Vector2i(1920, 1080)) -> GameRootV2:
	var game := _game(view_size)
	game.source_hands["breakfast:breakfast_shop"] = ["milk", "millet_porridge", "steamed_bun", "egg"]
	game._choose_meal_source("breakfast_shop")
	for id in ["milk", "millet_porridge", "steamed_bun"]: game._on_food_toggled(id)
	return game


func test_escape_cancels_confirmation_once_and_ignores_old_buttons() -> void:
	var game := _game()
	var choices: Array[String] = []
	game._show_story_dialog("替换这份存档？", "", [{"id": "save", "text": "替换"}, {"id": "back", "text": "返回"}], func(id: String) -> void: choices.append(id))
	var dialog := game._story_dialog
	var old_save := dialog._buttons.get_node("save") as Button
	dialog._input(_cancel_event())
	dialog._input(_cancel_event())
	old_save.pressed.emit()
	assert_eq(choices, ["back"])
	assert_false(dialog.visible)
	game._show_story_dialog("查看进度", "", [{"id": "close", "text": "继续"}], func(id: String) -> void: choices.append(id))
	old_save.pressed.emit()
	assert_true(dialog.visible)
	assert_eq(choices, ["back"])


func test_pending_dialog_blocks_cancel_and_focus_skips_disabled_slots() -> void:
	var game := _game()
	var choices: Array[String] = []
	game._show_story_dialog("正在保存进度", "", [], func(id: String) -> void: choices.append(id))
	var dialog := game._story_dialog
	dialog._input(_cancel_event())
	assert_true(dialog.visible)
	assert_true(choices.is_empty())
	game._show_story_dialog("读取进度", "", [{"id": "auto", "text": "自动存档", "enabled": false}, {"id": "cancel", "text": "取消", "enabled": false}, {"id": "back", "text": "返回"}], func(id: String) -> void: choices.append(id))
	dialog._focus_first()
	assert_eq(game.get_viewport().gui_get_focus_owner(), dialog._buttons.get_node("back"))
	dialog._input(_cancel_event())
	assert_eq(choices, ["back"])
	assert_false(dialog.visible)


func test_continuing_first_day_opens_sources_without_a_kitchen_panel() -> void:
	var game := _game()
	var pantry := game.kitchen.ingredients.duplicate(true)
	var batches := game.kitchen.batches.duplicate(true)
	game._on_new_day_continue()
	assert_true(game._active_stage is HouseholdSourceStage)
	assert_false(is_instance_valid(game._workspace))
	assert_eq(game.phase, "breakfast_source")
	assert_eq(game.kitchen.ingredients, pantry)
	assert_eq(game.kitchen.batches, batches)
	assert_true(game.today_meal_records.is_empty())
	assert_true(game._active_stage.find_children("*", "ScrollContainer", true, false).is_empty())
	assert_true(game._active_stage.find_child("WorktopPaper", true, false) == null)


func test_source_navigation_only_opens_cooking_preview_after_selecting_recipes() -> void:
	var game := _game()
	game._on_new_day_continue()
	var state_before := game.state.duplicate(true)
	var pantry := game.kitchen.ingredients.duplicate(true)
	(game._active_stage.find_child("home_kitchen", true, false) as Button).pressed.emit()
	assert_eq(game.phase, "breakfast")
	assert_true(game._active_stage is HouseholdMealStage)
	assert_false(is_instance_valid(game._workspace))
	game._on_food_toggled("rice_plain")
	game._confirm_food(game.selected_food_ids.duplicate())
	assert_true(game._workspace is CookingPlanStage)
	game._close_workspace()
	(game._active_stage.find_child("BackButton", true, false) as Button).pressed.emit()
	assert_true(game._active_stage is HouseholdSourceStage)
	assert_false(is_instance_valid(game._workspace))
	assert_eq(game.state, state_before)
	assert_eq(game.kitchen.ingredients, pantry)
	assert_true(game.today_meal_records.is_empty())
	(game._active_stage.find_child("go_out", true, false) as Button).pressed.emit()
	(game._active_stage.find_child("local_market", true, false) as Button).pressed.emit()
	assert_eq(game.current_source_id, "local_market")
	assert_false(is_instance_valid(game._workspace))


func test_home_choices_and_market_hotspots_fit_without_scrolling() -> void:
	for view_size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _game(view_size)
		var stage := game._active_stage as HouseholdSourceStage
		stage.apply_entry_profile(game._mobile_mode)
		_layout(game)
		stage._refresh_map_layout()
		_layout(stage)
		var bounds := game.get_viewport().get_visible_rect()
		for id: String in HouseholdSourceStage.HOME_ORDER:
			var button := stage.find_child(id, true, false) as Button
			assert_true(button != null and button.is_visible_in_tree())
			assert_true(bounds.encloses(button.get_global_rect()), "%s outside %s" % [id, view_size])
			assert_false(button.get_global_rect().intersects(stage.footer.get_global_rect()), "%s overlaps tools at %s" % [id, view_size])
			assert_true(button.get_global_rect().position.y >= game.top_safe_area.get_global_rect().end.y)
			if game._mobile_mode:
				assert_true(button.get_global_rect().end.y <= game.character_hud.status_board.get_global_rect().position.y)
		assert_true(bounds.encloses(stage.footer.get_global_rect()))
		assert_true(stage.find_child("community_canteen", true, false) == null)
		assert_true(stage.find_child("local_market", true, false) == null)
		(stage.find_child("go_out", true, false) as Button).pressed.emit()
		_layout(game)
		var market := game._active_stage as HouseholdMarketStage
		market._place_shops()
		_layout(market)
		market._place_shops()
		assert_true(market != null)
		assert_false(is_instance_valid(game._story_dialog) and game._story_dialog.visible)
		for id: String in HouseholdSourceStage.OUTSIDE_ORDER:
			var choice := market._choices[id] as Button
			assert_true(bounds.encloses(choice.get_global_rect()))
			assert_true(choice.get_global_rect().encloses(choice.get_node("Plaque").get_global_rect()))
			var photo := choice.get_node("Illustration/Art") as TextureRect
			assert_true(photo.texture != null, id + " has no illustration")
			assert_true(choice is HouseholdPropButton)
			assert_true(photo.texture.get_image().detect_alpha() != Image.ALPHA_NONE)
			assert_true(choice.get_theme_stylebox("normal") is StyleBoxEmpty)
			assert_true(choice.get_global_rect().grow(1).encloses(photo.get_global_rect()), "%s picture outside button at %s: %s / %s" % [id, view_size, choice.get_global_rect(), photo.get_global_rect()])
			assert_true(choice.get_global_rect().encloses(choice.get_node("Info").get_global_rect()), "%s info outside button at %s" % [id, view_size])
			assert_false(choice.get_global_rect().intersects(market.back_button.get_global_rect()))
		assert_true((market._choices["community_canteen"] as Button).disabled)
		assert_false((market._choices["breakfast_shop"] as Button).disabled)


func test_source_rules_and_tools_are_available_through_explicit_popups() -> void:
	var game := _game()
	game._on_new_day_continue()
	var stage := game._active_stage as HouseholdSourceStage
	var state_before := game.state.duplicate(true)
	var text_count := 0
	for label: Label in stage.find_children("*", "Label", true, false):
		if label.is_visible_in_tree(): text_count += label.text.length()
	assert_true(text_count < 50, "Destination scene should keep long rules inside details")
	(stage._props["home_kitchen"].get_node("Info") as Button).pressed.emit()
	assert_true(game.sticky_note.visible and game.sticky_note.pinned)
	assert_eq(game.sticky_note.get_payload()["energy"], -6)
	game.sticky_note._on_close_pressed()
	assert_false(game.sticky_note.pinned)
	(stage.find_child("Notebook", true, false) as Button).pressed.emit()
	assert_true(game._story_dialog.visible)
	assert_false(is_instance_valid(game._workspace))
	(game._story_dialog._buttons.get_node("kitchen") as Button).pressed.emit()
	assert_true(game._workspace is KitchenStockStage)
	assert_eq(game.state, state_before)
	assert_true(game.today_meal_records.is_empty())


func test_outing_scene_spends_nothing_and_returns_via_the_market() -> void:
	var game := _game()
	var baseline := game.state.duplicate(true)
	var pantry := game.kitchen.ingredients.duplicate(true)
	assert_eq(game._background_path_for_phase(), HouseholdSourceStage.WIDE_SCENE)
	(game._active_stage.find_child("go_out", true, false) as Button).pressed.emit()
	assert_eq(game.phase, "breakfast_source")
	assert_eq(game.current_source_id, "")
	assert_eq(game._background_path_for_phase(), HouseholdLocations.MARKET_WIDE)
	assert_false(is_instance_valid(game._workspace))
	var market := game._active_stage as HouseholdMarketStage
	var closed := market._choices["community_canteen"] as Button
	closed.pressed.emit()
	assert_eq(game.phase, "breakfast_source")
	assert_true(game._active_stage is HouseholdMarketStage)
	market._unhandled_key_input(_cancel_event())
	assert_true(game._active_stage is HouseholdSourceStage)
	assert_eq(game._background_path_for_phase(), HouseholdSourceStage.WIDE_SCENE)
	assert_eq(game.state, baseline)
	(game._active_stage.find_child("go_out", true, false) as Button).pressed.emit()
	(game._active_stage.find_child("local_market", true, false) as Button).pressed.emit()
	assert_eq(game.phase, "breakfast")
	assert_eq(game.current_source_id, "local_market")
	assert_contains(game._background_path_for_phase(), "zhou-fruit-stall")
	assert_false(is_instance_valid(game._workspace))
	game._change_meal_source()
	assert_true(game._active_stage is HouseholdMarketStage)
	assert_eq(game._background_path_for_phase(), HouseholdLocations.MARKET_WIDE)
	game._return_from_market()
	assert_eq(game._background_path_for_phase(), HouseholdSourceStage.WIDE_SCENE)
	assert_eq(game.state, baseline)
	assert_eq(game.kitchen.ingredients, pantry)
	assert_true(game.today_meal_records.is_empty())


func test_diner_scene_only_follows_an_available_market_choice() -> void:
	var game := _game()
	game.phase = "lunch_source"
	game._render_phase()
	var state_before := game.state.duplicate(true)
	(game._active_stage.find_child("go_out", true, false) as Button).pressed.emit()
	var canteen := game._active_stage.find_child("community_canteen", true, false) as Button
	assert_false(canteen.disabled)
	canteen.pressed.emit()
	assert_eq(game.phase, "lunch")
	assert_eq(game.current_source_id, "community_canteen")
	assert_contains(game._background_path_for_phase(), "zhou-homestyle-diner")
	assert_eq(game.state, state_before)
	assert_false(is_instance_valid(game._workspace))
	game._change_meal_source()
	assert_eq(game.phase, "lunch_source")
	assert_eq(game._background_path_for_phase(), HouseholdLocations.MARKET_WIDE)
	game._return_from_market()
	assert_eq(game._background_path_for_phase(), HouseholdSourceStage.WIDE_SCENE)


func test_fruit_stall_has_its_own_scene_at_every_meal() -> void:
	var game := _game()
	game._choose_meal_source("local_market")
	assert_contains(game._background_path_for_phase(), "zhou-fruit-stall")
	game.phase = "lunch"
	assert_contains(game._background_path_for_phase(), "zhou-fruit-stall")
	game.phase = "dinner"
	assert_contains(game._background_path_for_phase(), "zhou-fruit-stall")
	game._change_meal_source()
	game._return_from_market()
	assert_eq(game._background_path_for_phase(), HouseholdSourceStage.WIDE_SCENE)
	assert_true(game.today_meal_records.is_empty())


func test_cooking_and_stock_workspaces_show_their_own_locations_and_restore() -> void:
	var game := _game()
	var before := {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "batches": game.kitchen.batches.duplicate(true)}
	game._show_kitchen()
	assert_contains(game._background_path_for_phase(), "zhou-open-fridge")
	game._close_workspace()
	assert_eq(game._background_path_for_phase(), HouseholdSourceStage.WIDE_SCENE)
	game._choose_meal_source("home_kitchen")
	assert_contains(game._background_path_for_phase(), "zhou-kitchen")
	game._on_food_toggled("rice_plain")
	game._confirm_food(game.selected_food_ids.duplicate())
	assert_true(game._workspace is CookingPlanStage)
	assert_contains(game._background_path_for_phase(), "zhou-kitchen")
	game._close_workspace()
	game._show_kitchen()
	assert_contains(game._background_path_for_phase(), "zhou-open-fridge")
	game._close_workspace()
	assert_contains(game._background_path_for_phase(), "zhou-kitchen")
	assert_eq(game.selected_food_ids, ["rice_plain"])
	game._change_meal_source()
	game._choose_meal_source("home_fridge")
	assert_contains(game._background_path_for_phase(), "zhou-open-fridge")
	assert_eq(game.state, before["state"])
	assert_eq(game.kitchen.ingredients, before["ingredients"])
	assert_eq(game.kitchen.batches, before["batches"])
	assert_true(game.today_meal_records.is_empty())


func test_leaving_the_market_does_not_reopen_it_for_the_next_meal_or_day() -> void:
	var game := _game()
	game._show_outing_choices()
	game._choose_meal_source("breakfast_shop")
	game._on_food_toggled("steamed_bun")
	game._confirm_food(game.selected_food_ids.duplicate())
	assert_eq(game.phase, "breakfast_action")
	assert_eq(game.today_meal_records.back()["source_name"], "早餐店")
	assert_eq(game.today_meal_records.back()["total_cost"], 2)
	game._skip_action()
	assert_true(game._active_stage is HouseholdSourceStage)
	game.day = 2
	game.phase = "breakfast_source"
	game._render_phase()
	assert_true(game._active_stage is HouseholdSourceStage)


func test_home_entries_draw_graphics_inside_their_click_targets() -> void:
	for view_size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _game(view_size)
		var stage := game._active_stage as HouseholdSourceStage
		_layout(game)
		stage._refresh_map_layout()
		_layout(stage)
		for id: String in stage.HOME_ORDER:
			var prop := stage._props[id] as Control
			var art := prop.get_node("Illustration/Art") as TextureRect
			var target := prop.get_node(id) as Button
			assert_true(art.is_visible_in_tree() and art.texture is AtlasTexture, id + " must be drawn as a separate picture")
			assert_true((art.texture as AtlasTexture).region.has_area())
			assert_true(target.get_global_rect().encloses(art.get_global_rect()), id + " illustration must activate the same target as its caption")
		var book := stage.footer.get_node("Notebook/Illustration/Art") as TextureRect
		assert_true(book.is_visible_in_tree() and book.texture != null)
		assert_true((stage.footer.get_node("Notebook") as Button).text.is_empty())
		assert_true((stage.footer.get_node("Notebook") as Button).get_theme_stylebox("focus") is StyleBoxEmpty)


func test_cooking_shortage_names_exact_missing_food_and_condiment_amounts() -> void:
	var game := _game()
	game._choose_meal_source("home_kitchen")
	game.kitchen.ingredients["tofu"] = 1
	game.kitchen.condiments["soy_ml"] = 7
	game.kitchen.condiments["sugar_g"] = 2
	game._confirm_food(["soft_tofu_greens", "soft_apple"])
	var page := game._workspace as CookingPlanStage
	var ingredients := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	assert_false(page._seasoning_details.visible)
	page._details_button.set_pressed(true)
	assert_true(page._seasoning_details.is_visible_in_tree())
	page.choose_option("storage", "fridge")
	page.choose_option("sugar", "4")
	assert_true(page.confirm_button.disabled)
	assert_contains(page._shortage_note.text, "豆腐1份")
	assert_contains(page._shortage_note.text, "酱油3毫升")
	assert_contains(page._shortage_note.text, "白糖6克")
	assert_contains(page._condiments_note.text, "用10毫升／库存7毫升")
	assert_false(page._commit_summary.visible)
	page.choose_option("storage", "eat_now")
	page.choose_option("sugar", "0")
	assert_false(page.confirm_button.disabled)
	assert_false(page._shortage_note.visible)
	assert_true(page._commit_summary.visible)
	assert_contains(page._commit_summary.text, "当餐1份")
	assert_contains(page._commit_summary.text, "制作耗6精力")
	page._details_button.set_pressed(false)
	assert_false(page._seasoning_details.visible)
	assert_eq(game.kitchen.ingredients, ingredients)
	assert_eq(game.kitchen.condiments, condiments)
	assert_true(game.today_meal_records.is_empty())


func test_shortage_and_commit_summary_stay_outside_the_recipe_scroll() -> void:
	for view_size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _game(view_size)
		game._choose_meal_source("home_kitchen")
		game.kitchen.ingredients["tofu"] = 1
		game.kitchen.condiments["soy_ml"] = 1
		game._confirm_food(["rice_plain", "soft_tofu_greens", "soft_apple"])
		var page := game._workspace as CookingPlanStage
		page.choose_option("storage", "fridge")
		_layout(game)
		assert_true(page._shortage_note.is_visible_in_tree())
		assert_true(page.paper_panel.get_global_rect().encloses(page._shortage_note.get_global_rect()), "shortage must fit at %s" % view_size)
		assert_true(page.scroll.get_global_rect().end.y <= page._shortage_note.get_global_rect().position.y)
		assert_true(page._shortage_note.get_global_rect().end.y <= page.footer.get_global_rect().position.y)
		assert_true(page.paper_panel.get_global_rect().encloses(page.footer.get_global_rect()))
		assert_false(page.scroll.is_ancestor_of(page._shortage_note))


func test_stock_tabs_and_batch_details_are_read_only_and_keep_controls_visible() -> void:
	for view_size in [Vector2i(720, 1280), Vector2i(1920, 1080)]:
		var game := _game(view_size)
		game.kitchen.cook(["rice_plain", "soft_tofu_greens"], game._story_food_catalog(), 1, "fridge")
		game._show_kitchen()
		var page := game._workspace as KitchenStockStage
		var before := {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "batches": game.kitchen.batches.duplicate(true), "history": game.kitchen.history.duplicate(true)}
		assert_contains(page.subtitle_label.text, "待再热2份")
		assert_contains(page.subtitle_label.text, "待处理1份")
		page._tab_buttons["ingredients"].pressed.emit()
		_layout(game)
		assert_true(page._tab_pages["ingredients"].is_visible_in_tree())
		assert_false(page._tab_pages["cooked"].visible)
		assert_true(page.paper_panel.get_global_rect().encloses(page._tab_buttons["cooked"].get_global_rect()))
		assert_true(page._tab_buttons["cooked"].get_global_rect().end.y <= page.scroll.get_global_rect().position.y)
		page._tab_buttons["cooked"].pressed.emit()
		var details := page.find_child("Details_batch_2", true, false) as Button
		var record := page.find_child("Record_batch_2", true, false) as Control
		assert_false(record.visible)
		details.set_pressed(true)
		assert_true(record.visible)
		assert_contains((record.get_child(1) as Label).text, "750")
		page._select_tab("ingredients")
		page._select_tab("cooked")
		assert_true(record.visible, "tab navigation must preserve expanded records")
		details.set_pressed(false)
		assert_false(record.visible)
		assert_eq(game.state, before["state"])
		assert_eq(game.kitchen.ingredients, before["ingredients"])
		assert_eq(game.kitchen.condiments, before["condiments"])
		assert_eq(game.kitchen.batches, before["batches"])
		assert_eq(game.kitchen.history, before["history"])
		assert_true(game.today_meal_records.is_empty())


func test_story_actions_have_distinct_scenes_and_keep_shared_zero_slot_verbs() -> void:
	var game := _game()
	game.day = 4
	game.phase = "lunch_action"
	game._render_phase()
	var stage := game._active_stage as ActionStageV2
	var scenes := {}
	for id in ["rehearse", "group_rehearsal", "perform", "call_friend"]:
		var path := String(game._story_action(id)["image"])
		assert_contains(path, "/stories/actions/zhou_")
		assert_false(scenes.has(path), "each narrative action needs its own scene")
		scenes[path] = true
		var texture := load(path) as Texture2D
		assert_true(texture != null and texture.get_width() > 500 and texture.get_height() > 500)
	assert_eq((stage._cards_by_id["call_friend"] as CompactChoiceCardV2).select_button.text, "约饭")
	assert_eq((stage._cards_by_id["drink_water"] as CompactChoiceCardV2).select_button.text, "接水")
	var before := game.state.duplicate(true)
	assert_true(game.plan_shared_meal("home"))
	stage = game._active_stage as ActionStageV2
	assert_contains(stage.story_note.text, "晚饭约好了")
	assert_eq(game.actions_used_today, 0)
	for slot in stage.used_slots.get_children():
		assert_false((slot.get_node("Preview") as TextureRect).visible, "a zero-slot invitation must not occupy the daily planner")
	assert_eq(game.state, before)
	game.phase = "dinner_action"
	assert_false(game._household_action_note().contains("准备晚饭"), "after dinner, a missed invitation must not ask the player to prepare that meal again")
	assert_eq(game.shared_meal.plan["status"], "planned", "the presenter must leave missed-plan settlement to the existing day flow")


func test_performance_note_shows_both_shortfalls_and_uses_actual_availability() -> void:
	var game := _game()
	game.day = 7
	game.phase = "dinner_action"
	game.state["goal_progress"] = game._goal_target() - 8
	game.state["energy"] = int(game._story_action("perform")["min_energy"]) - 1
	var before := game.state.duplicate(true)
	assert_contains(game._household_action_note(), "排练8")
	assert_contains(game._household_action_note(), "精力1")
	assert_eq(game.state, before)
	assert_false(game.performed)
	game.state["goal_progress"] = game._goal_target()
	game.state["energy"] += 1
	assert_contains(game._household_action_note(), "准备好了")
	game.actions_used_today = game.MAX_DAILY_ACTIONS
	assert_contains(game._household_action_note(), game._action_disabled_reason(game._story_action("perform")))
	assert_false(game._household_action_note().contains("准备好了"))
	assert_true(game.today_action_records.is_empty())


func test_group_rehearsal_note_follows_the_day_and_current_action_reason() -> void:
	var game := _game()
	game.day = 3
	game.phase = "lunch_action"
	assert_contains(game._household_action_note(), "今天午后有集体排练")
	game.state["energy"] = 0
	assert_contains(game._household_action_note(), game._action_disabled_reason(game._story_action("group_rehearsal")))
	game.state["energy"] = 60
	game.used_action_ids.append("group_rehearsal")
	assert_contains(game._household_action_note(), "已经参加过")
	game.day = 2
	assert_false(game._household_action_note().contains("今天午后有集体排练"))


func test_household_night_returns_home_and_only_the_ending_uses_the_stage() -> void:
	var game := _game()
	for run_day in [2, 4]:
		game.day = run_day
		assert_contains(game._household_night_note(), "明天午饭后")
	game.day = 6
	assert_contains(game._household_night_note(), "明晚社区汇演")
	assert_contains(game._household_night_note(), str(game._goal_target()))
	assert_contains(game._household_night_note(), str(game._story_action("perform")["min_energy"]))
	game.day = 7
	game.phase = "sleep"
	game._render_phase()
	assert_eq(game._background_path_for_phase(), GameRootV2.HOUSEHOLD_HOME_NIGHT)
	assert_true(ResourceLoader.exists(GameRootV2.HOUSEHOLD_HOME_NIGHT))
	assert_false((game._active_stage as SleepStageV2).tomorrow_label.text.contains("明天"))
	assert_contains((game._active_stage as SleepStageV2).tomorrow_label.text, "本周最后一晚")
	game.performed = true
	game._render_phase()
	assert_eq(game._background_path_for_phase(), GameRootV2.HOUSEHOLD_HOME_NIGHT)
	assert_contains((game._active_stage as SleepStageV2).prompt_label.text, "回到家")
	assert_contains((game._active_stage as SleepStageV2).tomorrow_label.text, "这一周唱完了")
	game.phase = "ending"
	assert_contains(game._background_path_for_phase(), "choir_stage")


func test_story_schedule_note_and_night_copy_fit_mobile_and_desktop() -> void:
	for view_size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _game(view_size)
		game.day = 4
		game.phase = "lunch_action"
		game.plan_shared_meal("home")
		game._render_phase()
		_layout(game)
		var stage := game._active_stage as ActionStageV2
		var note := stage.get_node("Layout/PlannerNote") as Control
		assert_true(stage.story_note.is_visible_in_tree())
		assert_true(note.get_global_rect().encloses(stage.story_note.get_global_rect()), "schedule leaves its note at %s" % view_size)
		assert_true(note.get_global_rect().encloses(stage.used_slots.get_global_rect()), "schedule hides the executed actions at %s" % view_size)
		for character in stage.story_note.text + "今晚汇演还差排练精力回到家收尾":
			assert_true(HouseholdUI.BODY_FONT.has_char(character.unicode_at(0)), "Missing schedule glyph: " + character)
		game.day = 7
		game.performed = true
		game.phase = "sleep"
		game._render_phase()
		_layout(game)
		var sleep := game._active_stage as SleepStageV2
		assert_true(sleep.get_node("Layout/AlarmNote").get_global_rect().encloses(sleep.tomorrow_label.get_global_rect()))
		assert_true(sleep.get_node("Layout/AlarmNote").get_global_rect().encloses(sleep.hint_label.get_global_rect()))


func test_home_hover_previews_show_rules_without_spending_or_pinning() -> void:
	var game := _game()
	var stage := game._active_stage as HouseholdSourceStage
	var before := game.state.duplicate(true)
	var dismissed: Array[String] = []
	stage.detail_dismissed.connect(func(id: String) -> void: dismissed.append(id))
	for id: String in HouseholdSourceStage.HOME_ORDER:
		var button := stage._props[id].get_node(id) as Button
		button.mouse_entered.emit()
		assert_true(game.sticky_note.is_showing_item(id))
		assert_false(game.sticky_note.pinned)
		assert_eq(game.sticky_note.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		button.mouse_exited.emit()
		assert_true(dismissed.has(id))
		game.sticky_note.hide_note(false)
	assert_eq(game.state, before)
	assert_eq(game.phase, "breakfast_source")
	assert_true(game.today_meal_records.is_empty())
	stage.apply_entry_profile(true)
	(stage._props["home_kitchen"].get_node("home_kitchen") as Button).mouse_entered.emit()
	assert_false(game.sticky_note.visible)
	for id: String in HouseholdSourceStage.HOME_ORDER:
		game.sticky_note.hide_note(false)
		var info := stage._props[id].get_node("Info") as Button
		assert_eq(info.text, "?")
		info.pressed.emit()
		assert_true(game.sticky_note.is_showing_item(id) and game.sticky_note.pinned)
		assert_true(game._active_stage == stage)
		assert_eq(game.state, before)


func test_closed_shop_hover_and_explicit_details_preserve_opening_rules() -> void:
	var game := _game()
	var before := game.state.duplicate(true)
	game._show_outing_choices()
	var market := game._active_stage as HouseholdMarketStage
	var closed := market._choices["community_canteen"] as Button
	assert_true(closed.disabled)
	closed.mouse_entered.emit()
	assert_true(game.sticky_note.is_showing_item("community_canteen"))
	assert_false(game.sticky_note.pinned)
	assert_false(game.sticky_note.disabled_reason_label.text.is_empty())
	(closed.get_node("Info") as Button).pressed.emit()
	assert_true(game.sticky_note.pinned)
	(market._choices["breakfast_shop"] as Button).mouse_entered.emit()
	assert_true(game.sticky_note.is_showing_item("community_canteen"))
	closed.pressed.emit()
	assert_eq(game.current_source_id, "")
	assert_eq(game.state, before)
	assert_eq(game.phase, "breakfast_source")


func test_food_hover_and_keyboard_preview_include_current_unavailable_reason() -> void:
	var game := _game()
	game._choose_meal_source("home_kitchen")
	var card := game._active_stage._cards_by_id["egg"] as HouseholdFoodCard
	var before := game.state.duplicate(true)
	card.mouse_entered.emit()
	assert_true(game.sticky_note.is_showing_item("egg"))
	assert_false(game.sticky_note.pinned)
	card.set_enabled(false, "鸡蛋不够")
	card.info_button.focus_entered.emit()
	assert_eq(game.sticky_note.disabled_reason_label.text, "鸡蛋不够")
	card.info_button.pressed.emit()
	assert_true(game.sticky_note.pinned)
	assert_true(game.selected_food_ids.is_empty())
	assert_eq(game.state, before)
	assert_true(game.today_meal_records.is_empty())


func _cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _layout(node: Node) -> void:
	for pass_index in range(7): _sort(node)


func _sort(node: Node) -> void:
	if node is Container: (node as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children(): _sort(child)
	if node is Label: (node as Label).get_line_count()
	if node is Control: (node as Control).update_minimum_size()
	if node is Container and node.get_parent() is Control and not node.get_parent() is Container:
		var control := node as Control
		var parent_size := control.get_parent_area_size()
		control.set_size(Vector2(parent_size.x * (control.anchor_right - control.anchor_left) + control.offset_right - control.offset_left, parent_size.y * (control.anchor_bottom - control.anchor_top) + control.offset_bottom - control.offset_top))
