extends RefCounted
class_name PartyMovementDirector

const WALK_SPEED := 1.95
const SEPARATION_RADIUS := 0.70
const TARGET_LOCK_SECONDS := 0.45
const SUPPORT_COHESION_RADIUS := 2.2
const TARGET_LOAD_PENALTY := 0.18
const TARGET_OVERLOAD_PENALTY := 0.72
const FRONTLINE_SCREEN_DISTANCE := 0.58
const FLANK_STANDOFF := 0.70
const FLANK_ANGLE := 1.10
const SUPPORT_REAR_MARGIN := 0.18
const CONTROLLER_LATERAL_OFFSET := 0.72
const ROSTER = preload("res://scripts/heroes/HeroRosterCatalog.gd")

var independent_hunt := false
var holding_formation := false
var stalled_seconds: Dictionary = {}
var blocked_targets: Dictionary = {}
var formation_facing := Vector2.RIGHT
var formation_threat := -1
var formation_id := "balanced"
var positions: Dictionary = {}
var velocities: Dictionary = {}
var targets: Dictionary = {}
var distance_walked: Dictionary = {}
var travel_offsets: Dictionary = {}
var target_locks: Dictionary = {}
var field_navigation: RefCounted
var movement_profiles: Dictionary = {}
var combat_goals: Dictionary = {}
var hunt_slots: Dictionary = {}
var _decisions := CombatDecisionEngine.new()
var _planning_time: Dictionary={}

func configure(heroes: Array, states: Dictionary, origin: Vector2) -> void:
	formation_facing=Vector2.RIGHT
	formation_threat=-1
	positions.clear()
	velocities.clear()
	targets.clear()
	distance_walked.clear()
	travel_offsets.clear()
	target_locks.clear()
	movement_profiles.clear()
	combat_goals.clear()
	hunt_slots.clear()
	stalled_seconds.clear()
	blocked_targets.clear()
	_planning_time.clear()
	for index in heroes.size():
		var id := str(heroes[index].get("id", ""))
		var state: Dictionary = states.get(id, {})
		var row := str(state.get("row", "middle"))
		var roster: Dictionary = ROSTER.HEROES.get(id, {})
		var passive: Dictionary = ROSTER.skill(id, "passive")
		var role_group := str(state.get("role_group", roster.get("role_group", "딜러")))
		var ai_style := str(state.get("ai_style", "balanced"))
		var is_melee := str(roster.get("reach", "melee" if int(state.get("range", 1)) <= 1 else "ranged")) == "melee"
		movement_profiles[id] = {
			"melee": is_melee,
			"moving": str(passive.get("condition", "")) == "moved",
			"same_target": str(passive.get("condition", "")) == "same_target",
			"role_group": role_group,
			"ai_style": ai_style,
			"flanker": is_melee and role_group == "딜러" and ai_style in ["aggressive", "finisher"],
			"frontline_screen": role_group == "탱커" or ai_style == "protector",
			"rear_support": role_group == "서포터" or ai_style == "support",
			"lateral_control": role_group == "컨트롤러" or ai_style in ["controller", "control"]
		}
		var offset := Vector2((0.38 if row == "front" else (-0.38 if row == "rear" else 0.0)) - float(index / 3) * 0.16, float(index % 3 - 1) * 0.5)
		if independent_hunt:
			var count:=heroes.size()
			# A compact two-row party replaces the oversized circumference. Depth
			# spacing accounts for the camera while keeping body clearance intact.
			var columns:=mini(count,5)
			var rows:=ceili(float(count)/maxi(1,columns))
			offset=Vector2((index%columns-(columns-1)*.5)*1.22,(int(index/columns)-(rows-1)*.5)*2.30) if count>1 else Vector2.ZERO
		travel_offsets[id] = offset
		positions[id] = _clamp(origin + offset)
		velocities[id] = Vector2.ZERO
		targets[id] = -1
		distance_walked[id] = 0.0
		target_locks[id] = 0.0

