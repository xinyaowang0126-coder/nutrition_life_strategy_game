extends Control

const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Session := preload("res://scripts/stories/StorySession.gd")
const Dialog := preload("res://scripts/stories/StoryDialog.gd")
const SaveStore := preload("res://scripts/stories/GameSaveStore.gd")
const SaveCodec := preload("res://scripts/stories/GameSaveCodec.gd")
const CharacterStrip := preload("res://scripts/stories/SeriesCharacterStrip.gd")
const Backdrop := preload("res://scripts/stories/LifeSceneBackdrop.gd")
const ICON := preload("res://assets/branding/haohaochifan-512.png")
const GAME_SCENE := "res://scenes/game_v2/GameRootV2.tscn"
var _dialog: StoryDialog
var _selected := ""
var _selected_character := ""
var _starting := false
var _applying := false
var _mobile := false
var _page := "title"
var _save_store: RefCounted
var _save_hint: Label
var _choice_handler: Callable
var _groups: Array[Dictionary] = []
var _strips: Dictionary = {}
var _latest_save: Dictionary = {}
var _catalog_override: Array[Dictionary] = [] # For local expansion-layout fixtures.
var _title_page: MarginContainer
var _selection_page: MarginContainer
var _title_layout: GridContainer
var _title_copy: VBoxContainer
var _hero: TextureRect
var _title: Label
var _tagline: Label
var _subtitle: Label
var _title_start: Button
var _title_continue: Button
var _title_hint: Label
var _quit_button: Button
var _body_grid: GridContainer
var _rail: ScrollContainer
var _strip_row: HBoxContainer
var _details: ScrollContainer
var _details_body: VBoxContainer
var _story_picker: OptionButton
var _character_label: Label
var _story_title: Label
var _goal: Label
var _conditions: Label
var _learning: Label
var _saved_detail: Label
var _main_start: Button
var _other_saves: Button
var _restart: Button
var _more_info: Button
var _previous: Button
var _next: Button
var _position: Label
var _roster_hint: Label
var _backdrop: LifeSceneBackdrop
var _title_wash: TextureRect
var _scene_caption: Label
var _pause_scenes: Button
var _title_stack: VBoxContainer
var _base_background: ColorRect
var _selection_environment: TextureRect
var _selection_veil: ColorRect
var _back_button: Button
var _pointer_down := false
var _pointer_moved := false


static func group_stories(entries: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var by_id := {}
	var seen := {}
	for story in entries:
		if not story is Dictionary or typeof(story.get("id")) != TYPE_STRING or String(story["id"]).is_empty() or seen.has(story["id"]) or String(story.get("character_id", "")).is_empty(): continue
		seen[story["id"]] = true
		var id: String = story["character_id"]
		if not by_id.has(id):
			var group := {"id": id, "name": story.get("character_short_name", story["character_name"]), "portrait": story["portrait"], "selection_art": story.get("character_selection_art", story["portrait"]), "stories": []}
			by_id[id] = group
			result.append(group)
		by_id[id]["stories"].append(story.duplicate(true))
	return result


func _ready() -> void:
	_save_store = SaveStore.new()
	_groups = group_stories(_catalog_override if not _catalog_override.is_empty() else Catalog.all())
	var background := ColorRect.new()
	_base_background = background
	background.color = Color("#efe5d0")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_selection_environment = TextureRect.new()
	_selection_environment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_environment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selection_environment.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_selection_environment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selection_environment)
	_selection_veil = ColorRect.new()
	_selection_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_veil.color = Color(0.965, 0.935, 0.875, 0.86)
	_selection_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selection_veil)
	_backdrop = Backdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_title_wash = TextureRect.new()
	_title_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_wash)
	_build_title()
	_backdrop.scene_changed.connect(func(index: int, scene: Dictionary) -> void:
		_scene_caption.text = "%s  ·  %d / %d" % [scene["title"], index + 1, _backdrop.scenes.size()]
	)
	if not _backdrop.scenes.is_empty(): _scene_caption.text = _backdrop.scenes[0]["title"] + "  ·  1 / %d" % _backdrop.scenes.size()
	_build_selection()
	_dialog = Dialog.new()
	_dialog.name = "StoryIntro"
	add_child(_dialog)
	_dialog.chosen.connect(func(choice: String) -> void:
		var handler := _choice_handler
		_choice_handler = Callable()
		if handler.is_valid(): handler.call(choice)
	)
	_rebuild_characters()
	get_viewport().size_changed.connect(_apply_responsive_profile)
	_apply_responsive_profile()
	_show_title()
	call_deferred("_load_saved_cards")


