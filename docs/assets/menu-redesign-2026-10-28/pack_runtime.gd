extends SceneTree

const Menu := preload("res://scenes/main_menu/MainMenu.tscn")
const Catalog := preload("res://scripts/stories/StoryCatalog.gd")
const Scenes := preload("res://scripts/stories/LifeSceneCatalog.gd")
const Store := preload("res://scripts/stories/GameSaveStore.gd")
const Codec := preload("res://scripts/stories/GameSaveCodec.gd")
var errors: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void:
	Store.memory_for_tests = true
	Store._memory.clear()
	call_deferred("_run")

func _run() -> void:
	var scenes := Scenes.all()
	check(scenes.size() == 6, "Final PCK playlist missing scenes")
	for row in scenes:
		var art := load(row["image"]) as Texture2D
		check(art != null and art.get_width() > 1000, "Final PCK missing scene " + row["id"])
	var icon := load("res://assets/branding/haohaochifan-512.png") as Texture2D
	check(icon != null and icon.get_image().get_pixel(0,0).a == 0.0, "Final PCK brand icon is not transparent")
	for story in Catalog.all():
		var poster := load(story["character_selection_art"]) as Texture2D
		check(poster != null and poster.get_height() > poster.get_width(), "Final PCK missing full portrait")
		var menu := Menu.instantiate()
		root.add_child(menu)
		current_scene = menu
		await process_frame
		menu._show_characters()
		await process_frame
		menu._select_character(story["character_id"])
		await process_frame
		check(menu._selected == story["id"], "Packed person selection chose wrong story")
		menu._more_info.pressed.emit()
		check(not menu._dialog._buttons.has_node("start"), "Packed read-only story info can start over")
		menu._dialog._buttons.get_node("back").pressed.emit()
		await process_frame
		menu._enter_selected()
		await process_frame
		await process_frame
		var game := current_scene as GameRootV2
		if game == null:
			errors.append("Packed selected story did not launch")
			break
		check(game.story_id == story["id"] and game.day == 1, "Packed new story identity incorrect")
		var snapshot := game.capture_game_save()
		var encoded := Codec.encode(snapshot)
		check(encoded["ok"], "Packed capture did not encode")
		check(Store.new().write_local(snapshot)["ok"], "Packed save failed")
		var phase := game.phase
		game.free()
		await process_frame
		menu = Menu.instantiate()
		root.add_child(menu)
		current_scene = menu
		await process_frame
		menu._show_characters()
		await process_frame
		menu._select_character(story["character_id"])
		await process_frame
		check(menu._main_start.text == "继续这一周", "Packed existing save lacks continue entry")
		menu._enter_selected()
		await process_frame
		await process_frame
		game = current_scene as GameRootV2
		if game == null:
			errors.append("Packed continue did not launch")
			break
		check(game.story_id == story["id"] and game.phase == phase, "Packed continue did not restore identity/phase")
		cases.append({"story": game.story_id, "day": game.day, "phase": game.phase, "new_and_continue": true})
		game.free()
		await process_frame
	var report := {"errors": errors, "cases": cases, "scenes": scenes.size(), "pack_sha256": FileAccess.get_sha256("E:/nutrition_life_strategy_game/artifacts/menu-redesign-2026-10-28-web/index.pck"), "scope": "Matching native Godot 4.7.2 loads final Web PCK directly: six scene textures, both portrait posters, icon alpha, read-only story info, both selected-story starts and memory-backed save/continue. Browser rendering is verified separately; not continuous seven-day acceptance."}
	var file := FileAccess.open("E:/nutrition_life_strategy_game/.cache/menu-redesign-2026-10-28/pack-runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MENU_PACK_RUNTIME=" + JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