func advance(delta: float, heroes: Array, states: Dictionary, runtimes: Dictionary, anchor: Vector2, enemies: Array, enemy_positions: Array[Vector2], returning: Array[bool], engaged: bool, paused := false, enemy_homes: Array[Vector2] = []) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	if holding_formation and not paused and engaged:
		_face_threat(delta,anchor,enemies,enemy_positions,returning)
	var before_positions := positions.duplicate()
	var reserved := positions.duplicate()
	for hero in heroes:
		var id := str(hero.get("id", ""))
		var state: Dictionary = states.get(id, {})
		var start: Vector2 = positions.get(id, anchor)
		var prior_velocity: Vector2=velocities.get(id,Vector2.ZERO)
		velocities[id] = Vector2.ZERO
		if int(state.get("hp", 0)) <= 0:
			targets[id] = -1
			target_locks[id] = 0.0
			combat_goals.erase(id)
			hunt_slots.erase(id)
			continue
		if paused: continue
		target_locks[id] = maxf(0.0, float(target_locks.get(id, 0.0)) - delta)
		var runtime: Dictionary = runtimes.get(id, {})
		if float(runtime.get("windup", -1.0)) >= 0.0:
			continue
		var goal: Vector2 = formation_station(id,anchor)
		if engaged:
			var previous_target: int=int(targets.get(id,-1))
			var remaining: float=maxf(0,float(_planning_time.get(id,0))-delta)
			var plan: bool=not independent_hunt or remaining<=0 or not _eligible(previous_target,enemies,enemy_positions,returning)
			var target := _select_target(id, start, enemies, enemy_positions, returning, state, states, before_positions, runtime) if plan else previous_target
			_planning_time[id]=.10+float(posmod(id.hash(),3))*.01 if plan else remaining
			targets[id] = target
			if target >= 0:
				if plan:goal = _combat_goal(id, start, target, state, runtime, states, before_positions, enemies, enemy_positions, returning, enemy_homes)
				else:goal=enemy_positions[target]+Vector2(hunt_slots.get(id,{}).get('offset',start-enemy_positions[target]))
				if independent_hunt and plan:
					goal = preload("res://scripts/hunting/HuntPositionPlanner.gd").choose(self,id,start,target,goal,state,states,before_positions,reserved,enemies,enemy_positions,runtimes)
		else:
			targets[id] = -1
		if independent_hunt:
			# A role leash permits individual pursuit without abandoning the field.
			goal = clamp_hunt_position(id,goal,anchor)
		elif holding_formation:
			var station: Vector2 = formation_station(id,anchor)
			var intercept: float=1.35 if bool(movement_profiles.get(id,{}).get('frontline_screen',false)) else 0.85
			goal = station + (goal - station).limit_length(intercept)
		goal = _clamp(goal)
		if independent_hunt and not engaged and start.distance_to(goal)<.114:continue
		reserved[id] = goal
		var step_speed:=WALK_SPEED
		if independent_hunt:
			step_speed*=.45+.55*smoothstep(0,.72,start.distance_to(goal))
			var heading: Vector2=goal-start
			if prior_velocity.length()>.1 and heading.length()>.01 and prior_velocity.normalized().dot(heading.normalized())<.3:step_speed*=.65
		var next := _move("hero_%s" % id, start, goal, step_speed * delta)
		# Separation is a local steering force; global navigation always sees the full goal.
		var separation := Vector2.ZERO
		var spacing := 1.15 if independent_hunt else SEPARATION_RADIUS
		for other_id in before_positions:
			if other_id == id or int(states.get(other_id, {}).get("hp", 0)) <= 0:
				continue
			var away: Vector2 = start - Vector2(before_positions[other_id])
			var distance := away.length()
			if distance <= 0.001:
				# Give coincident actors opposite, deterministic directions; zero vectors cannot separate.
				var pair := id + ':' + str(other_id) if id < str(other_id) else str(other_id) + ':' + id
				var direction := Vector2.from_angle(float(absi(pair.hash()) % 6283) / 1000.0)
				separation += direction if id < str(other_id) else -direction
			elif distance < spacing:
				separation += away / distance * (1.0 - distance / spacing)
		var movement := next - start
		var steered := movement + separation * (3.4 if independent_hunt else .85) * delta
		steered = steered.limit_length(WALK_SPEED * delta)
		if steered.length() < 0.08 * delta:
			steered = Vector2.ZERO
		if independent_hunt:
			steered = clamp_hunt_position(id,start+steered,anchor) - start
		if field_navigation == null or field_navigation.is_walkable(start + steered):
			next = _move("hero_local_%s" % id, start, start + steered, WALK_SPEED * delta)
		if independent_hunt:
			_adapt_blocked_route(id, delta, start, next, goal, state, enemies, enemy_positions)
		positions[id] = next
		velocities[id] = (next - start) / delta
		distance_walked[id] = float(distance_walked.get(id, 0.0)) + start.distance_to(next)