func _page_margin(id: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = id
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	return margin


func _build_title() -> void:
	_title_page = _page_margin("TitlePage")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_title_page.add_child(scroll)
	var stack := VBoxContainer.new()
	_title_stack = stack
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 22)
	scroll.add_child(stack)
	_title_layout = GridContainer.new()
	_title_layout.add_theme_constant_override("h_separation", 76)
	_title_layout.add_theme_constant_override("v_separation", 24)
	stack.add_child(_title_layout)
	_title_copy = VBoxContainer.new()
	_title_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_copy.add_theme_constant_override("separation", 20)
	_title_layout.add_child(_title_copy)
	_title_copy.add_child(HouseholdUI.label("营养科普 · 生活策略", 25, HouseholdUI.GREEN))
	_title = HouseholdUI.label("好好吃饭", 108, HouseholdUI.INK, true)
	_title_copy.add_child(_title)
	_tagline = HouseholdUI.label("把自己的饭，也好好安排。", 39, HouseholdUI.ORANGE, true)
	_title_copy.add_child(_tagline)
	_subtitle = HouseholdUI.label("选一段生活，安排三餐、日常任务和休息。", 29)
	_title_copy.add_child(_subtitle)
	_title_start = HouseholdUI.button("开始游戏", "StartGame", true)
	_title_start.pressed.connect(_show_characters)
	_title_copy.add_child(_title_start)
	_title_continue = HouseholdUI.button("继续上次的生活", "ContinueLatest")
	_title_continue.hide()
	_title_continue.pressed.connect(func() -> void:
		if not _latest_save.is_empty(): _continue_saved(_latest_save)
	)
	_title_copy.add_child(_title_continue)
	_title_hint = HouseholdUI.label("每段生活，都有自己的一周。", 23, HouseholdUI.MUTED)
	_title_copy.add_child(_title_hint)
	var hero_center := CenterContainer.new()
	hero_center.name = "MealArtwork"
	hero_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_layout.add_child(hero_center)
	_hero = HouseholdUI.image(ICON)
	_hero.name = "BrandBowl"
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.hide()
	hero_center.add_child(_hero)
	var scenes := HBoxContainer.new()
	scenes.add_theme_constant_override("separation", 16)
	stack.add_child(scenes)
	_scene_caption = HouseholdUI.label("生活的片刻", 23, HouseholdUI.MUTED)
	scenes.add_child(_scene_caption)
	var previous := HouseholdUI.button("上一幅", "PreviousScene")
	previous.custom_minimum_size = Vector2(132, 82)
	previous.hide()
	previous.pressed.connect(func() -> void: _backdrop.select_scene(_backdrop.current - 1))
	scenes.add_child(previous)
	var next_scene := HouseholdUI.button("下一幅", "NextScene")
	next_scene.custom_minimum_size = Vector2(132, 82)
	next_scene.hide()
	next_scene.pressed.connect(func() -> void: _backdrop.select_scene(_backdrop.current + 1))
	scenes.add_child(next_scene)
	_pause_scenes = HouseholdUI.button("暂停轮换", "PauseScenes")
	_pause_scenes.custom_minimum_size = Vector2(132, 80)
	_pause_scenes.size_flags_horizontal = Control.SIZE_SHRINK_END
	_pause_scenes.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "hover_pressed", "pressed", "focus"]:
		var style := _pause_scenes.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.bg_color = Color(0, 0, 0, 0)
		style.set_border_width_all(2 if state == "focus" else 0)
		style.shadow_size = 0
		_pause_scenes.add_theme_stylebox_override(state, style)
	_pause_scenes.pressed.connect(func() -> void:
		_backdrop.paused = not _backdrop.paused
		_pause_scenes.text = "继续轮换" if _backdrop.paused else "暂停轮换"
	)
	scenes.add_child(_pause_scenes)
	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 24)
	stack.add_child(tools)
	var import_button := HouseholdUI.button("导入存档", "ImportSave")
	import_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	import_button.custom_minimum_size = Vector2(184, 80)
	import_button.pressed.connect(_import_file)
	tools.add_child(import_button)
	_quit_button = HouseholdUI.button("退出游戏", "QuitGame")
	_quit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quit_button.custom_minimum_size = Vector2(184, 80)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	_quit_button.visible = not OS.has_feature("web")
	tools.add_child(_quit_button)


