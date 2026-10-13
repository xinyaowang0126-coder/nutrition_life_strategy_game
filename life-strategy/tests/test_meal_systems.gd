@tool
extends McpTestSuite

const GameDataScript := preload("res://scripts/GameData.gd")
const MealDeckServiceScript := preload("res://scripts/systems/MealDeckService.gd")
const MealResolverScript := preload("res://scripts/systems/MealResolver.gd")
const NutritionLedgerScript := preload("res://scripts/systems/NutritionLedger.gd")


func suite_name() -> String:
	return "meal_systems"


func suite_setup(_ctx: Dictionary) -> void:
	GameDataScript.ensure_loaded()


func test_seeded_hands_are_repeatable_and_unique() -> void:
	var candidates := GameDataScript.get_food_ids_for_context("convenience_store", "lunch")
	var first := MealDeckServiceScript.new(20260710)
	var second := MealDeckServiceScript.new(20260710)
	var hand_a: Array[String] = first.build_hand(candidates, 5)
	var hand_b: Array[String] = second.build_hand(candidates, 5)
	assert_eq(hand_a, hand_b)
	var unique := {}
	for id in hand_a:
		unique[id] = true
	assert_eq(unique.size(), hand_a.size())


func test_dorm_hand_respects_inventory() -> void:
	var candidates := GameDataScript.get_food_ids_for_context("dorm_storage", "breakfast")
	var service := MealDeckServiceScript.new(17)
	var inventory := {"oatmeal": 0, "instant_noodles": 2, "milk": 0, "apple": 1}
	var hand: Array[String] = service.build_hand(candidates, 4, inventory, true)
	assert_false(hand.has("oatmeal"))
	assert_false(hand.has("milk"))
	assert_true(hand.has("instant_noodles"))
	assert_true(hand.has("apple"))


func test_meal_record_charges_source_fee_once() -> void:
	var source := GameDataScript.get_meal_source("takeout")
	var foods: Array[Dictionary] = [
		GameDataScript.get_food("sandwich"),
		GameDataScript.get_food("bubble_tea"),
	]
	var record := MealResolverScript.build_record("lunch", source, foods)
	assert_eq(int(record["food_cost"]), 19)
	assert_eq(int(record["source_fee"]), 3)
	assert_eq(int(record["total_cost"]), 22)


func test_meal_record_includes_source_stat_effects() -> void:
	var neutral_source := GameDataScript.get_meal_source("cafeteria").duplicate(true)
	neutral_source["energy"] = 0
	neutral_source["mood"] = 0
	neutral_source["stress"] = 0
	neutral_source["burden"] = 0
	var adjusted_source := neutral_source.duplicate(true)
	adjusted_source["energy"] = 4
	adjusted_source["mood"] = -2
	adjusted_source["stress"] = 3
	adjusted_source["burden"] = 1
	var foods: Array[Dictionary] = [GameDataScript.get_food("rice_plain")]
	var neutral := MealResolverScript.build_record("lunch", neutral_source, foods)
	var adjusted := MealResolverScript.build_record("lunch", adjusted_source, foods)
	var neutral_delta: Dictionary = neutral["stat_delta"]
	var adjusted_delta: Dictionary = adjusted["stat_delta"]
	assert_eq(int(adjusted_delta["energy"]), int(neutral_delta["energy"]) + 4)
	assert_eq(int(adjusted_delta["mood"]), int(neutral_delta["mood"]) - 2)
	assert_eq(int(adjusted_delta["stress"]), int(neutral_delta["stress"]) + 3)
	assert_false(adjusted_delta.has("diet_burden"), "retired source fields cannot produce a gameplay delta")
	assert_false(neutral_delta.has("diet_burden"))


