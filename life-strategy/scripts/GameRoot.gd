extends Control

const GameDataScript := preload("res://scripts/GameData.gd")
const MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const BG_PATH := "res://assets/generated/backgrounds/dorm_background.png"
const PORTRAIT_PATH := "res://assets/generated/characters/student_portrait.png"
const METRICS_GUIDE_PATH := "res://assets/generated/ui/metrics_guide.png"
const FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"

const MAX_FOODS_PER_MEAL := 3
const MAX_DAILY_ACTIONS := 3
const PHASE_ORDER := ["breakfast", "breakfast_action", "lunch", "lunch_action", "dinner", "dinner_action", "sleep"]
const PHASE_NAMES := {
	"breakfast": "早餐",
	"breakfast_action": "早餐后行动",
	"lunch": "午餐",
	"lunch_action": "午餐后行动",
	"dinner": "晚餐",
	"dinner_action": "晚餐后行动",
	"action": "行动",
	"sleep": "睡眠",
	"summary": "日结",
	"ending": "结局",
}

const STAT_ORDER := ["stability", "energy", "mood", "satiety", "stress", "diet_burden", "study_progress"]
const HEALTHY_TAGS := ["staple", "protein", "vegetable", "fruit", "fruit_like", "fiber", "whole_grain"]
const COMFORT_TAGS := ["favorite", "instant", "high_sugar", "high_fat", "high_sodium"]

var rng := RandomNumberGenerator.new()
var state: Dictionary = {}
var day := 1
var phase := "breakfast"
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var hand: Array[String] = []
var selected_food_indices: Array[int] = []
var actions_used_today := 0
var drink_water_used := 0
var deck_bias := "normal"
var tomorrow_bias := "normal"
var today_meals: Array[String] = []
var today_meal_quality: Array[int] = []
var today_food_spend := 0
var today_tags: Array[String] = []
var combos_today: Array[String] = []
var daily_summary := ""
var log_entries: Array[String] = []
var low_stability_days := 0
var ending_id := ""
var guide_visible := false

var root_margin: MarginContainer
var header_label: Label
var phase_label: Label
var left_content: VBoxContainer
var center_content: VBoxContainer
var right_content: VBoxContainer


func _ready() -> void:
	rng.randomize()
	_wire_scene_nodes()
	_apply_font()
	_setup_scene_shell()
	start_new_run()


func _apply_font() -> void:
	var font := load(FONT_PATH)
	if font:
		var ui_theme := Theme.new()
		ui_theme.default_font = font
		theme = ui_theme
		add_theme_font_override("font", font)


func _wire_scene_nodes() -> void:
	root_margin = $RootMargin
	header_label = $RootMargin/RootBox/HeaderPanel/HeaderRow/HeaderLabel
	phase_label = $RootMargin/RootBox/HeaderPanel/HeaderRow/PhaseLabel
	left_content = $RootMargin/RootBox/Body/LeftPanel/LeftContent
	center_content = $RootMargin/RootBox/Body/CenterPanel/CenterContent
	right_content = $RootMargin/RootBox/Body/RightPanel/RightContent


func _setup_scene_shell() -> void:
	var restart_button: Button = $RootMargin/RootBox/HeaderPanel/HeaderRow/RestartButton
	var menu_button: Button = $RootMargin/RootBox/HeaderPanel/HeaderRow/MenuButton
	restart_button.pressed.connect(start_new_run)
	menu_button.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	_style_existing_button(restart_button, Color(0.36, 0.42, 0.34))
	_style_existing_button(menu_button, Color(0.28, 0.35, 0.32))


func _style_existing_button(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.07)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.10)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.44, 0.43, 0.39)))
	button.add_theme_stylebox_override("focus", _button_style(color.lightened(0.10)))


func start_new_run() -> void:
	state = GameDataScript.get_starting_stats()
	day = 1
	phase = "breakfast"
	draw_pile.clear()
	discard_pile.clear()
	hand.clear()
	selected_food_indices.clear()
	actions_used_today = 0
	drink_water_used = 0
	guide_visible = false
	deck_bias = "normal"
	tomorrow_bias = "normal"
	today_meals.clear()
	today_meal_quality.clear()
	today_food_spend = 0
	today_tags.clear()
	combos_today.clear()
	daily_summary = ""
	log_entries.clear()
	low_stability_days = 0
	ending_id = ""
	_add_log("第 1 天开始。余额不多，但选择权还在。")
	_start_day()
	_refresh_all()


func _start_day() -> void:
	phase = "breakfast"
	actions_used_today = 0
	drink_water_used = 0
	selected_food_indices.clear()
	today_meals.clear()
	today_meal_quality.clear()
	today_food_spend = 0
	today_tags.clear()
	combos_today.clear()
	hand.clear()
	discard_pile.clear()
	_build_draw_pile()
	_refill_hand(6)
	_ensure_affordable_food()
	_update_stability()


