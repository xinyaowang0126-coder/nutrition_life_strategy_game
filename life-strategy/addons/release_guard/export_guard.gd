@tool
extends EditorExportPlugin

## Own only editor-plugin settings. Godot AI's signed export plugin owns its
## helper autoload; keeping the callbacks disjoint also preserves restoration.
const EDITOR_PLUGINS_KEY := "editor_plugins/enabled"

var _saved_editor_plugins: Variant = null
var _had_editor_plugins := false
var _stripped := false


func _get_name() -> String:
	return "ProjectReleaseGuard"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if _stripped:
		return
	_had_editor_plugins = ProjectSettings.has_setting(EDITOR_PLUGINS_KEY)
	if _had_editor_plugins:
		_saved_editor_plugins = ProjectSettings.get_setting(EDITOR_PLUGINS_KEY)
	ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, null)
	_stripped = true
	print("Release guard: stripping editor-only settings from the exported pack")


func _export_end() -> void:
	if not _stripped:
		return
	ProjectSettings.set_setting(
		EDITOR_PLUGINS_KEY, _saved_editor_plugins if _had_editor_plugins else null
	)
	_saved_editor_plugins = null
	_had_editor_plugins = false
	_stripped = false
