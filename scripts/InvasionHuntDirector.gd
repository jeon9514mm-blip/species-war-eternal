extends RoamingHuntDirector
## Ordinary hunting only. Challenge battles explicitly retain their own movement.
var invasion_enabled := true
var _entry_pending := false
var target_attack_reaches: Array[float]=[]
var target_hero_ids: Array[String]=[]
const ENTRY_SIDES := [
	{"id":"east","name":"동쪽","anchor":Vector2(30.2,10)},
	{"id":"west","name":"서쪽","anchor":Vector2(1.8,10)},
	{"id":"north","name":"북쪽","anchor":Vector2(16,1.4)},
	{"id":"south","name":"남쪽","anchor":Vector2(16,18.6)},
	{"id":"northeast","name":"북동쪽","anchor":Vector2(27.0,3.8)},
	{"id":"southwest","name":"남서쪽","anchor":Vector2(5.0,16.2)},
	{"id":"northwest","name":"북서쪽","anchor":Vector2(5.0,3.8)},
	{"id":"southeast","name":"남동쪽","anchor":Vector2(27.0,16.2)}
]
static func entry_side(corps_id: int) -> Dictionary:
	return ENTRY_SIDES[posmod(corps_id-1,ENTRY_SIDES.size())].duplicate(true)

static func approach_profile(archetype: String) -> Dictionary:
	# Standoff stays within actual attack reach; ranged enemies remain approachable.
	match archetype:
		'ranged':return {'distance':1.18,'speed':1.35,'retreat':true}
		'support':return {'distance':1.35,'speed':1.20,'retreat':true}
		'assassin':return {'distance':.60,'speed':1.85,'retreat':false}
		_:return {'distance':.68,'speed':1.40,'retreat':false}
func advance(delta: float, alive_mask: Array, immobile_mask: Array = [], hero_targets: Array[Vector2] = []) -> Dictionary:
	if not invasion_enabled: return super.advance(delta, alive_mask, immobile_mask, hero_targets)
	var result := {"mode":mode, "engaged":false, "encounter_started":false, "party_velocity":Vector2.ZERO, "target_index":-1, "returned_indices":[]}
	if delta <= 0.0 or not is_finite(delta) or mode == Mode.RECOVER: return result
	encounter_seconds += delta
	for i in enemy_positions.size():
		if i >= alive_mask.size() or not bool(alive_mask[i]): continue
		if i < immobile_mask.size() and bool(immobile_mask[i]): continue
		var target: Vector2 = hero_targets[i] if i < hero_targets.size() else party_position
		var pos: Vector2 = enemy_positions[i]
		var distance: float = pos.distance_to(target)
		var behavior:=approach_profile(enemy_archetypes[i] if i<enemy_archetypes.size() else 'brute')
		var preferred: float=behavior.distance
		# A ranged enemy cannot hold a melee-only defender in permanent stalemate.
		if i<target_attack_reaches.size():preferred=minf(preferred,maxf(.46,target_attack_reaches[i]-.08))
		var approach := _approach_slot(i, target, preferred, alive_mask)
		if bool(behavior.retreat) and distance<.65 and distance>.01:
			var away:=pos+(pos-target).normalized()*(preferred-distance)
			pos=_move_actor("enemy_%d"%i,pos,_clamp_field(away),.75*delta)
		elif distance > preferred or pos.distance_to(approach) > .12:
			pos = _move_actor("enemy_%d" % i, pos, approach, float(behavior.speed)*delta)
		enemy_positions[i] = _clamp_field(pos)
	_separate_enemies(delta, alive_mask, immobile_mask)
	current_target = _nearest_alive_enemy(alive_mask)
	aggro_active = current_target >= 0
	mode = Mode.ENGAGED if aggro_active else Mode.PATROL
	result.merge({"mode":mode, "engaged":aggro_active, "target_index":current_target, "encounter_started":_entry_pending and aggro_active}, true)
	_entry_pending = false
	return result

func append_corps(enemies: Array, corps_id: int) -> void:
	var entry:=entry_side(corps_id)
	var anchor: Vector2=entry.anchor
	var outward: Vector2=(anchor-FIELD_CENTER).normalized()
	var tangent:=Vector2(-outward.y,outward.x)
	for i in enemies.size():
		# Orient the same five-lane corps toward the center at every entrance.
		# Rows extend inward so no member is clamped into a corner stack.
		var point: Vector2 = _clamp_field(anchor-outward*(i/5)*1.15+tangent*(i%5-2)*1.8)
		if field_navigation!=null:point=field_navigation.clamp_to_walkable(point)
		enemies[i]["entry_side"]=entry.id
		# Invasions roam the whole field. Hero pursuit must use that same rule;
		# an old habitat leash must not prevent closing on a waiting ring.
		enemies[i]['leash_radius']=0.0
		enemy_positions.append(point); enemy_home_positions.append(point); enemy_wander_targets.append(party_position)
		enemy_pack_ids.append(corps_id); enemy_archetypes.append(str(enemies[i].get("archetype","brute")))
		enemy_sight_ranges.append(32.0); enemy_leash_ranges.append(0.0)
		enemy_returning.append(false); enemy_alerted.append(true)
	_entry_pending = true

func _enemy_separation_radius() -> float:
	return 1.35 if invasion_enabled else super._enemy_separation_radius()

func _approach_slot(index: int, target: Vector2, radius: float, alive_mask: Array) -> Vector2:
	var home := enemy_home_positions[index] if index < enemy_home_positions.size() else enemy_positions[index]
	var direction := (home - target).normalized()
	if direction.length_squared() < 0.01: direction = Vector2.RIGHT
	var rank := 0
	if index < target_hero_ids.size():
		for other in index:
			if other < alive_mask.size() and bool(alive_mask[other]) and other < target_hero_ids.size() and target_hero_ids[other] == target_hero_ids[index]: rank += 1
	# Two contact lanes fit the actor footprints. Overflow waits in spaced rings
	# and advances as a lane opens instead of piling fifteen bodies on one hero.
	var angle := (-PI*.5 if rank == 0 else PI*.5)
	if rank >= 2:
		angle = float((rank-2)%6)*TAU/6.0
		radius = 2.15 + float((rank-2)/6)*1.10
	var point := _clamp_field(target + direction.rotated(angle) * radius)
	if rank < 2 and field_navigation != null:
		# A contact slot projected to the far side of a rock creates a stalemate
		# at the hero's pursuit leash. Find a clear lane on the target's side.
		for offset in [0.0,-.45,.45,-.90,.90,-1.5,1.5,PI]:
			var candidate := _clamp_field(target + direction.rotated(angle+offset) * radius)
			if field_navigation.is_walkable(candidate) and field_navigation.has_clear_path(target,candidate):return candidate
		return target
	if field_navigation != null and not field_navigation.is_walkable(point): return field_navigation.clamp_to_walkable(point)
	return point
