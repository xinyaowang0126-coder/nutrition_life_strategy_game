@tool
extends McpTestSuite

const Prep := preload("res://scripts/stories/HouseholdPreparation.gd")
const Planner := preload("res://scripts/stories/HouseholdPreparationPresenter.gd")

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")


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


func suite_name() -> String:
	return "household_preparation"


func _six_scene(save: Dictionary = {}, size: Vector2i = Vector2i(1920, 1080)) -> GameRootV2:
	return _scene(_game(6).capture_game_save() if save.is_empty() else save, size)


func _six_intro(game: GameRootV2, look: bool = false) -> void:
	game._story_dialog._buttons.get_node("look" if look else "back").pressed.emit()


func _plan(game: GameRootV2, choice: String = "stock") -> void:
	assert_true(Prep.choose(game.household_preparation, game._current_meal_phase(), choice, game.kitchen.batches, game._story_clock()))


func _prep_ack(game: GameRootV2) -> void:
	game._story_dialog._buttons.get_node("close").pressed.emit()


func _records(game: GameRootV2) -> Array:
	return Prep.records_for(game.capture_game_save()["payload"])


func test_intro_and_planner_read_live_inventory_without_making_a_meal() -> void:
	var game := _six_scene()
	var before := _resources(game)
	assert_contains(game._story_dialog._body.text, "明晚就要登台")
	_six_intro(game, true)
	assert_eq(game._workspace.name, "PreparationPlanner")
	assert_contains(game._workspace.subtitle_label.text, "第6天午餐")
	assert_eq(_resources(game), before)
	assert_true(game.household_preparation["plans"].is_empty())
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_planning_changing_and_clearing_intent_do_not_spend_resources() -> void:
	var game := _six_scene()
	_six_intro(game, true)
	var before := _resources(game)
	for choice in ["stock", "later", "clear"]:
		game._workspace.find_child(choice, true, false).pressed.emit()
		assert_eq(_resources(game), before)
		assert_true(Codec.encode(game.capture_game_save())["ok"])
	assert_true(game.household_preparation["plans"].is_empty())


func test_recipe_draft_and_storage_survive_planning_and_cancel() -> void:
	var game := _six_scene()
	_six_intro(game)
	game._choose_meal_source("home_kitchen")
	game.hand.assign(["rice_plain", "soft_apple"])
	game.selected_food_ids.assign(["rice_plain", "soft_apple"])
	game._show_cooking_choice(game.selected_food_ids, "fridge", {"seasoning": "none", "added_sugar_g": 4})
	var before := _resources(game)
	game._workspace.learning_button.pressed.emit()
	game._workspace.find_child("stock", true, false).pressed.emit()
	game._workspace.close_button.pressed.emit()
	assert_eq(game._workspace.storage, "fridge")
	assert_eq(game._workspace.plan, {"seasoning": "none", "added_sugar_g": 4})
	assert_eq(_resources(game), before)
	assert_true(Prep.entry(game.household_preparation, "breakfast")["result"].is_empty())


func test_real_preparation_then_reheat_resolves_exact_batch_ids_once() -> void:
	var game := _six_scene()
	_six_intro(game)
	_plan(game)
	assert_true(_meal(game, ["rice_plain", "soft_apple"], "home_kitchen", "fridge"))
	assert_eq(game.household_preparation["pending"], "")
	game._skip_action()
	assert_contains(Prep.notice(game.household_preparation, 6, "lunch"), "原计划")
	assert_true(_meal(game, ["rice_plain", "soft_apple"], "home_fridge"))
	var row := Prep.entry(game.household_preparation, "breakfast")
	assert_eq(row["result"]["status"], "used")
	assert_eq(row["result"]["used_ids"], row["result"]["eligible_ids"])
	assert_eq(row["result"]["used_ids"].size(), 2)
	assert_contains(game._story_dialog._body.text, "这一份，这餐用上了")
	var before := _resources(game)
	var button: Button = game._story_dialog._buttons.get_node("close")
	button.pressed.emit()
	button.pressed.emit()
	assert_eq(_resources(game), before)
	assert_eq(game.household_preparation["acknowledged"], ["breakfast"])
	assert_eq(Prep.resolve(game.household_preparation, _records(game)), "")
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_one_dish_taken_does_not_claim_the_whole_prepared_plate_was_eaten() -> void:
	var game := _game(6)
	_plan(game)
	assert_true(_meal(game, ["rice_plain", "soft_apple"], "home_kitchen", "fridge"))
	game._skip_action()
	assert_true(_meal(game, ["rice_plain"], "home_fridge"))
	var result: Dictionary = Prep.entry(game.household_preparation, "breakfast")["result"]
	assert_eq(result["status"], "part_used")
	assert_eq(result["used_ids"].size(), 1)
	assert_contains(result["text"], "另有1样没有在这餐取用")


