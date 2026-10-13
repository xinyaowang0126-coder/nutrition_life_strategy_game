@tool
extends McpTestSuite

const Adapter := preload("res://scripts/health/MealGuidanceAdapter.gd")
const Shadow := preload("res://scripts/health/MealGuidanceShadow.gd")
const Suggestions := preload("res://scripts/health/FeasibleSuggestionService.gd")
const Store := preload("res://scripts/health/HealthDataStore.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Validator := preload("res://scripts/health/HealthDataValidator.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Data := preload("res://scripts/GameData.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Events := preload("res://scripts/systems/WeeklyEventService.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Fixture := preload("res://tests/fixtures/g4_sources/SourceFixture.gd")
var fixture


func suite_name() -> String:
	return "g4_sources"


func setup() -> void:
	fixture = Fixture.new()


func test_real_source_prices_and_limits_match_the_game_resolver() -> void:
	assert_true(Validator.validate(fixture.catalog)["valid"])
	for id in Data.get_meal_source_ids():
		var live := _live(id)
		live["selected_ids"] = [live["hand_ids"][0]]
		var context := Adapter.build_context(live, fixture.catalog)
		assert_true(context["valid"], id)
		var source := Events.apply_meal_source(live["day"], id, Data.get_meal_source(id))
		var food_rows: Array[Dictionary] = [Data.get_food(live["selected_ids"][0])]
		var record := Resolver.build_record(live["phase"], source, food_rows)
		assert_eq(context["total_cost"], record["total_cost"], id)
		assert_eq(context["selection_limit"], source["selection_limit"], id)
		assert_eq(context["fee"], record["source_fee"], id)
		for option in context["options"]:
			assert_eq(option["cost"], Data.get_food(option["id"])["cost"])


func test_coupon_and_rainy_day_fees_are_read_at_the_actual_day() -> void:
	for day in [1, 4, 6]:
		var live := _live("takeout", ["sandwich"], ["sandwich"], day)
		var context := Adapter.build_context(live, fixture.catalog)
		assert_true(context["valid"])
		assert_eq(context["fee"], {1: 3, 4: 1, 6: 5}[day])
		assert_eq(context["total_cost"], 9 + context["fee"])
	var coupon := _live("takeout", ["sandwich"], ["sandwich"], 4)
	coupon["balance"] = 10
	assert_true(Adapter.build_context(coupon, fixture.catalog)["valid"])
	coupon["day"] = 6
	assert_eq(Adapter.build_context(coupon, fixture.catalog)["reason"], "selection_unaffordable")


func test_closed_source_wrong_pool_or_phase_and_duplicate_ids_are_rejected() -> void:
	var values := [
		_live("takeout", ["sandwich"], ["sandwich"], 1, "breakfast"),
		_live("cafeteria", ["apple"], ["apple"]),
		_live("cafeteria", ["tofu"], ["tofu"], 1, "breakfast"),
		_live("cafeteria", ["rice_plain", "rice_plain"], ["rice_plain"]),
		_live("cafeteria", ["rice_plain"], ["rice_plain", "rice_plain"]),
		_live("cafeteria", ["rice_plain"], ["egg"]),
	]
	for live in values:
		assert_false(Adapter.build_context(live, fixture.catalog)["valid"], str(live))
	for phase in ["breakfast_source", "lunch_action", "sleep", "summary", "ending"]:
		var live := _live("cafeteria", ["rice_plain"], ["rice_plain"])
		live["phase"] = phase
		assert_eq(Adapter.build_context(live, fixture.catalog)["reason"], "not_selecting")
	assert_false(Adapter.build_context(_live("missing_source"), fixture.catalog)["valid"])


func test_source_selection_limits_and_integer_boundaries_are_enforced() -> void:
	var full := _live("cafeteria", ["rice_plain", "egg", "tomato"], ["rice_plain", "egg", "tomato"])
	assert_true(Adapter.build_context(full, fixture.catalog)["valid"])
	var too_many := _live("convenience_store", ["apple", "milk", "sandwich"], ["apple", "milk", "sandwich"])
	assert_eq(Adapter.build_context(too_many, fixture.catalog)["reason"], "selection_limit")
	for bad in [null, [], "selection", {"day": 1.0}, {"day": 0}, {"day": 8}]:
		assert_false(Adapter.build_context(bad, fixture.catalog)["valid"])
	for amount in [-1, 1000, 5.5, "5", true]:
		var live := _live("cafeteria")
		live["balance"] = amount
		assert_eq(Adapter.build_context(live, fixture.catalog)["reason"], "balance_invalid")


func test_pantry_uses_only_present_stock_and_never_charges_card_prices() -> void:
	var live := _live("dorm_storage", ["oatmeal", "milk", "apple"], ["oatmeal", "milk"])
	live["balance"] = 0
	live["inventory"] = {"oatmeal": 1, "milk": 1, "apple": 0}
	var context := Adapter.build_context(live, fixture.catalog)
	assert_true(context["valid"])
	assert_eq(context["payment_mode"], "stock")
	assert_eq(context["total_cost"], 0)
	assert_eq(context["fee"], 0)
	assert_false(context["options"][2]["available"])
	assert_true(context["options"][2]["candidate_snapshots"].is_empty())
	live["inventory"].erase("milk")
	assert_eq(Adapter.build_context(live, fixture.catalog)["reason"], "stock_unavailable")
	for amount in [-1, 1000, 1.0, "1"]:
		live["inventory"]["milk"] = amount
		assert_eq(Adapter.build_context(live, fixture.catalog)["reason"], "stock_invalid")


func test_cash_sources_ignore_pantry_stock_for_the_same_food() -> void:
	var live := _live("convenience_store", ["instant_noodles", "milk"], ["instant_noodles"])
	live["inventory"] = {"instant_noodles": 0, "milk": 0}
	var context := Adapter.build_context(live, fixture.catalog)
	assert_true(context["valid"])
	assert_eq(context["total_cost"], 5)
	assert_true(context["options"][1]["available"])
	live["balance"] = 3
	assert_false(Adapter.build_context(live, fixture.catalog)["valid"])


func test_context_is_detached_from_the_controller_catalog_and_rng() -> void:
	var game := _game()
	game._choose_meal_source("cafeteria")
	game._on_food_toggled(game.hand[0])
	var before := _game_state(game)
	var catalog_before: Dictionary = fixture.catalog.duplicate(true)
	var first := game.get_meal_guidance_input()
	var context := Adapter.build_context(first, fixture.catalog)
	assert_true(context["valid"])
	assert_eq(Adapter.build_context(game.get_meal_guidance_input(), fixture.catalog)["context_token"], context["context_token"])
	first["hand_ids"].clear()
	first["selected_ids"].clear()
	first["inventory"].clear()
	context["current_snapshot"]["profile_snapshots"].clear()
	context["options"].clear()
	assert_eq(_game_state(game), before)
	assert_eq(fixture.catalog, catalog_before)
	assert_false(game._health_catalog_loaded)
	assert_eq(game._health_archive, null)
	assert_eq(game.get_health_snapshots(), [])


func test_production_drafts_and_closed_flags_do_not_allow_guidance() -> void:
	var catalog := Store.new().load_catalog()
	var registry := Evidence.new()
	registry.load_registry()
	var live := _live("cafeteria", ["rice_plain", "egg", "tomato"], ["rice_plain", "egg"])
	var result := Shadow.inspect_selection(live, catalog, Config.defaults(), registry, Fixture.DATE, Composer.load_catalog())
	assert_true(result["valid"])
	assert_false(result["view"]["nutrition_allowed"])
	assert_eq(result["view"]["ingredients"], [])
	assert_false(result["suggestion"]["verified"])
	for profile in catalog["profiles"].values():
		assert_eq(profile["review_status"], "draft")
	for flag in ["data", "engine", "ui", "weekly"]:
		assert_false(bool(ProjectSettings.get_setting("health_guidance_v2/" + flag)))


func test_optional_suggestion_resolves_without_paying_and_confirm_matches_quote() -> void:
	var game := _game()
	game.source_hands["breakfast:cafeteria"] = ["rice_plain", "egg", "tomato"]
	game._choose_meal_source("cafeteria")
	game._on_food_toggled("rice_plain")
	game._on_food_toggled("egg")
	var before := _game_state(game)
	var proposal := _proposal(game.get_meal_guidance_input())
	assert_true(proposal["verified"])
	assert_eq(proposal["action"]["food_id"], "tomato")
	var resolved := _resolve(proposal, game.get_meal_guidance_input())
	assert_true(resolved["valid"])
	assert_eq(_game_state(game), before)
	game._confirm_food(resolved["selected_ids"])
	assert_eq(game.phase, "breakfast_action")
	assert_eq(game.today_meal_records.size(), 1)
	assert_eq(game.today_meal_records[0]["food_ids"], proposal["action"]["selection"])
	assert_eq(game.today_meal_records[0]["total_cost"], proposal["action"]["total_cost"])
	assert_eq(game.state["balance"], before["state"]["balance"] - 7)
	assert_false(_resolve(proposal, game.get_meal_guidance_input())["valid"])
	game._confirm_food(resolved["selected_ids"])
	assert_eq(game.today_meal_records.size(), 1)


func test_suggestion_cost_includes_event_fee_once_and_rejects_insufficient_balance() -> void:
	var live := _live("takeout", ["fried_chicken", "salad_bowl"], ["fried_chicken"], 4)
	live["balance"] = 31
	var offer := _proposal(live)
	assert_true(offer["verified"])
	assert_eq(offer["action"]["total_cost"], 31)
	assert_true(_resolve(offer, live)["valid"])
	live["balance"] = 30
	assert_false(_proposal(live)["verified"])
	assert_false(_resolve(offer, live)["valid"])
	live["balance"] = 35
	live["day"] = 6
	assert_eq(_proposal(live)["action"]["total_cost"], 35)
	assert_false(_resolve(offer, live)["valid"])


func test_old_proposal_is_rejected_after_any_material_live_input_changes() -> void:
	var live := _live("cafeteria", ["rice_plain", "egg", "tomato", "greens"], ["rice_plain", "egg"])
	var offer := _proposal(live)
	assert_true(offer["verified"])
	for kind in ["balance", "hand", "selection", "day", "phase", "source"]:
		var changed := live.duplicate(true)
		match kind:
			"balance": changed["balance"] -= 1
			"hand": changed["hand_ids"].erase("greens")
			"selection": changed["selected_ids"] = ["rice_plain"]
			"day": changed["day"] = 2
			"phase": changed["phase"] = "dinner"
			"source": changed["source_id"] = "takeout"
		assert_false(_resolve(offer, changed)["valid"], kind)
	fixture.catalog["profiles"]["tomato"]["components"][0]["name"] = "changed fixture"
	assert_false(_resolve(offer, live)["valid"])
	assert_false(Adapter.resolve_proposal(null, live, fixture.catalog, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)["valid"])


func test_saturated_source_swaps_within_its_limit_without_losing_known_roles() -> void:
	var live := _live("convenience_store", ["apple", "milk", "sandwich"], ["apple", "milk"])
	var offer := _proposal(live)
	assert_true(offer["verified"])
	assert_eq(offer["action"]["kind"], "replace_food")
	assert_eq(offer["action"]["selection"].size(), 2)
	assert_true(_resolve(offer, live)["valid"])
	var pantry := _live("dorm_storage", ["oatmeal", "milk", "apple"], ["oatmeal"])
	assert_false(_proposal(pantry)["verified"], "No vegetable in this real source: do not invent a current option")


func test_frozen_day_view_uses_confirmation_data_and_keeps_missing_meals_absent() -> void:
	var records: Array = [
		Shadow.freeze_record(1, _record("breakfast", ["rice_plain", "egg"]), fixture.catalog, fixture.config, fixture.registry, Fixture.DATE, fixture.copies),
		Shadow.freeze_record(1, Resolver.build_skipped_record("lunch"), fixture.catalog, fixture.config, fixture.registry, Fixture.DATE, fixture.copies),
	]
	var before := records.duplicate(true)
	fixture.catalog["profiles"].clear()
	fixture.copies["copies"].clear()
	var day := Shadow.inspect_day(1, records)
	assert_true(day["valid"])
	assert_eq(day["diary"]["rows"].size(), 2)
	assert_eq(day["diary"]["observation"], "午饭没吃。")
	assert_eq(day["diary"]["spent"], 4)
	day["diary"]["rows"].clear()
	assert_eq(records, before)
	assert_true(Shadow.inspect_day(1, [])["valid"])
	assert_false(Shadow.inspect_day(2, records)["valid"])
	assert_false(Shadow.inspect_day(1, [records[0], records[0]])["valid"])
	assert_false(Shadow.inspect_day(1, [])["diary"].has("score"))


func test_data_on_snapshot_is_authoritative_and_day_rejects_mismatched_records() -> void:
	var record := _record("breakfast", ["rice_plain"])
	record["health_snapshot"] = Snapshot.build(1, record, fixture.catalog)
	var original: Dictionary = record["health_snapshot"].duplicate(true)
	var frozen := Shadow.freeze_record(1, record, {}, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)
	assert_eq(frozen["health_snapshot"], original)
	assert_true(Shadow.inspect_day(1, [frozen])["valid"])
	for kind in ["day", "phase", "food_ids", "skipped", "snapshot"]:
		var changed := frozen.duplicate(true)
		match kind:
			"day": changed["day"] = 2
			"phase": changed["phase"] = "lunch"
			"food_ids": changed["food_ids"] = ["egg"]
			"skipped": changed["skipped"] = true
			"snapshot": changed["health_snapshot"] = {}
		assert_false(Shadow.inspect_day(1, [changed])["valid"], kind)
	assert_eq(record["health_snapshot"], original)


func _live(source: String, hand: Array = [], selected: Array = [], day: int = 1, phase: String = "lunch") -> Dictionary:
	return {"day": day, "phase": phase, "source_id": source, "balance": 120, "hand_ids": Data.get_food_ids_for_context(source, phase) if hand.is_empty() else hand.duplicate(), "selected_ids": selected.duplicate(), "inventory": Data.get_initial_dorm_inventory()}


func _proposal(live: Dictionary) -> Dictionary:
	return Suggestions.find_option(Adapter.build_context(live, fixture.catalog), fixture.config, fixture.registry, Fixture.DATE, fixture.copies)


func _resolve(proposal: Variant, live: Dictionary) -> Dictionary:
	return Adapter.resolve_proposal(proposal, live, fixture.catalog, fixture.config, fixture.registry, Fixture.DATE, fixture.copies)


func _game() -> GameRootV2:
	var game := Controller.new() as GameRootV2
	track(game)
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game.health_history_path = ""
	game._deck_service = Deck.new(73)
	game.start_new_run()
	return game


func _game_state(game: GameRootV2) -> Dictionary:
	return {"day": game.day, "phase": game.phase, "source": game.current_source_id, "state": game.state.duplicate(true), "hand": game.hand.duplicate(), "selected": game.selected_food_ids.duplicate(), "source_hands": game.source_hands.duplicate(true), "stock": game.dorm_inventory.duplicate(true), "records": game.today_meal_records.duplicate(true), "history": game.run_history.duplicate(true), "rng_state": game._deck_service._rng.state}


func _record(phase: String, ids: Array) -> Dictionary:
	var foods: Array[Dictionary] = []
	for id in ids:
		foods.append(Data.get_food(id))
	return Resolver.build_record(phase, Data.get_meal_source("cafeteria"), foods)