func _build_draw_pile() -> void:
	draw_pile.clear()
	for id in GameDataScript.FOOD_IDS:
		var food := GameDataScript.get_food(id)
		var copies := 2
		var cost := int(food["cost"])
		if GameDataScript.has_tag(food, "cheap"):
			copies += 2
		if _has_any_tag(food, HEALTHY_TAGS):
			copies += 1
		if GameDataScript.has_tag(food, "favorite"):
			copies += 1
		if cost >= 20:
			copies -= 1
		if deck_bias == "balanced" and _has_any_tag(food, HEALTHY_TAGS):
			copies += 2
		if deck_bias == "comfort" and _has_any_tag(food, COMFORT_TAGS):
			copies += 2
		copies = max(1, copies)
		for _i in range(copies):
			draw_pile.append(id)
	draw_pile.shuffle()


func _refill_hand(target_size: int) -> void:
	while hand.size() < target_size:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				_build_draw_pile()
			else:
				draw_pile = discard_pile.duplicate()
				discard_pile.clear()
				draw_pile.shuffle()
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())


func _ensure_affordable_food() -> void:
	for id in hand:
		if int(GameDataScript.get_food(id)["cost"]) <= int(state["balance"]):
			return
	if int(state["balance"]) >= GameDataScript.cheapest_food_cost():
		hand.append("rice_plain")


func _refresh_all() -> void:
	_refresh_header()
	_rebuild_left()
	_rebuild_center()
	_rebuild_right()


func _refresh_header() -> void:
	var current_phase: String = String(PHASE_NAMES.get(phase, phase))
	header_label.text = "撑过这一周  第 %d/%d 天" % [day, GameDataScript.TOTAL_DAYS]
	phase_label.text = "%s  |  余额 ¥%d  |  手牌 %d  |  行动 %d/%d" % [
		current_phase,
		int(state["balance"]),
		hand.size(),
		actions_used_today,
		MAX_DAILY_ACTIONS,
	]


func _rebuild_left() -> void:
	_clear_children(left_content)
	_add_heading(left_content, "角色状态", 24)

	var portrait := TextureRect.new()
	portrait.texture = load(PORTRAIT_PATH)
	portrait.custom_minimum_size = Vector2(0, 160)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	left_content.add_child(portrait)

	for key in STAT_ORDER:
		_add_stat_bar(key)

	var detail := Label.new()
	detail.text = "抽牌 %d  弃牌 %d\n今日餐费 ¥%d  行动 %d/%d\n明日倾向：%s" % [
		draw_pile.size(),
		discard_pile.size(),
		today_food_spend,
		actions_used_today,
		MAX_DAILY_ACTIONS,
		_bias_name(tomorrow_bias),
	]
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", Color(0.23, 0.26, 0.22))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_content.add_child(detail)

	var hint := Label.new()
	hint.text = _left_hint()
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.41, 0.33, 0.23))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_content.add_child(hint)

	var guide_button := _make_button("指标说明", Color(0.43, 0.49, 0.38))
	guide_button.custom_minimum_size = Vector2(0, 42)
	guide_button.pressed.connect(_open_metrics_guide)
	left_content.add_child(guide_button)


func _add_stat_bar(key: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	left_content.add_child(row)

	var label := Label.new()
	label.text = "%s  %d" % [GameDataScript.STAT_LABELS[key], int(state[key])]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", _stat_color(key, int(state[key])))
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = float(state[key])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.add_theme_stylebox_override("background", _bar_bg_style())
	bar.add_theme_stylebox_override("fill", _bar_fill_style(_stat_color(key, int(state[key]))))
	row.add_child(bar)


func _rebuild_center() -> void:
	_clear_children(center_content)
	if guide_visible:
		_build_metrics_guide_center()
		return
	if phase == "ending":
		_build_ending_center()
		return

	_add_heading(center_content, _center_title(), 26)
	var prompt := Label.new()
	prompt.text = _phase_prompt()
	prompt.add_theme_font_size_override("font_size", 17)
	prompt.add_theme_color_override("font_color", Color(0.24, 0.27, 0.23))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_content.add_child(prompt)

	if _is_meal_phase():
		_build_food_choices()
	elif _is_action_phase():
		_build_action_choices()
	elif phase == "sleep":
		_build_sleep_choices()
	elif phase == "summary":
		_build_summary_center()


func _build_food_choices() -> void:
	var selection_status := Label.new()
	selection_status.text = "本餐可选 1-%d 种食物。已选 %d 种，预计花费 ¥%d。" % [
		MAX_FOODS_PER_MEAL,
		selected_food_indices.size(),
		_selected_food_cost(),
	]
	selection_status.add_theme_font_size_override("font_size", 16)
	selection_status.add_theme_color_override("font_color", Color(0.33, 0.30, 0.24))
	selection_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_content.add_child(selection_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_content.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for index in range(hand.size()):
		grid.add_child(_make_food_card(hand[index], index))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	center_content.add_child(row)

	var skip_button := _make_button("跳过这餐", Color(0.41, 0.39, 0.34))
	skip_button.pressed.connect(_skip_meal)
	row.add_child(skip_button)

	var confirm_button := _make_button("确认进餐", Color(0.78, 0.31, 0.20))
	if not selected_food_indices.is_empty():
		confirm_button.text = "确认 %d 项" % selected_food_indices.size()
	confirm_button.disabled = selected_food_indices.is_empty()
	confirm_button.pressed.connect(_confirm_food)
	row.add_child(confirm_button)


func _make_food_card(id: String, hand_index: int = -1) -> PanelContainer:
	var food := GameDataScript.get_food(id)
	var selected := selected_food_indices.has(hand_index)
	var can_toggle := selected or _can_add_food(hand_index)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 390)
	panel.add_theme_stylebox_override("panel", _card_style(selected, can_toggle))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var image := TextureRect.new()
	image.texture = load(String(food["image"]))
	image.custom_minimum_size = Vector2(0, 190)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(image)

	var title := Label.new()
	title.text = "%s  ¥%d" % [String(food["name"]), int(food["cost"])]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.16, 0.19, 0.16))
	title.clip_text = true
	box.add_child(title)

	var stats := Label.new()
	stats.text = "饱%s 精%s 心%s 负%s" % [
		_delta_text(int(food["satiety"])),
		_delta_text(int(food["energy"])),
		_delta_text(int(food["mood"])),
		_delta_text(int(food["burden"])),
	]
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", Color(0.38, 0.31, 0.23))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stats)

	var desc := Label.new()
	desc.text = String(food["desc"])
	desc.custom_minimum_size = Vector2(0, 64)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.31, 0.32, 0.27))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	var button := _make_button(_food_button_text(hand_index), Color(0.66, 0.38, 0.18))
	button.disabled = not can_toggle
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(func(): _toggle_food_selection(hand_index))
	box.add_child(button)

	return panel


