extends SceneTree
## Run with Godot --headless --path . --script tests/regression/V67FieldTerrainNavigationSmokeTest.gd
const NAV := preload("res://scripts/hunting/MeadowNavigation.gd")
const TERRAIN := preload("res://scripts/maps/FieldTerrainCatalog.gd")
var checks: int = 0
var route_cases: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _walk(nav: RefCounted, start: Vector2, goal: Vector2, label: String) -> void:
	var position: Vector2 = start
	var safe: bool = true
	for tick: int in range(1000):
		var budget: float = [0.027, 0.118, 0.31][tick % 3]
		var next: Vector2 = nav.move_toward("shared_actor", position, goal, budget)
		safe = safe and next.is_finite() and nav.is_walkable(next) and nav.has_clear_path(position, next)
		safe = safe and position.distance_to(next) <= budget + 0.00001
		position = next
		if position.distance_to(goal) < 0.015:
			break
	route_cases += 1
	_check(safe, label + " keeps every movement outside terrain and within its frame speed")
	_check(position.distance_to(goal) < 0.015, label + " reaches its destination")

func _zone(nav: RefCounted, zone: String) -> void:
	nav.configure_zone(zone)
	_check(nav.enabled and nav.zone_id == zone, zone + " enables its own terrain")
	_check(nav.is_walkable(Vector2(16, 10)), zone + " keeps the default spawn clear")
	var free_cells: int = 0
	for y: int in range(NAV.GRID_SIZE.y):
		for x: int in range(NAV.GRID_SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			if not nav._grid.is_point_solid(cell):
				free_cells += 1
	_check(free_cells > int(NAV.GRID_SIZE.x * NAV.GRID_SIZE.y * 0.70), zone + " preserves at least seventy percent navigable ground")
	if zone != "gray_meadow":
		_check(nav._unreachable_cells.is_empty(), zone + " contains no sealed walkable pockets")
	for clearing: Array in TERRAIN.clearings(zone):
		var open: bool = true
		for ring: int in range(5):
			for angle: int in range(32):
				var sample: Vector2 = clearing[0] + Vector2.from_angle(float(angle) * TAU / 32.0) * clearing[1] * (float(ring) / 4.0)
				open = open and nav.is_walkable(sample)
		_check(open, zone + " leaves its painted battle clearing unobstructed at " + str(clearing[0]))
	for obstacle_index: int in range(TERRAIN.obstacles(zone).size()):
		var obstacle: Array = TERRAIN.obstacles(zone)[obstacle_index]
		var center: Vector2 = obstacle[0]
		var radius: Vector2 = obstacle[1]
		_check(not nav.is_walkable(center), zone + " blocks visible " + str(obstacle[2]) + " center " + str(center))
		_check(nav.is_walkable(nav.clamp_to_walkable(center)), zone + " corrects legacy spawns inside " + str(center))
		for direction: int in range(4):
			var offset: Vector2 = Vector2.from_angle(float(direction) * PI / 4.0) * (radius + Vector2.ONE * 0.48)
			var start: Vector2 = center + offset
			var goal: Vector2 = center - offset
			if nav.is_walkable(start) and nav.is_walkable(goal):
				_walk(nav, start, goal, "%s obstacle %d direction %d" % [zone, obstacle_index, direction])
	# Long trips use the same actor id as obstacle detours; stale routes must replan.
	for start: Vector2 in [Vector2(1, 1), Vector2(31, 1), Vector2(1, 19), Vector2(31, 19)]:
		_walk(nav, nav.clamp_to_walkable(start), Vector2(16, 10), zone + " edge-to-center " + str(start))

func _run() -> void:
	var nav: RefCounted = NAV.new()
	_check(NAV.OBSTACLES.size() == 17, "Meadow retains all seventeen legacy obstacles")
	for zone: String in TERRAIN.ZONE_IDS:
		_zone(nav, zone)
	# Every cached query is terrain-dependent, including spawn correction cells.
	nav.configure_zone("gray_meadow")
	nav.move_toward("persisted_hero", Vector2(6.9, 1.2), Vector2(6.9, 6.4), 0.1)
	nav.travel_distance(Vector2(6.9, 1.2), Vector2(6.9, 6.4))
	nav.clamp_to_walkable(Vector2(6.9, 3.6))
	_check(not nav._routes.is_empty() and not nav._distance_cache.is_empty() and not nav._nearest_cache.is_empty(), "Zone-switch fixture populates all navigation caches")
	nav.configure_zone("forgotten_mine")
	_check(nav._grid == null and nav._routes.is_empty() and nav._distance_cache.is_empty() and nav._nearest_cache.is_empty() and nav._unreachable_cells.is_empty(), "Zone changes invalidate grid, actor routes, distances, exits and disconnected cells")
	_check(nav.is_walkable(Vector2(16, 3.62)), "Mine no longer inherits the meadow's north tree")
	_check(not nav.is_walkable(Vector2(24.9, 15.7)), "Mine uses its own underground water collision")
	nav.configure_zone("gray_meadow")
	_check(not nav.is_walkable(Vector2(16, 3.62)), "Returning to meadow restores the original tree")
	_check(nav.is_walkable(Vector2(24.9, 15.7)), "Returning to meadow removes the mine pond")
	nav.configure_zone("unknown_test_region")
	_check(not nav.enabled and nav.is_walkable(Vector2(6.9, 3.6)), "Unsupported regions use bounded direct movement")
	_check(not nav.is_walkable(Vector2(-1, 10)), "Unsupported regions still enforce world bounds")
	_check(route_cases >= 140, "Coverage includes at least one hundred forty complete terrain routes")
	print("V67FieldTerrainNavigationSmokeTest: %d checks, %d failures, %d complete route cases" % [checks, failures.size(), route_cases])
	quit(0 if failures.is_empty() else 1)
