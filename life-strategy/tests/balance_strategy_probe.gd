extends SceneTree

## Real legal V2 commands; scripted diagnostics, not human success rates.
## --output=<absolute JSON path> --budget=150 --seed-count=30
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Data := preload("res://scripts/GameData.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Balance := preload("res://scripts/systems/GameplayBalanceRules.gd")
const SEEDS := [0, 1, 2, 3, 7, 13, 42, 73, 101, 211, 997, 20260905,
	4, 5, 6, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
const POLICIES := [
	"cafeteria_study_early", "cafeteria_paced_early", "cafeteria_adaptive_early",
	"pantry_adaptive_early", "takeout_adaptive_early", "convenience_adaptive_early",
	"mixed_adaptive_early", "restock_adaptive_early", "restock_planned_early", "mixed_paced_early",
	"mixed_adaptive_phone",
	"mixed_paced_phone", "mixed_paced_late", "mixed_no_study",
	"mixed_no_recovery", "mixed_water_early", "skip_night_study",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := ""
	var budget := int(Data.STARTING_STATS["balance"])
	var seed_count := SEEDS.size()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--budget="):
			budget = int(argument.trim_prefix("--budget="))
		elif argument.begins_with("--seed-count="):
			seed_count = clampi(int(argument.trim_prefix("--seed-count=")), 1, SEEDS.size())
	var rows: Array[Dictionary] = []
	var errors: Array[String] = []
	for policy in POLICIES:
		for seed_value in SEEDS.slice(0, seed_count):
			var row := _play(policy, seed_value, budget)
			rows.append(row)
			if not row["valid"]:
				errors.append("%s seed %d: %s" % [policy, seed_value, row["error"]])
	var report := {
		"schema_version": 1, "balance_version": Balance.VERSION, "budget": budget,
		"scope": "17 scripted policies across real hands, inventory, events and frozen recovery. Not a player study or proof of an optimal strategy.",
		"seeds": SEEDS.slice(0, seed_count), "policies": POLICIES, "rows": rows, "errors": errors,
	}
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write balance diagnostic: %s" % output_path)
			quit(1)
			return
		file.store_string(JSON.stringify(report, "\t"))
	else:
		print("BALANCE_STRATEGY_REPORT=" + JSON.stringify(report))
	print("BALANCE_STRATEGY_RESULT=" + JSON.stringify({"runs": rows.size(), "budget": budget, "errors": errors}))
	quit(0 if errors.is_empty() else 1)


func _play(policy: String, seed_value: int, budget: int) -> Dictionary:
	var game := Controller.new()
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game._deck_service = Deck.new(seed_value)
	game.start_new_run()
	game.state["balance"] = budget
	game._day_start_state["balance"] = budget
	var error := ""
	var steps := 0
	var target_day := 0
	var saturated_energy_steps := 0
	while game.phase != "ending" and steps < 160:
		steps += 1
		var before := "%d:%s" % [game.day, game.phase]
		if game.phase.ends_with("_source"):
			_choose_meal(game, policy)
		elif game.phase.ends_with("_action"):
			_choose_action(game, policy)
		elif game.phase == "sleep":
			var sleep_id := "sleep_early"
			if policy.ends_with("phone"):
				sleep_id = "scroll_phone"
			elif policy.ends_with("late") or policy == "skip_night_study":
				sleep_id = "night_study"
			game._choose_sleep(sleep_id)
		elif game.phase == "summary":
			game._on_summary_advanced()
		else:
			error = "Unexpected phase: %s" % game.phase
			break
		if target_day == 0 and int(game.state["study_progress"]) >= Data.STUDY_TARGET:
			target_day = game.day
		if int(game.state["energy"]) == 100:
			saturated_energy_steps += 1
		if before == "%d:%s" % [game.day, game.phase]:
			error = "No progress at %s" % before
			break
		if int(game.state["balance"]) < 0:
			error = "Negative balance"
			break
		for amount in game.dorm_inventory.values():
			if int(amount) < 0:
				error = "Negative pantry stock"
		for key in ["energy", "mood", "satiety", "stress", "study_progress", "stability"]:
			if int(game.state[key]) < 0 or int(game.state[key]) > 100:
				error = "Stat out of range: %s" % key
	if game.phase != "ending" and error.is_empty():
		error = "Step limit exceeded"
	var sources := {}
	var skipped := 0
	var days: Array[Dictionary] = []
	for record in game.run_history:
		var validation := Recovery.validate(record["recovery_state"])
		if not validation["valid"]:
			error = "Invalid recovery: %s" % validation["errors"]
		var periods: Array = record.get("periods", [])
		if periods.size() != 3:
			error = "A completed day must have exactly three elapsed periods"
		var meals: Array = record["meals"]
		if meals.size() != 3:
			error = "A completed day must record all three meals"
		for meal in meals:
			if meal["skipped"]:
				skipped += 1
			else:
				var source_id: String = meal["source_id"]
				sources[source_id] = int(sources.get(source_id, 0)) + 1
		days.append({
			"day": record["day"], "start": record["start_state"], "end": record["end_state"],
			"condition": record["recovery_state"]["condition"], "spend": record["spend"],
			"meals": meals, "actions": record["actions"], "periods": periods, "sleep": record["sleep"],
		})
	var row := {
		"policy": policy, "seed": seed_value, "valid": error.is_empty(), "error": error,
		"ending": game.ending_id, "day": game.day, "state": game.state.duplicate(true),
		"target_day": target_day, "saturated_energy_steps": saturated_energy_steps,
		"skipped_meals": skipped, "source_counts": sources, "days": days,
	}
	game.free()
	return row


func _choose_meal(game: GameRootV2, policy: String) -> void:
	if policy == "skip_night_study":
		game._skip_meal()
		return
	var sources := ["cafeteria", "dorm_storage", "convenience_store", "takeout"]
	if policy.begins_with("pantry") or policy.begins_with("restock"):
		sources = ["dorm_storage", "cafeteria", "convenience_store", "takeout"]
	elif policy.begins_with("takeout"):
		sources = ["takeout", "cafeteria", "dorm_storage", "convenience_store"]
	elif policy.begins_with("convenience"):
		sources = ["convenience_store", "cafeteria", "dorm_storage", "takeout"]
	elif policy.begins_with("mixed"):
		if game.phase == "breakfast_source":
			sources = ["dorm_storage", "convenience_store", "cafeteria", "takeout"]
		elif (game.day == 4 or int(game.state["energy"]) < 35) and int(game.state["balance"]) > (7 - game.day) * 18 + 20:
			sources = ["takeout", "cafeteria", "convenience_store", "dorm_storage"]
		elif game.day % 2 == 0:
			sources = ["convenience_store", "cafeteria", "dorm_storage", "takeout"]
	var meal_phase := game.phase.trim_suffix("_source")
	for source_id in sources:
		if not game._source_disabled_reason(source_id, meal_phase).is_empty():
			continue
		game._choose_meal_source(source_id)
		var plate := _affordable_plate(game)
		if not plate.is_empty():
			game._confirm_food(plate)
			return
		game._change_meal_source()
	game._skip_meal()


func _affordable_plate(game: GameRootV2) -> Array[String]:
	var source := game._effective_meal_source(game.current_source_id)
	var stock := String(source.get("payment_mode", "cash")) == "stock"
	var foods: Array[Dictionary] = []
	for id in game.hand:
		foods.append(Data.get_food(id))
	var best: Array[String] = []
	var best_score := -INF
	for mask in range(1, 1 << foods.size()):
		var plate: Array[String] = []
		var cost := int(source.get("fee", 0))
		var satiety := 0
		var energy := 0
		for index in range(foods.size()):
			if mask & (1 << index):
				plate.append(String(foods[index]["id"]))
				cost += 0 if stock else int(foods[index]["cost"])
				satiety += int(foods[index]["satiety"])
				energy += int(foods[index]["energy"])
		if plate.size() > game._source_selection_limit(game.current_source_id) or cost > int(game.state["balance"]):
			continue
		# Transparent resource policy: seek 26 fullness, then prefer lower cost.
		# No nutrition metadata or hidden knowledge influences these choices.
		var score := (100.0 if satiety >= 26 else 0.0) + mini(satiety, 32) + mini(energy, 4) - cost * 4.0
		if score > best_score:
			best_score = score
			best = plate
	return best


func _choose_action(game: GameRootV2, policy: String) -> void:
	if policy == "skip_night_study":
		game._skip_action()
		return
	if policy == "mixed_water_early" and game.drink_water_used < 2:
		game._apply_action("drink_water")
	var action_id := "study"
	if policy == "restock_planned_early":
		action_id = {"breakfast_action": "study", "lunch_action": "restock_pantry" if game.day in [2, 4] else "walk", "dinner_action": "nap"}[game.phase]
	elif policy.contains("paced"):
		action_id = {"breakfast_action": "study", "lunch_action": "walk", "dinner_action": "nap"}[game.phase]
	elif policy == "mixed_no_study":
		action_id = {"breakfast_action": "nap", "lunch_action": "walk", "dinner_action": "allow_imperfection"}[game.phase]
	elif policy.contains("adaptive") or policy == "mixed_water_early":
		if int(game.state["energy"]) < 42:
			action_id = "nap"
		elif int(game.state["stress"]) >= 58:
			action_id = "walk"
		elif int(game.state["study_progress"]) >= mini(Data.STUDY_TARGET, game.day * Data.DAILY_STUDY_PACE + 4):
			action_id = "walk" if int(game.state["stress"]) >= 40 else "nap"
		if policy.begins_with("restock") and game.dorm_inventory.get("oatmeal", 0) == 0 and game.day <= 5 and int(game.state["energy"]) >= 32 and int(game.state["balance"]) >= (7 - game.day) * 14:
			action_id = "restock_pantry" if not game.used_action_ids.has("restock_pantry") else action_id
	if game._can_use_action(game._effective_action(action_id)):
		game._apply_action(action_id)
	else:
		game._skip_action()