func _build_selection() -> void:
	_selection_page = _page_margin("CharacterPage")
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	_selection_page.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	stack.add_child(header)
	var back := HouseholdUI.button("返回标题", "BackToTitle")
	_back_button = back
	back.custom_minimum_size = Vector2(132, 76)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_show_title)
	header.add_child(back)
	var mark := HouseholdUI.image(ICON, 58)
	mark.custom_minimum_size.x = 58
	header.add_child(mark)
	header.add_child(HouseholdUI.label("这周，过谁的生活？", 42, HouseholdUI.INK, true))
	_roster_hint = HouseholdUI.label("每个人，都有自己的生活安排。", 25, HouseholdUI.MUTED)
	stack.add_child(_roster_hint)
	_body_grid = GridContainer.new()
	_body_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_grid.add_theme_constant_override("h_separation", 32)
	_body_grid.add_theme_constant_override("v_separation", 18)
	stack.add_child(_body_grid)
	var rail_pane := VBoxContainer.new()
	rail_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_pane.add_theme_constant_override("separation", 10)
	_body_grid.add_child(rail_pane)
	_rail = ScrollContainer.new()
	_rail.name = "CharacterRail"
	_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_rail.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rail.follow_focus = true
	rail_pane.add_child(_rail)
	_strip_row = HBoxContainer.new()
	_strip_row.name = "CharacterStrips"
	_strip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_strip_row.add_theme_constant_override("separation", 18)
	_rail.add_child(_strip_row)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	rail_pane.add_child(navigation)
	_previous = HouseholdUI.button("上一位", "PreviousCharacter")
	_previous.pressed.connect(_step_character.bind(-1))
	navigation.add_child(_previous)
	_position = HouseholdUI.label("", 24, HouseholdUI.MUTED)
	_position.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(_position)
	_next = HouseholdUI.button("下一位", "NextCharacter")
	_next.pressed.connect(_step_character.bind(1))
	navigation.add_child(_next)
	_details = ScrollContainer.new()
	_details.name = "CharacterDetails"
	_details.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_details.follow_focus = true
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_grid.add_child(_details)
	_details_body = VBoxContainer.new()
	_details_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_body.add_theme_constant_override("separation", 15)
	_details.add_child(_details_body)
	_character_label = HouseholdUI.label("", 27, HouseholdUI.GREEN)
	_details_body.add_child(_character_label)
	_story_picker = OptionButton.new()
	_story_picker.name = "ChooseLifeStory"
	HouseholdUI.style_button(_story_picker)
	_story_picker.custom_minimum_size.y = 84
	_story_picker.item_selected.connect(func(index: int) -> void:
		var group := _current_group()
		if index >= 0 and index < group["stories"].size():
			_selected = group["stories"][index]["id"]
			_refresh_details()
	)
	_details_body.add_child(_story_picker)
	_story_title = HouseholdUI.label("", 52, HouseholdUI.INK, true)
	_details_body.add_child(_story_title)
	_goal = HouseholdUI.label("", 30)
	_details_body.add_child(_goal)
	_conditions = HouseholdUI.label("", 25, HouseholdUI.MUTED)
	_details_body.add_child(_conditions)
	_learning = HouseholdUI.label("", 24, HouseholdUI.GREEN)
	_details_body.add_child(_learning)
	_saved_detail = HouseholdUI.label("", 23, HouseholdUI.MUTED)
	_details_body.add_child(_saved_detail)
	_save_hint = HouseholdUI.label("正在读取进度…", 22, HouseholdUI.MUTED)
	stack.add_child(_save_hint)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 14)
	_details_body.add_child(tools)
	_more_info = HouseholdUI.button("了解这段生活", "StoryInfo")
	_more_info.pressed.connect(func() -> void:
		var story := _current_story()
		if not story.is_empty(): _intro(story)
	)
	tools.add_child(_more_info)
	_other_saves = HouseholdUI.button("其他存档", "OtherSaves")
	_other_saves.pressed.connect(func() -> void:
		if _selected != "": _show_slots(_selected)
	)
	tools.add_child(_other_saves)
	_restart = HouseholdUI.button("重新开始", "RestartStory")
	_restart.pressed.connect(_request_restart)
	tools.add_child(_restart)
	_main_start = HouseholdUI.button("开始这一周", "ChooseStory", true)
	_main_start.pressed.connect(_enter_selected)
	stack.add_child(_main_start)
	_style_character_page()


