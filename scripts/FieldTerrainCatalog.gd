extends RefCounted
## World-space terrain shared by scenery, map props, minimap and navigation.
## Obstacle radii describe the visible ground footprint, not a tree's canopy.
## Paths and open battle clearings remain separate from blocking scenery.

const WORLD_SIZE := Vector2(32.0, 20.0)
const ART_RECT := Rect2(-12.0, -12.0, 56.0, 44.0)
const ZONE_IDS := ["gray_meadow", "forgotten_mine", "moonrest_forest"]

const MEADOW_OBSTACLES := [
	# Video-reference layout: a shallow pond on the left, a dense tree belt at
	# the horizon and trunk-sized collision footprints around a wide battle lawn.
	[Vector2(5.55, 7.25), Vector2(2.45, 1.20), "pond"],
	[Vector2(30.55, 15.15), Vector2(1.20, 0.95), "rock"],
	[Vector2(1.10, 2.70), Vector2(0.56, 0.54), "tree"],
	[Vector2(3.20, 2.15), Vector2(0.58, 0.54), "tree"],
	[Vector2(5.55, 2.45), Vector2(0.62, 0.56), "tree"],
	[Vector2(7.85, 2.10), Vector2(0.56, 0.52), "tree"],
	[Vector2(10.20, 2.65), Vector2(0.60, 0.55), "tree"],
	[Vector2(12.55, 2.05), Vector2(0.60, 0.55), "tree"],
	[Vector2(14.95, 2.55), Vector2(0.61, 0.56), "tree"],
	[Vector2(17.40, 2.05), Vector2(0.60, 0.55), "tree"],
	[Vector2(19.80, 2.65), Vector2(0.61, 0.56), "tree"],
	[Vector2(22.25, 2.10), Vector2(0.58, 0.54), "tree"],
	[Vector2(24.70, 2.55), Vector2(0.62, 0.56), "tree"],
	[Vector2(27.05, 2.05), Vector2(0.58, 0.54), "tree"],
	[Vector2(29.45, 2.60), Vector2(0.61, 0.56), "tree"],
	[Vector2(31.10, 3.45), Vector2(0.58, 0.54), "tree"],
	[Vector2(1.55, 8.75), Vector2(0.72, 0.66), "tree"],
	[Vector2(8.95, 9.55), Vector2(0.70, 0.64), "tree"],
	[Vector2(11.25, 11.05), Vector2(0.66, 0.61), "tree"],
	[Vector2(24.20, 8.70), Vector2(0.70, 0.63), "tree"],
	[Vector2(27.45, 10.20), Vector2(0.76, 0.68), "tree"],
	[Vector2(2.40, 16.70), Vector2(0.78, 0.70), "tree"],
	[Vector2(7.75, 17.55), Vector2(0.72, 0.66), "tree"],
	[Vector2(25.10, 17.45), Vector2(0.74, 0.66), "tree"],
	[Vector2(29.20, 18.10), Vector2(0.80, 0.72), "tree"],
]
const MINE_OBSTACLES := [
	[Vector2(4.00, 3.10), Vector2(1.10, 0.80), "rock"],
	[Vector2(7.30, 3.55), Vector2(0.72, 0.62), "crystal"],
	[Vector2(11.20, 2.60), Vector2(1.10, 0.80), "rock"],
	[Vector2(17.00, 2.20), Vector2(0.80, 0.70), "crystal"],
	[Vector2(22.60, 3.30), Vector2(1.25, 0.86), "rock"],
	[Vector2(27.60, 2.70), Vector2(0.78, 0.66), "crystal"],
	[Vector2(30.20, 6.80), Vector2(1.10, 0.86), "rock"],
	[Vector2(27.90, 15.50), Vector2(1.35, 0.90), "rock"],
	[Vector2(23.40, 17.20), Vector2(0.80, 0.66), "crystal"],
	[Vector2(16.40, 17.70), Vector2(0.76, 0.64), "crystal"],
	[Vector2(9.70, 17.00), Vector2(1.10, 0.82), "rock"],
	[Vector2(3.20, 15.70), Vector2(1.25, 0.90), "rock"],
]
const FOREST_OBSTACLES := [
	[Vector2(6.00, 7.00), Vector2(2.15, 1.10), "pond"],
	[Vector2(1.20, 2.80), Vector2(0.64, 0.58), "tree"],
	[Vector2(3.70, 2.20), Vector2(0.66, 0.60), "tree"],
	[Vector2(6.30, 2.65), Vector2(0.70, 0.62), "tree"],
	[Vector2(9.00, 2.10), Vector2(0.66, 0.60), "tree"],
	[Vector2(11.70, 2.70), Vector2(0.72, 0.64), "tree"],
	[Vector2(14.60, 2.15), Vector2(0.68, 0.62), "tree"],
	[Vector2(17.40, 2.75), Vector2(0.70, 0.64), "tree"],
	[Vector2(20.20, 2.10), Vector2(0.68, 0.62), "tree"],
	[Vector2(23.00, 2.65), Vector2(0.72, 0.64), "tree"],
	[Vector2(25.80, 2.10), Vector2(0.68, 0.62), "tree"],
	[Vector2(28.50, 2.70), Vector2(0.70, 0.64), "tree"],
	[Vector2(31.00, 3.20), Vector2(0.66, 0.60), "tree"],
	[Vector2(2.20, 10.20), Vector2(0.84, 0.74), "tree"],
	[Vector2(9.50, 10.10), Vector2(0.78, 0.70), "tree"],
	[Vector2(25.20, 9.40), Vector2(0.82, 0.72), "tree"],
	[Vector2(29.50, 12.30), Vector2(0.88, 0.76), "tree"],
	[Vector2(4.00, 17.20), Vector2(0.84, 0.76), "tree"],
	[Vector2(11.00, 17.70), Vector2(0.80, 0.72), "tree"],
	[Vector2(23.60, 17.40), Vector2(0.84, 0.74), "tree"],
	[Vector2(28.60, 17.80), Vector2(0.86, 0.76), "tree"],
	[Vector2(18.20, 5.20), Vector2(0.55, 0.50), "crystal"],
]