func centroid(states: Dictionary, fallback: Vector2) -> Vector2:
	var center := Vector2.ZERO
	var count := 0
	for id in positions:
		if int(states.get(id, {}).get("hp", 0)) > 0:
			center += Vector2(positions[id])
			count += 1
	return center / float(count) if count > 0 else fallback

func _select_target(id: String, start: Vector2, enemies: Array, enemy_positions: Array[Vector2], returning: Array[bool], state: Dictionary = {}, states: Dictionary = {}, before_positions: Dictionary = {}, runtime: Dictionary = {}) -> int:
	var previous := int(targets.get(id, -1))
	var previous_valid := _eligible(previous, enemies, enemy_positions, returning)
	var distances: Array = []
	for index in enemy_positions.size():
		distances.append(_travel_distance(start, enemy_positions[index]) if _eligible(index, enemies, enemy_positions, returning) else INF)
	# A nearby threat to our back line overrides a tank's ordinary damage target.
	if str(state.get("role_group", "")) == "탱커":
		var intercept := _intercept_target(id, enemies, enemy_positions, returning, distances, states, before_positions)
		if intercept >= 0:
			return _lock_choice(intercept, previous, id)
	# Do not walk away from an enemy the hero can already attack. This shares
	# the combat decision's role priorities and row/range rules.
	if not state.is_empty():
		var attack_previous := int(runtime.get("target_index", previous))
		if not _eligible(attack_previous, enemies, enemy_positions, returning):
			attack_previous = previous
		var same_target_profile := bool(movement_profiles.get(id, {}).get("same_target", false))
		var attack_profile: Dictionary = {"target_retention_bonus":0.35} if same_target_profile else {}
		var ranked := _decisions.rank_skill_targets(state, enemies, attack_profile, distances, attack_previous)
		if not ranked.is_empty():
			if independent_hunt and ranked.has(previous) and float(target_locks.get(id, 0.0)) > 0.0:
				return previous
			var reachable := _choose_reachable_target(id, state, enemies, ranked, attack_previous, same_target_profile)
			return _lock_choice(reachable, previous, id)
	if previous_valid and float(target_locks.get(id, 0.0)) > 0.0:
		return previous
	var best := -1
	var best_score := INF
	var same_target := bool(movement_profiles.get(id, {}).get("same_target", false))
	for index in enemy_positions.size():
		if not _eligible(index, enemies, enemy_positions, returning):
			continue
		var score := float(distances[index])
		if independent_hunt:
			score += _blocked_cost(id, index)
		if state.has("role_group"):
			score += _decisions.enemy_priority_score(state, enemies[index], index) * 0.9
		for other_id in targets:
			if other_id != id and int(targets[other_id]) == index:
				score += (0.12 if same_target or str(state.get("ai_style", "")) == "finisher" else 0.65) if independent_hunt else (0.04 if str(state.get("ai_style", "")) in ["finisher", "sustain"] or same_target else 0.12)
		if index == previous:
			score -= 0.60 if same_target else 0.30
		if score < best_score:
			best_score = score
			best = index
	return _lock_choice(best, previous, id)

