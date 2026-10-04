extends "res://scripts/V83UpgradeTestBase.gd"
const MOVEMENT = preload("res://scripts/PartyMovementDirector.gd")
const INVASION = preload("res://scripts/InvasionHuntDirector.gd")
class BlockedNavigation extends RefCounted:
	func travel_distance(a: Vector2,b: Vector2) -> float: return a.distance_to(b)
	func is_walkable(_point: Vector2) -> bool: return true
	func has_clear_path(_a: Vector2,_b: Vector2) -> bool: return true
	func clamp_to_walkable(point: Vector2) -> Vector2: return point
	func move_toward(_key: String,start: Vector2,_goal: Vector2,_distance: float) -> Vector2: return start
func _init() -> void: run.call_deferred()

func spread(positions: Dictionary) -> float:
	var sum := 0.0; var pairs := 0
	var ids := positions.keys()
	for a in ids.size():
		for b in range(a + 1, ids.size()):
			sum += Vector2(positions[ids[a]]).distance_to(positions[ids[b]])
			pairs += 1
	return sum / maxf(1.0, pairs)

func movement_trial(main: Node, independent: bool) -> Dictionary:
	var director = MOVEMENT.new()
	director.independent_hunt = independent; director.holding_formation = not independent
	director.configure(main.deployed_heroes, main.hero_battle_state, Vector2(16,10))
	var enemies: Array = []; var points: Array[Vector2] = []; var returning: Array[bool] = []
	for i in 12:
		points.append(Vector2(16,10) + Vector2.from_angle(float(i) * TAU / 12.0) * 4.0)
		enemies.append({"hp":1000,"max_hp":1000,"row":0,"archetype":"brute"})
		returning.append(false)
	for step in 200: director.advance(.1, main.deployed_heroes, main.hero_battle_state, {}, Vector2(16,10), enemies, points, returning, true)
	var chosen: Dictionary = {}; var farthest := 0.0
	for id in director.positions:
		chosen[director.targets[id]] = true
		farthest = maxf(farthest, Vector2(director.positions[id]).distance_to(Vector2(16,10)))
	var result := {"spread":spread(director.positions),"targets":chosen.size(),"farthest":farthest}
	var before: Dictionary = director.positions.duplicate()
	director.advance(.5,main.deployed_heroes,main.hero_battle_state,{},Vector2(16,10),enemies,points,returning,true,true)
	check(director.positions == before,"pause freezes individual steering")
	return result

func run() -> void:
	var metrics: Array = []
	for faction in ["aurelia","noxfera"]:
		var main = await make_main(faction,10)
		main.idle_stage=1;main._build_combat_screen();await settle()
		check(main.party_movement.independent_hunt and not main.party_movement.holding_formation,faction+" ordinary hunt enables personal pursuit")
		var legacy := movement_trial(main,false); var individual := movement_trial(main,true)
		check(float(individual.spread)>float(legacy.spread)*1.3,faction+" ten heroes occupy more space than the constrained formation")
		check(int(individual.targets)>=4 and float(individual.farthest)>2.0,faction+" personal targets cover several directions")
		metrics.append({"faction":faction,"constrained":legacy,"individual":individual})
		var ids: Array = main._alive_hero_ids()
		for id in ids: main.hero_battle_state[id].taunt=0.0
		main.hero_battle_state[ids[-1]].taunt=2.0
		check(main._select_hero_target_for_enemy(0)==str(ids[-1]),faction+" taunt overrides distance and load")
		main.hero_battle_state[ids[-1]].taunt=0.0
		main.hero_battle_state[ids[-1]].hp=0
		check(main._select_hero_target_for_enemy(0)!=str(ids[-1]),faction+" dead heroes never retain monster aggro")
		main._build_combat_screen();await settle()
		var total_damage := 0; var diversity := 0
		for step in 900:
			var before: Dictionary = {}
			for id in main.hero_battle_state: before[id]=int(main.hero_battle_state[id].hp)
			main._advance_auto_hunt(.1)
			var monster_targets: Dictionary = {}
			for enemy in main.enemy_wave:
				if int(enemy.hp)>0 and not str(enemy.get("target_id","")).is_empty(): monster_targets[enemy.target_id]=true
			diversity=maxi(diversity,monster_targets.size())
			for id in before: total_damage+=maxi(0,int(before[id])-int(main.hero_battle_state.get(id,{}).get("hp",0)))
			if step%60==0:
				check(main._enemy_wave_alive_count()<=25 and main.invasion.groups.size()<=2,"normal combat preserves population caps")
				for id in main.party_movement.positions: check(main.field_navigation.is_walkable(main.party_movement.positions[id]),"individual heroes stay on walkable terrain")
				await process_frame
			if main.combat_hunt_cycle>=2: break
		check(main.combat_hunt_cycle>=2,faction+" natural combat clears multiple corps without forced kills")
		check(diversity>=3,faction+" monsters pursue several heroes")
		check(total_damage>0,faction+" separated monsters still reach and damage heroes")
		metrics[-1]["natural"]={"cycles":main.combat_hunt_cycle,"monster_targets":diversity,"hero_hp_removed":total_damage}
		await dispose(main)
	# Identical hero destinations get different physical approach slots.
	var invasion = INVASION.new()
	invasion.enemy_home_positions.assign([Vector2(26,9),Vector2(26,10),Vector2(26,11)])
	invasion.enemy_positions=invasion.enemy_home_positions.duplicate()
	invasion.target_hero_ids.assign(["hero","hero","hero"])
	var a: Vector2=invasion._approach_slot(0,Vector2(16,10),.68,[true,true,true])
	var b: Vector2=invasion._approach_slot(1,Vector2(16,10),.68,[true,true,true])
	check(a.distance_to(b)>.1 and a.distance_to(Vector2(16,10))<.92,"monster approach slots differ within real melee reach")
	var blocked = MOVEMENT.new();blocked.independent_hunt=true;blocked.field_navigation=BlockedNavigation.new()
	var heroes: Array=[{"id":"leonhardt"}]
	var states: Dictionary={"leonhardt":{"hp":100,"max_hp":100,"range":1,"row":"front","role_group":"탱커"}}
	blocked.configure(heroes,states,Vector2(16,10))
	var enemies: Array=[{"hp":100,"max_hp":100,"row":0,"archetype":"brute"},{"hp":100,"max_hp":100,"row":0,"archetype":"brute"}]
	var points: Array[Vector2]=[Vector2(20,10),Vector2(20,12)]
	blocked.advance(.1,heroes,states,{},Vector2(16,10),enemies,points,[false,false],true)
	var first: int=blocked.targets.leonhardt
	for step in 28:blocked.advance(.1,heroes,states,{},Vector2(16,10),enemies,points,[false,false],true)
	check(int(blocked.targets.leonhardt)!=first,"failed pursuit adapts by selecting a different nearby target")
	states.leonhardt.hp=0
	var before: Dictionary=blocked.positions.duplicate()
	blocked.advance(.5,heroes,states,{},Vector2(16,10),enemies,points,[false,false],true)
	check(blocked.positions==before and int(blocked.targets.leonhardt)==-1,"dead hero stays still and releases its reserved target")
	print("INDEPENDENT_HUNT_METRICS ",JSON.stringify(metrics))
	done("INDEPENDENT_HUNT")