func _build_action_choices() -> void:
	var status := Label.new()
	status.text = "%s：选择 1 项活动后进入下一段。今日行动 %d/%d。" % [
		String(PHASE_NAMES.get(phase, "餐后行动")),
		actions_used_today,
		MAX_DAILY_ACTIONS,
	]
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", Color(0.25, 0.29, 0.24))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_content.add_child(status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_content.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for id in GameDataScript.ACTION_IDS:
		grid.add_child(_make_action_card(id))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	center_content.add_child(row)
	var finish := _make_button("跳过行动", Color(0.72, 0.31, 0.20))
	finish.pressed.connect(_skip_action)
	row.add_child(finish)


func _make_action_card(id: String) -> PanelContainer:
	var action := GameDataScript.get_action(id)
	var can_use := _can_use_action(action)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 330)
	panel.add_theme_stylebox_override("panel", _card_style(false, can_use))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var image := TextureRect.new()
	image.texture = load(String(action["image"]))
	image.custom_minimum_size = Vector2(0, 150)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(image)

	var title := Label.new()
	title.text = "%s  行动 1" % String(action["name"])
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.16, 0.19, 0.16))
	title.clip_text = true
	box.add_child(title)

	var stats := Label.new()
	stats.text = "精%s 心%s 压%s 学%s" % [
		_delta_text(int(action["energy"])),
		_delta_text(int(action["mood"])),
		_delta_text(int(action["stress"])),
		_delta_text(int(action["study"])),
	]
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", Color(0.38, 0.31, 0.23))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stats)

	var desc := Label.new()
	desc.text = String(action["desc"])
	desc.custom_minimum_size = Vector2(0, 54)
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.31, 0.32, 0.27))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	var button := _make_button(_action_button_text(action, can_use), Color(0.56, 0.42, 0.22))
	button.custom_minimum_size = Vector2(0, 38)
	button.disabled = not can_use
	button.pressed.connect(func(): _apply_action(id))
	box.add_child(button)
	return panel


func _build_sleep_choices() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	center_content.add_child(row)

	for id in GameDataScript.SLEEP_OPTIONS.keys():
		row.add_child(_make_sleep_card(id))


func _make_sleep_card(id: String) -> PanelContainer:
	var option := GameDataScript.get_sleep_option(id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 360)
	panel.add_theme_stylebox_override("panel", _card_style(false, true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = String(option["name"])
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.18, 0.21, 0.17))
	box.add_child(title)

	var stats := Label.new()
	stats.text = "精力%s\n心情%s\n压力%s\n复习%s\n饱腹%s" % [
		_delta_text(int(option["energy"])),
		_delta_text(int(option["mood"])),
		_delta_text(int(option["stress"])),
		_delta_text(int(option["study"])),
		_delta_text(int(option["satiety"])),
	]
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color(0.35, 0.29, 0.22))
	box.add_child(stats)

	var desc := Label.new()
	desc.text = String(option["desc"])
	desc.custom_minimum_size = Vector2(0, 100)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.29, 0.31, 0.26))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	var button := _make_button("选择", Color(0.70, 0.30, 0.20))
	button.pressed.connect(func(): _choose_sleep(id))
	box.add_child(button)
	return panel


