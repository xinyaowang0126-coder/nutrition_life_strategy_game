extends RefCounted

const VOICES := {
	"steady": "复习完了。",
	"goal_gap": "一周过去，还是差了点。",
	"reserve_gap": "复习完了，余力也剩得不多了。",
	"study_gap": "没复习完，下回得重新排时间。",
	"campus_rest": "先休息，复习下次再说。",
	"performed": "总算唱完了。",
	"unready": "这次没赶上，下回早点准备。",
	"other_choice": "今晚就不去唱了。",
	"zhou_rest": "今天先不练了。",
	"legacy": "看看这周都做了什么。",
}
const NEXT := {
	"study_time": "前几天多排几次复习。",
	"study_day": "第{day}天加一次餐后复习。",
	"rest_day": "第{day}天，把一段复习换成休息。",
	"study_state": "精力低或压力高时，先休息再复习。",
	"rest": "给休息留一个安排位。",
	"meals": "先安排三餐，再排其他事情。",
	"explore_source": "下周换个地方吃一顿。",
	"rehearse": "第7天晚饭前，再练一次歌。",
	"rehearsal_time": "前几天多排几次练歌。",
	"energy": "第7天午饭后休息，给汇演留够精力。",
	"slots": "第7天晚饭后，留一个安排位给汇演。",
	"preflight": "第7天午饭后，看看还要补练还是休息。",
	"own_choice": "下周也可以试试参加汇演。",
	"preparation": "做饭前先数数有几个人、家里还有什么。",
	"menu": "换道题，再试一次。",
}
const CAMPUS_RULES := "本周复习目标：70。\n\n稳稳到了周末：\n复习至少70，余力至少60。\n\n总算到了周末：\n复习至少50，余力至少25，\n但还没同时达到上面两个条件。\n\n这次没赶上：\n复习不足50，余力高于15。\n\n先歇一会儿：\n连续两天日结余力不高于15，提前结束。\n第7天余力不高于15，\n或复习至少50、余力不足25，也会结束。"


static func voice(id: String) -> String:
	return String(VOICES.get(id, VOICES["legacy"]))


static func next_try(id: String, args: Dictionary = {}) -> String:
	return String(NEXT.get(id, NEXT["rest"])).format(args)


static func household_review(stored: Dictionary) -> Array[Dictionary]:
	# v1 saves validate their frozen review verbatim. Present current copy from
	# its validated counters so wording changes do not invalidate those saves.
	var counts: Dictionary = stored.get("counts", {})
	if counts.is_empty(): return []
	var rows: Array[Dictionary] = [
		{"title": "这周的饭" if int(counts["days"]) >= 7 else "这几天的饭", "text": "%d天里吃了%d餐，跳过%d餐。" % [counts["days"], counts["meals"], counts["skipped"]]},
	]
	if counts["opening_discarded"] > 0:
		rows.append({"title": "开局那盘菜", "text": "丢掉了开局那盘保存不当的青菜。"})
	if counts["attempted_contexts"] > 0:
		var text := "做了%d组练习。" % counts["attempted_contexts"]
		if counts["first_correct"] > 0: text += "%d组首次独立答对。" % counts["first_correct"]
		if counts["retries"] > 0: text += "重试了%d次。" % counts["retries"]
		rows.append({"title": "选餐和标签", "text": text})
	if counts["shared"] > 0:
		rows.append({"title": "和老陈吃饭", "text": "一起吃了%d顿晚饭。" % counts["shared"]})
	if counts["prepared_items"] > 0 or counts["reheated_items"] > 0:
		rows.append({"title": "冷藏备餐", "text": "另留了%d样冷藏熟食，取用并再热了%d样。" % [counts["prepared_items"], counts["reheated_items"]]})
	if counts["counter_items"] > 0:
		rows.append({"title": "留在灶台的菜", "text": "%d样熟食选择留在灶台，没有冷藏。" % counts["counter_items"]})
	return rows
