@tool
extends EditorExportPlugin

## Strips the MCP game-helper autoload and editor-plugin setting from exported
## builds (#740).
##
## plugin.gd writes `autoload/_mcp_game_helper` into project.godot so the
## editor-spawned game process loads the helper. Exports bake project
## settings into the pack's project.binary, so without this plugin every
## export ships the autoload — and users who exclude addons/godot_ai/**
## in their export preset get three "Failed to instantiate an autoload"
## errors at game start. Even when the files ARE shipped, the helper is
## editor-tooling: no exported build should carry it.
##
## Strip mechanics: clear the in-memory ProjectSettings entry in
## _export_begin, restore it in _export_end. The export pipeline reads
## the live ProjectSettings when it bakes project.binary, which happens
## after _export_begin — verified end-to-end by
## script/ci-export-strip-smoke, which exports a real pack and asserts
## the autoload is absent inside it. We never call ProjectSettings.save()
## while stripped, so project.godot on disk keeps the autoload
## throughout; only the export snapshot loses it.
##
## Failure containment: if an export aborts so hard that _export_end
## never fires, the damage is bounded to the editor's in-memory settings
## — the running game reads project.godot from disk, and plugin.gd's
## _ensure_game_helper_autoload() re-asserts the entry on the next
## plugin enable / editor launch.

## Must equal "autoload/" + plugin.gd's GAME_HELPER_AUTOLOAD_NAME.
## Duplicated (not preloaded from plugin.gd) to avoid a cyclic preload —
## plugin.gd preloads this script. The pairing is locked by
## test_export_strip.gd's constants-contract test.
const AUTOLOAD_KEY := "autoload/_mcp_game_helper"
const EDITOR_PLUGINS_KEY := "editor_plugins/enabled"

var _saved_value: Variant = null
var _saved_editor_plugins: Variant = null
var _had_autoload := false
var _had_editor_plugins := false
var _stripped := false


func _get_name() -> String:
	return "GodotAIStripAutoload"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	## `_stripped` guard: if a previous export died before _export_end,
	## don't overwrite the genuinely-saved value with the already-cleared
	## state — restore semantics stay anchored to the original value.
	if _stripped:
		return
	_had_autoload = ProjectSettings.has_setting(AUTOLOAD_KEY)
	_had_editor_plugins = ProjectSettings.has_setting(EDITOR_PLUGINS_KEY)
	if not _had_autoload and not _had_editor_plugins:
		return
	## Setting a project setting to null erases it from the export snapshot.
	## Clearing editor_plugins/enabled keeps the development plugin path out of
	## project.binary while the already-loaded export plugin remains active.
	if _had_autoload:
		_saved_value = ProjectSettings.get_setting(AUTOLOAD_KEY)
		ProjectSettings.set_setting(AUTOLOAD_KEY, null)
	if _had_editor_plugins:
		_saved_editor_plugins = ProjectSettings.get_setting(EDITOR_PLUGINS_KEY)
		ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, null)
	_stripped = true
	print("MCP | export: stripping development-only project settings from the exported pack")


func _export_end() -> void:
	if not _stripped:
		return
	if _had_autoload:
		ProjectSettings.set_setting(AUTOLOAD_KEY, _saved_value)
		## Mirror _ensure_game_helper_autoload()'s registration shape so the
		## restored entry is indistinguishable from the original: initial
		## value "" keeps project.godot diff-clean, basic keeps it visible in
		## the non-advanced settings view.
		ProjectSettings.set_initial_value(AUTOLOAD_KEY, "")
		ProjectSettings.set_as_basic(AUTOLOAD_KEY, true)
	if _had_editor_plugins:
		ProjectSettings.set_setting(EDITOR_PLUGINS_KEY, _saved_editor_plugins)
	_saved_value = null
	_saved_editor_plugins = null
	_had_autoload = false
	_had_editor_plugins = false
	_stripped = false
