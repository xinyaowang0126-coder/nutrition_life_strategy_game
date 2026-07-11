extends Control

const GAME_SCENE := "res://scenes/game_v2/GameRootV2.tscn"
const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Bold.otf"
const FONT_DEFAULT := 22
const FONT_BUTTON := 27
const FONT_EMBOLDEN := 0.16
const FONT_WEIGHT := 700.0
const COLOR_BUTTON_TEXT := Color(1.0, 0.97, 0.88)
const COLOR_BUTTON_OUTLINE := Color(0.06, 0.08, 0.06, 0.55)
const MOBILE_CANVAS_SIZE := Vector2i(720, 1280)
const DESKTOP_CANVAS_SIZE := Vector2i(1920, 1080)

@onready var menu_margin: MarginContainer = $MenuMargin
@onready var layout: VBoxContainer = $MenuMargin/Layout
@onready var title_label: Label = $MenuMargin/Layout/Title
@onready var subtitle_label: Label = $MenuMargin/Layout/Subtitle
@onready var intro_panel: PanelContainer = $MenuMargin/Layout/IntroPanel
@onready var intro_text: Label = $MenuMargin/Layout/IntroPanel/IntroText
@onready var button_row: HBoxContainer = $MenuMargin/Layout/ButtonRow
@onready var start_button: Button = $MenuMargin/Layout/ButtonRow/StartButton
@onready var quit_button: Button = $MenuMargin/Layout/ButtonRow/QuitButton

var _applying_profile := false


func _ready() -> void:
	_apply_font()
	_style_buttons()
	get_viewport().size_changed.connect(_apply_responsive_profile)
	_apply_responsive_profile()
	start_button.pressed.connect(func(): get_tree().change_scene_to_file(GAME_SCENE))
	if OS.has_feature("web"):
		quit_button.hide()
	else:
		quit_button.pressed.connect(func(): get_tree().quit())


func _apply_responsive_profile() -> void:
	if _applying_profile:
		return
	_applying_profile = true
	var physical_size := DisplayServer.window_get_size()
	var mobile := physical_size.y > physical_size.x * 1.18
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var target_size := MOBILE_CANVAS_SIZE if mobile else DESKTOP_CANVAS_SIZE
	if window.content_scale_size != target_size:
		window.content_scale_size = target_size
	for side in ["margin_left", "margin_right"]:
		menu_margin.add_theme_constant_override(side, 28 if mobile else 120)
	for side in ["margin_top", "margin_bottom"]:
		menu_margin.add_theme_constant_override(side, 48 if mobile else 96)
	layout.add_theme_constant_override("separation", 22 if mobile else 26)
	title_label.add_theme_font_size_override("font_size", 54 if mobile else 88)
	subtitle_label.add_theme_font_size_override("font_size", 27 if mobile else 34)
	intro_text.add_theme_font_size_override("font_size", 22 if mobile else 24)
	intro_panel.custom_minimum_size = Vector2.ZERO if mobile else Vector2(880, 0)
	intro_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL if mobile else Control.SIZE_SHRINK_CENTER
	)
	button_row.add_theme_constant_override("separation", 14 if mobile else 18)
	start_button.custom_minimum_size = Vector2(230, 64) if mobile else Vector2(260, 68)
	quit_button.custom_minimum_size = Vector2(150, 64) if mobile else Vector2(180, 68)
	start_button.add_theme_font_size_override("font_size", 24 if mobile else FONT_BUTTON)
	quit_button.add_theme_font_size_override("font_size", 24 if mobile else FONT_BUTTON)
	_applying_profile = false


func _apply_font() -> void:
	var font := load(FONT_PATH)
	if font:
		var bold_font := FontVariation.new()
		bold_font.base_font = font
		bold_font.variation_embolden = FONT_EMBOLDEN
		bold_font.variation_opentype = {"wght": FONT_WEIGHT}
		var ui_theme := Theme.new()
		ui_theme.default_font = bold_font
		ui_theme.default_font_size = FONT_DEFAULT
		theme = ui_theme
		add_theme_font_override("font", bold_font)


func _style_buttons() -> void:
	_apply_button_style(start_button, Color(0.88, 0.38, 0.24))
	_apply_button_style(quit_button, Color(0.25, 0.34, 0.30))


func _apply_button_style(button: Button, color: Color) -> void:
	button.custom_minimum_size = Vector2(178, 62)
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
