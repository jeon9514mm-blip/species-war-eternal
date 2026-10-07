extends RefCounted
class_name PixelFxAtlas

## Supplemental hand-drawn raster bursts only. Canonical hero signatures remain.
## Never changes damage, status, target count, timing or proc conditions.
const ATLAS_PATH := "res://assets/fx/pixel-v32/elemental-spell-atlas-v32.png"
const FRAME_COUNT := 4
const EFFECT_ROWS := {"solar_flare": 0, "rune_spark": 1, "leaf_heal": 2, "ruby_shield": 3}
static var _textures: Dictionary = {}

static func effect_for(hero_id: String, slot: String, mode: String) -> String:
	if slot == "passive": return ""
	if hero_id == "elisia" and mode == "heal": return "leaf_heal"
	if hero_id == "selene" and mode == "shield": return "ruby_shield"
	if mode == "enemy" and slot in ["a1", "ultimate"]:
		if hero_id == "caelum": return "solar_flare"
		if hero_id == "tessa": return "rune_spark"
	return ""

static func frame_texture(effect: String, frame: int) -> Texture2D:
	if not EFFECT_ROWS.has(effect): return null
	frame = clampi(frame, 0, FRAME_COUNT - 1)
	var key := effect + str(frame)
	if _textures.has(key): return _textures[key]
	if not ResourceLoader.exists(ATLAS_PATH): return null
	var atlas := load(ATLAS_PATH) as Texture2D
	# Source cells use integer boundaries even when a generated atlas is 1254px.
	var x0 := floori(float(atlas.get_width()) * frame / 4.0)
	var x1 := floori(float(atlas.get_width()) * (frame + 1) / 4.0)
	var row := int(EFFECT_ROWS[effect])
	var y0 := floori(float(atlas.get_height()) * row / 4.0)
	var y1 := floori(float(atlas.get_height()) * (row + 1) / 4.0)
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(x0, y0, x1 - x0, y1 - y0)
	texture.filter_clip = true
	_textures[key] = texture
	return texture
