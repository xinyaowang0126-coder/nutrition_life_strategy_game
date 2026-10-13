@tool
extends McpTestSuite

const Adapter := preload("res://scripts/health/MealGuidanceAdapter.gd")
const Suggestions := preload("res://scripts/health/FeasibleSuggestionService.gd")
const Memory := preload("res://scripts/health/SuggestionMemory.gd")
const Presenter := preload("res://scripts/health/HealthGuidancePresenter.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Data := preload("res://scripts/GameData.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Fixture := preload("res://tests/fixtures/g4_sources/SourceFixture.gd")
const Model := preload("res://tests/preview/G4PreviewModel.gd")
const Preview := preload("res://tests/preview/G4MealPreview.tscn")
var fixture := Fixture.new()


func suite_name() -> String:
	return "g4_suggestions"


func setup() -> void:
	fixture = Fixture.new()


func test_missing_unavailable_vegetable_does_not_hide_a_real_pantry_staple_option() -> void:
	var live := _live("dorm_storage", ["milk", "oatmeal", "apple"], ["milk"])
	live["balance"] = 0
	var before := live.duplicate(true)
	var offer := _offer(live)
	assert_true(offer["verified"])
	assert_eq(offer["action"]["target_role"], "staple")
	assert_eq(offer["action"]["food_id"], "oatmeal")
	assert_eq(offer["action"]["total_cost"], 0)
	assert_eq(live, before)
	var game := _game()
	game.source_hands["breakfast:dorm_storage"] = live["hand_ids"].duplicate()
	game._choose_meal_source("dorm_storage")
	game._on_food_toggled("milk")
	var actual := _offer(game.get_meal_guidance_input())
	var resolved := _resolve(actual, game.get_meal_guidance_input())
	assert_true(resolved["valid"])
	game._confirm_food(resolved["selected_ids"])
	assert_eq(game.state["balance"], 150)
	assert_eq(game.dorm_inventory["milk"], 0)
	assert_eq(game.dorm_inventory["oatmeal"], 1)
	assert_eq(game.phase, "breakfast_action")


func test_primary_and_distinct_alternative_are_both_executable_and_keep_current_food() -> void:
	var live := _live("cafeteria", ["rice_plain", "tomato", "greens", "egg"], ["rice_plain"], 1, "lunch")
	var offer := _offer(live)
	assert_true(offer["verified"])
	assert_eq(offer["action"]["target_role"], "vegetable")
	assert_eq(offer["action"]["food_id"], "greens")
	assert_eq(offer["alternative"]["food_id"], "tomato")
	for action in [offer["action"], offer["alternative"]]:
		assert_true(_resolve({"verified": true, "action": action}, live)["valid"])
		assert_eq(action["kind"], "add_food")
		assert_true(action["selection"].has("rice_plain"))
		assert_eq(action["total_cost"], 5)
	var game := _game()
	game.phase = "lunch_source"
	game.source_hands["lunch:cafeteria"] = live["hand_ids"].duplicate()
	game._choose_meal_source("cafeteria")
	game._on_food_toggled("rice_plain")
	var actual := _offer(game.get_meal_guidance_input())
	var alternative := {"verified": true, "action": actual["alternative"]}
	var selected := _resolve(alternative, game.get_meal_guidance_input())
	game._confirm_food(selected["selected_ids"])
	assert_eq(game.state["balance"], 145)
	assert_eq(game.today_meal_records[0]["food_ids"], alternative["action"]["selection"])
	assert_false(_resolve(alternative, game.get_meal_guidance_input())["valid"])


func test_equal_price_taste_tiebreak_is_explicit_and_does_not_change_composition() -> void:
	var live := _live("cafeteria", ["rice_plain", "tomato", "greens", "egg"], ["rice_plain"], 1, "lunch")
	var context := Adapter.build_context(live, fixture.catalog)
	var view := Presenter.meal_view(context["current_snapshot"], fixture.config, fixture.registry, Fixture.DATE, fixture.copies)
	var policy := {"preferences": {"id": "test-character", "name": "测试角色", "version": 1, "reactions": {"tomato": {"mood_delta": 5, "comfort": true}, "greens": {"mood_delta": 0, "comfort": false}}}}
	assert_eq(_offer(live)["action"]["food_id"], "greens")
	var preferred := _offer(live, policy)
	assert_eq(preferred["action"]["food_id"], "tomato")
	assert_true(_resolve(preferred, live, policy)["valid"])
	assert_false(_resolve(preferred, live)["valid"])
	assert_eq(Presenter.meal_view(context["current_snapshot"], fixture.config, fixture.registry, Fixture.DATE, fixture.copies), view)
	# A character liking a dearer option does not bypass the cost ordering.
	context["options"][2]["cost"] = 1
	var cheaper := Suggestions.find_option(context, fixture.config, fixture.registry, Fixture.DATE, fixture.copies, policy)
	assert_eq(cheaper["action"]["food_id"], "greens")
	assert_eq(cheaper["action"]["total_cost"], 3)
	assert_false(preferred["action"].has("nutrition_score"))


func test_ranking_is_independent_of_option_order_and_outputs_are_detached() -> void:
	var context := Adapter.build_context(_live("cafeteria", ["rice_plain", "tomato", "greens", "egg"], ["rice_plain"], 1, "lunch"), fixture.catalog)
	var before := context.duplicate(true)
	var first := Suggestions.find_option(context, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)
	context["options"].reverse()
	var second := Suggestions.find_option(context, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)
	assert_eq(first, second)
	first["action"]["selection"].clear()
	first["alternative"]["selection"].clear()
	context["options"].reverse()
	assert_eq(context, before)


func test_dismissal_changes_the_offer_without_spending_or_changing_the_selection() -> void:
	var model := Model.new()
	model.toggle("fixture_rice")
	model.toggle("fixture_egg")
	var before := {"selected": model.selected.duplicate(), "balance": model.balance, "records": model.records.duplicate(true)}
	var original := model.suggestion()
	assert_true(model.dismiss_suggestion(original))
	var changed := model.suggestion()
	assert_true(changed["verified"])
	assert_ne(changed["action"]["suggestion_key"], original["action"]["suggestion_key"])
	assert_eq({"selected": model.selected, "balance": model.balance, "records": model.records}, before)
	assert_false(model.apply_suggestion(original))
	assert_true(model.confirm(), "Skipping advice never blocks confirmation")


func test_shown_receipt_does_not_rotate_the_same_selection_on_every_refresh() -> void:
	var live := _live("cafeteria", ["rice_plain", "egg", "tomato"], ["rice_plain", "egg"])
	var initial := _offer(live)
	var history := Memory.record([], initial["action"])
	assert_true(history["valid"])
	var refreshed := _offer(live, {"history": history["history"]})
	assert_eq(refreshed["action"]["food_id"], initial["action"]["food_id"])
	assert_true(refreshed["verified"])
	assert_false(_resolve(initial, live, {"history": history["history"]})["valid"], "Receipt changes invalidate the old policy token")


func test_recent_repeated_instruction_uses_an_available_alternative_first() -> void:
	var live := _live("cafeteria", ["rice_plain", "egg", "tomato", "greens"], ["rice_plain", "egg"], 1, "dinner")
	var current := _offer(live)
	var earlier: Dictionary = current["action"].duplicate(true)
	earlier["phase"] = "lunch"
	var history := Memory.record([], earlier)
	var offered := _offer(live, {"history": history["history"]})
	assert_true(offered["verified"])
	assert_eq(offered["action"]["food_id"], "tomato")
	assert_eq(offered["alternative"], null)
	assert_false(offered["action"]["suggestion_key"] == earlier["suggestion_key"])


func test_cooldown_without_confirmed_pattern_returns_a_plan_with_no_executable_card() -> void:
	var live := _live("cafeteria", ["rice_plain", "egg", "tomato"], ["rice_plain", "egg"], 1, "dinner")
	var earlier: Dictionary = _offer(live)["action"].duplicate(true)
	earlier["phase"] = "lunch"
	var history: Array = Memory.record([], earlier)["history"]
	var offered := _offer(live, {"history": history})
	assert_false(offered["verified"])
	assert_eq(offered["reason"], "cooldown_active")
	assert_eq(offered["action"], null)
	assert_eq(offered["plan"]["target_day"], 2)
	assert_eq(offered["plan"]["target_phase"], "breakfast")
	assert_eq(offered["plan"]["food_ids"], [])
	assert_false(offered["plan"]["executable_now"])
	assert_true(offered["plan"]["requires_recheck"])
	assert_false(_resolve(offered, live, {"history": history})["valid"])


func test_repeat_is_allowed_only_after_two_confirmed_supported_meals_and_no_other_option() -> void:
	var live := _live("cafeteria", ["rice_plain", "egg", "tomato"], ["rice_plain", "egg"], 1, "dinner")
	var prior_action: Dictionary = _offer(live)["action"].duplicate(true)
	prior_action["phase"] = "lunch"
	var history: Array = Memory.record([], prior_action)["history"]
	var meals := [_meal(1, "breakfast", ["rice_plain", "egg"]), _meal(1, "lunch", ["rice_plain", "egg"])]
	var policy := {"history": history, "meal_history": meals}
	assert_true(_offer(live, policy)["verified"])
	assert_true(_resolve(_offer(live, policy), live, policy)["valid"])
	policy["meal_history"] = [meals[1]]
	assert_false(_offer(live, policy)["verified"])
	policy["meal_history"] = [Snapshot.build(1, {"phase": "breakfast", "skipped": true}, fixture.catalog), meals[1]]
	assert_false(_offer(live, policy)["verified"], "A skipped meal is not a supported absence of vegetables")
	policy["meal_history"] = [_meal(1, "breakfast", ["rice_plain", "tomato"]), meals[1]]
	assert_false(_offer(live, policy)["verified"])


func test_a_recent_unknown_record_never_proves_a_persistent_pattern() -> void:
	var live := _live("cafeteria", ["rice_plain", "egg", "tomato"], ["rice_plain", "egg"], 1, "dinner")
	var earlier: Dictionary = _offer(live)["action"].duplicate(true)
	earlier["phase"] = "lunch"
	var policy := {"history": Memory.record([], earlier)["history"], "meal_history": [_meal(1, "breakfast", ["rice_plain"], {}), _meal(1, "lunch", ["rice_plain", "egg"])]}
	assert_false(_offer(live, policy)["verified"])
	assert_eq(_offer(live, policy)["reason"], "cooldown_active")


func test_future_invalid_or_duplicate_memory_cannot_bypass_the_filter() -> void:
	var live := _live("cafeteria", ["rice_plain", "egg", "tomato"], ["rice_plain", "egg"])
	var action: Dictionary = _offer(live)["action"].duplicate(true)
	action["phase"] = "lunch"
	var future: Array = Memory.record([], action)["history"]
	for policy in [null, [], {"weights": {}}, {"preferences": {"id": "bad"}}, {"history": future}, {"history": [true]}, {"meal_history": [_meal(1, "lunch", ["rice_plain"])]}, {"meal_history": [_meal(1, "breakfast", ["rice_plain"])]}]:
		var offered := _offer(live, policy)
		assert_false(offered["verified"])
		assert_eq(offered["reason"], "policy_invalid")
		assert_eq(offered["plan"], null)
	assert_false(Memory.record([], {}, "shown")["valid"])
	assert_false(Memory.record([], action, "accepted")["valid"])


func test_receipts_are_copied_deduplicated_and_do_not_extend_a_meal_archive() -> void:
	var action: Dictionary = _offer(_live("cafeteria", ["rice_plain", "egg", "tomato"], ["rice_plain", "egg"]))["action"]
	var history: Array = Memory.record([], action)["history"]
	var before := history.duplicate(true)
	var repeated := Memory.record(history, action)
	assert_eq(repeated["history"].size(), 1)
	repeated["history"][0]["target_role"] = "staple"
	assert_eq(history, before)
	assert_false(history[0].has("health_snapshot"))
	assert_false(history[0].has("score"))


func test_no_current_option_plan_is_structured_and_stops_at_the_end_of_the_week() -> void:
	var live := _live("dorm_storage", ["oatmeal", "milk", "apple"], ["oatmeal"])
	var offer := _offer(live)
	assert_false(offer["verified"])
	assert_eq(offer["plan"]["target_phase"], "lunch")
	assert_eq(offer["plan"]["target_role"], "vegetable")
	live["day"] = 7
	live["phase"] = "dinner"
	assert_eq(_offer(live)["plan"], null)
	fixture.config["review_status"] = "draft"
	live["phase"] = "lunch"
	assert_eq(_offer(live)["plan"], null)
	assert_eq(_offer(live)["reason"], "information_insufficient")


func test_preview_alternative_and_dismissal_are_optional_and_do_not_pay() -> void:
	var preview = Preview.instantiate()
	track(preview)
	(Engine.get_main_loop() as SceneTree).root.add_child(preview)
	preview._toggle("fixture_rice")
	preview._toggle("fixture_egg")
	assert_true(preview.alternative_toggle.visible)
	assert_false(preview.alternative_button.visible)
	preview.alternative_toggle.set_pressed_no_signal(true)
	preview._toggle_alternative()
	assert_true(preview.alternative_button.visible)
	preview._try_alternative()
	assert_eq(preview.model.balance, 20)
	assert_eq(preview.model.records.size(), 0)
	assert_true(preview.model.selected.has("fixture_mixed"))
	preview._confirm()
	assert_eq(preview.model.balance, 9)
	assert_eq(preview.model.records.size(), 1)
	assert_false(preview.model.suggestion_history.is_empty())
	preview._restart()
	preview._toggle("fixture_rice")
	preview._toggle("fixture_egg")
	preview._dismiss_suggestion()
	preview._dismiss_suggestion()
	assert_true(preview.plan_label.visible)
	assert_false(preview.suggestion_button.visible)
	assert_false(preview.confirm_button.disabled)
	assert_eq(preview.model.balance, 20)
	preview._confirm()
	assert_eq(preview.model.balance, 16)


func _live(source: String, hand: Array, selected: Array, day: int = 1, phase: String = "breakfast") -> Dictionary:
	return {"day": day, "phase": phase, "source_id": source, "balance": 120, "hand_ids": hand.duplicate(), "selected_ids": selected.duplicate(), "inventory": Data.get_initial_dorm_inventory()}


func _offer(live: Dictionary, policy: Variant = {}) -> Dictionary:
	return Suggestions.find_option(Adapter.build_context(live, fixture.catalog), fixture.config, fixture.registry, Fixture.DATE, fixture.copies, policy)


func _resolve(proposal: Variant, live: Dictionary, policy: Variant = {}) -> Dictionary:
	return Adapter.resolve_proposal(proposal, live, fixture.catalog, fixture.config, fixture.registry, Fixture.DATE, fixture.copies, policy)


func _meal(day: int, phase: String, ids: Array, catalog: Variant = null) -> Dictionary:
	return Snapshot.build(day, {"phase": phase, "source_id": "cafeteria", "food_ids": ids}, fixture.catalog if catalog == null else catalog)


func _game() -> GameRootV2:
	var game := Controller.new() as GameRootV2
	track(game)
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game._deck_service = Deck.new(73)
	game.start_new_run()
	return game