func test_meal_group_combination_is_same_meal_only() -> void:
	var source := GameDataScript.get_meal_source("cafeteria")
	var balanced_foods: Array[Dictionary] = [
		GameDataScript.get_food("rice_plain"),
		GameDataScript.get_food("egg"),
		GameDataScript.get_food("tomato"),
	]
	var balanced := MealResolverScript.build_record("breakfast", source, balanced_foods)
	assert_true(MealResolverScript.has_meal_group_combination(balanced))
	var plain_foods: Array[Dictionary] = [GameDataScript.get_food("rice_plain")]
	var plain := MealResolverScript.build_record("breakfast", source, plain_foods)
	assert_false(MealResolverScript.has_meal_group_combination(plain))


func test_new_meal_records_have_no_legacy_nutrition_score() -> void:
	var source := GameDataScript.get_meal_source("cafeteria")
	for ids in [["rice_plain", "egg", "tomato"], ["apple"]]:
		var foods: Array[Dictionary] = []
		for id in ids:
			foods.append(GameDataScript.get_food(id))
		var record := MealResolverScript.build_record("lunch", source, foods)
		assert_false(record.has("quality"))
		assert_false(record.has("nutrition_score"))
		assert_eq(record["food_ids"], ids)


func test_legacy_tags_are_frozen_metadata_without_a_score_or_resource_bonus() -> void:
	var original := GameDataScript.get_food("rice_plain")
	var changed := original.duplicate(true)
	changed["food_groups"] = ["vegetables", "fruits", "dairy"]
	changed["nutrient_tags"] = ["dietary_fiber_source", "calcium_source"]
	changed["limit_tags"] = ["high_sodium", "fried"]
	var source := GameDataScript.get_meal_source("cafeteria")
	var first := MealResolverScript.build_record("lunch", source, [original])
	var second := MealResolverScript.build_record("lunch", source, [changed])
	assert_eq(first["stat_delta"], second["stat_delta"])
	assert_eq(first["total_cost"], second["total_cost"])
	assert_eq(second["food_groups"], changed["food_groups"])
	assert_eq(second["nutrient_tags"], changed["nutrient_tags"])
	assert_eq(second["limit_tags"], changed["limit_tags"])
	assert_false(second.has("quality"))


func test_skipped_records_do_not_receive_a_default_diet_score() -> void:
	for phase in ["breakfast", "lunch", "dinner"]:
		var record := MealResolverScript.build_skipped_record(phase)
		assert_false(record.has("quality"))
		assert_true(record["skipped"])
		assert_eq(record["total_cost"], 0)
		assert_true(record["food_ids"].is_empty())


func test_food_groups_do_not_substitute_for_each_other() -> void:
	var tofu := GameDataScript.get_food("tofu")
	var tomato := GameDataScript.get_food("tomato")
	var milk := GameDataScript.get_food("milk")
	assert_true(tofu["tags"].has("soy"))
	assert_false(tofu["tags"].has("vegetable"), "tofu is a soy/protein food, not a vegetable")
	assert_true(tomato["tags"].has("vegetable"))
	assert_false(tomato["tags"].has("fruit"), "tomato must not satisfy the daily fruit reminder")
	assert_true(milk["tags"].has("dairy"))
	var source := GameDataScript.get_meal_source("cafeteria")
	var rice_and_tofu: Array[Dictionary] = [GameDataScript.get_food("rice_plain"), tofu]
	var record := MealResolverScript.build_record("lunch", source, rice_and_tofu)
	assert_false(MealResolverScript.has_meal_group_combination(record), "rice and tofu still need a vegetable")