func test_plan_without_confirmed_cooking_does_not_invent_a_saved_portion() -> void:
	var game := _game(6)
	_plan(game)
	assert_true(_meal(game, ["rice_plain", "egg"]))
	game._skip_action()
	assert_true(_meal(game, ["rice_plain", "tofu"], "home_kitchen"))
	var result: Dictionary = Prep.entry(game.household_preparation, "breakfast")["result"]
	assert_eq(result["status"], "not_prepared")
	assert_true(result["used_ids"].is_empty())
	assert_contains(result["text"], "没有对应的冷藏熟食记录")


func test_counter_storage_and_discard_are_not_usable_preparation() -> void:
	var game := _game(6)
	_plan(game)
	assert_true(_meal(game, ["rice_plain", "egg"], "home_kitchen", "counter"))
	game._skip_action()
	for batch in game.kitchen.batches:
		if batch["day"] == 6: assert_true(game.kitchen.discard(batch["id"], 6))
	assert_true(_meal(game, ["rice_plain", "egg"], "community_canteen"))
	assert_eq(Prep.entry(game.household_preparation, "breakfast")["result"]["status"], "not_prepared")


func test_changed_source_and_skipped_target_have_distinct_actual_results() -> void:
	for skipped in [false, true]:
		var game := _game(6)
		_plan(game)
		assert_true(_meal(game, ["rice_plain", "egg"], "home_kitchen", "fridge"))
		game._skip_action()
		if skipped: game._skip_meal()
		else: assert_true(_meal(game, ["rice_plain", "egg"], "community_canteen"))
		assert_eq(Prep.entry(game.household_preparation, "breakfast")["result"]["status"], "skipped" if skipped else "changed")


func test_later_arrangement_can_change_to_stock_without_penalty() -> void:
	var game := _game(6)
	_plan(game, "later")
	assert_true(_meal(game, ["rice_plain", "egg"], "home_kitchen", "fridge"))
	game._skip_action()
	assert_true(_meal(game, ["rice_plain", "egg"], "home_fridge"))
	assert_eq(Prep.entry(game.household_preparation, "breakfast")["result"]["status"], "stock_instead")


func test_existing_earlier_day_batch_is_plannable_and_tracks_its_own_id() -> void:
	var game := _game(5)
	for meal in ["breakfast", "lunch", "dinner"]:
		assert_true(_meal(game, ["rice_plain", "egg"], "home_kitchen", "fridge" if meal == "dinner" else "eat_now"))
		game._skip_action()
	game._choose_sleep("sleep_early")
	game._on_summary_advanced()
	_plan(game)
	var row := Prep.entry(game.household_preparation, "breakfast")
	assert_eq(row["available_ids"].size(), 2)
	assert_true(_meal(game, ["rice_plain", "tofu"], "home_kitchen"))
	game._skip_action()
	assert_true(_meal(game, ["rice_plain", "egg"], "home_fridge"))
	assert_eq(row["result"]["used_ids"], row["available_ids"])


