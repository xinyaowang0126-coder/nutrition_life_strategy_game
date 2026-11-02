extends RefCounted

const Flow := preload("res://scripts/stories/HouseholdLearningFlow.gd")
const Worktop := preload("res://scripts/stories/HouseholdWorktop.gd")


static func resume(game: Node) -> void:
	if not game._household(): return
	var stage: String = game.household_learning.get("opening_stage", "legacy")
	if stage in ["pending", "decision"]:
		game.household_learning["opening_stage"] = "available"
	elif stage == "breakfast":
		game.household_learning["opening_stage"] = "done"
	else:
		return
	game._queue_autosave()


static func open(game: Node) -> bool:
	if not game.is_node_ready() or not game._household() or game.day != 1 or not game._is_source_phase() or game._new_day_pending: return false
	if int(Flow.opening_batch(game.kitchen).get("quantity", 0)) <= 0: return false
	var generation: int = game._save_generation
	var page := Worktop.new()
	page.name = "OpeningLeftovers"
	game._present_workspace(page, func() -> void:
		if not _current(game, page, generation): return
		resolve_opening(game, "leave")
		game._close_workspace()
	)
	page.title_label.text = "昨晚留下的菜"
	page.subtitle_label.text = "保存记录"
	page.close_button.text = "回去安排这顿饭"
	page.body.add_child(HouseholdUI.image(HouseholdUI.food_texture(game._story_food("greens")), 160))
	HouseholdUI.note(page.body, Flow.opening_body(game.kitchen), true)
	var discard := HouseholdUI.button("丢弃这份菜", "DiscardLeftovers", true)
	page.footer.add_child(discard)
	discard.pressed.connect(func() -> void:
		if _current(game, page, generation) and resolve_opening(game, "discard"):
			game._close_workspace()
	)
	return true


static func _current(game: Node, page: Control, generation: int) -> bool:
	return is_instance_valid(page) and page == game._workspace and page.visible and not page.is_queued_for_deletion() and generation == game._save_generation


static func resolve_opening(game: Node, choice: String) -> bool:
	if not game._household() or game.day != 1 or not game._is_source_phase() or choice not in ["discard", "leave"]: return false
	if int(Flow.opening_batch(game.kitchen).get("quantity", 0)) <= 0: return false
	if choice == "discard" and not game.kitchen.discard(Flow.OPENING_BATCH, game.day): return false
	game.household_learning["opening_choice"] = choice
	game.household_learning["opening_stage"] = "done"
	game._queue_autosave()
	return true
