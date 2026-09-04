class_name HealthGuidanceFeatureFlags
extends RefCounted

const DATA_SETTING := "health_guidance_v2/data"
const ENGINE_SETTING := "health_guidance_v2/engine"
const UI_SETTING := "health_guidance_v2/ui"
const WEEKLY_SETTING := "health_guidance_v2/weekly"
const VALID_FLAGS := ["data", "engine", "ui", "weekly"]


static func current() -> Dictionary:
	return resolve({
		"data": bool(ProjectSettings.get_setting(DATA_SETTING, false)),
		"engine": bool(ProjectSettings.get_setting(ENGINE_SETTING, false)),
		"ui": bool(ProjectSettings.get_setting(UI_SETTING, false)),
		"weekly": bool(ProjectSettings.get_setting(WEEKLY_SETTING, false)),
	})


static func resolve(requested: Dictionary) -> Dictionary:
	var requested_data := bool(requested.get("data", false))
	var requested_engine := bool(requested.get("engine", false))
	var requested_ui := bool(requested.get("ui", false))
	var requested_weekly := bool(requested.get("weekly", false))

	var effective_data := requested_data
	var effective_engine := requested_engine and effective_data
	var effective_ui := requested_ui and effective_engine
	var effective_weekly := requested_weekly and effective_ui
	var warnings: Array[String] = []

	if requested_engine and not effective_data:
		warnings.append("health_guidance_v2/engine requires health_guidance_v2/data")
	if requested_ui and not effective_engine:
		warnings.append("health_guidance_v2/ui requires the effective engine flag")
	if requested_weekly and not effective_ui:
		warnings.append("health_guidance_v2/weekly requires the effective UI flag")

	return {
		"data": effective_data,
		"engine": effective_engine,
		"ui": effective_ui,
		"weekly": effective_weekly,
		"warnings": warnings,
	}


static func is_enabled(flags: Dictionary, flag_name: String) -> bool:
	if not VALID_FLAGS.has(flag_name):
		return false
	return bool(flags.get(flag_name, false))


static func warn_for_invalid(flags: Dictionary) -> void:
	for message in flags.get("warnings", []):
		push_warning(String(message))
