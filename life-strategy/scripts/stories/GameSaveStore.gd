class_name GameSaveStore
extends RefCounted

const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const WEB_SOURCE := "res://scripts/stories/web_save_bridge.js"
const SLOTS := ["auto", "manual_1", "manual_2", "manual_3"]
static var memory_for_tests := false
static var _memory: Dictionary = {}
var root_path := "user://game_saves"
var mode := "file"
var _web: JavaScriptObject


func _init(path: String = "user://game_saves", backend: String = "auto") -> void:
	root_path = path
	mode = ("memory" if memory_for_tests else ("web" if OS.has_feature("web") else "file")) if backend == "auto" else backend
	if mode == "web":
		var source := FileAccess.get_file_as_string(WEB_SOURCE)
		JavaScriptBridge.eval(source, true)
		_web = JavaScriptBridge.get_interface("NutritionLifeSaves")


func status() -> String:
	if mode != "web":
		return "ready"
	if _web == null:
		return "unavailable"
	var value: Variant = JSON.parse_string(String(_web.status()))
	return String(value.get("phase", "unavailable")) if value is Dictionary else "unavailable"


func wait_until_ready() -> bool:
	var start := Time.get_ticks_msec()
	while status() in ["opening", "loading"] and Time.get_ticks_msec() - start < 12000:
		await (Engine.get_main_loop() as SceneTree).create_timer(0.03).timeout
	return status() == "ready"


func read_save(story_id: String, slot: String = "auto") -> Dictionary:
	if not valid_key(story_id, slot):
		return Codec.failure("invalid_slot", "这个存档位置无效。")
	if status() != "ready":
		return Codec.failure("storage_unavailable", "存档暂时不可用，可以导出文件备份。")
	var content := _read_text(story_id, slot)
	var result := Codec.decode(content) if not content.is_empty() else Codec.failure("empty_slot", "这个位置还没有存档。")
	if result["ok"] and result["save"]["story_id"] != story_id:
		result = Codec.failure("wrong_story", "存档的人物与位置不一致。")
	if result["ok"]:
		if mode == "web": _web.mark_valid(story_id + ":" + slot, content)
		return result
	var backup := _read_text(story_id, slot + ":backup")
	if not backup.is_empty():
		var restored := Codec.decode(backup)
		if restored["ok"] and restored["save"]["story_id"] == story_id:
			restored["backup"] = true
			return restored
	return result


func write_save(envelope: Dictionary, slot: String = "auto") -> Dictionary:
	if mode != "web":
		return write_local(envelope, slot)
	var checked := Codec.encode(envelope)
	if not checked["ok"]: return checked
	var story_id := String(envelope["story_id"])
	if not valid_key(story_id, slot): return Codec.failure("invalid_slot", "这个存档位置无效。")
	if not await wait_until_ready(): return Codec.failure("storage_unavailable", "尚未保存。可重试或导出文件备份。")
	var previous := read_save(story_id, slot)
	var backup := String(Codec.encode(previous["save"])["text"]) if previous["ok"] else ""
	var result := await _poll(int(_web.put(story_id + ":" + slot, String(checked["text"]), backup)), 15000)
	if not result.get("ok", false): return Codec.failure("write_failed", "尚未保存。原存档保留，可重试或导出备份。")
	return {"ok": true, "save": checked["save"], "slot": slot}


func write_local(envelope: Dictionary, slot: String = "auto") -> Dictionary:
	if mode == "web": return Codec.failure("async_required", "浏览器存档需要等待写入完成。")
	var checked := Codec.encode(envelope)
	if not checked["ok"]: return checked
	var story_id := String(envelope["story_id"])
	if not valid_key(story_id, slot): return Codec.failure("invalid_slot", "这个存档位置无效。")
	var previous := read_save(story_id, slot)
	var backup := String(Codec.encode(previous["save"])["text"]) if previous["ok"] else ""
	var text := String(checked["text"])
	if mode == "memory":
		if not backup.is_empty(): _memory[story_id + ":" + slot + ":backup"] = backup
		_memory[story_id + ":" + slot] = text
	else:
		var folder := root_path.path_join(story_id)
		if DirAccess.make_dir_recursive_absolute(folder) != OK: return Codec.failure("write_failed", "无法创建存档位置。")
		if not backup.is_empty() and not _write_file(_file(story_id, slot + ":backup"), backup): return Codec.failure("backup_failed", "备用存档写入失败，原进度保留。")
		if not _write_file(_file(story_id, slot), text): return Codec.failure("write_failed", "尚未保存，原存档保留。")
	return {"ok": true, "save": checked["save"], "slot": slot}


func import_text(content: String, slot: String) -> Dictionary:
	var checked := Codec.decode(content)
	if not checked["ok"]:
		return checked
	return await write_save(checked["save"], slot)


func export_web(envelope: Dictionary) -> Dictionary:
	var checked := Codec.encode(envelope)
	if not checked["ok"]:
		return checked
	if _web == null:
		return Codec.failure("download_unavailable", "下载暂不可用。")
	var filename := "nutrition-life-" + String(envelope["story_id"]) + ".json"
	return {"ok": bool(_web.download(filename, checked["text"]))}


func pick_web_file() -> Dictionary:
	if _web == null:
		return Codec.failure("upload_unavailable", "文件选择暂不可用。")
	return await _poll(int(_web.pick()), 180000)


func retry() -> void:
	if _web != null and status() == "unavailable":
		_web.retry()


func valid_key(story_id: String, slot: String) -> bool:
	return not Catalog.get_story(story_id).is_empty() and SLOTS.has(slot)


func slot_has_data(story_id: String, slot: String) -> bool:
	return valid_key(story_id, slot) and not _read_text(story_id, slot).is_empty()


func _poll(id: int, timeout_ms: int) -> Dictionary:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout_ms:
		var response := String(_web.poll(id))
		if not response.is_empty():
			var result: Variant = JSON.parse_string(response)
			return result if result is Dictionary else {"ok": false, "error": "invalid_response"}
		await (Engine.get_main_loop() as SceneTree).create_timer(0.03).timeout
	return {"ok": false, "error": "timeout"}


func _read_text(story_id: String, slot: String) -> String:
	if mode == "web":
		return String(_web.read(story_id + ":" + slot)) if _web != null else ""
	if mode == "memory":
		return String(_memory.get(story_id + ":" + slot, ""))
	var path := _file(story_id, slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	if file.get_length() > Codec.MAX_BYTES:
		return "invalid_oversize"
	return file.get_as_text()


func _file(story_id: String, slot: String) -> String:
	return root_path.path_join(story_id).path_join(slot.replace(":", "_") + ".json")


func _write_file(path: String, content: String) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(temporary, path) == OK
