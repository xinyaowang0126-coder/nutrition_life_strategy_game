extends Control

const GAME_SCENE := "res://scenes/game/GameRoot.tscn"
const FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"
const FONT_DEFAULT := 18
const FONT_BUTTON := 22
const COLOR_BUTTON_TEXT := Color(1.0, 0.97, 0.88)
const COLOR_BUTTON_OUTLINE := Color(0.06, 0.08, 0.06, 0.55)

@onready var start_button: Button = $MenuMargin/Layout/ButtonRow/StartButton
@onready var quit_button: Button = $MenuMargin/Layout/ButtonRow/QuitButton


func _ready() -> void:
	_apply_font()
	_style_buttons()
	start_button.pressed.connect(func(): get_tree().change_scene_to_file(GAME_SCENE))
	quit_button.pressed.connect(func(): get_tree().quit())


func _apply_font() -> void:
	var font := load(FONT_PATH)
	if font:
		var ui_theme := Theme.new()
		ui_theme.default_font = font
		ui_theme.default_font_size = FONT_DEFAULT
		theme = ui_theme
		add_theme_font_override("font", font)


func _style_buttons() -> void:
	_apply_button_style(start_button, Color(0.88, 0.38, 0.24))
	_apply_button_style(quit_button, Color(0.25, 0.34, 0.30))


func _apply_button_style(button: Button, color: Color) -> void:
	button.add_theme_font_size_override("font_size", FONT_BUTTON)
	button.add_theme_color_override("font_color", COLOR_BUTTON_TEXT)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", COLOR_BUTTON_OUTLINE)
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.10)))
	button.add_theme_stylebox_override("focus", _button_style(color.lightened(0.12)))


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.98, 0.86, 0.62, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
