@tool
extends McpTestSuite

const MenuScript := preload("res://scripts/stories/SeriesMenu.gd")
const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Store := preload("res://scripts/stories/GameSaveStore.gd")
const Controller := preload("res://scripts/ui_v2/GameRootV2.gd")
const Deck := preload("res://scripts/systems/MealDeckService.gd")
const Backdrop := preload("res://scripts/stories/LifeSceneBackdrop.gd")
const Scenes := preload("res://scripts/stories/LifeSceneCatalog.gd")

class MenuHarness extends "res://scripts/stories/SeriesMenu.gd":
	var requested_story := ""
	var requested_save := {}
	func _start_week(id: String = "campus_exam") -> void: requested_story = id
	func _continue_saved(snapshot: Dictionary) -> void: requested_save = snapshot.duplicate(true)


func suite_name() -> String:
	return "series_menu"


func _menu(size: Vector2i = Vector2i(1920,1080)) -> MenuHarness:
	Store.memory_for_tests = true
	Store._memory.clear()
	var viewport := SubViewport.new()
	viewport.size = size
	track(viewport)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	var menu := MenuHarness.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(menu)
	var callback := Callable(menu, "_apply_responsive_profile")
	if viewport.size_changed.is_connected(callback): viewport.size_changed.disconnect(callback)
	menu._configure_layout(size.y > size.x)
	return menu


func _snapshot(id: String, time: int = 100) -> Dictionary:
	var game := Controller.new()
	track(game)
	game.story_id = id
	game._deck_service = Deck.new(42)
	game.start_new_run()
	var save := game.capture_game_save()
	save["saved_at"] = time
	return save


func test_title_is_separate_from_character_selection_and_enter_does_not_start() -> void:
	var menu := _menu()
	assert_eq(menu._page, "title")
	assert_true(menu._title_page.visible)
	assert_false(menu._selection_page.visible)
	menu._title_start.pressed.emit()
	assert_eq(menu._page, "characters")
	assert_true(menu._selection_page.visible)
	assert_eq(menu.requested_story, "")


func test_character_selection_and_primary_launch_follow_selected_story() -> void:
	var menu := _menu()
	menu._show_characters()
	menu._select_character("zhou_huilan_66")
	assert_eq(menu._selected, "choir_week")
	assert_eq(menu._story_title.text, "自己的舞台")
	menu._enter_selected()
	assert_eq(menu.requested_story, "choir_week")
	assert_true(menu.requested_save.is_empty())


func test_grouping_supports_more_characters_and_multiple_stories_per_person() -> void:
	var rows: Array = Catalog.all()
	var sequel: Dictionary = rows[0].duplicate(true)
	sequel["id"] = "second_story"
	sequel["title"] = "另一段生活"
	rows.append(sequel)
	for i in range(10):
		var extra: Dictionary = rows[0].duplicate(true)
		extra["id"] = "extra_story_%d" % i
		extra["character_id"] = "extra_person_%d" % i
		rows.append(extra)
	var groups := MenuScript.group_stories(rows)
	assert_eq(groups.size(), 12)
	assert_eq(groups[0]["stories"].size(), 2)
	assert_eq(groups[0]["stories"][1]["id"], "second_story")
	assert_eq(Catalog.all().size(), 2)


func test_malformed_and_duplicate_catalog_entries_do_not_create_fake_people() -> void:
	var rows: Array = [{}, {"id": "", "character_id": "x"}]
	rows.append_array(Catalog.all())
	rows.append(Catalog.all()[0])
	assert_eq(MenuScript.group_stories(rows).size(), 2)
	assert_true(MenuScript.group_stories([]).is_empty())


func test_person_switching_never_spends_or_writes_progress() -> void:
	var menu := _menu()
	var before := Store._memory.duplicate(true)
	menu._show_characters()
	for ignored in range(4):
		menu._select_character("zhou_huilan_66")
		menu._select_character("campus_student")
	assert_eq(Store._memory, before)
	assert_eq(menu.requested_story, "")
	assert_true(menu.requested_save.is_empty())


func test_existing_progress_uses_continue_without_resetting_other_story() -> void:
	var menu := _menu()
	var store := Store.new()
	assert_true(store.write_local(_snapshot("campus_exam", 100))["ok"])
	assert_true(store.write_local(_snapshot("choir_week", 200))["ok"])
	var before := Store._memory.duplicate(true)
	menu._select_character("zhou_huilan_66")
	menu._enter_selected()
	assert_eq(menu.requested_save["story_id"], "choir_week")
	assert_eq(Store._memory, before)
	assert_eq(menu._main_start.text, "继续这一周")
	menu._more_info.pressed.emit()
	assert_true(menu._dialog.visible)
	assert_false(menu._dialog._buttons.has_node("start"))
	menu._dialog._buttons.get_node("back").pressed.emit()
	assert_eq(Store._memory, before)


func test_latest_title_continue_uses_newest_valid_save() -> void:
	var menu := _menu()
	var store := Store.new()
	assert_true(store.write_local(_snapshot("campus_exam", 100))["ok"])
	assert_true(store.write_local(_snapshot("choir_week", 200))["ok"])
	menu._load_saved_cards()
	assert_true(menu._title_continue.visible)
	menu._title_continue.pressed.emit()
	assert_eq(menu.requested_save["story_id"], "choir_week")
	assert_contains(menu._title_continue.text, "周阿姨")


