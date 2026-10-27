class_name DormPantryStageV2
extends MealStageBaseV2

@onready var title_label: Label = $Layout/Header/TitleTag/Title
@onready var stock_label: Label = $Layout/Header/StockTag/Stock
@onready var pantry_scroll: ScrollContainer = $Layout/PantryPanel/PantryMargin/Pantry/PantryScroll
@onready var stock_grid: GridContainer = $Layout/PantryPanel/PantryMargin/Pantry/PantryScroll/StockGrid
@onready var slots: HBoxContainer = $Layout/BowlPanel/BowlMargin/Bowl/SelectedSlots
@onready var status_label: Label = $Layout/BowlPanel/BowlMargin/Bowl/BowlHeader/BowlReceipt/Status
@onready var back_button: Button = $Layout/Footer/BackButton
@onready var skip_button: Button = $Layout/Footer/SkipButton
@onready var confirm_button: Button = $Layout/Footer/ConfirmButton


func setup(foods: Array, selected_ids: Array = [], options: Dictionary = {}) -> void:
	var dorm_options := options.duplicate(true)
	dorm_options["payment_mode"] = "stock"
	super.setup(foods, selected_ids, dorm_options)


func _ready() -> void:
	_bind_meal_controls(back_button, skip_button, confirm_button, pantry_scroll)
	_finish_ready()


func _get_card_container() -> Container:
	return stock_grid


func _get_slot_nodes() -> Array:
	return slots.get_children()


func _get_confirm_button() -> Button:
	return confirm_button


func _update_scene_summary() -> void:
	if not is_node_ready():
		return
	title_label.text = "%s · 宿舍存粮" % _meal_label
	var stock_total := 0
	for value in _stock_by_id.values():
		stock_total += maxi(0, int(value))
	stock_label.text = "存货 %d 件" % stock_total
	status_label.text = "已选 %d/%d" % [_selected_ids.size(), _max_selected]


func _default_payment_mode() -> String:
	return "stock"


func _card_button_text() -> String:
	return "放进碗里"


func _slot_text(food: Dictionary) -> String:
	var food_id := String(food.get("id", ""))
	return "%s\n余 %d" % [String(food.get("name", "已选")), _card_stock(food_id)]


func apply_selection_layout(mobile: bool) -> void:
	super.apply_selection_layout(mobile)
	if _ready_finished:
		stock_grid.columns = 2 if mobile else 5
		# The inventory shelf has a heading and an inner margin above its
		# scroll area. Keep that chrome compact so a whole food card still fits
		# on short portrait screens alongside the new decision-cost row.
		var margin := get_node("Layout/PantryPanel/PantryMargin") as MarginContainer
		for side in ["margin_left", "margin_right"]:
			margin.add_theme_constant_override(side, 14 if mobile else 22)
		for side in ["margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(side, 8 if mobile else 18)
		(get_node("Layout/PantryPanel/PantryMargin/Pantry") as VBoxContainer).add_theme_constant_override("separation", 8 if mobile else 12)
		(get_node("Layout/PantryPanel/PantryMargin/Pantry/CabinetHeader/CabinetTitle") as Label).add_theme_font_size_override("font_size", 24 if mobile else 28)


func _get_layout_paths() -> Dictionary:
	return {"header": "Layout/Header", "cards": "Layout/PantryPanel", "selection": "Layout/BowlPanel", "footer": "Layout/Footer", "selection_margin": "Layout/BowlPanel/BowlMargin", "selection_box": "Layout/BowlPanel/BowlMargin/Bowl", "hide": ["Layout/BowlPanel/BowlMargin/Bowl/BowlHint", "Layout/BowlPanel/BowlMargin/Bowl/BowlHeader/BowlReceipt/FreeTag"]}
