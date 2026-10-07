extends RefCounted
## Spatial target assignment for ordinary hunting; challenge priorities stay separate.
static func select(main: Node, index: int, candidates: Array) -> String:
	if candidates.is_empty(): return ""
	var enemy: Dictionary = main.enemy_wave[index]
	var previous := str(enemy.get("target_id", ""))
	var taunting: Array = []
	for id in candidates:
		if float(main.hero_battle_state[id].get("taunt", 0.0)) > 0.0: taunting.append(id)
	var pool: Array = taunting if not taunting.is_empty() else candidates
	if pool.has(previous) and float(enemy.get("hunt_target_lock", 0.0)) > 0.0: return previous
	var position: Vector2 = main.roaming_hunt.enemy_position(index)
	var archetype := str(enemy.get("archetype", "brute"))
	# Keep these values local to this decision: the caller commits each target
	# before the next monster decides, so a frame-wide cache would become stale.
	var hero_positions: Dictionary = {}
	for id in candidates: hero_positions[str(id)] = main._hero_field_position(str(id))
	var target_loads: Dictionary = {}
	for other in main.enemy_wave.size():
		var other_enemy: Dictionary = main.enemy_wave[other]
		if other == index or int(other_enemy.get("hp", 0)) <= 0: continue
		var target := str(other_enemy.get("target_id", ""))
		target_loads[target] = int(target_loads.get(target, 0)) + 1
	var best := ""
	var best_score := INF
	for value in pool:
		var id := str(value)
		var hero: Dictionary = main.hero_battle_state[id]
		var point: Vector2 = hero_positions[id]
		var score := position.distance_to(point)
		var rear := str(hero.get("role_group", "")) == "서포터" or str(hero.get("row", "")) == "rear"
		var front := str(hero.get("role_group", "")) == "탱커" or str(hero.get("row", "")) == "front"
		var favored := rear if archetype in ["assassin", "ranged"] else front
		if favored: score -= 1.15
		var health: float=clampf(float(hero.get('hp',1))/maxf(1,float(hero.get('max_hp',hero.get('hp',1)))),0,1)
		score-=(1.0-health)*.82
		var nearby:=0
		for other_id in candidates:
			if other_id!=id and Vector2(hero_positions[str(other_id)]).distance_to(point)<.74:nearby+=1
		score-=float(maxi(0,2-nearby))*.13
		var load := int(target_loads.get(id, 0))
		# Tanks may hold more opponents, but proximity still matters.
		var capacity := 4 if str(hero.get("role_group", "")) == "탱커" else 2
		score += float(load) * 0.18 + float(maxi(0, load - capacity)) * 0.55
		if id == previous: score -= 0.70
		if score < best_score:
			best_score = score; best = id
	if best != previous: enemy["hunt_target_lock"] = 0.75
	return best
