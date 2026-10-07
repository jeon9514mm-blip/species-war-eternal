extends RefCounted
class_name CombatDecisionEngine

# Scores are lower-is-better. Keep a valid target through small HP changes,
# while allowing a newly dangerous or wounded enemy to override the preference.
const TARGET_RETENTION_BONUS := 0.07

func spatial_range(attack_range: int) -> float:
	return 0.95 if attack_range <= 1 else (1.32 if attack_range == 2 else 1.75)

func select_enemy_target(hero_state: Dictionary, enemies: Array, distances: Array = [], previous_target: int = -1) -> int:
	if not _is_alive(hero_state):
		return -1
	var attack_range := maxi(1, int(hero_state.get("range", 2)))
	var nearest_row := _nearest_reachable_row(enemies, distances, attack_range)
	var best := -1
	var best_score := INF
	for index in enemies.size():
		if not _eligible_enemy(enemies, index, distances, attack_range, nearest_row):
			continue
		var enemy: Dictionary = enemies[index]
		var score := _enemy_score(hero_state, enemy, index)
		if index == previous_target:
			score -= TARGET_RETENTION_BONUS
		if score < best_score:
			best_score = score
			best = index
	# No reachable target means wait or approach; it does not mean wave cleared.
	return best

# Shared by approach movement and combat so an actor does not chase one role
# priority and then attack an unrelated target when it reaches the pack.
func enemy_priority_score(hero_state: Dictionary, enemy: Dictionary, index: int) -> float:
	return _enemy_score(hero_state, enemy, index)

func skill_target_score(hero_state: Dictionary, enemy: Dictionary, index: int, profile: Dictionary) -> float:
	var score := _enemy_score(hero_state, enemy, index)
	var ratio := clampf(float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1))), 0.0, 1.0)
	if ratio <= float(profile.get("execute_threshold", -1.0)):
		score -= 0.85 * maxf(0.0, float(profile.get("execute_bonus", 1.0)) - 1.0)
	if ratio >= float(profile.get("high_hp_threshold", 2.0)) and float(profile.get("high_hp_bonus", 1.0)) > 1.0:
		score -= 0.65 + maxf(0.0, float(profile.get("high_hp_bonus", 1.0)) - 1.0)
	if bool(enemy.get("elite", false)):
		score -= 0.75 * maxf(0.0, float(profile.get("elite_bonus", 1.0)) - 1.0)
	var debuffed := false
	for status in ["stun", "weaken", "vulnerable"]:
		debuffed = debuffed or float(enemy.get(status + "_seconds", 0.0)) > 0.0
	if debuffed:
		score -= 1.2 * maxf(0.0, float(profile.get("status_bonus", 1.0)) - 1.0)
	var kind := str(profile.get("kind", "damage"))
	var status := kind if kind in ["stun", "weaken", "vulnerable"] else str(profile.get("status", ""))
	if not status.is_empty() and float(enemy.get(status + "_seconds", 0.0)) > 0.35:
		# Keep damage available, but spend limited control hits on fresh threats.
		score += 1.5
	if float(profile.get("lifesteal", 0.0)) > 0.0:
		var self_ratio := float(hero_state.get("hp", 0)) / maxf(1.0, float(hero_state.get("max_hp", 1)))
		if self_ratio < 0.6:
			var expected := maxf(1.0, float(hero_state.get("attack", 1)) * float(profile.get("value", 1.0)))
			# Near-dead targets cannot return useful life: absorption uses actual damage.
			score += 1.65 * (1.0 - minf(1.0, float(enemy.get("hp", 0)) / expected))
	return score

func rank_skill_targets(hero_state: Dictionary, enemies: Array, profile: Dictionary, distances: Array = [], previous_target: int = -1) -> Array[int]:
	var candidates: Array[int] = []
	if not _is_alive(hero_state):
		return candidates
	var attack_range := maxi(1, int(hero_state.get("range", 2)))
	var nearest_row := _nearest_reachable_row(enemies, distances, attack_range)
	var kind := str(profile.get("kind", "damage"))
	var avoid_status := bool(profile.get("avoid_active_status", false)) and kind in ["stun", "weaken", "vulnerable"]
	for index in enemies.size():
		if not _eligible_enemy(enemies, index, distances, attack_range, nearest_row):
			continue
		if avoid_status and float(enemies[index].get(kind + "_seconds", 0.0)) > 0.0:
			continue
		candidates.append(index)
	var retention := float(profile.get("target_retention_bonus", TARGET_RETENTION_BONUS))
	candidates.sort_custom(func(a: int, b: int) -> bool:
		if kind in ["stun", "weaken", "vulnerable"]:
			var a_controlled := float(enemies[a].get(kind + "_seconds", 0.0)) > .35
			var b_controlled := float(enemies[b].get(kind + "_seconds", 0.0)) > .35
			if a_controlled != b_controlled:
				return not a_controlled
		var left := skill_target_score(hero_state, enemies[a], a, profile) - (retention if a == previous_target else 0.0)
		var right := skill_target_score(hero_state, enemies[b], b, profile) - (retention if b == previous_target else 0.0)
		return a < b if is_equal_approx(left, right) else left < right
	)
	return candidates

func select_skill_target(hero_state: Dictionary, enemies: Array, profile: Dictionary, distances: Array = [], previous_target: int = -1) -> int:
	var candidates := rank_skill_targets(hero_state, enemies, profile, distances, previous_target)
	return candidates[0] if not candidates.is_empty() else -1

func can_attack_enemy(hero_state: Dictionary, enemies: Array, index: int, distances: Array = []) -> bool:
	if not _is_alive(hero_state):
		return false
	var attack_range := maxi(1, int(hero_state.get("range", 2)))
	return _eligible_enemy(enemies, index, distances, attack_range, _nearest_reachable_row(enemies, distances, attack_range))

