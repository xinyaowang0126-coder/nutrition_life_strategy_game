@tool
extends McpTestSuite

const DayCarryoverServiceScript := preload("res://scripts/systems/DayCarryoverService.gd")


func suite_name() -> String:
	return "day_carryover"


func test_early_sleep_and_supportive_meals_create_clear_focus() -> void:
	var nutrition := _nutrition({
		"eaten_meals": 3,
		"skipped_meals": 0,
		"grain_meals": 3,
		"vegetable_meals": 2,
		"high_quality_protein_meals": 2,
		"added_sugar_meals": 0,
		"high_sodium_meals": 0,
		"fried_meals": 0,
	})
	var actions := [{"id": "study"}, {"id": "walk"}]
	var state := {"energy": 72, "mood": 62, "stress": 34, "satiety": 61, "diet_burden": 24}
	var result: Dictionary = DayCarryoverServiceScript.evaluate_day(nutrition, actions, "sleep_early", state)
	assert_eq(String(result["id"]), "clear_focus")
	assert_eq(int(result["study_modifier"]), 3)
	assert_eq(int((result["opening_delta"] as Dictionary)["energy"]), 3)
	assert_eq(int((result["opening_delta"] as Dictionary)["stress"]), -2)
	assert_contains(String(result["summary"]), "复习")
	assert_eq(int(state["energy"]), 72, "evaluation must not mutate the end state")


func test_stable_day_has_no_study_adjustment() -> void:
	var nutrition := _nutrition({
		"eaten_meals": 3,
		"skipped_meals": 0,
		"grain_meals": 2,
		"vegetable_meals": 1,
		"high_quality_protein_meals": 1,
		"added_sugar_meals": 1,
		"high_sodium_meals": 1,
		"fried_meals": 0,
	})
	var result: Dictionary = DayCarryoverServiceScript.evaluate_day(
		nutrition,
		["study", "walk"],
		"scroll_phone",
		{"energy": 58, "mood": 58, "stress": 48, "satiety": 52, "diet_burden": 38}
	)
	assert_eq(String(result["id"]), "steady")
	assert_eq(int(result["study_modifier"]), 0)
	assert_true((result["opening_delta"] as Dictionary).is_empty())


func test_late_night_or_overwork_creates_fatigue_penalty() -> void:
	var nutrition := _nutrition({
		"eaten_meals": 3,
		"skipped_meals": 0,
		"grain_meals": 3,
		"vegetable_meals": 2,
		"high_quality_protein_meals": 2,
	})
	var result: Dictionary = DayCarryoverServiceScript.evaluate_day(
		nutrition,
		[{"action_id": "study"}, {"action_id": "study"}, {"action_id": "study"}],
		"night_study",
		{"energy": 45, "mood": 50, "stress": 60, "satiety": 45, "diet_burden": 35}
	)
	assert_eq(String(result["id"]), "fatigued")
	assert_eq(int(result["study_modifier"]), -2)
	assert_eq(int((result["opening_delta"] as Dictionary)["energy"]), -2)
	assert_eq(int((result["opening_delta"] as Dictionary)["stress"]), 2)


func test_compounded_sleep_meal_and_state_strain_creates_brain_fog() -> void:
	var nutrition := _nutrition({
		"eaten_meals": 1,
		"skipped_meals": 2,
		"grain_meals": 0,
		"vegetable_meals": 0,
		"high_quality_protein_meals": 0,
		"high_sodium_meals": 1,
	})
	var result: Dictionary = DayCarryoverServiceScript.evaluate_day(
		nutrition,
		["study", "study", "study"],
		"night_study",
		{"energy": 18, "mood": 31, "stress": 84, "satiety": 10, "diet_burden": 73}
	)
	assert_eq(String(result["id"]), "brain_fog")
	assert_eq(int(result["study_modifier"]), -4)
	assert_eq(int((result["opening_delta"] as Dictionary)["energy"]), -3)
	assert_eq(int((result["opening_delta"] as Dictionary)["mood"]), -2)
	assert_eq(int((result["opening_delta"] as Dictionary)["stress"]), 3)


func test_meal_regularness_changes_next_day_result() -> void:
	var healthy_state := {"energy": 65, "mood": 58, "stress": 44, "satiety": 50, "diet_burden": 30}
	var complete := _nutrition({
		"eaten_meals": 3,
		"skipped_meals": 0,
		"grain_meals": 3,
		"vegetable_meals": 2,
		"high_quality_protein_meals": 2,
	})
	var missed := _nutrition({
		"eaten_meals": 2,
		"skipped_meals": 1,
		"grain_meals": 1,
		"vegetable_meals": 1,
		"high_quality_protein_meals": 1,
	})
	var clear: Dictionary = DayCarryoverServiceScript.evaluate_day(complete, ["walk"], "sleep_early", healthy_state)
	var no_bonus: Dictionary = DayCarryoverServiceScript.evaluate_day(missed, ["walk"], "sleep_early", healthy_state)
	assert_eq(String(clear["id"]), "clear_focus")
	assert_eq(String(no_bonus["id"]), "steady")
	assert_gt(int(clear["study_modifier"]), int(no_bonus["study_modifier"]))


func _nutrition(metrics: Dictionary) -> Dictionary:
	return {"metrics": metrics.duplicate(true)}
