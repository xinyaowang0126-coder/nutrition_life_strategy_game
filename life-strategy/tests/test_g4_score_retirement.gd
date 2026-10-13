@tool
extends McpTestSuite

const Data := preload("res://scripts/GameData.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Reserve := preload("res://scripts/systems/GameReserveCalculator.gd")
const Gameplay := preload("res://scripts/systems/RecoveryGameplayService.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Facts := preload("res://scripts/systems/MealRecordPresenter.gd")
const Ledger := preload("res://scripts/systems/NutritionLedger.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")


func suite_name() -> String:
	return "g4_score_retirement"


func test_all_real_source_phase_candidates_build_without_a_diet_score() -> void:
	var count := 0
	for source_id in ["cafeteria", "takeout", "convenience_store", "dorm_storage"]:
		for phase in ["breakfast", "lunch", "dinner"]:
			for id in Data.get_food_ids_for_context(source_id, phase):
				var record := Resolver.build_record(phase, Data.get_meal_source(source_id), [Data.get_food(id)])
				assert_false(record.has("quality"))
				assert_false(record.has("rating"))
				assert_eq(record["food_ids"], [id])
				count += 1
	assert_gt(count, 23)


func test_skip_preserves_exact_resource_cost_and_explicit_fact_without_quality() -> void:
	for phase in ["breakfast", "lunch", "dinner"]:
		var record := Resolver.build_skipped_record(phase)
		assert_eq(record["stat_delta"], {"satiety": 0, "energy": -2, "mood": -2, "stress": 3, "study_progress": 0})
		assert_eq(record["total_cost"], 0)
		assert_true(record["skipped"])
		assert_false(record.has("quality"))


func test_new_records_keep_cash_fee_stock_and_frozen_names() -> void:
	var food := Data.get_food("apple")
	var source := Data.get_meal_source("takeout")
	var cash := Resolver.build_record("lunch", source, [food], {})
	assert_eq(cash["total_cost"], food["cost"] + source["fee"])
	assert_eq(cash["source_name"], source["name"])
	assert_eq(cash["food_names"], [food["name"]])
	var stock := Resolver.build_record("lunch", Data.get_meal_source("dorm_storage"), [food], {})
	assert_true(stock["uses_stock"])
	assert_eq(stock["total_cost"], 0)
	assert_eq(stock["food_names"], cash["food_names"])
	assert_false(stock.has("quality"))


func test_food_score_injection_never_enters_new_record_or_mutates_inputs() -> void:
	var food := Data.get_food("apple")
	var source := Data.get_meal_source("cafeteria")
	var expected := Resolver.build_record("lunch", source, [food], {})
	for value in [null, false, 100, "旧评分", [], {"score": 99}]:
		var poisoned := food.duplicate(true)
		poisoned["quality"] = value
		poisoned["nutrition_score"] = value
		var before := poisoned.duplicate(true)
		assert_eq(Resolver.build_record("lunch", source, [poisoned], {}), expected)
		assert_eq(poisoned, before)


func test_archived_scores_are_preserved_but_do_not_change_fact_or_health_reads() -> void:
	var old := Resolver.build_record("breakfast", Data.get_meal_source("cafeteria"), [Data.get_food("apple")])
	old["quality"] = 99
	var before := old.duplicate(true)
	var clean := old.duplicate(true)
	clean.erase("quality")
	assert_eq(Facts.capture([], [old], 1), Facts.capture([], [clean], 1))
	assert_eq(Ledger.summarize([old]), Ledger.summarize([clean]))
	assert_eq(Snapshot.legacy(1, old), Snapshot.legacy(1, clean))
	assert_eq(old, before)
	assert_eq(old["quality"], 99)


func test_retired_diet_score_methods_are_unavailable_on_the_production_resolver() -> void:
	var resolver := Resolver.new()
	for name in ["food_quality", "plate_quality", "day_quality", "average_scores"]:
		assert_false(resolver.has_method(name))
	assert_true(resolver.has_method("build_record"))
	assert_true(resolver.has_method("calculate_stability"))


func test_resource_calculator_matches_legacy_positional_calls_and_ignores_extra_scores() -> void:
	for day in [1, 6, 7]:
		for energy in [0, 15, 16, 100]:
			for satiety in [0, 19, 20, 100]:
				var state := _stats()
				state["energy"] = energy
				state["satiety"] = satiety
				var expected := Reserve.calculate(state, day, 7, 7.0)
				for quality in [0, 25, 95, 100]:
					assert_eq(Resolver.calculate_stability(state, quality, day, 7, 7.0), expected)
				state["quality"] = {"bad": "旧评分"}
				state["nutrition_score"] = 100
				assert_eq(Reserve.calculate(state, day, 7, 7.0), expected)


func test_current_recovery_path_and_legacy_shim_share_valid_results() -> void:
	var record := _recovery()
	for quality in [0, 25, 95, 100]:
		var current := Gameplay.calculate_stability_from_recovery(_stats(), 1, 7, record)
		assert_true(current["valid"])
		assert_eq(Gameplay.calculate_stability(_stats(), quality, 1, 7, record), current)
	for value in [null, false, "95", -1, 101, NAN, INF]:
		assert_false(Gameplay.calculate_stability(_stats(), value, 1, 7, record)["valid"])
	assert_false(Gameplay.calculate_stability_from_recovery(_stats(), 1, 7, {})["valid"])


func test_normal_confirm_skip_and_settlement_never_produce_new_quality_fields() -> void:
	var game := GameScene.instantiate() as GameRootV2
	track(game)
	game.health_history_path = ""
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	game.new_day_popup.hide_popup(false)
	game._choose_meal_source("cafeteria")
	game._on_food_toggled(game.hand[0])
	game._confirm_food(game.selected_food_ids.duplicate())
	game._skip_action()
	for phase in ["lunch", "dinner"]:
		game._skip_meal()
		game._skip_action()
	game._choose_sleep("sleep_early")
	assert_eq(game.phase, "summary")
	for record in game.run_history[0]["meals"]:
		assert_false(record.has("quality"))
	assert_eq(game.run_history[0]["nutrition"]["metrics"]["eaten_meals"], 1)
	assert_eq(game.run_history[0]["nutrition"]["metrics"]["skipped_meals"], 2)
	assert_false(game._health_catalog_loaded)


func _stats() -> Dictionary:
	return {"energy": 60, "mood": 60, "stress": 40, "satiety": 50, "study_progress": 70, "balance": 120}


func _recovery() -> Dictionary:
	var card := Data.get_sleep_option("sleep_early")
	var snapshot := {"id": "sleep_early"}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		snapshot[key] = card[key]
	return Recovery.settle(1, {"energy": 45, "stress": 45}, snapshot, {})["recovery_state"]
