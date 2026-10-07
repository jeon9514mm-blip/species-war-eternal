extends RefCounted
class_name RoamingHuntDirector

enum Mode { PATROL, CHASE, ENGAGED, RECOVER }

const FIELD_MIN := Vector2(0.35, 0.35)
const FIELD_MAX := Vector2(31.65, 19.65)
const FIELD_CENTER := Vector2(16.0, 10.0)
const WORLD_SIZE := Vector2(32.0, 20.0)
const PARTY_SPEED := 1.72
const MONSTER_WANDER_SPEED := 0.48
const MONSTER_CHASE_SPEED := 0.92
const DETECTION_RADIUS := 2.75
const ENGAGE_DISTANCE := 0.95
const CHASE_STOP_DISTANCE := ENGAGE_DISTANCE - 0.05
const ATTACK_ZONE_DISTANCE := 1.35
const ENGAGED_EXIT_DISTANCE := 1.50
const DISENGAGE_RADIUS := 4.5
const PATROL_REACHED := 0.16
const TARGET_SWITCH_MARGIN := 0.35
const TARGET_LOCK_SECONDS := 0.60
const SPAWN_SAFE_DISTANCE := 2.8
const SPAWN_SEPARATION := 0.38
const PACK_SEPARATION := 3.15
const RETREAT_HOME_MARGIN := 0.08
const ENEMY_SEPARATION_RADIUS := 0.58
const ENEMY_SEPARATION_SPEED := 0.92
const PACK_ASSIST_RADIUS := 3.0
const ECOLOGY = preload("res://scripts/hunting/FieldEcology.gd")
const TERRAIN = preload("res://scripts/maps/FieldTerrainCatalog.gd")

var mode: Mode = Mode.PATROL
var party_position := FIELD_CENTER
var patrol_target := FIELD_CENTER
var enemy_positions: Array[Vector2] = []
var enemy_pack_ids: Array[int] = []
var pack_centers: Array[Vector2] = []
var enemy_wander_targets: Array[Vector2] = []
var enemy_archetypes: Array[String] = []
var enemy_home_positions: Array[Vector2] = []
var enemy_sight_ranges: Array[float] = []
var enemy_leash_ranges: Array[float] = []
var enemy_returning: Array[bool] = []
var enemy_alerted: Array[bool] = []
var _returned_indices: Array[int] = []
var current_target := -1
var aggro_active := false
var encounter_seconds := 0.0
var distance_walked := 0.0
var rng := RandomNumberGenerator.new()
var _target_lock_remaining := 0.0
var field_navigation: RefCounted
var _spawn_heading := 0.0
var zone_id := "gray_meadow"

func configure(start: Vector2, seed: int, next_zone_id: String = "gray_meadow") -> void:
	rng.seed = maxi(1, seed)
	zone_id = next_zone_id if TERRAIN.supports_zone(next_zone_id) else "gray_meadow"
	_spawn_heading = rng.randf_range(-PI, PI)
	party_position = _clamp_field(start)
	patrol_target = _random_field_point()
	enemy_positions.clear()
	enemy_pack_ids.clear()
	pack_centers.clear()
	enemy_wander_targets.clear()
	enemy_archetypes.clear()
	enemy_home_positions.clear()
	enemy_sight_ranges.clear()
	enemy_leash_ranges.clear()
	enemy_returning.clear()
	enemy_alerted.clear()
	_returned_indices.clear()
	current_target = -1
	aggro_active = false
	encounter_seconds = 0.0
	distance_walked = 0.0
	_target_lock_remaining = 0.0
	mode = Mode.PATROL

func clear_enemies() -> void:
	if field_navigation != null:
		for index in enemy_positions.size():
			field_navigation.forget_actor("enemy_%d" % index)
	enemy_positions.clear()
	enemy_pack_ids.clear()
	pack_centers.clear()
	enemy_wander_targets.clear()
	enemy_archetypes.clear()
	enemy_home_positions.clear()
	enemy_sight_ranges.clear()
	enemy_leash_ranges.clear()
	enemy_returning.clear()
	enemy_alerted.clear()
	_returned_indices.clear()
	current_target = -1
	aggro_active = false
	encounter_seconds = 0.0
	_target_lock_remaining = 0.0
	mode = Mode.PATROL
	patrol_target = _random_field_point()

