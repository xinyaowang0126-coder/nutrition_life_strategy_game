class_name ConvenienceMealStageV2
extends MealStageBaseV2

@onready var title_label: Label = $Layout/Header/TitleTag/Title
@onready var status_label: Label = $Layout/Header/SelectionTag/Status
@onready var shelf_scroll: ScrollContainer = $Layout/ShelfPanel/ShelfMargin/Shelf/ShelfScroll
@onready var products: HBoxContainer = $Layout/ShelfPanel/ShelfMargin/Shelf/ShelfScroll/Products
@onready var total_label: Label = $Layout/BasketPanel/BasketMargin/Basket/BasketHeader/Total
@onready var slots: HBoxContainer = $Layout/BasketPanel/BasketMargin/Basket/SelectedSlots
@onready var back_button: Button = $Layout/Footer/BackButton
@onready var skip_button: Button = $Layout/Footer/SkipButton
@onready var confirm_button: Button = $Layout/Footer/ConfirmButton


func _ready() -> void:
	_bind_meal_controls(back_button, skip_button, confirm_button, shelf_scroll)
	_finish_ready()


func _get_card_container() -> Container:
	return products


func _get_slot_nodes() -> Array:
	return slots.get_children()


func _get_confirm_button() -> Button:
	return confirm_button


func _update_scene_summary() -> void:
	if not is_node_ready():
		return
	title_label.text = "%s · 便利店" % _meal_label
	status_label.text = "篮子 %d/%d" % [_selected_ids.size(), _max_selected]
	total_label.text = "合计 ¥%d" % _selection_total()


func _default_max_selected() -> int:
	return 5


func _card_button_text() -> String:
	return "放进篮子"
