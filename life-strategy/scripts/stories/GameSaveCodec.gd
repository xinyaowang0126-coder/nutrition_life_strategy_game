class_name GameSaveCodec
extends RefCounted

const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Data := preload("res://scripts/GameData.gd")
const Cards := preload("res://scripts/CardDataStore.gd")
const Balance := preload("res://scripts/systems/GameplayBalanceRules.gd")
const Recovery := preload("res://scripts/systems/RecoveryStateService.gd")
const Archive := preload("res://scripts/health/MealHealthArchive.gd")
const Preferences := preload("res://scripts/systems/FoodPreferenceService.gd")
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const HouseholdLearning := preload("res://scripts/stories/HouseholdLearningFlow.gd")
const MealLearning := preload("res://scripts/stories/HouseholdMealLearning.gd")
const DayFive := preload("res://scripts/stories/HouseholdDayFive.gd")
const Preparation := preload("res://scripts/stories/HouseholdPreparation.gd")
const Finale := preload("res://scripts/stories/HouseholdFinale.gd")
const VERSION := 1
const KIND := "nutrition_life_game_save"
const MAX_BYTES := 4194304
const PHASES := ["breakfast_source", "breakfast", "breakfast_action", "lunch_source", "lunch", "lunch_action", "dinner_source", "dinner", "dinner_action", "sleep", "summary", "ending"]
const FIELD_TYPES := {
	"state": TYPE_DICTIONARY, "day": TYPE_INT, "phase": TYPE_STRING,
	"hand": TYPE_ARRAY, "selected_food_ids": TYPE_ARRAY, "current_source_id": TYPE_STRING,
	"source_hands": TYPE_DICTIONARY, "dorm_inventory": TYPE_DICTIONARY,
	"today_meal_records": TYPE_ARRAY, "actions_used_today": TYPE_INT, "drink_water_used": TYPE_INT,
	"used_action_names": TYPE_ARRAY, "used_action_ids": TYPE_ARRAY, "today_action_records": TYPE_ARRAY,
	"today_period_records": TYPE_ARRAY, "combos_today": TYPE_ARRAY, "summary_payload": TYPE_DICTIONARY,
	"food_preferences": TYPE_DICTIONARY, "ending_id": TYPE_STRING, "low_stability_days": TYPE_INT,
	"run_history": TYPE_ARRAY, "current_event": TYPE_DICTIONARY, "current_learning_state": TYPE_DICTIONARY,
	"pending_learning_state": TYPE_DICTIONARY, "pending_recovery_state": TYPE_DICTIONARY,
	"current_recovery_state": TYPE_DICTIONARY, "_current_recovery_effect": TYPE_DICTIONARY,
	"_recovery_display_record": TYPE_DICTIONARY, "_started_day": TYPE_INT,
	"recovery_diagnostics": TYPE_ARRAY, "_day_start_state": TYPE_DICTIONARY,
	"chosen_sleep_id": TYPE_STRING, "chosen_sleep_name": TYPE_STRING,
	"_recovery_before_sleep": TYPE_DICTIONARY, "_recovery_sleep_snapshot": TYPE_DICTIONARY,
	"_day_settlement_effects": TYPE_ARRAY, "_day_settled": TYPE_BOOL,
	"performed": TYPE_BOOL, "_lesson_seen": TYPE_DICTIONARY,
	"household_learning": TYPE_DICTIONARY,
	"household_lessons": TYPE_DICTIONARY,
	"household_day_five": TYPE_DICTIONARY,
	"household_preparation": TYPE_DICTIONARY,
	"household_finale": TYPE_DICTIONARY,
}


