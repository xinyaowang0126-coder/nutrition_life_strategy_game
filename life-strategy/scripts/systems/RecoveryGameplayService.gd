class_name RecoveryGameplayService
extends RefCounted

## Consumes frozen, versioned records. Never reevaluates past recovery inputs.
const StateService := preload("res://scripts/systems/RecoveryStateService.gd")
const Rules := preload("res://scripts/systems/RecoveryRules.gd")
const Reserve := preload("res://scripts/systems/GameReserveCalculator.gd")
const CONTRIBUTIONS := {"rested": 10, "steady": 7, "strained": 4, "depleted": 1}
const LEARNING_IDS := {"rested": "clear_focus", "steady": "steady", "strained": "fatigued", "depleted": "brain_fog"}
const TITLES := {"rested": "恢复充分", "steady": "状态照常", "strained": "有些疲惫", "depleted": "需要缓缓"}
const SUMMARIES := {
	"rested": "按游戏规则，昨晚的休息、实际精力与压力支持了今天的复习加成。",
	"steady": "按游戏规则，昨晚的恢复记录没有触发额外复习加成或减益。",
	"strained": "按游戏规则，昨晚的精力、压力或安排触发了轻度复习减益。",
	"depleted": "按游戏规则，昨晚的精力、压力或安排触发了较大复习减益。",
}


static func prepare_day(record: Variant, expected_day: Variant) -> Dictionary:
	var errors := _record_errors(record)
	if not Rules.is_integer(expected_day) or expected_day < 0 or expected_day > 6:
		errors.append("expected_day: expected integer 0..6")
	if errors.is_empty():
		if expected_day == 0:
			if record["origin"] != "new_run_default":
				errors.append("first day requires the explicit new-run default")
		elif record["origin"] != "day_settlement" or record["evaluated_day"] != expected_day:
			errors.append("recovery record does not belong to the previous day")
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "recovery_state": null, "learning_state": unavailable_learning_state()}
	var frozen := StateService.normalize(record)
	return {"valid": true, "errors": [], "recovery_state": frozen, "learning_state": _learning_state(frozen)}


static func learning_state(record: Variant) -> Dictionary:
	var errors := _record_errors(record)
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "learning_state": unavailable_learning_state()}
	return {"valid": true, "errors": [], "learning_state": _learning_state(StateService.normalize(record))}


static func unavailable_learning_state() -> Dictionary:
	# No modifier/delta: an unavailable record is not a neutral consumable day.
	return {"id": "recovery_unavailable", "title": "恢复记录暂时不可用", "summary": "这一天的恢复记录无法使用，请通过菜单重新开始这一周。"}


## Current gameplay reads recovery and resources; legacy meal scores are not inputs.
static func calculate_stability_from_recovery(state: Variant, day: Variant, total_days: Variant, record: Variant) -> Dictionary:
	var errors := _record_errors(record)
	if not state is Dictionary:
		errors.append("state: expected dictionary")
	else:
		for key in ["energy", "mood", "stress", "satiety", "study_progress", "balance"]:
			var value: Variant = state.get(key)
			var maximum := 999 if key == "balance" else 100
			if not Rules.is_integer(value) or value < 0 or value > maximum:
				errors.append("state.%s: invalid gameplay value" % key)
	if not Rules.is_integer(total_days) or total_days != 7 or not Rules.is_integer(day) or day < 1 or day > 7:
		errors.append("day: expected a day within the seven-day run")
	if not errors.is_empty():
		return {"valid": false, "errors": errors, "stability": null}
	return {
		"valid": true, "errors": [],
		"stability": Reserve.calculate(state, int(day), int(total_days), float(CONTRIBUTIONS[record["condition"]])),
	}


## Deprecated compatibility signature. The legacy argument is validated only.
static func calculate_stability(state: Variant, quality: Variant, day: Variant, total_days: Variant, record: Variant) -> Dictionary:
	var result := calculate_stability_from_recovery(state, day, total_days, record)
	if not Rules.is_integer(quality) or quality < 0 or quality > 100:
		result["errors"].append("quality: invalid legacy gameplay input")
		result["valid"] = false
		result["stability"] = null
	return result


static func _record_errors(record: Variant) -> Array[String]:
	var validation := StateService.validate(record)
	var errors: Array[String] = []
	errors.append_array(validation["errors"])
	if validation["valid"] and (record["status"] != "known" or not CONTRIBUTIONS.has(record["condition"])):
		errors.append("recovery record is unavailable for gameplay")
	return errors


static func _learning_state(record: Dictionary) -> Dictionary:
	var condition: String = record["condition"]
	var effect: Dictionary = record["next_day_effect"]
	return {
		"id": LEARNING_IDS[condition], "title": TITLES[condition], "summary": SUMMARIES[condition],
		"study_modifier": effect["study_modifier"], "opening_delta": effect["opening_delta"].duplicate(true),
	}
