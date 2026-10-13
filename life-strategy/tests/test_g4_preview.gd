@tool
extends McpTestSuite

const Model := preload("res://tests/preview/G4PreviewModel.gd")
const Presenter := preload("res://scripts/health/HealthGuidancePresenter.gd")
const Suggestions := preload("res://scripts/health/FeasibleSuggestionService.gd")
const PanelScene := preload("res://scenes/game_v2/components/MealCompositionPanel.tscn")
const PreviewScene := preload("res://tests/preview/G4MealPreview.tscn")


func suite_name() -> String:
	return "g4_preview"


func test_preview_changes_neither_balance_nor_records_until_confirmed() -> void:
	var model := Model.new()
	model.toggle("fixture_rice")
	model.toggle("fixture_egg")
	var before := {"balance": model.balance, "selected": model.selected.duplicate(), "records": model.records.duplicate(true)}
	var view := model.meal_view()
	assert_eq(view["portion_text"], "份量未标")
	assert_eq(view["ingredients"][0]["name"], "米饭")
	assert_eq(view["ingredients"][1]["name"], "鸡蛋")
	assert_eq({"balance": model.balance, "selected": model.selected, "records": model.records}, before)
	view["ingredients"].clear()
	assert_eq(model.meal_view()["ingredients"].size(), 2)


func test_unknown_and_unapproved_copy_never_exposes_raw_ingredient_names() -> void:
	var model := Model.new()
	model.toggle("fixture_low")
	var view := model.meal_view()
	assert_false(view["nutrition_allowed"])
	assert_eq(view["ingredients"], [])
	assert_contains(view["text"], "配料")
	model.toggle("fixture_rice")
	view = model.meal_view()
	assert_true(view["nutrition_allowed"])
	assert_eq(view["ingredients"].size(), 1)
	assert_eq(view["data_note"], "配料不全")
	model.copies["copies"]["MEAL_COMPOSITION_PARTIAL"]["review_status"] = "draft"
	assert_eq(model.meal_view()["ingredients"], [])


func test_record_capture_is_frozen_and_separates_prices_from_health_snapshot() -> void:
	var model := Model.new()
	model.toggle("fixture_rice")
	model.toggle("fixture_egg")
	assert_true(model.confirm())
	assert_eq(model.balance, 16)
	assert_eq(model.phase(), "lunch")
	assert_eq(model.records.size(), 1)
	assert_false(model.confirm())
	assert_eq(model.records.size(), 1)
	assert_false(model.records[0]["health_snapshot"].has("total_cost"))
	model.catalog["profiles"]["fixture_rice"]["components"][0]["name"] = "changed"
	assert_eq(model.records[0]["meal_view"]["ingredients"][0]["name"], "米饭")


func test_diary_counts_ingredients_once_per_meal_and_reports_only_real_phases() -> void:
	var model := Model.new()
	model.toggle("fixture_mixed")
	model.toggle("fixture_egg")
	model.confirm()
	var first := model.diary()
	assert_eq(first["rows"].size(), 1)
	assert_false(first["observation"].contains("2 顿"))
	model.toggle("fixture_egg")
	model.confirm()
	var repeated := model.diary()
	assert_contains(repeated["observation"], "2 顿吃了鸡蛋")
	model.skip()
	assert_eq(model.diary()["observation"], "晚饭没吃。")
	assert_eq(model.diary()["spent"], 11)
	assert_false(model.skip())
	assert_eq(model.records.size(), 3)


func test_optional_add_and_swap_are_affordable_and_current() -> void:
	var model := Model.new()
	model.toggle("fixture_rice")
	model.toggle("fixture_egg")
	var offer := model.suggestion()
	assert_true(offer["verified"])
	assert_eq(offer["action"]["food_id"], "fixture_vegetable")
	assert_eq(offer["action"]["kind"], "add_food")
	assert_eq(offer["action"]["total_cost"], 7)
	assert_eq(model.balance, 20)
	assert_true(model.apply_suggestion(offer))
	assert_eq(model.selected.size(), 3)
	assert_eq(model.balance, 20)
	assert_false(model.apply_suggestion(offer))
	var other := Model.new()
	for id in ["fixture_rice", "fixture_egg", "fixture_fruit"]:
		other.toggle(id)
	var replacement := other.suggestion()
	assert_eq(replacement["action"]["remove_food_id"], "fixture_fruit")
	assert_true(other.apply_suggestion(replacement))
	assert_eq(other.selected.size(), 3)
	assert_true(other.selected.has("fixture_egg"))
	assert_true(other.selected.has("fixture_rice"))


