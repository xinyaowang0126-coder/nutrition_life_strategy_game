extends Control

const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Session := preload("res://scripts/stories/StorySession.gd")
const Dialog := preload("res://scripts/stories/StoryDialog.gd")
const SaveStore := preload("res://scripts/stories/GameSaveStore.gd")
const SaveCodec := preload("res://scripts/stories/GameSaveCodec.gd")
const GAME_SCENE := "res://scenes/game_v2/GameRootV2.tscn"
var _grid: GridContainer
var _margin: MarginContainer
var _dialog: StoryDialog
var _selected := ""
var _starting := false
var _applying := false
var _save_store: RefCounted
var _save_hint: Label
var _choice_handler: Callable


func _ready() -> void:
	_save_store = SaveStore.new()
	var background := ColorRect.new()
	background.color = Color("#68745c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_margin.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 22)
	scroll.add_child(stack)
	var title := Label.new()
	title.text = "好好吃饭"
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_font_override("font", HouseholdUI.TITLE_FONT)
	title.add_theme_color_override("font_color", Color("#f1dfbd"))
	stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "营养科普生活策略游戏\n选一个生活故事，安排三餐、日常任务和休息。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color("#f1dfbd"))
	stack.add_child(subtitle)
	_grid = GridContainer.new()
	_grid.name = "Stories"
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 24)
	_save_hint = Label.new()
	_save_hint.text = "正在读取进度…"
	_save_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_hint.add_theme_font_size_override("font_size", 23)
	_save_hint.add_theme_color_override("font_color", Color("#f1dfbd"))
	stack.add_child(_save_hint)
	var import_button := Button.new()
	import_button.text = "导入存档文件"
	import_button.name = "ImportSave"
	import_button.custom_minimum_size.y = 60
	import_button.pressed.connect(_import_file)
	HouseholdUI.style_button(import_button)
	stack.add_child(_grid)
	stack.add_child(import_button)
	_rebuild_story_cards()
	if not OS.has_feature("web"):
		var quit := Button.new()
		quit.text = "退出"
		quit.custom_minimum_size.y = 52
		HouseholdUI.style_button(quit)
		quit.pressed.connect(func() -> void: get_tree().quit())
		stack.add_child(quit)
	_dialog = Dialog.new()
	_dialog.name = "StoryIntro"
	add_child(_dialog)
	_dialog.chosen.connect(func(choice: String) -> void:
		var handler := _choice_handler
		_choice_handler = Callable()
		if handler.is_valid(): handler.call(choice)
	)
	get_viewport().size_changed.connect(_apply_responsive_profile)
	_apply_responsive_profile()
	call_deferred("_load_saved_cards")


func _add_story(story: Dictionary) -> void:
	var paper := PanelContainer.new()
	paper.name = String(story["id"])
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", HouseholdUI.paper(HouseholdUI.PAPER, 24))
	_grid.add_child(paper)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	paper.add_child(row)
	var portrait := HouseholdUI.image(load(String(story["portrait"])) as Texture2D, 300)
	portrait.name = "Portrait"
	portrait.custom_minimum_size.x = 170
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
	row.add_child(stack)
	stack.add_child(HouseholdUI.label(String(story["character_name"]) + "  /  " + String(story["subtitle"]), 23, HouseholdUI.GREEN))
	stack.add_child(HouseholdUI.label(String(story["title"]), 39, HouseholdUI.INK, true))
	stack.add_child(HouseholdUI.label(String(story["goal"]).replace("，", "，\n"), 24))
	stack.add_child(HouseholdUI.label(String(story["conditions"]), 20, HouseholdUI.MUTED))
	var saved: Dictionary = _save_store.read_save(String(story["id"]))
	if saved["ok"]:
		stack.add_child(HouseholdUI.label(SaveCodec.summary(saved["save"]) + ("\n可从上一份有效备份继续" if saved.get("backup", false) else ""), 20, HouseholdUI.MUTED))
	elif saved.get("error") not in ["empty_slot", "storage_unavailable"]:
		stack.add_child(HouseholdUI.label(String(saved.get("message", "这份进度暂时无法读取。")), 20, HouseholdUI.DANGER))
	var button := HouseholdUI.button("继续这一周" if saved["ok"] else "进入这段生活", "ChooseStory", true)
	button.disabled = _save_store.status() in ["loading", "opening"]
	button.pressed.connect(func() -> void:
		if saved["ok"]: _continue_saved(saved["save"])
		else: _intro(story)
	)
	stack.add_child(button)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	stack.add_child(tools)
	var slots := HouseholdUI.button("其他存档", "OtherSaves")
	slots.add_theme_font_size_override("font_size", 20)
	slots.custom_minimum_size.y = 46
	slots.pressed.connect(func() -> void: _show_slots(String(story["id"])))
	tools.add_child(slots)
	if saved["ok"]:
		var restart := HouseholdUI.button("重新开始", "RestartStory")
		restart.add_theme_font_size_override("font_size", 20)
		restart.custom_minimum_size.y = 46
		restart.pressed.connect(func() -> void:
			_present("开始新的一周？", SaveCodec.summary(saved["save"]) + "\n\n自动进度将被新的这一周替换，手动存档保留。", [{"id": "restart", "text": "开始新的一周"}, {"id": "cancel", "text": "保留现在的进度"}], func(choice: String) -> void:
				if choice == "restart": _intro(story)
			)
		)
		tools.add_child(restart)


func _start_week(id: String = Catalog.DEFAULT_ID) -> void:
	if _starting or not Session.request(id):
		return
	_starting = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _apply_responsive_profile() -> void:
	if _applying:
		return
	_applying = true
	var physical := DisplayServer.window_get_size()
	var mobile := physical.y > physical.x * 1.18
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().content_scale_size = Vector2i(720, 1280) if mobile else Vector2i(1920, 1080)
	_grid.columns = 1 if mobile else 2
	for side in ["margin_left", "margin_right"]:
		_margin.add_theme_constant_override(side, 24 if mobile else 190)
	for side in ["margin_top", "margin_bottom"]:
		_margin.add_theme_constant_override(side, 30 if mobile else 65)
	_applying = false


func _load_saved_cards() -> void:
	var ready: bool = await _save_store.wait_until_ready()
	_save_hint.text = "选择故事继续；每篇进度分别保存。" if ready else "本次暂不能保存进度。可以导入或导出文件备份。"
	_rebuild_story_cards()


func _rebuild_story_cards() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for story in Catalog.all():
		_add_story(story)


func _present(title: String, body: String, choices: Array, handler: Callable) -> void:
	_choice_handler = handler
	_dialog.present(title, body, choices)


func _intro(story: Dictionary) -> void:
	_selected = String(story["id"])
	_present(String(story["title"]), "本周目标\n" + String(story["goal"]) + "\n\n生活条件\n" + String(story["conditions"]) + "\n\n本篇科普\n" + String(story["learning"]) + "\n\n一局七天；查看和预览不扣钱，确认后才结算。", [{"id": "start", "text": "开始这一周"}, {"id": "back", "text": "看看其他故事"}], func(choice: String) -> void:
		if choice == "start": _start_week(_selected)
	)


func _continue_saved(snapshot: Dictionary) -> void:
	if _starting or not Session.request_saved(snapshot):
		return
	_starting = true
	get_tree().change_scene_to_file(GAME_SCENE)


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
