@tool
extends McpTestSuite

const NewDayPopupScene := preload("res://scenes/game_v2/components/NewDayPopup.tscn")


func suite_name() -> String:
	return "new_day_popup"


func test_desktop_layout_uses_two_cards_and_missing_images_are_safe() -> void:
	var popup = NewDayPopupScene.instantiate()
	_add_to_test_tree(popup)
	popup.show_day({
		"day": 3,
		"learning_state": {
			"title": "脑子很清醒",
			"summary": "昨晚睡得不错。",
			"study_modifier": 3,
		},
		"event": {
			"title": "食堂换了菜单",
			"summary": "今天多了一些搭配。",
			"effect_text": "食堂抽牌稍有变化",
		},
		"status_image": "res://missing-status-image.png",
		"event_image": "res://missing-event-image.png",
	}, false)
	popup._finish_show()

	assert_true(popup.visible)
	assert_eq(popup.day_title.text, "第 3 天开始")
	assert_eq(popup.cards_grid.columns, 2)
	assert_eq(popup.status_title.text, "脑子很清醒")
	assert_eq(popup.status_effect.text, "每次学习效果 +3")
	assert_eq(popup.event_title.text, "食堂换了菜单")
	assert_false(popup.status_image.visible)
	assert_false(popup.status_image_frame.visible)
	assert_false(popup.event_image.visible)
	assert_false(popup.event_image_frame.visible)
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.continue_button.get_global_rect()),
		"continue button must remain inside the modal paper: host=%s paper=%s vbox=%s body=%s grid=%s button=%s" % [
			popup.paper_host.get_global_rect(), popup.paper.size,
			popup.get_node("PaperHost/Paper/Margin/VBox").size, popup.body_scroll.size,
			popup.cards_grid.size, popup.continue_button.get_global_rect()
		]
	)


func test_mobile_layout_stacks_scrollable_cards_above_fixed_button() -> void:
	var popup = NewDayPopupScene.instantiate()
	_add_to_test_tree(popup)
	popup.show_day({
		"day": 2,
		"learning_state": {"title": "状态平稳", "study_modifier": 0},
		"event": {"title": "天气放晴"},
		"status_image": "res://icon.svg",
		"event_image": "",
	}, true)
	popup._finish_show()

	assert_eq(popup.cards_grid.columns, 1)
	assert_eq(popup.body_scroll.horizontal_scroll_mode, 0)
	assert_eq(popup.body_scroll.vertical_scroll_mode, 3)
	assert_eq(popup.body_scroll.scroll_deadzone, 18)
	assert_eq(popup.status_image_frame.custom_minimum_size.y, 140.0)
	assert_true(popup.status_image.visible)
	assert_true(popup.status_image.texture != null)
	assert_false(popup.event_image.visible)
	assert_true(popup.continue_button.get_combined_minimum_size().y >= 48.0)
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.continue_button.get_global_rect()),
		"mobile continue button must stay outside the scrolling card region: host=%s button=%s" % [
			popup.paper_host.get_global_rect(), popup.continue_button.get_global_rect()
		]
	)


func test_continue_emits_once_and_public_payload_is_a_copy() -> void:
	var popup = NewDayPopupScene.instantiate()
	_add_to_test_tree(popup)
	var events: Array[String] = []
	popup.continue_requested.connect(func() -> void: events.append("continue"))
	popup.show_day({"day": 4, "button_text": "进入第 4 天"})
	var payload_copy: Dictionary = popup.get_payload()
	payload_copy["day"] = 99
	assert_eq(int(popup.get_payload()["day"]), 4)
	popup.continue_button.pressed.emit()
	popup.continue_button.pressed.emit()
	assert_eq(events, ["continue"])


func _add_to_test_tree(node: Node) -> void:
	track(node)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(node)
