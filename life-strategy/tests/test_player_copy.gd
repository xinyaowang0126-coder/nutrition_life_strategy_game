@tool
extends McpTestSuite

const Ledger := preload("res://scripts/systems/NutritionLedger.gd")
const Resolver := preload("res://scripts/systems/MealResolver.gd")
const Data := preload("res://scripts/GameData.gd")
const Presenter := preload("res://scripts/systems/RecoveryPresenter.gd")
const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")

class RecordingGame extends GameRootV2:
	var messages: Array[String] = []
	func _post(message: String, _tone: String = "info") -> void:
		messages.append(message)


func suite_name() -> String:
	return "player_copy"


func test_unreviewed_legacy_tags_do_not_generate_nutrition_claims() -> void:
	var original := _meal([Data.get_food("rice_plain"), Data.get_food("egg")])
	var injected := original.duplicate(true)
	injected["nutrient_tags"] = ["dietary_fiber_source", "calcium_source", "whole_grain", "high_quality_protein_source"]
	injected["limit_tags"] = ["high_sodium", "added_sugar", "fried"]
	injected["food_groups"] = ["vegetables", "fruits", "dairy", "soy_products"]
	var base_records: Array[Dictionary] = [original]
	var injected_records: Array[Dictionary] = [injected]
	var base := Ledger.summarize(base_records)
	var candidate := Ledger.summarize(injected_records)
	assert_eq(base["observation"], candidate["observation"])
	assert_eq(base["action"], candidate["action"])
	assert_eq(base["detail_text"], candidate["detail_text"])
	assert_eq(base["basis"], candidate["basis"])
	assert_eq(base, candidate)
	assert_false(candidate["metrics"].has("high_sodium_meals"))
	assert_contains(candidate["basis"], "尚未核对")


func test_partial_empty_and_all_skipped_records_are_reported_literally() -> void:
	var empty: Array[Dictionary] = []
	assert_contains(Ledger.summarize(empty)["observation"], "还没有确认")
	var partial: Array[Dictionary] = [_meal([Data.get_food("apple")])]
	assert_contains(Ledger.summarize(partial)["observation"], "已记下 1 餐")
	assert_false(Ledger.summarize(partial)["observation"].contains("三餐都"))
	var skipped: Array[Dictionary] = []
	for phase in ["breakfast", "lunch", "dinner"]:
		skipped.append(Resolver.build_skipped_record(phase))
	var view := Ledger.summarize(skipped)
	assert_contains(view["observation"], "三顿都没吃")
	assert_false(view["action"].contains("补回来"))
	assert_false(view["detail_text"].contains("高钠"))


func test_unrecorded_food_names_are_not_guessed_from_ids_or_tags() -> void:
	var meal := _meal([Data.get_food("apple")])
	meal.erase("food_names")
	var records: Array[Dictionary] = [meal]
	var view := Ledger.summarize(records)
	assert_contains(view["detail_text"], "食物名称未记")
	assert_false(view["detail_text"].contains("苹果"))


func test_ending_does_not_describe_skips_as_a_subset_of_eaten_meals() -> void:
	var view := Presenter.ending_text("barely_survived", [{"day": 1, "meals": [{"phase": "breakfast", "skipped": false, "food_names": ["白米饭"]}, {"phase": "lunch", "skipped": true}], "sleep": {"id": "scroll_phone"}}])
	assert_contains(view, "已确认 1 餐")
	assert_contains(view, "另外跳过了 1 餐")
	assert_false(view.contains("其中跳过"))
	assert_false(view.contains("0 次"))


func test_unreviewed_or_ambiguous_food_labels_and_bodily_claims_are_removed() -> void:
	assert_eq(Data.get_food("oatmeal")["kind"], "主食")
	assert_eq(Data.get_food("whole_wheat_bread")["kind"], "面包")
	assert_eq(Data.get_food("salad_bowl")["kind"], "沙拉")
	assert_false(Data.get_food("coffee")["desc"].contains("心跳"))
	assert_false(Data.get_food("egg")["desc"].contains("补上"))
	assert_false(Data.get_action("restock_pantry")["desc"].contains("直接吃"))


func test_card_details_keep_one_effect_heading_without_repeated_disclaimers() -> void:
	var game := GameScene.instantiate() as GameRootV2
	track(game)
	game.health_history_path = ""
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	for id in ["rice_plain", "coffee", "salad_bowl"]:
		game._show_detail(Data.get_food(id), Rect2(0, 0, 10, 10), true, "food")
		assert_eq(game.sticky_note.metric_heading.text, "游戏即时效果")
		assert_false(game.sticky_note.description_label.text.contains("不是营养或健康评价"))
		assert_false(game.sticky_note.recovery_section.visible)
	assert_false(Presenter.HELP.contains("限幅"))
	assert_contains(Presenter.HELP, "不用于判断真实健康")


func test_nonconsecutive_preferred_meals_and_final_day_budget_have_factual_copy() -> void:
	var game := RecordingGame.new()
	track(game)
	game.start_new_run()
	game.day = 7
	var records: Array[Dictionary] = []
	for phase in ["breakfast", "lunch", "dinner"]:
		var record := Resolver.build_record(phase, Data.get_meal_source("cafeteria"), [Data.get_food("rice_plain")])
		record["comfort"] = phase != "lunch"
		records.append(record)
	game.today_meal_records = records
	var mood: int = game.state["mood"]
	var stress: int = game.state["stress"]
	game._check_meal_combos(records.back())
	assert_eq(game.state["mood"], mood + 2)
	assert_eq(game.state["stress"], stress - 2)
	var text := "\n".join(game.messages)
	assert_contains(text, "已有两餐")
	assert_contains(text, "压力 -2")
	assert_false(text.contains("连续"))
	assert_false(text.contains("明天"))


func _meal(foods: Array[Dictionary]) -> Dictionary:
	return Resolver.build_record("breakfast", Data.get_meal_source("cafeteria"), foods)
