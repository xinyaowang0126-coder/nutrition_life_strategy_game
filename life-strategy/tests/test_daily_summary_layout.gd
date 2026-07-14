@tool
extends McpTestSuite

const PopupScene := preload("res://scenes/game_v2/components/DailySummaryPopup.tscn")


func suite_name() -> String:
	return "daily_summary_layout"


func test_expanded_detail_scrolls_without_covering_desktop_footer() -> void:
	var popup := _popup_in_viewport(Vector2i(1920, 1080))
	_show_long_summary(popup, false)

	assert_true(popup.detail_panel.visible)
	assert_eq(popup.detail_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_gt(
		popup.detail_scroll.get_v_scroll_bar().max_value,
		popup.detail_scroll.get_v_scroll_bar().page,
		"long detail text must produce a usable vertical scroll range"
	)
	assert_true(popup.detail_panel.custom_minimum_size.y <= 310.0)
	assert_true(popup.paper_host.size.y <= 1080.0)
	assert_true(
		popup.paper_host.get_global_rect().encloses(popup.next_button.get_global_rect()),
		"the fixed footer must remain inside the desktop paper host"
	)
	assert_eq(popup.next_button.get_parent(), popup.root_stack)


func test_narrow_mobile_profile_stays_bounded_and_stacks_stats() -> void:
	var popup := _popup_in_viewport(Vector2i(390, 640))
	_show_long_summary(popup, true)

	assert_true(popup.paper_host.size.x <= 390.0)
	assert_true(popup.paper_host.size.y <= 640.0)
	assert_eq(popup.core_stats.columns, 1)
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
		"quality": "三餐都接住了，其中一顿的餐盘构成比较完整。",
		"advice": "明天继续保持进餐规律，同时给复习留出调整空间。",
		"nutrition": {
			"detail_text": "\n".join(detail_lines),
			"basis": "依据膳食指南进行游戏化反馈，仅用于健康教育。",
		},
		"stats": {"stability": 64, "study_progress": 20, "balance": 108},
	}, mobile)
	popup._finish_show()
	popup._toggle_nutrition_detail()
	_force_container_layout(popup.paper)


func _force_container_layout(container: Container) -> void:
	container.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in container.get_children():
		if child is Container:
			_force_container_layout(child as Container)