func spawn_group(enemies: Array) -> void:
	# Replacing a wave must discard routes associated with the old actors.
	clear_enemies()
	if enemies.is_empty():
		return
	var members := ECOLOGY.pack_size(enemies.size())
	var structured_anchors := _ordered_hunt_anchors()
	var elite_first_pack := typeof(enemies[0]) == TYPE_DICTIONARY and bool(enemies[0].get("elite", false))
	for index in enemies.size():
		var pack_id := int(index / float(members))
		if pack_id >= pack_centers.size():
			pack_centers.append(_spawn_anchor_for_pack(pack_id, structured_anchors, elite_first_pack))
		var pos := _spawn_member_position(pack_centers[pack_id], index % members, members)
		enemy_positions.append(pos)
		enemy_pack_ids.append(pack_id)
		enemy_wander_targets.append(_wander_point_near(pos))
		var enemy: Dictionary = enemies[index] if typeof(enemies[index]) == TYPE_DICTIONARY else {}
		enemy_archetypes.append(str(enemy.get("archetype", "brute")))
		enemy_home_positions.append(pos)
		enemy_sight_ranges.append(clampf(float(enemy.get("sight_radius", 2.75)), 0.5, 4.0))
		# Legacy callers without ecology metadata retain the original unrestricted field.
		enemy_leash_ranges.append(maxf(0.0, float(enemy.get("leash_radius", 0.0))))
		enemy_returning.append(false)
		enemy_alerted.append(false)
	patrol_target = pack_centers[0]
	mode = Mode.PATROL

func advance(delta: float, alive_mask: Array, immobile_mask: Array = [], hero_targets: Array[Vector2] = []) -> Dictionary:
	_returned_indices.clear()
	# Recovery belongs to the caller: only its explicit mode change may resume hunting.
	if mode == Mode.RECOVER:
		aggro_active = false
		current_target = -1
		_target_lock_remaining = 0.0
	elif not _is_alive_target(current_target, alive_mask):
		current_target = -1
		_target_lock_remaining = 0.0
		if _nearest_alive_enemy(alive_mask) < 0:
			aggro_active = false
			mode = Mode.PATROL
	var result := {
		"mode": mode,
		"engaged": mode == Mode.ENGAGED and aggro_active and current_target >= 0,
		"encounter_started": false,
		"party_velocity": Vector2.ZERO,
		"target_index": current_target,
		"returned_indices": _returned_indices
	}
	if delta <= 0.0 or not is_finite(delta) or mode == Mode.RECOVER:
		return result
	encounter_seconds += delta
	_target_lock_remaining = maxf(0.0, _target_lock_remaining - delta)
	_advance_enemy_wander_or_chase(delta, alive_mask, immobile_mask, hero_targets)
	if not _is_alive_target(current_target, alive_mask):
		current_target = -1
	var nearest := _nearest_alive_enemy(alive_mask)
	if nearest < 0:
		aggro_active = false
		current_target = -1
		mode = Mode.PATROL
		var patrol_velocity := _advance_party_patrol(delta)
		result["party_velocity"] = patrol_velocity
		result["mode"] = mode
		result["target_index"] = -1
		result["engaged"] = false
		return result

	var nearest_distance := party_position.distance_to(enemy_positions[nearest])
	if not aggro_active and nearest_distance <= DETECTION_RADIUS:
		aggro_active = true
		current_target = nearest
		_target_lock_remaining = TARGET_LOCK_SECONDS
		mode = Mode.CHASE
		result["encounter_started"] = true
	elif aggro_active:
		# Small distance changes must not turn a pursuing party around every frame.
		# Dead/lost targets are replaced immediately; a materially closer target can
		# be adopted after the short lock has elapsed.
		if current_target < 0 or enemy_distance(current_target) > DISENGAGE_RADIUS:
			current_target = nearest
			_target_lock_remaining = TARGET_LOCK_SECONDS
		elif nearest != current_target and _target_lock_remaining <= 0.0:
			var candidate_cost: float = field_navigation.travel_distance(party_position, enemy_positions[nearest]) if field_navigation != null else nearest_distance
			var current_cost: float = field_navigation.travel_distance(party_position, enemy_positions[current_target]) if field_navigation != null else enemy_distance(current_target)
			if candidate_cost + TARGET_SWITCH_MARGIN < current_cost:
				current_target = nearest
				_target_lock_remaining = TARGET_LOCK_SECONDS

	if aggro_active:
		if enemy_distance(current_target) > DISENGAGE_RADIUS:
			aggro_active = false
			current_target = -1
			_target_lock_remaining = 0.0
			mode = Mode.PATROL
			patrol_target = enemy_positions[nearest]
			result["party_velocity"] = _advance_party_patrol(delta)
		else:
			var velocity := _advance_party_chase(delta, current_target)
			result["party_velocity"] = velocity
			var attack_zone := ENGAGED_EXIT_DISTANCE if mode == Mode.ENGAGED else ATTACK_ZONE_DISTANCE
			var engaged := _any_enemy_in_attack_zone(alive_mask, attack_zone)
			mode = Mode.ENGAGED if engaged else Mode.CHASE
			result["engaged"] = engaged
	else:
		# Visit the remaining habitat after a small pack falls. A random patrol
		# used to wander away from surviving monsters when they were beyond sight.
		patrol_target = enemy_positions[nearest]
		result["party_velocity"] = _advance_party_patrol(delta)

	result["mode"] = mode
	result["target_index"] = current_target
	result["engaged"] = mode == Mode.ENGAGED
	return result

