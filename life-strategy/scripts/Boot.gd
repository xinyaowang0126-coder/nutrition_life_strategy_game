extends Control

const MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"


func _ready() -> void:
	call_deferred("_go_main_menu")


func _go_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
