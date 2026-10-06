extends RefCounted
## Gameplay bounds only. Map paths, clearings, obstacles and palettes are reset.
const WORLD_SIZE:=Vector2(32,20)
const LEGACY=preload('res://scripts/FieldTerrainCatalog.gd')
static func obstacles(_zone: String) -> Array:return []
static func palette(zone: String) -> Dictionary:return LEGACY.palette(zone)
static func paths(_zone: String) -> Array:return []
static func clearings(_zone: String) -> Array:return []
