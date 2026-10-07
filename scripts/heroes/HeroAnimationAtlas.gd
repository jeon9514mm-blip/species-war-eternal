extends RefCounted
class_name HeroAnimationAtlas

## Four source poses per hero: idle, left-foot walk, right-foot walk, attack.
## Each original PNG has four poses / five heroes, with irregular spacing.
## Measured regions preserve every visible pixel; all poses share a feet line.
## These new atlases have one three-quarter facing, mirrored for left movement.
const LAYOUT = preload("res://scripts/heroes/HeroAnimationAtlasLayout.gd")
const PIXEL_OVERRIDES = preload("res://assets/sprites/pixel-v32/animation-layout.gd")
const COLUMNS := 4
const ROWS := 5
const ROOT := "res://assets/sprites/heroes-v31/"
const GROUPS := {
	"a01": ["leonhardt", "mira", "elisia", "kairen", "orwin"],
	"a06": ["seria", "astel", "darius", "lunea", "caelum"],
	"a11": ["adrien", "tessa", "naia", "sael", "odelia"],
	"n01": ["valeria", "morgas", "ragna", "bron", "nyx"],
	"n06": ["fenris", "isolde", "garm", "veyra", "ulric"],
	"n11": ["lucien", "corvin", "rokan", "bora", "selene"]
}

static var _layouts: Dictionary = {}

static func sheet_path(hero_id: String) -> String:
	if PIXEL_OVERRIDES.SHEETS.has(hero_id):
		return str(PIXEL_OVERRIDES.SHEETS[hero_id])
	for key in GROUPS:
		if hero_id in GROUPS[key]:
			return "%s%s-sheet.png" % [ROOT, key]
	return ""

static func row_index(hero_id: String) -> int:
	if PIXEL_OVERRIDES.SHEETS.has(hero_id):
		return 0
	for group in GROUPS.values():
		var index: int = group.find(hero_id)
		if index >= 0:
			return index
	return -1

static func has_hero(hero_id: String) -> bool:
	var path := sheet_path(hero_id)
	return (LAYOUT.REGIONS.has(hero_id) or PIXEL_OVERRIDES.REGIONS.has(hero_id)) and not path.is_empty() and ResourceLoader.exists(path)

static func layout(texture: Texture2D, hero_id: String) -> Dictionary:
	if texture == null:
		return {}
	if not LAYOUT.REGIONS.has(hero_id) and not PIXEL_OVERRIDES.REGIONS.has(hero_id):
		return {}
	var cache_key := "%s:%d" % [hero_id, texture.get_instance_id()]
	if _layouts.has(cache_key):
		return _layouts[cache_key]
	var regions: Array = PIXEL_OVERRIDES.REGIONS[hero_id] if PIXEL_OVERRIDES.REGIONS.has(hero_id) else LAYOUT.REGIONS[hero_id]
	var pivots: Array = PIXEL_OVERRIDES.PIVOTS[hero_id] if PIXEL_OVERRIDES.PIVOTS.has(hero_id) else LAYOUT.PIVOTS[hero_id]
	var half_width := 0.0
	var top_extent := 0.0
	var bottom_extent := 0.0
	var source_bounds := Rect2(Vector2.ZERO, texture.get_size())
	for index in COLUMNS:
		var region := Rect2(regions[index])
		if not source_bounds.encloses(region):
			push_warning("Hero atlas region is outside the source: %s" % hero_id)
			return {}
		var local_pivot: Vector2 = pivots[index] - region.position
		half_width = maxf(half_width, maxf(local_pivot.x, region.size.x - local_pivot.x))
		top_extent = maxf(top_extent, local_pivot.y)
		bottom_extent = maxf(bottom_extent, region.size.y - local_pivot.y)
	var canvas := Vector2(ceilf(half_width) * 2.0 + 4.0, ceilf(top_extent + bottom_extent) + 4.0)
	var canvas_pivot := Vector2(canvas.x * 0.5, ceilf(top_extent) + 2.0)
	var textures: Array[AtlasTexture] = []
	for index in COLUMNS:
		var region := Rect2(regions[index])
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = region
		# A raised weapon does not move the actor sideways. All four frames are
		# anchored at measured lower-body centers, independently of source spacing.
		var local_pivot: Vector2 = pivots[index] - region.position
		frame.margin = Rect2(canvas_pivot - local_pivot, canvas - region.size)
		frame.filter_clip = true
		textures.append(frame)
	var result := {
		"regions": regions,
		"canvas": canvas,
		"canvas_pivot": canvas_pivot,
		"pivots": pivots,
		"frames": textures,
		"visual_height": float(PIXEL_OVERRIDES.VISUAL_HEIGHTS[hero_id] if PIXEL_OVERRIDES.VISUAL_HEIGHTS.has(hero_id) else LAYOUT.VISUAL_HEIGHTS[hero_id])
	}
	_layouts[cache_key] = result
	return result
