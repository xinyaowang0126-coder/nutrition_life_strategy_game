class_name WeeklyEventService
extends RefCounted

## Deterministic, side-effect-free rules for the seven-day event schedule.
## Callers keep ownership of every dictionary passed in; all returned values
## are deep copies and can be safely adapted for UI or run-state integration.

const EVENTS_BY_DAY := {
	2: {
		"id": "clear_skies",
		"day": 2,
		"title": "天气放晴",
		"summary": "风不大，校园里适合走一走。",
		"preview": "明天天气放晴，散步会比平时更解压。",
		"tone": "good",
		"opening_delta": {"mood": 3, "stress": -2},
		"source_deltas": {},
		"action_deltas": {
			"walk": {"mood": 2, "stress": -2},
		},
	},
	3: {
		"id": "cafeteria_rotation",
		"day": 3,
		"title": "食堂换菜单",
		"summary": "窗口多开了几样菜，今天更容易配齐一餐。",
		"preview": "明天食堂换菜单，可看到的菜会更多。",
		"tone": "good",
		"opening_delta": {},
		"source_deltas": {
			"cafeteria": {"hand_size": 2},
		},
		"action_deltas": {},
	},
	4: {
		"id": "delivery_coupon",
		"day": 4,
		"title": "外卖优惠券",
		"summary": "手机里多了一张配送券，外卖暂时没那么贵。",
		"preview": "明天有一张外卖券，配送费会降低，菜单也会多一项。",
		"tone": "info",
		"opening_delta": {},
		"source_deltas": {
			"takeout": {"fee": -2, "hand_size": 1},
		},
		"action_deltas": {},
	},
	5: {
		"id": "mock_exam_notice",
		"day": 5,
		"title": "小测提醒",
		"summary": "群里发来了小测范围，复习更有方向，也更费神。",
		"preview": "明天会公布小测范围：复习收益提高，但会更累、更紧张。",
		"tone": "warning",
		"opening_delta": {"stress": 4},
		"source_deltas": {},
		"action_deltas": {
			"study": {"energy": -2, "stress": 1, "study": 3},
		},
	},
	6: {
		"id": "rainy_day",
		"day": 6,
		"title": "下了一整天雨",
		"summary": "天色一直发灰，出门和点外卖都没有平时轻松。",
		"preview": "明天有雨：外卖配送费上涨，散步的恢复效果也会变弱。",
		"tone": "warning",
		"opening_delta": {"mood": -2, "stress": 2},
		"source_deltas": {
			"takeout": {"fee": 2},
		},
		"action_deltas": {
			"walk": {"energy": -2, "mood": -2, "stress": 3},
		},
	},
}

const BOUNDED_STATE_KEYS := [
	"stability",
	"energy",
	"mood",
	"satiety",
	"stress",
	"diet_burden",
	"study_progress",
]
const ZERO_MINIMUM_KEYS := ["balance", "fee", "cost"]
const ONE_MINIMUM_KEYS := ["hand_size", "selection_limit", "slots"]


static func event_for_day(day: int) -> Dictionary:
	var event: Dictionary = EVENTS_BY_DAY.get(day, {})
	return event.duplicate(true)


static func apply_opening_state(day: int, state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	var event := event_for_day(day)
	var delta: Dictionary = event.get("opening_delta", {})
	_apply_numeric_delta(result, delta, true)
	return result


static func apply_meal_source(day: int, source_id: String, source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var event := event_for_day(day)
	var by_source: Dictionary = event.get("source_deltas", {})
	var delta: Dictionary = by_source.get(source_id, {})
	_apply_numeric_delta(result, delta)
	return result


static func apply_action(day: int, action_id: String, action: Dictionary) -> Dictionary:
	var result := action.duplicate(true)
	var event := event_for_day(day)
	var by_action: Dictionary = event.get("action_deltas", {})
	var delta: Dictionary = by_action.get(action_id, {})
	_apply_numeric_delta(result, delta)
	return result


static func next_day_preview(current_day: int, total_days: int = 7) -> Dictionary:
	var next_day := current_day + 1
	if next_day > total_days:
		return {}
	var event := event_for_day(next_day)
	if event.is_empty():
		return {
			"day": next_day,
			"has_event": false,
			"event_id": "",
			"title": "照常安排",
			"summary": "明天没有额外变化，按自己的节奏来。",
			"tone": "info",
		}
	return {
		"day": next_day,
		"has_event": true,
		"event_id": String(event["id"]),
		"title": String(event["title"]),
		"summary": String(event["preview"]),
		"tone": String(event.get("tone", "info")),
	}


static func _apply_numeric_delta(target: Dictionary, delta: Dictionary, clamp_state: bool = false) -> void:
	for raw_key in delta:
		var key := String(raw_key)
		var value := int(target.get(key, 0)) + int(delta[raw_key])
		if clamp_state and BOUNDED_STATE_KEYS.has(key):
			value = clampi(value, 0, 100)
		elif ZERO_MINIMUM_KEYS.has(key):
			value = maxi(0, value)
		elif ONE_MINIMUM_KEYS.has(key):
			value = maxi(1, value)
		target[key] = value
