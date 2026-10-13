@tool
extends McpTestSuite

const Data := preload("res://scripts/GameData.gd")
const Cards := preload("res://scripts/CardDataStore.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Events := preload("res://scripts/systems/WeeklyEventService.gd")
const Legacy := preload("res://scripts/GameRoot.gd")
const Current := preload("res://scripts/ui_v2/GameRootV2.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const LegacyScene := preload("res://scenes/game/GameRoot.tscn")
const RETIRED := ["burden", "diet_burden", "character_health"]


func suite_name() -> String:
	return "recovery_retirement"


func test_all_card_catalogues_and_starting_state_have_no_retired_fields() -> void:
	Data.ensure_loaded()
	_assert_clean(Data.get_starting_stats())
	for catalogue in [Cards.foods, Cards.meal_sources, Cards.actions, Cards.sleep_options]:
		for id in catalogue:
			_assert_clean(catalogue[id])
	for path in [Cards.FOODS_XML, Cards.MEAL_SOURCES_XML, Cards.ACTIONS_XML, Cards.SLEEP_OPTIONS_XML]:
		assert_false(FileAccess.get_file_as_string(path).contains(" burden="))


func test_xml_parser_discards_injected_retired_attributes() -> void:
	var parser := XMLParser.new()
	assert_eq(parser.open_buffer('<food id="probe" energy="4" burden="99" diet_burden="98" character_health="97"/>'.to_utf8_buffer()), OK)
	assert_eq(parser.read(), OK)
	var parsed := Cards._read_attributes(parser)
	assert_eq(parsed["energy"], 4)
	_assert_clean(parsed)


func test_meal_and_skip_deltas_ignore_retired_food_and_source_properties() -> void:
	var food := Data.get_food("tomato")
	var source := Data.get_meal_source("cafeteria")
	var original := Resolver.build_record("lunch", source, [food])
	for key in RETIRED:
		food[key] = 999
		source[key] = -999
	var injected := Resolver.build_record("lunch", source, [food])
	assert_eq(injected, original)
	_assert_clean(injected["stat_delta"])
	_assert_clean(Resolver.build_skipped_record("lunch")["stat_delta"])


func test_event_updates_cannot_write_or_retain_old_state_fields() -> void:
	var state := Data.get_starting_stats()
	for key in RETIRED:
		state[key] = 10
	Events._apply_numeric_delta(state, {"energy": 3, "burden": -2, "diet_burden": 99, "character_health": 88}, true)
	assert_eq(state["energy"], Data.STARTING_STATS["energy"] + 3)
	_assert_clean(state)


func test_both_controllers_reject_retired_deltas_and_sanitize_old_state() -> void:
	for game in [_game(false), _game(true)]:
		var energy: int = game.state["energy"]
		for key in RETIRED:
			game.state[key] = 44
		game._apply_stat_delta({"energy": 1, "burden": 1, "diet_burden": 2, "character_health": 3})
		game._clamp_stats()
		assert_eq(game.state["energy"], energy + 1)
		_assert_clean(game.state)


func test_v1_successful_actions_stock_and_limits_are_recorded() -> void:
	var game = _game(true)
	game.phase = "breakfast_action"
	game.state["energy"] = 0
	game._apply_action("study")
	assert_true(game.today_action_records.is_empty())
	game.state["energy"] = 90
	var stock: int = game.dorm_inventory["oatmeal"]
	game._apply_action("restock_pantry")
	assert_eq(game.today_action_records.size(), 1)
	assert_eq(game.dorm_inventory["oatmeal"], stock + 1)
	assert_eq(game.state["balance"], 142)
	game.phase = "lunch_action"
	game._apply_action("restock_pantry")
	assert_eq(game.today_action_records.size(), 1)
	game._apply_action("drink_water")
	game._skip_action()
	game.phase = "dinner_action"
	game._apply_action("drink_water")
	game._skip_action()
	game._choose_sleep("scroll_phone")
	assert_eq(game.pending_recovery_state["inputs"]["action_counts"], {"restock_pantry": 1, "drink_water": 2})
	_assert_clean(game.state)


func test_v1_sleep_and_day_end_are_idempotent_and_freeze_independent_records() -> void:
	var game = _game(true)
	_fill_meals(game)
	game.phase = "sleep"
	game._choose_sleep("sleep_early")
	assert_true(Recovery.validate(game.pending_recovery_state)["valid"])
	assert_eq(game.run_history.size(), 1)
	var state: Dictionary = game.state.duplicate(true)
	var history: Array = game.run_history.duplicate(true)
	game._finish_day()
	game._choose_sleep("night_study")
	assert_eq(game.state, state)
	assert_eq(game.run_history, history)
	var copy: Dictionary = game.get_pending_recovery_state()
	copy["sleep_snapshot"]["energy"] = -99
	assert_true(Recovery.validate(game.run_history[0]["recovery_state"])["valid"])


func test_v1_consumes_frozen_recovery_and_event_once_with_study_yield() -> void:
	var game = _game(true)
	game.state.merge({"energy": 60, "stress": 40, "mood": 60, "satiety": 50, "study_progress": 70}, true)
	_fill_meals(game)
	game.phase = "sleep"
	game._choose_sleep("sleep_early")
	var end: Dictionary = game.state.duplicate(true)
	game._next_day()
	assert_eq(game.day, 2)
	assert_eq(game.current_recovery_state["condition"], "rested")
	assert_eq(game.state["energy"], mini(100, int(end["energy"]) + 3))
	assert_eq(game.state["stress"], maxi(0, int(end["stress"]) - 4))
	assert_eq(game._effective_action("study")["study"], 11)
	var state: Dictionary = game.state.duplicate(true)
	game._start_day()
	game._next_day()
	assert_eq(game.state, state)
	assert_eq(game.day, 2)


func test_v1_invalid_recovery_blocks_advancement_without_a_fallback() -> void:
	var game = _game(true)
	_fill_meals(game)
	game.phase = "sleep"
	game._choose_sleep("sleep_early")
	var state: Dictionary = game.state.duplicate(true)
	game.run_history[0]["recovery_state"] = Recovery.unavailable("legacy_unknown", "LEGACY_RECOVERY_NOT_RECORDED")
	game._next_day()
	assert_eq(game.day, 1)
	assert_eq(game.phase, "summary")
	assert_eq(game.state, state)
	assert_false(game.recovery_diagnostics.is_empty())


func test_both_versions_reach_seven_days_with_valid_clean_recovery_history() -> void:
	for legacy in [false, true]:
		var game = _game(legacy)
		game.state["balance"] = 500 # Lifecycle isolation; budget coverage lives in balance diagnostics.
		var steps := 0
		while game.phase != "ending" and steps < 160:
			steps += 1
			if game.phase.ends_with("_source"):
				game._choose_meal_source("cafeteria")
				if legacy:
					game.selected_food_indices.assign([0, 1, 2])
					game._confirm_food()
				else:
					game._confirm_food(game.hand.slice(0, 3))
			elif game.phase.ends_with("_action"):
				var action_id: String = {"breakfast_action": "study", "lunch_action": "walk", "dinner_action": "nap"}[game.phase]
				game._apply_action(action_id)
			elif game.phase == "sleep":
				game._choose_sleep("sleep_early")
			elif game.phase == "summary":
				game._next_day()
			else:
				break
		assert_eq(game.day, 7)
		assert_eq(game.phase, "ending")
		assert_eq(game.run_history.size(), 7)
		assert_true(game.recovery_diagnostics.is_empty(), str(game.recovery_diagnostics))
		_assert_clean(game.state)
		for record in game.run_history:
			assert_true(Recovery.validate(record["recovery_state"])["valid"])
			_assert_clean(record["end_state"])
			for action in record["actions"]:
				_assert_clean(action["stat_delta"])
			for meal in record["meals"]:
				_assert_clean(meal["stat_delta"])


func test_legacy_scene_runs_without_retired_numeric_bars() -> void:
	var game = LegacyScene.instantiate()
	track(game)
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	_assert_clean(game.state)
	assert_false(game.STAT_ORDER.has("diet_burden"))
	game.phase = "breakfast_action"
	game._apply_action("nap")
	assert_eq(game.today_action_records.size(), 1)


func _game(legacy: bool):
	var game = Legacy.new() if legacy else Current.new()
	track(game)
	game._deck_service = Deck.new(20260711)
	if not legacy:
		game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
		game.health_history_path = ""
	game.start_new_run()
	return game


func _fill_meals(game) -> void:
	for phase in ["breakfast", "lunch", "dinner"]:
		var foods: Array[Dictionary] = [Data.get_food("rice_plain"), Data.get_food("egg"), Data.get_food("tomato")]
		game.today_meal_records.append(Resolver.build_record(phase, Data.get_meal_source("cafeteria"), foods))


func _assert_clean(data: Dictionary) -> void:
	for key in RETIRED:
		assert_false(data.has(key), "retired field remains: " + key)
