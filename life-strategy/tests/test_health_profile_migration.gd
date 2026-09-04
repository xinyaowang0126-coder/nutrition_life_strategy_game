@tool
extends McpTestSuite

const HealthDataStoreScript := preload("res://scripts/health/HealthDataStore.gd")
const HealthDataValidatorScript := preload("res://scripts/health/HealthDataValidator.gd")
const HealthEvidenceRegistryScript := preload("res://scripts/health/HealthEvidenceRegistry.gd")

const NUT_204B_GAME_SPEC_ID := "GAME-SPEC-204B-V1"
const NUT_204C_GAME_SPEC_ID := "GAME-SPEC-204C-V1"
const NUT_204D_GAME_SPEC_ID := "GAME-SPEC-204D-V1"
const NUT_204A_PROFILE_IDS := [
	"egg",
	"greens",
	"mixed_grain_rice",
	"rice_plain",
	"tofu",
	"tomato",
]
const NUT_204B_PROFILE_IDS := [
	"bubble_tea",
	"coffee",
	"instant_noodles",
]
const NUT_204C_PROFILE_IDS := [
	"celery_pork_stir_fry",
	"chicken_vegetable_rice",
	"fried_chicken",
	"salad_bowl",
	"sandwich",
	"steamed_fish",
	"tomato_egg_stir_fry",
]
const NUT_204D_PROFILE_IDS := [
	"milk",
	"plain_yogurt",
	"whole_wheat_bread",
]
const NUT_205_PROFILE_IDS := ["apple", "banana", "oatmeal", "unsalted_nuts"]
const EXPECTED_PROFILE_IDS := [
	"apple",
	"banana",
	"bubble_tea",
	"celery_pork_stir_fry",
	"chicken_vegetable_rice",
	"coffee",
	"egg",
	"fried_chicken",
	"greens",
	"instant_noodles",
	"milk",
	"mixed_grain_rice",
	"oatmeal",
	"plain_yogurt",
	"rice_plain",
	"salad_bowl",
	"sandwich",
	"steamed_fish",
	"tofu",
	"tomato",
	"tomato_egg_stir_fry",
	"unsalted_nuts",
	"whole_wheat_bread",
]
const COMPOSITE_PROFILE_IDS := [
	"bubble_tea",
	"celery_pork_stir_fry",
	"chicken_vegetable_rice",
	"fried_chicken",
	"instant_noodles",
	"mixed_grain_rice",
	"plain_yogurt",
	"salad_bowl",
	"sandwich",
	"steamed_fish",
	"tomato_egg_stir_fry",
]
const NUT_204A_GROUPS := {
	"rice_plain": "grains_tubers",
	"mixed_grain_rice": "grains_tubers",
	"egg": "eggs",
	"tofu": "soy_products",
	"greens": "vegetables",
	"tomato": "vegetables",
}


func suite_name() -> String:
	return "health_profile_migration"


func test_nut_205_every_food_card_has_exactly_one_health_profile() -> void:
	var card_ids := _load_card_food_ids()
	var store := HealthDataStoreScript.new()
	var catalog: Dictionary = store.load_catalog()
	assert_eq(String(catalog["status"]), HealthDataStoreScript.STATUS_READY)
	assert_eq(int(catalog["profile_count"]), 23)
	assert_eq(int(catalog["unique_profile_count"]), 23)
	assert_eq(store.get_profile_ids(), EXPECTED_PROFILE_IDS)
	assert_eq(store.get_profile_ids(), card_ids)
	for food_id in EXPECTED_PROFILE_IDS:
		assert_true(card_ids.has(food_id), "profile has no card: %s" % food_id)
		assert_true(store.has_profile(food_id), "card has no migrated profile: %s" % food_id)


func test_nut_205_catalog_has_zero_blocking_validation_errors() -> void:
	var store := HealthDataStoreScript.new()
	var catalog: Dictionary = store.load_catalog()
	var report: Dictionary = HealthDataValidatorScript.validate(catalog, {
		"known_food_ids": _load_card_food_ids(),
		"composite_food_ids": COMPOSITE_PROFILE_IDS,
		"product_food_ids": EXPECTED_PROFILE_IDS,
		"display_names": {
			"coffee": "咖啡",
			"bubble_tea": "奶茶",
			"instant_noodles": "方便面",
		},
	})
	assert_true(bool(report["valid"]))
	assert_eq(int(report["error_count"]), 0)
	assert_eq(_issues_with_code(report["warnings"], "profile_draft").size(), 23)
	assert_eq(_issues_with_code(report["warnings"], "confidence_limited").size(), 28)
	assert_eq(int(report["warning_count"]), 51)


func test_nut_204a_profiles_keep_portions_recipes_and_cooking_explicitly_limited() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	for food_id in NUT_204A_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		assert_eq(String(profile["review_status"]), "draft")
		assert_eq(String(profile["confidence"]), "low")
		assert_eq(String(profile["basis_type"]), "generic_category")
		var portion := profile["portion"] as Dictionary
		assert_eq(String(portion["status"]), "unknown")
		assert_eq(String(portion["band"]), "unknown")
		assert_false(portion.has("value"))
		assert_false(portion.has("unit"))
		assert_eq(profile["cooking_methods"], ["unknown"])
		var caffeine := profile["caffeine"] as Dictionary
		assert_eq(String(caffeine["status"]), "unknown")
		assert_false(caffeine.has("mg"))
		assert_true((profile["evidence_refs"] as Array).has("PRODUCT-RECIPE-PENDING"))


