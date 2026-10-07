extends RefCounted
class_name AutoCombatTactics

const CAST_THRESHOLD := 55

func party_context(hero_states: Dictionary) -> Dictionary:
	var alive := 0
	var injured := 0
	var hp_sum := 0.0
	var lowest := 1.0
	for state_value in hero_states.values():
		if typeof(state_value) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = state_value
		var max_hp := maxi(1, int(state.get("max_hp", 1)))
		var hp := maxi(0, int(state.get("hp", 0)))
		if hp <= 0:
			continue
		alive += 1
		var ratio := float(hp) / float(max_hp)
		hp_sum += ratio
		lowest = minf(lowest, ratio)
		if ratio < 0.72:
			injured += 1
	if alive <= 0:
		return {"alive": 0, "injured": 0, "avg_hp": 0.0, "lowest_hp": 0.0}
	return {
		"alive": alive,
		"injured": injured,
		"avg_hp": hp_sum / float(alive),
		"lowest_hp": lowest
	}

func enemy_context(enemy_wave: Array) -> Dictionary:
	var alive := 0
	var elites := 0
	var supports := 0
	var assassins := 0
	var total_attack := 0
	var lowest_hp := 1.0
	for enemy_value in enemy_wave:
		if typeof(enemy_value) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_value
		var hp := maxi(0, int(enemy.get("hp", 0)))
		if hp <= 0:
			continue
		alive += 1
		total_attack += maxi(0, int(enemy.get("attack", 0)))
		var ratio := float(hp) / maxf(1.0, float(enemy.get("max_hp", 1)))
		lowest_hp = minf(lowest_hp, ratio)
		if bool(enemy.get("elite", false)):
			elites += 1
		var archetype := str(enemy.get("archetype", ""))
		if archetype == "support":
			supports += 1
		elif archetype == "assassin":
			assassins += 1
	if alive <= 0:
		lowest_hp = 0.0
	return {
		"alive": alive,
		"elites": elites,
		"supports": supports,
		"assassins": assassins,
		"total_attack": total_attack,
		"lowest_hp": lowest_hp
	}

func boss_context(is_raid: bool, telegraph_pending: bool, telegraph_remaining: float, boss_hp: int, boss_max_hp: int) -> Dictionary:
	return {
		"is_raid": is_raid,
		"telegraph": telegraph_pending,
		"telegraph_remaining": maxf(0.0, telegraph_remaining),
		"boss_hp_ratio": float(maxi(0, boss_hp)) / maxf(1.0, float(maxi(1, boss_max_hp)))
	}

