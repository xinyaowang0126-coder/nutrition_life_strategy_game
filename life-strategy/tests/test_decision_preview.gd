@tool
extends McpTestSuite

const Scene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
const Data := preload("res://scripts/GameData.gd")
const Balance := preload("res://scripts/systems/GameplayBalanceRules.gd")


func suite_name() -> String:
	return "decision_preview"


func _game(story_id: String) -> GameRootV2:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	Session.request(story_id)
	var game := Scene.instantiate() as GameRootV2
	game.health_history_path = ""
	viewport.add_child(game)
	game.new_day_popup.hide_popup(false)
	game._new_day_pending = false
	game._deck_service.set_seed(20261016)
	return game


func _source(game: GameRootV2, source_id: String) -> MealStageBaseV2:
	game.phase = "lunch_source" if source_id in ["takeout", "community_canteen"] else "breakfast_source"
	game._render_phase()
	game._choose_meal_source(source_id)
	return game._active_stage as MealStageBaseV2


func test_all_source_previews_match_real_payment_and_inventory_use() -> void:
	for story_id in ["campus_exam", "choir_week"]:
		var source_ids := ["cafeteria", "takeout", "convenience_store", "dorm_storage"] if story_id == "campus_exam" else ["home_kitchen", "community_canteen", "local_market", "home_fridge", "breakfast_shop"]
		for source_id: String in source_ids:
			var game := _game(story_id)
			var stage := _source(game, source_id)
			var ids: Array[String] = [game.hand[0], game.hand[1]]
			var before := {"state": game.state.duplicate(true), "pantry": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "dorm": game.dorm_inventory.duplicate(true)}
			var stocks := {}
			for id in ids:
				stocks[id] = game._stock_count(id, source_id)
				game._on_food_toggled(id)
			var preview := stage.get_cost_preview()
			assert_false(preview.is_empty(), story_id + "/" + source_id)
			assert_true(stage._get_cost_preview_label().is_visible_in_tree())
			assert_contains(stage._get_cost_preview_label().text, "精力")
			assert_eq(preview["source_effort"], maxi(0, -int(game._effective_meal_source(source_id).get("energy", 0))))
			assert_eq(game.state, before["state"])
			assert_eq(game.kitchen.ingredients, before["pantry"])
			assert_eq(game.kitchen.condiments, before["condiments"])
			assert_eq(game.dorm_inventory, before["dorm"])
			assert_true(game.today_meal_records.is_empty())
			if story_id == "choir_week": assert_true(game.confirm_household_food(ids))
			else: game._confirm_food(ids)
			var record: Dictionary = game.today_meal_records.back()
			assert_eq(record["total_cost"], preview["cash_cost"])
			assert_eq(int(before["state"]["balance"]) - int(game.state["balance"]), preview["cash_cost"])
			if source_id == "home_kitchen":
				var needs := game.kitchen.needs(ids, game._story_food_catalog())
				for key in needs:
					assert_eq(int(before["pantry"][key]) - int(game.kitchen.ingredients[key]), preview["inventory"][game._ingredient_name(key)])
			elif bool(record["uses_stock"]):
				for id in ids:
					assert_eq(int(stocks[id]) - game._stock_count(id, source_id), 1)
					assert_eq(preview["inventory"][game._story_food(id)["name"]], 1)
			else: assert_true(preview["inventory"].is_empty())


func test_takeout_preview_tracks_each_days_real_fee_without_spending() -> void:
	var game := _game("campus_exam")
	for run_day in range(1, 8):
		game.day = run_day
		_source(game, "takeout")
		var id := String(game.hand[0])
		var before := game.state.duplicate(true)
		var preview := game.preview_meal_cost([id])
		var source := game._effective_meal_source("takeout")
		assert_eq(preview["source_fee"], int(source.get("fee", 0)))
		assert_eq(preview["cash_cost"], int(source.get("fee", 0)) + int(game._story_food(id)["cost"]))
		assert_eq(game.state, before)


func test_shared_meal_preview_counts_current_two_portions_before_recipe_choices() -> void:
	var game := _game("choir_week")
	game.day = 4
	game.phase = "lunch_action"
	assert_true(game.plan_shared_meal("home"))
	game._skip_action()
	game._choose_meal_source("home_kitchen")
	var preview := game.preview_meal_cost(["rice_plain", "soft_tofu_greens"])
	assert_eq(preview["inventory"], {"米": 2, "豆腐": 2, "青菜": 2})
	assert_true(preview["recipe_next"])
	assert_contains(preview["detail"], "配方页")
	assert_eq(preview["cash_cost"], 0)
	assert_eq(preview["source_effort"], 6)
	assert_true(game.today_meal_records.is_empty())