func test_dinner_plan_waits_for_day_seven_breakfast_and_freezes_both_states() -> void:
	var game := _six_scene()
	_six_intro(game)
	for meal in ["breakfast", "lunch"]:
		assert_true(_meal(game, ["rice_plain", "egg"], "home_kitchen"))
		game._skip_action()
	_plan(game)
	assert_eq(Prep.target("dinner"), {"day": 7, "meal": "breakfast"})
	assert_true(_meal(game, ["rice_plain", "soft_tofu_greens"], "home_kitchen", "fridge"))
	game._skip_action()
	game._choose_sleep("sleep_early")
	var frozen: Dictionary = game.run_history.back()["preparation_recap"].duplicate(true)
	assert_contains(frozen["text"], "第7天早餐")
	assert_contains(frozen["text"], "还没有实际取用记录")
	game._on_summary_advanced()
	if game._new_day_pending: game._on_new_day_continue()
	if game.household_finale.get("intro") == "details": game._story_dialog._buttons.get_node("back").pressed.emit()
	assert_true(_meal(game, ["rice_plain", "soft_tofu_greens"], "home_fridge"))
	assert_eq(Prep.entry(game.household_preparation, "dinner")["result"]["status"], "used")
	assert_eq(game.run_history.back()["preparation_recap"], frozen)
	assert_eq(game.household_preparation["pending"], "dinner")
	_prep_ack(game)
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_reading_draft_and_pending_result_from_json_does_not_repeat_material_effects() -> void:
	var game := _six_scene()
	_six_intro(game)
	game._choose_meal_source("home_kitchen")
	game.hand.assign(["rice_plain", "soft_apple"])
	game.selected_food_ids.assign(["rice_plain", "soft_apple"])
	game._show_cooking_choice(game.selected_food_ids, "fridge", {"seasoning": "none", "added_sugar_g": 4})
	game._workspace.learning_button.pressed.emit()
	game._workspace.find_child("stock", true, false).pressed.emit()
	var draft := Codec.decode(Codec.encode(game.capture_game_save())["text"])
	assert_true(draft["ok"])
	var restored := _six_scene(draft["save"])
	assert_eq(restored._workspace.name, "PreparationPlanner")
	var before := _resources(restored)
	restored._workspace.close_button.pressed.emit()
	assert_eq(restored._workspace.storage, "fridge")
	assert_eq(restored._workspace.plan["added_sugar_g"], 4)
	assert_eq(_resources(restored), before)
	restored._workspace.confirm_button.pressed.emit()
	restored._skip_action()
	assert_true(_meal(restored, ["rice_plain", "soft_apple"], "home_fridge"))
	var pending := Codec.decode(Codec.encode(restored.capture_game_save())["text"])
	assert_true(pending["ok"])
	var response := _six_scene(pending["save"])
	before = _resources(response)
	assert_eq(response.household_preparation["pending"], "breakfast")
	_prep_ack(response)
	assert_eq(_resources(response), before)


func test_legacy_missing_state_does_not_replay_intro_or_invent_plans() -> void:
	var save := _game(6).capture_game_save()
	save["payload"].erase("household_preparation")
	var decoded := Codec.decode(JSON.stringify(save))
	assert_true(decoded["ok"])
	var game := _six_scene(decoded["save"])
	assert_eq(game.household_preparation, Prep.initial_state(true))
	assert_false(is_instance_valid(game._story_dialog) and game._story_dialog.visible)


func test_forged_result_pending_and_future_plan_are_rejected_transactionally() -> void:
	var game := _six_scene()
	_six_intro(game)
	_plan(game)
	var before := game.capture_game_save()
	for field in ["result", "pending", "future", "batch"]:
		var forged := before.duplicate(true)
		var state: Dictionary = forged["payload"]["household_preparation"]
		if field == "result": state["plans"][0]["result"] = {"status": "used", "eligible_ids": [], "used_ids": [], "text": "fiction"}
		elif field == "pending": state["pending"] = "breakfast"
		elif field == "future": state["plans"][0]["meal"] = "dinner"
		else: state["plans"][0]["available_ids"] = ["missing_batch"]
		assert_false(game.restore_game_save(forged)["ok"])
		assert_eq(game.household_preparation, before["payload"]["household_preparation"])
		assert_eq(_resources(game)["state"], before["payload"]["state"])


func test_planner_is_isolated_from_campus_and_new_runs() -> void:
	var game := _six_scene()
	_six_intro(game)
	_plan(game)
	game.story_id = "campus_exam"
	game.start_new_run()
	assert_true(game.household_preparation.is_empty())
	assert_false(Planner.resume(game))
	game.story_id = "choir_week"
	game.start_new_run()
	assert_eq(game.household_preparation, Prep.initial_state())


func test_three_logical_canvas_sizes_keep_planner_footer_and_body_separate() -> void:
	for size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		var game := _six_scene({}, size)
		_six_intro(game, true)
		_layout(game)
		assert_true(game.get_viewport_rect().encloses(game._workspace.paper_panel.get_global_rect()))
		assert_true(game._workspace.paper_panel.get_global_rect().encloses(game._workspace.footer.get_global_rect()))
		assert_true(game._workspace.scroll.get_global_rect().end.y <= game._workspace.footer.get_global_rect().position.y)


func test_all_preparation_copy_glyphs_are_bundled() -> void:
	var missing := ""
	for path in ["res://scripts/stories/HouseholdPreparation.gd", "res://scripts/stories/HouseholdPreparationPresenter.gd"]:
		for character in FileAccess.get_file_as_string(path):
			var code := character.unicode_at(0)
			if code >= 0x3400 and code <= 0x9fff and not HouseholdUI.BODY_FONT.has_char(code) and not missing.contains(character): missing += character
	assert_eq(missing, "", "Missing preparation glyphs: " + missing)


