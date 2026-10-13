extends RefCounted

## Test-only three-meal session. Prices and simulated reviews are fixtures;
## this never calls GameRoot or writes user:// health/game history.
const Store := preload("res://scripts/health/HealthDataStore.gd")
const Registry := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Presenter := preload("res://scripts/health/HealthGuidancePresenter.gd")
const Suggestions := preload("res://scripts/health/FeasibleSuggestionService.gd")
const Memory := preload("res://scripts/health/SuggestionMemory.gd")
const Ledger := preload("res://scripts/health/DietPatternLedger.gd")
const PeriodPresenter := preload("res://scripts/health/DietPatternPresenter.gd")
const DATE := "2026-10-08"
const PHASES := ["breakfast", "lunch", "dinner"]
const MENU := [
	{"id": "fixture_rice", "name": "白米饭", "cost": 2, "image": "rice_plain"},
	{"id": "fixture_egg", "name": "鸡蛋", "cost": 2, "image": "egg"},
	{"id": "fixture_vegetable", "name": "番茄", "cost": 3, "image": "tomato"},
	{"id": "fixture_mixed", "name": "番茄鸡蛋饭", "cost": 7, "image": "tomato_egg_stir_fry"},
	{"id": "fixture_fruit", "name": "苹果", "cost": 3, "image": "apple"},
	{"id": "fixture_dairy", "name": "牛奶", "cost": 4, "image": "milk"},
	{"id": "fixture_low", "name": "今日特餐", "cost": 5, "image": ""},
]
var balance := 20
var meal_index := 0
var selected: Array[String] = []
var records: Array[Dictionary] = []
var revision := 0
var catalog: Dictionary
var registry: Registry
var config: Dictionary
var copies: Dictionary
var suggestion_history: Array = []
var ledger := Ledger.new()


func _init() -> void:
	catalog = Store.new().load_catalog("res://tests/fixtures/g4_meal/profiles.xml")
	registry = Registry.new()
	registry.load_registry("res://tests/fixtures/g4_meal/evidence.xml")
	config = Config.defaults()
	config.merge({"review_status": "expert_reviewed", "reviewed_by": "fixture-only", "reviewed_at": "2026-10-01", "evidence_refs": ["FIXTURE-EDUCATION"]}, true)
	copies = Composer.load_catalog()
	for id in Composer.NUTRITION_IDS:
		copies["copies"][id].merge({"review_status": "expert_reviewed", "reviewed_by": "fixture-only", "reviewed_at": "2026-10-01", "evidence_refs": "FIXTURE-EDUCATION"}, true)


func phase() -> String:
	return PHASES[meal_index] if meal_index < PHASES.size() else "done"


func item(id: String) -> Dictionary:
	for entry in MENU:
		if entry["id"] == id:
			return entry.duplicate(true)
	return {}


func total(ids: Array = []) -> int:
	var amount := 0
	for id in (selected if ids.is_empty() else ids):
		amount += int(item(id).get("cost", 0))
	return amount


func can_toggle(id: String) -> bool:
	if phase() == "done" or item(id).is_empty():
		return false
	if selected.has(id):
		return true
	return selected.size() < 3 and total() + item(id)["cost"] <= balance


func toggle(id: String) -> bool:
	if not can_toggle(id):
		return false
	if selected.has(id):
		selected.erase(id)
	else:
		selected.append(id)
	revision += 1
	return true


func snapshot(ids: Array) -> Dictionary:
	return Snapshot.build(1, {"phase": phase(), "food_ids": ids, "source_id": "cafeteria"}, catalog)


func meal_view() -> Dictionary:
	if selected.is_empty():
		return {}
	return Presenter.meal_view(snapshot(selected), config, registry, DATE, copies)


func suggestion_context() -> Dictionary:
	var options: Array[Dictionary] = []
	for entry in MENU:
		var row: Dictionary = entry.duplicate(true)
		row["stock"] = 99
		row["available"] = true
		row["candidate_snapshots"] = {}
		if not selected.has(entry["id"]):
			var removals: Array = [""] if selected.size() < 3 else []
			removals.append_array(selected)
			for remove_id in removals:
				var ids := selected.duplicate()
				if remove_id != "":
					ids.erase(remove_id)
				ids.append(entry["id"])
				row["candidate_snapshots"][String(remove_id)] = snapshot(ids)
		options.append(row)
	return {"stage": "selecting" if phase() != "done" else "done", "phase": phase(), "source_id": "cafeteria", "payment_mode": "cash", "balance": balance, "fee": 0, "selection_limit": 3, "revision": revision, "selected_ids": selected.duplicate(), "options": options, "current_snapshot": snapshot(selected)}


func suggestion() -> Dictionary:
	var meals: Array = []
	for record in records:
		meals.append(record["health_snapshot"].duplicate(true))
	return Suggestions.find_option(suggestion_context(), config, registry, DATE, copies, {"history": suggestion_history, "meal_history": meals})


func dismiss_suggestion(proposal: Dictionary) -> bool:
	var fresh := suggestion()
	if not fresh["verified"] or proposal.get("action") != fresh["action"]:
		return false
	var remembered := Memory.record(suggestion_history, fresh["action"], "dismissed")
	if not remembered["valid"]:
		return false
	suggestion_history = remembered["history"]
	return true


func apply_suggestion(proposal: Dictionary) -> bool:
	if not proposal.get("verified", false) or not proposal.get("action") is Dictionary:
		return false
	if proposal["action"].get("revision") != revision:
		return false
	var fresh := suggestion()
	if not fresh["verified"] or (fresh["action"] != proposal["action"] and fresh["alternative"] != proposal["action"]):
		return false
	var remembered := Memory.record(suggestion_history, proposal["action"])
	if not remembered["valid"]:
		return false
	suggestion_history = remembered["history"]
	selected.assign(proposal["action"]["selection"])
	revision += 1
	return true


func confirm() -> bool:
	if phase() == "done" or selected.is_empty() or total() > balance:
		return false
	var names: Array[String] = []
	for id in selected:
		names.append(item(id)["name"])
	var amount := total()
	var record := Presenter.capture_record(1, {"phase": phase(), "food_ids": selected.duplicate(), "food_names": names, "source_id": "cafeteria", "source_name": "食堂", "total_cost": amount}, catalog, config, registry, DATE, copies)
	if not ledger.append_snapshot(record["health_snapshot"], config, registry, DATE, copies)["valid"]:
		return false
	records.append(record.duplicate(true))
	balance -= amount
	_advance()
	return true


func skip() -> bool:
	if phase() == "done":
		return false
	var record := Presenter.capture_record(1, {"phase": phase(), "skipped": true, "food_ids": [], "food_names": [], "total_cost": 0}, catalog, config, registry, DATE, copies)
	if not ledger.append_snapshot(record["health_snapshot"], config, registry, DATE, copies)["valid"]:
		return false
	records.append(record)
	_advance()
	return true


func _advance() -> void:
	meal_index += 1
	selected.clear()
	revision += 1


func diary() -> Dictionary:
	return Presenter.diary_view(records.duplicate(true))


func period_view() -> Dictionary:
	return PeriodPresenter.day_view(ledger, 1)
