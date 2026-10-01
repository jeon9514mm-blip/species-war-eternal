extends RoamingHuntDirector
## Ordinary hunting only. Challenge battles explicitly retain their own movement.
var invasion_enabled := true
var _entry_pending := false
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
		# Even ranged attackers advance into the defended area instead of staying
		# outside melee reach and forcing the formation to chase them.
		var preferred: float = 0.65
		if distance > preferred:
			pos = _move_actor("enemy_%d" % i, pos, target, minf(1.5 * delta, distance - preferred))
		enemy_positions[i] = _clamp_field(pos)
	_separate_enemies(delta, alive_mask, immobile_mask)
	current_target = _nearest_alive_enemy(alive_mask)
	aggro_active = current_target >= 0
	mode = Mode.ENGAGED if aggro_active else Mode.PATROL
	result.merge({"mode":mode, "engaged":aggro_active, "target_index":current_target, "encounter_started":_entry_pending and aggro_active}, true)
	_entry_pending = false
	return result

func append_corps(enemies: Array, corps_id: int) -> void:
	for i in enemies.size():
		var point: Vector2 = _clamp_field(Vector2(28.2 + (i / 5) * .8, 5.4 + (i % 5) * 2.2 + (corps_id % 2) * .35))
		enemy_positions.append(point); enemy_home_positions.append(point); enemy_wander_targets.append(party_position)
		enemy_pack_ids.append(corps_id); enemy_archetypes.append(str(enemies[i].get("archetype","brute")))
		enemy_sight_ranges.append(32.0); enemy_leash_ranges.append(0.0)
		enemy_returning.append(false); enemy_alerted.append(true)
	_entry_pending = true

func _enemy_separation_radius() -> float:
	return 1.35 if invasion_enabled else super._enemy_separation_radius()