static func capture(game: Node) -> Dictionary:
	var payload := {}
	for key in FIELD_TYPES:
		var value: Variant = game.get(key)
		payload[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	payload["kitchen"] = {"ingredients": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "batches": game.kitchen.batches.duplicate(true), "history": game.kitchen.history.duplicate(true), "serial": game.kitchen._serial}
	payload["shared_meal"] = {"plan": game.shared_meal.plan.duplicate(true), "history": game.shared_meal.history.duplicate(true)}
	payload["deck"] = game._deck_service.capture_state()
	payload["new_day_pending"] = game._new_day_pending and game.phase == "breakfast_source"
	payload["health_archive"] = game._health_archive.to_save_data() if game._health_archive != null else Archive.new().to_save_data()
	return {"kind": KIND, "schema_version": VERSION, "story_id": game.story_id, "story_version": game.story["version"], "character_id": game.story["character_id"], "character_version": game.story["character_version"], "balance_version": Balance.VERSION, "saved_at": int(Time.get_unix_time_from_system()), "payload": payload}


static func encode(envelope: Dictionary) -> Dictionary:
	if not json_value(envelope):
		return failure("invalid_value", "进度中包含不能保存的数据。")
	var checked := validate(normalize(envelope))
	if not checked["ok"]:
		return checked
	var content := JSON.stringify(checked["save"], "", true, true)
	if content.to_utf8_buffer().size() > MAX_BYTES:
		return failure("too_large", "这份进度文件过大。")
	return {"ok": true, "text": content, "save": checked["save"]}


static func decode(content: String) -> Dictionary:
	if content.to_utf8_buffer().size() > MAX_BYTES:
		return failure("too_large", "这份进度文件过大。")
	var parser := JSON.new()
	if parser.parse(content.trim_prefix("\ufeff")) != OK:
		return failure("invalid_json", "存档文件无法读取。原有进度保留。")
	if not json_value(parser.data):
		return failure("invalid_value", "存档包含无效的数据。")
	return validate(normalize(parser.data))


static func validate(envelope: Variant) -> Dictionary:
	Data.ensure_loaded()
	if not envelope is Dictionary or envelope.get("kind") != KIND:
		return failure("wrong_kind", "这不是本游戏的进度文件。")
	if envelope.get("schema_version") != VERSION or typeof(envelope.get("schema_version")) != TYPE_INT:
		return failure("unsupported_version", "这份存档的版本暂不支持，文件会保留。")
	if typeof(envelope.get("story_id")) != TYPE_STRING:
		return failure("invalid_story", "存档的人物信息不完整。")
	var story := Catalog.get_story(envelope["story_id"])
	if story.is_empty():
		return failure("invalid_story", "这份存档的故事尚未开放。")
	for key in {"story_version": "version", "character_id": "character_id", "character_version": "character_version"}:
		var story_key := String({"story_version": "version", "character_id": "character_id", "character_version": "character_version"}[key])
		if envelope.get(key) != story[story_key]:
			return failure("content_version", "这份存档与当前故事版本不兼容。")
	if envelope.get("balance_version") != Balance.VERSION or not integer_between(envelope.get("saved_at"), 0, 9007199254740991):
		return failure("rules_version", "存档的版本或保存时间无法识别。")
	var p: Variant = envelope.get("payload")
	if not p is Dictionary:
		return failure("invalid_payload", "存档缺少游戏进度。")
	# This additive field preserves v1 saves. Missing progress means the old
	# build did not record the scene; never invent a choice or replay it.
	if not p.has("household_learning"):
		envelope = envelope.duplicate(true)
		p = envelope["payload"]
		p["household_learning"] = HouseholdLearning.legacy_state() if story["mechanics"] == "household" else {}
	if not p.has("household_lessons"):
		envelope = envelope.duplicate(true)
		p = envelope["payload"]
		p["household_lessons"] = MealLearning.initial_state() if story["mechanics"] == "household" else {}
	if not p.has("household_day_five"):
		envelope = envelope.duplicate(true)
		p = envelope["payload"]
		p["household_day_five"] = DayFive.initial_state(true) if story["mechanics"] == "household" else {}
	if not p.has("household_preparation"):
		envelope = envelope.duplicate(true)
		p = envelope["payload"]
		p["household_preparation"] = Preparation.initial_state(true) if story["mechanics"] == "household" else {}
	if not p.has("household_finale"):
		envelope = envelope.duplicate(true)
		p = envelope["payload"]
		p["household_finale"] = Finale.initial_state(true) if story["mechanics"] == "household" else {}
	for key in FIELD_TYPES:
		if typeof(p.get(key)) != FIELD_TYPES[key]:
			return failure("invalid_field", "存档字段不完整：" + key)
	for key in ["today_meal_records", "today_action_records", "today_period_records", "run_history", "recovery_diagnostics", "_day_settlement_effects"]:
		for row in p[key]:
			if not row is Dictionary:
				return failure("invalid_record_type", "存档包含无效的记录。")
	for key in p["_lesson_seen"]:
		if not String(key).is_valid_int() or int(key) not in range(1, 8) or typeof(p["_lesson_seen"][key]) != TYPE_BOOL:
			return failure("invalid_lesson", "存档的科普记录无效。")
	if not integer_between(p["day"], 1, 7) or not PHASES.has(p["phase"]) or p["_started_day"] != p["day"]:
		return failure("invalid_phase", "存档的日期或阶段不一致。")
	var elder: bool = story["mechanics"] == "household"
	if not HouseholdLearning.valid(p["household_learning"], elder):
		return failure("invalid_household_learning", "存档的生活情节进度无效。")
	var foods: Dictionary = Catalog.content(story, "foods") if elder else Cards.foods
	var sources: Dictionary = Catalog.content(story, "sources") if elder else Cards.meal_sources
	var actions: Dictionary = Catalog.content(story, "actions") if elder else Cards.actions
	if not state_valid(p["state"], story) or not state_valid(p["_day_start_state"], story):
		return failure("invalid_state", "存档的资源或目标数据无效。")
	for key in ["hand", "selected_food_ids"]:
		if not id_list(p[key], foods, 32):
			return failure("invalid_foods", "存档的菜单不完整。")
	for id in p["selected_food_ids"]:
		if not p["hand"].has(id):
			return failure("invalid_selection", "餐盘与菜单不一致。")
	var meal_phase: bool = p["phase"] in ["breakfast", "lunch", "dinner"]
	if meal_phase:
		if not sources.has(p["current_source_id"]) or p["selected_food_ids"].size() > int(sources[p["current_source_id"]]["selection_limit"]):
			return failure("invalid_source", "存档的选餐来源无效。")
	elif p["current_source_id"] != "" or not p["hand"].is_empty() or not p["selected_food_ids"].is_empty():
		return failure("invalid_source", "存档的选餐阶段不一致。")
	for key in p["source_hands"]:
		var parts := String(key).split(":")
		if parts.size() != 2 or parts[0] not in ["breakfast", "lunch", "dinner"] or not sources.has(parts[1]) or not id_list(p["source_hands"][key], foods, 32):
			return failure("invalid_menu_cache", "存档的已生成菜单无效。")
	if not inventory_valid(p["dorm_inventory"], foods.keys()) or not id_list(p["used_action_ids"], actions, 16):
		return failure("invalid_inventory", "存档的库存或行动无效。")
	for key in ["used_action_names", "combos_today"]:
		if not string_list(p[key], 32):
			return failure("invalid_list", "存档的安排记录无效。")
	if not integer_between(p["actions_used_today"], 0, 3) or not integer_between(p["drink_water_used"], 0, 2) or not integer_between(p["low_stability_days"], 0, 7):
		return failure("invalid_limits", "存档的行动次数无效。")
	if not meal_records_valid(p["today_meal_records"], foods, sources, p["day"]) or p["today_action_records"].size() > 16 or p["today_period_records"].size() > 3:
		return failure("invalid_records", "存档的当日记录无效。")
	for row in p["today_action_records"]:
		if not row is Dictionary or not actions.has(row.get("id")) or not row.get("stat_delta") is Dictionary or not row.get("stock_added") is Dictionary:
			return failure("invalid_action", "存档的行动记录不完整。")
	if p["run_history"].size() != p["day"] - (0 if p["_day_settled"] else 1):
		return failure("invalid_history", "存档的周记录与日结不一致。")
	for i in range(p["run_history"].size()):
		var row: Variant = p["run_history"][i]
		if not row is Dictionary or row.get("day") != i + 1 or not meal_records_valid(row.get("meals"), foods, sources, i + 1) or not row.get("actions") is Array or not Recovery.validate(row.get("recovery_state"))["valid"]:
			return failure("invalid_history", "存档的周记录不完整。")
	for key in ["pending_recovery_state", "current_recovery_state", "_recovery_display_record"]:
		if not Recovery.validate(p[key])["valid"]:
			return failure("invalid_recovery", "存档的恢复记录无效。")
	if p["_day_settled"] != (p["phase"] in ["summary", "ending"]) or (p["phase"] == "summary" and p["summary_payload"].is_empty()):
		return failure("invalid_settlement", "存档的结算状态不一致。")
	if p["phase"] == "ending" and not Data.ENDINGS.has(p["ending_id"]):
		return failure("invalid_ending", "存档的结局无效。")
	if not p["food_preferences"].is_empty() and not Preferences._valid_profile(p["food_preferences"]):
		return failure("invalid_preference", "存档的人物口味记录无效。")
	if typeof(p.get("new_day_pending")) != TYPE_BOOL or (p["new_day_pending"] and p["phase"] != "breakfast_source"):
		return failure("invalid_notice", "存档的开场状态无效。")
	if not deck_valid(p.get("deck")):
		return failure("invalid_random_state", "存档的菜单随机状态无效。")
	if not kitchen_valid(p.get("kitchen"), foods, elder) or not shared_valid(p.get("shared_meal"), p["day"], elder):
		return failure("invalid_household", "存档的厨房或共同进餐记录无效。")
	if elder and not HouseholdLearning.matches_save(p["household_learning"], p["kitchen"], p["day"], p["phase"]):
		return failure("invalid_household_learning", "生活情节与实际处置记录不一致。")
	if not MealLearning.valid_state(p["household_lessons"], elder, p["day"], p["phase"], p["current_source_id"], p["selected_food_ids"], foods, sources) or (not p["household_lessons"].get("active", {}).is_empty() and p["new_day_pending"]):
		return failure("invalid_household_lessons", "练习记录或返回位置不完整。")
	if not DayFive.valid_state(p["household_day_five"], elder, p, foods):
		return failure("invalid_household_day_five", "今天的做法、回应或返回位置不一致。")
	if not Preparation.valid(p["household_preparation"], elder, p, foods):
		return failure("invalid_household_preparation", "备餐计划、取用记录或返回位置不一致。")
	if not Finale.valid(p["household_finale"], elder, p, foods, actions, int(story["goal_target"])):
		return failure("invalid_household_finale", "演前安排、实际参演或本周回顾不一致。")
	var finale_open: bool = not p["household_finale"].get("active", {}).is_empty() or p["household_finale"].get("pending", false) or p["household_finale"].get("intro") == "details"
	if finale_open and (not p["household_lessons"].get("active", {}).is_empty() or not p["household_day_five"].get("active", {}).is_empty() or p["household_day_five"].get("pending", "") != "" or p["household_day_five"].get("intro") == "details" or not p["household_preparation"].get("active", {}).is_empty() or p["household_preparation"].get("pending", "") != "" or p["household_preparation"].get("intro") == "details"):
		return failure("invalid_household_finale", "同时存在两份未关闭的安排。")
	var preparation_open: bool = not p["household_preparation"].get("active", {}).is_empty() or p["household_preparation"].get("pending", "") != "" or p["household_preparation"].get("intro") == "details"
	if preparation_open and (not p["household_lessons"].get("active", {}).is_empty() or not p["household_day_five"].get("active", {}).is_empty() or p["household_day_five"].get("pending", "") != "" or p["household_day_five"].get("intro") == "details"):
		return failure("invalid_household_preparation", "同时存在两份未关闭的安排。")
	if not p["household_lessons"].get("active", {}).is_empty() and (not p["household_day_five"].get("active", {}).is_empty() or p["household_day_five"].get("pending", "") != "" or p["household_day_five"].get("intro") == "details"):
		return failure("invalid_household_day_five", "同时存在两份未关闭的安排。")
	var archive := Archive.new()
	if not archive.load_data(p.get("health_archive"))["ok"]:
		return failure("invalid_archive", "存档的冻结资料无效。")
	return {"ok": true, "save": envelope.duplicate(true)}


static func state_valid(state: Dictionary, story: Dictionary) -> bool:
	if state.size() != Catalog.initial_stats(story).size():
		return false
	for key in Catalog.initial_stats(story):
		if not integer_between(state.get(key), 0, 1000000):
			return false
	for key in ["energy", "mood", "stress", "satiety", "stability"]:
		if not integer_between(state.get(key), 0, 100):
			return false
	return state.get("goal_target", state.get("study_target")) == story["goal_target"]


static func meal_records_valid(rows: Variant, foods: Dictionary, sources: Dictionary, day: int = 0) -> bool:
	if not rows is Array or rows.size() > 3:
		return false
	var phases := {}
	for row in rows:
		if not row is Dictionary or row.get("phase") not in ["breakfast", "lunch", "dinner"] or phases.has(row["phase"]):
			return false
		phases[row["phase"]] = true
		if not row.get("stat_delta") is Dictionary or not integer_between(row.get("total_cost"), 0, 1000000) or not id_list(row.get("food_ids"), foods, 3):
			return false
		if not string_list(row.get("food_names"), 3) or typeof(row.get("skipped")) != TYPE_BOOL or typeof(row.get("uses_stock")) != TYPE_BOOL:
			return false
		if not bool(row.get("skipped", false)) and not sources.has(row.get("source_id")):
			return false
		if row.has("recipe_facts") and (not row["recipe_facts"] is Dictionary or not Facts.valid(row["recipe_facts"])):
			return false
		if row.has("learning_facts"):
			var c: Variant = row["learning_facts"]
			if not MealLearning.valid_context(c, foods, sources) or c["scope"] != "confirmed" or c["food_ids"] != row["food_ids"] or c["food_names"] != row["food_names"] or c["meal"] != row["phase"] or c["source"] != row["source_id"] or c["recipe_facts"] != row.get("recipe_facts", {}): return false
		if row.has("day_five_experience") and not DayFive.valid_experience(row["day_five_experience"], row, day): return false
	return true


static func kitchen_valid(k: Variant, foods: Dictionary, elder: bool) -> bool:
	if not k is Dictionary or not inventory_valid(k.get("ingredients"), ["rice_plain", "egg", "tofu", "greens", "tomato", "oatmeal", "millet", "milk", "apple", "fish"]) or not inventory_valid(k.get("condiments"), ["salt_g", "soy_ml", "sugar_g"]) or not integer_between(k.get("serial"), 0, 100000) or not k.get("batches") is Array or not k.get("history") is Array:
		return false
	if not elder:
		return true
	if k["batches"].size() > 100 or k["history"].size() > 200 or k["condiments"].size() != 3:
		return false
	var ids := {}
	for batch in k["batches"]:
		if not batch is Dictionary or typeof(batch.get("id")) != TYPE_STRING or ids.has(batch["id"]) or not foods.has(batch.get("food_id")) or not integer_between(batch.get("quantity"), 0, 1):
			return false
		ids[batch["id"]] = true
		if String(batch["id"]).begins_with("batch_"):
			var suffix := String(batch["id"]).trim_prefix("batch_")
			if not suffix.is_valid_int() or int(suffix) <= 0 or int(suffix) > k["serial"]:
				return false
		if batch.has("recipe_facts") and (not batch["recipe_facts"] is Dictionary or not Facts.valid(batch["recipe_facts"])):
			return false
		# Unknown safety fields stay unknown. They are never filled by loading.
		for key in ["made_hour", "stored_hour"]:
			if batch.has(key) and not integer_between(batch[key], 0, 1000):
				return false
	return true


static func shared_valid(s: Variant, day: int, elder: bool) -> bool:
	if not s is Dictionary or not s.get("plan") is Dictionary or not s.get("history") is Array or s["history"].size() > 20:
		return false
	var plan: Dictionary = s["plan"]
	if plan.is_empty():
		return true
	if not (elder and plan.get("day") in [4, 5, 6] and int(plan["day"]) <= day and plan.get("meal") == "dinner" and plan.get("venue") in ["home", "community"] and plan.get("status") in ["planned", "completed"] and plan.get("companion_id") == "chen_friend" and plan.get("companion_name") == "老陈" and (plan.get("status") != "planned" or plan["day"] == day)):
		return false
	var completed := false
	var invited := false
	for entry in s["history"]:
		if not entry is Dictionary:
			return false
		if entry.get("day") == plan["day"]:
			invited = invited or entry.get("kind") == "invitation"
			completed = completed or entry.get("kind") == "shared_meal"
	return invited and completed == (plan["status"] == "completed")


static func deck_valid(deck: Variant) -> bool:
	if not deck is Dictionary or deck.size() != 2:
		return false
	for key in ["seed", "state"]:
		if typeof(deck.get(key)) != TYPE_STRING or not deck[key].is_valid_int() or str(int(deck[key])) != deck[key]:
			return false
	return true


static func inventory_valid(value: Variant, ids: Array) -> bool:
	if not value is Dictionary:
		return false
	for key in value:
		if not ids.has(key) or not integer_between(value[key], 0, 1000000):
			return false
	return true


static func id_list(value: Variant, entries: Dictionary, maximum: int) -> bool:
	if not string_list(value, maximum):
		return false
	for id in value:
		if not entries.has(id):
			return false
	return true


static func string_list(value: Variant, maximum: int) -> bool:
	if not value is Array or value.size() > maximum:
		return false
	for item in value:
		if typeof(item) != TYPE_STRING:
			return false
	return true


static func integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) == TYPE_INT and value >= minimum and value <= maximum


