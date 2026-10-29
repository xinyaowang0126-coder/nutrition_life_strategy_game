@tool
extends McpTestSuite

const Study := preload("res://scripts/stories/HouseholdMealLearning.gd")
const Presenter := preload("res://scripts/stories/HouseholdStudyPresenter.gd")
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")


func suite_name() -> String:
	return "household_study"


func _game(target_day: int = 2) -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.story_id = "choir_week"
	game.health_history_path = ""
	game._deck_service = Deck.new(42)
	game.start_new_run()
	var advances := 0
	while game.day < target_day and advances < 7:
		for meal in ["breakfast", "lunch", "dinner"]:
			game._choose_meal_source("breakfast_shop" if meal == "breakfast" else "community_canteen")
			var plate: Array[String] = []
			for id in game.hand:
				game.selected_food_ids = plate.duplicate()
				if game._can_add_food(id): plate.append(id)
				if plate.size() == 2: break
			assert_true(game.confirm_household_food(plate))
			game._apply_action("nap")
		game._choose_sleep("sleep_early")
		game._on_summary_advanced()
		advances += 1
	assert_eq(game.day, target_day, "Prior-day commands did not reach the requested day")
	return game


func _scene(day: int = 3, size: Vector2i = Vector2i(1920, 1080)) -> GameRootV2:
	var before := _game(day)
	return _scene_from(before.capture_game_save(), size)


func _scene_from(save: Dictionary, size: Vector2i = Vector2i(1920, 1080)) -> GameRootV2:
	var viewport := SubViewport.new()
	viewport.size = size
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	assert_true(Session.request_saved(save))
	var game := Scene.instantiate() as GameRootV2
	game.health_history_path = ""
	viewport.add_child(game)
	var callback := Callable(game, "_apply_responsive_profile")
	if viewport.size_changed.is_connected(callback): viewport.size_changed.disconnect(callback)
	game._mobile_mode = size.y > size.x
	game._apply_shell_profile()
	return game


func _recipe(game: GameRootV2, plan: Dictionary = {"seasoning": "light", "added_sugar_g": 4}, storage: String = "fridge") -> void:
	game._choose_meal_source("home_kitchen")
	# Declared real-catalog menu isolates the recipe and return-state boundary.
	game.hand.assign(["tofu", "oatmeal", "egg", "rice_plain", "greens"])
	game.selected_food_ids.assign(["tofu", "oatmeal"])
	game._render_phase()
	game._show_cooking_choice(game.selected_food_ids, storage, plan)


func _context(day: int, recipe: Dictionary = {}) -> Dictionary:
	var game := _game(day)
	return Study.context(day, "breakfast", "home_kitchen", ["tofu", "oatmeal"], game._story_food_catalog(), "selection" if recipe.is_empty() else "recipe_preview", recipe)


func _back(day: int) -> Dictionary:
	return {"kind": "meal", "day": day, "phase": "breakfast_source", "source": "", "ids": [], "plan": {}, "storage": "eat_now"}