func test_saved_food_preview_does_not_claim_another_raw_material_charge() -> void:
	var game := _game("choir_week")
	_source(game, "home_kitchen")
	assert_true(game.confirm_household_food(["rice_plain", "soft_tofu_greens"], "fridge"))
	game._skip_action()
	game._choose_meal_source("home_fridge")
	var before := game.kitchen.ingredients.duplicate(true)
	var preview := game.preview_meal_cost(["rice_plain", "soft_tofu_greens"])
	assert_eq(preview["inventory"], {"白米饭": 1, "时蔬炖豆腐": 1})
	assert_false(preview["recipe_next"])
	assert_eq(preview["source_effort"], 1)
	assert_eq(game.kitchen.ingredients, before)
	assert_true(game.confirm_household_food(["rice_plain", "soft_tofu_greens"]))
	assert_eq(game.kitchen.ingredients, before)


func test_removing_all_cards_clears_old_costs_and_invalid_previews_are_read_only() -> void:
	var game := _game("campus_exam")
	var stage := _source(game, "takeout")
	var id := String(game.hand[0])
	game._on_food_toggled(id)
	assert_false(stage.get_cost_preview().is_empty())
	game._on_food_toggled(id)
	assert_true(stage.get_cost_preview().is_empty())
	assert_false(stage._get_cost_preview_label().visible)
	assert_eq((stage as TakeoutMealStageV2).total_label.text, "合计 ¥0")
	# The empty total must not remove the delivery fee from affordability.
	stage.set_balance(int(game._story_food(id)["cost"]))
	assert_false(stage._disabled_reason(id).is_empty())
	var before := game.state.duplicate(true)
	assert_true(game.preview_meal_cost(["not_in_this_hand"]).is_empty())
	assert_true(game.preview_meal_cost([id, id]).is_empty())
	assert_eq(game.state, before)
	assert_true(game.today_meal_records.is_empty())


func test_action_cards_expose_direct_effort_slots_and_period_costs_without_activation() -> void:
	for story_id in ["campus_exam", "choir_week"]:
		var game := _game(story_id)
		var before := game.state.duplicate(true)
		game.phase = "breakfast_action"
		game._render_phase()
		var stage := game._active_stage as ActionStageV2
		for card: CompactChoiceCardV2 in stage._cards_by_id.values():
			var action := card.get_payload()
			assert_true(card.choice_cost_label.visible)
			assert_contains(card.choice_cost_label.text, "¥%d" % int(action.get("cost", 0)))
			assert_contains(card.choice_cost_label.text, "行动耗%d精力" % maxi(0, -int(action.get("energy", 0))))
			if int(action.get("slots", 1)) == 0: assert_contains(card.choice_cost_label.text, "时段不推进")
			else: assert_contains(card.choice_cost_label.text, "时段另耗%d" % -int(Balance.PERIOD_DELTA["energy"]))
		assert_eq(game.state, before)
		assert_true(game.today_action_records.is_empty())


func test_source_name_target_matches_artwork_enabled_state_and_does_not_duplicate_focus() -> void:
	var game := _game("campus_exam")
	var stage := game._active_stage as MealSourceStageV2
	for source_id: String in stage.SOURCE_NODE_NAMES:
		var prop := stage._prop_for(source_id)
		var target := prop.get_node("Name/NameTarget") as Button
		var art := prop.get_node("Button") as BaseButton
		assert_eq(target.disabled, art.disabled)
		assert_eq(target.focus_mode, Control.FOCUS_NONE)
		assert_eq(target.mouse_filter, Control.MOUSE_FILTER_STOP)
	stage.set_source_enabled("cafeteria", false, "现在未开放")
	assert_true((stage._prop_for("cafeteria").get_node("Name/NameTarget") as Button).disabled)
	(stage._prop_for("cafeteria").get_node("Name/NameTarget") as Button).pressed.emit()
	assert_eq(game.phase, "breakfast_source")
	assert_true(game.current_source_id.is_empty())
	stage.set_source_enabled("cafeteria", true)
	(stage._prop_for("cafeteria").get_node("Name/NameTarget") as Button).pressed.emit()
	assert_eq(game.current_source_id, "cafeteria")


func test_choir_night_art_is_distinct_while_campus_keeps_its_existing_art_and_values() -> void:
	var campus := _game("campus_exam")
	var choir := _game("choir_week")
	for id in ["sleep_early", "night_study", "scroll_phone"]:
		var original := Data.get_sleep_option(id)
		var student := campus._story_sleep(id)
		var elder := choir._story_sleep(id)
		assert_eq(student["image"], original["image"])
		assert_contains(elder["image"], "stories/night/zhou_")
		assert_true(ResourceLoader.exists(elder["image"]))
		for stat in ["energy", "satiety", "mood", "stress", "study"]: assert_eq(elder[stat], student[stat])
