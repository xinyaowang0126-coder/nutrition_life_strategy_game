class_name HouseholdLocations
extends RefCounted

const FOLDER := "res://assets/generated/stories/locations/"
const MARKET_WIDE := FOLDER + "zhou-market-wide-v1.png"
const MARKET_PORTRAIT := FOLDER + "zhou-market-portrait-v1.png"
const KITCHEN_PORTRAIT := FOLDER + "zhou-kitchen-portrait-v1.png"
const MEAL_BACKGROUNDS := {
	"home_kitchen": FOLDER + "zhou-kitchen-v1.png",
	"home_fridge": FOLDER + "zhou-open-fridge-v1.png",
	"breakfast_shop": FOLDER + "zhou-breakfast-shop-v1.png",
	# Stable source IDs keep existing meals, saves and invitations readable.
	"community_canteen": FOLDER + "zhou-homestyle-diner-v1.png",
	"local_market": FOLDER + "zhou-fruit-stall-v1.png",
}
const PORTRAIT_START_X := {"zhou-open-fridge-v1.png": 0.14, "zhou-breakfast-shop-v1.png": 0.11, "zhou-homestyle-diner-v1.png": 0.12, "zhou-kitchen-v1.png": 0.26}


static func meal_background(source: String, mobile: bool = false) -> String:
	if mobile and source == "home_kitchen": return KITCHEN_PORTRAIT
	return String(MEAL_BACKGROUNDS.get(source, ""))


static func texture_for(path: String, mobile: bool) -> Texture2D:
	var texture := load(path) as Texture2D
	if not mobile or not MEAL_BACKGROUNDS.values().has(path): return texture
	# The illustration puts its identifying objects at the left. A centred
	# crop of the full landscape would show the quiet wall behind the menu.
	var crop := AtlasTexture.new()
	crop.atlas = texture
	var width := minf(texture.get_width(), texture.get_height() * 0.70)
	var left := minf(texture.get_width() - width, float(PORTRAIT_START_X.get(path.get_file(), 0.0)) * texture.get_width())
	crop.region = Rect2(left, 0, width, texture.get_height())
	crop.filter_clip = true
	return crop