func test_nut_204a_records_only_supported_group_identity_without_amount_claims() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	for food_id in NUT_204A_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		var components := profile["components"] as Array
		assert_eq(components.size(), 1)
		var component := components[0] as Dictionary
		assert_eq(String(component["food_group"]), String(NUT_204A_GROUPS[food_id]))
		assert_eq(String(component["contribution_band"]), "dominant")
		assert_eq(String(component["basis_type"]), "generic_category")
		assert_eq(String(component["confidence"]), "low")
		assert_false(component.has("amount_value"))
		assert_false(component.has("amount_unit"))

	var mixed_grain: Dictionary = store.get_profile("mixed_grain_rice")
	assert_eq(String(mixed_grain["composition_status"]), "estimated")
	assert_false(mixed_grain.has("whole_grain"))


func test_nut_204a_evidence_ids_exist_but_pending_records_block_release_use() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry()
	for food_id in NUT_204A_PROFILE_IDS:
		var references: Array = store.get_profile(food_id)["evidence_refs"]
		for evidence_id in references:
			assert_true(registry.has_evidence(String(evidence_id)))
		var reference_report: Dictionary = registry.check_references(
			references,
			"2026-07-20"
		)
		assert_true((reference_report["missing_ids"] as Array).is_empty())
		assert_false(bool(reference_report["valid"]))
		assert_true((reference_report["needs_review_ids"] as Array).has(
			"PRODUCT-RECIPE-PENDING"
		))


func test_nut_204b_uses_canonical_game_recipes_and_simulated_label_values() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	var expected := {
		"coffee": {
			"basis_type": "menu_recipe",
			"portion_value": 350.0,
			"portion_unit": "ml",
			"portion_band": "medium",
			"method": "brewed",
		},
		"bubble_tea": {
			"basis_type": "menu_recipe",
			"portion_value": 500.0,
			"portion_unit": "ml",
			"portion_band": "large",
			"method": "mixed",
		},
		"instant_noodles": {
			"basis_type": "package_label",
			"portion_value": 100.0,
			"portion_unit": "g",
			"portion_band": "medium",
			"method": "mixed",
		},
	}
	for food_id in NUT_204B_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		var expected_profile := expected[food_id] as Dictionary
		assert_eq(String(profile["basis_type"]), String(expected_profile["basis_type"]))
		assert_eq(String(profile["composition_status"]), "known")
		assert_eq(String(profile["confidence"]), "high")
		assert_eq(String(profile["review_status"]), "draft")
		assert_true((profile["evidence_refs"] as Array).has(NUT_204B_GAME_SPEC_ID))
		assert_false((profile["evidence_refs"] as Array).has("PRODUCT-RECIPE-PENDING"))
		var portion := profile["portion"] as Dictionary
		assert_eq(String(portion["status"]), "known")
		assert_eq(float(portion["value"]), float(expected_profile["portion_value"]))
		assert_eq(String(portion["unit"]), String(expected_profile["portion_unit"]))
		assert_eq(String(portion["band"]), String(expected_profile["portion_band"]))
		assert_eq(profile["cooking_methods"], [expected_profile["method"]])


func test_nut_204b_components_keep_amounts_and_small_dairy_semantics() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()

	var coffee: Dictionary = store.get_profile("coffee")
	assert_eq((coffee["components"] as Array).size(), 1)
	var coffee_component := _component_by_id(coffee, "simulated_americano_coffee")
	_assert_component(
		coffee_component,
		"beverages",
		"dominant",
		350.0,
		"ml",
		"menu_recipe"
	)

	var bubble_tea: Dictionary = store.get_profile("bubble_tea")
	assert_eq((bubble_tea["components"] as Array).size(), 4)
	_assert_component(
		_component_by_id(bubble_tea, "simulated_brewed_tea_base"),
		"beverages",
		"dominant",
		340.0,
		"ml",
		"menu_recipe"
	)
	_assert_component(
		_component_by_id(bubble_tea, "simulated_whole_milk"),
		"dairy",
		"small",
		100.0,
		"ml",
		"menu_recipe"
	)
	_assert_component(
		_component_by_id(bubble_tea, "simulated_tapioca_pearls"),
		"other",
		"small",
		60.0,
		"g",
		"menu_recipe"
	)
	_assert_component(
		_component_by_id(bubble_tea, "simulated_added_sugar"),
		"other",
		"small",
		30.0,
		"g",
		"menu_recipe"
	)

	var instant_noodles: Dictionary = store.get_profile("instant_noodles")
	assert_eq((instant_noodles["components"] as Array).size(), 2)
	_assert_component(
		_component_by_id(instant_noodles, "simulated_instant_noodle_cake"),
		"grains_tubers",
		"dominant",
		85.0,
		"g",
		"package_label"
	)
	_assert_component(
		_component_by_id(instant_noodles, "simulated_instant_noodle_seasoning"),
		"other",
		"small",
		15.0,
		"g",
		"package_label"
	)