func _choose_reachable_target(id: String, state: Dictionary, enemies: Array, ranked: Array[int], previous: int, same_target_profile: bool) -> int:
	if ranked.is_empty():
		return -1
	# Finishers and explicit same-target kits intentionally concentrate damage.
	var style := str(state.get("ai_style", "balanced"))
	if same_target_profile or style == "finisher":
		return ranked[0]
	var best := ranked[0]
	var best_score := INF
	for index in ranked:
		var enemy: Dictionary = enemies[index]
		var load := _target_load(index, id)
		var soft_cap := _target_soft_cap(state, enemy)
		var overload := maxi(0, load + 1 - soft_cap)
		var score := _decisions.skill_target_score(state, enemy, index, {})
		score += float(load) * (0.42 if independent_hunt else TARGET_LOAD_PENALTY) + float(overload) * (1.05 if independent_hunt else TARGET_OVERLOAD_PENALTY)
		if independent_hunt: score += _blocked_cost(id, index)
		if index == previous:
			score -= 0.35 if independent_hunt else 0.20
		if score < best_score:
			best_score = score
			best = index
	return best

func _target_load(target_index: int, exclude_id: String) -> int:
	var load := 0
	for other_id in targets:
		if str(other_id) != exclude_id and int(targets[other_id]) == target_index:
			load += 1
	return load

func _target_soft_cap(state: Dictionary, enemy: Dictionary) -> int:
	var role_group := str(state.get("role_group", "딜러"))
	var style := str(state.get("ai_style", "balanced"))
	var archetype := str(enemy.get("archetype", ""))
	var elite_bonus := 1 if bool(enemy.get("elite", false)) else 0
	if role_group == "컨트롤러" or style in ["controller", "control"]:
		return 1 + elite_bonus
	if role_group == "탱커" or style == "protector":
		return 2 + elite_bonus
	if role_group == "서포터" or style == "support":
		return 1 + elite_bonus
	if int(state.get("range", 2)) <= 2 and style == "aggressive" and archetype in ["support", "ranged"]:
		return 1 + elite_bonus
	return (3 if archetype in ["support", "assassin"] else 2) + elite_bonus

func _lock_choice(choice: int, previous: int, id: String) -> int:
	if choice != previous:
		target_locks[id] = TARGET_LOCK_SECONDS
	return choice

func _intercept_target(id: String, enemies: Array, enemy_positions: Array[Vector2], returning: Array[bool], distances: Array, states: Dictionary, before_positions: Dictionary) -> int:
	var best := -1
	var best_score := INF
	for index in enemy_positions.size():
		if not _eligible(index, enemies, enemy_positions, returning) or float(distances[index]) > 2.8:
			continue
		if float(enemies[index].get("stun_seconds", 0.0)) > 0.0:
			continue
		for ally_id in before_positions:
			var ally: Dictionary = states.get(ally_id, {})
			if ally_id == id or int(ally.get("hp", 0)) <= 0:
				continue
			if str(ally.get("role_group", "")) != "서포터" and str(ally.get("row", "")) != "rear":
				continue
			var threat_distance: float = enemy_positions[index].distance_to(before_positions[ally_id])
			if threat_distance > 1.35:
				continue
			var score := float(distances[index]) + threat_distance - (0.35 if str(enemies[index].get("archetype", "")) == "assassin" else 0.0)
			if index == int(targets.get(id, -1)):
				score -= 0.25
			if score < best_score:
				best = index
				best_score = score
	return best

