@tool
extends McpTestSuite

const GameDataScript := preload("res://scripts/GameData.gd")
const GameScene := preload("res://scenes/game/GameRoot.tscn")


func suite_name() -> String:
	return "mvp_content"


func suite_setup(_ctx: Dictionary) -> void:
	GameDataScript.ensure_loaded()


func test_xml_card_data_exists() -> void:
	assert_true(FileAccess.file_exists("res://data/cards/foods.xml"), "foods.xml missing")
	assert_true(FileAccess.file_exists("res://data/cards/actions.xml"), "actions.xml missing")
	assert_true(FileAccess.file_exists("res://data/cards/sleep_options.xml"), "sleep_options.xml missing")
	assert_true(FileAccess.file_exists("res://data/cards/meal_sources.xml"), "meal_sources.xml missing")


func test_food_assets_and_costs() -> void:
	var food_ids := GameDataScript.get_food_ids_for_scene("meal")
	assert_eq(food_ids.size(), 23)
	for id in food_ids:
		var food := GameDataScript.get_food(id)
		assert_true(food.has("name"), "%s missing name" % id)
		assert_true(int(food["cost"]) >= 0, "%s cost is negative" % id)
		assert_true(food.has("scenes"), "%s missing scenes" % id)
		assert_true(food.has("food_groups"), "%s missing professional food-group classification" % id)
		assert_true(GameDataScript.is_food_available(id, "meal"), "%s should be available in meal scene" % id)
		assert_true(ResourceLoader.exists(String(food["image"])), "%s image missing: %s" % [id, String(food["image"])])


func test_new_foods_match_realistic_meal_sources() -> void:
	for id in ["mixed_grain_rice", "tomato_egg_stir_fry", "celery_pork_stir_fry"]:
		assert_true(
			GameDataScript.get_food_ids_for_context("cafeteria", "lunch").has(id),
			"%s should appear as a cafeteria lunch option" % id
		)
	assert_true(GameDataScript.get_food_ids_for_context("cafeteria", "dinner").has("steamed_fish"))
	assert_true(GameDataScript.get_food_ids_for_context("takeout", "dinner").has("steamed_fish"))
	assert_true(GameDataScript.get_food_ids_for_context("takeout", "lunch").has("chicken_vegetable_rice"))
	for id in ["plain_yogurt", "whole_wheat_bread", "unsalted_nuts"]:
		assert_true(GameDataScript.get_food_ids_for_context("convenience_store", "breakfast").has(id))
		assert_true(GameDataScript.get_food_ids_for_context("dorm_storage", "breakfast").has(id))
	var tomato_egg := GameDataScript.get_food("tomato_egg_stir_fry")
	assert_true(tomato_egg["food_groups"].has("vegetables"))
	assert_true(tomato_egg["food_groups"].has("eggs"))
	assert_true(tomato_egg["nutrient_tags"].has("high_quality_protein_source"))
	var nuts := GameDataScript.get_food("unsalted_nuts")
	assert_true(nuts["nutrient_tags"].has("unsaturated_fatty_acid_source"))


func test_food_satiety_is_rebalanced() -> void:
	var expected := {
		"rice_plain": 16,
		"oatmeal": 18,
		"egg": 10,
		"tofu": 11,
		"greens": 5,
		"tomato": 4,
		"apple": 6,
		"banana": 8,
		"milk": 6,
		"coffee": 1,
		"bubble_tea": 4,
		"instant_noodles": 20,
		"fried_chicken": 22,
		"salad_bowl": 14,
		"sandwich": 18,
	}
	for id in expected:
		var satiety := int(GameDataScript.get_food(id).get("satiety", -1))
		assert_eq(satiety, int(expected[id]), "%s satiety drifted" % id)
		assert_true(satiety <= 22, "%s is too filling as one item" % id)
	for id in ["milk", "coffee", "bubble_tea"]:
		assert_true(int(GameDataScript.get_food(id)["satiety"]) <= 6, "%s drink should stay light" % id)
	assert_eq(int(GameDataScript.get_food("rice_plain")["satiety"]) + int(GameDataScript.get_food("egg")["satiety"]), 26)
	assert_eq(int(GameDataScript.get_food("rice_plain")["satiety"]) + int(GameDataScript.get_food("tofu")["satiety"]), 27)
	assert_eq(int(GameDataScript.get_food("salad_bowl")["satiety"]) + int(GameDataScript.get_food("sandwich")["satiety"]), 32)


