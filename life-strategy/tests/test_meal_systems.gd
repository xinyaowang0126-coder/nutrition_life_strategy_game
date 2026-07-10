@tool
extends McpTestSuite

const GameDataScript := preload("res://scripts/GameData.gd")
const MealDeckServiceScript := preload("res://scripts/systems/MealDeckService.gd")
const MealResolverScript := preload("res://scripts/systems/MealResolver.gd")


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


func test_balanced_plate_is_same_meal_only() -> void:
	var source := GameDataScript.get_meal_source("cafeteria")
	var balanced_foods: Array[Dictionary] = [
		GameDataScript.get_food("rice_plain"),
		GameDataScript.get_food("egg"),
		GameDataScript.get_food("tomato"),
	]
	var balanced := MealResolverScript.build_record("breakfast", source, balanced_foods)
	assert_true(MealResolverScript.has_balanced_plate(balanced))
	var plain_foods: Array[Dictionary] = [GameDataScript.get_food("rice_plain")]
	var plain := MealResolverScript.build_record("breakfast", source, plain_foods)
	assert_false(MealResolverScript.has_balanced_plate(plain))


func test_low_study_has_its_own_ending() -> void:
	var state := GameDataScript.get_starting_stats()
	state["stability"] = 72
	state["study_progress"] = 30
	assert_eq(MealResolverScript.select_ending(state), "study_shortfall")
