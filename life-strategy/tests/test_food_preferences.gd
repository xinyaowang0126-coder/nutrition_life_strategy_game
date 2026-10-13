@tool
extends McpTestSuite

const PreferenceScript := preload("res://scripts/systems/FoodPreferenceService.gd")
const CardsScript := preload("res://scripts/CardDataStore.gd")
const EXPECTED_MOODS := {
	"rice_plain": 0,
	"oatmeal": 0,
	"egg": 0,
	"tofu": 0,
	"greens": -2,
	"tomato": 1,
	"apple": 2,
	"banana": 2,
	"milk": 1,
	"coffee": 2,
	"bubble_tea": 6,
	"instant_noodles": 2,
	"fried_chicken": 6,
	"salad_bowl": -1,
	"sandwich": 2,
	"mixed_grain_rice": 1,
	"tomato_egg_stir_fry": 3,
	"celery_pork_stir_fry": 2,
	"steamed_fish": 3,
	"plain_yogurt": 2,
	"whole_wheat_bread": 1,
	"unsalted_nuts": 2,
	"chicken_vegetable_rice": 3,
}
const COMFORT_FOODS := ["bubble_tea", "instant_noodles", "fried_chicken"]

var _test_directory := ""


func suite_name() -> String:
	return "food_preferences"


