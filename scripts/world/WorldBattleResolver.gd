extends RefCounted
class_name WorldBattleResolver

const MAX_ROUNDS := 30
const REPORT_LOG_LIMIT := 16

func _clone_squad(source: Array) -> Array:
	var result: Array = []
	for entry in source:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = entry.duplicate(true)
		unit["max_hp"] = maxi(1, WorldWarState.safe_int(unit.get("max_hp", 100)))
		unit["hp"] = clampi(WorldWarState.safe_int(unit.get("hp", unit["max_hp"])), 0, int(unit["max_hp"]))
		unit["attack"] = maxi(1, WorldWarState.safe_int(unit.get("attack", 20)))
		unit["defense"] = maxi(0, WorldWarState.safe_int(unit.get("defense", 5)))
		unit["role"] = str(unit.get("role", "딜러"))
		unit["row"] = str(unit.get("row", "중열"))
		unit["name"] = str(unit.get("name", "병사"))
		result.append(unit)
	return result

func _alive_indices(squad: Array) -> Array[int]:
	var result: Array[int] = []
	for index in squad.size():
		if int(squad[index].get("hp", 0)) > 0:
			result.append(index)
	return result

func _lowest_hp_index(squad: Array) -> int:
	var best := -1
	var best_ratio := 2.0
	for index in _alive_indices(squad):
		var unit: Dictionary = squad[index]
		var ratio := float(unit["hp"]) / maxf(1.0, float(unit["max_hp"]))
		if ratio < best_ratio:
			best_ratio = ratio
			best = index
	return best

func _select_target(attacker: Dictionary, enemy: Array) -> int:
	var alive := _alive_indices(enemy)
	if alive.is_empty():
		return -1
	var role := str(attacker.get("role", "딜러"))
	if role == "암살자":
		for index in alive:
			var target: Dictionary = enemy[index]
			if str(target.get("row", "")) == "후열" or str(target.get("role", "")) == "서포터":
				return index
	for index in alive:
		if str(enemy[index].get("role", "")) == "탱커":
			return index
	for row in ["전열", "중열", "후열"]:
		for index in alive:
			if str(enemy[index].get("row", "")) == row:
				return index
	return alive[0]

func _attack_once(actor: Dictionary, enemy: Array, rng: RandomNumberGenerator) -> Dictionary:
	var target_index := _select_target(actor, enemy)
	if target_index < 0:
		return {"damage": 0, "target": ""}
	var target: Dictionary = enemy[target_index]
	var variance := rng.randf_range(0.90, 1.10)
	var raw := float(actor.get("attack", 20)) * variance
	var mitigation := float(target.get("defense", 0)) * 0.58
	var damage := maxi(1, int(round(raw - mitigation)))
	if str(actor.get("role", "")) == "컨트롤러":
		damage = int(round(float(damage) * 0.92))
	elif str(actor.get("role", "")) == "암살자" and str(target.get("row", "")) == "후열":
		damage = int(round(float(damage) * 1.18))
	# Reports describe HP actually removed, excluding damage beyond a kill.
	damage = mini(damage, int(target["hp"]))
	target["hp"] = maxi(0, int(target["hp"]) - damage)
	enemy[target_index] = target
	return {"damage": damage, "target": str(target.get("name", "")), "killed": int(target["hp"]) <= 0}

func _act_squad(acting: Array, enemy: Array, rng: RandomNumberGenerator, side_name: String, logs: Array[String]) -> Dictionary:
	var dealt := 0
	var healed := 0
	for index in _alive_indices(acting):
		if _alive_indices(enemy).is_empty():
			break
		var actor: Dictionary = acting[index]
		if str(actor.get("role", "")) == "서포터":
			var heal_index := _lowest_hp_index(acting)
			if heal_index >= 0:
				var target: Dictionary = acting[heal_index]
				if int(target["hp"]) < int(target["max_hp"]):
					var amount := maxi(1, int(round(float(actor.get("attack", 20)) * 0.72)))
					var actual := mini(amount, int(target["max_hp"]) - int(target["hp"]))
					target["hp"] = int(target["hp"]) + actual
					acting[heal_index] = target
					healed += actual
					if logs.size() < REPORT_LOG_LIMIT:
						logs.append("%s %s → %s 회복 +%d" % [side_name, actor["name"], target["name"], actual])
					continue
		var result := _attack_once(actor, enemy, rng)
		dealt += int(result.get("damage", 0))
		if logs.size() < REPORT_LOG_LIMIT and int(result.get("damage", 0)) > 0:
			logs.append("%s %s → %s %d 피해%s" % [
				side_name,
				actor["name"],
				str(result.get("target", "")),
				int(result.get("damage", 0)),
				" · 격파" if bool(result.get("killed", false)) else ""
			])
	return {"damage": dealt, "healed": healed}

