@tool
extends McpTestSuite

const GameDataScript := preload("res://scripts/GameData.gd")
const GameScene := preload("res://scenes/game/GameRoot.tscn")


func suite_name() -> String:
	return "mvp_content"


func test_food_assets_and_costs() -> void:
	assert_eq(GameDataScript.FOOD_IDS.size(), 15)
	for id in GameDataScript.FOOD_IDS:
		var food := GameDataScript.get_food(id)
		assert_true(food.has("name"), "%s missing name" % id)
		assert_true(int(food["cost"]) >= 0, "%s cost is negative" % id)
		assert_true(ResourceLoader.exists(String(food["image"])), "%s image missing: %s" % [id, String(food["image"])])


func test_action_assets_and_rules() -> void:
	assert_eq(GameDataScript.ACTION_IDS.size(), 6)
	for id in GameDataScript.ACTION_IDS:
		var action := GameDataScript.get_action(id)
		assert_true(action.has("slots"), "%s missing slots" % id)
		assert_true(int(action["slots"]) >= 1, "%s should consume one meal-after action" % id)
		assert_true(ResourceLoader.exists(String(action["image"])), "%s image missing: %s" % [id, String(action["image"])])
	assert_eq(int(GameDataScript.get_action("drink_water")["slots"]), 1)


func test_metrics_guide_asset_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/generated/ui/metrics_guide.png"), "metrics guide image missing")


func test_endings_have_images() -> void:
	for id in GameDataScript.ENDINGS.keys():
		var ending := GameDataScript.get_ending(String(id))
		assert_true(ResourceLoader.exists(String(ending["image"])), "%s ending image missing" % id)


func test_game_scene_instantiates() -> void:
	var node := GameScene.instantiate()
	track(node)
	assert_true(node is Control, "GameRoot scene should instantiate as Control")
