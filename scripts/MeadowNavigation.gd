extends RefCounted
## Shared world-space navigation for all three painted hunting zones.
## Actors retain their own routes; every move is bounded by the supplied distance.

const FIELD_MIN := Vector2(0.35, 0.35)
const FIELD_MAX := Vector2(31.65, 19.65)
const CELL_SIZE := 0.40
const GRID_SIZE := Vector2i(79, 49)
const GOAL_REPATH_DISTANCE := 0.65
const DISTANCE_CACHE_LIMIT := 256
const OBSTACLE_MARGIN := 0.12
const TERRAIN := preload("res://scripts/FieldTerrainCatalog.gd")
# Kept public for earlier diagnostics and meadow-specific actor tests.
const OBSTACLES := TERRAIN.MEADOW_OBSTACLES

var enabled := true
var uses_3d_layout := false
var zone_id: String = "gray_meadow"
var _active_obstacles: Array = OBSTACLES
var _grid: AStarGrid2D
var _routes: Dictionary = {}
var _nearest_cache: Dictionary = {}
var _unreachable_cells: Dictionary = {}
var _query_count := 0
var _move_count := 0
var _distance_cache: Dictionary = {}
var _distance_queries := 0

func configure_zone(next_zone_id: String,next_3d_layout: bool=false) -> void:
	var next_enabled: bool = TERRAIN.supports_zone(next_zone_id)
	if zone_id == next_zone_id and enabled == next_enabled and uses_3d_layout == next_3d_layout:
		return
	zone_id = next_zone_id
	enabled = next_enabled
	uses_3d_layout=next_3d_layout
	_active_obstacles = preload("res://scripts/maps3d/Map3DLayout.gd").obstacles(zone_id) if uses_3d_layout else TERRAIN.obstacles(zone_id)
	# Grid solids, nearest exits and failed pockets all depend on the region.
	# Actor keys persist between regions, so old routes must never survive here.
	_grid = null
	_nearest_cache.clear()
	_unreachable_cells.clear()
	clear_routes()

func set_enabled(value: bool) -> void:
	if enabled != value:
		enabled = value
		clear_routes()

func clear_routes() -> void:
	_routes.clear()
	_distance_cache.clear()

func forget_actor(key: Variant) -> void:
	_routes.erase(key)

func get_debug_stats() -> Dictionary:
	return {"astar_queries": _query_count, "move_calls": _move_count, "routes": _routes.size(), "distance_queries": _distance_queries, "distance_cache": _distance_cache.size(), "zone_id": zone_id, "obstacles": _active_obstacles.size()}

func _inside_bounds(point: Vector2) -> bool:
	return point.x >= FIELD_MIN.x and point.x <= FIELD_MAX.x and point.y >= FIELD_MIN.y and point.y <= FIELD_MAX.y

func _outside_obstacles(point: Vector2, extra_margin: float = 0.0) -> bool:
	for obstacle in _active_obstacles:
		var radius: Vector2 = obstacle[1] + Vector2.ONE * (OBSTACLE_MARGIN + extra_margin)
		var local: Vector2 = (point - obstacle[0]) / radius
		if local.length_squared() < 1.0:
			return false
	return true

func is_walkable(point: Vector2) -> bool:
	if not _inside_bounds(point):
		return false
	if not enabled:
		return true
	_ensure_grid()
	if not _outside_obstacles(point) or _unreachable_cells.has(_world_cell(point)):
		return false
	# A continuous point outside an ellipse may round to a solid grid cell.
	# At the eastern edge this includes a sealed sliver with no route to the
	# main clearing. Admit near-edge points only with a clear grid connection.
	if _grid.is_point_solid(_world_cell(point)):
		return _segment_clear(point, _cell_world(_connection_cell(point)))
	return true

