extends RefCounted
class_name FieldArtCatalog
## New artist stone texture; the retired map assets remain deleted.
const ROOT := "res://assets/maps/rune-stone/"
const PATHS := {'gray_meadow':'stone.png','forgotten_mine':'stone.png','moonrest_forest':'stone.png'}
const CAMP_PATH := ""
static func texture_path(zone_id: String) -> String:return ROOT+str(PATHS.get(zone_id,'stone.png'))
static func texture_for(zone_id: String) -> Texture2D:return load(texture_path(zone_id))
static func source_uv(_zone_id: String) -> Rect2:return Rect2(0,0,1,1)
static func world_art_rect(_zone_id: String, world_size := Vector2(32,20)) -> Rect2:return Rect2(Vector2.ZERO,world_size)
static func base_color(_zone_id: String) -> Color:return Color("#29313a")
static func camp_texture_path() -> String:return ""
static func camp_texture() -> Texture2D:return null

static func lighting(zone: String) -> Dictionary:
	match zone:
		'forgotten_mine':return {'ambient':Color('#dfd3bf'),'sun':Color('#fff0d8')}
		'moonrest_forest':return {'ambient':Color('#c9dedb'),'sun':Color('#e6f1ff')}
		_:return {'ambient':Color('#e0e9df'),'sun':Color('#fff7e8')}

static func stone_palette(zone: String) -> Dictionary:
	match zone:
		'forgotten_mine':return {'stone':Color('#e4ceb6'),'rune':Color('#ffb65e')}
		'moonrest_forest':return {'stone':Color('#b8c7e2'),'rune':Color('#b29bff')}
		_:return {'stone':Color.WHITE,'rune':Color('#51d8f2')}
