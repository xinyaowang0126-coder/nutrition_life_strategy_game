extends SceneTree

## Diagnostic policy sample, not a balance acceptance test or player study.
## Runs real V2 commands without entering the scene tree or writing user history.
## godot --headless --path life-strategy --script res://tests/gameplay_strategy_probe.gd

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Data := preload("res://scripts/GameData.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const SEEDS := [0, 1, 2, 3, 7, 13, 42, 73, 101, 211, 997, 20260905]
const POLICIES := [
	"cafeteria_study_early", "cafeteria_paced_early", "cafeteria_adaptive_early",
	"pantry_adaptive_early", "takeout_adaptive_early", "skip_night_study",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows: Array[Dictionary] = []
	var errors: Array[String] = []
	for policy in POLICIES:
		for seed_value in SEEDS:
			var row := _play(policy, seed_value)
			rows.append(row)
			if not bool(row["valid"]):
				errors.append("%s seed %d: %s" % [policy, seed_value, row["error"]])
	var report := {
		"schema_version": 1, "seeds": SEEDS, "policies": POLICIES,
		"isolation": {"controller_in_tree": false, "health_flags": "all_off", "history_path": ""},
		"scope": "Scripted legal choices with C2 frozen recovery effects, R2 stability and endings. Not human success rates, C3/D acceptance or a balance proof.",
		"source_sha256": FileAccess.get_sha256("res://scripts/ui_v2/GameRootV2.gd"),
		"rows": rows, "errors": errors,
	}
	print("GAMEPLAY_STRATEGY_AUDIT=" + JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)


func _play(policy: String, seed_value: int) -> Dictionary:
	var game := Controller.new()
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game._deck_service = Deck.new(seed_value)
	game.start_new_run()
	var error := ""
	var steps := 0
	while game.phase != "ending" and steps < 160:
		steps += 1
		var before := "%d:%s" % [game.day, game.phase]
		if game.phase.ends_with("_source"):
			_choose_meal(game, policy)
		elif game.phase.ends_with("_action"):
			_choose_action(game, policy)
		elif game.phase == "sleep":
			game._choose_sleep("night_study" if policy == "skip_night_study" else "sleep_early")
		elif game.phase == "summary":
			game._on_summary_advanced()
		else:
			error = "Unexpected phase: %s" % game.phase
			break
		if before == "%d:%s" % [game.day, game.phase]:
			error = "No progress at %s" % before
			break
		if int(game.state["balance"]) < 0:
			error = "Negative balance"
			break
		for amount in game.dorm_inventory.values():
			if int(amount) < 0:
				error = "Negative pantry stock"
	if game.phase != "ending" and error.is_empty():
		error = "Step limit exceeded"
	var sources := {}
	var skipped := 0
	var meals := 0
	var recovery_rows: Array[Dictionary] = []
	for day_record in game.run_history:
		var recovery: Dictionary = day_record.get("recovery_state", {})
		var validation := Recovery.validate(recovery)
		if not validation["valid"] or recovery.get("origin") != "day_settlement":
			error = "Invalid or missing recovery day %s: %s" % [day_record.get("day"), validation["errors"]]
		else:
			recovery_rows.append({
				"day": day_record["day"], "condition": recovery["condition"],
				"inputs": recovery["inputs"], "sleep_snapshot": recovery["sleep_snapshot"],
				"presented_next_day": day_record["next_learning_state"],
				"recovery_next_day": recovery["next_day_effect"],
			})
		var seen := {}
		for meal in day_record.get("meals", []):
			meals += 1
			var phase_name := String(meal.get("phase", ""))
			if seen.has(phase_name):
				error = "Duplicate meal in day record"
			seen[phase_name] = true
			if bool(meal.get("skipped", false)):
				skipped += 1
			else:
				var source := String(meal.get("source_id", ""))
				sources[source] = int(sources.get(source, 0)) + 1
	var row := {
		"policy": policy, "seed": seed_value, "valid": error.is_empty(), "error": error,
		"ending": game.ending_id, "day": game.day, "state": game.state.duplicate(true),
		"meal_count": meals, "skipped_meals": skipped, "source_counts": sources,
		"dorm_inventory": game.dorm_inventory.duplicate(true), "recovery_rows": recovery_rows,
	}
	game.free()
	return row


func _choose_meal(game: GameRootV2, policy: String) -> void:
	if policy == "skip_night_study":
		game._skip_meal()
		return
	var sources := ["cafeteria", "dorm_storage", "convenience_store", "takeout"]
	if policy.begins_with("pantry"):
		sources = ["dorm_storage", "cafeteria", "convenience_store", "takeout"]
	elif policy.begins_with("takeout"):
		sources = ["takeout", "cafeteria", "dorm_storage", "convenience_store"]
	var meal := game.phase.trim_suffix("_source")
	for source_id in sources:
		if not game._source_disabled_reason(source_id, meal).is_empty():
			continue
		game._choose_meal_source(source_id)
		var plate := _affordable_plate(game)
		if not plate.is_empty():
			game._confirm_food(plate)
			return
		game._change_meal_source()
	game._skip_meal()


func _affordable_plate(game: GameRootV2) -> Array[String]:
	var candidates := game.hand.duplicate()
	var preferred := ["rice_plain", "egg", "tomato", "mixed_grain_rice"] if game.phase == "breakfast" else ["rice_plain", "tofu", "greens", "tomato", "mixed_grain_rice"]
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var ai := preferred.find(a)
		var bi := preferred.find(b)
		if ai >= 0 or bi >= 0:
			return (ai if ai >= 0 else 100) < (bi if bi >= 0 else 100)
		var ac := int(Data.get_food(a).get("cost", 0))
		var bc := int(Data.get_food(b).get("cost", 0))
		return a < b if ac == bc else ac < bc
	)
	var source := game._effective_meal_source(game.current_source_id)
	var stock := String(source.get("payment_mode", "cash")) == "stock"
	var spent := int(source.get("fee", 0))
	var plate: Array[String] = []
	for food_id in candidates:
		var cost := 0 if stock else int(Data.get_food(food_id).get("cost", 0))
		if spent + cost > int(game.state["balance"]):
			continue
		plate.append(food_id)
		spent += cost
		if plate.size() >= mini(2, game._source_selection_limit(game.current_source_id)):
			break
	return plate


func _choose_action(game: GameRootV2, policy: String) -> void:
	if policy == "skip_night_study":
		game._skip_action()
		return
	var action_id := "study"
	if policy == "cafeteria_paced_early":
		action_id = {"breakfast_action": "study", "lunch_action": "walk", "dinner_action": "nap"}[game.phase]
	elif policy.contains("adaptive"):
		if int(game.state["energy"]) < 35:
			action_id = "nap"
		elif int(game.state["stress"]) >= 65:
			action_id = "walk"
	if game._can_use_action(game._effective_action(action_id)):
		game._apply_action(action_id)
	else:
		game._skip_action()