func _style_character_page() -> void:
	for button: Button in _selection_page.find_children("*", "Button", true, false):
		if button == _main_start: continue
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size.x = 140
		for state in ["normal", "hover", "hover_pressed", "pressed", "focus", "disabled"]:
			var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			style.bg_color = Color(0.80, 0.65, 0.44, 0.18) if state in ["hover", "pressed", "hover_pressed"] else Color(0, 0, 0, 0)
			style.set_border_width_all(2 if state == "focus" else 0)
			style.border_color = HouseholdUI.ORANGE
			style.shadow_size = 0
			button.add_theme_stylebox_override(state, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(state, HouseholdUI.INK)


func _current_group() -> Dictionary:
	for group in _groups:
		if group["id"] == _selected_character: return group
	return {}


func _current_story() -> Dictionary:
	for story in _current_group().get("stories", []):
		if story["id"] == _selected: return story
	return {}


func _rebuild_characters() -> void:
	for child in _strip_row.get_children():
		_strip_row.remove_child(child)
		child.queue_free()
	_strips.clear()
	for group in _groups:
		var strip := CharacterStrip.new()
		_strip_row.add_child(strip)
		strip.setup(group)
		_strips[group["id"]] = strip
		strip.pressed.connect(_press_character.bind(group["id"]))
		strip.focus_entered.connect(_focus_character.bind(group["id"]))
	if _selected_character == "" and not _groups.is_empty(): _selected_character = _groups[0]["id"]
	if _groups.is_empty():
		_selected_character = ""
		_selected = ""
		_refresh_details()
		_update_strips()
	else: _select_character(_selected_character)


func _select_character(id: String) -> void:
	if _starting or not _strips.has(id): return
	_selected_character = id
	var group := _current_group()
	if not group["stories"].any(func(story: Dictionary) -> bool: return story["id"] == _selected): _selected = group["stories"][0]["id"]
	_refresh_details()
	_update_strips()


func _press_character(id: String) -> void:
	if not _pointer_moved: _select_character(id)


func _focus_character(id: String) -> void:
	if not _pointer_down: _select_character(id)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_pointer_down = event.pressed
		if event.pressed: _pointer_moved = false
	elif event is InputEventScreenDrag and event.relative.length() > 10:
		_pointer_moved = true
	elif event is InputEventKey and event.pressed:
		_pointer_moved = false


func _update_strips() -> void:
	var index := 0
	for i in _groups.size():
		var id: String = _groups[i]["id"]
		_strips[id].configure(id == _selected_character, _mobile, 430 if _mobile else 610)
		if id == _selected_character: index = i
	_position.text = "%d / %d · %s" % [index + 1, _groups.size(), "左右滑动选人" if _mobile else "点击人物或用方向键切换"] if not _groups.is_empty() else "暂无可玩人物"
	_previous.disabled = index <= 0
	_next.disabled = index >= _groups.size() - 1


func _refresh_details() -> void:
	var group := _current_group()
	var story := _current_story()
	if story.is_empty():
		_main_start.disabled = true
		_main_start.text = "暂无可玩故事"
		_restart.hide()
		return
	_character_label.text = story["character_name"] + " · " + story["subtitle"]
	_selection_environment.texture = load(story["background"]) as Texture2D
	_story_title.text = story["title"]
	_goal.text = story["goal"]
	_conditions.text = "一局7天 · " + story["conditions"]
	if _mobile: _conditions.text = "一局7天 · 开局预算 ¥%d" % Catalog.initial_stats(story)["balance"]
	_learning.text = "在这段生活里练习\n" + story["learning"]
	_story_picker.clear()
	for item in group["stories"]: _story_picker.add_item(item["title"])
	_story_picker.select(group["stories"].find(story))
	_story_picker.visible = group["stories"].size() > 1
	var saved: Dictionary = _save_store.read_save(_selected)
	_saved_detail.text = SaveCodec.summary(saved["save"]) if saved["ok"] else ("这段生活还没有自动进度。" if saved.get("error") in ["empty_slot", "storage_unavailable"] else saved.get("message", "进度暂不可用。"))
	if _mobile:
		_saved_detail.visible = saved["ok"]
		if saved["ok"]: _saved_detail.text = "已有进度 · 第%d天" % saved["save"]["payload"]["day"]
	else: _saved_detail.show()
	_main_start.text = "继续这一周" if saved["ok"] else "开始这一周"
	_main_start.disabled = _save_store.status() in ["loading", "opening"] or Catalog.get_story(_selected).is_empty()
	_restart.visible = saved["ok"]
	_details.scroll_vertical = 0


func _step_character(direction: int) -> void:
	if _groups.is_empty(): return
	var index := _groups.find(_current_group())
	var next_index := clampi(index + direction, 0, _groups.size() - 1)
	if next_index < 0: return
	var id: String = _groups[next_index]["id"]
	_select_character(id)
	_strips[id].grab_focus()
	call_deferred("_reveal_character", id)


func _reveal_character(id: String) -> void:
	if _page == "characters" and _strips.has(id): _rail.ensure_control_visible(_strips[id])


func _show_title() -> void:
	if _starting: return
	_page = "title"
	_title_page.show()
	_selection_page.hide()
	_backdrop.show()
	_title_wash.show()
	_backdrop.enabled = true
	_base_background.color = Color("#efe5d0")
	_selection_environment.hide()
	_selection_veil.hide()
	_title_start.call_deferred("grab_focus")


func _show_characters() -> void:
	if _starting: return
	_page = "characters"
	_title_page.hide()
	_selection_page.show()
	_backdrop.hide()
	_title_wash.hide()
	_backdrop.enabled = false
	_base_background.color = Color("#efe5d0")
	_selection_environment.show()
	_selection_veil.show()
	_roster_hint.text = "%d位人物 · 每段生活的进度分别保存" % _groups.size()
	_refresh_details()
	_update_strips()
	if _strips.has(_selected_character): _strips[_selected_character].call_deferred("grab_focus")


func _enter_selected() -> void:
	if _starting or _main_start.disabled or _current_story().is_empty(): return
	var saved: Dictionary = _save_store.read_save(_selected)
	if saved["ok"]: _continue_saved(saved["save"])
	else: _start_week(_selected)


func _request_restart() -> void:
	var saved: Dictionary = _save_store.read_save(_selected)
	if not saved["ok"]: return
	var story := _current_story()
	_present("开始新的一周？", SaveCodec.summary(saved["save"]) + "\n\n自动进度将被新的这一周替换，手动存档保留。", [{"id": "restart", "text": "开始新的一周"}, {"id": "cancel", "text": "保留现在的进度"}], func(choice: String) -> void:
		if choice == "restart": _intro(story, true)
	)


func _start_week(id: String = Catalog.DEFAULT_ID) -> void:
	if _starting or not Session.request(id): return
	_starting = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _continue_saved(snapshot: Dictionary) -> void:
	if _starting or not Session.request_saved(snapshot): return
	_starting = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _apply_responsive_profile() -> void:
	if _applying: return
	_applying = true
	var physical := DisplayServer.window_get_size()
	_mobile = physical.y > physical.x * 1.18
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().content_scale_size = Vector2i(720, 1280) if _mobile else Vector2i(1920, 1080)
	_configure_layout(_mobile)
	_applying = false


func _configure_layout(mobile: bool) -> void:
	_mobile = mobile
	for page in [_title_page, _selection_page]:
		for side in ["margin_left", "margin_right"]: page.add_theme_constant_override(side, 24 if _mobile else 100)
		for side in ["margin_top", "margin_bottom"]: page.add_theme_constant_override(side, 24 if _mobile else 36)
	_title_layout.columns = 1 if _mobile else 2
	_title_layout.move_child(_title_layout.get_node("MealArtwork"), 0 if _mobile else 1)
	var art := _title_layout.get_node("MealArtwork") as CenterContainer
	art.visible = not _mobile
	art.custom_minimum_size = Vector2.ZERO if _mobile else Vector2(690, 570)
	_title_stack.alignment = BoxContainer.ALIGNMENT_END if _mobile else BoxContainer.ALIGNMENT_CENTER
	_title_copy.add_theme_constant_override("separation", 12 if _mobile else 20)
	_subtitle.text = "安排三餐，也安排自己的一周。" if _mobile else "选一段生活，安排三餐、日常任务和休息。"
	_backdrop.set_mobile(_mobile)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.36, 0.56, 1]) if _mobile else PackedFloat32Array([0, 0.38, 0.61, 1])
	gradient.colors = PackedColorArray([Color(0.961, 0.925, 0.851, 0), Color(0.961, 0.925, 0.851, 0.35), Color(0.961, 0.925, 0.851, 0.96), Color(0.961, 0.925, 0.851, 1)]) if _mobile else PackedColorArray([Color(0.961, 0.925, 0.851, 0.94), Color(0.961, 0.925, 0.851, 0.88), Color(0.961, 0.925, 0.851, 0.18), Color(0.961, 0.925, 0.851, 0)])
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.fill_from = Vector2.ZERO
	wash.fill_to = Vector2(0, 1) if _mobile else Vector2(1, 0)
	_title_wash.texture = wash
	_title_wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scene_caption.visible = not _mobile
	_title.add_theme_font_size_override("font_size", 84 if _mobile else 108)
	_tagline.add_theme_font_size_override("font_size", 32 if _mobile else 39)
	_subtitle.add_theme_font_size_override("font_size", 26 if _mobile else 29)
	_tagline.visible = not _mobile
	_subtitle.visible = not _mobile
	for child in _title_copy.get_children():
		if child is Label: child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if _mobile else HORIZONTAL_ALIGNMENT_LEFT
	_title_start.custom_minimum_size.y = 96
	_title_start.custom_minimum_size.x = 0 if _mobile else 520
	_title_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _mobile else Control.SIZE_SHRINK_BEGIN
	_title_continue.custom_minimum_size.y = 90
	_title_start.add_theme_font_size_override("font_size", 30)
	_title_continue.add_theme_font_size_override("font_size", 26)
	_quit_button.visible = not _mobile and not OS.has_feature("web")
	_body_grid.columns = 1 if _mobile else 2
	_rail.custom_minimum_size.y = 430 if _mobile else 610
	_details.custom_minimum_size = Vector2(0, 180) if _mobile else Vector2(470, 0)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _mobile else Control.SIZE_FILL
	_story_title.add_theme_font_size_override("font_size", 43 if _mobile else 52)
	_goal.add_theme_font_size_override("font_size", 27 if _mobile else 30)
	_learning.add_theme_font_size_override("font_size", 23 if _mobile else 24)
	_learning.visible = not _mobile
	_details_body.add_theme_constant_override("separation", 8 if _mobile else 15)
	_main_start.custom_minimum_size.y = 88 if _mobile else 80
	_main_start.custom_minimum_size.x = 0 if _mobile else 470
	_main_start.add_theme_font_size_override("font_size", 32)
	_main_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _mobile else Control.SIZE_SHRINK_END
	_save_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if _mobile else HORIZONTAL_ALIGNMENT_RIGHT
	for button in [_more_info, _other_saves, _restart, _previous, _next]: button.custom_minimum_size.y = 80 if _mobile else 64
	_back_button.custom_minimum_size.y = 76 if _mobile else 64
	_update_strips()


