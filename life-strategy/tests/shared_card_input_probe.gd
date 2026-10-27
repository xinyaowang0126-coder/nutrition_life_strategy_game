extends "res://tests/story_keyboard_visual_probe.gd"

var cases: Array[Dictionary] = []


func _run() -> void:
	var routine_only := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--routine-only": routine_only = true
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(640, 960), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		await settle()
		for story in ["campus_exam", "choir_week"]:
			Session.request(story)
			var game := Game.instantiate() as GameRootV2
			game.health_history_path = ""
			root.add_child(game)
			current_scene = game
			await settle()
			game.new_day_popup.hide_popup(false)
			game._new_day_pending = false
			game._deck_service.set_seed(20261015)
			var sources: Array = ["cafeteria", "takeout", "convenience_store", "dorm_storage"] if story == "campus_exam" else ["home_kitchen", "community_canteen", "local_market", "home_fridge"]
			if routine_only: sources.clear()
			for source: String in sources:
				var prefix := "%dx%d-%s-%s" % [resolution.x, resolution.y, story, source]
				game.phase = "lunch_source" if source in ["takeout", "community_canteen"] else "breakfast_source"
				game._render_phase()
				game._choose_meal_source(source)
				var ids: Array[String] = [game.hand[0], game.hand[1]]
				var before := {"state": game.state.duplicate(true), "pantry": game.kitchen.ingredients.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true), "dorm": game.dorm_inventory.duplicate(true)}
				var stage := game._active_stage as MealStageBaseV2
				for id in ids: stage._on_card_selected(id)
				await settle()
				var slot := stage._get_slot_nodes()[0] as SelectedFoodCardV2
				check(slot != null and slot.preview.visible and slot.preview.size.y > 8, prefix + ": no shared selected-card artwork")
				await click(slot.preview)
				check(game.selected_food_ids == [ids[1]], prefix + ": whole-card mouse removal changed the wrong selection")
				slot = stage._get_slot_nodes()[0] as SelectedFoodCardV2
				slot.remove_button.grab_focus()
				await key(KEY_ENTER)
				check(game.selected_food_ids.is_empty() and stage._get_confirm_button().disabled, prefix + ": keyboard removal did not clear selection safely")
				check(root.gui_get_focus_owner() == stage._cards_by_id[ids[1]], prefix + ": last removal did not restore food-card focus")
				stage._on_card_selected(ids[0])
				await settle()
				slot = stage._get_slot_nodes()[0] as SelectedFoodCardV2
				await touch_card(slot.preview)
				check(game.selected_food_ids.is_empty(), prefix + ": whole-card touch removal did not execute once")
				check(game.state == before["state"] and game.kitchen.ingredients == before["pantry"] and game.kitchen.condiments == before["condiments"] and game.dorm_inventory == before["dorm"], prefix + ": selection editing spent resources")
				check(game.today_meal_records.is_empty(), prefix + ": selection editing settled a meal")
				await save(prefix)
				cases.append({"story": story, "source": source, "window": str(resolution)})
			for phase_name in ["breakfast_action", "sleep"]:
				game.phase = phase_name
				game._render_phase()
				await settle()
				var scroll: ScrollContainer
				var last_card: CompactChoiceCardV2
				if phase_name == "sleep":
					var sleep := game._active_stage as SleepStageV2
					scroll = sleep.sleep_scroll
					last_card = sleep._cards_by_id.values().back()
				else:
					var actions := game._active_stage as ActionStageV2
					scroll = actions.action_scroll
					last_card = actions._cards_by_id.values().back()
				# The illustrated card itself is the visible selection control;
				# its legacy SelectButton is hidden in the shared scene.
				last_card.grab_focus()
				await settle()
				var focus_prefix := "%dx%d-%s-%s" % [resolution.x, resolution.y, story, phase_name]
				var scroll_rect := scroll.get_global_rect()
				check(root.gui_get_focus_owner() == last_card, focus_prefix + ": the visible card must receive keyboard focus")
				# Scroll offsets are integer pixels while the responsive rail uses
				# fractional coordinates. Allow one logical pixel of rounding only.
				check(scroll_rect.grow(1.0).encloses(last_card.get_global_rect()), "%s: focused card must be scrolled into view; scroll=%s, card=%s" % [focus_prefix, scroll_rect, last_card.get_global_rect()])
				await save(focus_prefix)
				last_card.info_button.grab_focus()
				await settle()
				check(root.gui_get_focus_owner() == last_card.info_button and scroll.get_global_rect().grow(1.0).encloses(last_card.info_button.get_global_rect()), focus_prefix + ": focused details button must be scrolled into view")
				cases.append({"story": story, "source": phase_name, "window": str(resolution), "scroll_rect": str(scroll_rect), "card_rect": str(last_card.get_global_rect()), "scroll_horizontal": scroll.scroll_horizontal, "card_scale": str(last_card.scale)})
			game.queue_free()
			await process_frame
	var result := {"errors": errors, "cases": cases, "scope": "Both stories, all eight sources, action and sleep cards, portrait and desktop. Actual native mouse on selected-card artwork, keyboard Enter and ScreenTouch; far-card focus scrolling. Declared source/day fixtures; no meals confirmed. In-memory saves only."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("SHARED_CARD_INPUT_RESULT=" + JSON.stringify({"errors": errors, "cases": cases.size()}))
	quit(0 if errors.is_empty() else 1)


func touch_card(control: Control) -> void:
	var point := control.get_global_rect().get_center() * (Vector2(root.size) / root.get_visible_rect().size)
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()
