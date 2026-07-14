@tool
extends McpTestSuite

const WeeklyEventServiceScript := preload("res://scripts/systems/WeeklyEventService.gd")


func suite_name() -> String:
	return "weekly_events"


func test_schedule_is_deterministic_and_covers_days_two_through_six() -> void:
	var ids := {}
	for day in range(2, 7):
		var event: Dictionary = WeeklyEventServiceScript.event_for_day(day)
		assert_false(event.is_empty(), "day %d should have a scheduled event" % day)
		assert_eq(int(event["day"]), day)
		ids[String(event["id"])] = true
	assert_eq(ids.size(), 5, "every scheduled day should use a distinct event")
	assert_true(WeeklyEventServiceScript.event_for_day(1).is_empty())
	assert_true(WeeklyEventServiceScript.event_for_day(7).is_empty())

	var edited := WeeklyEventServiceScript.event_for_day(2)
	var edited_delta: Dictionary = edited["opening_delta"]
	edited_delta["mood"] = 99
	var fresh := WeeklyEventServiceScript.event_for_day(2)
	assert_eq(int((fresh["opening_delta"] as Dictionary)["mood"]), 3, "event data must be returned as a deep copy")


func test_opening_state_is_applied_without_mutating_or_overflowing_input() -> void:
	var state := {
		"energy": 52,
		"mood": 99,
		"stress": 1,
		"balance": 120,
	}
	var result: Dictionary = WeeklyEventServiceScript.apply_opening_state(2, state)
	assert_eq(int(result["mood"]), 100)
	assert_eq(int(result["stress"]), 0)
	assert_eq(int(result["energy"]), 52)
	assert_eq(int(state["mood"]), 99, "the caller's state must remain unchanged")
	assert_eq(int(state["stress"]), 1)

	var exam_result := WeeklyEventServiceScript.apply_opening_state(5, {"stress": 98})
	assert_eq(int(exam_result["stress"]), 100)


func test_meal_source_modifiers_are_targeted_and_pure() -> void:
	var cafeteria := {"id": "cafeteria", "fee": 0, "hand_size": 6}
	var cafeteria_event: Dictionary = WeeklyEventServiceScript.apply_meal_source(3, "cafeteria", cafeteria)
	assert_eq(int(cafeteria_event["hand_size"]), 8)
	assert_eq(int(cafeteria["hand_size"]), 6)

	var takeout := {"id": "takeout", "fee": 3, "hand_size": 4}
	var coupon_result: Dictionary = WeeklyEventServiceScript.apply_meal_source(4, "takeout", takeout)
	assert_eq(int(coupon_result["fee"]), 1)
	assert_eq(int(coupon_result["hand_size"]), 5)
	assert_eq(int(takeout["fee"]), 3, "the source template must remain unchanged")

	var unrelated: Dictionary = WeeklyEventServiceScript.apply_meal_source(4, "cafeteria", cafeteria)
	assert_eq(unrelated, cafeteria, "an event must not leak onto another source")
	var rainy_takeout: Dictionary = WeeklyEventServiceScript.apply_meal_source(6, "takeout", takeout)
	assert_eq(int(rainy_takeout["fee"]), 5)


func test_action_modifiers_create_predictable_tradeoffs() -> void:
	var walk := {"id": "walk", "energy": -3, "mood": 3, "stress": -6, "slots": 1}
	var sunny_walk: Dictionary = WeeklyEventServiceScript.apply_action(2, "walk", walk)
	assert_eq(int(sunny_walk["energy"]), -3)
	assert_eq(int(sunny_walk["mood"]), 5)
	assert_eq(int(sunny_walk["stress"]), -8)
	assert_eq(int(walk["mood"]), 3, "the action template must remain unchanged")

	var study := {"id": "study", "energy": -8, "stress": 3, "study": 10, "slots": 1}
	var focused_study: Dictionary = WeeklyEventServiceScript.apply_action(5, "study", study)
	assert_eq(int(focused_study["energy"]), -10)
	assert_eq(int(focused_study["stress"]), 4)
	assert_eq(int(focused_study["study"]), 13)

	var rainy_walk: Dictionary = WeeklyEventServiceScript.apply_action(6, "walk", walk)
	assert_eq(int(rainy_walk["energy"]), -5)
	assert_eq(int(rainy_walk["mood"]), 1)
	assert_eq(int(rainy_walk["stress"]), -3)
	var unrelated: Dictionary = WeeklyEventServiceScript.apply_action(5, "nap", {"id": "nap", "energy": 14})
	assert_eq(int(unrelated["energy"]), 14)


func test_next_day_preview_reports_events_and_quiet_days() -> void:
	var day_two_preview: Dictionary = WeeklyEventServiceScript.next_day_preview(1)
	assert_true(bool(day_two_preview["has_event"]))
	assert_eq(int(day_two_preview["day"]), 2)
	assert_eq(String(day_two_preview["event_id"]), "clear_skies")
	assert_contains(String(day_two_preview["summary"]), "散步")

	var rainy_preview: Dictionary = WeeklyEventServiceScript.next_day_preview(5)
	assert_true(bool(rainy_preview["has_event"]))
	assert_eq(String(rainy_preview["event_id"]), "rainy_day")
	assert_eq(String(rainy_preview["tone"]), "warning")

	var quiet_preview: Dictionary = WeeklyEventServiceScript.next_day_preview(6)
	assert_false(bool(quiet_preview["has_event"]))
	assert_eq(int(quiet_preview["day"]), 7)
	assert_eq(String(quiet_preview["event_id"]), "")
	assert_true(WeeklyEventServiceScript.next_day_preview(7).is_empty())
