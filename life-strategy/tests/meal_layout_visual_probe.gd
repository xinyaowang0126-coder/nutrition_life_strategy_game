extends SceneTree

const GameScene := preload("res://scenes/game_v2/GameRootV2.tscn")
const SIZES := [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(720, 1280), Vector2i(390, 844)]
var _output := "res://.godot/meal-layout-visual"
var _errors: Array[String] = []
var _cases: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sizes := SIZES.duplicate()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
		elif argument.begins_with("--size="):
			var dimensions := argument.trim_prefix("--size=").split("x")
			if dimensions.size() == 2:
				sizes = [Vector2i(int(dimensions[0]), int(dimensions[1]))]
	DirAccess.make_dir_recursive_absolute(_output)
	for resolution in sizes:
		root.size = resolution
		await _settle()
		_check(DisplayServer.window_get_size() == resolution, "Physical window did not reach " + str(resolution))
		var game := GameScene.instantiate() as GameRootV2
		game.health_history_path = ""
		root.add_child(game)
		current_scene = game
		await _settle()
		_check(game._mobile_mode == (resolution.y > resolution.x * 1.18), "Responsive profile does not match " + str(resolution))
		var reference := {}
		for source in ["cafeteria", "takeout", "convenience_store", "dorm_storage"]:
			game.start_new_run()
			game.new_day_popup.hide_popup(false)
			if source == "takeout":
				game.phase = "lunch_source"
				game._render_phase()
			game._choose_meal_source(source)
			await _settle()
			var stage := game._active_stage as MealStageBaseV2
			var regions := stage.get_selection_layout_rects()
			var footer := stage.get_node(String(stage._get_layout_paths()["footer"])) as Control
			for button_name in ["BackButton", "SkipButton", "ConfirmButton"]:
				regions[button_name] = (footer.get_node(button_name) as Control).get_global_rect()
			regions["first_slot"] = (stage._get_slot_nodes()[0] as Control).get_global_rect()
			var prefix := "%dx%d-%s" % [resolution.x, resolution.y, source]
			if reference.is_empty():
				reference = regions
			else:
				for key in ["cards", "selection", "footer", "BackButton", "SkipButton", "ConfirmButton", "first_slot"]:
					_check((regions[key] as Rect2).is_equal_approx(reference[key]), prefix + " has a different " + key + " region")
			_check((regions["cards"] as Rect2).end.y <= (regions["selection"] as Rect2).position.y, prefix + " cards overlap selected food")
			_check((regions["selection"] as Rect2).end.y <= (regions["footer"] as Rect2).position.y, prefix + " selected food covers buttons")
			var visible := game.get_viewport().get_visible_rect()
			_check(visible.encloses(stage._get_confirm_button().get_global_rect()), prefix + " confirmation is outside the viewport")
			var food_id := ""
			for id in stage._cards_by_id:
				if stage._disabled_reason(String(id)).is_empty():
					food_id = String(id)
					break
			_check(not food_id.is_empty(), prefix + " has no available card")
			if food_id.is_empty():
				continue
			var card: Variant = stage._cards_by_id[food_id]
			var card_scroll := stage._get_card_container().get_parent() as ScrollContainer
			if card is CompactChoiceCardV2:
				_check(card_scroll.get_global_rect().encloses(card.title_label.get_global_rect()), prefix + " first available card name is clipped")
				_check(card_scroll.get_global_rect().encloses(card.primary_stat.get_global_rect()), prefix + " first available card stats are clipped")
			var initial_paper: Color = (card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
			await _save(prefix + "-normal")
			var factor := Vector2(root.size) / game.get_viewport().get_visible_rect().size
			var position: Vector2 = card.get_global_rect().get_center() * factor
			var motion := InputEventMouseMotion.new()
			motion.position = position
			motion.global_position = position
			Input.parse_input_event(motion)
			await _settle()
			_check(game.sticky_note.visible and not game.sticky_note.pinned, prefix + " hover details failed")
			for pressed in [true, false]:
				var mouse := InputEventMouseButton.new()
				mouse.position = position
				mouse.global_position = position
				mouse.button_index = MOUSE_BUTTON_LEFT
				mouse.pressed = pressed
				Input.parse_input_event(mouse)
				await process_frame
			await _settle()
			_check(stage.get_selected_ids().has(food_id), prefix + " surface click failed")
			_check((card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color != initial_paper, prefix + " selected paper colour did not change")
			_check(card.self_modulate != Color.WHITE, prefix + " selected card has no warm tint")
			var outside := InputEventMouseMotion.new()
			outside.position = Vector2(8, 8)
			outside.global_position = outside.position
			Input.parse_input_event(outside)
			await _settle()
			for id in stage._cards_by_id:
				if stage.get_selected_ids().size() >= stage._max_selected:
					break
				if not stage.get_selected_ids().has(String(id)) and stage._disabled_reason(String(id)).is_empty():
					stage._on_card_selected(String(id))
			await _settle()
			var selected_rect := stage.get_selection_layout_rects()["selection"] as Rect2
			_check(selected_rect.is_equal_approx(regions["selection"]), prefix + " selection contents expanded the panel")
			for index in range(stage.get_selected_ids().size()):
				var selected_card := stage._get_slot_nodes()[index] as SelectedFoodCardV2
				var card_rect := selected_card.get_global_rect()
				_check(selected_rect.encloses(card_rect), prefix + " selected card is clipped by its panel")
				_check(selected_card.preview.visible and selected_card.preview.texture != null, prefix + " selected card lost its picture")
				_check(card_rect.encloses(selected_card.preview.get_global_rect()), prefix + " selected picture extends outside its card")
				_check(card_rect.encloses(selected_card.title_label.get_global_rect()), prefix + " selected name extends outside its card")
				_check(card_rect.encloses(selected_card.preference_label.get_global_rect()), prefix + " selected stats extend outside its card")
				_check(not selected_card.title_label.text.is_empty(), prefix + " selected card has no name")
			await _save(prefix + "-selected")
			_cases.append({"size": resolution, "source": source, "regions": str(regions), "selected": food_id, "tint": str(card.self_modulate)})
		for phase_name in ["breakfast_source", "breakfast_action", "lunch_action", "dinner_action", "sleep"]:
			game.phase = phase_name
			game._render_phase()
			await _settle()
			var stage := game._active_stage as Control
			var prefix := "%dx%d-%s" % [resolution.x, resolution.y, phase_name]
			if stage is MealSourceStageV2:
				var skip := stage.get_node("Footer/SkipButton") as Button
				var rules := stage.get_node("Footer/MenuHintButton") as Button
				_check(skip.get_global_rect().is_equal_approx(reference["SkipButton"]), prefix + " skip button differs from meal selection")
				_check(rules.get_global_rect().is_equal_approx(reference["ConfirmButton"]), prefix + " rightmost button differs from other stages")
				await _save(prefix)
				_cases.append({"size": resolution, "phase": phase_name, "skip": str(skip.get_global_rect()), "rules": str(rules.get_global_rect())})
				continue
			var action_phase := stage is ActionStageV2
			var rail := stage.get_node("Layout/ActionRail" if action_phase else "Layout/SleepRail") as Control
			var note := stage.get_node("Layout/PlannerNote" if action_phase else "Layout/AlarmNote") as Control
			_check(rail.get_global_rect().is_equal_approx(reference["cards"]), prefix + " card rail differs from meal selection")
			_check(note.get_global_rect().is_equal_approx(reference["selection"]), prefix + " note differs from the shared selection position")
			if action_phase:
				var button := stage.get_node("Layout/SkipButton") as Button
				_check(button.get_global_rect().is_equal_approx(reference["ConfirmButton"]), prefix + " next-step button differs from meal confirmation")
			await _save(prefix)
			_cases.append({"size": resolution, "phase": phase_name, "cards": str(rail.get_global_rect()), "selection": str(note.get_global_rect())})
		root.remove_child(game)
		game.queue_free()
		await process_frame
	var result := {"valid": _errors.is_empty(), "errors": _errors, "cases": _cases, "scope": "Native Windows render and injected mouse events; not physical-device testing."}
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("MEAL_LAYOUT_VISUAL_RESULT=" + JSON.stringify({"valid": result["valid"], "errors": _errors, "cases": _cases.size()}))
	quit(0 if _errors.is_empty() else 1)


func _settle() -> void:
	await create_timer(0.4).timeout
	for frame in range(3):
		await process_frame
	RenderingServer.force_draw()


func _save(name: String) -> void:
	RenderingServer.force_draw()
	_check(root.get_texture().get_image().save_png(_output.path_join(name + ".png")) == OK, "Screenshot failed: " + name)


func _check(valid: bool, message: String) -> void:
	if not valid:
		_errors.append(message)