func test_nut_204b_factor_inputs_and_caffeine_facts_do_not_invent_timing_guidance() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()

	var coffee: Dictionary = store.get_profile("coffee")
	_assert_caffeine(coffee, "known", 100.0, "unknown", "unknown")
	_assert_factor(coffee, "added_sugar", "none", "menu_recipe", NUT_204B_GAME_SPEC_ID, true)
	_assert_factor(coffee, "caffeine", "unknown", "menu_recipe", NUT_204B_GAME_SPEC_ID, false)

	var bubble_tea: Dictionary = store.get_profile("bubble_tea")
	_assert_caffeine(bubble_tea, "known", 50.0, "unknown", "unknown")
	_assert_factor(
		bubble_tea,
		"added_sugar",
		"high",
		"menu_recipe",
		NUT_204B_GAME_SPEC_ID,
		true
	)
	_assert_factor(
		bubble_tea,
		"caffeine",
		"unknown",
		"menu_recipe",
		NUT_204B_GAME_SPEC_ID,
		false
	)
	assert_true(_factor_by_id(bubble_tea, "saturated_fat").is_empty())

	var instant_noodles: Dictionary = store.get_profile("instant_noodles")
	var noodle_caffeine := instant_noodles["caffeine"] as Dictionary
	assert_eq(String(noodle_caffeine["status"]), "not_applicable")
	assert_eq(String(noodle_caffeine["band"]), "none")
	assert_eq(String(noodle_caffeine["serving_time_relevance"]), "none")
	assert_false(noodle_caffeine.has("mg"))
	_assert_factor(
		instant_noodles,
		"sodium",
		"high",
		"package_label",
		NUT_204B_GAME_SPEC_ID,
		true
	)
	assert_true(_factor_by_id(instant_noodles, "saturated_fat").is_empty())


func test_nut_204b_game_spec_is_traceable_but_does_not_approve_health_guidance() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry()
	var game_spec: Dictionary = registry.get_evidence(NUT_204B_GAME_SPEC_ID)
	assert_eq(String(game_spec["source_type"]), "internal_game_spec")
	assert_eq(String(game_spec["url"]), "")
	assert_true((game_spec["supports"] as Array).has("SIMULATED_MENU_RECIPE"))
	assert_true((game_spec["supports"] as Array).has("SIMULATED_PACKAGE_LABEL"))
	for boundary in [
		"REAL_PRODUCT_COMPOSITION",
		"HEALTH_THRESHOLD",
		"PLAYER_GUIDANCE",
		"EXPERT_REVIEW",
	]:
		assert_true((game_spec["does_not_support"] as Array).has(boundary))
	var spec_report: Dictionary = registry.check_references(
		[NUT_204B_GAME_SPEC_ID],
		"2026-07-20"
	)
	assert_true(bool(spec_report["valid"]))

	var store := HealthDataStoreScript.new()
	var catalog: Dictionary = store.load_catalog()
	var validation: Dictionary = HealthDataValidatorScript.validate(catalog, {
		"known_food_ids": _load_card_food_ids(),
		"composite_food_ids": COMPOSITE_PROFILE_IDS,
		"product_food_ids": EXPECTED_PROFILE_IDS,
	})
	var draft_food_ids := _food_ids_for_code(validation["warnings"], "profile_draft")
	for food_id in NUT_204B_PROFILE_IDS:
		assert_true(draft_food_ids.has(food_id))
		var references: Array = store.get_profile(food_id)["evidence_refs"].duplicate()
		for factor_value in store.get_profile(food_id)["factors"]:
			references.append_array((factor_value as Dictionary)["evidence_refs"])
		assert_true(bool(registry.check_references(references, "2026-07-20")["valid"]))


