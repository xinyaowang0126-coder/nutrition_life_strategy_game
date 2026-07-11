class_name TakeoutMealStageV2
extends MealStageBaseV2

const TAKEOUT_ROW_CARD_PATH := "res://scenes/game_v2/components/TakeoutFoodRowCard.tscn"

@onready var title_label: Label = $Layout/Header/TitleTag/Title
@onready var status_label: Label = $Layout/Header/SelectionTag/Status
@onready var fee_label: Label = $Layout/PhoneShell/PhoneMargin/Phone/AppHeader/FeeChip/Fee
@onready var menu_scroll: ScrollContainer = $Layout/PhoneShell/PhoneMargin/Phone/MenuScroll
@onready var food_list: VBoxContainer = $Layout/PhoneShell/PhoneMargin/Phone/MenuScroll/FoodList
@onready var bag_label: Label = $Layout/PhoneShell/PhoneMargin/Phone/CheckoutBar/CheckoutMargin/Checkout/OrderText/Bag
@onready var total_label: Label = $Layout/PhoneShell/PhoneMargin/Phone/CheckoutBar/CheckoutMargin/Checkout/OrderText/Total
@onready var confirm_button: Button = $Layout/PhoneShell/PhoneMargin/Phone/CheckoutBar/CheckoutMargin/Checkout/ConfirmButton
@onready var back_button: Button = $Layout/Footer/BackButton
@onready var skip_button: Button = $Layout/Footer/SkipButton


func _ready() -> void:
	_bind_meal_controls(back_button, skip_button, confirm_button, menu_scroll)
	_finish_ready()


func _get_card_container() -> Container:
	return food_list


func _get_confirm_button() -> Button:
	return confirm_button


func _create_card() -> Variant:
	var packed := load(TAKEOUT_ROW_CARD_PATH) as PackedScene
	return packed.instantiate() if packed != null else null


func _prepare_card(card: Control) -> void:
	card.custom_minimum_size.x = 0.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _update_scene_summary() -> void:
	if not is_node_ready():
		return
	title_label.text = "%s · 外卖 App" % _meal_label
	status_label.text = "购物袋 %d/%d" % [_selected_ids.size(), _max_selected]
	fee_label.text = "配送 ¥%d" % _source_fee
	bag_label.text = "购物袋 %d/%d" % [_selected_ids.size(), _max_selected]
	total_label.text = "合计 ¥%d" % _selection_total()


func _default_max_selected() -> int:
	return 4


func _card_button_text() -> String:
	return "加购"
