extends "res://tests/story_series_visual_probe.gd"

const Game := preload("res://scenes/game_v2/GameRootV2.tscn")
const Session := preload("res://scripts/stories/StorySession.gd")
var pages: Array[Dictionary] = []
var _prefix := ""


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(640, 960), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		await settle()
		_prefix = "%dx%d-series" % [resolution.x, resolution.y]
		var menu := Menu.instantiate()
		root.add_child(menu)
		current_scene = menu
		await capture("01-stories", "系列入口")
		menu.queue_free()
		await process_frame
		for story_id in ["campus_exam", "choir_week"]:
			_prefix = "%dx%d-%s" % [resolution.x, resolution.y, story_id]
			var game := await new_game(story_id)
			await capture("02-new-day", "人物开局与新日")
			game.new_day_popup.hide_popup(false)
			game._new_day_pending = false
			await capture("03-sources", "来源选择")
			var sources: Array = ["cafeteria", "takeout", "convenience_store", "dorm_storage"] if story_id == "campus_exam" else ["home_kitchen", "community_canteen", "local_market", "home_fridge"]
			for source: String in sources:
				game.phase = "lunch_source" if source in ["takeout", "community_canteen"] else "breakfast_source"
				game._render_phase()
				game._choose_meal_source(source)
				for id in game.hand.slice(0, mini(2, game._source_selection_limit(source))): game._on_food_toggled(String(id))
				await capture("04-food-" + source, "餐食手牌与已选区 · " + source)
			game.phase = "breakfast_action"
			game._render_phase()
			await capture("05-action", "餐后行动卡")
			game.phase = "sleep"
			game._render_phase()
			await capture("06-sleep", "夜间安排卡")
			if story_id == "choir_week":
				game.phase = "breakfast_source"
				game._render_phase()
				game._choose_meal_source("home_kitchen")
				game._confirm_food(["rice_plain", "soft_tofu_greens"])
				await capture("07-cooking", "配方工作台")
				game._close_workspace()
				game._show_kitchen()
				await capture("08-stock", "食材与熟食批次")
				game._close_workspace()
				game.day = 4
				game.phase = "lunch_action"
				game._render_phase()
				game._show_shared_meal_invitation()
				await capture("09-shared-meal", "共同进餐")
				game._close_workspace()
				game.day = 2
				game._render_phase()
				game._show_education()
				await capture("10-lesson", "科普情境练习")
			game.queue_free()
			await process_frame
			game = await new_game(story_id)
			game.new_day_popup.hide_popup(false)
			game._new_day_pending = false
			for meal in range(3):
				game._skip_meal()
				game._skip_action()
			game._choose_sleep("sleep_early")
			await capture("11-summary", "日结与反馈")
			game._show_meal_record_book()
			await capture("12-records", "餐次记录")
			game._record_book.close_book()
			game._show_game_menu()
			await capture("13-progress", "菜单与进度")
			game._close_workspace(false)
			game._show_save_slots(false)
			await capture("14-save-slots", "存档槽位")
			game._close_workspace(false)
			game.day = 7
			game.state[game._goal_key()] = game._goal_target()
			game.performed = story_id == "choir_week"
			game._finish_run("stable_endurance")
			await capture("15-ending", "人物结局")
			game.queue_free()
			await process_frame
	var result := {"errors": errors, "pages": pages, "scope": "Fresh native captures of both stories at portrait and desktop sizes. Declared menu/state/day-completion/ending fixtures, not a complete seven-day playthrough. In-memory saves only."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("CROSS_STORY_UI_RESULT=" + JSON.stringify({"errors": errors, "page_count": pages.size()}))
	quit(0 if errors.is_empty() else 1)


func new_game(story_id: String) -> GameRootV2:
	Session.request(story_id)
	var game := Game.instantiate() as GameRootV2
	game.health_history_path = ""
	root.add_child(game)
	current_scene = game
	game._deck_service.set_seed(20261015)
	await settle()
	return game


func capture(id: String, label: String) -> void:
	await settle()
	var filename := _prefix + "-" + id
	await save(filename)
	pages.append({"id": id, "label": label, "file": filename + ".png", "group": _prefix})