func _combat_goal(id: String, start: Vector2, target: int, state: Dictionary, runtime: Dictionary, states: Dictionary, before_positions: Dictionary, enemies: Array, enemy_positions: Array[Vector2], returning: Array[bool], enemy_homes: Array[Vector2]) -> Vector2:
	var enemy_position := enemy_positions[target]
	var attack_range := int(state.get("range", 1))
	var profile: Dictionary = movement_profiles.get(id, {})
	var melee := bool(profile.get("melee", attack_range <= 1))
	var role_group := str(state.get("role_group", profile.get("role_group", "딜러")))
	var style := str(state.get("ai_style", profile.get("ai_style", "balanced")))
	var maximum_range := _decisions.spatial_range(attack_range)
	var preferred := _preferred_standoff(role_group, style, melee, attack_range)
	preferred = minf(preferred, maxf(0.46, maximum_range - 0.12))
	var ally_center := _ally_center(id, states, before_positions, start)
	var has_allies := false
	for ally_id in before_positions:
		has_allies = has_allies or (ally_id != id and int(states.get(ally_id, {}).get("hp", 0)) > 0)
	var away := (start - enemy_position).normalized()
	if away.length_squared() < 0.01:
		away = Vector2.from_angle(float(state.get("slot", 0)) * 2.4)
	if independent_hunt:
		away = away.rotated((float(posmod(id.hash(), 5)) - 2.0) * 0.24)
	var goal := enemy_position + away * preferred
	if melee:
		# Movement-triggered kits circle within their real attack reach rather
		# than behaving like stationary archers or running out to earn a proc.
		if bool(profile.get("moving", false)) and runtime.has("kit_last_move_position") and float(runtime.get("passive_remaining", 0.0)) <= 0.3 and start.distance_to(runtime["kit_last_move_position"]) < 0.62 and start.distance_to(enemy_position) <= maximum_range:
			for direction in [1.0, -1.0]:
				var moving_flank := enemy_position + away.rotated(1.2 * direction) * minf(0.68, maximum_range - 0.12)
				if _point_walkable(moving_flank) and _clear_path(start, moving_flank):
					return moving_flank
		# Tanks stop on the party-facing side of a threat. This makes the
		# protective line visible instead of letting tanks orbit behind enemies.
		if bool(profile.get("frontline_screen", false)) and has_allies:
			var to_party := (ally_center - enemy_position).normalized()
			if to_party.length_squared() > 0.01:
				var screen_goal := enemy_position + to_party * minf(FRONTLINE_SCREEN_DISTANCE, maximum_range - 0.12)
				screen_goal = _habitat_goal(_clamp(screen_goal), target, enemies, enemy_homes)
				if _point_walkable(screen_goal) and _clear_path(start, screen_goal):
					if start.distance_to(screen_goal) > 0.08:
						return screen_goal
					return start
		# Aggressive/finisher melee dealers visibly split to the target's sides.
		# The side is deterministic per hero so a 10-hero party does not jitter.
		if bool(profile.get("flanker", false)) and has_allies:
			var approach := (enemy_position - ally_center).normalized()
			if approach.length_squared() < 0.01:
				approach = -away
			var side := -1.0 if posmod(id.hash(), 2) == 0 else 1.0
			var flank_direction := (-approach).rotated(FLANK_ANGLE * side)
			var flank_goal := enemy_position + flank_direction * minf(FLANK_STANDOFF, maximum_range - 0.12)
			flank_goal = _habitat_goal(_clamp(flank_goal), target, enemies, enemy_homes)
			if _point_walkable(flank_goal) and _clear_path(start, flank_goal):
				if start.distance_to(flank_goal) > 0.10:
					return flank_goal
				return start
		# Melee controllers use a shallower side angle than assassins. This
		# leaves the direct party-to-enemy lane open for the main tank.
		if bool(profile.get("lateral_control", false)) and has_allies:
			var control_approach := (enemy_position - ally_center).normalized()
			if control_approach.length_squared() < 0.01:
				control_approach = -away
			var control_side := -1.0 if posmod(id.hash(), 2) == 0 else 1.0
			var control_direction := (-control_approach).rotated(0.62 * control_side)
			var control_goal := enemy_position + control_direction * minf(0.66, maximum_range - 0.12)
			control_goal = _habitat_goal(_clamp(control_goal), target, enemies, enemy_homes)
			if _point_walkable(control_goal) and _clear_path(start, control_goal):
				if start.distance_to(control_goal) > 0.10:
					return control_goal
				return start
		# A standoff point can land inside a tree even when both actors stand
		# on walkable ground. Route to the enemy until normal spacing is possible.
		if not _point_walkable(goal) or not _clear_path(goal, enemy_position):
			return enemy_position
		if start.distance_to(goal) <= 0.10:
			return start
		return goal
	var support := bool(profile.get("rear_support", false))
	var controller := bool(profile.get("lateral_control", false))
	var in_firing_range := start.distance_to(enemy_position) <= maximum_range
	# Distant approaches keep one stable global route around ponds/trees.
	# Close retreat chooses a clear local route so a wall cannot trap kiting.
	var candidates: Array[Vector2] = [start]
	var previous_goal: Dictionary = combat_goals.get(id, {})
	var retained_goal := start
	var retain_goal := false
	if int(previous_goal.get("target", -1)) == target:
		retained_goal = previous_goal.get("goal", start)
		retain_goal = retained_goal.distance_to(enemy_position) <= maximum_range and _within_habitat(retained_goal, target, enemies, enemy_homes) and _clear_path(start, retained_goal)
		if retain_goal:
			candidates.append(retained_goal)
	for angle in [0.0, 0.65, -0.65, 1.3, -1.3, 2.1, -2.1, PI]:
		var candidate := enemy_position + away.rotated(angle) * preferred
		if support and has_allies:
			candidate = ally_center + (candidate - ally_center).limit_length(SUPPORT_COHESION_RADIUS)
		candidate = _habitat_goal(candidate, target, enemies, enemy_homes)
		candidate = _clamp(candidate)
		if not _within_habitat(candidate, target, enemies, enemy_homes):
			continue
		if in_firing_range and not _clear_path(start, candidate):
			continue
		candidates.append(candidate)
		if not in_firing_range:
			break
	var best := start
	var best_score := INF
	var front_dir := (enemy_position - ally_center).normalized() if has_allies else -away
	if front_dir.length_squared() < 0.01:
		front_dir = Vector2.RIGHT
	var lateral_axis := Vector2(-front_dir.y, front_dir.x)
	var lateral_sign := -1.0 if posmod(id.hash(), 2) == 0 else 1.0
	for candidate in candidates:
		var distance := candidate.distance_to(enemy_position)
		var score := maxf(0.0, distance - (maximum_range - 0.12)) * 4.0
		score += maxf(0.0, preferred - 0.14 - distance) * 2.5
		if independent_hunt:
			for ally_id in before_positions:
				if ally_id != id and int(states.get(ally_id, {}).get("hp", 0)) > 0:
					score += maxf(0.0, 1.1 - candidate.distance_to(before_positions[ally_id])) * 1.4
		for index in enemy_positions.size():
			if _eligible(index, enemies, enemy_positions, returning):
				var danger := maxf(0.0, 0.94 - candidate.distance_to(enemy_positions[index]))
				score += danger * danger * 5.0
		score += start.distance_to(candidate) * 0.18
		if support and has_allies:
			score += maxf(0.0, candidate.distance_to(ally_center) - SUPPORT_COHESION_RADIUS) * 4.0
			# Stay behind the party center relative to the current threat. A small
			# rear margin is enough to read as a healer/support back line.
			var depth := (candidate - ally_center).dot(front_dir)
			score += maxf(0.0, depth + SUPPORT_REAR_MARGIN) * 3.8
		if controller and has_allies:
			# Controllers occupy a side lane so their control casts read separately
			# from healers and pure ranged damage dealers.
			var lateral := (candidate - ally_center).dot(lateral_axis)
			score += absf(lateral - CONTROLLER_LATERAL_OFFSET * lateral_sign) * 0.65
		if role_group == "딜러" and style == "finisher":
			# Finishers prefer the edge of their firing range, reducing needless
			# forward/backward shuffling while they wait for an execute window.
			score += absf(distance - minf(maximum_range - 0.12, preferred)) * 0.18
		if not _within_habitat(candidate, target, enemies, enemy_homes):
			score += 10.0
		if candidate == start:
			score -= 0.08
		# Keep the chosen escape side while its danger score remains comparable;
		# tiny angular changes near walls must not flip retreat every frame.
		if retain_goal and candidate == retained_goal:
			score -= 0.24
		if score < best_score:
			best = candidate
			best_score = score
	combat_goals[id] = {"target":target,"goal":best}
	return best