func select_hero_target(enemy: Dictionary, enemy_index: int, hero_states: Dictionary, alive_ids: Array, previous_target: String = "") -> String:
	var alive: Array[String] = []
	var taunting: Array[String] = []
	var tanks: Array[String] = []
	var front: Array[String] = []
	var rear: Array[String] = []
	var support: Array[String] = []
	for id_value in alive_ids:
		var hero_id := str(id_value)
		if alive.has(hero_id) or not hero_states.has(hero_id) or not _is_alive(hero_states[hero_id]):
			continue
		var state: Dictionary = hero_states[hero_id]
		alive.append(hero_id)
		if float(state.get("taunt", 0.0)) > 0.0:
			taunting.append(hero_id)
		if str(state.get("role_group", "")) == "탱커":
			tanks.append(hero_id)
		if str(state.get("role_group", "")) == "서포터":
			support.append(hero_id)
		if str(state.get("row", "front")) == "front":
			front.append(hero_id)
		elif str(state.get("row", "front")) == "rear":
			rear.append(hero_id)
	if alive.is_empty():
		return ""
	var pool: Array[String] = alive
	if not taunting.is_empty():
		pool = taunting
	else:
		match str(enemy.get("archetype", "brute")):
			"assassin":
				pool = support if not support.is_empty() else (rear if not rear.is_empty() else alive)
			"ranged":
				pool = rear if not rear.is_empty() else alive
			_:
				pool = tanks if not tanks.is_empty() else (front if not front.is_empty() else alive)
	# Retention must never override a new taunt or the archetype's priority pool.
	if pool.has(previous_target):
		return previous_target
	return pool[posmod(enemy_index, pool.size())]

func _is_alive(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	return int(value.get("hp", 0)) > 0 and bool(value.get("alive", true))

func _within_distance(index: int, distances: Array, attack_range: int) -> bool:
	# Empty distances preserve row-only selection in raids and simulations.
	if distances.is_empty():
		return true
	if index >= distances.size() or typeof(distances[index]) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var distance := float(distances[index])
	return is_finite(distance) and distance >= 0.0 and distance <= spatial_range(attack_range)

func _nearest_reachable_row(enemies: Array, distances: Array, attack_range: int) -> int:
	var nearest_row := 2147483647
	for index in enemies.size():
		if _is_alive(enemies[index]) and _within_distance(index, distances, attack_range):
			nearest_row = mini(nearest_row, int(enemies[index].get("row", 0)))
	return nearest_row

func _eligible_enemy(enemies: Array, index: int, distances: Array, attack_range: int, nearest_row: int) -> bool:
	if index < 0 or index >= enemies.size() or not _is_alive(enemies[index]):
		return false
	if not _within_distance(index, distances, attack_range):
		return false
	# Formation rows describe roster-only simulations. Once world distances are
	# supplied, a spawned row tag cannot block an adjacent physical target.
	if not distances.is_empty():
		return true
	var enemy_row := int(enemies[index].get("row", 0))
	if attack_range == 1 and enemy_row > nearest_row:
		return false
	if attack_range == 2 and enemy_row > nearest_row + 1:
		return false
	return true

func _enemy_score(hero_state: Dictionary, enemy: Dictionary, index: int) -> float:
	var ratio := clampf(float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1))), 0.0, 1.0)
	var row := int(enemy.get("row", 0))
	var archetype := str(enemy.get("archetype", ""))
	var elite := bool(enemy.get("elite", false))
	var attack := maxf(0.0, float(enemy.get("attack", 0)))
	var role := str(hero_state.get("role_group", "딜러"))
	var style := str(hero_state.get("ai_style", "balanced"))
	var score := ratio + float(index) * 0.03
	if elite:
		score -= 0.24
	if archetype == "support":
		score -= 0.20
	elif archetype == "assassin":
		score -= 0.10
	if role == "탱커":
		score = float(row) + float(index) * 0.02 - (0.12 if elite else 0.0)
	elif role == "컨트롤러" or style in ["controller", "control"]:
		score = -attack * 0.01 + ratio * 0.25 + float(index) * 0.01
		if archetype in ["support", "assassin"]:
			score -= 0.25
		if elite:
			score -= 0.20
	match style:
		"finisher":
			# Finishers keep pressure on wounded targets even when a healthier
			# support unit looks attractive to the generic priority rules.
			score += ratio * 0.55
			if archetype in ["support", "assassin"]:
				score -= 0.08
			if row > 0:
				score -= 0.05
		"protector":
			# Attack is the existing immediate danger signal, not accumulated threat.
			score -= minf(0.22, attack * 0.003)
			if archetype == "assassin":
				score -= 0.10
		"controller", "control":
			if elite:
				score -= 0.08
			if archetype == "support":
				score -= 0.10
		"aggressive":
			# Pressure styles hunt exposed back-line archetypes instead of merely
			# choosing the first front-row body. Their movement director then
			# makes melee variants approach from a visible flank.
			if archetype == "support":
				score -= 0.24
			elif archetype == "ranged":
				score -= 0.16
			elif archetype == "assassin":
				score -= 0.06
		"support":
			score += float(row) * 0.06
			# Support basics avoid the highest-damage threat when two targets are
			# otherwise comparable; survival positioning remains the main defense.
			score += minf(0.10, attack * 0.001)
		"sustain":
			var self_ratio := float(hero_state.get("hp", 0)) / maxf(1.0, float(hero_state.get("max_hp", 1)))
			if self_ratio < 0.6:
				score += minf(0.16, attack * 0.002)
				var expected_basic := maxf(1.0, float(hero_state.get("attack", 1)))
				if float(enemy.get("hp", 0)) < expected_basic * 0.5:
					score += 0.85
	return score
