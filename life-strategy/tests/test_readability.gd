@tool
extends McpTestSuite

const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")
const Events := preload("res://scripts/systems/WeeklyEventService.gd")
const Data := preload("res://scripts/GameData.gd")


func suite_name() -> String:
	return "readability"


func test_mobile_pantry_first_row_keeps_names_and_stats_visible() -> void:
	# 600x956 physical pixels expands the 720x1280 canvas horizontally.
	for logical_size in [Vector2i(720, 1280), Vector2i(803, 1280)]:
		var game := _game(logical_size, true)
		game._choose_meal_source("dorm_storage")
		_layout(game)
		var stage := game._active_stage as DormPantryStageV2
		var visible_area := stage.pantry_scroll.get_global_rect()
		assert_eq(stage.pantry_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
		var cards := stage.stock_grid.get_children()
		assert_true(not cards.is_empty())
		for index in range(mini(2, cards.size())):
			var card := cards[index] as CompactChoiceCardV2
			assert_true(visible_area.encloses(card.title_label.get_global_rect()), "first-row food names must be visible without scrolling")
			assert_true(visible_area.encloses(card.primary_stat.get_global_rect()), "first-row quick stats must not be clipped")
		assert_true(game.get_viewport().get_visible_rect().encloses(stage.confirm_button.get_global_rect()))
		var bowl := stage.get_node("Layout/BowlPanel") as Control
		assert_true(bowl.get_global_rect().end.y <= stage.confirm_button.get_global_rect().position.y, "bowl %s min %s must not cover confirmation %s at %s" % [bowl.get_global_rect(), bowl.get_combined_minimum_size(), stage.confirm_button.get_global_rect(), logical_size])


func test_sleep_previews_wrap_and_stay_inside_their_note() -> void:
	for logical_size in [Vector2i(720, 1280), Vector2i(803, 1280), Vector2i(1920, 1080)]:
		var game := _game(logical_size, logical_size.y > logical_size.x)
		for day in range(1, 8):
			game.day = day
			game.phase = "sleep"
			game._render_phase()
			_layout(game)
			var stage := game._active_stage as SleepStageV2
			var note := stage.get_node("Layout/AlarmNote") as Control
			assert_ne(stage.tomorrow_label.autowrap_mode, TextServer.AUTOWRAP_OFF)
			assert_ne(stage.hint_label.autowrap_mode, TextServer.AUTOWRAP_OFF)
			assert_true(game.get_viewport().get_visible_rect().encloses(note.get_global_rect()), "event note %s min %s must stay in %s on day %d" % [note.get_global_rect(), note.get_combined_minimum_size(), logical_size, day])
			assert_true(note.get_global_rect().encloses(stage.tomorrow_label.get_global_rect()))
			assert_true(note.get_global_rect().encloses(stage.hint_label.get_global_rect()))
			var preview := Events.next_day_preview(day, Data.TOTAL_DAYS)
			if not preview.is_empty():
				assert_contains(stage.tomorrow_label.text, String(preview["summary"]))


func test_source_name_plates_keep_readable_contrast_when_disabled() -> void:
	var game := _game(Vector2i(720, 1280), true)
	var stage := game._active_stage as MealSourceStageV2
	for source_id in MealSourceStageV2.SOURCE_NODE_NAMES:
		var prop := stage._prop_for(String(source_id))
		var label := prop.get_node("Name") as Label
		var plate := label.get_theme_stylebox("normal") as StyleBoxFlat
		assert_true(plate != null, "source names need their own background")
		assert_true(plate.bg_color.a >= 0.95, "night backgrounds must not dominate the name plate")
		for enabled in [true, false]:
			stage.set_source_enabled(String(source_id), enabled, "" if enabled else "暂时未开放")
			var text_color := label.get_theme_color("font_color") * label.modulate
			var background := plate.bg_color * label.modulate
			var ratio := (_luminance(background) + 0.05) / (_luminance(text_color) + 0.05)
			assert_true(ratio >= 4.5, "name contrast must survive the disabled appearance: %.2f" % ratio)


func _game(logical_size: Vector2i, mobile: bool) -> GameRootV2:
	var viewport := SubViewport.new()
	viewport.size = logical_size
	track(viewport)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(viewport)
	var game := GameScene.instantiate() as GameRootV2
	game.health_history_path = ""
	viewport.add_child(game)
	var resize_callback := Callable(game, "_apply_responsive_profile")
	if viewport.size_changed.is_connected(resize_callback):
		viewport.size_changed.disconnect(resize_callback)
	game._mobile_mode = mobile
	game._apply_shell_profile()
	game.new_day_popup.hide()
	game._render_phase()
	_layout(game)
	return game


func _layout(root: Node) -> void:
	for pass_index in range(6):
		_sort(root)


func _sort(node: Node) -> void:
	if node is Container:
		(node as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		_sort(child)
	if node is Label and (node as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		(node as Label).get_line_count()
	if node is Control:
		(node as Control).update_minimum_size()
	if node is Container and node.get_parent() is Control and not node.get_parent() is Container:
		# The synchronous runner cannot wait for Godot's deferred minimum-size
		# pass. Reapply the declared anchored rectangle after child wrapping has
		# settled; do not measure the transient height from the old width.
		var control := node as Control
		var parent_size := control.get_parent_area_size()
		control.set_size(Vector2(
			parent_size.x * (control.anchor_right - control.anchor_left) + control.offset_right - control.offset_left,
			parent_size.y * (control.anchor_bottom - control.anchor_top) + control.offset_bottom - control.offset_top
		))


func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


func _linear(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)
