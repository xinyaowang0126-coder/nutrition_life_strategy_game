@tool
extends McpTestSuite

const Carryover := preload("res://scripts/systems/DayCarryoverService.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Data := preload("res://scripts/GameData.gd")


func suite_name() -> String:
	return "day_carryover"


func test_early_sleep_record_supplies_the_frozen_study_bonus() -> void:
	var record := _record("sleep_early", 45, 45)
	var frozen := record.duplicate(true)
	var prepared := Carryover.from_recovery(record, 1)
	assert_true(prepared["valid"])
	assert_eq(prepared["learning_state"]["id"], "clear_focus")
	assert_eq(prepared["learning_state"]["study_modifier"], 3)
	assert_eq(prepared["learning_state"]["opening_delta"], {"energy": 3, "mood": 1, "stress": -2})
	assert_eq(record, frozen)


func test_phone_record_can_be_neutral_without_a_food_gate() -> void:
	var prepared := Carryover.from_recovery(_record("scroll_phone", 65, 45), 1)
	assert_true(prepared["valid"])
	assert_eq(prepared["learning_state"]["id"], "steady")
	assert_eq(prepared["learning_state"]["study_modifier"], 0)
	assert_true(prepared["learning_state"]["opening_delta"].is_empty())


func test_late_study_record_preserves_the_frozen_penalty() -> void:
	var prepared := Carryover.from_recovery(_record("night_study", 80, 40), 1)
	assert_true(prepared["valid"])
	assert_eq(prepared["learning_state"]["id"], "fatigued")
	assert_eq(prepared["learning_state"]["study_modifier"], -2)
	assert_eq(prepared["learning_state"]["opening_delta"], {"energy": -2, "stress": 2})


func test_depleted_record_has_the_frozen_severe_effect() -> void:
	var prepared := Carryover.from_recovery(_record("scroll_phone", 20, 95), 1)
	assert_true(prepared["valid"])
	assert_eq(prepared["learning_state"]["id"], "brain_fog")
	assert_eq(prepared["learning_state"]["study_modifier"], -4)
	assert_eq(prepared["learning_state"]["opening_delta"], {"energy": -3, "mood": -2, "stress": 3})


func test_diet_metrics_are_not_an_accepted_carryover_record() -> void:
	for data in [{"metrics": {"skipped_meals": 1}}, {"diet_burden": 0}, {"food_ids": ["greens"]}, {"energy": 70, "stress": 40}]:
		var prepared := Carryover.from_recovery(data, 1)
		assert_false(prepared["valid"])
		assert_false(prepared["learning_state"].has("study_modifier"))
	assert_false(Carryover.from_recovery(_record("sleep_early", 45, 45), 2)["valid"])


func _record(id: String, energy: int, stress: int) -> Dictionary:
	var card := Data.get_sleep_option(id)
	var snapshot := {"id": id}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		snapshot[key] = card[key]
	return Recovery.settle(1, {"energy": energy, "stress": stress}, snapshot, {})["recovery_state"]
