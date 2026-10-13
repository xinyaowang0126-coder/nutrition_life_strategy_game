@tool
extends McpTestSuite

const Ledger := preload("res://scripts/health/DietPatternLedger.gd")
const Presenter := preload("res://scripts/health/DietPatternPresenter.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const MealModel := preload("res://tests/preview/G4PreviewModel.gd")
const RecordModel := preload("res://tests/preview/G4RecordPreviewModel.gd")
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Store := preload("res://scripts/health/HealthDataStore.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Preview := preload("res://tests/preview/G4RecordPreview.tscn")
const DATE := "2026-10-11"
var fixture := MealModel.new()


func suite_name() -> String:
	return "g4_ledger"


func setup() -> void:
	fixture = MealModel.new()


func test_composite_and_single_ingredient_count_once_per_meal_and_period() -> void:
	var ledger := Ledger.new()
	assert_true(_append(ledger, _meal(1, "breakfast", ["fixture_mixed", "fixture_egg"]))["valid"])
	assert_true(_append(ledger, _meal(1, "lunch", ["fixture_mixed"]))["valid"])
	var view := ledger.day_view(1)
	assert_eq(view["diversity"]["unique_ingredient_count"], 3)
	var ingredients: Array = view["diversity"]["segments"][0]["ingredients"]
	assert_eq(ingredients.size(), 3, "Trace seasoning and repeated egg do not inflate diversity")
	for ingredient in ingredients:
		assert_eq(ingredient["meal_keys"], ["1:breakfast", "1:lunch"])
		assert_eq(ingredient["days"], [1])
	assert_eq(view["regularity"]["unrecorded"], 1)
	assert_eq(view["diversity"]["status"], "partial")
	assert_eq(view["attention_factors"]["status"], "not_evaluated")


func test_unknown_portions_keep_supported_composition_and_have_a_separate_list() -> void:
	var ledger := Ledger.new()
	_append(ledger, _meal(1, "breakfast", ["fixture_mixed"]))
	var day := ledger.day_view(1)
	assert_eq(day["meals"][0]["composition_status"], "supported")
	assert_eq(day["meals"][0]["ingredients"].size(), 3)
	assert_eq(day["diversity"]["unknown_portion_meal_keys"], ["1:breakfast"])
	assert_eq(day["diversity"]["segments"][0]["unknown_meal_keys"], [])
	assert_contains(Presenter.day_view(ledger, 1)["notes"], "1 餐份量未标。")


func test_roles_remain_separate_for_each_meal_without_cross_meal_compensation() -> void:
	var ledger := Ledger.new()
	_append(ledger, _meal(1, "breakfast", ["fixture_rice"]))
	_append(ledger, _meal(1, "lunch", ["fixture_vegetable"]))
	_append(ledger, _meal(1, "dinner", ["fixture_egg"]))
	var meals: Array = ledger.day_view(1)["meals"]
	assert_eq(meals[0]["roles"]["vegetable"]["presence"], "not_recorded")
	assert_eq(meals[1]["roles"]["staple"]["presence"], "not_recorded")
	assert_eq(meals[2]["roles"]["protein_source"]["presence"], "material")
	assert_eq(meals[2]["roles"]["vegetable"]["presence"], "not_recorded")
	assert_eq(ledger.day_view(1)["diversity"]["unique_ingredient_count"], 3)


func test_unrecorded_skipped_and_legacy_are_distinct_and_unknown_is_not_zero() -> void:
	var ledger := Ledger.new()
	_append(ledger, Snapshot.build(1, {"phase": "lunch", "skipped": true}, fixture.catalog))
	_append(ledger, Snapshot.legacy(1, {"phase": "dinner", "food_ids": ["fixture_mixed"], "skipped": true}))
	var day := ledger.day_view(1)
	assert_eq(day["regularity"], {"eaten": 0, "skipped": 1, "legacy_unknown": 1, "unrecorded": 1})
	assert_eq(day["meals"][0]["status"], "unrecorded")
	assert_eq(day["meals"][2]["ingredients"], [])
	assert_eq(day["diversity"]["unique_ingredient_count"], null)
	assert_eq(Presenter.day_view(ledger, 1)["summary"], "午饭没吃。")


func test_repeated_meals_across_days_do_not_create_new_ingredient_identities() -> void:
	var ledger := Ledger.new()
	for day in range(1, 8):
		for phase in Ledger.PHASES:
			_append(ledger, _meal(day, phase, ["fixture_mixed"]))
	var week := ledger.week_view()
	assert_eq(week["regularity"]["eaten"], 21)
	assert_eq(week["diversity"]["status"], "supported")
	assert_eq(week["diversity"]["unique_ingredient_count"], 3)
	for ingredient in week["diversity"]["segments"][0]["ingredients"]:
		assert_eq(ingredient["meal_keys"].size(), 21)
		assert_eq(ingredient["days"], [1, 2, 3, 4, 5, 6, 7])
	assert_eq(week["primary_suggestion"], null)


func test_snapshot_catalog_config_and_copy_changes_cannot_rewrite_frozen_history() -> void:
	var ledger := Ledger.new()
	var snapshot := _meal(1, "breakfast", ["fixture_mixed"])
	var original := snapshot.duplicate(true)
	_append(ledger, snapshot)
	var before := ledger.day_view(1)
	snapshot["profile_snapshots"].clear()
	fixture.catalog["profiles"].clear()
	fixture.config["review_status"] = "draft"
	fixture.copies["copies"].clear()
	assert_eq(ledger.day_view(1), before)
	assert_eq(ledger.get_snapshots()[0], original)
	var entries := ledger.get_entries()
	entries[0]["ingredients"].clear()
	ledger.get_snapshots().clear()
	assert_eq(ledger.day_view(1), before)


func test_duplicate_invalid_and_future_records_fail_transactionally() -> void:
	var ledger := Ledger.new()
	var breakfast := _meal(1, "breakfast", ["fixture_rice"])
	_append(ledger, breakfast)
	var before := ledger.get_entries()
	assert_false(_append(ledger, breakfast)["valid"])
	var malformed := breakfast.duplicate(true)
	malformed["component_snapshot"] = []
	assert_false(_append(ledger, malformed)["valid"])
	var extra := _meal(1, "lunch", ["fixture_egg"])
	assert_false(ledger.replace_snapshots([extra, malformed], fixture.config, fixture.registry, DATE, fixture.copies)["valid"])
	assert_eq(ledger.get_entries(), before)
	assert_false(_append(ledger, _meal(8, "breakfast", ["fixture_rice"]))["valid"])
	assert_false(ledger.replace_snapshots(true, fixture.config, fixture.registry, DATE, fixture.copies)["valid"])
	assert_false(ledger.day_view(0)["valid"])
	assert_false(ledger.week_view(8)["valid"])


func test_unknown_unsupported_model_is_preserved_and_never_summed_across_versions() -> void:
	var ledger := Ledger.new()
	_append(ledger, _meal(1, "breakfast", ["fixture_mixed"]))
	var future := _meal(2, "breakfast", ["fixture_mixed"])
	future["model_version"] = "diet-future"
	for profile in future["profile_snapshots"].values():
		profile["model_version"] = "diet-future"
	assert_true(Snapshot.validate(future)["valid"])
	assert_true(_append(ledger, future)["valid"])
	var week := ledger.week_view(2)
	assert_eq(week["diversity"]["status"], "segmented")
	assert_eq(week["diversity"]["unique_ingredient_count"], null)
	assert_eq(week["diversity"]["segments"].size(), 2)
	assert_eq(ledger.day_view(2)["meals"][0]["composition_status"], "unsupported_model")
	assert_eq(ledger.day_view(2)["diversity"]["unique_ingredient_count"], null)
	assert_eq(ledger.get_snapshots()[1], future)


func test_unavailable_missing_and_low_confidence_do_not_become_known_zero() -> void:
	var ledger := Ledger.new()
	var missing := Snapshot.build(1, {"phase": "breakfast", "food_ids": ["fixture_rice"]}, {})
	_append(ledger, missing)
	_append(ledger, _meal(1, "lunch", ["fixture_low"]))
	_append(ledger, _meal(1, "dinner", ["fixture_rice", "absent_food"]))
	var day := ledger.day_view(1)
	assert_eq(day["regularity"]["eaten"], 3)
	assert_eq(day["meals"][0]["composition_status"], "unknown")
	assert_eq(day["meals"][1]["ingredients"], [])
	assert_eq(day["meals"][2]["roles"]["vegetable"]["presence"], "unknown")
	assert_eq(day["diversity"]["unique_ingredient_count"], 1)
	assert_eq(day["diversity"]["status"], "partial")


func test_conflicting_identity_within_a_model_is_excluded_from_aggregate_count() -> void:
	var ledger := Ledger.new()
	_append(ledger, _meal(1, "breakfast", ["fixture_vegetable"]))
	var catalog: Dictionary = fixture.catalog.duplicate(true)
	var profile: Dictionary = catalog["profiles"]["fixture_vegetable"]
	profile["components"][0]["food_group"] = "fruits"
	catalog["profile_entries"] = catalog["profiles"].values()
	var conflicting := Snapshot.build(1, {"phase": "lunch", "food_ids": ["fixture_vegetable"]}, catalog)
	# Other fixture profiles still use the original identity; isolate the
	# proposed profile so the snapshot itself is structurally valid.
	catalog["profiles"] = {"fixture_vegetable": profile}
	catalog["profile_entries"] = [profile]
	conflicting = Snapshot.build(1, {"phase": "lunch", "food_ids": ["fixture_vegetable"]}, catalog)
	assert_true(_append(ledger, conflicting)["valid"])
	var segment: Dictionary = ledger.day_view(1)["diversity"]["segments"][0]
	assert_eq(segment["conflicting_ingredient_ids"], ["shared_tomato"])
	assert_eq(segment["ingredients"], [])
	assert_eq(segment["unique_ingredient_count"], 0)
	assert_eq(segment["status"], "partial")
	var one_meal := _meal(2, "breakfast", ["fixture_mixed", "fixture_vegetable"])
	one_meal["profile_snapshots"]["fixture_vegetable"]["components"][0]["food_group"] = "fruits"
	for component in one_meal["component_snapshot"]:
		if component["food_id"] == "fixture_vegetable" and component["ingredient_id"] == "shared_tomato":
			component["food_group"] = "fruits"
	assert_true(Snapshot.validate(one_meal)["valid"], "The ledger applies a stricter cross-profile identity boundary")
	var before := ledger.get_entries()
	assert_false(_append(ledger, one_meal)["valid"])
	assert_eq(ledger.get_entries(), before)


func test_week_cutoff_and_unplaced_legacy_do_not_invent_or_consume_meal_slots() -> void:
	var ledger := Ledger.new()
	_append(ledger, _meal(1, "breakfast", ["fixture_rice"]))
	_append(ledger, _meal(7, "dinner", ["fixture_egg"]))
	_append(ledger, Snapshot.legacy(0, {"food_ids": ["fixture_mixed"]}))
	var week := ledger.week_view(1)
	assert_eq(week["meals"].size(), 3)
	assert_eq(week["regularity"]["eaten"], 1)
	assert_eq(week["unplaced_legacy_count"], 1)
	assert_eq(week["diversity"]["unique_ingredient_count"], 1)
	assert_eq(ledger.get_snapshots().size(), 3)
	assert_eq(ledger.week_view()["regularity"]["eaten"], 2)


func test_production_drafts_and_pending_copy_never_expose_ingredient_counts() -> void:
	var ledger := Ledger.new()
	var registry := Evidence.new()
	registry.load_registry()
	var catalog := Store.new().load_catalog()
	var production := Snapshot.build(1, {"phase": "breakfast", "food_ids": ["sandwich"]}, catalog)
	assert_true(ledger.append_snapshot(production, Config.defaults(), registry, DATE, Composer.load_catalog())["valid"])
	assert_eq(ledger.day_view(1)["regularity"]["eaten"], 1)
	assert_eq(ledger.day_view(1)["diversity"]["unique_ingredient_count"], null)
	assert_eq(Presenter.day_view(ledger, 1)["composition"][0]["lines"], [])
	for key in ["data", "engine", "ui", "weekly"]:
		assert_false(bool(ProjectSettings.get_setting("health_guidance_v2/" + key)))
	var blocked := Ledger.new()
	assert_true(blocked.append_snapshot(_meal(1, "breakfast", ["fixture_mixed"]), fixture.config, fixture.registry, DATE, Composer.load_catalog())["valid"])
	assert_eq(blocked.day_view(1)["diversity"]["unique_ingredient_count"], null)


func test_order_independence_and_json_integer_days_are_supported() -> void:
	var records := [_meal(1, "breakfast", ["fixture_mixed"]), _meal(2, "lunch", ["fixture_fruit"])]
	var first := Ledger.new()
	var second := Ledger.new()
	assert_true(first.replace_snapshots(records, fixture.config, fixture.registry, DATE, fixture.copies)["valid"])
	records.reverse()
	assert_true(second.replace_snapshots(records, fixture.config, fixture.registry, DATE, fixture.copies)["valid"])
	assert_eq(first.week_view(2), second.week_view(2))
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(_meal(3, "breakfast", ["fixture_mixed"])))
	assert_true(_append(first, parsed)["valid"])
	assert_eq(first.day_view(3)["regularity"]["eaten"], 1)
	assert_eq(first.day_view(3)["diversity"]["unique_ingredient_count"], 3)


func test_all_skipped_empty_and_clear_views_are_factual_without_scores() -> void:
	var ledger := Ledger.new()
	assert_eq(ledger.day_view(1)["diversity"]["unique_ingredient_count"], null)
	for phase in Ledger.PHASES:
		_append(ledger, Snapshot.build(1, {"phase": phase, "skipped": true}, fixture.catalog))
	assert_eq(ledger.day_view(1)["diversity"]["status"], "not_applicable")
	assert_eq(ledger.day_view(1)["diversity"]["unique_ingredient_count"], 0)
	assert_eq(Presenter.day_view(ledger, 1)["summary"], "今天三顿都没吃。")
	_assert_no_scores(ledger.week_view())
	ledger.clear()
	assert_eq(ledger.get_entries(), [])
	assert_eq(ledger.day_view(1)["regularity"]["unrecorded"], 3)


func test_factors_stay_frozen_and_gameplay_or_invalid_context_cannot_enter_the_ledger() -> void:
	var ledger := Ledger.new()
	var snapshot := _meal(1, "breakfast", ["fixture_mixed"])
	var factors: Array = snapshot["factor_snapshot"].duplicate(true)
	assert_true(_append(ledger, snapshot)["valid"])
	_append(ledger, _meal(1, "lunch", ["fixture_vegetable"]))
	ledger.day_view(1)
	ledger.week_view()
	assert_eq(ledger.get_snapshots()[0]["factor_snapshot"], factors)
	var before := ledger.get_entries()
	var contaminated := _meal(1, "dinner", ["fixture_egg"])
	contaminated["recovery_state"] = {"condition": "rested"}
	assert_false(_append(ledger, contaminated)["valid"])
	for field in ["stress", "satiety", "study", "grade", "diagnosis", "disease_risk", "healthy"]:
		var extra := _meal(1, "dinner", ["fixture_egg"])
		extra[field] = "injected"
		assert_false(_append(ledger, extra)["valid"], field + " cannot enter frozen health history")
	assert_false(ledger.append_snapshot(_meal(1, "dinner", ["fixture_egg"]), fixture.config, fixture.registry, "bad-date", fixture.copies)["valid"])
	assert_eq(ledger.get_entries(), before)


func test_preview_confirmation_freezes_ledger_once_and_navigation_is_read_only() -> void:
	fixture.toggle("fixture_mixed")
	assert_eq(fixture.ledger.get_entries(), [])
	assert_true(fixture.confirm())
	assert_false(fixture.confirm())
	assert_eq(fixture.ledger.get_entries().size(), 1)
	assert_eq(fixture.period_view()["composition"][0]["text"], "记到 3 种配料")
	var preview = Preview.instantiate()
	track(preview)
	(Engine.get_main_loop() as SceneTree).root.add_child(preview)
	var before: Array[Dictionary] = preview.model.ledger.get_entries()
	for day in range(1, 8):
		preview._select_day(day)
		assert_contains(preview.title_label.text, "第 %d 天" % day)
	preview._select_week()
	assert_true(preview.week_button.button_pressed)
	assert_eq(preview.model.ledger.get_entries(), before)
	preview._clear()
	assert_contains(preview.summary_label.text, "没有")
	preview._restore()
	assert_eq(preview.model.ledger.get_entries(), before)


func _append(ledger: Ledger, snapshot: Variant) -> Dictionary:
	return ledger.append_snapshot(snapshot, fixture.config, fixture.registry, DATE, fixture.copies)


func _meal(day: int, phase: String, ids: Array) -> Dictionary:
	return Snapshot.build(day, {"phase": phase, "source_id": "cafeteria", "food_ids": ids}, fixture.catalog)


func _assert_no_scores(value: Variant) -> void:
	if value is Dictionary:
		for key in value:
			assert_false(key in ["quality", "average_quality", "health_score", "nutrition_score", "grade", "stability", "recovery_state", "factor_score"])
			_assert_no_scores(value[key])
	elif value is Array:
		for item in value:
			_assert_no_scores(item)