# Raised scenery that sells the reference-video density without adding hidden
# collision. These sit mainly outside the active lawn or behind blocking trunks.
const MEADOW_DECOR := [
	[Vector2(-1.2, 0.35), Vector2(0.92, 0.82), "tree"], [Vector2(1.9, 0.55), Vector2(0.88, 0.80), "tree"],
	[Vector2(4.5, 0.25), Vector2(0.92, 0.82), "tree"], [Vector2(7.1, 0.65), Vector2(0.88, 0.80), "tree"],
	[Vector2(9.4, 0.30), Vector2(0.96, 0.84), "tree"], [Vector2(12.0, 0.60), Vector2(0.90, 0.82), "tree"],
	[Vector2(14.5, 0.25), Vector2(0.96, 0.84), "tree"], [Vector2(17.0, 0.55), Vector2(0.92, 0.82), "tree"],
	[Vector2(19.5, 0.30), Vector2(0.98, 0.86), "tree"], [Vector2(22.0, 0.65), Vector2(0.92, 0.82), "tree"],
	[Vector2(24.5, 0.25), Vector2(0.96, 0.84), "tree"], [Vector2(27.0, 0.55), Vector2(0.92, 0.82), "tree"],
	[Vector2(29.5, 0.30), Vector2(0.96, 0.84), "tree"], [Vector2(32.0, 0.55), Vector2(0.90, 0.82), "tree"],
	[Vector2(0.2, 12.8), Vector2(0.82, 0.74), "tree"], [Vector2(31.8, 9.3), Vector2(0.82, 0.74), "tree"],
	[Vector2(14.0, 18.7), Vector2(0.72, 0.66), "tree"], [Vector2(20.5, 18.8), Vector2(0.76, 0.68), "tree"],
	[Vector2(4.6, 13.9), Vector2(0.62, 0.58), "tree"], [Vector2(6.2, 14.7), Vector2(0.58, 0.54), "tree"],
	[Vector2(28.5, 13.7), Vector2(0.64, 0.58), "tree"], [Vector2(30.0, 13.1), Vector2(0.56, 0.52), "tree"],
]
const FOREST_DECOR := [
	[Vector2(-1.0, 1.2), Vector2(1.05, 0.94), "tree"], [Vector2(2.1, 1.0), Vector2(1.02, 0.92), "tree"],
	[Vector2(5.0, 1.0), Vector2(1.06, 0.94), "tree"], [Vector2(8.0, 1.0), Vector2(1.02, 0.92), "tree"],
	[Vector2(11.0, 1.0), Vector2(1.06, 0.94), "tree"], [Vector2(14.0, 1.0), Vector2(1.02, 0.92), "tree"],
	[Vector2(17.0, 0.55), Vector2(1.06, 0.94), "tree"], [Vector2(20.0, 1.0), Vector2(1.02, 0.92), "tree"],
	[Vector2(23.0, 1.0), Vector2(1.06, 0.94), "tree"], [Vector2(26.0, 1.0), Vector2(1.02, 0.92), "tree"],
	[Vector2(29.0, 1.0), Vector2(1.06, 0.94), "tree"], [Vector2(32.0, 0.55), Vector2(1.02, 0.92), "tree"],
	[Vector2(0.1, 14.0), Vector2(0.95, 0.84), "tree"], [Vector2(31.9, 15.0), Vector2(0.95, 0.84), "tree"],
]
const MINE_DECOR := [
	[Vector2(1.0, 1.4), Vector2(1.1, 0.82), "rock"], [Vector2(5.3, 1.2), Vector2(0.76, 0.66), "crystal"],
	[Vector2(9.8, 1.0), Vector2(1.0, 0.78), "rock"], [Vector2(14.0, 1.1), Vector2(0.72, 0.64), "crystal"],
	[Vector2(19.0, 1.0), Vector2(1.05, 0.80), "rock"], [Vector2(24.0, 1.0), Vector2(0.72, 0.64), "crystal"],
	[Vector2(29.0, 1.3), Vector2(1.05, 0.80), "rock"], [Vector2(31.8, 11.0), Vector2(0.75, 0.66), "crystal"],
]


