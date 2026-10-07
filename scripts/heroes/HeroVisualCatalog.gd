extends RefCounted
class_name HeroVisualCatalog

## Presentation assets only. This catalog does not modify combat or progression.
## v32 uses six identity-preserving pixel-art edits. AtlasTexture keeps the
## final generated PNGs byte-for-byte intact; metadata contains measured tiles.
const DATA = preload("res://assets/heroes/pixel-v32/hero-visual-data.gd")
const BOARDS := {
	"a01": preload("res://assets/heroes/pixel-v32/a01-board.png"),
	"a06": preload("res://assets/heroes/pixel-v32/a06-board.png"),
	"a11": preload("res://assets/heroes/pixel-v32/a11-board.png"),
	"n01": preload("res://assets/heroes/pixel-v32/n01-board.png"),
	"n06": preload("res://assets/heroes/pixel-v32/n06-board.png"),
	"n11": preload("res://assets/heroes/pixel-v32/n11-board.png")
}
const SKILL_SLOTS: Array[String] = ["a1", "a2", "passive", "ultimate"]

static var _portraits: Dictionary = {}
static var _skills: Dictionary = {}

static func has_hero(hero_id: String) -> bool:
	return DATA.HEROES.has(hero_id)

static func _atlas(board: String, bounds: Array) -> Texture2D:
	if not BOARDS.has(board) or bounds.size() != 4:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = BOARDS[board] as Texture2D
	texture.region = Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
	texture.filter_clip = true
	return texture

static func portrait_texture(hero_id: String) -> Texture2D:
	# v36 SD portrait-only route; the four original skill icon routes are unchanged.
	var sd_catalog = preload("res://scripts/sd/SDHeroVisuals.gd")
	if sd_catalog.has_hero(hero_id):
		return sd_catalog.portrait(hero_id)
	if not has_hero(hero_id):
		return null
	if not _portraits.has(hero_id):
		var entry: Dictionary = DATA.HEROES[hero_id]
		_portraits[hero_id] = _atlas(str(entry["board"]), entry["portrait"])
	return _portraits[hero_id] as Texture2D

static func skill_texture(hero_id: String, slot: String) -> Texture2D:
	if not has_hero(hero_id) or not SKILL_SLOTS.has(slot):
		return null
	var key := "%s:%s" % [hero_id, slot]
	if not _skills.has(key):
		var entry: Dictionary = DATA.HEROES[hero_id]
		var regions: Dictionary = entry["skills"]
		_skills[key] = _atlas(str(entry["board"]), regions[slot])
	return _skills[key] as Texture2D

static func palette(hero_id: String) -> Array[Color]:
	var colors: Array[Color] = []
	if not has_hero(hero_id):
		return colors
	var entry: Dictionary = DATA.HEROES[hero_id]["design"]
	for hex_color: String in entry["palette"]:
		colors.append(Color(hex_color))
	return colors

static func design(hero_id: String) -> Dictionary:
	if not has_hero(hero_id):
		return {}
	var entry: Dictionary = DATA.HEROES[hero_id]["design"]
	return entry.duplicate(true)

static func skill_design(hero_id: String, slot: String) -> Dictionary:
	if not has_hero(hero_id) or not SKILL_SLOTS.has(slot):
		return {}
	var entry: Dictionary = DATA.HEROES[hero_id]["design"]
	for skill: Dictionary in entry["skills"]:
		if str(skill["slot"]) == slot:
			return skill.duplicate(true)
	return {}
