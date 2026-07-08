class_name CardDataStore
extends RefCounted

const FOODS_XML := "res://data/cards/foods.xml"
const ACTIONS_XML := "res://data/cards/actions.xml"
const SLEEP_OPTIONS_XML := "res://data/cards/sleep_options.xml"

const INT_FIELDS := [
	"cost",
	"slots",
	"satiety",
	"energy",
	"mood",
	"burden",
	"stress",
	"study",
]

const CSV_FIELDS := ["tags", "scenes"]

static var food_ids: Array[String] = []
static var foods: Dictionary = {}
static var action_ids: Array[String] = []
static var actions: Dictionary = {}
static var sleep_option_ids: Array[String] = []
static var sleep_options: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return

	food_ids.clear()
	foods.clear()
	action_ids.clear()
	actions.clear()
	sleep_option_ids.clear()
	sleep_options.clear()

	_load_xml_cards(FOODS_XML, "food", food_ids, foods)
	_load_xml_cards(ACTIONS_XML, "action", action_ids, actions)
	_load_xml_cards(SLEEP_OPTIONS_XML, "sleep_option", sleep_option_ids, sleep_options)
	_loaded = true


static func get_food(id: String) -> Dictionary:
	ensure_loaded()
	if not foods.has(id):
		push_error("Unknown food id: %s" % id)
		return {}
	return foods[id].duplicate(true)


static func get_action(id: String) -> Dictionary:
	ensure_loaded()
	if not actions.has(id):
		push_error("Unknown action id: %s" % id)
		return {}
	return actions[id].duplicate(true)


static func get_sleep_option(id: String) -> Dictionary:
	ensure_loaded()
	if not sleep_options.has(id):
		push_error("Unknown sleep id: %s" % id)
		return {}
	return sleep_options[id].duplicate(true)


static func get_food_ids_for_scene(scene: String) -> Array[String]:
	ensure_loaded()
	var ids: Array[String] = []
	for id in food_ids:
		if is_food_available(id, scene):
			ids.append(id)
	return ids


static func get_action_ids_for_scene(scene: String) -> Array[String]:
	ensure_loaded()
	var ids: Array[String] = []
	for id in action_ids:
		if is_action_available(id, scene):
			ids.append(id)
	return ids


static func get_sleep_option_ids_for_scene(scene: String) -> Array[String]:
	ensure_loaded()
	var ids: Array[String] = []
	for id in sleep_option_ids:
		if is_sleep_option_available(id, scene):
			ids.append(id)
	return ids


static func is_food_available(id: String, scene: String) -> bool:
	ensure_loaded()
	return foods.has(id) and _has_scene(foods[id], scene)


static func is_action_available(id: String, scene: String) -> bool:
	ensure_loaded()
	return actions.has(id) and _has_scene(actions[id], scene)


static func is_sleep_option_available(id: String, scene: String) -> bool:
	ensure_loaded()
	return sleep_options.has(id) and _has_scene(sleep_options[id], scene)


static func cheapest_food_cost(scene: String = "") -> int:
	ensure_loaded()
	var cheapest := 999
	for id in food_ids:
		if not scene.is_empty() and not is_food_available(id, scene):
			continue
		cheapest = min(cheapest, int(foods[id]["cost"]))
	return cheapest


static func _load_xml_cards(path: String, element_name: String, ids: Array[String], target: Dictionary) -> void:
	var parser := XMLParser.new()
	var err := parser.open(path)
	if err != OK:
		push_error("Failed to open card XML: %s (error %d)" % [path, err])
		return

	var current: Dictionary = {}
	var reading_desc := false
	while parser.read() == OK:
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			if node_name == element_name:
				current = _read_attributes(parser)
			elif node_name == "desc" and not current.is_empty():
				reading_desc = true
		elif node_type == XMLParser.NODE_TEXT or node_type == XMLParser.NODE_CDATA:
			if reading_desc and not current.is_empty():
				var desc := parser.get_node_data().strip_edges()
				if not desc.is_empty():
					current["desc"] = String(current.get("desc", "")) + desc
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name := parser.get_node_name()
			if end_name == "desc":
				reading_desc = false
			elif end_name == element_name:
				_append_card(current, ids, target, path)
				current = {}


static func _read_attributes(parser: XMLParser) -> Dictionary:
	var out := {}
	for index in range(parser.get_attribute_count()):
		var key := parser.get_attribute_name(index)
		var value := parser.get_attribute_value(index)
		if CSV_FIELDS.has(key):
			out[key] = _split_csv(value)
		elif INT_FIELDS.has(key):
			out[key] = int(value)
		else:
			out[key] = value
	return out


static func _append_card(card: Dictionary, ids: Array[String], target: Dictionary, source_path: String) -> void:
	if card.is_empty():
		return
	if not card.has("id") or String(card["id"]).is_empty():
		push_error("Card without id in %s" % source_path)
		return

	var id := String(card["id"])
	card["id"] = id
	if not card.has("tags"):
		card["tags"] = []
	if not card.has("scenes"):
		card["scenes"] = ["any"]
	if not card.has("desc"):
		card["desc"] = ""

	ids.append(id)
	target[id] = card.duplicate(true)


static func _split_csv(value: String) -> Array[String]:
	var out: Array[String] = []
	for raw in value.split(",", false):
		var item := String(raw).strip_edges()
		if not item.is_empty():
			out.append(item)
	return out


static func _has_scene(item: Dictionary, scene: String) -> bool:
	if scene.is_empty():
		return true
	var scenes: Array = item.get("scenes", [])
	return scenes.has("any") or scenes.has(scene)
