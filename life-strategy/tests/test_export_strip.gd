@tool
extends McpTestSuite

const EXPORT_PLUGIN_PATH := "res://addons/godot_ai/export/mcp_export_plugin.gd"
const AUTOLOAD_KEY := "autoload/_mcp_game_helper"
const EDITOR_PLUGINS_KEY := "editor_plugins/enabled"
const HELPER_PATH := "*res://addons/godot_ai/runtime/game_helper.gd"

var _plugin: Variant
var _testable_script: GDScript
var _original_settings: Dictionary = {}
var _project_bytes := PackedByteArray()


func suite_name() -> String:
	return "export_strip"


func suite_setup(_ctx: Dictionary) -> void:
	## EditorExportPlugin cannot be instantiated by the game's headless runner.
	## Run its unchanged callback bodies against the real ProjectSettings using
	## a RefCounted host. The actual Web export remains the integration check.
	_testable_script = GDScript.new()
	_testable_script.source_code = FileAccess.get_file_as_string(EXPORT_PLUGIN_PATH).replace(
		"extends EditorExportPlugin", "extends RefCounted"
	)
	if _testable_script.reload() != OK:
		fail_setup("Could not load the export callback test host")


func setup() -> void:
	_original_settings.clear()
	for key in [AUTOLOAD_KEY, EDITOR_PLUGINS_KEY]:
		if ProjectSettings.has_setting(key):
			_original_settings[key] = ProjectSettings.get_setting(key)
	_project_bytes = FileAccess.get_file_as_bytes("res://project.godot")
	_plugin = _testable_script.new()
	track(_plugin)


func teardown() -> void:
	if _plugin != null:
		_plugin._export_end()
	for key in [AUTOLOAD_KEY, EDITOR_PLUGINS_KEY]:
		ProjectSettings.set_setting(key, _original_settings.get(key, null))
	assert_eq(
		FileAccess.get_file_as_bytes("res://project.godot"), _project_bytes,
		"export callbacks must never write the editor's project.godot"
	)


func test_both_development_settings_are_stripped_and_restored_exactly() -> void:
	var plugins := PackedStringArray([
		"res://addons/godot_ai/plugin.cfg", "res://addons/another_editor_tool/plugin.cfg"
	])
	ProjectSettings.set_setting(AUTOLOAD_KEY, HELPER_PATH)
	ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, plugins)
	_begin()
	_assert_stripped()
	_plugin._export_end()
	assert_eq(ProjectSettings.get_setting(AUTOLOAD_KEY), HELPER_PATH)
	assert_eq(ProjectSettings.get_setting(EDITOR_PLUGINS_KEY), plugins)


func test_editor_plugins_are_stripped_without_a_helper_autoload() -> void:
	var plugins := PackedStringArray(["res://addons/godot_ai/plugin.cfg"])
	ProjectSettings.set_setting(AUTOLOAD_KEY, null)
	ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, plugins)
	_begin()
	_assert_stripped()
	_plugin._export_end()
	assert_false(ProjectSettings.has_setting(AUTOLOAD_KEY))
	assert_eq(ProjectSettings.get_setting(EDITOR_PLUGINS_KEY), plugins)


func test_autoload_is_restored_without_creating_editor_plugins() -> void:
	ProjectSettings.set_setting(AUTOLOAD_KEY, HELPER_PATH)
	ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, null)
	_begin()
	_assert_stripped()
	_plugin._export_end()
	assert_eq(ProjectSettings.get_setting(AUTOLOAD_KEY), HELPER_PATH)
	assert_false(ProjectSettings.has_setting(EDITOR_PLUGINS_KEY))


func test_absent_settings_and_repeated_callbacks_preserve_original_absence() -> void:
	ProjectSettings.set_setting(AUTOLOAD_KEY, null)
	ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, null)
	_begin()
	_begin()
	_assert_stripped()
	_plugin._export_end()
	_plugin._export_end()
	_assert_stripped()


func test_repeated_begin_does_not_overwrite_the_original_snapshot() -> void:
	var plugins := PackedStringArray(["res://addons/godot_ai/plugin.cfg"])
	ProjectSettings.set_setting(AUTOLOAD_KEY, HELPER_PATH)
	ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, plugins)
	_begin()
	_begin()
	_assert_stripped()
	_plugin._export_end()
	_plugin._export_end()
	assert_eq(ProjectSettings.get_setting(AUTOLOAD_KEY), HELPER_PATH)
	assert_eq(ProjectSettings.get_setting(EDITOR_PLUGINS_KEY), plugins)


func test_next_export_takes_a_fresh_snapshot_and_preserves_an_empty_array() -> void:
	ProjectSettings.set_setting(AUTOLOAD_KEY, HELPER_PATH)
	ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, PackedStringArray(["first"]))
	_begin()
	_plugin._export_end()
	ProjectSettings.set_setting(AUTOLOAD_KEY, "res://custom_helper.gd")
	ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, PackedStringArray())
	_begin()
	_assert_stripped()
	_plugin._export_end()
	assert_eq(ProjectSettings.get_setting(AUTOLOAD_KEY), "res://custom_helper.gd")
	assert_true(ProjectSettings.has_setting(EDITOR_PLUGINS_KEY))
	assert_eq(ProjectSettings.get_setting(EDITOR_PLUGINS_KEY), PackedStringArray())


func test_end_before_begin_does_not_change_settings() -> void:
	_plugin._export_end()
	for key in [AUTOLOAD_KEY, EDITOR_PLUGINS_KEY]:
		assert_eq(ProjectSettings.has_setting(key), _original_settings.has(key))
		assert_eq(ProjectSettings.get_setting(key, null), _original_settings.get(key, null))


func _begin() -> void:
	_plugin._export_begin(PackedStringArray(["web"]), false, "unused.pck", 0)


func _assert_stripped() -> void:
	assert_false(ProjectSettings.has_setting(AUTOLOAD_KEY))
	assert_false(ProjectSettings.has_setting(EDITOR_PLUGINS_KEY))
