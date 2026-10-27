@tool
extends McpTestSuite

const PopupScene := preload("res://scenes/game_v2/components/DailySummaryPopup.tscn")


func suite_name() -> String:
	return "daily_summary_layout"


func test_rapid_next_requests_emit_once_until_a_new_summary_is_shown() -> void:
	var popup := _popup_in_viewport(Vector2i(1920, 1080))
	var events: Array[String] = []
	popup.next_day_requested.connect(func() -> void: events.append("next"))
	popup.show_summary({"day": 1})
	popup.next_button.pressed.emit()
	popup.next_button.pressed.emit()
	assert_eq(events, ["next"])
	popup.hide_summary(false)
	popup.next_button.pressed.emit()
	assert_eq(events, ["next"])
	popup.show_summary({"day": 2})
	popup.next_button.pressed.emit()
	assert_eq(events, ["next", "next"])


func test_escape_collapses_details_without_advancing_the_day() -> void:
	var popup := _popup_in_viewport(Vector2i(720, 1280))
	var events: Array[String] = []
	popup.next_day_requested.connect(func() -> void: events.append("next"))
	_show_long_summary(popup, true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	popup._input(escape)
	assert_false(popup.detail_panel.visible)
	assert_true(popup.visible)
	assert_eq(popup.get_viewport().gui_get_focus_owner(), popup.detail_button)
	popup._input(escape)
	assert_true(events.is_empty())
	assert_false(popup.next_button.disabled)


func test_enter_activates_focused_detail_or_record_entry_without_advancing() -> void:
	var popup := _popup_in_viewport(Vector2i(720, 1280))
	var events: Array[String] = []
	popup.next_day_requested.connect(func() -> void: events.append("next"))
	popup.record_book_requested.connect(func() -> void: events.append("records"))
	popup.show_summary({"day": 1, "record_book_available": true, "detail": {"detail_text": "早餐、午餐、晚餐的实际选择。"}}, true)
	popup.detail_button.grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	popup._input(enter)
	assert_true(popup.detail_panel.visible)
	assert_true(events.is_empty())
	popup.record_book_button.grab_focus()
	popup._input(enter)
	assert_eq(events, ["records"])
	assert_false(popup.next_button.disabled)


func test_expanded_detail_scrolls_without_covering_desktop_footer() -> void:
	var popup := _popup_in_viewport(Vector2i(1920, 1080))
	_show_long_summary(popup, false)

	assert_true(popup.detail_panel.visible)
	assert_gt(popup.content_scroll.scroll_vertical, 0)
	assert_eq(popup.detail_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_gt(
		popup.detail_scroll.get_v_scroll_bar().max_value,
		popup.detail_scroll.get_v_scroll_bar().page,
		"long detail text must produce a usable vertical scroll range"
	)
	assert_true(popup.detail_panel.custom_minimum_size.y <= 310.0)
	assert_true(popup.paper_host.size.y <= 1080.0)
	assert_true(popup.meal_trail.visible)
	assert_eq(popup.meal_trail.columns, 3)
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.next_button.get_global_rect()),
		"the fixed footer must remain inside the desktop paper host"
	)
	assert_eq(popup.next_button.get_parent(), popup.root_stack)


func test_desktop_meal_summary_keeps_details_entry_above_the_fold() -> void:
	var popup := _popup_in_viewport(Vector2i(1920, 1080))
	popup.show_summary({
		"day": 3,
		"title": "第 3 天，收工",
		"record_summary": "今天有一餐没吃。先把这件事记下来。",
		"advice": "明天要是排得开，先给吃饭留个空档；不用靠下一顿集中补偿。\n今天的复习计划还差 2。明天电量高时再补一段也来得及。\n明天：状态平稳 · 每次复习 不变 · 食堂轮换",
		"meal_stamps": [
			{"title": "早餐", "text": "食堂 · 白米饭、鸡蛋", "state": "eaten"},
			{"title": "午餐", "text": "便利店 · 苹果、牛奶", "state": "eaten"},
			{"title": "晚餐", "text": "没吃", "state": "skipped"},
		],
		"detail": {
			"detail_text": "选餐记录\n早餐｜食堂｜白米饭、鸡蛋\n午餐｜便利店｜苹果、牛奶\n晚餐｜跳过",
			"basis": "成分与份量尚未核对，暂不作营养评价。",
		},
		"stats": {"stability": 64, "study_progress": 30, "balance": 82},
	}, false)
	popup._finish_show()
	for _layout_pass in range(4):
		popup._layout_popup()
		_force_container_layout(popup.paper)

	var scroll_bar := popup.content_scroll.get_v_scroll_bar()
	assert_true(
		scroll_bar.max_value <= scroll_bar.page + 1.0,
		"the standard desktop meal summary, note, and details entry should fit without scrolling (max %.1f, page %.1f)" % [
			scroll_bar.max_value,
			scroll_bar.page,
		]
	)
	assert_true(popup.detail_button.is_visible_in_tree())
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.detail_button.get_global_rect()),
		"the flip-ticket entry must remain inside the paper host"
	)


