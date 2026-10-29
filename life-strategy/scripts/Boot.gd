extends Control

const MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const UI := preload("res://scripts/stories/HouseholdUI.gd")
const Backdrop := preload("res://scripts/stories/LifeSceneBackdrop.gd")
const FONT := preload("res://assets/fonts/HouseholdBody.tres")
var _progress: ProgressBar
var _status: Label
var _background: LifeSceneBackdrop
var _panel: PanelContainer


func _ready() -> void:
	_background = Backdrop.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.paper(Color(0.96, 0.92, 0.83, 0.94), 30))
	add_child(_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	_panel.add_child(stack)
	var title := Label.new()
	title.text = "好好吃饭"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#4b3628"))
	stack.add_child(title)
	_status = Label.new()
	_status.text = "正在准备这一周的生活…"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_override("font", FONT)
	_status.add_theme_font_size_override("font_size", 26)
	_status.add_theme_color_override("font_color", Color("#52664d"))
	stack.add_child(_status)
	_progress = ProgressBar.new()
	_progress.name = "LoadingProgress"
	_progress.show_percentage = false
	_progress.indeterminate = true
	_progress.custom_minimum_size.y = 20
	var track := UI.paper(Color("#d6bd98"), 0, 10)
	track.border_color = Color("#b49370")
	track.shadow_size = 0
	var fill := UI.paper(UI.ORANGE, 0, 10)
	fill.set_border_width_all(0)
	fill.shadow_size = 0
	_progress.add_theme_stylebox_override("background", track)
	_progress.add_theme_stylebox_override("fill", fill)
	stack.add_child(_progress)
	get_viewport().size_changed.connect(_layout)
	_layout()
	call_deferred("_go_main_menu")


func _layout() -> void:
	var mobile := DisplayServer.window_get_size().y > DisplayServer.window_get_size().x * 1.18
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().content_scale_size = Vector2i(720, 1280) if mobile else Vector2i(1920, 1080)
	_background.set_mobile(mobile)
	_panel.anchor_left = 0.06 if mobile else 0.08
	_panel.anchor_right = 0.94 if mobile else 0.48
	_panel.anchor_top = 0.65 if mobile else 0.58
	_panel.anchor_bottom = 0.89 if mobile else 0.85


func _go_main_menu() -> void:
	# GDScript font constants are loaded on the main thread. The browser shell
	# handles byte-progress/carousel while the engine and PCK are downloading.
	await get_tree().process_frame
	var packed := load(MAIN_MENU) as PackedScene
	if packed != null:
		_progress.indeterminate = false
		_progress.value = 100
		await get_tree().process_frame
		get_tree().change_scene_to_packed(packed)
	else: _status.text = "资源暂未载入，请重新打开试玩。"
