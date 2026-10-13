extends SceneTree

## Production combination audit + simulated-review execution matrix. No
## production flag changes, persistent history or player-facing output.
const Adapter := preload("res://scripts/health/MealGuidanceAdapter.gd")
const Shadow := preload("res://scripts/health/MealGuidanceShadow.gd")
const Suggestions := preload("res://scripts/health/FeasibleSuggestionService.gd")
const Store := preload("res://scripts/health/HealthDataStore.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Data := preload("res://scripts/GameData.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Fixture := preload("res://tests/fixtures/g4_sources/SourceFixture.gd")
const SEEDS := [0, 7, 42, 73]
const DAYS := [1, 3, 4, 6, 7]
var errors: Array[String] = []
var production_counts := {}
var matrix_counts := {}
var verified_counts := {}
var alternative_counts := {}
var limit_cases := 0
var fixture := Fixture.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_msec()
	var catalog := Store.new().load_catalog()
	var registry := Evidence.new()
	registry.load_registry()
	var config := Config.defaults()
	var copies := Composer.load_catalog()
	for phase in ["breakfast", "lunch", "dinner"]:
		for source in Data.get_meal_source_ids_for_scene(phase):
			var pool := Data.get_food_ids_for_context(source, phase)
			var source_data := Data.get_meal_source(source)
			for selection in _combinations(pool, int(source_data["selection_limit"])):
				var live := {"day": 1, "phase": phase, "source_id": source, "balance": 120, "hand_ids": pool.duplicate(), "selected_ids": selection.duplicate(), "inventory": Data.get_initial_dorm_inventory()}
				var before := live.duplicate(true)
				var result := Shadow.inspect_selection(live, catalog, config, registry, Fixture.DATE, copies)
				_check(result["valid"], "production invalid %s %s %s" % [source, phase, selection])
				_check(not result.get("view", {}).get("nutrition_allowed", false), "production draft guidance")
				_check(not result["suggestion"]["verified"], "production draft suggestion")
				_check(live == before, "production input mutation")
				production_counts[source] = int(production_counts.get(source, 0)) + 1
		print("G4_SOURCE_PROGRESS=" + JSON.stringify({"production_phase": phase, "counts": production_counts}))
	for seed_value in SEEDS:
		for day in DAYS:
			for phase in ["breakfast", "lunch", "dinner"]:
				for source in Data.get_meal_source_ids_for_scene(phase):
					var game := _game(seed_value, day, phase, source)
					var hand := game.hand.duplicate()
					for selection in _combinations(hand, game._source_selection_limit(source)):
						game.selected_food_ids.assign(selection)
						var live := game.get_meal_guidance_input()
						var before := live.duplicate(true)
						var context := Adapter.build_context(live, fixture.catalog)
						_check(context["valid"], "dealt context invalid")
						var offer := Suggestions.find_option(context, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)
						_check(game.get_meal_guidance_input() == before, "dealt input mutation")
						matrix_counts[source] = int(matrix_counts.get(source, 0)) + 1
						if offer["verified"]:
							_execute(offer, live, seed_value)
							verified_counts[source] = int(verified_counts.get(source, 0)) + 1
							if offer["alternative"] is Dictionary:
								_execute({"verified": true, "action": offer["alternative"]}, live, seed_value)
								alternative_counts[source] = int(alternative_counts.get(source, 0)) + 1
							# A quote can only be executable within the current budget.
							var bounded := live.duplicate(true)
							bounded["balance"] = offer["action"]["total_cost"] - 1
							var bounded_context := Adapter.build_context(bounded, fixture.catalog)
							var cheaper := Suggestions.find_option(bounded_context, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)
							if cheaper["verified"]:
								_check(cheaper["action"]["total_cost"] <= bounded["balance"], "unaffordable verified action")
								_execute(cheaper, bounded, seed_value)
							limit_cases += 1
					game.free()
		print("G4_SOURCE_PROGRESS=" + JSON.stringify({"seed": seed_value, "contexts": matrix_counts, "verified": verified_counts}))
	var report := {
		"schema_version": 1, "date": Fixture.DATE, "duration_ms": Time.get_ticks_msec() - started,
		"isolation": {"health_flags": "all_off", "history_path": "", "controllers_in_tree": false, "approval_metadata": "test-only simulation"},
		"production_scope": "All allowed source/phase selections from the real pools at day 1; full pools cover possible selections, not a claim that all cards are dealt together.",
		"production_combinations": production_counts,
		"matrix_scope": "Actual V2 dealt hands, every nonempty selection within each source limit. Suggestions use isolated synthetic composition and reviews, real price/fees/stock, and execute through normal confirmation.",
		"seeds": SEEDS, "days": DAYS, "dealt_contexts": matrix_counts,
		"verified_actions": verified_counts, "verified_alternatives": alternative_counts, "suggestion_rules_version": Suggestions.RULES_VERSION, "budget_boundary_cases": limit_cases,
		"errors": errors,
	}
	print("G4_SOURCES_AUDIT=" + JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)


func _execute(offer: Dictionary, live: Dictionary, seed_value: int) -> void:
	var resolved := Adapter.resolve_proposal(offer, live, fixture.catalog, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)
	_check(resolved["valid"], "fresh quote rejected")
	if not resolved["valid"]:
		return
	var trial := _game(seed_value, live["day"], live["phase"], live["source_id"])
	trial.hand.assign(live["hand_ids"])
	trial.selected_food_ids.assign(live["selected_ids"])
	trial.dorm_inventory = live["inventory"].duplicate(true)
	trial.state["balance"] = live["balance"]
	var stock := trial.dorm_inventory.duplicate(true)
	trial._confirm_food(resolved["selected_ids"])
	_check(trial.today_meal_records.size() == 1, "verified action did not confirm exactly once")
	_check(trial.phase == live["phase"] + "_action", "verified action did not advance")
	if trial.today_meal_records.size() == 1:
		var record: Dictionary = trial.today_meal_records[0]
		_check(record["food_ids"] == offer["action"]["selection"], "confirmed different selection")
		_check(record["total_cost"] == offer["action"]["total_cost"], "confirmed different cost")
		_check(trial.state["balance"] == live["balance"] - offer["action"]["total_cost"], "charged different cost")
		for id in stock:
			var used := 1 if record["uses_stock"] and record["food_ids"].has(id) else 0
			_check(trial.dorm_inventory[id] == stock[id] - used, "incorrect stock consumption")
		var frozen := Shadow.freeze_record(live["day"], record, fixture.catalog, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)
		_check(Shadow.inspect_day(live["day"], [frozen])["valid"], "invalid confirmed day view")
	trial._confirm_food(resolved["selected_ids"])
	_check(trial.today_meal_records.size() == 1, "duplicate confirmation")
	_check(not Adapter.resolve_proposal(offer, trial.get_meal_guidance_input(), fixture.catalog, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)["valid"], "settled proposal accepted")
	trial.free()


func _game(seed_value: int, day: int, phase: String, source: String) -> GameRootV2:
	var game := Controller.new() as GameRootV2
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game._deck_service = Deck.new(seed_value)
	game.start_new_run()
	game.day = day
	game.phase = phase + "_source"
	game._choose_meal_source(source)
	return game


func _combinations(pool: Array, limit: int) -> Array:
	var rows: Array = []
	for a in range(pool.size()):
		rows.append([pool[a]])
		if limit < 2:
			continue
		for b in range(a + 1, pool.size()):
			rows.append([pool[a], pool[b]])
			if limit < 3:
				continue
			for c in range(b + 1, pool.size()):
				rows.append([pool[a], pool[b], pool[c]])
	return rows


func _check(condition: bool, reason: String) -> void:
	if not condition and not errors.has(reason):
		errors.append(reason)
