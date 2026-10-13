@tool
extends McpTestSuite

const Store := preload("res://scripts/health/HealthDataStore.gd")
const Registry := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const CASES := [
	["food_health_profiles", "res://tests/fixtures/health_data_store/normal.xml"],
	["evidence_registry", "res://tests/fixtures/health_evidence_registry/lifecycle.xml"],
]
var _path := ""


func suite_name() -> String:
	return "health_xml_structure"


func setup() -> void:
	_path = "res://.godot/health-xml-%d-%d.xml" % [OS.get_process_id(), Time.get_ticks_usec()]


func teardown() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func test_unclosed_roots_fail_closed_with_and_without_trailing_whitespace() -> void:
	for item in CASES:
		var xml := FileAccess.get_file_as_string(item[1]).replace("</%s>" % item[0], "")
		_reject(item, xml.strip_edges())
		_reject(item, xml + "\n  ")


func test_mismatched_root_and_nested_closings_fail_closed() -> void:
	for item in CASES:
		var xml := FileAccess.get_file_as_string(item[1])
		_reject(item, xml.replace("</%s>" % item[0], "</unexpected>"))
		_reject(item, xml.replace("</%s>" % item[0], "<nested></wrong></%s>" % item[0]))


func test_a_second_root_cannot_append_records_to_a_valid_catalog() -> void:
	for item in CASES:
		var xml := FileAccess.get_file_as_string(item[1])
		_reject(item, xml + "<unexpected/>")
		_reject(item, xml + "<%s/>" % item[0])


func test_non_whitespace_text_outside_root_fails_closed() -> void:
	for item in CASES:
		var xml := FileAccess.get_file_as_string(item[1])
		_reject(item, xml + "trailing garbage")
		_reject(item, "leading garbage" + xml)


func test_valid_nested_self_closing_and_commented_documents_remain_supported() -> void:
	for item in CASES:
		var xml := FileAccess.get_file_as_string(item[1])
		_write(xml + "\n<!-- end -->\n ")
		var loader = Store.new() if item[0] == "food_health_profiles" else Registry.new()
		var loaded: Dictionary = loader.load_catalog(_path) if loader is Store else loader.load_registry(_path)
		assert_true(bool(loaded["available"]), str(loaded))
		_write('<%s schema_version="1"/>' % item[0])
		loaded = loader.load_catalog(_path) if loader is Store else loader.load_registry(_path)
		assert_eq(loaded["status"], "ready_empty")
		assert_true(bool(loaded["available"]))


func _reject(item: Array, xml: String) -> void:
	var loader = Store.new() if item[0] == "food_health_profiles" else Registry.new()
	var valid: Dictionary = loader.load_catalog(item[1]) if loader is Store else loader.load_registry(item[1])
	assert_true(bool(valid["available"]))
	_write(xml)
	var loaded: Dictionary = loader.load_catalog(_path) if loader is Store else loader.load_registry(_path)
	assert_eq(loaded["status"], "invalid_xml", str(loaded))
	assert_false(bool(loaded["available"]))
	assert_true(bool(loaded["degraded"]))
	if loader is Store:
		assert_true(loader.get_profile_ids().is_empty())
	else:
		assert_true(loader.get_evidence_ids().is_empty())
		assert_false(bool(loader.audit("2026-09-05")["valid"]))


func _write(xml: String) -> void:
	var handle := FileAccess.open(_path, FileAccess.WRITE)
	assert_true(handle != null)
	if handle != null:
		handle.store_string(xml)
		handle.close()