func _materials(game: GameRootV2) -> Dictionary:
	return {"state": game.state.duplicate(true), "ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "batches": game.kitchen.batches.duplicate(true), "history": game.kitchen.history.duplicate(true), "meals": game.today_meal_records.duplicate(true), "selected": game.selected_food_ids.duplicate(), "phase": game.phase}


func test_sodium_question_uses_current_recipe_and_never_calls_it_whole_meal_sodium() -> void:
	var game := _game(3)
	for pair in [["none", 0], ["light", 750], ["usual", 1500]]:
		var facts := Facts.freeze(["tofu", "oatmeal"], game._story_food_catalog(), {"seasoning": pair[0], "added_sugar_g": 0})
		var c := Study.context(3, "breakfast", "home_kitchen", ["tofu", "oatmeal"], game._story_food_catalog(), "recipe_preview", facts)
		var q := Study.question(c)
		assert_contains(q["choices"][1]["text"], str(pair[1]))
		assert_eq(q["correct"], "measured")
		assert_contains(q["explanation"], "不是整餐或全天总量")
	var outside := Study.question(Study.context(3, "lunch", "community_canteen", ["tofu"], game._story_food_catalog()))
	assert_eq(outside["correct"], "known")
	assert_contains(outside["explanation"], "保留未知")


func test_sugar_question_keeps_known_white_sugar_separate_from_unknown_totals() -> void:
	var game := _game(4)
	for sugar in [0, 4, 8]:
		var facts := Facts.freeze(["oatmeal"], game._story_food_catalog(), {"seasoning": "none", "added_sugar_g": sugar})
		var q := Study.question(Study.context(4, "breakfast", "home_kitchen", ["oatmeal"], game._story_food_catalog(), "recipe_preview", facts))
		assert_contains(q["choices"][1]["text"], "白糖%d克" % sugar)
		assert_contains(q["choices"][1]["text"], "总糖与其他添加糖未知")
		assert_eq(q["correct"], "known")
		assert_contains(q["explanation"], "不代表没有总糖")


func test_transfer_labels_have_different_values_and_do_not_become_eaten_food() -> void:
	var c := _context(4)
	var before := c.duplicate(true)
	var a := Study.question(c, "label_a")
	var b := Study.question(c, "label_b")
	assert_contains(a["choices"][1]["text"], "20克总糖")
	assert_contains(b["choices"][1]["text"], "18克总糖")
	assert_contains(b["body"], "不在餐盘里")
	assert_eq(a["correct"], "total_known")
	assert_eq(c, before)


func test_first_wrong_answer_survives_retry_and_stale_second_answer() -> void:
	var journal := Study.initial_state()
	assert_true(Study.begin(journal, _context(2), _back(2)))
	assert_true(Study.answer(journal, "enough"))
	assert_false(Study.answer(journal, "known"))
	assert_true(Study.retry(journal))
	assert_false(Study.retry(journal))
	assert_true(Study.answer(journal, "known"))
	var row: Dictionary = journal["entries"][0]
	assert_eq(row["attempt_count"], 2)
	assert_eq(row["retry_count"], 1)
	assert_eq(row["attempts"][0], {"choice": "enough", "correct": false, "after_help": false, "number": 1})
	assert_true(row["attempts"][1]["after_help"])
	assert_true(row["attempts"][1]["correct"])


func test_viewing_help_skipping_and_reopening_are_distinct_from_answering() -> void:
	var journal := Study.initial_state()
	var c := _context(2)
	Study.begin(journal, c, _back(2))
	Study.close(journal)
	assert_eq(journal["entries"][0]["skip_count"], 1)
	assert_eq(journal["entries"][0]["attempt_count"], 0)
	Study.begin(journal, c, _back(2))
	assert_true(Study.explain(journal))
	assert_true(journal["entries"][0]["explanation_seen"])
	assert_eq(journal["entries"][0]["attempt_count"], 0)
	Study.retry(journal)
	Study.answer(journal, "known")
	assert_true(journal["entries"][0]["attempts"][0]["after_help"])
	assert_eq(journal["entries"].size(), 1)
	assert_eq(journal["entries"][0]["view_count"], 2)


func test_retry_history_is_bounded_without_losing_first_or_latest_answer() -> void:
	var journal := Study.initial_state()
	Study.begin(journal, _context(2), _back(2))
	Study.answer(journal, "enough")
	for i in range(40):
		Study.retry(journal)
		Study.answer(journal, "known")
	var row: Dictionary = journal["entries"][0]
	assert_eq(row["attempts"].size(), Study.MAX_ATTEMPTS)
	assert_eq(row["attempts"][0]["number"], 1)
	assert_false(row["attempts"][0]["correct"])
	assert_eq(row["attempts"].back()["number"], 41)


func test_recipe_practice_returns_unsaved_plan_and_storage_without_spending() -> void:
	var game := _scene(3)
	_recipe(game, {"seasoning": "usual", "added_sugar_g": 8}, "fridge")
	var before := _materials(game)
	game._workspace.learning_button.pressed.emit()
	assert_eq(game._workspace.name, "MealStudyPage")
	assert_contains(game._workspace.title_label.text, "钠")
	game._workspace.find_child("Explain", true, false).pressed.emit()
	assert_eq(game.household_lessons["entries"][0]["attempt_count"], 0)
	game._workspace.close_button.pressed.emit()
	assert_true(game._workspace is CookingPlanStage)
	assert_eq(game._workspace.plan, {"seasoning": "usual", "added_sugar_g": 8})
	assert_eq(game._workspace.storage, "fridge")
	assert_eq(_materials(game), before)
	assert_true(game.household_lessons["active"].is_empty())


func test_ui_double_taps_do_not_reanswer_or_spend_resources() -> void:
	var game := _scene(3)
	_recipe(game)
	var before := _materials(game)
	game._workspace.learning_button.pressed.emit()
	var stale: Button = game._workspace.find_child("per100", true, false)
	stale.pressed.emit()
	stale.pressed.emit()
	assert_eq(game.household_lessons["entries"][0]["attempt_count"], 1)
	game._workspace.find_child("Retry", true, false).pressed.emit()
	game._workspace.find_child("measured", true, false).pressed.emit()
	assert_eq(game.household_lessons["entries"][0]["attempt_count"], 2)
	assert_false(game.household_lessons["entries"][0]["attempts"][0]["correct"])
	assert_eq(_materials(game), before)


func test_reference_view_before_first_answer_is_recorded_as_help() -> void:
	var game := _scene(4)
	_recipe(game)
	game._workspace.learning_button.pressed.emit()
	game._workspace.find_child("Reference", true, false).pressed.emit()
	assert_true(game.household_lessons["entries"][0]["reference_seen"])
	assert_false(game.household_lessons["entries"][0]["explanation_seen"])
	game._workspace.find_child("known", true, false).pressed.emit()
	assert_true(game.household_lessons["entries"][0]["attempts"][0]["after_help"])


func test_question_and_feedback_restore_from_json_without_recounting_views() -> void:
	for feedback in [false, true]:
		var game := _scene(4)
		_recipe(game)
		game._workspace.learning_button.pressed.emit()
		if feedback: game._workspace.find_child("total", true, false).pressed.emit()
		var encoded := Codec.encode(game.capture_game_save())
		assert_true(encoded["ok"], str(encoded))
		if not encoded["ok"]: continue
		var saved: Dictionary = Codec.decode(encoded["text"])["save"]
		var restored := _scene_from(saved)
		assert_eq(restored._workspace.name, "MealStudyPage")
		assert_eq(restored.household_lessons, saved["payload"]["household_lessons"])
		assert_eq(restored.household_lessons["active"]["page"], "feedback" if feedback else "question")
		restored._workspace.close_button.pressed.emit()
		assert_true(restored._workspace is CookingPlanStage)
		assert_eq(restored._workspace.plan["added_sugar_g"], 4)
		assert_eq(restored._workspace.storage, "fridge")


func test_reordering_the_same_plate_keeps_first_attempt_and_still_saves() -> void:
	var game := _scene(3)
	_recipe(game)
	game._workspace.learning_button.pressed.emit()
	game._workspace.find_child("per100", true, false).pressed.emit()
	game._workspace.close_button.pressed.emit()
	game._close_workspace()
	game.selected_food_ids.reverse()
	game._show_cooking_choice(game.selected_food_ids, "fridge", {"seasoning": "light", "added_sugar_g": 4})
	game._workspace.learning_button.pressed.emit()
	assert_eq(game.household_lessons["entries"].size(), 1)
	assert_eq(game.household_lessons["entries"][0]["attempt_count"], 1)
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_legacy_saves_gain_an_empty_journal_without_fabricating_attempts() -> void:
	var game := _game(3)
	var old := game.capture_game_save()
	old["payload"].erase("household_lessons")
	var decoded := Codec.decode(JSON.stringify(old))
	assert_true(decoded["ok"], str(decoded))
	assert_false(old["payload"].has("household_lessons"))
	assert_eq(decoded["save"]["payload"]["household_lessons"], Study.initial_state())
	assert_true(game.restore_game_save(decoded["save"])["ok"])
	assert_eq(game.household_lessons["entries"].size(), 0)


func test_forged_correctness_and_return_context_are_transactionally_rejected() -> void:
	var game := _scene(3)
	_recipe(game)
	game._workspace.learning_button.pressed.emit()
	game._workspace.find_child("per100", true, false).pressed.emit()
	var original := game.capture_game_save()
	var forged := original.duplicate(true)
	forged["payload"]["household_lessons"]["entries"][0]["attempts"][0]["correct"] = true
	assert_false(game.restore_game_save(forged)["ok"])
	assert_eq(game.household_lessons, original["payload"]["household_lessons"])
	forged = original.duplicate(true)
	forged["payload"]["household_lessons"]["active"]["return"]["day"] = 2
	assert_false(game.restore_game_save(forged)["ok"])
	assert_eq(game.household_lessons, original["payload"]["household_lessons"])


func test_day_observations_use_confirmed_meals_and_preserve_unknowns() -> void:
	var game := _game(3)
	game._choose_meal_source("home_kitchen")
	assert_true(game.confirm_household_food(["tofu"], "fridge", {"seasoning": "light", "added_sugar_g": 0}))
	var observation := Study.day_observation(game.today_meal_records, 3)
	assert_eq(observation["known_sodium_mg"], 750.0)
	assert_eq(observation["recorded_recipes"], 1)
	assert_contains(observation["text"], "未知")
	var outside := Study.day_observation([{"food_ids": ["tofu"], "skipped": false}], 3)
	assert_eq(outside["known_sodium_mg"], null)
	assert_contains(outside["text"], "不能")
	var skipped := Study.day_observation([{"food_ids": [], "skipped": true}], 4)
	assert_eq(skipped["known_white_sugar_g"], null)
	assert_contains(skipped["text"], "没有已确认")


func test_feasible_change_respects_current_cash_inventory_and_recipe_needs() -> void:
	var game := _scene(2)
	game._choose_meal_source("home_kitchen")
	game.hand.assign(["rice_plain", "egg", "tofu", "greens"])
	game.selected_food_ids.assign(["rice_plain"])
	var c := Study.context(2, "breakfast", "home_kitchen", ["rice_plain"], game._story_food_catalog())
	assert_false(Presenter.feasible_change(game, c).is_empty())
	for id in ["egg", "tofu", "greens"]: game.kitchen.ingredients[id] = 0
	assert_eq(Presenter.feasible_change(game, c), "")
	game._change_meal_source()
	game.state["balance"] = 2
	game._choose_meal_source("breakfast_shop")
	game.hand.assign(["steamed_bun", "egg", "milk"])
	game.selected_food_ids.assign(["steamed_bun"])
	c = Study.context(2, "breakfast", "breakfast_shop", ["steamed_bun"], game._story_food_catalog())
	assert_eq(Presenter.feasible_change(game, c), "")
	assert_eq(game.state["balance"], 2)


func test_confirmed_learning_context_is_frozen_and_cancelled_preview_is_not_a_meal() -> void:
	var game := _scene(4)
	_recipe(game)
	game._workspace.learning_button.pressed.emit()
	game._workspace.close_button.pressed.emit()
	assert_true(game.today_meal_records.is_empty())
	game._workspace.confirm_button.pressed.emit()
	assert_eq(game.today_meal_records.size(), 1)
	var frozen: Dictionary = game.today_meal_records[0]["learning_facts"].duplicate(true)
	assert_eq(frozen["scope"], "confirmed")
	assert_eq(frozen["recipe_facts"]["white_sugar_added_g"], 4)
	game.kitchen.history[0]["recipe_facts"]["white_sugar_added_g"] = 999
	assert_eq(game.today_meal_records[0]["learning_facts"], frozen)


func test_campus_remains_isolated_and_new_run_clears_the_journal() -> void:
	var game := _scene(3)
	_recipe(game)
	game._workspace.learning_button.pressed.emit()
	game._workspace.find_child("Explain", true, false).pressed.emit()
	game._workspace.close_button.pressed.emit()
	game._close_workspace()
	game.story_id = "campus_exam"
	game.start_new_run()
	assert_true(game.household_lessons.is_empty())
	assert_false(Presenter.open_reference(game))
	game._choose_meal_source("cafeteria")
	assert_false(game._active_stage is HouseholdMealStage)
	game.story_id = "choir_week"
	game.start_new_run()
	assert_eq(game.household_lessons, Study.initial_state())


func test_new_study_copy_has_all_required_glyphs() -> void:
	var missing := ""
	for path in ["res://scripts/stories/HouseholdMealLearning.gd", "res://scripts/stories/HouseholdStudyPresenter.gd"]:
		for character in FileAccess.get_file_as_string(path):
			var code := character.unicode_at(0)
			if code >= 0x3400 and code <= 0x9fff and not HouseholdUI.BODY_FONT.has_char(code) and not missing.contains(character): missing += character
	assert_eq(missing, "", "Missing study glyphs: " + missing)


func test_day_observation_is_frozen_in_history_and_week_recap() -> void:
	var game := _game(3)
	var observed: Dictionary = game.run_history[1]["learning_observation"].duplicate(true)
	assert_eq(observed["eaten"], 3)
	assert_contains(game._build_week_recap()["detail_text"], observed["text"])
	game.today_meal_records.append({"food_ids": [], "skipped": true})
	game.household_lessons["entries"].clear()
	assert_eq(game.run_history[1]["learning_observation"], observed)


func test_fridge_practice_reads_the_frozen_recipe_without_consuming_it() -> void:
	var game := _scene(3)
	_recipe(game, {"seasoning": "usual", "added_sugar_g": 8}, "fridge")
	game._workspace.confirm_button.pressed.emit()
	game._skip_action()
	game._choose_meal_source("home_fridge")
	game._on_food_toggled("tofu")
	game._on_food_toggled("milk")
	var before := _materials(game)
	game._active_stage.learning_button.pressed.emit()
	var c: Dictionary = game.household_lessons["entries"][0]["context"]
	assert_eq(c["scope"], "stock_preview")
	assert_eq(c["recipe_facts"]["sodium_from_added_seasonings_mg"], 1500.0)
	assert_eq(c["recipe_facts"]["unrecorded_items"], 1)
	assert_contains(Study.question(c)["body"], "1项食物")
	assert_eq(_materials(game), before)
	assert_true(Codec.encode(game.capture_game_save())["ok"])
	game._workspace.close_button.pressed.emit()
	assert_true(game.confirm_household_food(["tofu", "milk"]))
	assert_eq(game.today_meal_records.back()["recipe_facts"], c["recipe_facts"])


func test_study_controls_and_long_feedback_fit_desktop_and_portrait_layouts() -> void:
	for size in [Vector2i(720, 1280), Vector2i(853, 1280), Vector2i(1920, 1080)]:
		for day in [2, 3, 4]:
			var game := _scene(day, size)
			_recipe(game)
			game._workspace.close_button.pressed.emit()
			_layout(game)
			var stage := game._active_stage as HouseholdMealStage
			assert_true(stage.paper_panel.get_global_rect().encloses(stage.learning_button.get_global_rect()), "Meal study entry escaped at %s day %d" % [size, day])
			assert_true(stage.food_scroll.size.y > 100, "Food rail became too small at %s day %d: scroll=%s paper=%s selected=%s" % [size, day, stage.food_scroll.size, stage.paper_panel.size, stage._selected_strip.get_combined_minimum_size()])
			stage.learning_button.pressed.emit()
			_layout(game)
			_layout(game)
			var page := game._workspace
			var paper := page.paper_panel.get_global_rect()
			assert_true(game.get_viewport_rect().encloses(paper), "Study paper escaped at %s day %d" % [size, day])
			assert_true(paper.encloses(page.footer.get_global_rect()))
			assert_true(page.scroll.get_global_rect().end.y <= page.footer.get_global_rect().position.y)
			assert_true(page.footer.get_global_rect().encloses(page.close_button.get_global_rect()))
			page.find_child("Reference", true, false).pressed.emit()
			_layout(game)
			assert_true(paper.encloses(page.footer.get_global_rect()), "Expanded reference displaced footer")
			page.find_child("Explain", true, false).pressed.emit()
			_layout(game)
			_layout(game)
			assert_true(game._workspace.paper_panel.get_global_rect().encloses(game._workspace.footer.get_global_rect()), "Long feedback displaced footer")


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