func test_nut_204c_uses_complete_canonical_recipes_with_exact_portions() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	var expected := {
		"celery_pork_stir_fry": {
			"value": 220.0,
			"band": "medium",
			"basis": "menu_recipe",
			"methods": ["stir_fried"],
		},
		"chicken_vegetable_rice": {
			"value": 480.0,
			"band": "large",
			"basis": "menu_recipe",
			"methods": ["mixed"],
		},
		"fried_chicken": {
			"value": 220.0,
			"band": "large",
			"basis": "menu_recipe",
			"methods": ["deep_fried"],
		},
		"salad_bowl": {
			"value": 280.0,
			"band": "large",
			"basis": "menu_recipe",
			"methods": ["raw_ready_to_eat", "mixed"],
		},
		"sandwich": {
			"value": 190.0,
			"band": "medium",
			"basis": "package_label",
			"methods": ["mixed"],
		},
		"steamed_fish": {
			"value": 215.0,
			"band": "medium",
			"basis": "menu_recipe",
			"methods": ["steamed"],
		},
		"tomato_egg_stir_fry": {
			"value": 240.0,
			"band": "medium",
			"basis": "menu_recipe",
			"methods": ["stir_fried"],
		},
	}
	for food_id in NUT_204C_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		var spec := expected[food_id] as Dictionary
		assert_eq(int(profile["profile_version"]), 1)
		assert_eq(String(profile["basis_type"]), String(spec["basis"]))
		assert_eq(String(profile["composition_status"]), "known")
		assert_eq(String(profile["confidence"]), "high")
		assert_eq(String(profile["review_status"]), "draft")
		assert_true((profile["evidence_refs"] as Array).has(NUT_204C_GAME_SPEC_ID))
		assert_false((profile["evidence_refs"] as Array).has("PRODUCT-RECIPE-PENDING"))
		var portion := profile["portion"] as Dictionary
		assert_eq(String(portion["status"]), "known")
		assert_eq(float(portion["value"]), float(spec["value"]))
		assert_eq(String(portion["unit"]), "g")
		assert_eq(String(portion["band"]), String(spec["band"]))
		assert_eq(profile["cooking_methods"], spec["methods"])
		assert_eq(
			_sum_component_amounts(profile, String(portion["unit"])),
			float(portion["value"])
		)
		assert_eq(_component_ids(profile).size(), (profile["components"] as Array).size())
		_assert_non_caffeinated(profile)


func test_nut_204c_components_match_the_frozen_game_spec() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	var expected := {
		"fried_chicken": [
			["chicken_meat", "poultry_livestock", "dominant", 150.0],
			["wheat_flour_coating", "grains_tubers", "small", 40.0],
			["absorbed_frying_oil", "other", "small", 20.0],
			["fried_chicken_seasoning", "other", "trace", 10.0],
		],
		"salad_bowl": [
			["romaine_lettuce", "vegetables", "material", 100.0],
			["cucumber", "vegetables", "small", 60.0],
			["tomato", "vegetables", "small", 60.0],
			["red_cabbage", "vegetables", "small", 40.0],
			["oil_vinegar_dressing", "other", "small", 20.0],
		],
		"sandwich": [
			["white_wheat_bread", "grains_tubers", "dominant", 90.0],
			["chicken_egg", "eggs", "material", 50.0],
			["romaine_lettuce", "vegetables", "small", 20.0],
			["tomato", "vegetables", "small", 20.0],
			["mayonnaise", "other", "small", 10.0],
		],
		"tomato_egg_stir_fry": [
			["tomato", "vegetables", "dominant", 130.0],
			["chicken_egg", "eggs", "material", 90.0],
			["stir_fry_oil", "other", "small", 10.0],
			["tomato_egg_seasoning", "other", "trace", 10.0],
		],
		"celery_pork_stir_fry": [
			["celery", "vegetables", "dominant", 120.0],
			["lean_pork", "poultry_livestock", "material", 75.0],
			["stir_fry_oil", "other", "small", 10.0],
			["celery_pork_seasoning", "other", "small", 15.0],
		],
		"steamed_fish": [
			["sea_bass_meat", "fish_seafood", "dominant", 180.0],
			["scallion_ginger", "vegetables", "trace", 10.0],
			["steamed_fish_sauce", "other", "small", 20.0],
			["finishing_oil", "other", "trace", 5.0],
		],
		"chicken_vegetable_rice": [
			["cooked_white_rice", "grains_tubers", "dominant", 200.0],
			["chicken_meat", "poultry_livestock", "material", 100.0],
			["broccoli", "vegetables", "material", 70.0],
			["bok_choy", "vegetables", "small", 50.0],
			["carrot", "vegetables", "small", 30.0],
			["chicken_rice_sauce", "other", "small", 20.0],
			["stir_fry_oil", "other", "small", 10.0],
		],
	}
	for food_id in NUT_204C_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		var component_specs := expected[food_id] as Array
		assert_eq((profile["components"] as Array).size(), component_specs.size())
		for component_spec_value in component_specs:
			var component_spec := component_spec_value as Array
			_assert_component(
				_component_by_id(profile, String(component_spec[0])),
				String(component_spec[1]),
				String(component_spec[2]),
				float(component_spec[3]),
				"g",
				String(profile["basis_type"])
			)


func test_nut_204c_shared_ingredient_ids_support_future_dedup_without_false_groups() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	assert_eq(int(store.get_profile("rice_plain")["profile_version"]), 2)
	assert_eq(int(store.get_profile("egg")["profile_version"]), 2)
	assert_eq(int(store.get_profile("tomato")["profile_version"]), 2)
	for food_id in ["rice_plain", "chicken_vegetable_rice"]:
		assert_false(_component_by_id(store.get_profile(food_id), "cooked_white_rice").is_empty())
	for food_id in ["egg", "sandwich", "tomato_egg_stir_fry"]:
		assert_false(_component_by_id(store.get_profile(food_id), "chicken_egg").is_empty())
	for food_id in ["tomato", "salad_bowl", "sandwich", "tomato_egg_stir_fry"]:
		assert_false(_component_by_id(store.get_profile(food_id), "tomato").is_empty())
	for food_id in ["fried_chicken", "chicken_vegetable_rice"]:
		assert_false(_component_by_id(store.get_profile(food_id), "chicken_meat").is_empty())
	for food_id in ["salad_bowl", "sandwich"]:
		assert_false(_component_by_id(store.get_profile(food_id), "romaine_lettuce").is_empty())

	assert_true(_components_with_group(store.get_profile("salad_bowl"), "fruits").is_empty())
	assert_eq(
		String(_component_by_id(store.get_profile("sandwich"), "chicken_egg")["food_group"]),
		"eggs"
	)
	assert_eq(
		String(_component_by_id(store.get_profile("steamed_fish"), "scallion_ginger")[
			"contribution_band"
		]),
		"trace"
	)
	assert_eq(
		String(_component_by_id(store.get_profile("fried_chicken"), "wheat_flour_coating")[
			"contribution_band"
		]),
		"small"
	)


