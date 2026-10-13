class_name MealGuidanceShadow
extends RefCounted

## Explicit developer diagnostics. Never attached to the normal game loop or
## controlled by changing the four production flags. Reports are detached.
const Adapter := preload("res://scripts/health/MealGuidanceAdapter.gd")
const Presenter := preload("res://scripts/health/HealthGuidancePresenter.gd")
const Suggestions := preload("res://scripts/health/FeasibleSuggestionService.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")


static func inspect_selection(live: Variant, catalog: Dictionary, config: Dictionary, registry: Evidence, date: String, copies: Dictionary) -> Dictionary:
	var context := Adapter.build_context(live, catalog)
	if not context["valid"]:
		return {"valid": false, "reason": context["reason"], "view": {}, "suggestion": {"verified": false, "action": null}}
	if context["selected_ids"].is_empty():
		return {"valid": true, "reason": "nothing_selected", "view": {}, "suggestion": {"verified": false, "action": null}}
	var view := Presenter.meal_view(context["current_snapshot"], config, registry, date, copies)
	return {
		"valid": view["valid"], "reason": "selection_inspected",
		"day": context["day"], "phase": context["phase"], "source_id": context["source_id"],
		"payment_mode": context["payment_mode"], "fee": context["fee"], "total_cost": context["total_cost"],
		"context_token": context["context_token"], "snapshot": context["current_snapshot"].duplicate(true),
		"view": view.duplicate(true),
		"suggestion": Suggestions.find_option(context, config, registry, date, copies).duplicate(true),
	}


static func freeze_record(day: int, game_record: Dictionary, catalog: Dictionary, config: Dictionary, registry: Evidence, date: String, copies: Dictionary) -> Dictionary:
	# Called at confirmation by a diagnostic harness, never retrospectively
	# against current profiles. Existing data-on snapshots remain authoritative.
	var snapshot: Variant = game_record["health_snapshot"] if game_record.has("health_snapshot") else Snapshot.build(day, game_record, catalog)
	if not snapshot is Dictionary:
		return {}
	var record := {
		"day": day, "phase": game_record.get("phase", ""), "skipped": game_record.get("skipped", false),
		"food_names": game_record.get("food_names", []).duplicate(), "food_ids": game_record.get("food_ids", []).duplicate(),
		"source_name": game_record.get("source_name", ""), "spent": game_record.get("total_cost", 0),
		"health_snapshot": snapshot.duplicate(true), "meal_view": Presenter.meal_view(snapshot, config, registry, date, copies),
	}
	return record.duplicate(true)


static func inspect_day(day: int, frozen_records: Array) -> Dictionary:
	if day < 1 or day > 7:
		return {"valid": false, "reason": "day_invalid", "diary": {}}
	var seen := {}
	for record in frozen_records:
		if not record is Dictionary or record.get("day") != day or not record.get("health_snapshot") is Dictionary:
			return {"valid": false, "reason": "record_invalid", "diary": {}}
		var snapshot: Dictionary = record["health_snapshot"]
		var checked := Snapshot.validate(snapshot)
		if not checked["valid"] or snapshot.get("day") != day or seen.has(record.get("phase")):
			return {"valid": false, "reason": "record_invalid", "diary": {}}
		if record.get("phase") != snapshot.get("phase") or record.get("food_ids") != snapshot.get("food_ids") or record.get("skipped") != (snapshot.get("status") == "skipped") or not record.get("meal_view") is Dictionary:
			return {"valid": false, "reason": "record_invalid", "diary": {}}
		seen[record["phase"]] = true
	return {"valid": true, "reason": "frozen_day", "diary": Presenter.diary_view(frozen_records).duplicate(true)}
