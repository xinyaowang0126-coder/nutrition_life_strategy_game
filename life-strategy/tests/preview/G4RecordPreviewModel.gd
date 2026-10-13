extends RefCounted

## Explicit synthetic seven-day record set, not live gameplay or approval.
const MealModel := preload("res://tests/preview/G4PreviewModel.gd")
const Ledger := preload("res://scripts/health/DietPatternLedger.gd")
const Presenter := preload("res://scripts/health/DietPatternPresenter.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const DATE := "2026-10-11"
var ledger := Ledger.new()
var selected_day := 1
var weekly := false


func _init() -> void:
	load_examples()


func load_examples() -> Dictionary:
	var meal := MealModel.new()
	var snapshots: Array = []
	for row in [
		[1, "breakfast", ["fixture_mixed", "fixture_egg"]], [1, "lunch", ["fixture_mixed"]], [1, "dinner", ["fixture_fruit"]],
		[2, "dinner", ["fixture_low"]], [3, "breakfast", ["fixture_rice", "fixture_egg"]], [3, "lunch", ["fixture_dairy", "fixture_fruit"]], [3, "dinner", ["fixture_mixed"]],
		[4, "breakfast", ["fixture_mixed", "fixture_vegetable"]],
	]:
		snapshots.append(Snapshot.build(row[0], {"phase": row[1], "source_id": "cafeteria", "food_ids": row[2]}, meal.catalog))
	snapshots.append(Snapshot.legacy(2, {"phase": "breakfast", "food_ids": ["fixture_rice"]}))
	for row in [[2, "lunch"], [7, "breakfast"], [7, "lunch"], [7, "dinner"]]:
		snapshots.append(Snapshot.build(row[0], {"phase": row[1], "skipped": true}, meal.catalog))
	var future := Snapshot.build(6, {"phase": "lunch", "source_id": "cafeteria", "food_ids": ["fixture_mixed"]}, meal.catalog)
	future["model_version"] = "diet-pattern-future-example"
	for profile in future["profile_snapshots"].values():
		profile["model_version"] = future["model_version"]
	snapshots.append(future)
	snapshots.append(Snapshot.legacy(0, {"food_ids": ["fixture_rice"]}))
	return ledger.replace_snapshots(snapshots, meal.config, meal.registry, DATE, meal.copies)


func select_day(day: int) -> bool:
	if day < 1 or day > 7:
		return false
	selected_day = day
	weekly = false
	return true


func view() -> Dictionary:
	return Presenter.week_view(ledger) if weekly else Presenter.day_view(ledger, selected_day)