func test_nut_204c_methods_are_facts_while_unclassified_factors_stay_unknown() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	for food_id in NUT_204C_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		_assert_factor(
			profile,
			"sodium",
			"unknown",
			String(profile["basis_type"]),
			NUT_204C_GAME_SPEC_ID,
			true
		)
		for factor_value in profile["factors"]:
			var factor := factor_value as Dictionary
			assert_false(String(factor["band"]) in ["moderate", "high"])

	var fried_chicken: Dictionary = store.get_profile("fried_chicken")
	assert_true((fried_chicken["cooking_methods"] as Array).has("deep_fried"))
	_assert_factor(
		fried_chicken,
		"deep_fried",
		"present",
		"menu_recipe",
		NUT_204C_GAME_SPEC_ID,
		true
	)
	assert_eq(String(_factor_by_id(store.get_profile("steamed_fish"), "sodium")["band"]), "unknown")


func test_nut_204c_game_spec_is_usable_provenance_but_not_health_approval() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry()
	var game_spec: Dictionary = registry.get_evidence(NUT_204C_GAME_SPEC_ID)
	assert_eq(String(game_spec["source_type"]), "internal_game_spec")
	assert_eq(String(game_spec["url"]), "")
	for support in [
		"SIMULATED_MENU_RECIPE",
		"SIMULATED_PACKAGE_LABEL",
		"SIMULATED_INGREDIENT_COMPOSITION",
		"SIMULATED_COOKING_METHOD",
		"SHARED_INGREDIENT_IDENTITY",
	]:
		assert_true((game_spec["supports"] as Array).has(support))
	for boundary in [
		"REAL_DISH_COMPOSITION",
		"HEALTH_THRESHOLD",
		"PLAYER_GUIDANCE",
		"EXPERT_REVIEW",
		"ALLERGEN_COMPLETENESS",
		"FOOD_SAFETY",
	]:
		assert_true((game_spec["does_not_support"] as Array).has(boundary))
	assert_true(bool(registry.check_references(
		[NUT_204C_GAME_SPEC_ID],
		"2026-07-20",
		["SIMULATED_INGREDIENT_COMPOSITION"]
	)["valid"]))
	var guidance_check: Dictionary = registry.check_references(
		[NUT_204C_GAME_SPEC_ID],
		"2026-07-20",
		["PLAYER_GUIDANCE"]
	)
	assert_false(bool(guidance_check["valid"]))
	assert_eq(guidance_check["unsupported_capabilities"], ["PLAYER_GUIDANCE"])

	var store := HealthDataStoreScript.new()
	var catalog: Dictionary = store.load_catalog()
	var validation: Dictionary = HealthDataValidatorScript.validate(catalog, {
		"known_food_ids": _load_card_food_ids(),
		"composite_food_ids": COMPOSITE_PROFILE_IDS,
		"product_food_ids": EXPECTED_PROFILE_IDS,
	})
	assert_true(bool(validation["valid"]))
	for food_id in NUT_204C_PROFILE_IDS:
		var issues := _issues_for_food(validation["warnings"], food_id)
		assert_eq(issues.size(), 1)
		assert_eq(String(issues[0]["code"]), "profile_draft")
		var profile: Dictionary = store.get_profile(food_id)
		var references: Array = profile["evidence_refs"].duplicate()
		for factor_value in profile["factors"]:
			references.append_array((factor_value as Dictionary)["evidence_refs"])
		assert_true(bool(registry.check_references(references, "2026-07-20")["valid"]))


func test_nut_204d_uses_fixed_simulated_package_labels_and_portions() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	var expected := {
		"milk": {
			"value": 250.0,
			"unit": "ml",
			"band": "medium",
			"methods": ["not_applicable"],
		},
		"plain_yogurt": {
			"value": 180.0,
			"unit": "g",
			"band": "medium",
			"methods": ["not_applicable"],
		},
		"whole_wheat_bread": {
			"value": 70.0,
			"unit": "g",
			"band": "small",
			"methods": ["baked"],
		},
	}
	for food_id in NUT_204D_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		var spec := expected[food_id] as Dictionary
		assert_eq(int(profile["profile_version"]), 1)
		assert_eq(String(profile["basis_type"]), "package_label")
		assert_eq(String(profile["composition_status"]), "known")
		assert_eq(String(profile["confidence"]), "high")
		assert_eq(String(profile["review_status"]), "draft")
		assert_true((profile["evidence_refs"] as Array).has(NUT_204D_GAME_SPEC_ID))
		assert_false((profile["evidence_refs"] as Array).has("PRODUCT-RECIPE-PENDING"))
		var portion := profile["portion"] as Dictionary
		assert_eq(String(portion["status"]), "known")
		assert_eq(float(portion["value"]), float(spec["value"]))
		assert_eq(String(portion["unit"]), String(spec["unit"]))
		assert_eq(String(portion["band"]), String(spec["band"]))
		assert_eq(profile["cooking_methods"], spec["methods"])
		assert_eq(
			_sum_component_amounts(profile, String(portion["unit"])),
			float(portion["value"])
		)
		assert_eq(_component_ids(profile).size(), (profile["components"] as Array).size())
		_assert_non_caffeinated(profile)