func _survivor_hp(squad: Array) -> int:
	var total := 0
	for unit in squad:
		total += maxi(0, int(unit.get("hp", 0)))
	return total

func _apply_attacker_fatigue(squad: Array, fatigue: int) -> void:
	var penalty := minf(0.30, float(clampi(fatigue, 0, 100)) * 0.003)
	var multiplier := 1.0 - penalty
	for index in squad.size():
		var unit: Dictionary = squad[index]
		unit["_base_attack"] = int(unit["attack"])
		unit["_base_max_hp"] = int(unit["max_hp"])
		var hp_ratio := float(unit["hp"]) / float(unit["max_hp"])
		unit["attack"] = maxi(1, int(round(float(unit["attack"]) * multiplier)))
		unit["max_hp"] = maxi(1, int(round(float(unit["max_hp"]) * multiplier)))
		unit["hp"] = int(ceil(float(unit["max_hp"]) * hp_ratio))
		squad[index] = unit

func _apply_defense_bonus(squad: Array, defense_multiplier: float) -> void:
	for index in squad.size():
		var unit: Dictionary = squad[index]
		unit["_base_defense"] = int(unit["defense"])
		unit["_base_max_hp"] = int(unit["max_hp"])
		var hp_ratio := float(unit["hp"]) / float(unit["max_hp"])
		unit["defense"] = maxi(0, int(round(float(unit["defense"]) * clampf(defense_multiplier, 0.1, 3.0))))
		unit["max_hp"] = maxi(1, int(round(float(unit["max_hp"]) * maxf(0.1, 1.0 + (defense_multiplier - 1.0) * 0.45))))
		unit["hp"] = int(ceil(float(unit["max_hp"]) * hp_ratio))
		squad[index] = unit

func _restore_base_stats(squad: Array) -> void:
	# Combat modifiers are transient. Retain wounds, never stack bonuses or heal
	# damaged defenders when a second attack or rally wave arrives.
	for unit in squad:
		var hp_ratio := float(unit["hp"]) / float(unit["max_hp"])
		unit["max_hp"] = int(unit.get("_base_max_hp", unit["max_hp"]))
		unit["attack"] = int(unit.get("_base_attack", unit["attack"]))
		unit["defense"] = int(unit.get("_base_defense", unit["defense"]))
		unit["hp"] = clampi(int(ceil(float(unit["max_hp"]) * hp_ratio)), 0, int(unit["max_hp"]))
		unit.erase("_base_max_hp")
		unit.erase("_base_attack")
		unit.erase("_base_defense")

# Shared, read-only modifier path. Does not consume RNG, mutate sources or heal
# wounds. Scouting and each real exchange now use exactly the same rounding.
func preview_combatants(attacker_source: Array, defender_source: Array, fatigue: int, defense_multiplier: float = 1.0, stance: String = "balanced") -> Dictionary:
	var attacker: Array = _clone_squad(attacker_source)
	var defender: Array = _clone_squad(defender_source)
	_apply_attacker_fatigue(attacker, fatigue)
	_apply_stance(attacker, stance)
	_apply_defense_bonus(defender, defense_multiplier)
	return {"attacker": attacker, "defender": defender}