func test_narrow_mobile_profile_stays_bounded_and_stacks_stats() -> void:
	var popup := _popup_in_viewport(Vector2i(390, 640))
	_show_long_summary(popup, true)

	assert_true(popup.paper_host.size.x <= 390.0)
	assert_true(popup.paper_host.size.y <= 640.0)
	assert_eq(popup.core_stats.columns, 1)
	assert_true(popup.meal_trail.visible)
	assert_eq(popup.meal_trail.columns, 1)
	assert_true(popup.detail_panel.custom_minimum_size.y < popup.paper_host.size.y)
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.next_button.get_global_rect()),
		"the mobile footer must remain visible while summary content scrolls"
	)
	assert_true(popup.next_button.custom_minimum_size.y >= 48.0)


func test_legacy_payload_without_record_detail_keeps_footer_accessible() -> void:
	for canvas in [Vector2i(1920, 1080), Vector2i(720, 1280), Vector2i(390, 640)]:
		var popup := _popup_in_viewport(canvas)
		popup.show_summary({
			"quality": "旧营养评分 95",
			"nutrition": {"detail_text": "旧营养评级"},
			"advice": "这一天先记到这里。\n明天按预算和时间安排。\n还有记录未记清。",
			"meal_stamps": [
				{"title": "早餐", "text": "未记", "state": "missing"},
				{"title": "午餐", "text": "未记", "state": "missing"},
				{"title": "晚餐", "text": "未记", "state": "missing"},
			],
			"stats": {"stability": 60, "study_progress": 10, "balance": 100},
		}, canvas.y > canvas.x)
		popup._finish_show()
		for _pass in range(4):
			popup._layout_popup()
			_force_container_layout(popup.paper)
		assert_eq(popup.record_summary_label.text, "选餐记录暂时不可用。")
		assert_false(popup.detail_button.visible)
		assert_true(popup.paper_host.get_global_rect().encloses(popup.next_button.get_global_rect()), "unknown fallback footer clipped at %s" % canvas)
		assert_eq(popup.next_button.get_parent(), popup.root_stack)


func _popup_in_viewport(viewport_size: Vector2i) -> DailySummaryPopupV2:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	track(viewport)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(viewport)
	var popup := PopupScene.instantiate() as DailySummaryPopupV2
	viewport.add_child(popup)
	popup.size = Vector2(viewport_size)
	return popup


func _show_long_summary(popup: DailySummaryPopupV2, mobile: bool) -> void:
	var detail_lines: Array[String] = []
	for index in range(40):
		detail_lines.append("第 %d 条记录：饮食、作息与复习变化。" % (index + 1))
	popup.show_summary({
		"day": 1,
		"record_summary": "三餐都吃了，今天先记到这里。",
		"advice": "明天继续照预算、时间和口味做选择，也给复习留点空档。",
		"meal_stamps": [
			{"title": "早餐", "text": "食堂 · 白米饭、鸡蛋", "state": "eaten"},
			{"title": "午餐", "text": "便利店 · 苹果、牛奶", "state": "eaten"},
			{"title": "晚餐", "text": "宿舍存粮 · 燕麦片", "state": "eaten"},
		],
		"detail": {
			"detail_text": "\n".join(detail_lines),
			"basis": "这里只记录确认过的食物与游戏变化，成分与份量尚未核对。",
		},
		"stats": {"stability": 64, "study_progress": 20, "balance": 108},
	}, mobile)
	popup._finish_show()
	popup._toggle_nutrition_detail()
	_force_container_layout(popup.paper)
	popup._reveal_detail()


func _force_container_layout(container: Container) -> void:
	container.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in container.get_children():
		if child is Container:
			_force_container_layout(child as Container)
