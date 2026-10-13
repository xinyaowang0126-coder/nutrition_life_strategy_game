extends SceneTree

## Test-only examples. Simulated review metadata never changes production.
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Store := preload("res://scripts/health/HealthDataStore.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const DATE := "2026-10-08"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var report := examples()
	print("G4_MEAL_PROBE=" + JSON.stringify(report))
	quit(0 if report["valid"] else 1)


static func examples() -> Dictionary:
	var registry := Evidence.new()
	registry.load_registry("res://tests/fixtures/g4_meal/evidence.xml")
	var catalog := Store.new().load_catalog("res://tests/fixtures/g4_meal/profiles.xml")
	var config := Config.defaults()
	config.merge({"review_status": "expert_reviewed", "reviewed_by": "fixture-only", "reviewed_at": "2026-10-01", "evidence_refs": ["FIXTURE-EDUCATION"]}, true)
	var copies := Composer.load_catalog()
	for id in Composer.NUTRITION_IDS:
		copies["copies"][id].merge({"review_status": "expert_reviewed", "reviewed_by": "fixture-only", "reviewed_at": "2026-10-01", "evidence_refs": "FIXTURE-EDUCATION"}, true)
	var cases := {
		"known_composition_unknown_portion": Snapshot.build(1, {"phase": "lunch", "food_ids": ["fixture_mixed"]}, catalog),
		"partial_composition": Snapshot.build(1, {"phase": "lunch", "food_ids": ["fixture_rice", "missing_food"]}, catalog),
		"fruit_and_dairy": Snapshot.build(1, {"phase": "lunch", "food_ids": ["fixture_fruit", "fixture_dairy"]}, catalog),
		"skipped": Snapshot.build(1, {"phase": "lunch", "skipped": true}),
		"legacy_unknown": Snapshot.legacy(1, {"phase": "lunch", "quality": 86}),
	}
	var rows := {}
	var valid := true
	for id in cases:
		var result := Composer.compose_meal(cases[id], config, registry, DATE, copies)
		valid = valid and bool(result["valid"])
		rows[id] = {"text": result["primary"]["text"], "structure": result["evaluation"]["dimensions"]["plate_structure"], "data_quality": result["evaluation"]["data_quality"], "suggestion": result["primary_suggestion"]}
	var production_registry := Evidence.new()
	production_registry.load_registry()
	var actual := Store.new().load_catalog()
	var snapshot := Snapshot.build(1, {"phase": "lunch", "food_ids": ["chicken_vegetable_rice"]}, actual)
	var guarded := Composer.compose_meal(snapshot, Config.defaults(), production_registry, DATE, Composer.load_catalog())
	valid = valid and guarded["primary"]["kind"] == "boundary" and guarded["evaluation"]["observations"].is_empty()
	return {"valid": valid, "scope": "Isolated fixtures with simulated review metadata; not a real review or production UI.", "cases": rows, "production_guard": {"text": guarded["primary"]["text"], "affirmative_observations": guarded["evaluation"]["observations"], "structure_status": guarded["evaluation"]["dimensions"]["plate_structure"]["status"]}}