func skill_priority(profile: Dictionary, hero_state: Dictionary, party: Dictionary, enemies: Dictionary, boss: Dictionary) -> int:
	if int(hero_state.get("hp", 0)) <= 0 or int(party.get("alive", 0)) <= 0:
		return 0
	var kind := str(profile.get("kind", "damage"))
	var alive_enemies := int(enemies.get("alive", 0))
	var elite_count := int(enemies.get("elites", 0))
	var is_raid := bool(boss.get("is_raid", false))
	var telegraph := bool(boss.get("telegraph", false))
	var avg_hp := float(party.get("avg_hp", 1.0))
	var lowest_hp := float(party.get("lowest_hp", 1.0))
	var injured := int(party.get("injured", 0))
	var self_ratio := float(hero_state.get("hp", 1)) / maxf(1.0, float(hero_state.get("max_hp", 1)))
	var ai_style := str(hero_state.get("ai_style", "balanced"))
	var lowest_enemy := float(enemies.get("lowest_hp", 1.0))
	var style_bonus := 0
	if ai_style == "protector" and kind == "guard":
		style_bonus = 12
	elif ai_style == "support" and kind == "heal":
		style_bonus = 14 if injured >= 2 else 12
	elif ai_style in ["controller", "control"] and kind in ["stun", "weaken", "vulnerable"]:
		style_bonus = 14 if elite_count > 0 or telegraph else 12
	elif ai_style == "aggressive" and kind in ["damage", "stun"]:
		style_bonus = 12 if alive_enemies >= 3 or elite_count > 0 else 8
	elif ai_style == "finisher" and kind == "damage":
		# High-HP sniper skills are an explicit exception: they should fire near
		# full health even though the hero's broad identity is a finisher.
		var high_hp_skill := float(profile.get("high_hp_bonus", 1.0)) > 1.0 and float(profile.get("high_hp_threshold", 2.0)) <= 1.0
		if high_hp_skill:
			style_bonus = 12 if lowest_enemy >= float(profile.get("high_hp_threshold", 0.7)) else 4
		elif lowest_enemy < 0.35:
			style_bonus = 18
		elif lowest_enemy < 0.60:
			style_bonus = 10
		elif elite_count == 0 and not is_raid and lowest_enemy > 0.80:
			style_bonus = -8
		else:
			style_bonus = 3
	elif ai_style == "sustain" and kind in ["lifesteal", "heal"]:
		style_bonus = 14 if self_ratio < 0.50 else (10 if self_ratio < 0.75 else 4)
	match kind:
		"heal":
			var threshold := float(profile.get("threshold", 0.72))
			if lowest_hp > threshold:
				return 0
			var score := 62
			if lowest_hp < 0.50:
				score += 25
			if injured >= 2:
				score += 12
			if telegraph:
				score += 10
			return mini(100, score + style_bonus)
		"guard":
			if telegraph:
				return mini(100, 100 + style_bonus)
			# A healthy back line must not conceal the tank's own survival need.
			if self_ratio <= 0.35:
				return mini(100, 95 + style_bonus)
			if self_ratio <= 0.55:
				return mini(100, 80 + style_bonus)
			if avg_hp < 0.60:
				return mini(100, 88 + style_bonus)
			if elite_count > 0 and alive_enemies >= 2:
				return mini(100, 78 + style_bonus)
			if alive_enemies >= 4:
				return mini(100, 70 + style_bonus)
			if is_raid:
				return mini(100, 62 + style_bonus)
			return mini(100, 22 + style_bonus)
		"stun":
			if telegraph:
				return mini(100, 100 + style_bonus)
			if elite_count > 0:
				return mini(100, 82 + style_bonus)
			if alive_enemies >= 4:
				return mini(100, 72 + style_bonus)
			if is_raid:
				return mini(100, 64 + style_bonus)
			return mini(100, 42 + style_bonus)
		"weaken":
			if telegraph:
				return mini(100, 92 + style_bonus)
			if elite_count > 0:
				return mini(100, 78 + style_bonus)
			if alive_enemies >= 3:
				return mini(100, 70 + style_bonus)
			if is_raid:
				return mini(100, 66 + style_bonus)
			return mini(100, 42 + style_bonus)
		"vulnerable":
			if is_raid and float(boss.get("boss_hp_ratio", 1.0)) > 0.12:
				return mini(100, 76 + style_bonus)
			if elite_count > 0:
				return mini(100, 74 + style_bonus)
			if alive_enemies >= 3:
				return mini(100, 65 + style_bonus)
			return mini(100, 50 + style_bonus)
		"lifesteal":
			if self_ratio < 0.60:
				return mini(100, 92 + style_bonus)
			if self_ratio < 0.82:
				return mini(100, 74 + style_bonus)
			if elite_count > 0 or is_raid:
				return mini(100, 62 + style_bonus)
			return mini(100, 52 + style_bonus)
		_:
			if elite_count > 0:
				return mini(100, 80 + style_bonus)
			if int(enemies.get("supports", 0)) > 0:
				return mini(100, 72 + style_bonus)
			if alive_enemies >= 3:
				return mini(100, 68 + style_bonus)
			if is_raid:
				return mini(100, 64 + style_bonus)
			return mini(100, 58 + style_bonus)

func should_use_skill(profile: Dictionary, hero_state: Dictionary, party: Dictionary, enemies: Dictionary, boss: Dictionary) -> bool:
	return skill_priority(profile, hero_state, party, enemies, boss) >= CAST_THRESHOLD