func _build_summary_center() -> void:
	var label := Label.new()
	label.text = daily_summary
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.20, 0.23, 0.20))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_content.add_child(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	center_content.add_child(row)
	var next_button := _make_button("进入第 %d 天" % (day + 1), Color(0.74, 0.30, 0.19))
	next_button.pressed.connect(_next_day)
	row.add_child(next_button)


func _build_ending_center() -> void:
	var ending := GameDataScript.get_ending(ending_id)
	_add_heading(center_content, String(ending["title"]), 34)

	var image := TextureRect.new()
	image.texture = load(String(ending["image"]))
	image.custom_minimum_size = Vector2(0, 430)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	center_content.add_child(image)

	var text := Label.new()
	text.text = "%s\n\n最终稳定度 %d  |  复习进度 %d  |  余额 ¥%d\n%s" % [
		String(ending["subtitle"]),
		int(state["stability"]),
		int(state["study_progress"]),
		int(state["balance"]),
		daily_summary,
	]
	text.add_theme_font_size_override("font_size", 21)
	text.add_theme_color_override("font_color", Color(0.20, 0.23, 0.20))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_content.add_child(text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	center_content.add_child(row)

	var restart := _make_button("再来一周", Color(0.76, 0.31, 0.19))
	restart.pressed.connect(start_new_run)
	row.add_child(restart)

	var menu := _make_button("回主菜单", Color(0.34, 0.40, 0.35))
	menu.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	row.add_child(menu)


func _open_metrics_guide() -> void:
	guide_visible = true
	_refresh_all()


func _close_metrics_guide() -> void:
	guide_visible = false
	_refresh_all()


func _build_metrics_guide_center() -> void:
	_add_heading(center_content, "指标说明", 30)

	var image := TextureRect.new()
	image.texture = load(METRICS_GUIDE_PATH)
	image.custom_minimum_size = Vector2(0, 340)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	center_content.add_child(image)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_content.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var guide := Label.new()
	guide.text = "稳定度：综合健康、心情、压力、预算和复习的安全线。低于 30 要优先止损。\n精力：影响白天行动承受力，复习和熬夜会消耗，睡眠和小睡能恢复。\n心情：代表主观撑下去的余量。快乐食物和放松会提升，但不一定长期稳定。\n饱腹：太低会带来压力和掉状态，太高也可能增加饮食负担。\n压力：越高越危险。复习、预算紧张和跳餐会升高，散步、睡眠和允许不完美会降低。\n饮食负担：高糖、高油、高盐和连续速食会堆积；蔬果、喝水、散步和规律睡眠能缓解。\n复习进度：决定结局门槛，但强推复习会透支其他指标。\n\n餐食：每餐最多选择 %d 种食物，组合主食、蛋白、蔬果更稳。\n行动：三餐后各有一次机会，每天最多 %d 次。跳过不扣次数。" % [
		MAX_FOODS_PER_MEAL,
		MAX_DAILY_ACTIONS,
	]
	guide.add_theme_font_size_override("font_size", 18)
	guide.add_theme_color_override("font_color", Color(0.20, 0.23, 0.20))
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(guide)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	center_content.add_child(row)
	var close := _make_button("返回", Color(0.34, 0.40, 0.35))
	close.pressed.connect(_close_metrics_guide)
	row.add_child(close)


func _rebuild_right() -> void:
	_clear_children(right_content)
	_add_heading(right_content, "今日记录", 22)

	var meals := Label.new()
	if today_meals.is_empty():
		meals.text = "还没吃东西。"
	else:
		meals.text = "\n".join(today_meals)
	meals.add_theme_font_size_override("font_size", 16)
	meals.add_theme_color_override("font_color", Color(0.24, 0.27, 0.23))
	meals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_content.add_child(meals)

	_add_heading(right_content, "状态提示", 20)
	var signals := Label.new()
	signals.text = _signals_text()
	signals.add_theme_font_size_override("font_size", 15)
	signals.add_theme_color_override("font_color", Color(0.34, 0.30, 0.24))
	signals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_content.add_child(signals)

	_add_heading(right_content, "日志", 20)
	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_content.add_child(log_scroll)
	var log_box := VBoxContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.add_theme_constant_override("separation", 6)
	log_scroll.add_child(log_box)
	for entry in log_entries:
		var label := Label.new()
		label.text = entry
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.25, 0.28, 0.24))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_box.add_child(label)


func _selected_food_cost() -> int:
	var total := 0
	for index in selected_food_indices:
		if index >= 0 and index < hand.size():
			total += int(GameDataScript.get_food(hand[index])["cost"])
	return total


