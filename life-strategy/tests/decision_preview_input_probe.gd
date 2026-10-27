extends "res://tests/story_keyboard_visual_probe.gd"

var cases: Array[Dictionary] = []


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	for resolution in [Vector2i(390, 640), Vector2i(640, 960), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		await settle()
		for story_id in ["campus_exam", "choir_week"]:
			Session.request(story_id)
			var game := Game.instantiate() as GameRootV2
			game.health_history_path = ""
			root.add_child(game)
			current_scene = game
			await settle()
			game.new_day_popup.hide_popup(false)
			game._new_day_pending = false
			game._deck_service.set_seed(20261016)
			var sources := ["cafeteria", "takeout", "convenience_store", "dorm_storage"] if story_id == "campus_exam" else ["home_kitchen", "community_canteen", "local_market", "home_fridge"]
			for source_id: String in sources:
				var prefix := "%dx%d-%s-%s" % [resolution.x, resolution.y, story_id, source_id]
				game.phase = "lunch_source" if source_id in ["takeout", "community_canteen"] else "breakfast_source"
				game._render_phase()
				await settle()
				var name_target: Control
				if story_id == "campus_exam":
					name_target = (game._active_stage as MealSourceStageV2)._prop_for(source_id).get_node("Name/NameTarget")
				else:
					if source_id in HouseholdSourceStage.OUTSIDE_ORDER:
						await click(game._active_stage.find_child("go_out", true, false))
						name_target = game._story_dialog._buttons.get_node(source_id)
					var source_card := game._active_stage.find_child(source_id, true, false) as Button
					if source_card != null:
						name_target = (game._active_stage as HouseholdSourceStage)._props[source_id].get_node("Nameplate")
				await click(name_target)
				check(game.current_source_id == source_id, prefix + ": visible source name did not activate the same source as its artwork")
				var stage := game._active_stage as MealStageBaseV2
				if stage == null:
					check(false, prefix + ": source name did not open meal selection")
					continue
				var before := {"state": game.state.duplicate(true), "pantry": game.kitchen.ingredients.duplicate(true), "dorm": game.dorm_inventory.duplicate(true), "condiments": game.kitchen.condiments.duplicate(true)}
				for id in game.hand.slice(0, 2): game._on_food_toggled(id)
				await settle()
				var label := stage._get_cost_preview_label()
				var surface := stage.paper_panel.get_global_rect() if stage is HouseholdMealStage else stage.get_selection_layout_rects()["selection"] as Rect2
				check(label.visible and surface.grow(1).encloses(label.get_global_rect()), prefix + ": cost preview escaped its paper")
				check(label.get_global_rect().end.y <= stage._get_confirm_button().get_global_rect().position.y + 1, prefix + ": cost preview overlaps confirmation")
				for slot: SelectedFoodCardV2 in stage._get_slot_nodes():
					if not slot.is_visible_in_tree(): continue
					check(surface.grow(1).encloses(slot.get_global_rect()), prefix + ": selected card escaped its paper after cost wrapping")
				check(game.state == before["state"] and game.kitchen.ingredients == before["pantry"] and game.kitchen.condiments == before["condiments"] and game.dorm_inventory == before["dorm"], prefix + ": opening or reading costs spent resources")
				check(game.today_meal_records.is_empty(), prefix + ": cost preview settled a meal")
				if stage is DormPantryStageV2:
					var pantry := stage as DormPantryStageV2
					for card: CompactChoiceCardV2 in pantry.stock_grid.get_children().slice(0, 2):
						check(pantry.pantry_scroll.get_global_rect().grow(1).encloses(card.title_label.get_global_rect()), prefix + ": first pantry row name is clipped")
						check(pantry.pantry_scroll.get_global_rect().grow(1).encloses(card.primary_stat.get_global_rect()), prefix + ": first pantry row stats are clipped")
				await save(prefix)
				cases.append({"story": story_id, "source": source_id, "window": str(resolution), "preview": stage.get_cost_preview()})
			if story_id == "campus_exam":
				game.phase = "breakfast_source"
				game.current_source_id = ""
				game._render_phase()
				await settle()
				var source_stage := game._active_stage as MealSourceStageV2
				await click(source_stage._prop_for("takeout").get_node("Name") as Control)
				check(game.phase == "breakfast_source" and game.current_source_id.is_empty(), "closed takeout name entered the source")
				await click(source_stage._prop_for("takeout").get_node("Info") as Control)
				check(game.sticky_note.visible and game.sticky_note.pinned, "closed source details unavailable")
				await save("%dx%d-closed-source-details" % [resolution.x, resolution.y])
				await key(KEY_ESCAPE)
				var signals := {"count": 0}
				source_stage.source_selected.connect(func(_id: String) -> void: signals["count"] += 1)
				await touch(source_stage._prop_for("cafeteria").get_node("Name/NameTarget") as Control)
				check(game.current_source_id == "cafeteria" and signals["count"] == 1, "source-name touch did not choose exactly once")
				cases.append({"story": story_id, "source": "closed_name_and_touch", "window": str(resolution)})
			for phase_name in ["breakfast_action", "sleep"]:
				game.phase = phase_name
				game._render_phase()
				await settle()
				var cards: Dictionary = game._active_stage._cards_by_id
				var scroll: ScrollContainer = game._active_stage.action_scroll if phase_name == "breakfast_action" else game._active_stage.sleep_scroll
				for card: CompactChoiceCardV2 in cards.values():
					check(card.choice_cost_label.visible and card.get_global_rect().grow(1).encloses(card.choice_cost_label.get_global_rect()), "%s/%s: choice costs overflowed their card" % [story_id, phase_name])
				var last_card := cards.values().back() as CompactChoiceCardV2
				last_card.grab_focus()
				await settle()
				check(scroll.get_global_rect().grow(1).encloses(last_card.get_global_rect()), "%dx%d/%s/%s: cost labels made a focused card too tall" % [resolution.x, resolution.y, story_id, phase_name])
				await save("%dx%d-%s-%s" % [resolution.x, resolution.y, story_id, phase_name])
				cases.append({"story": story_id, "source": phase_name, "window": str(resolution)})
			game.queue_free()
			await process_frame
	var result := {"errors": errors, "cases": cases, "scope": "Both stories, eight source names and live meal costs, first pantry row readability, action/sleep cost labels and focus at 390x640, 640x960 and 1280x720 native windows. Actual nameplate mouse clicks, closed-source details, Enter/Escape and raw ScreenTouch. Declared phases/hands, in-memory saves, no meals confirmed; not a seven-day UI playthrough."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("DECISION_PREVIEW_INPUT_RESULT=" + JSON.stringify({"errors": errors, "cases": cases.size()}))
	quit(0 if errors.is_empty() else 1)


func touch(control: Control) -> void:
	var point := control.get_global_rect().get_center() * (Vector2(root.size) / root.get_visible_rect().size)
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()