func test_ready_pantry_milk_is_not_reported_as_reheated_prepared_milk() -> void:
	var game := _game(6)
	_plan(game)
	assert_true(_meal(game, ["milk"], "home_kitchen", "fridge"))
	game._skip_action()
	assert_true(_meal(game, ["milk"], "home_fridge"))
	assert_eq(game.today_meal_records.back()["kitchen_transaction"]["batches"][0]["kind"], "ready_pantry")
	var result: Dictionary = Prep.entry(game.household_preparation, "breakfast")["result"]
	assert_eq(result["status"], "changed")
	assert_true(result["used_ids"].is_empty())


func test_two_people_and_one_future_portion_use_three_portions_not_four() -> void:
	var game := _six_scene()
	_six_intro(game)
	for meal in ["breakfast", "lunch"]:
		assert_true(_meal(game, ["rice_plain", "egg"]))
		if meal == "breakfast": game._skip_action()
	assert_true(game.plan_shared_meal("home"))
	game._skip_action()
	game._choose_meal_source("home_kitchen")
	game.hand.assign(["rice_plain", "soft_tofu_greens"])
	game.selected_food_ids.assign(["rice_plain", "soft_tofu_greens"])
	game._show_cooking_choice(game.selected_food_ids, "fridge")
	game._workspace.learning_button.pressed.emit()
	var labels: Array[String] = []
	for label: Label in game._workspace.find_children("*", "Label", true, false): labels.append(label.text)
	assert_contains("\n".join(labels), "当餐2人份＋另留1份，本次共做3份")
	var rice: int = game.kitchen.ingredients["rice_plain"]
	var tofu: int = game.kitchen.ingredients["tofu"]
	game._workspace.close_button.pressed.emit()
	game._workspace.confirm_button.pressed.emit()
	assert_eq(game.kitchen.ingredients["rice_plain"], rice - 3)
	assert_eq(game.kitchen.ingredients["tofu"], tofu - 3)
	assert_eq(game.today_meal_records.back()["kitchen_transaction"]["served_portions"], 2)
	assert_eq(game.today_meal_records.back()["kitchen_transaction"]["prepared"].size(), 2)


func test_insufficient_stock_is_visible_and_plan_cannot_supply_the_shortage() -> void:
	var game := _six_scene()
	_six_intro(game)
	game.kitchen.ingredients["rice_plain"] = 1
	game._choose_meal_source("home_kitchen")
	game.hand.assign(["rice_plain"])
	game.selected_food_ids.assign(["rice_plain"])
	game._show_cooking_choice(game.selected_food_ids, "fridge")
	assert_true(game._workspace.confirm_button.disabled)
	game._workspace.learning_button.pressed.emit()
	var before := _resources(game)
	game._workspace.find_child("stock", true, false).pressed.emit()
	var text := ""
	for label: Label in game._workspace.find_children("*", "Label", true, false): text += label.text
	assert_contains(text, "库存不足")
	game._workspace.close_button.pressed.emit()
	assert_true(game._workspace.confirm_button.disabled)
	assert_eq(_resources(game), before)


func test_a_frozen_result_cannot_be_rewritten_by_importing_an_invented_response() -> void:
	var game := _six_scene()
	_six_intro(game)
	_plan(game)
	assert_true(_meal(game, ["rice_plain", "egg"], "home_kitchen", "fridge"))
	game._skip_action()
	assert_true(_meal(game, ["rice_plain", "egg"], "home_fridge"))
	var original := game.capture_game_save()
	var forged := original.duplicate(true)
	forged["payload"]["household_preparation"]["plans"][0]["result"]["text"] = "invented outcome"
	assert_false(game.restore_game_save(forged)["ok"])
	assert_eq(game.household_preparation, original["payload"]["household_preparation"])
	assert_true(Codec.encode(original)["ok"])


func test_actual_preparation_without_a_plan_does_not_invent_an_intention() -> void:
	var game := _six_scene()
	_six_intro(game)
	assert_true(_meal(game, ["rice_plain", "egg"], "home_kitchen", "fridge"))
	game._skip_action()
	assert_true(_meal(game, ["rice_plain", "egg"], "home_fridge"))
	assert_true(game.household_preparation["plans"].is_empty())
	assert_eq(game.household_preparation["pending"], "")
	assert_false(game._story_dialog.visible)
