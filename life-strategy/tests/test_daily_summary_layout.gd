@tool
extends McpTestSuite

const PopupScene := preload("res://scenes/game_v2/components/DailySummaryPopup.tscn")


func suite_name() -> String:
	return "daily_summary_layout"


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
		"nutrition": {
			"detail_text": "三餐情况　吃了 2/3 餐\n餐盘线索\n卡牌资料线索",
			"basis": "规则小字：本局饮食信息参考《中国居民膳食指南（2022）》的一般原则。",
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
		"nutrition": {
			"detail_text": "\n".join(detail_lines),
			"basis": "规则小字：本局饮食信息参考《中国居民膳食指南（2022）》的一般原则；卡牌出现不代表现实摄入量足够，也不用于现实健康判断。",
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
