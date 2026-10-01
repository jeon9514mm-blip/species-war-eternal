extends RefCounted
class_name AutoHuntController

## Deterministic navigation and encounter lifecycle. No scene nodes or timers:
## the host advances this only while the hunt is active (seconds, not frames).
enum State { SEARCHING, MOVING, FIGHTING, LOOTING, RECOVERING, WAITING }

const CELL_SIZE := Vector2(94, 44)
const MOVE_SPEED := 170.0
const RESPAWN_SECONDS := 6.0
const LOOT_SECONDS := 0.65
const SEARCH_RETRY_SECONDS := 0.5
const MAX_MOVEMENT_SECONDS := 12.0
const RECENT_TARGET_MEMORY := 3

var state: State = State.SEARCHING
var state_time := 0.0
var clock := 0.0
var position := Vector2(3, 2)
var target_position := Vector2(3, 2)
var target_index := -1
var encounter_id := 0
var distance_walked := 0.0
var spots: Array[Vector2] = []
var respawn_at: Array[float] = []
var visits: Array[int] = []
var failures: Array[int] = []
var recent_targets: Array[int] = []
var path: Array[Vector2] = []
var grid := AStarGrid2D.new()
var _path_cursor := 0
var _travel_distance := 0.0
var _travel_walked := 0.0
var _stuck_seconds := 0.0

func configure(positions: Array, start: Vector2, blocked: Array[Vector2i] = []) -> void:
	grid.region = Rect2i(0, 0, 7, 5)
	grid.cell_size = CELL_SIZE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for cell in blocked:
		if grid.is_in_boundsv(cell):
			grid.set_point_solid(cell)
	spots.clear()
	for point in positions:
		var cell := Vector2i(point)
		if grid.is_in_boundsv(cell) and not spots.has(Vector2(cell)):
			spots.append(Vector2(cell))
	respawn_at.clear()
	visits.clear()
	failures.clear()
	recent_targets.clear()
	for _spot in spots:
		respawn_at.append(0.0)
		visits.append(0)
		failures.append(0)
	position = start.clamp(Vector2.ZERO, Vector2(6, 4))
	target_position = position
	target_index = -1
	clock = 0.0
	encounter_id = 0
	distance_walked = 0.0
	path.clear()
	set_state(State.SEARCHING)

func advance_time(delta: float) -> void:
	clock += delta
	state_time += delta

func set_state(next_state: State) -> void:
	state = next_state
	state_time = 0.0

func acquire_target() -> bool:
	# Keep the chosen encounter until it ends; never switch each frame.
	var best_score := INF
	var best_path: Array[Vector2] = []
	var best_index := -1
	var from := Vector2i(position.round())
	var min_visits := 0
	if not visits.is_empty():
		min_visits = visits[0]
		for value in visits:
			min_visits = mini(min_visits, int(value))
	if not grid.is_in_boundsv(from) or grid.is_point_solid(from):
		set_state(State.WAITING)
		return false
	for index in spots.size():
		var cell := Vector2i(spots[index])
		if respawn_at[index] > clock or grid.is_point_solid(cell):
			continue
		var ids := grid.get_id_path(from, cell)
		if ids.is_empty():
			continue
		var candidate: Array[Vector2] = []
		for id in ids:
			candidate.append(Vector2(id))
		var distance := _path_length(candidate)
		# Distance first, then relative visit/failure/recent-target penalties.
		# Relative visits prevent scores from growing forever during long idle sessions.
		var visit_penalty := float(maxi(0, visits[index] - min_visits)) * 150.0
		var failure_penalty := float(failures[index]) * 180.0
		var recent_penalty := 0.0
		var recent_position := recent_targets.find(index)
		if recent_position >= 0:
			recent_penalty = float(RECENT_TARGET_MEMORY - recent_position) * 90.0
		var score := distance + visit_penalty + failure_penalty + recent_penalty
		if score < best_score:
			best_score = score
			best_index = index
			best_path = candidate
	if best_index < 0:
		target_index = -1
		set_state(State.WAITING)
		return false
	target_index = best_index
	target_position = spots[best_index]
	path = best_path
	_path_cursor = 0
	_travel_distance = maxf(_path_length(path), 1.0)
	_travel_walked = 0.0
	_stuck_seconds = 0.0
	encounter_id += 1
	set_state(State.MOVING)
	return true

func advance_movement(delta: float) -> void:
	if state_time > MAX_MOVEMENT_SECONDS:
		abandon_target()
		return
	if not target_is_valid():
		abandon_target()
		return
	var before := position
	var budget := MOVE_SPEED * delta
	while budget > 0.0001 and _path_cursor < path.size():
		var next := path[_path_cursor]
		if grid.is_point_solid(Vector2i(next)):
			abandon_target()
			return
		var distance := ((next - position) * CELL_SIZE).length()
		if distance <= budget:
			position = next
			budget -= distance
			_travel_walked += distance
			distance_walked += distance
			_path_cursor += 1
		else:
			position = position.lerp(next, budget / distance)
			_travel_walked += budget
			distance_walked += budget
			budget = 0.0
	if _path_cursor >= path.size():
		position = target_position
		set_state(State.FIGHTING)
		return
	_stuck_seconds = _stuck_seconds + delta if position.is_equal_approx(before) else 0.0
	if _stuck_seconds > 1.5:
		abandon_target()

func target_is_valid() -> bool:
	return target_index >= 0 and target_index < spots.size() \
		and grid.is_in_boundsv(Vector2i(target_position)) \
		and not grid.is_point_solid(Vector2i(target_position))

func finish_target() -> void:
	if target_index >= 0 and target_index < spots.size():
		respawn_at[target_index] = clock + RESPAWN_SECONDS
		visits[target_index] += 1
		failures[target_index] = maxi(0, failures[target_index] - 1)
		recent_targets.push_front(target_index)
		while recent_targets.size() > RECENT_TARGET_MEMORY:
			recent_targets.pop_back()
	set_state(State.LOOTING)

func retreat_target() -> void:
	# Tactical recovery is not a navigation failure. Do not poison future target
	# selection with failure/visit penalties just because the party was wounded.
	if target_index >= 0 and target_index < spots.size():
		respawn_at[target_index] = clock + SEARCH_RETRY_SECONDS
	target_index = -1
	path.clear()
	set_state(State.SEARCHING)

func abandon_target() -> void:
	if target_index >= 0 and target_index < spots.size():
		respawn_at[target_index] = clock + SEARCH_RETRY_SECONDS
		visits[target_index] += 1
		failures[target_index] = mini(4, failures[target_index] + 1)
	target_index = -1
	path.clear()
	set_state(State.SEARCHING)

func travel_progress() -> float:
	return clampf(_travel_walked / _travel_distance, 0.0, 1.0)

func _path_length(points: Array[Vector2]) -> float:
	var distance := 0.0
	var previous := position
	for point in points:
		distance += ((point - previous) * CELL_SIZE).length()
		previous = point
	return distance