func enemy_position(index: int) -> Vector2:
	if index < 0 or index >= enemy_positions.size():
		return party_position
	return enemy_positions[index]

func enemy_distance(index: int) -> float:
	return party_position.distance_to(enemy_position(index))

func nearest_alive_enemy(alive_mask: Array) -> int:
	return _nearest_alive_enemy(alive_mask)

func _advance_party_patrol(delta: float) -> Vector2:
	if party_position.distance_to(patrol_target) <= PATROL_REACHED:
		patrol_target = _random_field_point()
	var before := party_position
	party_position = _move_actor("party_anchor", party_position, patrol_target, PARTY_SPEED * delta)
	party_position = _clamp_field(party_position)
	distance_walked += before.distance_to(party_position)
	return party_position - before

func _advance_party_chase(delta: float, target_index: int) -> Vector2:
	if target_index < 0 or target_index >= enemy_positions.size():
		return Vector2.ZERO
	var target := enemy_positions[target_index]
	var distance := party_position.distance_to(target)
	var clear: bool = field_navigation == null or field_navigation.has_clear_path(party_position, target)
	if clear and distance <= CHASE_STOP_DISTANCE:
		return Vector2.ZERO
	var before := party_position
	# Stop slightly inside melee range, without stepping through the target on a
	# slow frame or relying on a floating-point equality at the attack boundary.
	var travel := minf(PARTY_SPEED * delta, distance - CHASE_STOP_DISTANCE) if clear else PARTY_SPEED * delta
	party_position = _move_actor("party_anchor", party_position, target, travel)
	party_position = _clamp_field(party_position)
	distance_walked += before.distance_to(party_position)
	return party_position - before