func test_nut_204d_components_match_the_frozen_product_spec_and_shared_ids() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	var expected := {
		"milk": [
			["simulated_whole_milk", "dairy", "dominant", 250.0, "ml"],
		],
		"plain_yogurt": [
			["simulated_plain_yogurt_base", "dairy", "dominant", 172.0, "g"],
			["simulated_added_sugar", "other", "small", 8.0, "g"],
		],
		"whole_wheat_bread": [
			[
				"simulated_whole_wheat_bread",
				"grains_tubers",
				"dominant",
				70.0,
				"g",
			],
		],
	}
	for food_id in NUT_204D_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		var component_specs := expected[food_id] as Array
		assert_eq((profile["components"] as Array).size(), component_specs.size())
		for component_spec_value in component_specs:
			var component_spec := component_spec_value as Array
			_assert_component(
				_component_by_id(profile, String(component_spec[0])),
				String(component_spec[1]),
				String(component_spec[2]),
				float(component_spec[3]),
				String(component_spec[4]),
				"package_label"
			)

	for food_id in ["bubble_tea", "milk"]:
		assert_false(_component_by_id(
			store.get_profile(food_id),
			"simulated_whole_milk"
		).is_empty())
	for food_id in ["bubble_tea", "plain_yogurt"]:
		assert_false(_component_by_id(
			store.get_profile(food_id),
			"simulated_added_sugar"
		).is_empty())
	assert_true(_component_by_id(
		store.get_profile("whole_wheat_bread"),
		"white_wheat_bread"
	).is_empty())


func test_nut_204d_raw_factor_facts_do_not_invent_health_bands() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	_assert_factor(
		store.get_profile("milk"),
		"added_sugar",
		"none",
		"package_label",
		NUT_204D_GAME_SPEC_ID,
		true
	)
	_assert_factor(
		store.get_profile("plain_yogurt"),
		"added_sugar",
		"unknown",
		"package_label",
		NUT_204D_GAME_SPEC_ID,
		true
	)
	for factor_id in ["added_sugar", "sodium"]:
		_assert_factor(
			store.get_profile("whole_wheat_bread"),
			factor_id,
			"unknown",
			"package_label",
			NUT_204D_GAME_SPEC_ID,
			true
		)
	for food_id in NUT_204D_PROFILE_IDS:
		for factor_value in store.get_profile(food_id)["factors"]:
			var factor := factor_value as Dictionary
			assert_false(String(factor["band"]) in ["low", "moderate", "high"])


func test_nut_204d_keeps_unparsed_allergen_and_food_safety_states_empty() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	for food_id in NUT_204D_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		assert_true((profile["allergens"] as Array).is_empty())
		assert_true((profile["food_safety"] as Dictionary).is_empty())


