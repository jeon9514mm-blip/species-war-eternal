extends RefCounted
class_name FieldArtCatalog

## v70 shared non-pixel hunt-map artwork for combat, lobby and world cards.
## Internal zone ids remain unchanged for save compatibility.
const ROOT := "res://assets/terrain-v70/"
const PATHS := {
	"gray_meadow": ROOT + "evergreen-meadow.png",
	"forgotten_mine": ROOT + "crimson-canyon.png",
	"moonrest_forest": ROOT + "arcane-sanctuary.png",
}
const CAMP_PATH := ROOT + "evergreen-overview.png"
const SOURCE_UVS := {
	"gray_meadow": Rect2(0.0, 0.0, 1.0, 1.0),
	"forgotten_mine": Rect2(0.0, 0.0, 1.0, 1.0),
	"moonrest_forest": Rect2(0.0, 0.0, 1.0, 1.0),
}
const BASE_COLORS := {
	"gray_meadow": Color("#6ca348"),
	"forgotten_mine": Color("#8e4b35"),
	"moonrest_forest": Color("#587f91"),
}

static func texture_path(zone_id: String) -> String:
	return str(PATHS.get(zone_id, PATHS["gray_meadow"]))

static func texture_for(zone_id: String) -> Texture2D:
	var path := texture_path(zone_id)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func source_uv(zone_id: String) -> Rect2:
	return SOURCE_UVS.get(zone_id, Rect2(0.0, 0.0, 1.0, 1.0))

static func world_art_rect(zone_id: String, world_size := Vector2(32.0, 20.0)) -> Rect2:
	var uv := source_uv(zone_id)
	return Rect2(-uv.position / uv.size * world_size, world_size / uv.size)

static func base_color(zone_id: String) -> Color:
	return BASE_COLORS.get(zone_id, BASE_COLORS["gray_meadow"])

static func camp_texture_path() -> String:
	return CAMP_PATH

static func camp_texture() -> Texture2D:
	return load(CAMP_PATH) as Texture2D if ResourceLoader.exists(CAMP_PATH) else null