func setup() -> void:
	_test_directory = ProjectSettings.globalize_path(
		"res://.godot/food-preference-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	assert_eq(DirAccess.make_dir_recursive_absolute(_test_directory), OK)


func teardown() -> void:
	var directory := DirAccess.open(_test_directory)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(_test_directory.path_join(file_name))
	DirAccess.remove_absolute(_test_directory)


func test_default_character_preserves_all_23_mood_values_and_explicit_comfort() -> void:
	var profile: Dictionary = PreferenceScript.default_profile()
	assert_eq(profile.get("id"), "campus_student")
	assert_eq(profile.get("version"), 2)
	assert_eq(profile.get("name"), "本局角色")
	assert_eq((profile["reactions"] as Dictionary).size(), 23)
	for food_id in EXPECTED_MOODS:
		var response: Dictionary = PreferenceScript.reaction(food_id, profile)
		assert_eq(response["status"], "known", food_id)
		assert_eq(response["mood_delta"], EXPECTED_MOODS[food_id], food_id)
		assert_eq(response["comfort"], COMFORT_FOODS.has(food_id), food_id)
		assert_eq(response["profile_id"], "campus_student")
		assert_eq(response["profile_version"], 2)
		assert_eq(response["character_name"], "本局角色")


func test_food_catalog_has_no_character_mood_or_preference_tags() -> void:
	CardsScript.ensure_loaded()
	assert_eq(CardsScript.food_ids.size(), EXPECTED_MOODS.size())
	for food_id in CardsScript.food_ids:
		assert_true(EXPECTED_MOODS.has(food_id))
		var food: Dictionary = CardsScript.get_food(food_id)
		assert_false(food.has("mood"), food_id)
		assert_false((food["tags"] as Array).has("mood"), food_id)
		assert_false((food["tags"] as Array).has("favorite"), food_id)
	assert_contains(CardsScript.get_food("bubble_tea")["tags"], "high_sugar")
	assert_contains(CardsScript.get_food("instant_noodles")["tags"], "high_sodium")
	assert_contains(CardsScript.get_food("fried_chicken")["tags"], "tasty")
	assert_true(CardsScript.get_action("nap").has("mood"))


func test_profiles_reactions_and_decorated_food_are_independent_copies() -> void:
	var profile: Dictionary = PreferenceScript.default_profile()
	var original: Dictionary = profile.duplicate(true)
	profile["reactions"]["apple"]["mood_delta"] = -15
	assert_eq(PreferenceScript.default_profile(), original)
	var response: Dictionary = PreferenceScript.reaction("apple", profile)
	response["mood_delta"] = 100
	assert_eq(profile["reactions"]["apple"]["mood_delta"], -15)
	var food := {"id": "apple", "mood": 50, "tags": ["fruit"], "nested": {"value": 1}}
	var decorated: Dictionary = PreferenceScript.decorate_food(food, profile)
	assert_false(decorated.has("mood"))
	assert_eq(decorated["food_preference"]["mood_delta"], -15)
	(decorated["tags"] as Array).clear()
	decorated["nested"]["value"] = 9
	decorated["food_preference"]["mood_delta"] = 80
	assert_eq(food["mood"], 50)
	assert_eq(food["tags"], ["fruit"])
	assert_eq(food["nested"]["value"], 1)
	assert_eq(profile["reactions"]["apple"]["mood_delta"], -15)


func test_same_food_changes_with_character_preferences_only() -> void:
	var profile: Dictionary = PreferenceScript.default_profile()
	var other: Dictionary = profile.duplicate(true)
	other["id"] = "different_student"
	other["version"] = 2
	other["name"] = "另一角色"
	other["reactions"]["greens"] = {"mood_delta": 8, "comfort": true}
	var food := {"id": "greens", "mood": -90, "tags": ["favorite", "high_sugar"]}
	food["health"] = {"confidence": "high", "quality": 100}
	var first: Dictionary = PreferenceScript.decorate_food(food, profile)
	var second: Dictionary = PreferenceScript.decorate_food(food, other)
	assert_eq(first["food_preference"]["mood_delta"], -2)
	assert_false(first["food_preference"]["comfort"])
	assert_eq(second["food_preference"]["mood_delta"], 8)
	assert_true(second["food_preference"]["comfort"])
	assert_eq(second["food_preference"]["character_name"], "另一角色")
	assert_eq(second["food_preference"]["profile_version"], 2)
	food["tags"] = []
	food["mood"] = 90
	assert_eq(PreferenceScript.decorate_food(food, other)["food_preference"], second["food_preference"])


func test_missing_and_invalid_preferences_never_use_old_food_mood_or_tags() -> void:
	var profile: Dictionary = PreferenceScript.default_profile()
	(profile["reactions"] as Dictionary).erase("bubble_tea")
	var food := {"id": "bubble_tea", "mood": 99, "tags": ["favorite", "mood"]}
	var unspecified: Dictionary = PreferenceScript.decorate_food(food, profile)["food_preference"]
	_assert_unspecified(unspecified)
	assert_eq(unspecified["profile_id"], "campus_student")
	var invalid_profiles: Array[Dictionary] = [
		{}, {"id": "broken", "version": 1, "name": "错误资料", "reactions": []},
		{"id": "broken", "version": 0, "name": "错误资料", "reactions": {}},
		{"id": "broken", "version": 1, "name": "错误资料", "reactions": {"bubble_tea": {"mood_delta": "99", "comfort": true}}},
		{"id": "broken", "version": 1, "name": "错误资料", "reactions": {"bubble_tea": {"mood_delta": 99, "comfort": "true"}}},
	]
	for invalid in invalid_profiles:
		_assert_unspecified(PreferenceScript.decorate_food(food, invalid)["food_preference"])
	profile["reactions"]["bad_other_food"] = {"mood_delta": 1, "comfort": "bad"}
	_assert_unspecified(PreferenceScript.reaction("apple", profile))


func test_profile_loader_rejects_missing_malformed_duplicate_and_future_data() -> void:
	assert_true(PreferenceScript.load_profile(_test_directory.path_join("missing.xml")).is_empty())
	var valid := FileAccess.get_file_as_string(PreferenceScript.DEFAULT_PROFILE_PATH)
	var invalid_documents: Array[String] = [
		"", "<wrong />", valid.replace("schema_version=\"1\"", "schema_version=\"2\""),
		valid.replace("version=\"2\" name", "version=\"1.5\" name"),
		valid.replace("id=\"campus_student\"", "id=\"\""),
		valid.replace("food_id=\"oatmeal\"", "food_id=\"rice_plain\""),
		valid.replace("mood_delta=\"6\"", "mood_delta=\"18.5\""),
		valid.replace("comfort=\"true\"", "comfort=\"yes\""),
		valid.replace("</food_preferences>", ""),
		valid.replace("</food_preferences>", "</other>"),
		valid + "<food_preferences schema_version=\"1\" id=\"other\" version=\"2\" name=\"other\" />",
	]
	for index in range(invalid_documents.size()):
		var path := _write_xml("invalid-%d.xml" % index, invalid_documents[index])
		assert_true(PreferenceScript.load_profile(path).is_empty(), "Invalid XML accepted: %d" % index)
	assert_eq(PreferenceScript.load_profile(PreferenceScript.DEFAULT_PROFILE_PATH), PreferenceScript.default_profile())


func test_profile_loader_returns_independent_data_each_time() -> void:
	var path := _write_xml("valid.xml", FileAccess.get_file_as_string(PreferenceScript.DEFAULT_PROFILE_PATH))
	var first: Dictionary = PreferenceScript.load_profile(path)
	var second: Dictionary = PreferenceScript.load_profile(path)
	(first["reactions"] as Dictionary).clear()
	assert_eq((second["reactions"] as Dictionary).size(), 23)
	assert_eq(PreferenceScript.load_profile(path), second)


func _assert_unspecified(response: Dictionary) -> void:
	assert_eq(response["status"], "unspecified")
	assert_eq(response["mood_delta"], 0)
	assert_eq(response["comfort"], false)


func _write_xml(name: String, contents: String) -> String:
	var path := _test_directory.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null)
	if file != null:
		file.store_string(contents)
		file.close()
	return path
