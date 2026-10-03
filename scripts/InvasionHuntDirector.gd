extends RoamingHuntDirector
## Ordinary hunting only. Challenge battles explicitly retain their own movement.
var invasion_enabled := true
var _entry_pending := false
var target_attack_reaches: Array[float]=[]
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
		if distance > preferred:
			pos = _move_actor("enemy_%d" % i, pos, target, minf(float(behavior.speed)*delta,distance-preferred))
		elif bool(behavior.retreat) and distance<.65 and distance>.01:
			var away:=pos+(pos-target).normalized()*(preferred-distance)
			pos=_move_actor("enemy_%d"%i,pos,_clamp_field(away),.75*delta)
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
		enemy_positions.append(point); enemy_home_positions.append(point); enemy_wander_targets.append(party_position)
		enemy_pack_ids.append(corps_id); enemy_archetypes.append(str(enemies[i].get("archetype","brute")))
		enemy_sight_ranges.append(32.0); enemy_leash_ranges.append(0.0)
		enemy_returning.append(false); enemy_alerted.append(true)
	_entry_pending = true

func _enemy_separation_radius() -> float:
	return 1.35 if invasion_enabled else super._enemy_separation_radius()