func _preferred_standoff(role_group: String, style: String, melee: bool, attack_range: int) -> float:
	if melee:
		if role_group == "탱커" or style == "protector":
			return 0.56
		if role_group == "컨트롤러" or style in ["controller", "control"]:
			return 0.66
		if style in ["aggressive", "finisher"]:
			return FLANK_STANDOFF
		if style == "sustain":
			return 0.60
		return 0.62
	if role_group == "서포터" or style == "support":
		return 1.60 if attack_range >= 3 else 1.18
	if role_group == "컨트롤러" or style in ["controller", "control"]:
		return 1.52 if attack_range >= 3 else 1.16
	if style == "finisher":
		return 1.62 if attack_range >= 3 else 1.18
	if style == "aggressive":
		return 1.38 if attack_range >= 3 else 1.10
	return 1.46 if attack_range >= 3 else 1.14

func _ally_center(id: String, states: Dictionary, before_positions: Dictionary, fallback: Vector2) -> Vector2:
	var result := Vector2.ZERO
	var count := 0
	for other_id in before_positions:
		if other_id != id and int(states.get(other_id, {}).get("hp", 0)) > 0:
			result += Vector2(before_positions[other_id])
			count += 1
	return result / float(count) if count > 0 else fallback

func _habitat_goal(point: Vector2, target: int, enemies: Array, enemy_homes: Array[Vector2]) -> Vector2:
	if target < enemy_homes.size():
		var leash := float(enemies[target].get("leash_radius", 0.0))
		if leash > 0.0:
			return enemy_homes[target] + (point - enemy_homes[target]).limit_length(maxf(0.8, leash - 0.4))
	return point

