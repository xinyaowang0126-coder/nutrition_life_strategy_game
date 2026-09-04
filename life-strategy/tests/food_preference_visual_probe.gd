extends SceneTree

## Manual rendered UI check; not part of the headless test discovery.
## Run with a display driver. Screenshots remain in the ignored .godot cache.
const GAME_SCENE := preload("res://scenes/game_v2/GameRootV2.tscn")
const PreferenceScript := preload("res://scripts/systems/FoodPreferenceService.gd")
const OUTPUT_DIR := "res://.godot/nut207-visual"

var _failures: Array[String] = []
var _captures: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	root.title = "NUT-207 角色口味界面核验"
	for resolution in [Vector2i(1920, 1080), Vector2i(720, 1280)]:
		await _capture(resolution, "cafeteria", "greens", false)
		await _capture(resolution, "takeout", "salad_bowl", false)
		await _capture(resolution, "cafeteria", "greens", true)
	var report := {"captures": _captures, "failures": _failures}
	var report_file := FileAccess.open(OUTPUT_DIR.path_join("report.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	print("NUT207_VISUAL_RESULT=" + JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)


func _capture(resolution: Vector2i, source: String, food_id: String, changed: bool) -> void:
	root.size = resolution
	await create_timer(0.15).timeout
	var game := GAME_SCENE.instantiate() as GameRootV2
	root.add_child(game)
	await create_timer(0.3).timeout
	game.new_day_popup.hide_popup(false)
	game.health_history_path = ""
	if changed:
		var profile: Dictionary = PreferenceScript.default_profile()
		profile["id"] = "greens_fan"
		profile["reactions"]["greens"] = {"mood_delta": 7, "comfort": true}
		game.set_food_preferences(profile)
	game.phase = "lunch_source"
	game.source_hands["lunch:%s" % source] = (
		["greens", "tomato", "rice_plain"] if source == "cafeteria" else ["salad_bowl", "bubble_tea"]
	)
	game._choose_meal_source(source)
	await create_timer(0.35).timeout
	var cards: Dictionary = game._active_stage._cards_by_id
	if not cards.has(food_id):
		_failures.append("Missing card: %s" % food_id)
		game.queue_free()
		await process_frame
		return
	cards[food_id].request_detail(true)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_save_capture(game, cards[food_id], resolution, food_id, changed)
	game.queue_free()
	await process_frame


func _save_capture(game: GameRootV2, card: Control, resolution: Vector2i, food_id: String, changed: bool) -> void:
	var suffix := "changed" if changed else "default"
	var name := "%dx%d-%s-%s" % [resolution.x, resolution.y, food_id, suffix]
	var note: Control = game.sticky_note
	var bounds := root.get_visible_rect()
	var note_bounds := note.get_global_rect()
	if not bounds.encloses(note_bounds):
		_failures.append("Detail outside viewport: %s" % name)
	var picture := root.get_texture().get_image()
	var screenshot_path := OUTPUT_DIR.path_join(name + ".png")
	if picture.save_png(screenshot_path) != OK:
		_failures.append("Could not save: %s" % name)
	_captures.append({
		"name": name, "path": ProjectSettings.globalize_path(screenshot_path),
		"image_size": str(picture.get_size()), "viewport": str(bounds),
		"card_rect": str(card.get_global_rect()), "detail_rect": str(note_bounds),
		"preference": game.sticky_note.preference_reaction.text,
		"mood_in_food_grid": game.sticky_note.mood_metric.visible,
		"mobile": game._mobile_mode,
	})