func _can_add_food(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	if selected_food_indices.has(hand_index):
		return true
	if selected_food_indices.size() >= MAX_FOODS_PER_MEAL:
		return false
	var food := GameDataScript.get_food(hand[hand_index])
	return _selected_food_cost() + int(food["cost"]) <= int(state["balance"])


func _food_button_text(hand_index: int) -> String:
	if selected_food_indices.has(hand_index):
		return "移除"
	if hand_index < 0 or hand_index >= hand.size():
		return "不可用"
	var food := GameDataScript.get_food(hand[hand_index])
	if int(food["cost"]) > int(state["balance"]):
		return "余额不足"
	if selected_food_indices.size() >= MAX_FOODS_PER_MEAL:
		return "已满"
	if _selected_food_cost() + int(food["cost"]) > int(state["balance"]):
		return "预算不足"
	return "加入"


func _toggle_food_selection(hand_index: int) -> void:
	if selected_food_indices.has(hand_index):
		selected_food_indices.erase(hand_index)
	elif _can_add_food(hand_index):
		selected_food_indices.append(hand_index)
	_refresh_all()


func _confirm_food() -> void:
	if selected_food_indices.is_empty():
		return
	var selected_indices: Array[int] = []
	for index in selected_food_indices:
		if index >= 0 and index < hand.size():
			selected_indices.append(index)
	if selected_indices.is_empty():
		selected_food_indices.clear()
		_refresh_all()
		return
	selected_indices.sort()

	var foods: Array[Dictionary] = []
	var food_ids: Array[String] = []
	var food_names: Array[String] = []
	var food_qualities: Array[int] = []
	var total_cost := 0
	for index in selected_indices:
		var selected_food_id: String = hand[index]
		var food := GameDataScript.get_food(selected_food_id)
		foods.append(food)
		food_ids.append(selected_food_id)
		food_names.append(String(food["name"]))
		food_qualities.append(_food_quality(food))
		total_cost += int(food["cost"])

	if total_cost > int(state["balance"]):
		_add_log("余额不够，换个更稳的选择。")
		_refresh_all()
		return

	var meal_phase := phase
	for food in foods:
		_apply_food(food, false)
	var meal_quality := _average_scores(food_qualities)
	today_meal_quality.append(meal_quality)
	today_meals.append("%s：%s  质量 %d" % [PHASE_NAMES[meal_phase], " + ".join(food_names), meal_quality])
	_add_log("%s选择了%s。" % [PHASE_NAMES[meal_phase], " + ".join(food_names)])

	selected_indices.reverse()
	for index in selected_indices:
		discard_pile.append(hand[index])
		hand.remove_at(index)
	selected_food_indices.clear()
	_refill_hand(6)
	_ensure_affordable_food()
	_advance_from_meal()


func _apply_food(food: Dictionary, record_entry := true) -> void:
	state["balance"] = int(state["balance"]) - int(food["cost"])
	state["satiety"] = int(state["satiety"]) + int(food["satiety"])
	state["energy"] = int(state["energy"]) + int(food["energy"])
	state["mood"] = int(state["mood"]) + int(food["mood"])
	state["diet_burden"] = int(state["diet_burden"]) + int(food["burden"])
	if food.has("stress"):
		state["stress"] = int(state["stress"]) + int(food["stress"])

	today_food_spend += int(food["cost"])
	for tag in food["tags"]:
		if not today_tags.has(String(tag)):
			today_tags.append(String(tag))
	var quality := _food_quality(food)
	if record_entry:
		today_meal_quality.append(quality)
		today_meals.append("%s：%s  质量 %d" % [PHASE_NAMES[phase], String(food["name"]), quality])
		_add_log("%s选择了%s。" % [PHASE_NAMES[phase], String(food["name"])])
	_check_daily_combos(food)
	_clamp_stats()
	_update_stability()


func _skip_meal() -> void:
	state["satiety"] = int(state["satiety"]) - 16
	state["energy"] = int(state["energy"]) - 5
	state["mood"] = int(state["mood"]) - 4
	state["stress"] = int(state["stress"]) + 7
	today_meal_quality.append(25)
	today_meals.append("%s：跳过  质量 25" % PHASE_NAMES[phase])
	_add_log("%s跳过了，压力和饥饿感上来了。" % PHASE_NAMES[phase])
	selected_food_indices.clear()
	_clamp_stats()
	_update_stability()
	_advance_from_meal()


func _advance_from_meal() -> void:
	if phase == "breakfast":
		phase = "breakfast_action"
	elif phase == "lunch":
		phase = "lunch_action"
	else:
		phase = "dinner_action"
	_refill_hand(6)
	_ensure_affordable_food()
	_refresh_all()


func _apply_action(id: String) -> void:
	var action := GameDataScript.get_action(id)
	if not _can_use_action(action):
		return
	actions_used_today += 1
	if id == "drink_water":
		drink_water_used += 1

	state["balance"] = int(state["balance"]) - int(action["cost"])
	state["energy"] = int(state["energy"]) + int(action["energy"])
	state["mood"] = int(state["mood"]) + int(action["mood"])
	state["stress"] = int(state["stress"]) + int(action["stress"])
	state["study_progress"] = int(state["study_progress"]) + int(action["study"])
	state["satiety"] = int(state["satiety"]) + int(action["satiety"])
	state["diet_burden"] = int(state["diet_burden"]) + int(action["burden"])

	if id == "go_cafeteria":
		tomorrow_bias = "balanced"
	elif id == "convenience_store":
		tomorrow_bias = "comfort"

	_add_log("行动：%s。" % String(action["name"]))
	_clamp_stats()
	_update_stability()
	_advance_after_action()


func _skip_action() -> void:
	_add_log("%s没有额外安排。" % String(PHASE_NAMES.get(phase, "餐后行动")))
	_advance_after_action()


func _advance_after_action() -> void:
	if phase == "breakfast_action":
		phase = "lunch"
	elif phase == "lunch_action":
		phase = "dinner"
	else:
		phase = "sleep"
	_refresh_all()


func _choose_sleep(id: String) -> void:
	var option := GameDataScript.get_sleep_option(id)
	state["energy"] = int(state["energy"]) + int(option["energy"])
	state["mood"] = int(state["mood"]) + int(option["mood"])
	state["stress"] = int(state["stress"]) + int(option["stress"])
	state["study_progress"] = int(state["study_progress"]) + int(option["study"])
	state["satiety"] = int(state["satiety"]) + int(option["satiety"])
	state["diet_burden"] = int(state["diet_burden"]) + int(option["burden"])
	_add_log("夜晚选择：%s。" % String(option["name"]))
	_finish_day()


func _finish_day() -> void:
	var avg_quality: int = _today_quality_average()
	if avg_quality >= 66:
		state["energy"] = int(state["energy"]) + 4
		state["mood"] = int(state["mood"]) + 4
		state["diet_burden"] = int(state["diet_burden"]) - 2
		_add_log("今天饮食比较稳，身体恢复得更好。")
	elif avg_quality < 42:
		state["stress"] = int(state["stress"]) + 5
		state["diet_burden"] = int(state["diet_burden"]) + 4
		_add_log("今天吃得太乱，身体开始抗议。")

	if int(state["satiety"]) < 20:
		state["stress"] = int(state["stress"]) + 8
		state["mood"] = int(state["mood"]) - 5
	if int(state["satiety"]) > 92:
		state["diet_burden"] = int(state["diet_burden"]) + 4
		state["energy"] = int(state["energy"]) - 3

	var remaining_days: int = max(1, GameDataScript.TOTAL_DAYS - day)
	if int(state["balance"]) < remaining_days * 8:
		state["stress"] = int(state["stress"]) + 5
		state["mood"] = int(state["mood"]) - 2
		_add_log("预算余量偏低，明天会更紧。")

	var target_study: int = day * 9
	if int(state["study_progress"]) < target_study:
		state["stress"] = int(state["stress"]) + 3
	else:
		state["mood"] = int(state["mood"]) + 2

	state["diet_burden"] = int(state["diet_burden"]) - 3
	state["satiety"] = int(state["satiety"]) - 6
	_clamp_stats()
	_update_stability()

	if int(state["stability"]) <= 15:
		low_stability_days += 1
	else:
		low_stability_days = max(0, low_stability_days - 1)

	daily_summary = "第 %d 天结束。\n\n饮食平均质量：%d\n稳定度：%d\n复习进度：%d\n余额：¥%d\n\n%s" % [
		day,
		avg_quality,
		int(state["stability"]),
		int(state["study_progress"]),
		int(state["balance"]),
		_summary_advice(avg_quality),
	]

	if low_stability_days >= 2:
		_finish_run("collapsed")
	elif day >= GameDataScript.TOTAL_DAYS:
		_finish_run(_select_ending())
	else:
		phase = "summary"
		deck_bias = tomorrow_bias
		tomorrow_bias = "normal"
		_refresh_all()


func _next_day() -> void:
	day += 1
	_add_log("第 %d 天开始。" % day)
	_start_day()
	_refresh_all()


func _finish_run(result: String) -> void:
	ending_id = result
	phase = "ending"
	_add_log("一周结束：%s。" % String(GameDataScript.ENDINGS[ending_id]["title"]))
	_refresh_all()


func _select_ending() -> String:
	if int(state["stability"]) <= 15:
		return "collapsed"
	if int(state["study_progress"]) < 45:
		return "collapsed"
	if int(state["study_progress"]) >= 72 and int(state["stability"]) >= 60 and int(state["diet_burden"]) <= 60:
		return "stable_endurance"
	if int(state["study_progress"]) >= 50 and int(state["stability"]) >= 25:
		return "barely_survived"
	return "collapsed"


func _check_daily_combos(food: Dictionary) -> void:
	if not combos_today.has("balanced_plate"):
		if today_tags.has("staple") and today_tags.has("protein") and (today_tags.has("vegetable") or today_tags.has("fruit") or today_tags.has("fruit_like")):
			combos_today.append("balanced_plate")
			state["energy"] = int(state["energy"]) + 5
			state["mood"] = int(state["mood"]) + 3
			state["diet_burden"] = int(state["diet_burden"]) - 2
			_add_log("触发组合：主食 + 蛋白 + 蔬果，今天底盘更稳。")

	if not combos_today.has("comfort_chain") and _today_comfort_count() >= 2:
		combos_today.append("comfort_chain")
		state["mood"] = int(state["mood"]) + 4
		state["diet_burden"] = int(state["diet_burden"]) + 3
		_add_log("连续快乐食物让心情上来了，也留下负担。")

	if not combos_today.has("budget_saver") and today_meals.size() >= 3 and today_food_spend <= 12:
		combos_today.append("budget_saver")
		state["stress"] = int(state["stress"]) - 3
		_add_log("今日餐费控制得很好，预算压力下降。")

	if GameDataScript.has_tag(food, "instant"):
		state["satiety"] = int(state["satiety"]) + 8
		state["diet_burden"] = int(state["diet_burden"]) + 2


func _food_quality(food: Dictionary) -> int:
	var quality := 48
	if GameDataScript.has_tag(food, "staple"):
		quality += 8
	if GameDataScript.has_tag(food, "protein"):
		quality += 12
	if GameDataScript.has_tag(food, "vegetable") or GameDataScript.has_tag(food, "fruit") or GameDataScript.has_tag(food, "fruit_like"):
		quality += 13
	if GameDataScript.has_tag(food, "fiber") or GameDataScript.has_tag(food, "whole_grain"):
		quality += 5
	if GameDataScript.has_tag(food, "high_sugar"):
		quality -= 11
	if GameDataScript.has_tag(food, "high_fat"):
		quality -= 10
	if GameDataScript.has_tag(food, "high_sodium"):
		quality -= 8
	if GameDataScript.has_tag(food, "instant"):
		quality -= 6
	if int(food["cost"]) > 22:
		quality -= 2
	return clamp(quality, 20, 95)


func _average_scores(scores: Array[int]) -> int:
	if scores.is_empty():
		return 25
	var total := 0
	for score in scores:
		total += int(score)
	return int(round(float(total) / float(scores.size())))


func _today_quality_average() -> int:
	if today_meal_quality.is_empty():
		return 25
	var total: int = 0
	for score in today_meal_quality:
		total += int(score)
	return int(round(float(total) / float(today_meal_quality.size())))


func _today_comfort_count() -> int:
	var count: int = 0
	for meal_text in today_meals:
		if meal_text.contains("奶茶") or meal_text.contains("方便面") or meal_text.contains("炸鸡"):
			count += 1
	return count


func _update_stability() -> void:
	var avg_quality: float = float(_today_quality_average())
	var mental: float = float(state["mood"]) * 0.55 + (100.0 - float(state["stress"])) * 0.45
	var remaining_days: int = max(1, GameDataScript.TOTAL_DAYS - day + 1)
	var budget_safety: float = clamp(float(state["balance"]) / (float(remaining_days) * 10.0) * 100.0, 0.0, 100.0)
	var diet_control: float = 100.0 - float(state["diet_burden"])
	var score: float = avg_quality * 0.20
	score += mental * 0.25
	score += float(state["energy"]) * 0.20
	score += float(state["satiety"]) * 0.10
	score += diet_control * 0.10
	score += float(state["study_progress"]) * 0.10
	score += budget_safety * 0.05
	if int(state["energy"]) < 16:
		score -= 10
	if int(state["mood"]) < 16:
		score -= 10
	if int(state["satiety"]) < 12:
		score -= 8
	if int(state["stress"]) > 88:
		score -= 10
	if int(state["balance"]) < max(1, remaining_days * 6):
		score -= 8
	state["stability"] = int(round(clamp(score, 0.0, 100.0)))


func _clamp_stats() -> void:
	for key in ["stability", "energy", "mood", "satiety", "stress", "diet_burden", "study_progress"]:
		state[key] = clamp(int(state[key]), 0, 100)
	state["balance"] = clamp(int(state["balance"]), 0, 999)


func _can_use_action(action: Dictionary) -> bool:
	if not _is_action_phase():
		return false
	if int(action["cost"]) > int(state["balance"]):
		return false
	if actions_used_today >= MAX_DAILY_ACTIONS:
		return false
	if String(action["id"]) == "drink_water":
		return drink_water_used < 2
	return true


func _action_button_text(action: Dictionary, can_use: bool) -> String:
	if can_use:
		return "执行"
	if actions_used_today >= MAX_DAILY_ACTIONS:
		return "次数用完"
	if String(action["id"]) == "drink_water" and drink_water_used >= 2:
		return "已达上限"
	if int(action["cost"]) > int(state["balance"]):
		return "余额不足"
	return "不可用"


func _is_meal_phase() -> bool:
	return phase == "breakfast" or phase == "lunch" or phase == "dinner"


func _is_action_phase() -> bool:
	return phase == "breakfast_action" or phase == "lunch_action" or phase == "dinner_action"


func _has_any_tag(item: Dictionary, tags: Array) -> bool:
	for tag in tags:
		if GameDataScript.has_tag(item, String(tag)):
			return true
	return false


func _center_title() -> String:
	if phase == "summary":
		return "今天收尾"
	if _is_action_phase():
		return String(PHASE_NAMES.get(phase, "餐后行动"))
	return "%s选择" % PHASE_NAMES.get(phase, phase)


func _phase_prompt() -> String:
	if phase == "breakfast":
		return "早餐决定上午的底盘。便宜食物能保预算，均衡组合会提升稳定度。"
	if phase == "lunch":
		return "午餐要在复习精力、心情和餐费之间取舍。"
	if phase == "dinner":
		return "晚餐会影响睡眠前状态。高快乐食物能救心情，也会增加饮食负担。"
	if phase == "breakfast_action":
		return "早餐后的行动决定上午节奏。每次餐后只能安排 1 项活动。"
	if phase == "lunch_action":
		return "午餐后选择 1 项活动，在复习推进、恢复和压力之间取舍。"
	if phase == "dinner_action":
		return "晚餐后是今天最后一次行动机会，之后进入睡眠安排。"
	if phase == "sleep":
		return "夜晚是最后一次权衡：恢复、赶进度，或者给自己一点喘息。"
	if phase == "summary":
		return "查看今天的反馈，再进入下一天。"
	return ""


func _left_hint() -> String:
	if int(state["stress"]) >= 75:
		return "压力已经偏高，散步、早睡或允许不完美能帮你止损。"
	if int(state["diet_burden"]) >= 65:
		return "饮食负担偏高，明天尽量补蔬果、水和清淡蛋白。"
	if int(state["balance"]) <= max(8, (GameDataScript.TOTAL_DAYS - day + 1) * 7):
		return "预算余量很窄，低价主食和蛋白会更关键。"
	if int(state["study_progress"]) < day * 8:
		return "复习进度有点落后，但别用崩盘换短期推进。"
	return "当前还能周旋。把三餐、行动和睡眠连起来看，会更稳。"


func _signals_text() -> String:
	var lines: Array[String] = []
	var avg: int = _today_quality_average()
	lines.append("今日饮食均值：%d" % avg)
	if combos_today.has("balanced_plate"):
		lines.append("已触发均衡组合。")
	if combos_today.has("comfort_chain"):
		lines.append("快乐链条生效，注意负担。")
	if combos_today.has("budget_saver"):
		lines.append("餐费控制优秀。")
	if int(state["stability"]) <= 30:
		lines.append("稳定度危险，下一步优先恢复。")
	elif int(state["stability"]) >= 70:
		lines.append("状态良好，可以考虑推进复习。")
	if lines.is_empty():
		return "选择后这里会显示组合和风险提示。"
	return "\n".join(lines)


func _summary_advice(avg_quality: int) -> String:
	if int(state["stability"]) <= 25:
		return "建议：明天先保命。便宜均衡餐、散步、早睡，比强推复习更重要。"
	if int(state["study_progress"]) < day * 9:
		return "建议：状态还撑得住时补一点复习，但别连续熬夜。"
	if avg_quality < 45:
		return "建议：今天饮食太凑合，明天至少补一个蛋白和一个蔬果。"
	if int(state["balance"]) < max(10, (GameDataScript.TOTAL_DAYS - day) * 8):
		return "建议：预算紧了。白米饭、鸡蛋、豆腐、燕麦会成为救命牌。"
	return "建议：今天节奏不错，保持这种有弹性的稳定。"


func _bias_name(id: String) -> String:
	if id == "balanced":
		return "食堂均衡"
	if id == "comfort":
		return "便利店快乐"
	return "普通"


func _add_log(text: String) -> void:
	log_entries.push_front("D%d  %s" % [day, text])
	while log_entries.size() > 12:
		log_entries.pop_back()


func _delta_text(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return "%d" % value


func _stat_color(key: String, value: int) -> Color:
	if key == "stress" or key == "diet_burden":
		if value >= 75:
			return Color(0.78, 0.22, 0.16)
		if value >= 50:
			return Color(0.75, 0.45, 0.14)
		return Color(0.24, 0.49, 0.35)
	if key == "stability":
		if value <= 25:
			return Color(0.78, 0.22, 0.16)
		if value <= 50:
			return Color(0.75, 0.45, 0.14)
		return Color(0.24, 0.49, 0.35)
	if value <= 25:
		return Color(0.78, 0.22, 0.16)
	if value <= 50:
		return Color(0.75, 0.45, 0.14)
	return Color(0.24, 0.49, 0.35)


func _add_heading(parent: Control, text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.16, 0.20, 0.17))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _make_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(146, 44)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.07)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.10)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.44, 0.43, 0.39)))
	button.add_theme_stylebox_override("focus", _button_style(color.lightened(0.10)))
	return button


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.98, 0.86, 0.62, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _panel_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _card_style(selected: bool, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.87, 0.98) if enabled else Color(0.80, 0.78, 0.70, 0.85)
	style.border_color = Color(0.86, 0.32, 0.19, 0.90) if selected else Color(0.72, 0.52, 0.29, 0.58)
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _bar_bg_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.78, 0.72, 0.62, 0.72)
	style.set_corner_radius_all(5)
	return style


func _bar_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
