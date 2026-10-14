extends Control

signal source_selected(source_id: String)
signal skip_requested
signal detail_requested(payload: Dictionary, anchor: Rect2, pinned: bool)
signal detail_dismissed(id: String)
signal kitchen_requested
signal education_requested
signal recipe_requested
var _sources: Array = []
var _meal := "早餐"
var _paper: PanelContainer
var _plan_summary := ""


func setup(sources: Array, meal: String, _reasons: Dictionary = {}, plan_summary: String = "") -> void:
	_sources = sources.duplicate(true)
	_meal = meal
	_plan_summary = plan_summary
	_rebuild()


func _ready() -> void:
	_rebuild()
	get_viewport().size_changed.connect(_layout)


func _rebuild() -> void:
	if not is_node_ready():
		return
	if is_instance_valid(_paper):
		remove_child(_paper)
		_paper.queue_free()
	_paper = PanelContainer.new()
	_paper.name = "SourcesPaper"
	_paper.add_theme_stylebox_override("panel", StoryDialog.paper())
	add_child(_paper)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	_paper.add_child(stack)
	var title := Label.new()
	title.text = "%s怎么吃？" % _meal
	title.add_theme_font_size_override("font_size", 34)
	stack.add_child(title)
	if not _plan_summary.is_empty():
		var note := Label.new()
		note.text = _plan_summary
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 21)
		stack.add_child(note)
	for source in _sources:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		stack.add_child(row)
		var button := Button.new()
		button.name = String(source["id"])
		button.text = String(source["name"]) + (" · " + String(source["disabled_reason"]) if not String(source.get("disabled_reason", "")).is_empty() else "")
		button.custom_minimum_size.y = 65
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 24)
		button.disabled = not bool(source.get("enabled", true))
		button.pressed.connect(func() -> void: source_selected.emit(String(source["id"])))
		row.add_child(button)
		var info := Button.new()
		info.text = "详情"
		info.custom_minimum_size = Vector2(86, 65)
		info.pressed.connect(func() -> void: detail_requested.emit(source, info.get_global_rect(), true))
		row.add_child(info)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	stack.add_child(tools)
	for choice in [{"name": "厨房记录", "id": "kitchen"}, {"name": "配方记录", "id": "recipe"}, {"name": "科普参考", "id": "education"}, {"name": "这餐先不吃", "id": "skip"}]:
		var button := Button.new()
		button.text = choice["name"]
		button.name = choice["id"]
		button.custom_minimum_size.y = 52
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			match choice["id"]:
				"kitchen": kitchen_requested.emit()
				"education": education_requested.emit()
				"recipe": recipe_requested.emit()
				_: skip_requested.emit()
		)
		tools.add_child(button)
	_layout()


func _layout() -> void:
	if _paper == null:
		return
	var mobile := DisplayServer.window_get_size().y > DisplayServer.window_get_size().x
	_paper.anchor_left = 0.02 if mobile else 0.48
	_paper.anchor_right = 0.98
	_paper.anchor_top = 0.02 if mobile else 0.10
	_paper.anchor_bottom = 0.02 if mobile else 0.10
	_paper.offset_left = 0
	_paper.offset_right = 0
	_paper.offset_top = 0
	_paper.offset_bottom = 480
