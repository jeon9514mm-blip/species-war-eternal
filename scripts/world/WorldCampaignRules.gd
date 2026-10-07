extends RefCounted
class_name WorldCampaignRules
## Read-only campaign intelligence shared by scouting and authoritative battles.
const STANCES := ['balanced','assault','guard']
static func stance_name(id: String) -> String:
	return {'balanced':'균형','assault':'강습','guard':'신중'}.get(id,'균형')
static func stance_description(id: String) -> String:
	return {'balanced':'공격·방어 기본 능력 유지','assault':'공격 +15% · 방어 -15%','guard':'공격 -10% · 방어 +20%'}.get(id,'공격·방어 기본 능력 유지')
static func neutral_guardians(world: WorldWarState, cell: Vector2i) -> Array:
	var level:=world.neutral_guard_level(cell)
	if level<=0:return []
	var existing:=world.garrison_at(cell)
	if not existing.is_empty():return existing
	var squad:=WorldBattleResolver.new().make_garrison('neutral',cell,world.tile_type(cell),600+level*350)
	var count:=mini(10,2+level*2)
	squad=squad.slice(0,count)
	for index in squad.size():
		squad[index]['id']='militia_%d_%d_%d'%[cell.x,cell.y,index]
		squad[index]['name']='Lv.%d 영토 수비대 %d'%[level,index+1]
	return squad
static func strength(squad: Array) -> int:
	var result:=0.0
	for unit in squad:
		if not unit is Dictionary or float(unit.get('hp',0))<=0:continue
		var hp:=float(unit.get('hp',0))
		var fraction:=hp/maxf(1,float(unit.get('max_hp',1)))
		result+=hp*.12+(float(unit.get('attack',0))*4.0+float(unit.get('defense',0))*2.0)*fraction
	return int(round(result))
static func terrain_defense(world: WorldWarState, cell: Vector2i) -> float:
	return {'forest':1.08,'hills':1.12,'fort':1.18,'citadel':1.24,'mine':1.05,'forest_resource':1.08,'ruins':1.10}.get(world.tile_type(cell),1.0)
static func scout(world: WorldWarState, conflict: WorldConflictState, cell: Vector2i, power: int, attackers: Array) -> Dictionary:
	if not world.in_bounds(cell):return {}
	var defenders: Array=[]
	var owner:=world.tile_owner(cell)
	var forces:=0
	if owner==WorldWarState.FACTION_NEUTRAL:
		defenders=neutral_guardians(world,cell)
		forces=1 if not defenders.is_empty() else 0
	elif owner!=world.faction:
		var stationed:=conflict.garrisons_at(cell)
		if stationed.is_empty():
			var legacy:=world.garrison_at(cell)
			if not legacy.is_empty():defenders=legacy;forces=1
			else:
				forces=mini(conflict.capacity_at(world,cell),conflict._seed_count_for_tile(world.tile_type(cell)))
				for index in forces:
					defenders.append_array(WorldBattleResolver.new().make_garrison(owner,cell+Vector2i(index,index*2),world.tile_type(cell),int(maxi(700,power)*(.82+index*.08))))
		else:
			forces=stationed.size()
			for force in stationed:defenders.append_array(force.get('squad',[]))
	else:
		var stationed:=conflict.garrisons_at(cell)
		forces=stationed.size()
		for force in stationed:defenders.append_array(force.get('squad',[]))
		if stationed.is_empty():
			defenders=world.garrison_at(cell)
			forces=1 if not defenders.is_empty() else 0
	var wounded: Array = wounded_party(world, attackers)
	var terrain: float = terrain_defense(world, cell)
	if owner == world.enemy_faction():
		terrain = WorldSupplyNetwork.new().tile_defense_multiplier(world, cell, owner) * float(world.faction_balance_buff(owner)["defense_multiplier"])
	var prepared: Dictionary = WorldBattleResolver.new().preview_combatants(wounded, defenders, world.army_fatigue, terrain, world.battle_stance)
	var attack_strength: int = strength(prepared["attacker"])
	var defense_strength: int = strength(prepared["defender"])
	var ratio: float = float(attack_strength) / maxf(1.0, float(defense_strength))
	var risk: String = "우세" if ratio >= 1.35 else ("접전" if ratio >= 0.85 else "위험")
	if defense_strength == 0: risk = "교전 없음"
	if owner == world.faction: risk = "아군 영토"
	return {"defenders": defenders, "forces": forces, "attacker_strength": attack_strength,
		"defender_strength": defense_strength, "risk": risk, "terrain_defense": terrain,
		"guard_level": world.neutral_guard_level(cell), "stance": world.battle_stance,
		"attacker_preview": prepared["attacker"], "defender_preview": prepared["defender"]}

static func wounded_party(world: WorldWarState, source: Array) -> Array:
	var result: Array = WorldBattleResolver.new()._clone_squad(source)
	for unit in result:
		var ratio: float = clampf(float(world.army_wounds.get(str(unit.get("id", "")), 1.0)), 0.0, 1.0)
		unit["hp"] = int(ceil(float(unit["max_hp"]) * ratio))
	return result

