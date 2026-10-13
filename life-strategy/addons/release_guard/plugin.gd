@tool
extends EditorPlugin

const ExportGuard := preload("res://addons/release_guard/export_guard.gd")

var _export_guard: EditorExportPlugin


func _enter_tree() -> void:
	_export_guard = ExportGuard.new()
	add_export_plugin(_export_guard)


func _exit_tree() -> void:
	if _export_guard != null:
		remove_export_plugin(_export_guard)
		_export_guard = null