func _advance_enemy_wander_or_chase(delta: float, alive_mask: Array, immobile_mask: Array = [], hero_targets: Array[Vector2] = []) -> void:
	# First pass determines direct alerts and shares them with the local habitat pack.
	# This makes 3-5 monster groups react together without waking the whole field.
	var direct_alerts: Array[bool] = []
	direct_alerts.resize(enemy_positions.size())
	var alerted_packs: Dictionary = {}
	for index in enemy_positions.size():
		direct_alerts[index] = false
		if index >= alive_mask.size() or not bool(alive_mask[index]):
			continue
		var pos := enemy_positions[index]
		var home := enemy_home_positions[index] if index < enemy_home_positions.size() else pos
		var leash := enemy_leash_ranges[index] if index < enemy_leash_ranges.size() else 0.0
		var was_alerted := enemy_alerted[index] if index < enemy_alerted.size() else false
		if leash > 0.0 and was_alerted and pos.distance_to(home) > leash:
			enemy_returning[index] = true
		if is_returning(index):
			continue
		var hero_target := hero_targets[index] if index < hero_targets.size() else party_position
		var sight := enemy_sight_ranges[index] if index < enemy_sight_ranges.size() else DETECTION_RADIUS
		var can_see: bool = pos.distance_to(hero_target) <= sight and (field_navigation == null or field_navigation.has_clear_path(pos, hero_target))
		var direct := aggro_active and (was_alerted or index == current_target or can_see)
		direct_alerts[index] = direct
		if direct and index < enemy_pack_ids.size():
			alerted_packs[enemy_pack_ids[index]] = true

	for index in enemy_positions.size():
		if index >= alive_mask.size() or not bool(alive_mask[index]):
			continue
		var pos := enemy_positions[index]
		var archetype := enemy_archetypes[index] if index < enemy_archetypes.size() else "brute"
		var home := enemy_home_positions[index] if index < enemy_home_positions.size() else pos
		var leash := enemy_leash_ranges[index] if index < enemy_leash_ranges.size() else 0.0
		if is_returning(index):
			pos = _move_actor("enemy_%d" % index, pos, home, MONSTER_CHASE_SPEED * 1.5 * delta)
			if pos.distance_to(home) <= 0.00001:
				pos = home
				enemy_returning[index] = false
				enemy_alerted[index] = false
				_returned_indices.append(index)
			enemy_positions[index] = _clamp_field(pos)
			continue
		if index < immobile_mask.size() and bool(immobile_mask[index]):
			continue
		var hero_target := hero_targets[index] if index < hero_targets.size() else party_position
		var distance := pos.distance_to(hero_target)
		var pack_id := enemy_pack_ids[index] if index < enemy_pack_ids.size() else -1
		var pack_alert := pack_id >= 0 and alerted_packs.has(pack_id) and pos.distance_to(home) <= PACK_ASSIST_RADIUS
		var alerted := aggro_active and (bool(direct_alerts[index]) or pack_alert)
		if index < enemy_alerted.size():
			enemy_alerted[index] = alerted
		if alerted:
			var preferred := _preferred_distance(archetype)
			if distance > preferred + 0.18:
				var approach := minf(MONSTER_CHASE_SPEED * _speed_mult(archetype) * delta, distance - preferred)
				pos = _move_actor("enemy_%d" % index, pos, hero_target, approach)
			elif archetype in ["ranged", "support"] and distance < preferred - 0.22:
				var away := (pos - hero_target).normalized()
				if away.length_squared() < 0.01:
					away = Vector2.RIGHT
				var retreat_goal := pos + away * (preferred - distance)
				if leash > 0.0:
					retreat_goal = home + (retreat_goal - home).limit_length(maxf(0.0, leash - RETREAT_HOME_MARGIN))
				var next := _move_actor("enemy_%d" % index, pos, retreat_goal, MONSTER_WANDER_SPEED * delta)
				if leash <= 0.0 or next.distance_to(home) <= leash:
					pos = next
		else:
			var wander := enemy_wander_targets[index]
			if pos.distance_to(wander) < 0.12:
				enemy_wander_targets[index] = _wander_point_near(home)
				wander = enemy_wander_targets[index]
			pos = _move_actor("enemy_%d" % index, pos, wander, MONSTER_WANDER_SPEED * _speed_mult(archetype) * delta)
		enemy_positions[index] = _clamp_field(pos)
	_separate_enemies(delta, alive_mask, immobile_mask)

func is_returning(index: int) -> bool:
	return index >= 0 and index < enemy_returning.size() and enemy_returning[index]

