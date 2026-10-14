class_name SharedMealPlan
extends RefCounted

var plan: Dictionary = {}
var history: Array[Dictionary] = []


func reset() -> void:
	plan.clear()
	history.clear()


func invite(day: int, venue: String) -> bool:
	if day not in [4, 5, 6] or venue not in ["home", "community"] or not plan.is_empty():
		return false
	plan = {"day": day, "meal": "dinner", "venue": venue, "companion_id": "chen_friend", "companion_name": "老陈", "status": "planned"}
	history.append({"kind": "invitation", "day": day, "plan": plan.duplicate(true)})
	return true


func matches(day: int, phase: String, source: String) -> bool:
	if plan.get("status") != "planned" or plan.get("day") != day or phase != "dinner":
		return false
	return (plan["venue"] == "home" and source == "home_kitchen") or (plan["venue"] == "community" and source == "community_canteen")


func complete(day: int, meal: Dictionary) -> bool:
	if not meal.get("food_ids") is Array or meal["food_ids"].is_empty():
		return false
	if bool(meal.get("skipped", false)) or not matches(day, String(meal.get("phase", "")), String(meal.get("source_id", ""))):
		return false
	plan["status"] = "completed"
	meal["companions"] = [{"id": plan["companion_id"], "name": plan["companion_name"]}]
	history.append({"kind": "shared_meal", "day": day, "venue": plan["venue"], "food_names": meal.get("food_names", []).duplicate(), "companions": meal["companions"].duplicate(true)})
	return true


func finish_day(day: int) -> void:
	if plan.get("status") == "planned" and plan.get("day") == day:
		plan["status"] = "missed"
		history.append({"kind": "missed", "day": day, "plan": plan.duplicate(true)})
		plan.clear()


func summary() -> String:
	if plan.get("status") == "planned":
		return "晚饭约好了：%s和老陈见。接下来准备晚饭。" % ("在家里" if plan["venue"] == "home" else "在社区食堂")
	for entry in history:
		if entry.get("kind") == "shared_meal":
			return "第%d天和老陈一起吃了晚饭。" % int(entry["day"])
	return "这周还没有共同进餐记录。"
