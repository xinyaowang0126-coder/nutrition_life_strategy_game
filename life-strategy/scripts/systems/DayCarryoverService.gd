class_name DayCarryoverService
extends RefCounted

## Builds one deterministic next-day condition from the previous day's
## nutrition summary, actions, sleep choice, and final state. The returned
## study_modifier is a flat adjustment intended for the next day's study
## action; opening_delta can be applied once when that day starts.

const CLEAR_FOCUS := {
	"id": "clear_focus",
	"title": "进入状态较快",
	"summary": "按游戏规则，昨日的进餐记录、较早休息和收尾状态共同触发了今日复习加成。",
	"study_modifier": 3,
	"opening_delta": {"energy": 3, "mood": 1, "stress": -2},
}
const STEADY := {
	"id": "steady",
	"title": "状态照常",
	"summary": "按游戏规则，昨日记录没有触发额外的复习加成或减益。",
	"study_modifier": 0,
	"opening_delta": {},
}
const FATIGUED := {
	"id": "fatigued",
	"title": "进入状态较慢",
	"summary": "按游戏规则，昨日的精力、压力、作息或安排触发了轻度复习减益。",
	"study_modifier": -2,
	"opening_delta": {"energy": -2, "stress": 2},
}
const BRAIN_FOG := {
	"id": "brain_fog",
	"title": "需要先缓一缓",
	"summary": "按游戏规则，昨日多项状态同时触发了较大复习减益；这不是医学判断。",
	"study_modifier": -4,
	"opening_delta": {"energy": -3, "mood": -2, "stress": 3},
}


static func evaluate_day(
	nutrition_summary: Dictionary,
	action_records: Array,
	sleep_id: String,
	end_state: Dictionary
) -> Dictionary:
	var metrics: Dictionary = nutrition_summary.get("metrics", nutrition_summary)
	var skipped := int(metrics.get("skipped_meals", 0))
	var eaten := int(metrics.get("eaten_meals", maxi(0, 3 - skipped)))
	var grain_meals := int(metrics.get("grain_meals", 0))
	var vegetable_meals := int(metrics.get("vegetable_meals", 0))
	var protein_meals := int(metrics.get("high_quality_protein_meals", 0))
	var limited_meals := (
		int(metrics.get("added_sugar_meals", 0))
		+ int(metrics.get("high_sodium_meals", 0))
		+ int(metrics.get("fried_meals", 0))
	)

	var energy := int(end_state.get("energy", 50))
	var mood := int(end_state.get("mood", 50))
	var stress := int(end_state.get("stress", 50))
	var satiety := int(end_state.get("satiety", 50))
	var burden := int(end_state.get("diet_burden", end_state.get("burden", 0)))
	var action_counts := _count_actions(action_records)
	var study_count := int(action_counts.get("study", 0))
	var recovery_count := (
		int(action_counts.get("nap", 0))
		+ int(action_counts.get("walk", 0))
		+ int(action_counts.get("allow_imperfection", 0))
	)

	var regular_meals := skipped == 0 and eaten >= 3
	var supportive_meals := grain_meals >= 2 and vegetable_meals >= 1 and protein_meals >= 1
	var nutrition_strain := skipped >= 1 or eaten < 3 or limited_meals >= 3
	var overworked := study_count >= 3 and recovery_count == 0
	var late_night := sleep_id == "night_study"
	var slept_early := sleep_id == "sleep_early"

	var severe_strain := (
		energy <= 22
		or stress >= 82
		or satiety <= 12
		or burden >= 82
		or skipped >= 2
	)
	var compounded_strain := (
		(nutrition_strain and late_night)
		or (overworked and energy < 35)
		or (stress >= 75 and energy < 35)
	)
	if severe_strain or compounded_strain:
		return BRAIN_FOG.duplicate(true)

	var tired := (
		late_night
		or energy < 42
		or stress >= 66
		or satiety < 24
		or burden >= 68
		or overworked
		or (nutrition_strain and not slept_early)
	)
	if tired:
		return FATIGUED.duplicate(true)

	var clear := (
		slept_early
		and regular_meals
		and supportive_meals
		and limited_meals <= 1
		and energy >= 58
		and mood >= 45
		and stress <= 52
		and burden <= 55
		and not overworked
	)
	if clear:
		return CLEAR_FOCUS.duplicate(true)

	return STEADY.duplicate(true)


static func _count_actions(action_records: Array) -> Dictionary:
	var counts := {}
	for record in action_records:
		var action_id := ""
		if record is Dictionary:
			var data := record as Dictionary
			action_id = String(data.get("id", data.get("action_id", "")))
		else:
			action_id = String(record)
		if action_id.is_empty():
			continue
		counts[action_id] = int(counts.get(action_id, 0)) + 1
	return counts
