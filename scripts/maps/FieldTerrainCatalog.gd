extends RefCounted
## Empty visual layout; retain zone IDs and hunt pack coordinates for gameplay.
const WORLD_SIZE := Vector2(32,20)
const ART_RECT := Rect2(0,0,32,20)
const ZONE_IDS := ["gray_meadow","forgotten_mine","moonrest_forest"]
const MEADOW_OBSTACLES := []
const MINE_OBSTACLES := []
const FOREST_OBSTACLES := []
const MEADOW_DECOR := []
const MINE_DECOR := []
const FOREST_DECOR := []
const MEADOW_HUNT_ANCHORS := [
	Vector2(10.5, 13.5), Vector2(16.0, 12.0), Vector2(23.0, 11.0),
	Vector2(26.8, 15.5), Vector2(13.5, 7.4),
]
const MINE_HUNT_ANCHORS := [
	Vector2(8.7, 12.8), Vector2(16.0, 11.0), Vector2(24.0, 10.2),
	Vector2(7.5, 7.4), Vector2(25.8, 14.0),
]
const FOREST_HUNT_ANCHORS := [
	Vector2(9.5, 13.0), Vector2(16.0, 12.0), Vector2(23.0, 11.0),
	Vector2(27.0, 15.3), Vector2(14.6, 7.2),
]

static func supports_zone(zone: String) -> bool:return zone in ZONE_IDS
static func obstacles(_zone: String) -> Array:return []
static func decorations(_zone: String) -> Array:return []
static func paths(_zone: String) -> Array:return []
static func clearings(_zone: String) -> Array:return []
static func hunt_pack_anchors(zone_id: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var source: Array = MEADOW_HUNT_ANCHORS
	match zone_id:
		"forgotten_mine": source = MINE_HUNT_ANCHORS
		"moonrest_forest": source = FOREST_HUNT_ANCHORS
	for point in source:
		result.append(Vector2(point))
	return result

static func palette(_zone: String) -> Dictionary:
	return {'ground':Color('#29313a'),'path':Color('#29313a'),'path_edge':Color('#29313a'),'water':Color('#29313a'),'water_edge':Color('#29313a'),'glow':Color('#29313a')}
