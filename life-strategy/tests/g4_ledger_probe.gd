extends SceneTree

## Same legal commands with/without explicit confirmation-time diagnostics.
## No production switches, persistent history or synthetic production reviews.
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Data := preload("res://scripts/GameData.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Ledger := preload("res://scripts/health/DietPatternLedger.gd")
const Store := preload("res://scripts/health/HealthDataStore.gd")
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const DATE := "2026-10-11"
const SEEDS := [0, 7, 42, 73]
const ORDERS := [["cafeteria", "dorm_storage", "convenience_store", "takeout"], ["takeout", "convenience_store", "dorm_storage", "cafeteria"]]
var errors: Array[String] = []
var catalog := Store.new().load_catalog()
var config := Config.defaults()
var copies := Composer.load_catalog()
var registry := Evidence.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	registry.load_registry()
	var rows: Array[Dictionary] = []
	for order in ORDERS:
		for seed_value in SEEDS:
			rows.append(_play(order, seed_value))
	print("G4_LEDGER_AUDIT=" + JSON.stringify({"date": DATE, "rows": rows, "errors": errors, "scope": "8 paired isolated V2 runs, production draft data, all health switches off. Capture only at confirmation; no save writes, player or balance study."}))
	quit(0 if errors.is_empty() else 1)


func _play(order: Array, seed_value: int) -> Dictionary:
	var game := _game(seed_value)
	var control := _game(seed_value)
	var ledger := Ledger.new()
	var source_counts := {}
	var steps := 0
	while game.phase != "ending" and steps < 160:
		steps += 1
		if game.phase.ends_with("_source"):
			var source := ""
			for id in order:
				if game._source_disabled_reason(id, game._current_meal_phase()).is_empty():
					source = id
					break
			if source.is_empty():
				game._skip_meal()
				control._skip_meal()
			else:
				game._choose_meal_source(source)
				control._choose_meal_source(source)
				var candidates := game.hand.duplicate()
				candidates.sort_custom(func(a: String, b: String) -> bool:
					var first: int = Data.get_food(a)["cost"]
					var second: int = Data.get_food(b)["cost"]
					return a < b if first == second else first < second
				)
				var plate: Array[String] = []
				for id in candidates:
					if game._can_add_food(id):
						plate.append(id)
						break
				if plate.is_empty():
					game._skip_meal()
					control._skip_meal()
				else:
					game._confirm_food(plate)
					control._confirm_food(plate)
					source_counts[source] = int(source_counts.get(source, 0)) + 1
			var frozen := Snapshot.build(game.day, game.today_meal_records.back(), catalog)
			_check(ledger.append_snapshot(frozen, config, registry, DATE, copies)["valid"], "ledger rejected confirmed record")
			var before := _state(game)
			var daily := ledger.day_view(game.day)
			var weekly := ledger.week_view(game.day)
			_check(daily["valid"] and weekly["valid"], "period invalid")
			_check(daily["diversity"]["unique_ingredient_count"] == null or daily["regularity"]["eaten"] == 0, "draft data exposed composition count")
			_check(_state(game) == before, "ledger read mutated game")
		elif game.phase.ends_with("_action"):
			var action_id: String = {"breakfast_action": "study", "lunch_action": "walk", "dinner_action": "nap"}[game.phase]
			if game._can_use_action(game._effective_action(action_id)):
				game._apply_action(action_id)
				control._apply_action(action_id)
			else:
				game._skip_action()
				control._skip_action()
		elif game.phase == "sleep":
			game._choose_sleep("sleep_early")
			control._choose_sleep("sleep_early")
		elif game.phase == "summary":
			game._on_summary_advanced()
			control._on_summary_advanced()
		else:
			_check(false, "unexpected phase")
			break
		_check(_state(game) == _state(control), "paired gameplay difference")
	_check(game.phase == "ending", "paired run did not finish")
	var row := {"seed": seed_value, "order": order, "day": game.day, "ending": game.ending_id, "captured_meals": ledger.get_entries().size(), "source_counts": source_counts, "gameplay_identical": _state(game) == _state(control), "health_catalog_loaded": game._health_catalog_loaded}
	game.free()
	control.free()
	return row


func _game(seed_value: int) -> GameRootV2:
	var game := Controller.new() as GameRootV2
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game._deck_service = Deck.new(seed_value)
	game.start_new_run()
	return game


func _state(game: GameRootV2) -> Dictionary:
	return {"day": game.day, "phase": game.phase, "state": game.state.duplicate(true), "inventory": game.dorm_inventory.duplicate(true), "hand": game.hand.duplicate(), "selected": game.selected_food_ids.duplicate(), "source_hands": game.source_hands.duplicate(true), "meals": game.today_meal_records.duplicate(true), "history": game.run_history.duplicate(true), "ending": game.ending_id, "rng": game._deck_service._rng.state}


func _check(condition: bool, reason: String) -> void:
	if not condition and not errors.has(reason):
		errors.append(reason)
