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
	var best := ""
	var best_score := INF
	for value in pool:
		var id := str(value)
		var hero: Dictionary = main.hero_battle_state[id]
		var score := position.distance_to(main._hero_field_position(id))
		var rear := str(hero.get("role_group", "")) == "서포터" or str(hero.get("row", "")) == "rear"
		var front := str(hero.get("role_group", "")) == "탱커" or str(hero.get("row", "")) == "front"
		var favored := rear if archetype in ["assassin", "ranged"] else front
		if favored: score -= 1.15
		var health: float=clampf(float(hero.get('hp',1))/maxf(1,float(hero.get('max_hp',hero.get('hp',1)))),0,1)
		score-=(1.0-health)*.82
		var nearby:=0
		for other_id in candidates:
			if other_id!=id and main._hero_field_position(str(other_id)).distance_to(main._hero_field_position(id))<.74:nearby+=1
		score-=float(maxi(0,2-nearby))*.13
		var load := 0
		for other in main.enemy_wave.size():
			if other != index and int(main.enemy_wave[other].get("hp", 0)) > 0 and str(main.enemy_wave[other].get("target_id", "")) == id: load += 1
		# Tanks may hold more opponents, but proximity still matters.
		var capacity := 4 if str(hero.get("role_group", "")) == "탱커" else 2
		score += float(load) * 0.18 + float(maxi(0, load - capacity)) * 0.55
		if id == previous: score -= 0.70
		if score < best_score:
			best_score = score; best = id
	if best != previous: enemy["hunt_target_lock"] = 0.75
	return best
