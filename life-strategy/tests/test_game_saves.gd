@tool
extends McpTestSuite

const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Store := preload("res://scripts/stories/GameSaveStore.gd")
const Session := preload("res://scripts/stories/StorySession.gd")


func suite_name() -> String:
	return "game_saves"


func _game(id: String = "choir_week", seed_value: int = 42) -> GameRootV2:
	var game := Controller.new()
	track(game)
	game.story_id = id
	game._deck_service = Deck.new(seed_value)
	game.start_new_run()
	return game


func _roundtrip(game: GameRootV2) -> void:
	var encoded := Codec.encode(game.capture_game_save())
	assert_true(encoded["ok"], str(encoded))
	if not encoded["ok"]: return
	var parsed := Codec.decode(encoded["text"])
	assert_true(parsed["ok"], str(parsed))
	if not parsed["ok"]: return
	assert_true(game.restore_game_save(parsed["save"])["ok"])
	assert_eq(Codec.normalize(game.capture_game_save()["payload"]), parsed["save"]["payload"])


func test_start_and_selected_menu_roundtrip_both_stories() -> void:
	for id in ["campus_exam", "choir_week"]:
		var game := _game(id)
		_roundtrip(game)
		game._choose_meal_source("home_kitchen" if id == "choir_week" else "cafeteria")
		game._on_food_toggled("rice_plain")
		_roundtrip(game)
		assert_eq(game.selected_food_ids, ["rice_plain"])


func test_full_random_state_is_exact_and_future_menus_do_not_reroll() -> void:
	var game := _game("campus_exam", 211)
	game._choose_meal_source("cafeteria")
	var saved := game.capture_game_save()
	var clone := _game("campus_exam", 1)
	var decoded := Codec.decode(Codec.encode(saved)["text"])
	assert_true(clone.restore_game_save(decoded["save"])["ok"])
	assert_eq(game._deck_service.capture_state(), clone._deck_service.capture_state())
	var ids: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h"]
	for i in range(20):
		assert_eq(game._deck_service.build_hand(ids, 4), clone._deck_service.build_hand(ids, 4))


func test_unsafe_unknown_and_frozen_recipe_survive_without_spending_twice() -> void:
	var game := _game()
	game._choose_meal_source("home_kitchen")
	assert_true(game.confirm_household_food(["tofu", "millet_porridge"], "fridge", {"seasoning": "usual", "added_sugar_g": 8}))
	var before := game.kitchen.ingredients.duplicate(true)
	var condiments := game.kitchen.condiments.duplicate(true)
	_roundtrip(game)
	assert_eq(game.kitchen.ingredients, before)
	assert_eq(game.kitchen.condiments, condiments)
	assert_eq(game.kitchen.batches[0]["danger_minutes"], 720)
	assert_eq(game.kitchen.batches[1]["recipe_facts"]["sodium_from_added_seasonings_mg"], 1500)
	game.kitchen.batches[1].erase("fridge_max_c")
	_roundtrip(game)
	assert_eq(game.kitchen.available("tofu", 1), 0)
	game._skip_action()
	game._choose_meal_source("home_fridge")
	assert_true(game.confirm_household_food(["millet_porridge"]))
	_roundtrip(game)
	assert_eq(game.kitchen.available("millet_porridge", 1), 0)
	assert_eq(game.today_meal_records.back()["recipe_facts"]["white_sugar_added_g"], 8)


func test_invalid_save_is_transactional_and_cannot_switch_story_or_open_health_flags() -> void:
	var game := _game()
	var before := game.capture_game_save()
	var invalid := before.duplicate(true)
	invalid["payload"]["day"] = 99
	assert_false(game.restore_game_save(invalid)["ok"])
	assert_eq(game.state, before["payload"]["state"])
	assert_eq(game.kitchen.ingredients, before["payload"]["kitchen"]["ingredients"])
	invalid = before.duplicate(true)
	invalid["story_id"] = "campus_exam"
	assert_false(game.restore_game_save(invalid)["ok"])
	assert_eq(game.story_id, "choir_week")
	assert_false(Codec.decode("{broken}")["ok"])
	invalid = before.duplicate(true)
	invalid["schema_version"] = 2
	assert_false(game.restore_game_save(invalid)["ok"])
	invalid = before.duplicate(true)
	invalid["payload"]["today_period_records"] = ["broken"]
	assert_false(game.restore_game_save(invalid)["ok"])
	assert_false(game._health_data_enabled())