func _ensure_grid() -> void:
	if _grid != null:
		return
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(Vector2i.ZERO, GRID_SIZE)
	_grid.cell_size = Vector2.ONE * CELL_SIZE
	_grid.offset = FIELD_MIN
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			# Extra clearance makes every grid edge safe before route smoothing.
			_grid.set_point_solid(cell, not _outside_obstacles(_cell_world(cell), CELL_SIZE * 0.36))
	# Edge trees can seal tiny corner pockets. Keep every valid spawn in the
	# same connected clearing so an otherwise clear point cannot trap an actor.
	var queue: Array[Vector2i] = [_world_cell(Vector2(16.0, 10.0))]
	var reachable := {queue[0]: true}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if _grid.region.has_point(next) and not reachable.has(next) and not _grid.is_point_solid(next):
				reachable[next] = true
				queue.append(next)
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			if not _grid.is_point_solid(cell) and not reachable.has(cell):
				_grid.set_point_solid(cell, true)
				_unreachable_cells[cell] = true

func _cell_world(cell: Vector2i) -> Vector2:
	return FIELD_MIN + Vector2(cell) * CELL_SIZE

func _world_cell(point: Vector2) -> Vector2i:
	var relative := (point - FIELD_MIN) / CELL_SIZE
	return Vector2i(clampi(roundi(relative.x), 0, GRID_SIZE.x - 1), clampi(roundi(relative.y), 0, GRID_SIZE.y - 1))

func _nearest_free_cell(point: Vector2) -> Vector2i:
	_ensure_grid()
	var initial := _world_cell(point)
	if not _grid.is_point_solid(initial):
		return initial
	if _nearest_cache.has(initial):
		return _nearest_cache[initial]
	var best := initial
	var best_distance := INF
	for ring in range(1, maxi(GRID_SIZE.x, GRID_SIZE.y)):
		for y in range(maxi(0, initial.y - ring), mini(GRID_SIZE.y - 1, initial.y + ring) + 1):
			for x in range(maxi(0, initial.x - ring), mini(GRID_SIZE.x - 1, initial.x + ring) + 1):
				if absi(x - initial.x) != ring and absi(y - initial.y) != ring:
					continue
				var cell := Vector2i(x, y)
				if _grid.is_point_solid(cell):
					continue
				var distance := _cell_world(cell).distance_squared_to(point)
				if distance < best_distance:
					best = cell
					best_distance = distance
		if best_distance < INF:
			_nearest_cache[initial] = best
			return best
	return best

func clamp_to_walkable(point: Vector2) -> Vector2:
	var bounded := point.clamp(FIELD_MIN, FIELD_MAX)
	if not enabled or is_walkable(bounded):
		return bounded
	return _cell_world(_nearest_free_cell(bounded))

func _segment_clear(from: Vector2, target: Vector2) -> bool:
	if not _inside_bounds(from) or not _inside_bounds(target):
		return false
	if not enabled:
		return true
	# Exact segment/ellipse clearance also catches thin intersections between samples.
	for obstacle in _active_obstacles:
		var radius: Vector2 = obstacle[1] + Vector2.ONE * OBSTACLE_MARGIN
		var a: Vector2 = (from - obstacle[0]) / radius
		var b: Vector2 = (target - obstacle[0]) / radius
		var direction := b - a
		var distance_squared := direction.length_squared()
		var t := 0.0 if distance_squared < 0.000001 else clampf(-a.dot(direction) / distance_squared, 0.0, 1.0)
		if (a + direction * t).length_squared() < 1.0:
			return false
	return true

func _connection_cell(point: Vector2) -> Vector2i:
	var nearest := _nearest_free_cell(point)
	if _segment_clear(point, _cell_world(nearest)):
		return nearest
	# A point very close to an ellipse may need an outward connection instead.
	var initial := _world_cell(point)
	var best := nearest
	var best_distance := INF
	for y in range(maxi(0, initial.y - 4), mini(GRID_SIZE.y - 1, initial.y + 4) + 1):
		for x in range(maxi(0, initial.x - 4), mini(GRID_SIZE.x - 1, initial.x + 4) + 1):
			var cell := Vector2i(x, y)
			if _grid.is_point_solid(cell):
				continue
			var candidate := _cell_world(cell)
			var distance := point.distance_squared_to(candidate)
			if distance < best_distance and _segment_clear(point, candidate):
				best = cell
				best_distance = distance
	return best

