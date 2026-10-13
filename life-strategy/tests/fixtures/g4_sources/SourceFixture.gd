extends RefCounted

## TEST ONLY: simulated profiles/reviews under real card IDs. These are not
## production recipes or professional approval. Prices/pools remain real.
const Model := preload("res://tests/preview/G4PreviewModel.gd")
const Data := preload("res://scripts/GameData.gd")
const DATE := "2026-10-09"
const PROFILE_BY_ID := {
	"rice_plain": "fixture_rice", "mixed_grain_rice": "fixture_rice",
	"oatmeal": "fixture_rice", "instant_noodles": "fixture_rice",
	"egg": "fixture_egg", "tofu": "fixture_egg", "fried_chicken": "fixture_egg",
	"tomato": "fixture_vegetable", "greens": "fixture_vegetable", "salad_bowl": "fixture_vegetable",
	"sandwich": "fixture_mixed", "apple": "fixture_fruit", "banana": "fixture_fruit",
	"milk": "fixture_dairy", "yogurt": "fixture_dairy",
}
var catalog: Dictionary
var config: Dictionary
var registry
var copies: Dictionary


func _init() -> void:
	var model := Model.new()
	config = model.config.duplicate(true)
	registry = model.registry
	copies = model.copies.duplicate(true)
	catalog = model.catalog.duplicate(true)
	catalog["profiles"] = {}
	catalog["profile_entries"] = []
	for id in Data.get_food_ids_for_scene("meal"):
		var profile: Dictionary = model.catalog["profiles"][PROFILE_BY_ID.get(id, "fixture_low")].duplicate(true)
		profile["food_id"] = id
		catalog["profiles"][id] = profile
		catalog["profile_entries"].append(profile.duplicate(true))
