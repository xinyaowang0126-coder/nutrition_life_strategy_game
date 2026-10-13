@tool
extends McpTestSuite

const FlagsScript := preload("res://scripts/health/HealthGuidanceFeatureFlags.gd")
const NutritionLedgerScript := preload("res://scripts/systems/NutritionLedger.gd")
const DayCarryoverServiceScript := preload("res://scripts/systems/DayCarryoverService.gd")
const CharacterHUDScene := preload("res://scenes/game_v2/components/CharacterHUD.tscn")
const StickyNoteScene := preload("res://scenes/game_v2/components/StickyNotePopup.tscn")


func suite_name() -> String:
	return "health_guidance_m1"


func test_legacy_baseline_fixtures_are_explicitly_audit_only() -> void:
	var quality: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://tests/fixtures/health_v1_baseline/current_quality_examples.json"
		)
	)
	var daily: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://tests/fixtures/health_v1_baseline/current_daily_summary_examples.json"
		)
	)
	assert_true(bool(quality.get("legacy_only", false)))
	assert_true(bool(daily.get("legacy_only", false)))
	assert_eq((quality.get("cases", []) as Array).size(), 5)
	assert_eq((daily.get("cases", []) as Array).size(), 2)


func test_health_guidance_v2_flags_default_to_off() -> void:
	var flags: Dictionary = FlagsScript.current()
	for flag_name in FlagsScript.VALID_FLAGS:
		assert_false(bool(flags.get(flag_name, true)), "%s must default to off" % flag_name)
	assert_true((flags.get("warnings", []) as Array).is_empty())


func test_health_guidance_v2_flags_downgrade_invalid_dependencies() -> void:
	var flags: Dictionary = FlagsScript.resolve({
		"data": false,
		"engine": true,
		"ui": true,
		"weekly": true,
	})
	assert_false(bool(flags["data"]))
	assert_false(bool(flags["engine"]))
	assert_false(bool(flags["ui"]))
	assert_false(bool(flags["weekly"]))
	assert_eq((flags["warnings"] as Array).size(), 3)
	assert_false(FlagsScript.is_enabled(flags, "not_a_flag"))


func test_retired_health_numeric_widgets_ignore_legacy_values() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := CharacterHUDScene.instantiate() as CharacterHUDV2
	track(hud)
	tree.root.add_child(hud)
	hud.update_stats({"stability": 60, "energy": 50, "mood": 50, "satiety": 50, "stress": 50, "diet_burden": 24, "study_progress": 10, "study_target": 70}, false)
	assert_false(hud.has_node("StatusBoard/Margin/VBox/StatGrid/BurdenChip"))
	assert_contains(hud.recovery_value.text, "不可用")
	var detail := hud._make_detail_payload()
	for key in ["character_health", "diet_burden", "burden"]:
		assert_false(detail.has(key))
	assert_contains(String(detail["desc"]), "不是对玩家真实健康的评价")
	var note := StickyNoteScene.instantiate() as StickyNotePopupV2
	track(note)
	tree.root.add_child(note)
	for payload in [{"id": "sample", "name": "示例", "burden": 3}, {"id": "sample2", "name": "示例", "character_health": 76}, detail]:
		note.setup(payload, "state")
		assert_false(note.has_node("Margin/VBox/MetricGrid/Burden"))

func test_legacy_scores_no_longer_produce_a_daily_health_tier() -> void:
	var records: Array[Dictionary] = [{"phase": "breakfast", "skipped": false, "food_ids": ["old_food"], "food_names": ["旧记录食物"], "quality": 90}]
	var view := NutritionLedgerScript.summarize(records)
	assert_false(view.has("score"))
	assert_false(view.has("rating"))
	assert_contains(view["detail_text"], "旧记录食物")
	assert_contains(view["basis"], "不作营养评价")


func test_carryover_copy_is_explicitly_gameplay_not_medical() -> void:
	var Recovery := load("res://scripts/systems/RecoveryStateService.gd")
	var Data := load("res://scripts/GameData.gd")
	var card = Data.get_sleep_option("sleep_early")
	var snapshot := {"id": "sleep_early"}
	for key in ["energy", "mood", "stress", "study", "satiety"]:
		snapshot[key] = card[key]
	var record = Recovery.settle(1, {"energy": 45, "stress": 45}, snapshot, {})["recovery_state"]
	var prepared = DayCarryoverServiceScript.from_recovery(record, 1)
	assert_true(prepared["valid"])
	assert_eq(prepared["learning_state"]["title"], "恢复充分")
	assert_contains(String(prepared["learning_state"]["summary"]), "按游戏规则")
	assert_false(String(prepared["learning_state"]["summary"]).contains("饮食"))

func test_risky_legacy_copy_is_absent_from_current_player_scripts() -> void:
	var source := "\n".join([
		FileAccess.get_file_as_string("res://scripts/systems/NutritionLedger.gd"),
		FileAccess.get_file_as_string("res://scripts/systems/DayCarryoverService.gd"),
		FileAccess.get_file_as_string("res://scripts/ui_v2/GameRootV2.gd"),
		FileAccess.get_file_as_string("res://scripts/GameRoot.gd"),
	])
	for phrase in [
		"餐盘完整",
		"搭配较好",
		"优先补齐",
		"脑雾",
		"身体也有点沉",
		"不太舒服",
		"没那么累",
	]:
		assert_false(source.contains(phrase), "risky player copy remains: %s" % phrase)
