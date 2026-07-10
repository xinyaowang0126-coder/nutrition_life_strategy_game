class_name PhaseChoiceView
extends VBoxContainer

signal back_pressed
signal secondary_pressed
signal primary_pressed

@onready var title_label: Label = $Title
@onready var prompt_label: Label = $Prompt
@onready var status_label: Label = $Status
@onready var scroll: ScrollContainer = $Scroll
@onready var grid: GridContainer = $Scroll/Grid
@onready var back_button: Button = $Footer/Back
@onready var spacer: Control = $Footer/Spacer
@onready var secondary_button: Button = $Footer/Secondary
@onready var primary_button: Button = $Footer/Primary


func _ready() -> void:
	back_button.pressed.connect(func(): back_pressed.emit())
	secondary_button.pressed.connect(func(): secondary_pressed.emit())
	primary_button.pressed.connect(func(): primary_pressed.emit())


func setup(title: String, prompt: String, status: String, columns: int = 3) -> void:
	title_label.text = title
	prompt_label.text = prompt
	prompt_label.visible = not prompt.is_empty()
	status_label.text = status
	status_label.visible = not status.is_empty()
	grid.columns = max(1, columns)


func add_card(card: Control) -> void:
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(card)


func clear_cards() -> void:
	for child in grid.get_children():
		child.queue_free()


func configure_footer(back_text: String, secondary_text: String, primary_text: String) -> void:
	back_button.text = back_text
	back_button.visible = not back_text.is_empty()
	secondary_button.text = secondary_text
	secondary_button.visible = not secondary_text.is_empty()
	primary_button.text = primary_text
	primary_button.visible = not primary_text.is_empty()
	spacer.visible = true


func set_primary_enabled(enabled: bool) -> void:
	primary_button.disabled = not enabled


func set_status(text: String) -> void:
	status_label.text = text
	status_label.visible = not text.is_empty()


func set_portrait_mode(enabled: bool) -> void:
	title_label.add_theme_font_size_override("font_size", 88 if enabled else 32)
	prompt_label.add_theme_font_size_override("font_size", 56 if enabled else 20)
	status_label.add_theme_font_size_override("font_size", 50 if enabled else 18)
	for button in [back_button, secondary_button, primary_button]:
		button.add_theme_font_size_override("font_size", 54 if enabled else 20)
		button.custom_minimum_size.y = 132 if enabled else 54
