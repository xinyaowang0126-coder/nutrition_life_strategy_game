@tool
extends McpTestSuite

const GameDataScript := preload("res://scripts/GameData.gd")
const GameRootScript := preload("res://scripts/ui_v2/GameRootV2.gd")
const DeckScript := preload("res://scripts/systems/MealDeckService.gd")
const ResolverScript := preload("res://scripts/systems/MealResolver.gd")
const PreferenceScript := preload("res://scripts/systems/FoodPreferenceService.gd")
const HealthStoreScript := preload("res://scripts/health/HealthDataStore.gd")
const SnapshotScript := preload("res://scripts/health/MealHealthSnapshot.gd")


func suite_name() -> String:
	return "food_preference_flow"


func suite_setup(_ctx: Dictionary) -> void:
	GameDataScript.ensure_loaded()


func test_default_tastes_preserve_meal_effects_and_source_costs() -> void:
	var source := GameDataScript.get_meal_source("takeout")
	source["mood"] = -2
	var foods: Array[Dictionary] = [
		GameDataScript.get_food("salad_bowl"), GameDataScript.get_food("sandwich"),
	]
	var record: Dictionary = ResolverScript.build_record("lunch", source, foods)
	assert_eq(record["stat_delta"]["mood"], -1, "default tastes are -1 + 2; source adds -2")
	assert_eq(record["stat_delta"]["satiety"], 52)
	assert_eq(record["stat_delta"]["energy"], 3 + int(source.get("energy", 0)))
	assert_false(record["stat_delta"].has("diet_burden"))
	assert_eq(record["total_cost"], 25 + int(source.get("fee", 0)))
	assert_false(record["comfort"])
	assert_eq(record["preference_reactions"][0]["mood_delta"], -1)
	assert_eq(record["preference_reactions"][1]["mood_delta"], 2)


func test_nutrition_tags_and_forged_preview_cannot_set_taste_or_comfort() -> void:
	var food := GameDataScript.get_food("greens")
	food["mood"] = 99
	food["tags"] = ["favorite", "high_sugar", "high_sodium", "high_fat", "instant"]
	food["food_preference"] = {"status": "known", "mood_delta": 99, "comfort": true}
	var foods: Array[Dictionary] = [food]
	var record: Dictionary = ResolverScript.build_record("lunch", {}, foods, {})
	assert_eq(record["stat_delta"]["mood"], 0)
	assert_false(record["comfort"])
	assert_eq(record["preference_reactions"][0]["status"], "unspecified")
	var declared := _greens_profile(7, true)
	var selected: Dictionary = ResolverScript.build_record("lunch", {}, foods, declared)
	assert_eq(selected["stat_delta"]["mood"], 7)
	assert_true(selected["comfort"])
	assert_false(selected.has("quality"))
	assert_false(record.has("quality"))


func test_changed_tastes_leave_food_profiles_and_health_snapshots_identical() -> void:
	var catalog: Dictionary = HealthStoreScript.new().load_catalog()
	var catalog_before: Dictionary = catalog.duplicate(true)
	var food := GameDataScript.get_food("greens")
	var foods: Array[Dictionary] = [food]
	var original: Dictionary = ResolverScript.build_record("lunch", {}, foods)
	var preferred: Dictionary = ResolverScript.build_record("lunch", {}, foods, _greens_profile(7, true))
	assert_eq(original["stat_delta"]["mood"], -2)
	assert_eq(preferred["stat_delta"]["mood"], 7)
	assert_ne(original["comfort"], preferred["comfort"])
	var original_health: Dictionary = SnapshotScript.build(1, original, catalog)
	var preferred_health: Dictionary = SnapshotScript.build(1, preferred, catalog)
	assert_true(SnapshotScript.validate(original_health)["valid"])
	assert_eq(original_health, preferred_health)
	assert_eq(catalog, catalog_before)
	assert_eq(GameDataScript.get_food("greens"), food)
	preferred_health["preference_reactions"] = preferred["preference_reactions"]
	assert_false(SnapshotScript.validate(preferred_health)["valid"])