func test_action_assets_and_rules() -> void:
	var action_ids := GameDataScript.get_action_ids_for_scene("breakfast_action")
	assert_eq(action_ids.size(), 6)
	for id in action_ids:
		var action := GameDataScript.get_action(id)
		assert_true(action.has("slots"), "%s missing slots" % id)
		assert_true(int(action["slots"]) >= 1, "%s should consume one meal-after action" % id)
		assert_true(action.has("scenes"), "%s missing scenes" % id)
		assert_true(ResourceLoader.exists(String(action["image"])), "%s image missing: %s" % [id, String(action["image"])])
	assert_eq(int(GameDataScript.get_action("drink_water")["slots"]), 1)
	assert_eq(int(GameDataScript.get_action("study")["min_energy"]), 8)
	var restock := GameDataScript.get_action("restock_pantry")
	assert_eq(int(restock["cost"]), 10)
	assert_eq(restock["stock_items"], ["oatmeal:1", "milk:1", "apple:1"])


func test_sleep_early_is_sleep_only() -> void:
	assert_false(GameDataScript.get_action_ids_for_scene("breakfast_action").has("sleep_early"), "sleep_early should not be a breakfast-after action")
	assert_false(GameDataScript.get_action_ids_for_scene("lunch_action").has("sleep_early"), "sleep_early should not be a lunch-after action")
	assert_false(GameDataScript.get_action_ids_for_scene("dinner_action").has("sleep_early"), "sleep_early should not be a dinner-after action")
	assert_true(GameDataScript.get_sleep_option_ids_for_scene("sleep").has("sleep_early"), "sleep_early should be available in sleep phase")


func test_metrics_guide_asset_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/generated/ui/metrics_guide.png"), "metrics guide image missing")


func test_meal_sources_and_pools() -> void:
	var source_ids := GameDataScript.get_meal_source_ids()
	assert_eq(source_ids.size(), 4)
	assert_false(GameDataScript.is_meal_source_available("takeout", "breakfast"))
	assert_true(GameDataScript.is_meal_source_available("takeout", "lunch"))
	for id in source_ids:
		var source := GameDataScript.get_meal_source(id)
		assert_true(int(source.get("selection_limit", 0)) >= 1, "%s missing selection limit" % id)
		assert_true(ResourceLoader.exists(String(source["image"])), "%s image missing" % id)
		assert_true(ResourceLoader.exists(String(source["background"])), "%s background missing" % id)
		for meal in ["breakfast", "lunch", "dinner"]:
			if GameDataScript.is_meal_source_available(id, meal):
				assert_gt(GameDataScript.get_food_ids_for_context(id, meal).size(), 0, "%s has no %s food" % [id, meal])
	var inventory := GameDataScript.get_initial_dorm_inventory()
	assert_eq(int(inventory.get("oatmeal", 0)), 2)
	assert_eq(int(inventory.get("instant_noodles", 0)), 2)
	assert_eq(int(GameDataScript.get_meal_source("cafeteria")["selection_limit"]), 3)
	assert_eq(int(GameDataScript.get_meal_source("takeout")["selection_limit"]), 2)


func test_endings_have_images() -> void:
	for id in GameDataScript.ENDINGS.keys():
		var ending := GameDataScript.get_ending(String(id))
		assert_true(ResourceLoader.exists(String(ending["image"])), "%s ending image missing" % id)


func test_game_scene_instantiates() -> void:
	var node := GameScene.instantiate()
	track(node)
	assert_true(node is Control, "GameRoot scene should instantiate as Control")
