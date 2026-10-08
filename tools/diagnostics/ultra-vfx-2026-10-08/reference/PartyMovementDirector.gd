extends PartyMovementDirector
## Frozen pre-cache advance entry for deterministic trajectory verification.
const BEFORE=preload("res://tools/diagnostics/ultra-vfx-2026-10-08/reference/HuntPositionPlanner.gd")
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
					goal = BEFORE.choose(self,id,start,target,goal,state,states,before_positions,reserved,enemies,enemy_positions,runtimes)
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
