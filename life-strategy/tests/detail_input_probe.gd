extends RefCounted

## Frame-timed GUI input check for the running V2 game. Run through MCP:
## var probe = load("res://tests/detail_input_probe.gd").new()
## return await probe.run(get_tree().current_scene, Vector2i(720, 1280), "cafeteria")
## This starts an isolated run, never writes health history, and uses actual
## InputEvent dispatch rather than directly invoking close/confirm callbacks.

const Deck := preload("res://scripts/systems/MealDeckService.gd")

var _errors: Array[String] = []
var _game: Variant
var _tree: SceneTree


func run(game: Variant, resolution: Vector2i, source_id: String) -> Dictionary:
	_errors.clear()
	_game = game
	_tree = game.get_tree()
	var window := game.get_window() as Window
	window.mode = Window.MODE_WINDOWED
	window.size = resolution
	await _settle(0.3)
	game.health_history_path = ""
	game.health_guidance_flags = {"data": false, "engine": false, "ui": false, "weekly": false}
	game._deck_service = Deck.new(20260711)
	game.start_new_run()
	game.new_day_popup.hide()
	game._choose_meal_source(source_id)
	await _settle(0.2)
	var cards: Dictionary = game._active_stage._cards_by_id
	var food_id := String(cards.keys()[0])
	var card: Variant = cards[food_id]
	game._on_food_toggled(food_id)
	await _settle(0.2)
	var before := _snapshot()
	# Begin outside the card so this verifies an actual hover transition even
	# when a prior probe left the pointer at the card's initial coordinates.
	await _motion(Vector2(8, 8))
	await _settle(0.15)
	await _motion(_screen_center(card))
	await _settle(0.2)
	_expect(game.sticky_note.visible, "hover preview did not appear")
	_expect(not game.sticky_note.pinned, "hover preview became pinned")
	_expect(not game.sticky_note.close_button.visible, "transient preview exposes a disappearing close target")
	_expect(not game.sticky_note.action_button.visible, "transient preview exposes an action")
	await _motion(Vector2(8, 8))
	await _settle(0.15)
	await _click(_screen_center(card.info_button))
	await _settle(0.2)
	_expect(game.sticky_note.visible and game.sticky_note.pinned, "information button did not open stable details")
	_expect(game.sticky_note.close_button.visible, "pinned details have no close control")
	if cards.size() > 1:
		await _motion(_screen_center(cards[cards.keys()[1]]))
		await _settle(0.15)
		_expect(game.sticky_note.pinned, "another hover unpinned explicit details")
		_expect(String(game.sticky_note.get_payload().get("id", "")) == food_id, "another hover replaced explicit details")
	var logical_size: Vector2 = game.get_viewport().get_visible_rect().size
	await _capture("%dx%d-%s-pinned" % [int(logical_size.x), int(logical_size.y), source_id])
	await _click(_screen_center(game.sticky_note.close_button))
	await _settle(0.15)
	_expect(not game.sticky_note.visible, "close did not dismiss pinned details")
	_expect(_snapshot() == before, "closing details changed phase, money, inventory or meal records")
	await _click(_screen_center(card.info_button))
	await _settle(0.2)
	await _key(KEY_ESCAPE)
	await _settle(0.15)
	_expect(not game.sticky_note.visible, "Escape did not dismiss pinned details")
	_expect(_snapshot() == before, "Escape changed gameplay")
	await _motion(Vector2(8, 8))
	await _settle(0.15)
	var touch_position := _screen_center(card)
	_touch(touch_position, true)
	await _settle(0.6)
	_expect(game.sticky_note.visible and not game.sticky_note.pinned, "held touch did not show a transient preview")
	_expect(not game.sticky_note.close_button.visible, "held touch exposes a close target")
	_touch(touch_position, false)
	await _settle(0.15)
	_expect(not game.sticky_note.visible, "touch release left the preview open")
	_expect(_snapshot() == before, "long press selected or settled food")
	return {
		"valid": _errors.is_empty(), "errors": _errors.duplicate(),
		"requested_size": resolution, "actual_size": window.size,
		"resolution_matched": window.size == resolution,
		"logical_size": game.get_viewport().get_visible_rect().size,
		"source_id": source_id, "food_id": food_id, "before": before, "after": _snapshot(),
		"checks": ["hover_readonly", "pinned_stable", "close_no_settlement", "escape_no_settlement", "touch_hold_release"],
	}


func _snapshot() -> Dictionary:
	return {
		"phase": _game.phase, "state": _game.state.duplicate(true),
		"stock": _game.dorm_inventory.duplicate(true),
		"meal_count": _game.today_meal_records.size(),
		"selected": _game.selected_food_ids.duplicate(),
	}


func _screen_center(control: Control) -> Vector2:
	var window := _game.get_window() as Window
	var factor: Vector2 = Vector2(window.size) / _game.get_viewport().get_visible_rect().size
	return control.get_global_rect().get_center() * factor


func _motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await _tree.process_frame


func _click(position: Vector2) -> void:
	await _motion(position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await _tree.process_frame


func _key(keycode: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await _tree.process_frame


func _touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)


func _settle(seconds: float) -> void:
	await _tree.create_timer(seconds).timeout


func _capture(label: String) -> void:
	var directory := "res://.godot/ux01-2026-10-07"
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	var result: int = _game.get_viewport().get_texture().get_image().save_png(directory + "/" + label + ".png")
	_expect(result == OK, "could not save runtime screenshot")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
