extends RefCounted
## The clear battlefield is surrounded by scenery beyond the simulation bounds.
## Entry gap: east edge, z 6..13. Border geometry never adds hidden obstacles.
const WORLD_SIZE:=Vector2(32,20)
const LEGACY=preload('res://scripts/FieldTerrainCatalog.gd')
static func obstacles(_zone: String) -> Array: return []
static func palette(zone: String) -> Dictionary:
	if zone=='gray_meadow':return {'ground':Color('#304d61'),'path':Color('#67aabd'),'path_edge':Color('#162736'),'water':Color('#428cb2'),'water_edge':Color('#8bdded'),'glow':Color('#86dcef')}
	return LEGACY.palette(zone)
static func paths(_zone: String) -> Array:
	return [{'points':PackedVector2Array([Vector2(0,14),Vector2(16,11.92),Vector2(32,9.84)]),'width':2.0}]
static func clearings(_zone: String) -> Array:
	return [[Vector2(16,10),Vector2(12,7)]]
