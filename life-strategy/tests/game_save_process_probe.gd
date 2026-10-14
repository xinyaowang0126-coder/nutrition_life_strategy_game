extends SceneTree

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Store := preload("res://scripts/stories/GameSaveStore.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var reading := OS.get_cmdline_user_args().has("--read")
	var store := Store.new("res://.godot/process-save-probe", "file")
	var game := Controller.new()
	var errors: Array = []
	if reading:
		var saved := store.read_save("choir_week")
		if not saved["ok"]:
			errors.append(saved)
		else:
			var restored := game.restore_game_save(saved["save"])
			if not restored["ok"]: errors.append(restored)
			if Codec.normalize(game.capture_game_save()["payload"]) != saved["save"]["payload"]: errors.append("Payload changed after process restart")
			if game.phase != "breakfast_action" or game.kitchen.ingredients["tofu"] != 3 or game.kitchen.batches[1]["recipe_facts"]["sodium_from_added_seasonings_mg"] != 1500: errors.append("Phase, pantry or recipe changed")
	else:
		game.story_id = "choir_week"
		game._deck_service = Deck.new(211)
		game.start_new_run()
		game._choose_meal_source("home_kitchen")
		if not game.confirm_household_food(["tofu", "millet_porridge"], "fridge", {"seasoning": "usual", "added_sugar_g": 8}): errors.append("Cooking failed")
		var saved := store.write_local(game.capture_game_save())
		if not saved["ok"]: errors.append(saved)
	print("SAVE_PROCESS_RESULT=" + JSON.stringify({"errors": errors, "mode": "read" if reading else "write", "scope": "Two separate native engine processes, real file backend. Not browser IndexedDB."}))
	game.free()
	quit(0 if errors.is_empty() else 1)
