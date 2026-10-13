class_name GameplayBalanceRules
extends RefCounted

## Fictional resource rules, separate from food composition and health data.
## One period passes after a main action or a skip, never after drinking water.
const VERSION := "campus-balance-v2"
const PERIOD_DELTA := {"energy": -8, "satiety": -20, "stress": 2}
const PERIOD_HINT := "时段结束：精力 -8、饱腹 -20、压力 +2；不再安排也会经过这段时间。"


static func period_delta() -> Dictionary:
	return PERIOD_DELTA.duplicate(true)


static func study_penalty(state: Dictionary) -> Dictionary:
	var modifier := 0
	var reasons: Array[String] = []
	if int(state.get("energy", 0)) < 25:
		modifier -= 3
		reasons.append("精力偏低")
	if int(state.get("stress", 0)) >= 70:
		modifier -= 2
		reasons.append("压力偏高")
	if int(state.get("satiety", 0)) < 20:
		modifier -= 2
		reasons.append("饱腹偏低")
	return {"modifier": modifier, "reasons": reasons}
