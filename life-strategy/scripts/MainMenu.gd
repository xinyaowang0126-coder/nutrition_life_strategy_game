extends Control

const GAME_SCENE := "res://scenes/game_v2/GameRootV2.tscn"
const MOBILE_CANVAS_SIZE := Vector2i(720, 1280)
const DESKTOP_CANVAS_SIZE := Vector2i(1920, 1080)

@onready var menu_margin: MarginContainer = $MenuMargin
@onready var book: PanelContainer = $MenuMargin/Center/Book
@onready var story: VBoxContainer = $MenuMargin/Center/Book/BookMargin/Spread/Story
@onready var title_label: Label = $MenuMargin/Center/Book/BookMargin/Spread/Story/Title
@onready var subtitle_label: Label = $MenuMargin/Center/Book/BookMargin/Spread/Story/Subtitle
@onready var intro_text: Label = $MenuMargin/Center/Book/BookMargin/Spread/Story/IntroText
@onready var start_button: Button = $MenuMargin/Center/Book/BookMargin/Spread/Story/ButtonRow/StartButton
@onready var quit_button: Button = $MenuMargin/Center/Book/BookMargin/Spread/Story/ButtonRow/QuitButton
@onready var right_page: VBoxContainer = $MenuMargin/Center/Book/BookMargin/Spread/RightPage
@onready var divider: VSeparator = $MenuMargin/Center/Book/BookMargin/Spread/Divider

var _applying_profile := false
var _starting := false


func _ready() -> void:
	_style_button(start_button, Color("#ad633f"))
	_style_button(quit_button, Color("#626c4e"))
	get_viewport().size_changed.connect(_apply_responsive_profile)
	_apply_responsive_profile()
	start_button.pressed.connect(_start_week)
	if OS.has_feature("web"):
		quit_button.hide()
	else:
		quit_button.pressed.connect(func() -> void: get_tree().quit())
	book.modulate.a = 0.0
	create_tween().tween_property(book, "modulate:a", 1.0, 0.35)
	start_button.grab_focus()


func _start_week() -> void:
	if _starting:
		return
	_starting = true
	start_button.disabled = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _apply_responsive_profile() -> void:
	if _applying_profile:
		return
	_applying_profile = true
	var physical_size := DisplayServer.window_get_size()
	var mobile := physical_size.y > physical_size.x * 1.18
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var target := MOBILE_CANVAS_SIZE if mobile else DESKTOP_CANVAS_SIZE
	if window.content_scale_size != target:
		window.content_scale_size = target
	for side in ["margin_left", "margin_right"]:
		menu_margin.add_theme_constant_override(side, 32 if mobile else 120)
	for side in ["margin_top", "margin_bottom"]:
		menu_margin.add_theme_constant_override(side, 50 if mobile else 80)
	book.custom_minimum_size = Vector2(640, 0) if mobile else Vector2(1260, 0)
	story.custom_minimum_size.x = 530 if mobile else 650
	right_page.visible = not mobile
	divider.visible = not mobile
	title_label.add_theme_font_size_override("font_size", 80 if mobile else 90)
	subtitle_label.add_theme_font_size_override("font_size", 28 if mobile else 30)
	intro_text.add_theme_font_size_override("font_size", 23)
	start_button.custom_minimum_size = Vector2(280, 76)
	quit_button.custom_minimum_size = Vector2(128, 76)
	_applying_profile = false


func _style_button(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var surface := StyleBoxFlat.new()
		surface.bg_color = color.lightened(0.12) if state == "hover" else (color.darkened(0.12) if state == "pressed" else color)
		surface.border_color = Color("#dfbd7f")
		surface.set_border_width_all(2)
		surface.set_corner_radius_all(12)
		surface.content_margin_left = 20
		surface.content_margin_right = 20
		surface.content_margin_top = 12
		surface.content_margin_bottom = 12
		surface.shadow_color = Color(0.18, 0.11, 0.05, 0.25)
		surface.shadow_size = 7
		surface.shadow_offset = Vector2(0, 4)
		button.add_theme_stylebox_override(state, surface)