func ultimate_priority(role_group: String, hero_state: Dictionary, party: Dictionary, enemies: Dictionary, boss: Dictionary, profile: Dictionary = {}) -> int:
	if int(hero_state.get("hp", 0)) <= 0 or int(party.get("alive", 0)) <= 0:
		return 0
	if role_group != "서포터" and int(enemies.get("alive", 0)) <= 0:
		return 0
	var telegraph := bool(boss.get("telegraph", false))
	var is_raid := bool(boss.get("is_raid", false))
	var avg_hp := float(party.get("avg_hp", 1.0))
	var lowest_hp := float(party.get("lowest_hp", 1.0))
	var injured := int(party.get("injured", 0))
	var elite_count := int(enemies.get("elites", 0))
	var alive_enemies := int(enemies.get("alive", 0))
	var ai_style := str(hero_state.get("ai_style", "balanced"))
	var style_bonus := 0
	match ai_style:
		"protector":
			style_bonus = 10 if role_group == "탱커" else 0
		"support":
			style_bonus = 10 if role_group == "서포터" else 0
		"controller", "control":
			style_bonus = 10 if role_group == "컨트롤러" else 0
		"aggressive":
			style_bonus = 10 if role_group == "딜러" and (alive_enemies >= 3 or elite_count > 0) else (6 if role_group == "딜러" else 0)
		"finisher":
			if role_group == "딜러":
				var lowest_enemy := float(enemies.get("lowest_hp", 1.0))
				# Some finishers intentionally own high-HP sniper ultimates. Keep that
				# authored identity instead of applying the generic wounded-target hold.
				var high_hp_ultimate := float(profile.get("high_hp_bonus", 1.0)) > 1.0 and float(profile.get("high_hp_threshold", 2.0)) <= 1.0
				if high_hp_ultimate and lowest_enemy >= float(profile.get("high_hp_threshold", 0.7)):
					style_bonus = 10
				else:
					style_bonus = 12 if lowest_enemy < 0.45 else (-8 if lowest_enemy > 0.78 and elite_count == 0 and not is_raid else 3)
		"sustain":
			var self_ratio := float(hero_state.get("hp", 0)) / maxf(1.0, float(hero_state.get("max_hp", 1)))
			style_bonus = 9 if self_ratio < 0.55 else 5
	match role_group:
		"탱커":
			if telegraph:
				return mini(100, 100 + style_bonus)
			if float(hero_state.get("hp", 0)) / maxf(1.0, float(hero_state.get("max_hp", 1))) <= 0.35:
				return mini(100, 95 + style_bonus)
			if avg_hp < 0.58:
				return mini(100, 88 + style_bonus)
			if elite_count > 0 and alive_enemies >= 2:
				return mini(100, 74 + style_bonus)
			if is_raid:
				return mini(100, 62 + style_bonus)
			return mini(100, 30 + style_bonus)
		"서포터":
			if lowest_hp < 0.48:
				return mini(100, 100 + style_bonus)
			if injured >= 2 and avg_hp < 0.76:
				return mini(100, 88 + style_bonus)
			if telegraph and injured > 0:
				return mini(100, 82 + style_bonus)
			return mini(100, 28 + style_bonus)
		"컨트롤러":
			if telegraph:
				return mini(100, 100 + style_bonus)
			if elite_count > 0:
				return mini(100, 86 + style_bonus)
			if alive_enemies >= 4:
				return mini(100, 78 + style_bonus)
			if is_raid:
				return mini(100, 70 + style_bonus)
			return mini(100, 45 + style_bonus)
		_:
			if elite_count > 0:
				return mini(100, 88 + style_bonus)
			if alive_enemies >= 4:
				return mini(100, 78 + style_bonus)
			if is_raid and float(boss.get("boss_hp_ratio", 1.0)) > 0.10:
				return mini(100, 72 + style_bonus)
			if alive_enemies == 1 and float(enemies.get("lowest_hp", 1.0)) < 0.18:
				return mini(100, 20 + style_bonus)
			return mini(100, 52 + style_bonus)

func should_use_ultimate(role_group: String, hero_state: Dictionary, party: Dictionary, enemies: Dictionary, boss: Dictionary, profile: Dictionary = {}) -> bool:
	return ultimate_priority(role_group, hero_state, party, enemies, boss, profile) >= CAST_THRESHOLD