# v71 structured hunting habitats. These are open, navigable combat pockets
# used by RoamingHuntDirector to keep dense populations distributed across
# each painted map instead of stacking every pack around the party.
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

static func supports_zone(zone_id: String) -> bool:
	return zone_id in ZONE_IDS

static func obstacles(zone_id: String) -> Array:
	match zone_id:
		"forgotten_mine": return MINE_OBSTACLES
		"moonrest_forest": return FOREST_OBSTACLES
		"gray_meadow": return MEADOW_OBSTACLES
	return []

static func decorations(zone_id: String) -> Array:
	match zone_id:
		"forgotten_mine": return MINE_DECOR
		"moonrest_forest": return FOREST_DECOR
		"gray_meadow": return MEADOW_DECOR
	return []

static func paths(zone_id: String) -> Array:
	match zone_id:
		"forgotten_mine":
			return [
				{"points": PackedVector2Array([Vector2(-5, 14), Vector2(4, 13), Vector2(11, 12), Vector2(17, 11), Vector2(24, 10), Vector2(36, 8)]), "width": 2.75},
				{"points": PackedVector2Array([Vector2(17, -3), Vector2(17, 5), Vector2(17, 11), Vector2(18, 18), Vector2(20, 25)]), "width": 1.85},
			]
		"moonrest_forest":
			return [
				{"points": PackedVector2Array([Vector2(-4, 16), Vector2(4, 15), Vector2(10, 13.5), Vector2(16, 12), Vector2(23, 10.5), Vector2(36, 9)]), "width": 2.30},
				{"points": PackedVector2Array([Vector2(13, -3), Vector2(14, 5), Vector2(16, 12), Vector2(18, 20), Vector2(19, 25)]), "width": 1.55},
			]
		_:
			return [
				{"points": PackedVector2Array([Vector2(-4, 16), Vector2(4, 15.2), Vector2(10, 13.8), Vector2(16, 12.0), Vector2(22, 10.3), Vector2(36, 8.5)]), "width": 2.55},
			]

static func clearings(zone_id: String) -> Array:
	match zone_id:
		"forgotten_mine": return [[Vector2(16.0, 11.0), Vector2(5.4, 3.2)], [Vector2(8.7, 12.8), Vector2(3.0, 2.0)], [Vector2(24.0, 10.2), Vector2(3.0, 2.0)]]
		"moonrest_forest": return [[Vector2(16.0, 12.0), Vector2(5.6, 3.4)], [Vector2(9.5, 13.0), Vector2(2.8, 1.9)], [Vector2(23.0, 11.0), Vector2(2.8, 1.9)]]
	return [[Vector2(16.0, 12.0), Vector2(6.2, 3.6)], [Vector2(10.5, 13.5), Vector2(3.2, 2.0)], [Vector2(23.0, 11.0), Vector2(3.0, 1.9)]]


static func hunt_pack_anchors(zone_id: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var source: Array = MEADOW_HUNT_ANCHORS
	match zone_id:
		"forgotten_mine": source = MINE_HUNT_ANCHORS
		"moonrest_forest": source = FOREST_HUNT_ANCHORS
	for point in source:
		result.append(Vector2(point))
	return result

static func palette(zone_id: String) -> Dictionary:
	match zone_id:
		"forgotten_mine": return {"ground": Color("#59636d"), "path": Color("#ada592"), "path_edge": Color("#4c5660"), "water": Color("#417d8c"), "water_edge": Color("#77baba"), "glow": Color("#98ddf3")}
		"moonrest_forest": return {"ground": Color("#225c68"), "path": Color("#9fb39d"), "path_edge": Color("#456b61"), "water": Color("#478d9b"), "water_edge": Color("#9bcbbb"), "glow": Color("#c0d7ed")}
	return {"ground": Color("#6db743"), "path": Color("#b9c66d"), "path_edge": Color("#8aa75a"), "water": Color("#26bfe0"), "water_edge": Color("#7be1e3"), "glow": Color("#fff1a4")}
