class_name HealthGuidancePresenter
extends RefCounted

## Read-only view models. No live card lookup and no gameplay mutations.
const Composer := preload("res://scripts/health/GuidanceComposer.gd")
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Snapshot := preload("res://scripts/health/MealHealthSnapshot.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const PHASE_NAMES := {"breakfast": "早饭", "lunch": "午饭", "dinner": "晚饭"}


static func meal_view(snapshot: Variant, config: Variant, registry: Evidence, date: String, copies: Variant) -> Dictionary:
	var composed := Composer.compose_meal(snapshot, config, registry, date, copies)
	var view := {"valid": composed["valid"], "text": composed["primary"]["text"], "ingredients": [], "details": [], "portion_text": "", "data_note": "", "nutrition_allowed": composed["copy_allowed"] and composed["primary"]["kind"] == "nutrition_observation", "basis_text": "配料和份量分开看。知道有什么，不等于知道吃了多少。", "copy_id": composed["primary"]["id"]}
	if not view["nutrition_allowed"]:
		return view
	var evaluation: Dictionary = composed["evaluation"]
	if not evaluation["data_quality"]["unknown_portion_food_ids"].is_empty():
		view["portion_text"] = "份量未标"
	if evaluation["dimensions"]["plate_structure"]["status"] == "partial":
		view["data_note"] = "配料不全"
	for group in Composer.LABELS:
		for ingredient in evaluation["ingredients"]:
			if ingredient["food_group"] != group or Config.CONFIDENCE[ingredient["confidence"]] < 2:
				continue
			var source: String = ingredient["selected_food_id"]
			var name := ""
			for component in snapshot["profile_snapshots"][source]["components"]:
				if component["ingredient_id"] == ingredient["ingredient_id"]:
					name = String(component["name"]).strip_edges()
					break
			if name.is_empty():
				continue
			var row := {"id": ingredient["ingredient_id"], "name": name, "band": ingredient["contribution_band"]}
			view["details"].append(row.duplicate(true))
			if Config.BANDS[ingredient["contribution_band"]] >= 2:
				view["ingredients"].append(row.duplicate(true))
	return view


static func capture_record(day: int, game_record: Dictionary, catalog: Dictionary, config: Dictionary, registry: Evidence, date: String, copies: Dictionary) -> Dictionary:
	var snapshot := Snapshot.build(day, game_record, catalog)
	return {"phase": game_record.get("phase", ""), "skipped": game_record.get("skipped", false), "food_names": game_record.get("food_names", []).duplicate(), "food_ids": game_record.get("food_ids", []).duplicate(), "source_name": game_record.get("source_name", ""), "spent": game_record.get("total_cost", 0), "health_snapshot": snapshot.duplicate(true), "meal_view": meal_view(snapshot, config, registry, date, copies).duplicate(true)}


static func diary_view(records: Array) -> Dictionary:
	var rows: Array[Dictionary] = []
	var skipped_names: Array[String] = []
	var ingredient_meals := {}
	var spent := 0
	var eaten := 0
	for record in records:
		var phase: String = record.get("phase", "")
		if not PHASE_NAMES.has(phase):
			continue
		var skipped: bool = record.get("skipped", false)
		var names: Array = record.get("food_names", [])
		rows.append({"phase": phase, "title": PHASE_NAMES[phase], "text": "没吃" if skipped else ("、".join(names) if not names.is_empty() else "名字没记下")})
		spent += int(record.get("spent", 0))
		if skipped:
			skipped_names.append(PHASE_NAMES[phase])
			continue
		eaten += 1
		var meal: Dictionary = record.get("meal_view", {})
		if not meal.get("nutrition_allowed", false):
			continue
		var seen := {}
		for ingredient in meal.get("ingredients", []):
			var id: String = ingredient["id"]
			if seen.has(id):
				continue
			seen[id] = true
			if not ingredient_meals.has(id):
				ingredient_meals[id] = {"count": 0, "name": ingredient["name"]}
			ingredient_meals[id]["count"] += 1
	var observation := "还没开饭。"
	if not skipped_names.is_empty():
		observation = "今天三顿都没吃。" if skipped_names.size() == 3 else "、".join(skipped_names) + "没吃。"
	elif eaten > 0:
		observation = "三顿都吃了。" if eaten == 3 else "吃了 %d 顿。" % eaten
		var ids := ingredient_meals.keys()
		ids.sort()
		for id in ids:
			if ingredient_meals[id]["count"] >= 2:
				observation = "今天有 %d 顿吃了%s。" % [ingredient_meals[id]["count"], ingredient_meals[id]["name"]]
				break
	return {"title": "今天吃了什么", "rows": rows, "observation": observation, "spent": spent, "eaten": eaten, "skipped": skipped_names.size()}