func _within_habitat(point: Vector2, target: int, enemies: Array, enemy_homes: Array[Vector2]) -> bool:
	return point.distance_squared_to(_habitat_goal(point, target, enemies, enemy_homes)) < 0.000001

func _travel_distance(start: Vector2, target: Vector2) -> float:
	return field_navigation.travel_distance(start, target) if field_navigation != null else start.distance_to(target)

func _point_walkable(point: Vector2) -> bool:
	return field_navigation.is_walkable(point) if field_navigation != null else point == point.clamp(RoamingHuntDirector.FIELD_MIN, RoamingHuntDirector.FIELD_MAX)

func _clear_path(start: Vector2, target: Vector2) -> bool:
	return field_navigation.has_clear_path(start, target) if field_navigation != null else true

func _eligible(index: int, enemies: Array, enemy_positions: Array[Vector2], returning: Array[bool]) -> bool:
	return index >= 0 and index < enemies.size() and index < enemy_positions.size() and int(enemies[index].get("hp", 0)) > 0 and not (index < returning.size() and returning[index])

func _clamp(point: Vector2) -> Vector2:
	point = point.clamp(RoamingHuntDirector.FIELD_MIN, RoamingHuntDirector.FIELD_MAX)
	return field_navigation.clamp_to_walkable(point) if field_navigation != null else point

func _move(key: String, start: Vector2, target: Vector2, distance: float) -> Vector2:
	return field_navigation.move_toward(key, start, target, distance) if field_navigation != null else start.move_toward(target, distance)

func apply_formation(heroes: Array, id: String) -> void:
	formation_id = preload("res://scripts/combat/BattleFormation.gd").sanitize(id)
	travel_offsets = preload("res://scripts/combat/BattleFormation.gd").offsets(heroes, formation_id)
	if independent_hunt:
		# Applying a saved formation must not restore the old wide four-lane grid.
		# Keep its role order and stat bonuses, using the compact hunting stations.
		var ordered: Array=heroes.duplicate()
		ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return preload('res://scripts/combat/BattleFormation.gd')._rank(a)<preload('res://scripts/combat/BattleFormation.gd')._rank(b))
		var columns:=mini(ordered.size(),5)
		var rows:=ceili(float(ordered.size())/maxi(1,columns))
		for index in ordered.size():
			travel_offsets[str(ordered[index].id)]=Vector2((index%columns-(columns-1)*.5)*1.22,(int(index/columns)-(rows-1)*.5)*2.30)

func place_formation(origin: Vector2) -> void:
	# Only used when creating a battlefield; live changes keep gradual movement.
	for id in travel_offsets:
		positions[id] = _clamp(formation_station(id,origin))