func resolve(attacker_source: Array, defender_source: Array, attacker_fatigue: int, defender_defense_multiplier := 1.0, seed := 1, attacker_stance: String = "balanced") -> Dictionary:
	var prepared: Dictionary = preview_combatants(attacker_source, defender_source, attacker_fatigue, defender_defense_multiplier, attacker_stance)
	var attacker: Array = prepared["attacker"]
	var defender: Array = prepared["defender"]
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, seed)
	var logs: Array[String] = []
	var attacker_damage := 0
	var defender_damage := 0
	var rounds := 0
	var timeline: Array=[]
	for round_index in MAX_ROUNDS:
		rounds = round_index + 1
		var a := _act_squad(attacker, defender, rng, "공격", logs)
		attacker_damage += int(a.get("damage", 0))
		if _alive_indices(defender).is_empty():
			timeline.append({"round":rounds,"attacker_hp":_survivor_hp(attacker),"defender_hp":0,"attacker_damage":a["damage"],"defender_damage":0})
			break
		var d := _act_squad(defender, attacker, rng, "수비", logs)
		defender_damage += int(d.get("damage", 0))
		timeline.append({"round":rounds,"attacker_hp":_survivor_hp(attacker),"defender_hp":_survivor_hp(defender),"attacker_damage":a["damage"],"defender_damage":d["damage"]})
		if _alive_indices(attacker).is_empty():
			break
	var attacker_alive := _alive_indices(attacker).size()
	var defender_alive := _alive_indices(defender).size()
	var attacker_hp := _survivor_hp(attacker)
	var defender_hp := _survivor_hp(defender)
	var victory := false
	if defender_alive == 0 and attacker_alive > 0:
		victory = true
	elif attacker_alive > 0 and defender_alive > 0 and rounds >= MAX_ROUNDS:
		victory = attacker_hp > defender_hp
	_restore_base_stats(attacker)
	_restore_base_stats(defender)
	return {
		"victory": victory,
		"rounds": rounds,
		"stance": attacker_stance,
		"timeline": timeline,
		"attacker_alive": attacker_alive,
		"defender_alive": defender_alive,
		"attacker_hp": attacker_hp,
		"defender_hp": defender_hp,
		"attacker_damage": attacker_damage,
		"defender_damage": defender_damage,
		"logs": logs,
		"attacker_units": attacker,
		"defender_units": defender
	}

func make_garrison(defender_faction: String, tile: Vector2i, tile_type: String, power_hint: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, (tile.x + 11) * 1009 + (tile.y + 23) * 917 + (1 if defender_faction == WorldWarState.FACTION_AURELIA else 2) * 7919)
	var roles := ["탱커", "딜러", "딜러", "서포터", "컨트롤러", "딜러", "암살자", "딜러", "서포터", "딜러"]
	var rows := ["전열", "전열", "중열", "후열", "중열", "중열", "후열", "후열", "후열", "중열"]
	var landmark_mult := 1.0
	if tile_type == "fort":
		landmark_mult = 1.12
	elif tile_type == "citadel":
		landmark_mult = 1.18
	elif tile_type == "capital":
		landmark_mult = 1.30
	var per_unit_power := maxf(55.0, float(maxi(600, power_hint)) / 20.0)
	var squad: Array = []
	for index in 10:
		var role: String = str(roles[index])
		var hp_mult := 1.0
		var attack_mult := 1.0
		var defense_bonus := 0
		if role == "탱커":
			hp_mult = 1.45
			attack_mult = 0.75
			defense_bonus = 12
		elif role == "서포터":
			hp_mult = 1.05
			attack_mult = 0.82
			defense_bonus = 4
		elif role == "암살자":
			hp_mult = 0.90
			attack_mult = 1.25
		var max_hp := int((250.0 + per_unit_power * 2.8) * hp_mult * landmark_mult * rng.randf_range(0.95, 1.05))
		var attack := int((18.0 + per_unit_power * 0.34) * attack_mult * landmark_mult * rng.randf_range(0.95, 1.05))
		var defense := int(5.0 + per_unit_power * 0.055) + defense_bonus
		squad.append({
			"id": "garrison_%d" % index,
			"name": "%s 수비대 %02d" % ["아우렐리아" if defender_faction == WorldWarState.FACTION_AURELIA else "녹스페라", index + 1],
			"role": role,
			"row": rows[index],
			"max_hp": max_hp,
			"hp": max_hp,
			"attack": attack,
			"defense": defense
		})
	return squad

func _apply_stance(squad: Array, stance: String) -> void:
	var attack_mult:=1.15 if stance=='assault' else (.9 if stance=='guard' else 1.0)
	var defense_mult:=.85 if stance=='assault' else (1.2 if stance=='guard' else 1.0)
	for unit in squad:
		unit['_base_defense']=unit['defense']
		unit['attack']=maxi(1,int(round(unit['attack']*attack_mult)))
		unit['defense']=maxi(0,int(round(unit['defense']*defense_mult)))
