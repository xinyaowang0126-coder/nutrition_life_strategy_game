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
	assert_eq(int(record["food_cost"]), 30)
	assert_eq(int(record["source_fee"]), 3)
	assert_eq(int(record["total_cost"]), 33)


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
	assert_eq(int(adjusted_delta["diet_burden"]), int(neutral_delta["diet_burden"]) + 1)


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


func test_plate_quality_rewards_a_complete_plate_over_a_single_fruit() -> void:
	var cafeteria := GameDataScript.get_meal_source("cafeteria")
	var convenience := GameDataScript.get_meal_source("convenience_store")
	var complete := MealResolverScript.build_record("lunch", cafeteria, [
		GameDataScript.get_food("rice_plain"),
		GameDataScript.get_food("egg"),
		GameDataScript.get_food("tomato"),
	])
	var apple_only := MealResolverScript.build_record(
		"lunch",
		convenience,
		[GameDataScript.get_food("apple")]
	)
	assert_gt(int(complete["quality"]), int(apple_only["quality"]))
	assert_gt(int(complete["quality"]), 65, "a complete plate should reach the good-day band")
	assert_false(int(apple_only["quality"]) >= 66, "a single apple is not a complete meal")


func test_plate_quality_uses_professional_fields_not_presentation_tags() -> void:
	var complete_fields := {
		"food_groups": ["grains_tubers", "vegetables", "eggs"],
		"nutrient_tags": [
			"carbohydrate_source",
			"dietary_fiber_source",
			"high_quality_protein_source",
		],
		"limit_tags": [],
	}
	var misleading_tags := complete_fields.duplicate(true)
	misleading_tags["tags"] = ["high_sugar", "high_fat", "instant"]
	assert_eq(
		MealResolverScript.food_quality(complete_fields),
		MealResolverScript.food_quality(misleading_tags),
		"legacy display tags must not alter the professional plate score"
	)


func test_plate_quality_penalizes_limit_factors() -> void:
	var groups := ["grains_tubers", "vegetables", "poultry_livestock"]
	var nutrients := [
		"carbohydrate_source",
		"dietary_fiber_source",
		"high_quality_protein_source",
	]
	var unrestricted := MealResolverScript.plate_quality(groups, nutrients, [])
	var limited := MealResolverScript.plate_quality(groups, nutrients, ["high_sodium", "fried"])
	assert_gt(unrestricted, limited)


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


func test_nutrition_ledger_reports_patterns_and_scientific_context() -> void:
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
	assert_eq(int(metrics["vegetable_meals"]), 1)
	assert_eq(int(metrics["fruit_meals"]), 1)
	assert_eq(int(metrics["unique_foods"]), 4)
	assert_eq(int(metrics["animal_food_meals"]), 1)
	assert_eq(int(metrics["fiber_source_meals"]), 2)
	assert_eq(int(metrics["high_quality_protein_meals"]), 1)
	assert_eq(int(summary["score"]), MealResolverScript.day_quality(records))
	assert_false(String(summary["rating"]).is_empty())
	assert_true(int(summary["score"]) >= 0 and int(summary["score"]) <= 100)
	assert_contains(String(summary["detail_text"]), "食物类别分布")
	assert_contains(String(summary["detail_text"]), "重点营养素来源")
	assert_contains(String(summary["basis"]), "仅用于健康教育")


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
		{"stability": 60, "study": 70, "burden": 61, "ending": "barely_survived"},
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
	var final_day_broke := MealResolverScript.calculate_stability(state, 66, 7, 7)
	state["balance"] = 120
	var final_day_funded := MealResolverScript.calculate_stability(state, 66, 7, 7)
	assert_eq(final_day_broke, final_day_funded, "ending day has no future meal budget to reserve")

	state["balance"] = 0
	var penultimate_broke := MealResolverScript.calculate_stability(state, 66, 6, 7)
	state["balance"] = 120
	var penultimate_funded := MealResolverScript.calculate_stability(state, 66, 6, 7)
	assert_gt(penultimate_funded, penultimate_broke, "budget should still matter while a future day remains")
