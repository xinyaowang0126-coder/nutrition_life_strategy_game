extends RefCounted

const VOICES := {
	"steady": "复习安排完了，今晚可以把书合上了。",
	"goal_gap": "这一周走完了，复习还差一点。",
	"reserve_gap": "复习到位了，收工时的余力不多了。",
	"study_gap": "这周先到这里，复习还没到原来的目标。",
	"campus_rest": "先停在这里，书可以下次再看。",
	"performed": "这回，歌唱完了。",
	"unready": "这次没上台，歌谱先收好。",
	"other_choice": "歌谱先收好，今晚另作安排。",
	"zhou_rest": "这几天先到这里，剩下的下次再排。",
	"legacy": "这一周，照留下的记录慢慢回看。",
}
const NEXT := {
	"study_time": "下周前几天先留一段复习，再看看日结进度是否跟上计划。",
	"study_day": "下一周第{day}天试着留一段餐后复习，再看目标还差多少。",
	"rest_day": "下一周第{day}天，试着把一段复习换成休息，再看余力变化。",
	"study_state": "下次开书前先看精力和压力，试着调整一段餐后安排。",
	"rest": "下次试着留一段休息，再看看日结的精力和余力。",
	"meals": "下次先为三餐留出安排，再排复习或休息。",
	"explore_source": "下一周换一顿用餐来源，比较这餐的花费和存粮取用。",
	"rehearse": "把一次补练放到第7天晚饭前，再核对排练进度。",
	"rehearsal_time": "下周把练歌分散到前几天，逐日核对排练进度。",
	"energy": "第7天午饭后试着留一段休息，晚饭后再核对精力。",
	"slots": "为第7天晚饭后的汇演留一个安排位。",
	"preflight": "第7天午饭后先核对排练和精力，再决定补练还是休息。",
	"own_choice": "下一周可以继续自己的安排，也可以试着在晚饭后上台。",
	"preparation": "下次先核对下一餐的人数和库存，再决定是否多做一份。",
	"menu": "换一个已开放的菜单练习，先核对实际份量。",
}
const CAMPUS_RULES := "本周复习目标：70。\n\n稳稳到了周末：\n复习至少70，且余力至少60。\n\n总算到了周末：\n复习至少50，且余力至少25。\n还未同时满足“稳稳”的两个条件。\n\n这次没赶上：\n复习不足50，余力高于15。\n\n先歇一会儿：\n连续两天日结余力不高于15，会提前结束。\n第7天余力不高于15；\n或者复习至少50、余力不足25。\n\n余力是游戏资源指标。"


static func voice(id: String) -> String:
	return String(VOICES.get(id, VOICES["legacy"]))


static func next_try(id: String, args: Dictionary = {}) -> String:
	return String(NEXT.get(id, NEXT["rest"])).format(args)