static func json_value(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return abs(value) <= 9007199254740991
		TYPE_FLOAT:
			return is_finite(value) and abs(value) <= 9007199254740991
		TYPE_ARRAY:
			if value.size() > 1000:
				return false
			for item in value:
				if not json_value(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 1000:
				return false
			for key in value:
				if typeof(key) not in [TYPE_STRING, TYPE_INT] or not json_value(value[key], depth + 1):
					return false
			return true
	return false


static func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key in value:
			out[str(key)] = normalize(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(normalize(item))
		return out
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	return value


static func summary(save: Dictionary) -> String:
	var story := Catalog.get_story(save["story_id"])
	var p: Dictionary = save["payload"]
	var stages := {"breakfast_source": "早餐前", "breakfast": "选早餐", "breakfast_action": "早餐后", "lunch_source": "午餐前", "lunch": "选午餐", "lunch_action": "午餐后", "dinner_source": "晚餐前", "dinner": "选晚餐", "dinner_action": "晚餐后", "sleep": "睡前", "summary": "今日小结", "ending": "本周结局"}
	var goal_key := "goal_progress" if story["mechanics"] == "household" else "study_progress"
	var local_time := int(save["saved_at"]) + int(Time.get_time_zone_from_system()["bias"]) * 60
	return "%s · 第%d天 · %s\n%s %d/%d · 余额 ¥%d\n保存于 %s" % [story["character_name"], p["day"], stages[p["phase"]], "排练" if goal_key == "goal_progress" else "复习", p["state"][goal_key], story["goal_target"], p["state"]["balance"], Time.get_datetime_string_from_unix_time(local_time).replace("T", " ")]


static func failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message}