func _any_enemy_in_attack_zone(alive_mask: Array, radius: float = ATTACK_ZONE_DISTANCE) -> bool:
	for index in enemy_positions.size():
		if index < alive_mask.size() and bool(alive_mask[index]) and not is_returning(index):
			if party_position.distance_to(enemy_positions[index]) <= radius and (field_navigation == null or field_navigation.has_clear_path(party_position, enemy_positions[index])):
				return true
	return false

func _is_alive_target(index: int, alive_mask: Array) -> bool:
	return index >= 0 and index < enemy_positions.size() and index < alive_mask.size() and bool(alive_mask[index]) and not is_returning(index)

func _nearest_alive_enemy(alive_mask: Array) -> int:
	var best := -1
	var best_distance := INF
	for index in enemy_positions.size():
		if index >= alive_mask.size() or not bool(alive_mask[index]) or is_returning(index):
			continue
		var distance: float = field_navigation.travel_distance(party_position, enemy_positions[index]) if field_navigation != null else party_position.distance_to(enemy_positions[index])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best

func _ordered_hunt_anchors() -> Array[Vector2]:
	var anchors := TERRAIN.hunt_pack_anchors(zone_id)
	for index in anchors.size():
		anchors[index] = _clamp_field(anchors[index])
	anchors.sort_custom(func(a, b):
		return party_position.distance_squared_to(Vector2(a)) < party_position.distance_squared_to(Vector2(b))
	)
	return anchors

func _spawn_anchor_for_pack(pack_id: int, anchors: Array[Vector2], elite_first_pack: bool) -> Vector2:
	if anchors.is_empty():
		return _spawn_anchor_away_from_party()
	var preferred_index := mini(pack_id, anchors.size() - 1)
	# Elite stages place their first pack deeper in the map, so the party clears
	# ordinary habitat packs before reaching the elite pocket naturally.
	if elite_first_pack and pack_id == 0:
		preferred_index = anchors.size() - 1
	elif elite_first_pack and pack_id > 0:
		preferred_index = mini(pack_id - 1, anchors.size() - 2)
	var candidate := anchors[preferred_index]
	var clearance := party_position.distance_to(candidate) - SPAWN_SAFE_DISTANCE
	for center in pack_centers:
		clearance = minf(clearance, candidate.distance_to(center) - PACK_SEPARATION)
	if clearance >= -0.15:
		return candidate
	# Try the remaining authored habitats before falling back to procedural placement.
	for offset in anchors.size():
		var alternative := anchors[(preferred_index + offset + 1) % anchors.size()]
		var alt_clearance := party_position.distance_to(alternative) - SPAWN_SAFE_DISTANCE
		for center in pack_centers:
			alt_clearance = minf(alt_clearance, alternative.distance_to(center) - PACK_SEPARATION)
		if alt_clearance >= -0.15:
			return alternative
	return _spawn_anchor_away_from_party()

func _enemy_separation_radius() -> float:
	return ENEMY_SEPARATION_RADIUS

func _separate_enemies(delta: float, alive_mask: Array, immobile_mask: Array = []) -> void:
	if enemy_positions.size() < 2 or delta <= 0.0:
		return
	var snapshot: Array[Vector2] = []
	for point in enemy_positions:
		snapshot.append(Vector2(point))
	var pushes: Array[Vector2] = []
	pushes.resize(enemy_positions.size())
	for index in pushes.size():
		pushes[index] = Vector2.ZERO
	for left in enemy_positions.size():
		if left >= alive_mask.size() or not bool(alive_mask[left]) or is_returning(left) or (left < immobile_mask.size() and bool(immobile_mask[left])):
			continue
		for right in range(left + 1, enemy_positions.size()):
			if right >= alive_mask.size() or not bool(alive_mask[right]) or is_returning(right) or (right < immobile_mask.size() and bool(immobile_mask[right])):
				continue
			var away := snapshot[left] - snapshot[right]
			var distance := away.length()
			if distance >= _enemy_separation_radius():
				continue
			if distance <= 0.0001:
				var angle := float(((left + 1) * 92821 + (right + 1) * 68917) % 6283) / 1000.0
				away = Vector2.from_angle(angle)
				distance = 0.0
			else:
				away /= distance
			var overlap := _enemy_separation_radius() - distance
			pushes[left] += away * overlap * 0.5
			pushes[right] -= away * overlap * 0.5
	var max_step := ENEMY_SEPARATION_SPEED * delta
	for index in enemy_positions.size():
		if pushes[index].length_squared() <= 0.000001:
			continue
		var start := enemy_positions[index]
		var candidate := start + pushes[index].limit_length(max_step)
		var home := enemy_home_positions[index] if index < enemy_home_positions.size() else start
		var leash := enemy_leash_ranges[index] if index < enemy_leash_ranges.size() else 0.0
		if leash > 0.0:
			candidate = home + (candidate - home).limit_length(maxf(0.0, leash - RETREAT_HOME_MARGIN))
		candidate = _clamp_field(candidate)
		if field_navigation == null or (field_navigation.is_walkable(candidate) and field_navigation.has_clear_path(start, candidate)):
			enemy_positions[index] = candidate