func test_nut_204d_game_spec_supports_product_facts_but_not_health_approval() -> void:
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry()
	var game_spec: Dictionary = registry.get_evidence(NUT_204D_GAME_SPEC_ID)
	assert_eq(String(game_spec["source_type"]), "internal_game_spec")
	assert_eq(String(game_spec["url"]), "")
	var required_product_capabilities := [
		"SHARED_INGREDIENT_IDENTITY",
		"SIMULATED_COOKING_METHOD",
		"SIMULATED_FACTOR_INPUT",
		"SIMULATED_INGREDIENT_COMPOSITION",
		"SIMULATED_PACKAGE_LABEL",
		"SIMULATED_PORTION",
	]
	for capability in required_product_capabilities:
		assert_true((game_spec["supports"] as Array).has(capability))
	for boundary in [
		"REAL_PRODUCT_COMPOSITION",
		"REAL_PRODUCT_LABEL",
		"HEALTH_THRESHOLD",
		"PLAYER_GUIDANCE",
		"EXPERT_REVIEW",
		"ALLERGEN_COMPLETENESS",
		"FOOD_SAFETY",
		"REGULATORY_LABEL_COMPLIANCE",
	]:
		assert_true((game_spec["does_not_support"] as Array).has(boundary))
	assert_true(bool(registry.check_references(
		[NUT_204D_GAME_SPEC_ID],
		"2026-07-20",
		required_product_capabilities
	)["valid"]))
	for unsupported_capability in [
		"REAL_PRODUCT_LABEL",
		"HEALTH_THRESHOLD",
		"PLAYER_GUIDANCE",
		"ALLERGEN_COMPLETENESS",
		"FOOD_SAFETY",
		"REGULATORY_LABEL_COMPLIANCE",
	]:
		var boundary_check: Dictionary = registry.check_references(
			[NUT_204D_GAME_SPEC_ID],
			"2026-07-20",
			[unsupported_capability]
		)
		assert_false(bool(boundary_check["valid"]))
		assert_eq(boundary_check["unsupported_capabilities"], [unsupported_capability])

	var store := HealthDataStoreScript.new()
	var catalog: Dictionary = store.load_catalog()
	var validation: Dictionary = HealthDataValidatorScript.validate(catalog, {
		"known_food_ids": _load_card_food_ids(),
		"composite_food_ids": COMPOSITE_PROFILE_IDS,
		"product_food_ids": EXPECTED_PROFILE_IDS,
	})
	assert_true(bool(validation["valid"]))
	for food_id in NUT_204D_PROFILE_IDS:
		var issues := _issues_for_food(validation["warnings"], food_id)
		assert_eq(issues.size(), 1)
		assert_eq(String(issues[0]["code"]), "profile_draft")
		var profile: Dictionary = store.get_profile(food_id)
		var references: Array = profile["evidence_refs"].duplicate()
		for factor_value in profile["factors"]:
			references.append_array((factor_value as Dictionary)["evidence_refs"])
		var profile_evidence_check: Dictionary = registry.check_references(
			references,
			"2026-07-20",
			[
				"SIMULATED_PACKAGE_LABEL",
				"SIMULATED_PORTION",
				"SIMULATED_INGREDIENT_COMPOSITION",
			]
		)
		assert_true(bool(profile_evidence_check["valid"]))


func test_nut_205_unknown_portions_and_factors_never_inherit_legacy_claims() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	for food_id in NUT_205_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		assert_eq(String(profile["basis_type"]), "generic_category")
		assert_eq(String(profile["confidence"]), "low")
		assert_eq(String(profile["review_status"]), "draft")
		assert_eq(String(profile["reviewed_by"]), "")
		var portion := profile["portion"] as Dictionary
		assert_eq(String(portion["status"]), "unknown")
		assert_eq(String(portion["band"]), "unknown")
		assert_false(portion.has("value"))
		assert_false(portion.has("unit"))
		assert_eq(profile["cooking_methods"], ["unknown"])
		assert_eq(String(profile["caffeine"]["status"]), "unknown")
		assert_false((profile["caffeine"] as Dictionary).has("mg"))
		assert_true((profile["allergens"] as Array).is_empty())
		assert_true((profile["food_safety"] as Dictionary).is_empty())
		for legacy_field in ["nutrient_tags", "limit_tags", "whole_grain", "burden", "mood"]:
			assert_false(profile.has(legacy_field))
		for factor in profile["factors"]:
			assert_eq(String(factor["band"]), "unknown")
			assert_eq(String(factor["basis_type"]), "unknown")
	for food_id in ["oatmeal", "unsalted_nuts"]:
		for factor_id in ["added_sugar", "sodium"]:
			assert_eq(String(_factor_by_id(store.get_profile(food_id), factor_id)["band"]), "unknown")


func test_nut_205_categories_do_not_invent_ingredients_or_vegetable_contributions() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	var expected := {
		"apple": ["apple", "fruits", "dominant"],
		"banana": ["banana", "fruits", "dominant"],
		"oatmeal": ["oats_unspecified", "grains_tubers", "unknown"],
		"unsalted_nuts": ["nuts_unspecified", "nuts_seeds", "unknown"],
	}
	for food_id in NUT_205_PROFILE_IDS:
		var profile: Dictionary = store.get_profile(food_id)
		var components := profile["components"] as Array
		assert_eq(String(profile["composition_status"]), "estimated")
		assert_eq(components.size(), 1)
		var component := components[0] as Dictionary
		assert_eq(String(component["ingredient_id"]), String(expected[food_id][0]))
		assert_eq(String(component["food_group"]), String(expected[food_id][1]))
		assert_eq(String(component["contribution_band"]), String(expected[food_id][2]))
		assert_eq(String(component["confidence"]), "low")
		assert_false(component.has("amount_value"))
		assert_false(component.has("amount_unit"))
		assert_true(_components_with_group(profile, "vegetables").is_empty())
		assert_true(_components_with_group(profile, "dairy").is_empty())