func _load_saved_cards() -> void:
	var ready: bool = await _save_store.wait_until_ready()
	_save_hint.text = "选择人物，再开始或继续这一周。" if ready else "本次暂不能保存进度，可用存档文件备份。"
	_latest_save = {}
	for story in Catalog.all():
		var saved: Dictionary = _save_store.read_save(story["id"])
		if saved["ok"] and ( _latest_save.is_empty() or saved["save"]["saved_at"] > _latest_save["saved_at"]): _latest_save = saved["save"]
	_title_continue.visible = not _latest_save.is_empty()
	if not _latest_save.is_empty():
		var story := Catalog.get_story(_latest_save["story_id"])
		_title_continue.text = "继续上次 · %s · 第%d天" % [story.get("character_short_name", story["character_name"]), _latest_save["payload"]["day"]]
	_title_hint.text = "每段生活的进度分别保存。" if ready else "本次可游玩，建议导出文件保留进度。"
	_refresh_details()


func _unhandled_key_input(event: InputEvent) -> void:
	if _starting or _dialog.visible: return
	if _page == "characters" and event.is_action_pressed("ui_cancel", true):
		get_viewport().set_input_as_handled()
		if not event.is_echo(): _show_title()


func _process(_delta: float) -> void:
	if is_instance_valid(_backdrop): _backdrop.enabled = _page == "title" and not _dialog.visible and not _starting


