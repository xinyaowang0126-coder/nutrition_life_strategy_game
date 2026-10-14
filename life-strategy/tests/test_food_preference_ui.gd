@tool
extends McpTestSuite

const CompactCardScene := preload("res://scenes/game_v2/components/CompactChoiceCard.tscn")
const TakeoutRowScene := preload("res://scenes/game_v2/components/TakeoutFoodRowCard.tscn")
const StickyNoteScene := preload("res://scenes/game_v2/components/StickyNotePopup.tscn")
const LegacyCardScene := preload("res://scenes/game/components/ChoiceCard.tscn")


func suite_name() -> String:
	return "food_preference_ui"


func test_transient_preview_passes_clicks_and_pinned_detail_restores_controls() -> void:
	var note := _note(_food(0))
	note.show_at(Rect2(200, 200, 180, 280), false, false)
	assert_eq(note.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for control in note.find_children("*", "Control", true, false):
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	note.show_at(Rect2(200, 200, 180, 280), false, true)
	assert_eq(note.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(note.close_button.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_false(note.close_button.disabled)
	note.show_at(Rect2(200, 200, 180, 280), false, false)
	assert_eq(note.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(note.recovery_section.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_negative_food_reaction_is_separate_and_explicitly_character_taste() -> void:
	var food := _food(-2)
	food["mood"] = 999
	var card := _compact(food)
	var row := _takeout(food)
	var note := _note(food)
	var legacy := _legacy(food)
	assert_eq(card.primary_stat.text, "饱腹 +5")
	assert_eq(card.secondary_stat.text, "口味 -2")
	assert_eq(row.quick_stat.text, "饱腹 +5\n口味 -2")
	assert_true(note.preference_section.visible)
	assert_eq((note.preference_section.get_node("Heading") as Label).text, "角色口味（游戏效果）")
	assert_eq(note.preference_reaction.text, "不太合本局角色的口味 · 心情 -2")
	assert_false(note.mood_metric.visible, "food mood must leave the generic stat grid")
	assert_contains(legacy.summary_label.text, "口味 -2")
	assert_contains(legacy.tooltip_text, "角色口味（游戏效果）")
	assert_contains(legacy.tooltip_text, "不太合本局角色的口味 · 心情 -2")
	assert_false(legacy.tooltip_text.contains("999"))


func test_missing_and_unspecified_preferences_do_not_fall_back_to_raw_mood() -> void:
	var missing := _food(0)
	missing.erase("food_preference")
	missing["mood"] = 99
	var unspecified := _food(0)
	unspecified["food_preference"]["status"] = "unspecified"
	unspecified["mood"] = -99
	for food in [missing, unspecified]:
		var card := _compact(food)
		var row := _takeout(food)
		var note := _note(food)
		var legacy := _legacy(food)
		assert_eq(card.secondary_stat.text, "口味未设置")
		assert_contains(row.quick_stat.text, "口味未设置")
		assert_eq(note.preference_reaction.text, "口味未设置")
		assert_contains(legacy.summary_label.text, "口味未设置")
		assert_contains(legacy.tooltip_text, "口味未设置")
		assert_false(legacy.tooltip_text.contains("99"))
		assert_false(note.mood_metric.visible)


func test_known_neutral_taste_is_distinct_from_an_unspecified_preference() -> void:
	var food := _food(0)
	var card := _compact(food)
	var row := _takeout(food)
	var note := _note(food)
	var legacy := _legacy(food)
	assert_eq(card.secondary_stat.text, "口味 0")
	assert_contains(row.quick_stat.text, "口味 0")
	assert_eq(note.preference_reaction.text, "本局角色没有特别偏好 · 心情 0")
	assert_contains(legacy.summary_label.text, "口味 0")
	assert_false(note.preference_reaction.text.contains("未设置"))


func test_favorite_copy_comes_only_from_the_supplied_character_preference() -> void:
	var food := _food(3)
	food["tags"] = ["favorite", "high_sugar", "high_fat"]
	food["food_groups"] = ["vegetables"]
	food["health_snapshot"] = {"confidence": "high", "health_score": 100}
	var note := _note(food)
	var legacy := _legacy(food)
	assert_eq(note.preference_reaction.text, "合本局角色的口味 · 心情 +3")
	assert_false(legacy.tooltip_text.contains("偏爱"))
	food["tags"] = []
	food["food_preference"]["comfort"] = true
	note.setup(food, "food")
	legacy.configure(food, "food", "选这个")
	assert_eq(note.preference_reaction.text, "本局角色偏爱这一口 · 心情 +3")
	assert_contains(legacy.tooltip_text, "本局角色偏爱这一口 · 心情 +3")
	assert_eq(_compact(food).secondary_stat.text, "口味 +3")


func test_reused_components_keep_action_sleep_and_source_mood_unchanged() -> void:
	var note := _note(_food(-2))
	var card := _compact(_food(-2))
	var legacy := _legacy(_food(-2))
	for mode in ["action", "sleep", "source"]:
		var payload := {
			"id": "sample", "name": "示例", "mood": 20,
			"energy": 2, "stress": 0, "study": 0, "hand_size": 4,
			"food_preference": {"status": "known", "mood_delta": -99},
		}
		note.setup(payload, mode)
		card.configure(payload, mode)
		legacy.configure(payload, mode, "确认")
		assert_false(note.preference_section.visible)
		assert_true(note.mood_metric.visible)
		assert_eq(note.mood_metric.text, "心情 +20")
		assert_false(card.secondary_stat.visible)
		assert_false(legacy.tooltip_text.contains("角色口味"))
		if mode != "source":
			assert_eq(card.primary_stat.text, "心情 +20")
			assert_contains(legacy.tooltip_text, "心情 +20")
	note.setup(_food(-3), "food")
	assert_false(note.mood_metric.visible)
	assert_true(note.preference_section.visible)
	assert_contains(note.preference_reaction.text, "心情 -3")


func test_detail_signals_preserve_the_decorated_preference_without_shared_mutation() -> void:
	for packed in [CompactCardScene, TakeoutRowScene]:
		var food := _food(-2)
		var card: Variant = _add_to_tree(packed.instantiate())
		card.configure(food, "food")
		var emitted: Array[Dictionary] = []
		card.detail_requested.connect(func(payload: Dictionary, _rect: Rect2, _pinned: bool) -> void:
			emitted.append(payload)
		)
		food["food_preference"]["mood_delta"] = 99
		card.request_detail(true)
		assert_eq(emitted.size(), 1)
		assert_eq(int(emitted[0]["food_preference"]["mood_delta"]), -2)
		emitted[0]["food_preference"]["mood_delta"] = 77
		card.request_detail(true)
		assert_eq(int(emitted[1]["food_preference"]["mood_delta"]), -2)


func test_preference_labels_fit_the_existing_card_widths() -> void:
	for status in ["known", "unspecified"]:
		var food := _food(-3)
		food["food_preference"]["status"] = status
		var card := _compact(food)
		var row := _takeout(food)
		_force_layout(card)
		_force_layout(row)
		assert_true(card.get_combined_minimum_size().x <= 210.0, "taste should fit the 210 px compact card")
		assert_true(row.get_combined_minimum_size().x <= 520.0, "taste should fit the 520 px takeout row")
		var taste_height := row.get_combined_minimum_size().y
		row.quick_stat.text = "饱腹 +5"
		_force_layout(row)
		assert_eq(taste_height, row.get_combined_minimum_size().y, "taste should fit within the original art-driven row height")


func test_note_remeasures_content_after_the_wrap_width_changes() -> void:
	for resolution in [Vector2i(1920, 1080), Vector2i(720, 1280)]:
		for mode in ["food", "action", "state"]:
			var viewport := SubViewport.new()
			viewport.size = resolution
			_add_to_tree(viewport)
			var note := StickyNoteScene.instantiate() as StickyNotePopupV2
			viewport.add_child(note)
			var payload := _food(-2)
			payload["mood"] = 4
			payload["desc"] = "这段说明需要在所选宽度下重新换行。".repeat(6)
			note.setup(payload, mode)
			var mobile: bool = resolution.x < resolution.y
			note.show_at(Rect2(40, 300, 210, 330), mobile, true)
			var target_width := 672.0 if mobile else 430.0
			# Simulate the obsolete tall size seen before wrapped labels receive
			# their real width. The synchronous runner cannot await layout frames.
			note.size = Vector2(target_width, 1800)
			for pass_index in range(3):
				_force_layout(note)
			note._finish_show_layout(note._show_revision, target_width)
			assert_eq(note.size.x, target_width)
			assert_eq(note.size.y, note.get_combined_minimum_size().y)
			assert_true(note.size.y < 1800.0, "the obsolete pre-wrap height must shrink")
			assert_true(viewport.get_visible_rect().encloses(note.get_global_rect()))
			assert_true(viewport.get_visible_rect().encloses(note.close_button.get_global_rect()))


func test_stale_show_and_hide_callbacks_cannot_change_a_new_or_closed_note() -> void:
	var note := _note(_food(-2))
	note.show_at(Rect2(40, 100, 210, 330), false, true)
	var first_revision := note._show_revision
	note.setup(_food(3), "food")
	assert_gt(note._show_revision, first_revision)
	var size_before := note.size
	var position_before := note.position
	note._finish_show_layout(first_revision, 900)
	assert_eq(note.size, size_before)
	assert_eq(note.position, position_before)
	assert_contains(note.preference_reaction.text, "心情 +3")
	var second_revision := note._show_revision
	note.hide_note(false)
	note._finish_show_layout(second_revision, 900)
	assert_false(note.visible)
	note.show_at(Rect2(60, 100, 210, 330), false, true)
	note._finish_hide(second_revision)
	assert_true(note.visible, "an older closing animation must not hide the reopened note")


func test_transient_previews_do_not_offer_close_or_action_controls() -> void:
	var note := _note(_food(0))
	note.setup(_food(0), "food", "", "加入")
	for mobile in [false, true]:
		note.show_at(Rect2(40, 100, 210, 330), mobile, false)
		assert_true(note.visible)
		assert_false(note.close_button.visible, "a disappearing preview must not promise a close target")
		assert_true(note.close_button.disabled)
		assert_false(note.action_button.visible)
		assert_true(note.action_button.disabled)


func test_pinned_details_restore_controls_and_respect_disabled_actions() -> void:
	var note := _note(_food(0))
	note.setup(_food(0), "food", "", "加入")
	note.show_at(Rect2(40, 100, 210, 330), true, true)
	assert_true(note.close_button.visible)
	assert_false(note.close_button.disabled)
	assert_true(note.action_button.visible)
	assert_false(note.action_button.disabled)
	note.setup(_food(0), "food", "余额不足", "加入")
	assert_true(note.close_button.visible)
	assert_true(note.action_button.visible)
	assert_true(note.action_button.disabled)
	note.show_at(Rect2(40, 100, 210, 330), true, false)
	assert_false(note.close_button.visible)
	assert_false(note.action_button.visible)


func _food(mood_delta: int) -> Dictionary:
	return {
		"id": "greens", "name": "青菜", "satiety": 5, "energy": 2,
		"cost": 3, "burden": -2, "desc": "刚从窗口端过来的一碟。",
		"food_preference": {
			"profile_id": "fixture_character", "profile_version": 1,
			"character_name": "本局角色", "status": "known",
			"mood_delta": mood_delta, "comfort": false,
		},
	}


func _compact(food: Dictionary) -> CompactChoiceCardV2:
	var card := _add_to_tree(CompactCardScene.instantiate()) as CompactChoiceCardV2
	card.configure(food, "food")
	return card


func _takeout(food: Dictionary) -> TakeoutFoodRowCardV2:
	var card := _add_to_tree(TakeoutRowScene.instantiate()) as TakeoutFoodRowCardV2
	card.configure(food, "food")
	return card


func _note(food: Dictionary) -> StickyNotePopupV2:
	var note := _add_to_tree(StickyNoteScene.instantiate()) as StickyNotePopupV2
	note.setup(food, "food")
	return note


func _legacy(food: Dictionary) -> ChoiceCard:
	var card := _add_to_tree(LegacyCardScene.instantiate()) as ChoiceCard
	card.configure(food, "food", "选这个")
	return card


func _add_to_tree(node: Node) -> Node:
	track(node)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(node)
	return node


func _force_layout(node: Node) -> void:
	for child in node.get_children():
		_force_layout(child)
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