func test_nut_205_coverage_does_not_clear_pending_or_overdue_evidence() -> void:
	var store := HealthDataStoreScript.new()
	store.load_catalog()
	var registry := HealthEvidenceRegistryScript.new()
	registry.load_registry()
	for food_id in NUT_205_PROFILE_IDS:
		var references: Array = store.get_profile(food_id)["evidence_refs"]
		var check: Dictionary = registry.check_references(
			references, "2026-09-04", ["PLAYER_GUIDANCE"]
		)
		assert_true((check["missing_ids"] as Array).is_empty())
		assert_false(bool(check["valid"]))
		assert_true((check["needs_review_ids"] as Array).has("PRODUCT-RECIPE-PENDING"))
		assert_true((check["registry_audit"]["review_due_ids"] as Array).has("PRODUCT-RECIPE-PENDING"))
		assert_true((check["unsupported_capabilities"] as Array).has("PLAYER_GUIDANCE"))
	# Even an existing food card must stay unknown when the health catalog is empty.
	store.load_catalog("res://tests/fixtures/health_data_store/empty_catalog.xml")
	for food_id in NUT_205_PROFILE_IDS:
		var lookup: Dictionary = store.lookup_profile(food_id)
		assert_eq(String(lookup["status"]), "information_insufficient")
		assert_eq(String(lookup["reason"]), "profile_missing")
		assert_true((lookup["profile"] as Dictionary).is_empty())


func _load_card_food_ids() -> Array[String]:
	var result: Array[String] = []
	var parser := XMLParser.new()
	if parser.open("res://data/cards/foods.xml") != OK:
		return result
	var read_error := parser.read()
	while read_error == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "food":
			for index in range(parser.get_attribute_count()):
				if parser.get_attribute_name(index) == "id":
					result.append(parser.get_attribute_value(index))
					break
		read_error = parser.read()
	result.sort()
	return result


func _issues_with_code(issues: Array, code: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue_value in issues:
		var issue := issue_value as Dictionary
		if String(issue.get("code", "")) == code:
			result.append(issue)
	return result


func _food_ids_for_code(issues: Array, code: String) -> Array[String]:
	var result: Array[String] = []
	for issue in _issues_with_code(issues, code):
		var food_id := String(issue.get("food_id", ""))
		if not result.has(food_id):
			result.append(food_id)
	return result


func _issues_for_food(issues: Array, food_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue_value in issues:
		var issue := issue_value as Dictionary
		if String(issue.get("food_id", "")) == food_id:
			result.append(issue)
	return result


func _component_ids(profile: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for component_value in profile.get("components", []):
		var ingredient_id := String((component_value as Dictionary).get("ingredient_id", ""))
		if not result.has(ingredient_id):
			result.append(ingredient_id)
	return result


func _components_with_group(profile: Dictionary, food_group: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for component_value in profile.get("components", []):
		var component := component_value as Dictionary
		if String(component.get("food_group", "")) == food_group:
			result.append(component)
	return result


func _sum_component_amounts(profile: Dictionary, amount_unit: String = "g") -> float:
	var total := 0.0
	for component_value in profile.get("components", []):
		var component := component_value as Dictionary
		if String(component.get("amount_unit", "")) == amount_unit:
			total += float(component.get("amount_value", 0.0))
	return total


func _component_by_id(profile: Dictionary, ingredient_id: String) -> Dictionary:
	for component_value in profile.get("components", []):
		var component := component_value as Dictionary
		if String(component.get("ingredient_id", "")) == ingredient_id:
			return component
	return {}


func _factor_by_id(profile: Dictionary, factor_id: String) -> Dictionary:
	for factor_value in profile.get("factors", []):
		var factor := factor_value as Dictionary
		if String(factor.get("factor_id", "")) == factor_id:
			return factor
	return {}


func _assert_component(
	component: Dictionary,
	food_group: String,
	contribution_band: String,
	amount_value: float,
	amount_unit: String,
	basis_type: String
) -> void:
	assert_false(component.is_empty())
	assert_eq(String(component["food_group"]), food_group)
	assert_eq(String(component["contribution_band"]), contribution_band)
	assert_eq(float(component["amount_value"]), amount_value)
	assert_eq(String(component["amount_unit"]), amount_unit)
	assert_eq(String(component["basis_type"]), basis_type)
	assert_eq(String(component["confidence"]), "high")


func _assert_caffeine(
	profile: Dictionary,
	status: String,
	mg: float,
	band: String,
	serving_time_relevance: String
) -> void:
	var caffeine := profile["caffeine"] as Dictionary
	assert_eq(String(caffeine["status"]), status)
	assert_eq(float(caffeine["mg"]), mg)
	assert_eq(String(caffeine["band"]), band)
	assert_eq(String(caffeine["serving_time_relevance"]), serving_time_relevance)


func _assert_non_caffeinated(profile: Dictionary) -> void:
	var caffeine := profile["caffeine"] as Dictionary
	assert_eq(String(caffeine["status"]), "not_applicable")
	assert_eq(String(caffeine["band"]), "none")
	assert_eq(String(caffeine["serving_time_relevance"]), "none")
	assert_false(caffeine.has("mg"))


func _assert_factor(
	profile: Dictionary,
	factor_id: String,
	band: String,
	basis_type: String,
	game_spec_id: String,
	requires_general_guideline: bool
) -> void:
	var factor := _factor_by_id(profile, factor_id)
	assert_false(factor.is_empty())
	assert_eq(String(factor["band"]), band)
	assert_eq(String(factor["basis_type"]), basis_type)
	assert_eq(String(factor["confidence"]), "high")
	var references := factor["evidence_refs"] as Array
	assert_true(references.has(game_spec_id))
	assert_eq(references.has("CDG-2022-05"), requires_general_guideline)