func test_cancel_restart_keeps_auto_and_manual_progress() -> void:
	var menu := _menu()
	var store := Store.new()
	var save := _snapshot("choir_week")
	assert_true(store.write_local(save)["ok"])
	assert_true(store.write_local(save,"manual_1")["ok"])
	menu._select_character("zhou_huilan_66")
	var before := Store._memory.duplicate(true)
	menu._request_restart()
	assert_true(menu._dialog.visible)
	menu._dialog._buttons.get_node("cancel").pressed.emit()
	assert_eq(Store._memory, before)
	assert_eq(menu.requested_story, "")


func test_empty_manual_slots_are_disabled_and_back_is_available() -> void:
	var menu := _menu()
	menu._show_slots("campus_exam")
	for slot in Store.SLOTS: assert_true(menu._dialog._buttons.get_node(slot).disabled)
	assert_false(menu._dialog._buttons.get_node("back").disabled)


func test_invalid_import_does_not_touch_progress_or_request_a_story() -> void:
	var menu := _menu()
	var before := Store._memory.duplicate(true)
	menu._preview_import("not JSON")
	assert_eq(Store._memory, before)
	assert_true(menu.requested_save.is_empty())
	assert_true(menu._dialog.visible)


func test_catalog_contains_coherent_portrait_art_for_all_playable_people() -> void:
	for story in Catalog.all():
		assert_true(ResourceLoader.exists(story["character_selection_art"]))
		assert_ne(story["character_selection_art"], story["portrait"])
		assert_false(story["character_short_name"].is_empty())


func test_life_playlist_contains_multiple_real_assets_per_person() -> void:
	var scenes := Scenes.all()
	assert_eq(scenes.size(), 6)
	var counts := {}
	for scene in scenes:
		counts[scene["character_id"]] = counts.get(scene["character_id"], 0) + 1
		assert_true(ResourceLoader.exists(scene["image"]))
		assert_true(scene["mobile_focus_x"] > 0 and scene["mobile_focus_x"] < 1)
	for story in Catalog.all(): assert_true(counts[story["character_id"]] >= 3)


func test_background_rotation_pause_and_disabled_page_have_no_side_effects() -> void:
	var backdrop := Backdrop.new()
	track(backdrop)
	(Engine.get_main_loop() as SceneTree).root.add_child(backdrop)
	backdrop.size = Vector2(1280,720)
	var first: int = backdrop.current
	backdrop._process(11)
	assert_eq(backdrop.current, (first+1) % backdrop.scenes.size())
	backdrop.paused = true
	first = backdrop.current
	backdrop._process(30)
	assert_eq(backdrop.current, first)
	backdrop.paused = false
	backdrop.enabled = false
	backdrop._process(30)
	assert_eq(backdrop.current, first)


func test_loading_shell_uses_real_progress_and_no_prominent_switch_buttons() -> void:
	var shell := FileAccess.get_file_as_string("res://export/web_shell.html")
	assert_contains(shell, "onProgress(current,total)")
	assert_contains(shell, "prefers-reduced-motion")
	assert_contains(shell, "lifeTimer")
	assert_false(shell.contains('id="previous"'))
	assert_false(shell.contains('id="next"'))
	assert_false(shell.contains("status-splash"))


func test_engine_icon_files_are_new_art_with_complete_windows_sizes() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/icon"), "res://assets/branding/haohaochifan-512.png")
	var image := Image.load_from_file("res://assets/branding/haohaochifan-512.png")
	assert_eq(image.get_size(), Vector2i(512,512))
	assert_eq(image.get_pixel(0,0).a, 0.0)
	assert_true(image.get_pixel(256,256).a > 0.9)
	var file := FileAccess.open("res://assets/branding/haohaochifan.ico", FileAccess.READ)
	assert_eq(file.get_16(), 0)
	assert_eq(file.get_16(), 1)
	assert_eq(file.get_16(), 6)


func test_no_prominent_title_previous_or_next_controls() -> void:
	var menu := _menu(Vector2i(780,1280))
	assert_false(menu._title_page.find_child("PreviousScene",true,false).visible)
	assert_false(menu._title_page.find_child("NextScene",true,false).visible)
	assert_true(menu._pause_scenes.visible)


func test_three_viewports_keep_primary_button_and_full_art_inside_canvas() -> void:
	for size in [Vector2i(720,1280),Vector2i(853,1280),Vector2i(1920,1080)]:
		var menu := _menu(size)
		menu._show_characters()
		_layout(menu)
		assert_true(menu.get_viewport_rect().encloses(menu._main_start.get_global_rect()))
		assert_true(menu.get_viewport_rect().encloses(menu._rail.get_global_rect()))
		assert_true(menu._strips[menu._selected_character]._art.texture != null)


func _layout(node: Node) -> void:
	for i in range(7): _sort(node)


func _sort(node: Node) -> void:
	if node is Container: node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children(): _sort(child)
	if node is Label: node.get_line_count()
	if node is Control: node.update_minimum_size()
	if node is Container and node.get_parent() is Control and not node.get_parent() is Container:
		var control := node as Control
		var parent_size := control.get_parent_area_size()
		control.set_size(Vector2(parent_size.x*(control.anchor_right-control.anchor_left)+control.offset_right-control.offset_left,parent_size.y*(control.anchor_bottom-control.anchor_top)+control.offset_bottom-control.offset_top))