func _spawn_anchor_away_from_party() -> Vector2:
	# Spread packs across a local habitat. Projection out of a tree or pond may
	# shorten a candidate's distance, so validate the final navigable position.
	var best := party_position
	var best_clearance := -INF
	for attempt in 96:
		var angle := _spawn_heading + float(attempt) * 2.399963
		var origin := party_position if pack_centers.is_empty() else pack_centers[-1]
		var radius := rng.randf_range(4.0, 6.0) if pack_centers.is_empty() else rng.randf_range(PACK_SEPARATION, 4.6)
		if attempt >= 48:
			origin = party_position
			radius = rng.randf_range(7.2, 10.2)
		var candidate := _clamp_field(origin + Vector2.from_angle(angle) * radius)
		var clearance := party_position.distance_to(candidate) - 4.0
		for center in pack_centers:
			clearance = minf(clearance, candidate.distance_to(center) - PACK_SEPARATION)
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
		if clearance >= 0.0:
			_spawn_heading = angle + rng.randf_range(-0.5, 0.5)
			return candidate
	return best

func _spawn_member_position(anchor: Vector2, member: int, members: int) -> Vector2:
	var best := anchor
	var best_clearance := -INF
	for attempt in 64:
		var angle := float(member) * TAU / float(members) + float(attempt) * 2.399963
		var radius := 0.42 + float(attempt % 4) * 0.18
		var candidate := _clamp_field(anchor + Vector2.from_angle(angle) * radius)
		if field_navigation != null and not field_navigation.has_clear_path(anchor, candidate):
			continue
		var clearance := candidate.distance_to(party_position) - SPAWN_SAFE_DISTANCE
		for placed in enemy_positions:
			clearance = minf(clearance, candidate.distance_to(placed) - SPAWN_SEPARATION)
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
		if clearance >= 0.0:
			return candidate
	return best

func _random_field_point() -> Vector2:
	return _clamp_field(party_position + Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(3.5, 6.0))

func _wander_point_near(origin: Vector2) -> Vector2:
	return _clamp_field(origin + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.6, 0.6)))

func _preferred_distance(archetype: String) -> float:
	if archetype == "ranged":
		return 1.25
	if archetype == "support":
		return 1.45
	if archetype == "assassin":
		return 0.48
	return 0.62

func _speed_mult(archetype: String) -> float:
	if archetype == "assassin":
		return 1.18
	if archetype == "skirmisher":
		return 1.10
	if archetype == "brute":
		return 0.88
	return 1.0

func _clamp_field(value: Vector2) -> Vector2:
	var point := Vector2(
		clampf(value.x, FIELD_MIN.x, FIELD_MAX.x),
		clampf(value.y, FIELD_MIN.y, FIELD_MAX.y)
	)

	return field_navigation.clamp_to_walkable(point) if field_navigation != null else point

func _move_actor(key: String, start: Vector2, target: Vector2, distance: float) -> Vector2:
	if field_navigation != null:
		return field_navigation.move_toward(key, start, target, distance)
	return start.move_toward(target, distance)
