class_name CafeteriaMealStageV2
extends MealStageBaseV2

@onready var title_label: Label = $Header/TitleTag/Title
@onready var status_label: Label = $Header/SelectionTag/Status
@onready var food_scroll: ScrollContainer = $FoodRail
@onready var cards: HBoxContainer = $FoodRail/Cards
@onready var receipt_label: Label = $TrayDropZone/TrayMargin/VBox/TrayHeader/Receipt
@onready var slots: HBoxContainer = $TrayDropZone/TrayMargin/VBox/SelectedSlots
@onready var back_button: Button = $Footer/BackButton
@onready var skip_button: Button = $Footer/SkipButton
@onready var confirm_button: Button = $Footer/ConfirmButton


func _ready() -> void:
	_bind_meal_controls(back_button, skip_button, confirm_button, food_scroll)
	_finish_ready()


func _get_card_container() -> Container:
	return cards


func _get_slot_nodes() -> Array:
	return slots.get_children()


func _get_confirm_button() -> Button:
	return confirm_button


func _update_scene_summary() -> void:
	if not is_node_ready():
		return
	title_label.text = "%s · 食堂窗口" % _meal_label
	status_label.text = "已选 %d/%d" % [_selected_ids.size(), _max_selected]
	receipt_label.text = "合计 ¥%d" % _selection_total()


func _card_button_text() -> String:
	return "放进餐盘"