# Pure shared admission check. Authority calls it again after logistics update.
# Friendly moves/retreat remain available to a wounded or exhausted army.
static func march_check(world: WorldWarState, march: WorldMarchState, supply: WorldSupplyNetwork, target: Vector2i, squad: Array, season_active: bool = true, already_wounded: bool = false) -> Dictionary:
	if world == null or march == null or supply == null: return {"ok": false, "reason": "월드 상태 없음", "plan": {}}
	if march.active: return {"ok": false, "reason": "이미 행군 중", "plan": {}}
	var plan: Dictionary = march.plan(world, target)
	var reason: String = ""
	var conquering: bool = str(plan.get("action", "")) in ["attack_enemy", "capture_neutral"]
	var ready: bool = false
	var units: Array = squad if already_wounded else wounded_party(world, squad)
	for unit in units:
		if unit is Dictionary and int(unit.get("hp", 0)) > 0: ready = true
	if plan.is_empty(): reason = "행군 경로 없음"
	elif conquering and not season_active: reason = "시즌 정산 중"
	elif conquering and (world.tile_owner(target) == world.enemy_faction() or world.neutral_guard_level(target) > 0) and not world.can_launch_combat(): reason = "피로 한도"
	elif conquering and not ready: reason = "부상 회복 필요"
	elif conquering and not supply.is_supply_connected(world, world.army_position, world.faction): reason = "보급 단절"
	elif world.rations < int(plan["ration_cost"]): reason = "군량 부족"
	return {"ok": reason.is_empty(), "reason": reason, "plan": plan}

static func preparation_snapshot(world: WorldWarState, conflict: WorldConflictState, march: WorldMarchState, target: Vector2i, power: int, squad: Array) -> Dictionary:
	# Do not include resource regeneration. Cost/affordability is revalidated
	# at confirmation; changing tactics, wounds, routes or defenders needs review.
	var info: Dictionary = scout(world, conflict, target, power, squad)
	return {"faction": world.faction, "origin": world.army_position, "target": target,
		"owner": world.tile_owner(target), "stance": world.battle_stance, "fatigue": world.army_fatigue,
		"party": wounded_party(world, squad), "plan": march.plan(world, target),
		"defenders": info.get("defenders", []).duplicate(true), "defense": info.get("terrain_defense", 1.0)}

static func supply_links_after_capture(world: WorldWarState, target: Vector2i, connected: Dictionary) -> int:
	# Hypothetical one-tile connection. Never writes an owner or world snapshot.
	var visited: Dictionary = {world._key(target): true}
	var queue: Array[Vector2i] = [target]
	var count: int = 0
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for next in world.neighbors(current):
			var key: String = world._key(next)
			if visited.has(key) or connected.has(key) or world.tile_owner(next) != world.faction: continue
			visited[key] = true; queue.append(next); count += 1
	return count

static func recommend(world: WorldWarState, march: WorldMarchState, supply: WorldSupplyNetwork, squad: Array, purpose: String = "nearby", season_active: bool = true) -> Dictionary:
	if world == null or march == null or march.active or purpose not in ["nearby", "resources", "supply", "forts"]: return {}
	var best: Dictionary = {}
	var seen: Dictionary = {}
	var connected: Dictionary = supply.connected_keys(world, world.faction)
	for key in connected:
		var pair: PackedStringArray = str(key).split(":")
		for cell in world.neighbors(Vector2i(int(pair[0]), int(pair[1]))):
			if seen.has(cell) or world.tile_owner(cell) == world.faction: continue
			seen[cell] = true
			var check: Dictionary = march_check(world, march, supply, cell, squad, season_active)
			if not bool(check["ok"]): continue
			var kind: String = world.tile_type(cell)
			var links: int = supply_links_after_capture(world, cell, connected)
			if purpose == "resources" and kind not in ["mine", "forest_resource", "ruins"]: continue
			if purpose == "forts" and kind not in ["fort", "citadel"]: continue
			if purpose == "supply" and links == 0: continue
			var plan: Dictionary = check["plan"]
			var score: float = float(plan["distance"]) * 10.0 + (1000.0 if world.tile_owner(cell) == world.enemy_faction() else 0.0)
			if purpose == "supply": score -= float(links) * 100.0
			if purpose == "nearby" and kind in ["mine", "forest_resource", "ruins"]: score -= 6.0
			if best.is_empty() or score < float(best["score"]):
				var why: String = {"nearby": "가까운 개척 목표", "resources": "자원 생산 영토", "supply": "고립 아군 영토 %d칸 보급 연결" % links, "forts": "성곽 거점 공략"}[purpose]
				best = {"target": cell, "score": score, "purpose": purpose, "reason": why,
					"distance": plan["distance"], "cost": plan["ration_cost"], "reconnected": links}
	return best