func test_daily_ledger_reports_only_confirmed_meal_facts() -> void:
	var cafeteria := GameDataScript.get_meal_source("cafeteria")
	var convenience := GameDataScript.get_meal_source("convenience_store")
	var records: Array[Dictionary] = [
		MealResolverScript.build_record("breakfast", cafeteria, [
			GameDataScript.get_food("rice_plain"),
			GameDataScript.get_food("egg"),
			GameDataScript.get_food("tomato"),
		]),
		MealResolverScript.build_record("lunch", convenience, [GameDataScript.get_food("apple")]),
		MealResolverScript.build_skipped_record("dinner"),
	]
	var summary: Dictionary = NutritionLedgerScript.summarize(records)
	var metrics: Dictionary = summary["metrics"]
	assert_eq(int(metrics["eaten_meals"]), 2)
	assert_eq(int(metrics["skipped_meals"]), 1)
	assert_eq(int(metrics["unknown_meals"]), 0)
	assert_eq(int(metrics["unrecorded_meals"]), 0)
	assert_eq(int(metrics["unplaced_records"]), 0)
	assert_false(summary.has("score"))
	assert_false(summary.has("rating"))
	assert_false(metrics.has("fiber_source_meals"))
	assert_contains(String(summary["detail_text"]), "选餐记录")
	assert_contains(String(summary["detail_text"]), "白米饭、鸡蛋、番茄")
	assert_contains(String(summary["detail_text"]), "晚餐｜跳过")
	assert_contains(String(summary["basis"]), "尚未核对")
	assert_false(String(summary["detail_text"]).contains("膳食纤维来源"))
	assert_false(String(summary["detail_text"]).contains("高钠"))
	assert_false(String(summary["detail_text"]).contains("今日饮食结构记录"))
	assert_false(String(summary["detail_text"]).contains("营养评分"))


func test_low_study_has_its_own_ending() -> void:
	var state := GameDataScript.get_starting_stats()
	state["stability"] = 72
	state["study_progress"] = 30
	assert_eq(MealResolverScript.select_ending(state), "study_shortfall")


func test_ending_boundary_matrix_has_no_unclassified_gap() -> void:
	var base_state := GameDataScript.get_starting_stats()
	var cases := [
		{"stability": 15, "study": 100, "burden": 0, "ending": "collapsed"},
		{"stability": 16, "study": 49, "burden": 0, "ending": "study_shortfall"},
		{"stability": 25, "study": 49, "burden": 0, "ending": "study_shortfall"},
		{"stability": 24, "study": 50, "burden": 0, "ending": "collapsed"},
		{"stability": 25, "study": 50, "burden": 0, "ending": "barely_survived"},
		{"stability": 60, "study": 69, "burden": 0, "ending": "barely_survived"},
		{"stability": 59, "study": 70, "burden": 0, "ending": "barely_survived"},
		{"stability": 60, "study": 70, "burden": 60, "ending": "stable_endurance"},
		{"stability": 60, "study": 70, "burden": 61, "ending": "stable_endurance"},
	]
	for case in cases:
		var state := base_state.duplicate(true)
		state["stability"] = int(case["stability"])
		state["study_progress"] = int(case["study"])
		state["diet_burden"] = int(case["burden"])
		assert_eq(
			MealResolverScript.select_ending(state),
			String(case["ending"]),
			"ending mismatch at stability=%d, study=%d, burden=%d" % [
				int(case["stability"]),
				int(case["study"]),
				int(case["burden"]),
			]
		)


func test_final_day_stability_does_not_reserve_phantom_budget() -> void:
	var state := GameDataScript.get_starting_stats()
	state["balance"] = 0
	var final_day_broke := MealResolverScript.calculate_stability(state, 66, 7, 7, 7.0)
	state["balance"] = 120
	var final_day_funded := MealResolverScript.calculate_stability(state, 66, 7, 7, 7.0)
	assert_eq(final_day_broke, final_day_funded, "ending day has no future meal budget to reserve")

	state["balance"] = 0
	var penultimate_broke := MealResolverScript.calculate_stability(state, 66, 6, 7, 7.0)
	state["balance"] = 120
	var penultimate_funded := MealResolverScript.calculate_stability(state, 66, 6, 7, 7.0)
	assert_gt(penultimate_funded, penultimate_broke, "budget should still matter while a future day remains")