func test_v2_card_preview_and_confirm_use_the_same_current_character() -> void:
	var normal := _new_game()
	var changed := _new_game()
	var profile := _greens_profile(7, true)
	changed.set_food_preferences(profile)
	profile["reactions"]["greens"]["mood_delta"] = 99
	var preview: Dictionary = changed.get_food_for_character("greens")
	assert_false(preview.has("mood"))
	assert_eq(preview["food_preference"]["mood_delta"], 7)
	preview["food_preference"]["mood_delta"] = 55
	_eat_greens(normal)
	_eat_greens(changed)
	assert_eq(changed.state["mood"], int(normal.state["mood"]) + 9)
	assert_eq(changed.state["balance"], normal.state["balance"])
	assert_eq(changed.dorm_inventory, normal.dorm_inventory)
	assert_eq(changed.phase, normal.phase)
	assert_eq(changed.get_health_snapshots(), normal.get_health_snapshots())
	assert_eq(changed.today_meal_records[0]["preference_reactions"][0]["mood_delta"], 7)
	assert_eq(changed.today_meal_records[0]["preference_reactions"][0]["profile_id"], "greens_fan")


func test_taste_changes_do_not_rewrite_confirmed_records_and_restart_resets_tastes() -> void:
	var game := _new_game()
	game.set_food_preferences(_greens_profile(7, true))
	_eat_greens(game)
	var saved_record: Dictionary = game.today_meal_records[0].duplicate(true)
	var saved_health: Array[Dictionary] = game.get_health_snapshots()
	game.set_food_preferences(_greens_profile(-4, false))
	assert_eq(game.today_meal_records[0], saved_record)
	assert_eq(game.get_health_snapshots(), saved_health)
	game.day = 2
	game._start_day()
	assert_eq(game.get_food_for_character("greens")["food_preference"]["mood_delta"], -4)
	game.start_new_run()
	assert_eq(game.get_food_for_character("greens")["food_preference"]["mood_delta"], -2)
	assert_true(game.today_meal_records.is_empty())
	assert_true(game.get_health_snapshots().is_empty())


func test_explicit_empty_profile_remains_unspecified_in_preview_and_gameplay() -> void:
	var game := _new_game()
	game.set_food_preferences({})
	var preview: Dictionary = game.get_food_for_character("greens")
	assert_eq(preview["food_preference"]["status"], "unspecified")
	var opening_mood := int(game.state["mood"])
	_eat_greens(game)
	assert_eq(game.state["mood"], opening_mood)
	assert_false(game.today_meal_records[0]["comfort"])
	assert_eq(game.today_meal_records[0]["preference_reactions"][0]["mood_delta"], 0)
	assert_eq(game.get_health_snapshots()[0]["status"], "eaten")
	var skipped: Dictionary = ResolverScript.build_skipped_record("dinner")
	assert_true(skipped["preference_reactions"].is_empty())
	assert_eq(skipped["stat_delta"]["mood"], -2, "skipping remains a separate game effect")


func test_comfort_is_a_declared_preference_not_a_nutrition_classification() -> void:
	for food_id in ["bubble_tea", "instant_noodles", "fried_chicken"]:
		var foods: Array[Dictionary] = [GameDataScript.get_food(food_id)]
		assert_true(ResolverScript.build_record("dinner", {}, foods)["comfort"])
		assert_false(ResolverScript.build_record("dinner", {}, foods, {})["comfort"])
	var vegetables: Array[Dictionary] = [GameDataScript.get_food("greens")]
	var first: Dictionary = ResolverScript.build_record("lunch", {}, vegetables, _greens_profile(7, true))
	var second: Dictionary = ResolverScript.build_record("dinner", {}, vegetables, _greens_profile(7, true))
	var meals: Array[Dictionary] = [first, second]
	assert_eq(ResolverScript.comfort_meal_count(meals), 2)
	assert_eq(first["limit_tags"], [])


func _greens_profile(mood_delta: int, comfort: bool) -> Dictionary:
	var profile: Dictionary = PreferenceScript.default_profile()
	profile["id"] = "greens_fan"
	profile["reactions"]["greens"] = {"mood_delta": mood_delta, "comfort": comfort}
	return profile


func _new_game() -> GameRootV2:
	var game := GameRootScript.new() as GameRootV2
	track(game)
	game.health_guidance_flags = {"data": true}
	game.health_history_path = ""
	game._deck_service = DeckScript.new(20260711)
	game.start_new_run()
	return game


func _eat_greens(game: GameRootV2) -> void:
	game.phase = "lunch_source"
	game._choose_meal_source("cafeteria")
	# Fix this real cafeteria choice so taste assertions do not depend on a draw.
	assert_true(GameDataScript.get_food_ids_for_context("cafeteria", "lunch").has("greens"))
	game.hand.assign(["greens"])
	game._confirm_food(["greens"])
	assert_eq(game.phase, "lunch_action")