func test_file_slots_backup_import_and_story_isolation() -> void:
	var folder := "res://.godot/save-tests-" + str(Time.get_ticks_usec())
	var store := Store.new(folder, "file")
	var older := _game().capture_game_save()
	var campus := _game("campus_exam").capture_game_save()
	for slot in Store.SLOTS:
		var result: Dictionary = store.write_local(older, slot)
		assert_true(result["ok"], str(result))
	assert_true(store.write_local(campus)["ok"])
	assert_eq(store.read_save("campus_exam")["save"]["payload"]["state"]["balance"], 150)
	assert_eq(store.read_save("choir_week")["save"]["payload"]["state"]["balance"], 210)
	var new_store := Store.new(folder, "file")
	assert_true(new_store.read_save("choir_week", "manual_3")["ok"])
	var changed := older.duplicate(true)
	changed["payload"]["state"]["balance"] = 200
	assert_true(new_store.write_local(changed)["ok"])
	var file := FileAccess.open(folder.path_join("choir_week/auto.json"), FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var restored := new_store.read_save("choir_week")
	assert_true(restored["ok"])
	assert_true(restored["backup"])
	assert_eq(restored["save"]["payload"]["state"]["balance"], 210)
	assert_false(Codec.decode("{}")["ok"])
	assert_eq(new_store.read_save("choir_week", "manual_1")["save"]["payload"]["state"]["balance"], 210)
	assert_true(new_store.write_local(Codec.decode(Codec.encode(changed)["text"])["save"], "manual_2")["ok"])
	assert_eq(new_store.read_save("choir_week", "manual_2")["save"]["payload"]["state"]["balance"], 200)
	assert_false(new_store.write_local(changed, "../escape")["ok"])


func test_invitation_is_still_a_plan_after_reading_and_completed_stays_completed() -> void:
	var game := _game()
	# A service-level branch fixture; full-day identity is checked separately.
	game.day = 4
	game._started_day = 4
	game.phase = "lunch_action"
	for d in range(1, 4):
		game.run_history.append({"day": d, "meals": [], "actions": [], "recovery_state": game.current_recovery_state.duplicate(true)})
	assert_true(game.plan_shared_meal("home"))
	var forged := game.capture_game_save()
	forged["payload"]["shared_meal"]["plan"]["status"] = "completed"
	assert_false(Codec.encode(forged)["ok"])
	_roundtrip(game)
	assert_eq(game.shared_meal.plan["status"], "planned")
	game._skip_action()
	game._choose_meal_source("home_kitchen")
	assert_true(game.confirm_household_food(["rice_plain", "tofu"]))
	_roundtrip(game)
	assert_eq(game.shared_meal.plan["status"], "completed")
	assert_eq(game.shared_meal.history.size(), 2)
	assert_false(game.confirm_household_food(["rice_plain", "tofu"]))


func test_fresh_scene_continues_without_new_day_resources_or_inventory() -> void:
	var previous := _game()
	previous._choose_meal_source("home_kitchen")
	assert_true(previous.confirm_household_food(["tofu"], "fridge"))
	var saved := previous.capture_game_save()
	assert_true(Session.request_saved(saved))
	var game := Scene.instantiate() as GameRootV2
	track(game)
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	assert_eq(game.phase, "breakfast_action")
	assert_false(game.new_day_popup.visible)
	assert_eq(game.state, previous.state)
	assert_eq(game.kitchen.ingredients, previous.kitchen.ingredients)
	assert_eq(game.today_meal_records.size(), 1)
	assert_true(Session.take_saved().is_empty())


func test_save_dialog_blocks_day_and_summary_keys_and_restores_them() -> void:
	Session.request("choir_week")
	var game := Scene.instantiate() as GameRootV2
	track(game)
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	game.new_day_popup.hide_popup(false)
	game._show_game_menu()
	assert_false(game.daily_summary.is_processing_unhandled_key_input())
	assert_true(game.daily_summary.next_button.disabled)
	assert_false(game.new_day_popup.is_processing_unhandled_key_input())
	assert_true(game.new_day_popup.continue_button.disabled)
	game._story_dialog._buttons.get_node("close").pressed.emit()
	assert_false(game.new_day_popup.continue_button.disabled)
	assert_false(game.daily_summary.next_button.disabled)


func test_every_phase_roundtrips_across_real_seven_day_runs() -> void:
	for id in ["campus_exam", "choir_week"]:
		var game := _game(id)
		for run_day in range(1, 8):
			for meal in ["breakfast", "lunch", "dinner"]:
				_roundtrip(game)
				game._choose_meal_source("local_market" if id == "choir_week" and meal == "breakfast" else ("community_canteen" if id == "choir_week" else "cafeteria"))
				_roundtrip(game)
				var plate: Array[String] = []
				for food_id in ["rice_plain", "oatmeal", "egg", "tofu", "millet_porridge", "steamed_egg", "tomato_egg_stir_fry", "soft_tofu_greens", "greens", "tomato", "milk", "plain_yogurt", "apple", "banana", "steamed_fish"]:
					if not game.hand.has(food_id): continue
					game.selected_food_ids = plate.duplicate()
					if game._can_add_food(food_id): plate.append(food_id)
					if plate.size() >= 2: break
				game._confirm_food(plate)
				_roundtrip(game)
				if meal == "breakfast":
					game._apply_action("rehearse" if id == "choir_week" else "study")
				elif meal == "lunch" and run_day in [3, 5]:
					game._apply_action("group_rehearsal" if id == "choir_week" else "study")
				else:
					game._apply_action("nap")
				_roundtrip(game)
			game._choose_sleep("sleep_early")
			_roundtrip(game)
			if run_day < 7 and game.phase == "summary":
				game._on_summary_advanced()
		assert_eq(game.day, 7)
		assert_eq(game.phase, "ending")
