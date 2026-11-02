@tool
extends McpTestSuite

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Cards := preload("res://scripts/CardDataStore.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Session := preload("res://scripts/stories/StorySession.gd")
const Study := preload("res://scripts/stories/CampusPresenter.gd")
const Journal := preload("res://scripts/stories/CampusStudyJournal.gd")
const Learning := preload("res://scripts/stories/CampusMealLearning.gd")
const Resources := preload("res://scripts/stories/CampusResourcePlan.gd")
const ResourceUI := preload("res://scripts/stories/CampusResourcePresenter.gd")


func suite_name() -> String: return "campus_depth"


func _game() -> GameRootV2:
	var game := Controller.new()
	track(game)
	game._deck_service = Deck.new(42)
	game.health_history_path = ""
	game.start_new_run()
	return game


func _ui(size: Vector2i = Vector2i(1280, 720)) -> GameRootV2:
	var viewport := SubViewport.new()
	viewport.size = size
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	Session.request("campus_exam")
	var game := Scene.instantiate() as GameRootV2
	viewport.add_child(game)
	game.new_day_popup.hide_popup(false)
	game._on_new_day_continue()
	game._choose_meal_source("cafeteria")
	return game


func _choose(game: GameRootV2, ids: Array) -> void:
	for id in game.selected_food_ids.duplicate(): game._on_food_toggled(id)
	for id in ids: game._on_food_toggled(id)


func _day(game: GameRootV2) -> void:
	for meal in ["breakfast", "lunch", "dinner"]:
		game._choose_meal_source("cafeteria")
		var plate: Array[String] = []
		for id in ["rice_plain", "oatmeal", "egg", "tofu", "greens"]:
			if game.hand.has(id) and plate.size() < game._source_selection_limit("cafeteria"): plate.append(id)
		if plate.is_empty(): plate.append(game.hand[0])
		game._confirm_food(plate)
		var action: String = {"breakfast": "study", "lunch": "walk", "dinner": "nap"}[meal]
		if game._can_use_action(game._effective_action(action)): game._apply_action(action)
		else: game._skip_action()
	game._choose_sleep("sleep_early")


func test_help_close_reopen_and_restore_cannot_become_an_independent_answer() -> void:
	var game := _ui()
	_choose(game, [game.hand[0]])
	assert_true(Study.open_study(game))
	var context: Dictionary = game.campus_week["active"]["context"].duplicate(true)
	game._story_dialog._buttons.get_node("explain").pressed.emit()
	game._story_dialog._buttons.get_node("back").pressed.emit()
	assert_eq(Journal.entry(game.campus_week["journal"], "composition", context)["help_views"], 1)
	var saved := Codec.encode(game.capture_game_save())
	assert_true(saved["ok"], str(saved))
	var restored := _ui(Vector2i(640, 960))
	assert_true(restored.restore_game_save(saved["save"])["ok"])
	Study.open_study(restored)
	assert_true(restored.campus_week["active"]["help"])
	var q := Learning.question(restored.campus_week["active"]["context"])
	restored._story_dialog._buttons.get_node(q["correct"]).pressed.emit()
	var row := Journal.entry(restored.campus_week["journal"], "composition", context)
	assert_true(row["first_answer"]["after_help"])
	assert_eq(row["first_answer"]["independence"], "after_help")
	assert_true(Codec.encode(restored.capture_game_save())["ok"])


func test_first_answer_retry_skip_and_reordered_menu_are_preserved() -> void:
	Cards.ensure_loaded()
	var journal := Journal.initial_state()
	var a := Learning.context(1, "breakfast", "cafeteria", ["egg", "rice_plain"], Cards.foods)
	var b := Learning.context(2, "lunch", "cafeteria", ["rice_plain", "egg"], Cards.foods)
	Journal.open(journal, "composition", a)
	Journal.answer(journal, "composition", a, {"choice": "enough"}, false)
	Journal.help(journal, "composition", a)
	Journal.retry(journal, "composition", a)
	Journal.skip(journal, "composition", a)
	Journal.open(journal, "composition", b)
	Journal.answer(journal, "composition", b, {"choice": "known"}, true)
	var row := Journal.entry(journal, "composition", b)
	assert_eq(journal["entries"].size(), 1)
	assert_false(row["first_answer"]["correct"])
	assert_eq(row["first_answer"]["independence"], "independent")
	assert_true(row["answers"][1]["after_help"])
	assert_eq(row["retries"], 1)
	assert_eq(row["skips"], 1)
	assert_true(Journal.valid(journal))


func test_v1_migration_preserves_unknown_help_history_without_activating_new_events() -> void:
	var game := _ui()
	_choose(game, [game.hand[0]])
	var save := game.capture_game_save()
	var old: Dictionary = save["payload"]["campus_week"]
	old["version"] = 1
	old.erase("journal")
	old.erase("resources")
	assert_true(game.restore_game_save(save)["ok"])
	assert_true(game.campus_week["journal"]["legacy"])
	Study.open_study(game)
	var c: Dictionary = game.campus_week["active"]["context"]
	game._story_dialog._buttons.get_node(Learning.question(c)["correct"]).pressed.emit()
	assert_eq(Journal.entry(game.campus_week["journal"], "composition", c)["first_answer"]["independence"], "unknown")
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_long_retry_history_keeps_first_answer_and_latest_response() -> void:
	Cards.ensure_loaded()
	var c := Learning.context(1, "breakfast", "cafeteria", ["egg"], Cards.foods)
	var journal := Journal.initial_state()
	for number in range(80):
		Journal.answer(journal, "composition", c, {"choice": "known"}, true)
		Journal.help(journal, "composition", c)
	var row := Journal.entry(journal, "composition", c)
	assert_eq(row["answers"].size(), 65)
	assert_eq(row["first_answer"]["number"], 1)
	assert_eq(row["answers"].back()["number"], 80)
	assert_eq(row["first_answer"]["independence"], "independent")
	assert_true(Journal.valid(journal))


func test_normal_tray_confirms_a_meal_once_without_an_exercise_entry() -> void:
	var game := _ui()
	assert_true(game._active_stage.find_child("CampusStudy", true, false) == null)
	_choose(game, [game.hand[0]])
	var cost := game._selected_meal_total()
	var balance: int = game.state["balance"]
	var ids := game.selected_food_ids.duplicate()
	game._confirm_food(ids)
	assert_eq(game.today_meal_records.size(), 1)
	assert_eq(game.state["balance"], balance - cost)
	assert_true(game.campus_week["active"].is_empty())
	game._confirm_food(ids)
	assert_eq(game.today_meal_records.size(), 1)
	Study.notebook(game)
	assert_true(game._workspace.find_child("meal_task", true, false) == null)
	assert_true(game._workspace.find_child("resources", true, false) == null)
	assert_true(game._workspace.find_child("plan", true, false) != null)


func test_reserved_stock_is_unavailable_early_and_explicit_release_does_not_add_food() -> void:
	var game := _game()
	game._choose_meal_source("dorm_storage")
	var inventory := game.dorm_inventory.duplicate(true)
	var resources: Dictionary = game.campus_week["resources"]
	assert_true(Resources.reserve_stock(resources, game.dorm_inventory, "milk", 2, "breakfast", 1, game.phase))
	assert_eq(game._stock_count("milk", "dorm_storage"), 0)
	assert_eq(game._visible_stock()["milk"], 0)
	game._confirm_food(["milk"])
	assert_true(game.today_meal_records.is_empty())
	assert_eq(game.dorm_inventory, inventory)
	assert_true(Codec.encode(game.capture_game_save())["ok"])
	assert_true(Resources.release_stock(resources, 1, 1, game.phase))
	assert_eq(game._stock_count("milk", "dorm_storage"), inventory["milk"])
	assert_eq(game.dorm_inventory, inventory)
	assert_false(Resources.release_stock(resources, 1, 1, game.phase))


func test_reserved_food_is_guaranteed_in_the_target_hand_and_consumed_once() -> void:
	var game := _game()
	assert_true(Resources.reserve_stock(game.campus_week["resources"], game.dorm_inventory, "milk", 2, "breakfast", 1, game.phase))
	_day(game)
	game._on_summary_advanced()
	assert_eq(game.day, 2)
	assert_eq(game._stock_count("milk", "dorm_storage"), 1)
	game._choose_meal_source("dorm_storage")
	assert_true(game.hand.has("milk"))
	game._confirm_food(["milk"])
	assert_eq(game.campus_week["resources"]["stock"][0]["status"], "used")
	assert_eq(game.dorm_inventory["milk"], 0)
	game._confirm_food(["milk"])
	assert_eq(game.dorm_inventory["milk"], 0)
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_changing_or_skipping_reserved_meal_releases_without_consuming() -> void:
	for skipped in [true, false]:
		var resources := Resources.initial_state()
		assert_true(Resources.reserve_stock(resources, {"milk": 1}, "milk", 2, "breakfast", 1, "sleep"))
		Resources.settle(resources, 2, {"phase": "breakfast", "source_id": "" if skipped else "cafeteria", "food_ids": [] if skipped else ["egg"], "skipped": skipped})
		assert_eq(resources["stock"][0]["status"], "skipped" if skipped else "changed")
		assert_eq(Resources.quantity(resources, {"milk": 1}, "milk", 2, "lunch"), 1)


func test_cash_reservation_blocks_real_meals_and_paid_actions_until_released() -> void:
	var game := _game()
	var resources: Dictionary = game.campus_week["resources"]
	assert_true(Resources.reserve_budget(resources, 150, 2, 1, game.phase, game.state["balance"]))
	assert_eq(game._spendable_balance(), 0)
	assert_eq(game.state["balance"], 150)
	assert_false(game._source_disabled_reason("cafeteria", "breakfast").is_empty())
	assert_eq(game._source_disabled_reason("dorm_storage", "breakfast"), "")
	game._choose_meal_source("dorm_storage")
	game._confirm_food([game.hand[0]])
	assert_false(game._can_use_action(game._effective_action("restock_pantry")))
	assert_true(Resources.release_budget(resources, 1, game.day, game.phase))
	assert_eq(game._spendable_balance(), 150)
	assert_true(game._can_use_action(game._effective_action("restock_pantry")))
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_cash_reservation_unlocks_on_start_day_and_counts_actual_spending_once() -> void:
	var game := _game()
	var resources: Dictionary = game.campus_week["resources"]
	Resources.reserve_budget(resources, 40, 2, 1, game.phase, game.state["balance"])
	assert_eq(game._spendable_balance(), 110)
	_day(game)
	game._on_summary_advanced()
	assert_eq(game._spendable_balance(), game.state["balance"])
	_day(game)
	var expected := 0
	for meal in game.today_meal_records: expected += int(meal["total_cost"])
	for action in game.today_action_records: expected += int(action["cost"])
	assert_eq(Resources.spent(resources["budgets"][0], game.capture_game_save()["payload"]), expected)
	assert_true(Codec.encode(game.capture_game_save())["ok"])
	assert_false(Resources.reserve_budget(resources, 20, 1, game.day, game.phase, game.state["balance"]))


func test_corrupt_reservations_are_rejected_transactionally() -> void:
	var game := _ui()
	var resources: Dictionary = game.campus_week["resources"]
	Resources.reserve_stock(resources, game.dorm_inventory, "milk", 2, "breakfast", 1, game.phase)
	var before := game.capture_game_save()
	var bad := before.duplicate(true)
	var duplicate: Dictionary = bad["payload"]["campus_week"]["resources"]["stock"][0].duplicate(true)
	duplicate["id"] = 2
	duplicate["meal"] = "lunch"
	bad["payload"]["campus_week"]["resources"]["stock"].append(duplicate)
	assert_false(game.restore_game_save(bad)["ok"])
	assert_eq(game.capture_game_save()["payload"], before["payload"])



func test_resource_panel_buttons_persist_reservations_and_ignore_retired_callbacks() -> void:
	var game := _ui()
	assert_true(ResourceUI.open(game, {"day": 2, "meal": "breakfast"}))
	game._workspace.find_child("source_dorm_storage", true, false).pressed.emit()
	var old: Button = game._workspace.find_child("reserve_milk", true, false)
	assert_true(old != null)
	old.pressed.emit()
	assert_eq(game.campus_week["resources"]["stock"].size(), 1)
	old.pressed.emit()
	assert_eq(game.campus_week["resources"]["stock"].size(), 1)
	var button := game._workspace.find_child("release_stock_1", true, false) as Button
	button.pressed.emit()
	assert_eq(game.campus_week["resources"]["stock"][0]["status"], "released")
	game._workspace.close_button.pressed.emit()
	assert_false(is_instance_valid(game._workspace))
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_ending_cannot_create_or_release_resource_reservations() -> void:
	var resources := Resources.initial_state()
	Resources.reserve_stock(resources, {"milk": 1}, "milk", 2, "breakfast", 1, "sleep")
	Resources.reserve_budget(resources, 40, 2, 1, "sleep", 150)
	var before := resources.duplicate(true)
	assert_false(Resources.reserve_stock(resources, {"milk": 1}, "milk", 3, "breakfast", 2, "ending"))
	assert_false(Resources.reserve_budget(resources, 10, 1, 2, "ending", 150))
	assert_false(Resources.release_stock(resources, 1, 2, "ending"))
	assert_false(Resources.release_budget(resources, 1, 2, "ending"))
	assert_eq(resources, before)
	assert_contains(Resources.budget_text(resources["budgets"][0], {"day": 1, "phase": "ending", "run_history": [], "today_meal_records": [], "today_action_records": []}), "预留未启用")


func test_adjacent_budget_periods_are_allowed_without_overlapping_or_double_counting() -> void:
	var game := _game()
	var resources: Dictionary = game.campus_week["resources"]
	Resources.reserve_budget(resources, 20, 1, 1, game.phase, game.state["balance"])
	_day(game)
	game._on_summary_advanced()
	_day(game)
	assert_true(Resources.reserve_budget(resources, 20, 2, 2, game.phase, game.state["balance"]))
	assert_eq(resources["budgets"].size(), 2)
	assert_eq(Resources.locked_money(resources, 2), 20)
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_switching_destination_releases_only_that_meal_reservation() -> void:
	var game := _ui()
	ResourceUI.open(game, {"day": 2, "meal": "breakfast"})
	game._workspace.find_child("source_dorm_storage", true, false).pressed.emit()
	game._workspace.find_child("reserve_milk", true, false).pressed.emit()
	var inventory := game.dorm_inventory.duplicate(true)
	assert_eq(game._stock_count("milk", "dorm_storage"), 0)
	game._workspace.find_child("source_cafeteria", true, false).pressed.emit()
	assert_eq(game.campus_week["resources"]["stock"][0]["status"], "released")
	assert_eq(game._stock_count("milk", "dorm_storage"), inventory["milk"])
	assert_eq(game.dorm_inventory, inventory)
	assert_true(Codec.encode(game.capture_game_save())["ok"])


func test_plan_source_stock_and_budget_share_one_page_without_eating_or_advancing() -> void:
	var game := _ui()
	var before: Dictionary = game.capture_game_save()["payload"]
	assert_true(ResourceUI.open(game, {"day": 2, "meal": "breakfast"}))
	var page: Control = game._workspace
	game._workspace.find_child("source_dorm_storage", true, false).pressed.emit()
	game._workspace.find_child("reserve_milk", true, false).pressed.emit()
	game._workspace.find_child("budget_days_2", true, false).pressed.emit()
	game._workspace.find_child("budget_2_40", true, false).pressed.emit()
	assert_eq(game._workspace, page)
	assert_contains(ResourceUI.summary(game, {"day": 2, "meal": "breakfast"}), "牛奶")
	assert_eq(game._spendable_balance(), before["state"]["balance"] - 40)
	assert_eq(game.state, before["state"])
	assert_eq(game.dorm_inventory, before["dorm_inventory"])
	assert_true(game.today_meal_records.is_empty())
	assert_eq(game.day, 1)
	game._workspace.close_button.pressed.emit()
	assert_true(game.campus_week["active"].is_empty())
	assert_true(Codec.encode(game.capture_game_save())["ok"])