func _present(title: String, body: String, choices: Array, handler: Callable) -> void:
	_choice_handler = handler
	_dialog.present(title, body, choices)


func _intro(story: Dictionary, can_start: bool = false) -> void:
	_selected = String(story["id"])
	var choices: Array = []
	if can_start: choices.append({"id": "start", "text": "开始这一周"})
	choices.append({"id": "back", "text": "返回选人"})
	_present(String(story["title"]), "本周目标\n" + String(story["goal"]) + "\n\n生活条件\n" + String(story["conditions"]) + "\n\n本篇科普\n" + String(story["learning"]) + "\n\n一局七天；查看和预览不扣钱，确认后才结算。", choices, func(choice: String) -> void:
		if choice == "start": _start_week(_selected)
	)


func _show_slots(id: String) -> void:
	var choices: Array = []
	var body := "选择要继续的进度。"
	for slot in SaveStore.SLOTS:
		var saved: Dictionary = _save_store.read_save(id, slot)
		var label: String = "自动存档" if slot == "auto" else "存档 " + slot.trim_prefix("manual_")
		if saved["ok"]: body += "\n\n" + label + "\n" + SaveCodec.summary(saved["save"])
		choices.append({"id": slot, "text": label, "enabled": saved["ok"]})
	choices.append({"id": "back", "text": "回到故事选择"})
	_present("读取已有进度", body, choices, func(slot: String) -> void:
		if slot != "back":
			var saved: Dictionary = _save_store.read_save(id, slot)
			if saved["ok"]: _continue_saved(saved["save"])
	)


