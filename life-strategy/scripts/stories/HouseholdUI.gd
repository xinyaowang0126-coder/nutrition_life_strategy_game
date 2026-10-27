class_name HouseholdUI
extends RefCounted

## Shared paper controls for story components inside the existing game shell.
const INK := Color("#4b3628")
const MUTED := Color("#6f5e4b")
const PAPER := Color("#f5ecd9")
const TILE := Color("#eee0c5")
const ORANGE := Color("#a95132")
const GREEN := Color("#52664d")
const DANGER := Color("#a14c35")
const BODY_FONT := preload("res://assets/fonts/HouseholdBody.tres")
const TITLE_FONT := preload("res://assets/fonts/NotoSansCJKsc-Bold.otf")
const GAME_THEME := preload("res://scenes/game_v2/V2Theme.tres")
const INGREDIENT_IDS := ["rice_plain", "egg", "tofu", "greens", "tomato", "oatmeal", "millet", "milk", "apple", "fish"]
const INGREDIENT_NAMES := {"rice_plain": "米", "egg": "蛋", "tofu": "豆腐", "greens": "青菜", "tomato": "番茄", "oatmeal": "燕麦", "millet": "小米", "milk": "未开封奶", "apple": "苹果", "fish": "鱼"}


static func paper(color: Color = PAPER, padding: int = 22, radius: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("#c4ac87")
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	box.shadow_color = Color(0.22, 0.15, 0.08, 0.16)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	return box


static func label(text: String, font_size: int = 23, color: Color = INK, heading: bool = false) -> Label:
	var value := Label.new()
	value.text = text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_override("font", TITLE_FONT if heading else BODY_FONT)
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", color)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return value


static func style_button(button: Button, primary: bool = false, selected: bool = false) -> void:
	var normal := paper(ORANGE if primary else (Color("#fae6d4") if selected else PAPER), 12, 12)
	if selected:
		normal.border_color = ORANGE
		normal.set_border_width_all(2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#aa5836") if primary else Color("#eed5b6")
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = GREEN
	focus.set_border_width_all(3)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#e5dccd")
	disabled.shadow_size = 0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("#fff8ec") if primary else (ORANGE if selected else INK))
	button.add_theme_color_override("font_disabled_color", Color("#8c8274"))
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 22)


static func button(text: String, id: String, primary: bool = false) -> Button:
	var value := Button.new()
	value.name = id
	value.text = text
	value.custom_minimum_size.y = 58
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_button(value, primary)
	return value


## Use the same question-mark control as the student chapter's cards.
static func info_button(id: String = "Info") -> Button:
	var value := Button.new()
	value.name = id
	value.text = "?"
	value.theme = GAME_THEME
	value.custom_minimum_size = Vector2(50, 50)
	value.add_theme_font_size_override("font_size", 17)
	value.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return value


static func focusable_controls(scope: Control) -> Array[Control]:
	var controls: Array[Control] = []
	for child in scope.get_children():
		if not child is Control or not child.is_visible_in_tree() or child.is_queued_for_deletion(): continue
		var control := child as Control
		if control.focus_mode == Control.FOCUS_ALL and (not control is BaseButton or not (control as BaseButton).disabled):
			controls.append(control)
		controls.append_array(focusable_controls(control))
	return controls


## Let Godot handle activation and spatial navigation inside the paper, while
## keeping keyboard focus out of the covered game behind it.
static func handle_modal_key(scope: Control, event: InputEvent, activate_buttons: bool = false) -> bool:
	if not event is InputEventKey or not event.pressed: return false
	var controls := focusable_controls(scope)
	var owner := scope.get_viewport().gui_get_focus_owner()
	var previous := event.is_action_pressed("ui_focus_prev", true, true)
	if previous or event.is_action_pressed("ui_focus_next", true, true):
		if not controls.is_empty():
			var index := controls.find(owner)
			var next := posmod(index + (-1 if previous else 1), controls.size()) if index >= 0 else (controls.size() - 1 if previous else 0)
			controls[next].grab_focus()
		return true
	for direction in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var action: String = ["ui_left", "ui_up", "ui_right", "ui_down"][direction]
		if not event.is_action_pressed(action, true): continue
		if controls.has(owner):
			var neighbor := owner.find_valid_focus_neighbor(direction)
			if controls.has(neighbor): return false
		if not controls.is_empty():
			var index := controls.find(owner)
			var backwards: bool = direction in [SIDE_LEFT, SIDE_TOP]
			controls[posmod(index + (-1 if backwards else 1), controls.size()) if index >= 0 else 0].grab_focus()
		return true
	if event.is_action_pressed("ui_accept", true) and not controls.has(owner):
		if not controls.is_empty(): controls[0].grab_focus()
		return true
	if activate_buttons and event.is_action_pressed("ui_accept", true) and owner is Button:
		# Dispatch before the popup's legacy unhandled Enter shortcut can
		# advance the day instead of opening the focused details button.
		scope.get_viewport().set_input_as_handled()
		if not event.is_echo(): (owner as Button).pressed.emit()
		return true
	return false


static func image(texture: Texture2D, height: float = 110) -> TextureRect:
	var value := TextureRect.new()
	value.texture = texture
	value.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	value.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	value.custom_minimum_size = Vector2(0, height)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return value


static func food_texture(food: Dictionary) -> Texture2D:
	var path := String(food.get("image", ""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var texture := load(path) as Texture2D
	if not path.contains("/generated/cards/"): return texture
	var crop := AtlasTexture.new()
	crop.atlas = texture
	crop.region = Rect2(130, 112, 252, 288)
	crop.filter_clip = true
	return crop


static func ingredient_texture(id: String) -> Texture2D:
	const PATH := "res://assets/generated/stories/ingredients/ingredient_atlas.png"
	const REGIONS := "res://assets/generated/stories/ingredients/ingredient_regions.json"
	if not ResourceLoader.exists(PATH) or not INGREDIENT_IDS.has(id): return null
	var texture := load(PATH) as Texture2D
	var index := INGREDIENT_IDS.find(id)
	var region := Rect2((index % 5) * texture.get_width() / 5.0, (index / 5) * texture.get_height() / 2.0, texture.get_width() / 5.0, texture.get_height() / 2.0)
	if FileAccess.file_exists(REGIONS):
		var mapping: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGIONS))
		if mapping is Dictionary and mapping.get(id) is Array and mapping[id].size() == 4:
			var bounds: Array = mapping[id]
			region = Rect2(bounds[0], bounds[1], bounds[2], bounds[3])
	var crop := AtlasTexture.new()
	crop.atlas = texture
	crop.region = region
	crop.filter_clip = true
	return crop


static func ingredient_name(id: String) -> String:
	return String(INGREDIENT_NAMES.get(id, id))


static func section(parent: Container, text: String) -> void:
	var line := HSeparator.new()
	line.add_theme_stylebox_override("separator", paper(Color("#cfb996"), 0, 0))
	parent.add_child(line)
	parent.add_child(label(text, 27, INK, true))


static func note(parent: Container, text: String, warning: bool = false) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", paper(Color("#f5dfcb") if warning else TILE, 12, 10))
	parent.add_child(panel)
	var value := label(text, 20, DANGER if warning else MUTED)
	panel.add_child(value)
	return value