func _create_route(key: Variant, from: Vector2, goal: Vector2) -> Dictionary:
	_ensure_grid()
	var start_cell := _connection_cell(from)
	var goal_cell := _connection_cell(goal)
	_query_count += 1
	var points := _grid.get_point_path(start_cell, goal_cell)
	if not points.is_empty() and _segment_clear(points[points.size() - 1], goal):
		points.append(goal)
	var route := {"goal": goal, "points": points, "index": 0, "last": from}
	_routes[key] = route
	return route

func has_clear_path(from: Vector2, target: Vector2) -> bool:
	return from.is_finite() and target.is_finite() and _segment_clear(from, target)

func travel_distance(from: Vector2, target: Vector2) -> float:
	# Cached grid distance ranks targets across ponds without planning for every hero every tick.
	if not from.is_finite() or not target.is_finite(): return INF
	if has_clear_path(from, target): return from.distance_to(target)
	_ensure_grid()
	var start_cell := _connection_cell(clamp_to_walkable(from))
	var goal_cell := _connection_cell(clamp_to_walkable(target))
	var key := Vector4i(start_cell.x, start_cell.y, goal_cell.x, goal_cell.y)
	if not _distance_cache.has(key):
		var points := _grid.get_point_path(start_cell, goal_cell)
		_distance_queries += 1
		var distance := 0.0 if not points.is_empty() else INF
		for i in range(1, points.size()): distance += points[i - 1].distance_to(points[i])
		if _distance_cache.size() >= DISTANCE_CACHE_LIMIT: _distance_cache.clear()
		_distance_cache[key] = distance
	return float(_distance_cache[key]) + from.distance_to(_cell_world(start_cell)) + target.distance_to(_cell_world(goal_cell))

func route_preview(key: Variant, from: Vector2) -> PackedVector2Array:
	var route: Dictionary = _routes.get(key, {})
	if route.is_empty(): return PackedVector2Array()
	var points: PackedVector2Array = route['points']
	var result := PackedVector2Array([from])
	for i in range(int(route['index']), points.size()): result.append(points[i])
	return result

func move_toward(key: Variant, from: Vector2, target: Vector2, max_distance: float) -> Vector2:
	_move_count += 1
	if max_distance <= 0.0 or not is_finite(max_distance) or not from.is_finite() or not target.is_finite():
		return from
	var goal := clamp_to_walkable(target)
	if not is_walkable(from):
		forget_actor(key)
		return from.move_toward(clamp_to_walkable(from), max_distance)
	if _segment_clear(from, goal):
		forget_actor(key)
		return from.move_toward(goal, max_distance)
	var route: Dictionary = _routes.get(key, {})
	if route.is_empty() or Vector2(route['goal']).distance_to(goal) > GOAL_REPATH_DISTANCE or Vector2(route['last']).distance_to(from) > 0.55:
		route = _create_route(key, from, goal)
	var points: PackedVector2Array = route['points']
	if points.is_empty(): return from
	var index := int(route['index'])
	while index < points.size() - 1 and from.distance_to(points[index]) < 0.001: index += 1
	for candidate in range(points.size() - 1, index, -1):
		if _segment_clear(from, points[candidate]):
			index = candidate
			break
	if not _segment_clear(from, points[index]):
		# Reconnect immediately after local avoidance nudges an actor off its route.
		route = _create_route(key, from, goal)
		points = route['points']
		index = 0
		if points.is_empty() or not _segment_clear(from, points[0]): return from
	var next := from.move_toward(points[index], max_distance)
	var remaining := maxf(0.0, max_distance - from.distance_to(next))
	# Spend the remainder at a corner only if the resulting whole movement stays clear.
	# The simulation publishes one endpoint, so testing just the two subsegments is unsafe.
	while remaining > 0.0001 and next.distance_to(points[index]) < 0.001 and index < points.size() - 1:
		var candidate := next.move_toward(points[index + 1], remaining)
		if not _segment_clear(from, candidate): break
		remaining -= next.distance_to(candidate)
		next = candidate
		index += 1
	route['index'] = index
	route['last'] = next
	_routes[key] = route
	return next