func test_suggestions_respect_budget_fee_stock_and_source_availability() -> void:
	var model := Model.new()
	model.toggle("fixture_rice")
	model.toggle("fixture_egg")
	for kind in ["budget", "fee", "stock", "unavailable"]:
		var context := model.suggestion_context()
		match kind:
			"budget": context["balance"] = 4
			"fee": context["fee"] = 19
			"stock":
				context["payment_mode"] = "stock"
				context["source_id"] = "dorm_storage"
				context["selection_limit"] = 2
				context["current_snapshot"]["source_id"] = "dorm_storage"
				for row in context["options"]:
					for snapshot in row["candidate_snapshots"].values():
						snapshot["source_id"] = "dorm_storage"
					if not model.selected.has(row["id"]):
						row["stock"] = 0
			"unavailable":
				for row in context["options"]:
					if not model.selected.has(row["id"]):
						row["available"] = false
		var offer := Suggestions.find_option(context, model.config, model.registry, Model.DATE, model.copies)
		assert_false(offer["verified"], kind)
		if kind == "stock":
			for row in context["options"]:
				if row["id"] == "fixture_mixed":
					row["stock"] = 1
			var feasible := Suggestions.find_option(context, model.config, model.registry, Model.DATE, model.copies)
			assert_true(feasible["verified"])
			assert_eq(feasible["action"]["total_cost"], 0)


func test_actual_source_opening_payment_mode_and_limit_are_checked() -> void:
	var model := Model.new()
	model.toggle("fixture_rice")
	model.toggle("fixture_egg")
	for mode in ["closed", "payment", "limit", "unknown"]:
		var context := model.suggestion_context()
		match mode:
			"closed": context["source_id"] = "takeout"
			"payment": context["payment_mode"] = "stock"
			"limit": context["source_id"] = "convenience_store"
			"unknown": context["source_id"] = "missing_source"
		assert_false(Suggestions.find_option(context, model.config, model.registry, Model.DATE, model.copies)["verified"], mode)


func test_affordable_add_is_preferred_but_budget_can_use_swap_with_free_slot() -> void:
	var model := Model.new()
	model.toggle("fixture_egg")
	model.toggle("fixture_fruit")
	var comfortable := model.suggestion()
	assert_eq(comfortable["action"]["kind"], "add_food")
	model.balance = 5
	var constrained := model.suggestion()
	assert_true(constrained["verified"])
	assert_eq(constrained["action"]["kind"], "replace_food")
	assert_eq(constrained["action"]["remove_food_id"], "fixture_fruit")
	assert_eq(constrained["action"]["total_cost"], 5)
	assert_true(model.apply_suggestion(constrained))
	assert_eq(model.balance, 5)
	assert_true(model.confirm())
	assert_eq(model.balance, 0)


func test_stale_wrong_day_or_malformed_candidate_is_not_suggested() -> void:
	var model := Model.new()
	model.toggle("fixture_rice")
	model.toggle("fixture_egg")
	var stale := model.suggestion()
	model.toggle("fixture_fruit")
	assert_false(model.apply_suggestion(stale))
	for mutation in ["phase", "day", "ids", "invalid"]:
		var context := model.suggestion_context()
		for row in context["options"]:
			for key in row["candidate_snapshots"]:
				var value: Dictionary = row["candidate_snapshots"][key]
				match mutation:
					"phase": value["phase"] = "breakfast_action"
					"day": value["day"] = 2
					"ids": value["food_ids"] = []
					"invalid": row["candidate_snapshots"][key] = 99
		assert_false(Suggestions.find_option(context, model.config, model.registry, Model.DATE, model.copies)["verified"], mutation)


func test_unknown_role_gives_no_instruction_and_complete_selection_is_not_scored() -> void:
	var model := Model.new()
	model.toggle("fixture_rice")
	model.toggle("fixture_low")
	assert_false(model.suggestion()["verified"])
	model.toggle("fixture_low")
	model.toggle("fixture_mixed")
	assert_false(model.suggestion()["verified"])
	var view := model.meal_view()
	assert_false(view.has("score"))
	assert_false(view["text"].contains("均衡"))
	assert_false(view["text"].contains("足够"))


func test_composition_panel_reopen_is_readonly_and_has_no_acceptance_gate() -> void:
	var model := Model.new()
	model.toggle("fixture_mixed")
	var panel = PanelScene.instantiate()
	track(panel)
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	panel.show_view(model.meal_view())
	assert_eq(panel.portion_label.text, "份量未标")
	for repeat in range(3):
		panel.details_button.pressed.emit()
		panel.details_button.pressed.emit()
	assert_eq(model.balance, 20)
	assert_eq(model.records.size(), 0)
	assert_eq(model.selected, ["fixture_mixed"])
	assert_false(panel.details_scroll.visible)


func test_preview_scene_is_separate_from_normal_game_and_renders_journal() -> void:
	var preview = PreviewScene.instantiate()
	track(preview)
	(Engine.get_main_loop() as SceneTree).root.add_child(preview)
	assert_contains(preview.title_label.text, "早饭")
	preview._toggle("fixture_mixed")
	preview._confirm()
	preview._toggle_diary()
	assert_true(preview.diary_panel.visible)
	assert_eq(preview.model.records.size(), 1)
	assert_false(preview.confirm_button.visible)
	assert_false(FileAccess.get_file_as_string("res://scripts/ui_v2/GameRootV2.gd").contains("G4MealPreview"))
	preview._toggle_diary()
	preview._skip()
	preview._skip()
	assert_eq(preview.title_label.text, "今天吃了什么")
	assert_true(preview.diary_button.disabled)