func formation_station(id: String, anchor: Vector2) -> Vector2:
	var offset: Vector2=travel_offsets.get(id,Vector2.ZERO)
	return anchor+offset.rotated(formation_facing.angle()) if holding_formation else anchor+offset

func _face_threat(delta: float,anchor: Vector2,enemies: Array,enemy_positions: Array[Vector2],returning: Array[bool]) -> void:
	# Follow closest living pressure rather than averaging opposite waves to zero.
	var nearest:=-1;var nearest_distance:=INF
	for i in mini(enemies.size(),enemy_positions.size()):
		if not _eligible(i,enemies,enemy_positions,returning):continue
		var distance:=anchor.distance_squared_to(enemy_positions[i])
		if distance<nearest_distance:nearest=i;nearest_distance=distance
	if nearest<0:return
	if _eligible(formation_threat,enemies,enemy_positions,returning):
		var retained_distance:=anchor.distance_squared_to(enemy_positions[formation_threat])
		if retained_distance<=nearest_distance*1.25+.25:nearest=formation_threat
	formation_threat=nearest
	var direction:=enemy_positions[nearest]-anchor
	# Once contact reaches the party core, keep the established defensive front.
	if direction.length_squared()<4.0:return
	var turn:=formation_facing.angle_to(direction.normalized())
	if absf(turn)<.08:return
	formation_facing=formation_facing.rotated(clampf(turn,-delta*.55,delta*.55)).normalized()

func hunt_leash(id: String) -> float:
	var profile: Dictionary = movement_profiles.get(id, {})
	return 3.4 if bool(profile.get("rear_support", false)) else (4.6 if bool(profile.get("flanker", false)) else 4.0)

func clamp_hunt_position(id: String, point: Vector2, anchor: Vector2) -> Vector2:
	var offset: Vector2=(point-anchor).limit_length(hunt_leash(id))
	# Keep the compact party within a fixed-height landscape combat viewport.
	# Horizontal pursuit remains independent; depth no longer spreads off screen.
	offset.y=clampf(offset.y,-1.85,1.85)
	return anchor+offset

func _blocked_cost(id: String, index: int) -> float:
	var memory: Dictionary = blocked_targets.get(id, {})
	return 4.0 if int(memory.get("target", -1)) == index and float(memory.get("remaining", 0.0)) > 0.0 else 0.0

func _adapt_blocked_route(id: String, delta: float, start: Vector2, next: Vector2, goal: Vector2, state: Dictionary, enemies: Array, enemy_positions: Array[Vector2]) -> void:
	var memory: Dictionary = blocked_targets.get(id, {})
	memory["remaining"] = maxf(0.0, float(memory.get("remaining", 0.0)) - delta)
	blocked_targets[id] = memory
	var target := int(targets.get(id, -1))
	if target < 0 or target >= enemy_positions.size():
		stalled_seconds[id] = 0.0; return
	var distance_to_goal := start.distance_to(goal)
	var approaching := next.distance_to(goal) < distance_to_goal - 0.01 * delta
	# Waiting in attack reach or during a cast is intentional; only failed pursuit adapts.
	# Successful movement already clears a stall; skip the read-only all-enemy
	# range query until a hero actually needs to distinguish waiting from stuck.
	if approaching or distance_to_goal < 0.2:
		stalled_seconds[id] = 0.0; return
	if _decisions.can_attack_enemy(state, enemies, target, _distances_from(start, enemy_positions)):
		stalled_seconds[id] = 0.0; return
	stalled_seconds[id] = float(stalled_seconds.get(id, 0.0)) + delta
	if float(stalled_seconds[id]) >= 2.5:
		blocked_targets[id] = {"target":target, "remaining":4.0}
		stalled_seconds[id] = 0.0
		target_locks[id] = 0.0
		combat_goals.erase(id)

func _distances_from(start: Vector2, enemy_positions: Array[Vector2]) -> Array:
	var distances: Array = []
	for point in enemy_positions: distances.append(start.distance_to(point))
	return distances
