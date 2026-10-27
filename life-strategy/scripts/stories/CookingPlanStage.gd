class_name CookingPlanStage
extends HouseholdWorktop

signal confirm_requested(ids: Array, storage: String, plan: Dictionary)
const Facts := preload("res://scripts/stories/HouseholdMealFacts.gd")
const CONDIMENT_UNITS := {"salt_g": ["盐", "克"], "soy_ml": ["酱油", "毫升"], "sugar_g": ["白糖", "克"]}
var ids: Array[String] = []
var storage := "eat_now"
var plan: Dictionary = {}
var ingredients_needed: Dictionary = {}
var confirm_button: Button
var option_buttons: Dictionary = {}
var _foods: Dictionary = {}
var _kitchen: KitchenStock
var _served := 1
var _ingredients_grid: GridContainer
var _sodium_note: Label
var _storage_note: Label
var _effort_note: Label
var _shortage_note: Label
var _commit_summary: Label
var _condiments_note: Label
var _details_button: Button
var _seasoning_details: VBoxContainer
var _portions_label: Label
var _seasoning_label: Label
var _content_grid: GridContainer
var _recipe_column: VBoxContainer
var _controls_column: VBoxContainer
var _source_effort: Dictionary = {}
var _preview_revision := 0


func setup(food_ids: Array[String], foods: Dictionary, stock: KitchenStock, served: int, meal: String, keep: String = "eat_now", recipe: Dictionary = {}, source_effort: Dictionary = {}) -> void:
	ids = food_ids.duplicate()
	_foods = foods.duplicate(true)
	_kitchen = stock
	_served = served
	storage = keep
	_source_effort = source_effort.duplicate(true)
	plan = Facts.defaults(ids, _foods) if recipe.is_empty() else recipe.duplicate(true)
	title_label.text = "%s · 家里做饭" % meal
	subtitle_label.text = "本次配方 · 确认后才使用食材"
	close_button.text = "继续选菜"
	body.add_theme_constant_override("separation", 6)
	_content_grid = GridContainer.new()
	_content_grid.add_theme_constant_override("h_separation", 24)
	_content_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(_content_grid)
	_recipe_column = VBoxContainer.new()
	_recipe_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_column.add_theme_constant_override("separation", 6)
	_content_grid.add_child(_recipe_column)
	_controls_column = VBoxContainer.new()
	_controls_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_column.add_theme_constant_override("separation", 6)
	_content_grid.add_child(_controls_column)
	var dishes := HBoxContainer.new()
	dishes.add_theme_constant_override("separation", 12)
	_recipe_column.add_child(dishes)
	for id in ids:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", HouseholdUI.paper(HouseholdUI.TILE, 8, 10))
		dishes.add_child(card)
		var stack := HBoxContainer.new()
		card.add_child(stack)
		var art := HouseholdUI.image(HouseholdUI.food_texture(_foods[id]), 48)
		art.custom_minimum_size.x = 48
		stack.add_child(art)
		var name_label := HouseholdUI.label(String(_foods[id]["name"]), 20, HouseholdUI.INK, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(name_label)
	HouseholdUI.section(_recipe_column, "1  备好食材")
	_ingredients_grid = GridContainer.new()
	_ingredients_grid.columns = 3
	_ingredients_grid.add_theme_constant_override("h_separation", 10)
	_ingredients_grid.add_theme_constant_override("v_separation", 10)
	_recipe_column.add_child(_ingredients_grid)
	HouseholdUI.section(_controls_column, "2  调味")
	if Facts.supports(ids, _foods, "seasonable"):
		_add_options("seasoning", [{"id": "none", "text": "不另加"}, {"id": "light", "text": "少放一点"}, {"id": "usual", "text": "按原口味"}])
		_seasoning_label = HouseholdUI.label("", 20, HouseholdUI.ORANGE)
		_controls_column.add_child(_seasoning_label)
	else:
		_controls_column.add_child(HouseholdUI.label("这份配方不另加盐和酱油。", 22, HouseholdUI.MUTED))
	if Facts.supports(ids, _foods, "sweetenable"):
		_controls_column.add_child(HouseholdUI.label("额外白糖（每人份）", 22))
		_add_options("sugar", [{"id": "0", "text": "不加糖"}, {"id": "4", "text": "4克"}, {"id": "8", "text": "8克"}])
	_details_button = HouseholdUI.button("查看调味记录", "SeasoningDetails")
	_details_button.toggle_mode = true
	_details_button.custom_minimum_size.y = 44
	_details_button.add_theme_font_size_override("font_size", 19)
	_controls_column.add_child(_details_button)
	_seasoning_details = VBoxContainer.new()
	_seasoning_details.name = "SeasoningRecord"
	_controls_column.add_child(_seasoning_details)
	_condiments_note = HouseholdUI.label("", 20, HouseholdUI.MUTED)
	_condiments_note.name = "CondimentUse"
	_seasoning_details.add_child(_condiments_note)
	_sodium_note = HouseholdUI.note(_seasoning_details, "")
	_seasoning_details.hide()
	_details_button.toggled.connect(func(open: bool) -> void:
		if not is_visible_in_tree() or is_queued_for_deletion(): return
		_seasoning_details.visible = open
		_details_button.text = "收起调味记录" if open else "查看调味记录"
		if open: call_deferred("_reveal_seasoning_details")
	)
	HouseholdUI.section(_controls_column, "3  人数与留存")
	_portions_label = HouseholdUI.label("", 22, HouseholdUI.GREEN)
	_controls_column.add_child(_portions_label)
	_add_options("storage", [{"id": "eat_now", "text": "只做当餐"}, {"id": "fridge", "text": "另备1份冷藏"}, {"id": "counter", "text": "留在灶台"}])
	_effort_note = HouseholdUI.label("", 21, HouseholdUI.GREEN)
	_controls_column.add_child(_effort_note)
	_storage_note = HouseholdUI.note(_controls_column, "")
	# Keep the current commitment and any shortage next to the action, even
	# when a long recipe is scrolled to its ingredients on a small screen.
	var stack := footer.get_parent()
	_commit_summary = HouseholdUI.label("", 20, HouseholdUI.GREEN)
	_commit_summary.name = "CommitSummary"
	stack.add_child(_commit_summary)
	stack.move_child(_commit_summary, footer.get_index())
	_shortage_note = HouseholdUI.label("", 20, HouseholdUI.DANGER)
	_shortage_note.name = "Shortage"
	stack.add_child(_shortage_note)
	stack.move_child(_shortage_note, footer.get_index())
	confirm_button = HouseholdUI.button("按这份配方做饭", "confirm", true)
	confirm_button.size_flags_stretch_ratio = 1.65
	footer.add_child(confirm_button)
	confirm_button.pressed.connect(func() -> void:
		if visible and not is_queued_for_deletion() and not confirm_button.disabled:
			confirm_requested.emit(ids.duplicate(), storage, plan.duplicate(true))
	)
	_update_preview()
	apply_profile(_mobile)


func _add_options(group: String, choices: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	_controls_column.add_child(row)
	for choice in choices:
		var id := String(choice["id"])
		var button := HouseholdUI.button(String(choice["text"]), group + "_" + id)
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 19)
		button.custom_minimum_size.y = 54
		row.add_child(button)
		option_buttons[group + ":" + id] = button
		button.pressed.connect(func() -> void: choose_option(group, id))


func choose_option(group: String, id: String) -> void:
	if not visible or is_queued_for_deletion() or not option_buttons.has(group + ":" + id): return
	match group:
		"seasoning": plan["seasoning"] = id
		"sugar": plan["added_sugar_g"] = int(id)
		"storage": storage = id
	_update_preview()
	if group == "storage": call_deferred("_reveal_storage_note", _preview_revision)


func _reveal_storage_note(revision: int) -> void:
	# Wrapped copy changes several nested containers' minimum sizes. Reveal
	# the final bounds after those layout passes, not the previous short note.
	for frame in range(3):
		if not is_inside_tree() or not visible or is_queued_for_deletion(): return
		await get_tree().process_frame
	if revision == _preview_revision and is_inside_tree() and visible and not is_queued_for_deletion():
		scroll.ensure_control_visible(_storage_note.get_parent() as Control)


func _reveal_seasoning_details() -> void:
	for frame in range(3):
		if not is_inside_tree() or not visible or is_queued_for_deletion(): return
		await get_tree().process_frame
	if _seasoning_details.is_visible_in_tree(): scroll.ensure_control_visible(_seasoning_details)


func _update_preview() -> void:
	_preview_revision += 1
	var portions := _served + (0 if storage == "eat_now" else 1)
	ingredients_needed = _kitchen.needs(ids, _foods)
	for key in ingredients_needed: ingredients_needed[key] = int(ingredients_needed[key]) * portions
	for child in _ingredients_grid.get_children():
		_ingredients_grid.remove_child(child)
		child.queue_free()
	for key in ingredients_needed:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", HouseholdUI.paper(HouseholdUI.TILE, 8, 10))
		_ingredients_grid.add_child(tile)
		var stack := VBoxContainer.new()
		tile.add_child(stack)
		stack.add_child(HouseholdUI.image(HouseholdUI.ingredient_texture(String(key)), 80))
		var need := int(ingredients_needed[key])
		var stock := int(_kitchen.ingredients.get(key, 0))
		stack.add_child(HouseholdUI.label("%s ×%d" % [HouseholdUI.ingredient_name(String(key)), need], 23, HouseholdUI.INK, true))
		stack.add_child(HouseholdUI.label("库存 %d" % stock, 20, HouseholdUI.GREEN if stock >= need else HouseholdUI.DANGER))
	for key in option_buttons:
		var parts: PackedStringArray = String(key).split(":")
		var selected: bool = (parts[1] == storage if parts[0] == "storage" else (parts[1] == str(plan["added_sugar_g"]) if parts[0] == "sugar" else parts[1] == plan["seasoning"]))
		HouseholdUI.style_button(option_buttons[key], false, selected)
		(option_buttons[key] as Button).set_pressed_no_signal(selected)
		(option_buttons[key] as Button).add_theme_font_size_override("font_size", 19)
	var facts := Facts.freeze(ids, _foods, plan)
	if _seasoning_label != null:
		_seasoning_label.text = "每人份：盐%s克 + 酱油%s毫升" % [Facts.number(facts.get("salt_g", 0)), Facts.number(facts.get("soy_ml", 0))]
	_sodium_note.text = "每人份调味钠 %s毫克 · 另加白糖 %s克\n食材本底钠和总糖未知；这不是整餐或全天总量。" % [Facts.number(facts.get("sodium_from_added_seasonings_mg", 0)), Facts.number(facts.get("white_sugar_added_g", 0))]
	_sodium_note.tooltip_text = "本关给定酱油标签：每100毫升钠7000毫克。调味平均分配到相应菜肴；数值是教学配方。"
	_portions_label.text = "当餐%d人份%s · 本次共做%d份" % [_served, "，和老陈一起吃" if _served == 2 else "", portions]
	_update_effort_preview()
	_storage_note.text = {"eat_now": "只准备这顿饭，不另留熟食。", "fridge": "留存份上桌前分装，1小时内放入4℃冰箱；下次食用前彻底再热。", "counter": "留在灶台到下一餐会经过5小时，保存不当有健康风险，届时应丢弃。"}.get(storage, "")
	_storage_note.add_theme_color_override("font_color", HouseholdUI.DANGER if storage == "counter" else HouseholdUI.MUTED)
	confirm_button.disabled = not _kitchen.can_prepare(ids, _foods, portions, plan)
	_update_commit_preview(portions)
	_shortage_note.visible = confirm_button.disabled
	_commit_summary.visible = not confirm_button.disabled


func _update_commit_preview(portions: int) -> void:
	var shortages: Array[String] = []
	for key in ingredients_needed:
		var missing := int(ingredients_needed[key]) - int(_kitchen.ingredients.get(key, 0))
		if missing > 0: shortages.append("%s%d份" % [HouseholdUI.ingredient_name(String(key)), missing])
	var quantities := Facts.seasoning_needs(plan, portions)
	var use_lines: Array[String] = []
	for key in CONDIMENT_UNITS:
		var needed := int(quantities.get(key, 0))
		if needed <= 0: continue
		var available := int(_kitchen.condiments.get(key, 0))
		var unit: Array = CONDIMENT_UNITS[key]
		use_lines.append("%s：用%d%s／库存%d%s" % [unit[0], needed, unit[1], available, unit[1]])
		if needed > available: shortages.append("%s%d%s" % [unit[0], needed - available, unit[1]])
	_condiments_note.text = "本次调味用量\n" + "\n".join(use_lines) if not use_lines.is_empty() else "本次不消耗盐、酱油或白糖。"
	_condiments_note.add_theme_color_override("font_color", HouseholdUI.DANGER if not shortages.is_empty() else HouseholdUI.MUTED)
	_shortage_note.text = "还缺：%s。\n减少份数、调整调味，或继续选菜。" % "、".join(shortages) if not shortages.is_empty() else "配方暂不可用，请继续选菜。"
	var allocation := "当餐%d份" % _served
	if storage != "eat_now": allocation += "＋%s1份" % ("冷藏" if storage == "fridge" else "灶台留存")
	var effort := " · 制作耗%d精力" % int(_source_effort["cook"]) if _source_effort.has("cook") else ""
	_commit_summary.text = allocation + effort
	_commit_summary.add_theme_color_override("font_color", HouseholdUI.DANGER if storage == "counter" else HouseholdUI.GREEN)


func _update_effort_preview() -> void:
	var extra: Array[String] = []
	var unit_needs := _kitchen.needs(ids, _foods)
	for key in unit_needs:
		extra.append("%s×%d" % [HouseholdUI.ingredient_name(String(key)), int(unit_needs[key])])
	var extra_condiments := Facts.seasoning_needs(plan, 1)
	for key in CONDIMENT_UNITS:
		if float(extra_condiments.get(key, 0)) > 0:
			extra.append("%s%s%s" % [CONDIMENT_UNITS[key][0], Facts.number(extra_condiments[key]), CONDIMENT_UNITS[key][1]])
	var extra_line := "另用：%s。" % "、".join(extra)
	var can_use_later := bool(_source_effort.get("can_use_later", true))
	_effort_note.add_theme_color_override("font_color", HouseholdUI.DANGER if storage == "counter" or (storage == "fridge" and not can_use_later) else HouseholdUI.GREEN)
	_effort_note.tooltip_text = "只比较制作消耗，未计食物本身的游戏效果和每个时段的消耗；另备的是1份，不随当餐人数翻倍。"
	if not _source_effort.has("cook") or not _source_effort.has("reheat"):
		_effort_note.text = "" if storage == "eat_now" else extra_line
		return
	var cook := int(_source_effort["cook"])
	var reheat := int(_source_effort["reheat"])
	var saved := cook - reheat
	if storage == "fridge":
		_effort_note.text = extra_line + "\n" + ("本局已是最后一餐，多备的1份不会再用到。" if not can_use_later else "两餐制作：%d＋%d＝%d精力；分开现做%d，省%d。" % [cook, reheat, cook + reheat, cook * 2, saved])
	elif storage == "counter":
		_effort_note.text = extra_line + "\n本次制作耗%d精力，灶台留存不能用于下一餐。" % cook
	else:
		_effort_note.text = "本次制作耗%d精力%s。" % [cook, "；另备冷藏，两餐可省%d" % saved if can_use_later else "；本局最后一餐，建议只做当餐"]


func apply_profile(mobile: bool) -> void:
	super.apply_profile(mobile)
	if _content_grid != null:
		_content_grid.columns = 1 if mobile else 2
