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


func test_character_health_is_positive_direction_and_labeled_as_a_game_mechanic() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := CharacterHUDScene.instantiate() as CharacterHUDV2
	track(hud)
	tree.root.add_child(hud)
	hud.update_stats({
		"stability": 60,
		"energy": 50,
		"mood": 50,
		"satiety": 50,
		"stress": 50,
		"diet_burden": 24,
		"study_progress": 10,
		"study_target": 70,
	}, false)
	assert_eq(hud.burden_value.text, "角色健康 76")
	assert_eq(int(hud._make_detail_payload()["character_health"]), 76)
	assert_contains(String(hud._make_detail_payload()["desc"]), "不是对玩家真实健康的评价")
	assert_contains(String(hud._make_detail_payload()["desc"]), "不参与饮食结构判断")

	var note := StickyNoteScene.instantiate() as StickyNotePopupV2
	track(note)
	tree.root.add_child(note)
	note.setup({"id": "sample", "name": "示例", "burden": 3}, "food")
	assert_eq(note.burden_metric.text, "角色健康 -3")
	note.setup(hud._make_detail_payload(), "state")
	assert_eq(note.burden_metric.text, "角色健康 76")


func test_legacy_rating_no_longer_exposes_a_health_tier() -> void:
	var low_copy := NutritionLedgerScript.rating_for_score(20)
	var high_copy := NutritionLedgerScript.rating_for_score(90)
	assert_eq(low_copy, high_copy)
	assert_contains(low_copy, "不作健康评价")


func test_carryover_copy_is_explicitly_gameplay_not_medical() -> void:
	assert_eq(String(DayCarryoverServiceScript.CLEAR_FOCUS["title"]), "进入状态较快")
	assert_eq(String(DayCarryoverServiceScript.BRAIN_FOG["title"]), "需要先缓一缓")
	assert_contains(String(DayCarryoverServiceScript.CLEAR_FOCUS["summary"]), "按游戏规则")
	assert_contains(String(DayCarryoverServiceScript.BRAIN_FOG["summary"]), "不是医学判断")


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