func _import_file() -> void:
	if OS.has_feature("web"):
		var result: Dictionary = await _save_store.pick_web_file()
		if result.get("ok", false): _preview_import(String(result["text"]))
		elif result.get("error") != "cancelled": _present("文件未能读取", "可以重新选择存档文件。", [{"id": "close", "text": "回到故事选择"}], func(_id: String) -> void: pass)
	else:
		var picker := FileDialog.new()
		picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		picker.access = FileDialog.ACCESS_FILESYSTEM
		picker.filters = PackedStringArray(["*.json ; 游戏存档"])
		picker.file_selected.connect(func(path: String) -> void:
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null and file.get_length() <= SaveCodec.MAX_BYTES: _preview_import(file.get_as_text())
			else: _present("文件未能读取", "文件无法读取或过大。", [{"id": "close", "text": "回到故事选择"}], func(_id: String) -> void: pass)
			picker.queue_free()
		)
		picker.canceled.connect(picker.queue_free)
		add_child(picker)
		picker.popup_centered(Vector2i(680, 480))


func _preview_import(text: String) -> void:
	var checked := SaveCodec.decode(text)
	if not checked["ok"]:
		_present("进度文件不可用", checked["message"], [{"id": "close", "text": "回到故事选择"}], func(_id: String) -> void: pass)
		return
	var snapshot: Dictionary = checked["save"]
	var choices: Array = []
	for slot in ["manual_1", "manual_2", "manual_3"]:
		choices.append({"id": slot, "text": "导入到存档 " + slot.trim_prefix("manual_")})
	choices.append({"id": "cancel", "text": "取消导入"})
	_present("导入这份进度？", SaveCodec.summary(snapshot), choices, func(slot: String) -> void:
		if slot == "cancel": return
		var previous: Dictionary = _save_store.read_save(snapshot["story_id"], slot)
		if previous["ok"] or _save_store.slot_has_data(snapshot["story_id"], slot):
			var old_summary := SaveCodec.summary(previous["save"]) if previous["ok"] else "这个位置有暂时无法读取的存档。"
			_present("替换这份存档？", old_summary, [{"id": "import", "text": "替换并继续"}, {"id": "cancel", "text": "保留原有进度"}], func(choice: String) -> void:
				if choice == "import": _finish_import(snapshot, slot)
			)
		else: _finish_import(snapshot, slot)
	)


func _finish_import(snapshot: Dictionary, slot: String) -> void:
	_present("正在导入", "请稍候。", [], func(_id: String) -> void: pass)
	var result: Dictionary = await _save_store.write_save(snapshot, slot)
	if result["ok"]: _continue_saved(snapshot)
	else: _present("尚未导入", String(result.get("message", "请稍后重试。")), [{"id": "close", "text": "回到故事选择"}], func(_id: String) -> void: pass)
