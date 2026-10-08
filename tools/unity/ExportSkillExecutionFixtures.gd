extends SceneTree
## Executes the original production HeroKitRuntime in an isolated adapter.
## Never creates Main, reads player saves, grants wallet rewards, or runs a scene.
const KITS = preload("res://scripts/heroes/HeroKitRuntime.gd")
const ROSTER = preload("res://scripts/heroes/HeroRosterCatalog.gd")
const RULES = preload("res://scripts/heroes/HeroCombatRules.gd")
class Roam extends RefCounted:
	func is_returning(_index: int) -> bool: return false
class Adapter extends Node:
	var hero_identity_catalog = preload("res://scripts/heroes/HeroIdentityCatalog.gd").new()
	var combat_decisions = preload("res://scripts/combat/CombatDecisionEngine.gd").new()
	var hero_battle_state := {}
	var hero_skill_runtime := {}
	var enemy_wave := []
	var active_screen := "combat"
	var challenge_session = null
	var party_movement := {"independent_hunt":false}
	var roaming_hunt = Roam.new()
	var hunt_ai := {"encounter_id":1}
	var raid_encounter_serial := 1
	var raid_boss_hp := 10000
	var raid_boss_max_hp := 10000
	var raid_boss_attack := 100
	var boss_telegraph_pending := false
	var _stun_seconds := 0.0
	var _weaken_seconds := 0.0
	var _vulnerable_seconds := 0.0
	var skill_event_text := ""
	func setup(id: String, scenario: int) -> void:
		for i in 4:
			var aid := id if i == 0 else "fixture_ally_%d" % i
			hero_battle_state[aid] = {"hp":450 if i==0 else 350+i*100,"max_hp":1000,"attack":200,"defense":10,"slot":i,"range":3,"row":"front" if i<2 else "rear","role_group":ROSTER.HEROES[id].role_group if i==0 else "딜러","ai_style":"balanced","ultimate":100.0,"guard":1.0 if scenario==2 else 0.0,"taunt":0.0,"shield":0,"shield_seconds":0.0,"alive":true}
			if scenario==1: hero_battle_state[aid].hp=1000
		hero_skill_runtime[id]={"remaining":0.0,"secondary_remaining":0.0,"passive_remaining":0.0,"kit_last_move_position":Vector2(-1,0),"kit_basic_count":3,"kit_last_move_basic":0}
		for i in 3:
			enemy_wave.append({"hp":1000 if scenario!=2 else (1 if i==0 else 350),"max_hp":1000,"attack":80,"row":0,"archetype":"brute","elite":i==2,"alive":true,"target_id":id,"stun_seconds":0.0,"weaken_seconds":1.0 if scenario==2 else 0.0,"vulnerable_seconds":0.0})
	func _get_skill_tree(_id: String) -> Dictionary: return {"utility":0}
	func _alive_hero_ids() -> Array[String]:
		var ids: Array[String]=[]
		for id in hero_battle_state:
			if hero_battle_state[id].hp>0: ids.append(id)
		return ids
	func _lowest_hp_hero_id() -> String:
		var ids:=_alive_hero_ids()
		ids.sort_custom(func(a,b):return float(hero_battle_state[a].hp)/hero_battle_state[a].max_hp<float(hero_battle_state[b].hp)/hero_battle_state[b].max_hp)
		return ids[0] if not ids.is_empty() else ""
	func _select_enemy_target(id: String) -> int: return combat_decisions.select_enemy_target(hero_battle_state[id],enemy_wave,_combat_enemy_distances(id))
	func _combat_enemy_distances(_id: String) -> Array: return [0.0,0.0,0.0]
	func _enemy_wave_alive_count() -> int: return enemy_wave.filter(func(e):return e.hp>0).size()
	func _can_attack_enemy(_id: String,index: int) -> bool: return index>=0 and index<enemy_wave.size() and enemy_wave[index].hp>0
	func _hero_field_position(_id: String) -> Vector2: return Vector2.ZERO
	func _hero_skill_enemy_targets(id: String,target: int,p: Dictionary) -> Array[int]:
		var result: Array[int]=combat_decisions.rank_skill_targets(hero_battle_state[id],enemy_wave,p,_combat_enemy_distances(id))
		if result.has(target):result.erase(target);result.push_front(target)
		result.resize(mini(result.size(),maxi(1,int(p.get("max_targets",enemy_wave.size()))) if p.get("aoe",false) else 1))
		return result
	func _ultimate_ready(id: String) -> bool: return hero_battle_state[id].ultimate>=100
	func _raid_control_window() -> bool: return true
	func _raid_apply_control(duration: float,_id: String) -> void: _stun_seconds=maxf(_stun_seconds,duration)
	func _apply_enemy_status(index: int,kind: String,duration: float) -> void:
		preload("res://scripts/combat/CombatStatusRules.gd").apply(enemy_wave[index],kind,duration)
	func _gain_ultimate(id: String,amount: float) -> void:
		hero_battle_state[id].ultimate=clampf(hero_battle_state[id].ultimate+amount*hero_identity_catalog.profile(id).ult_gain_mult,0,100)
	func _heal_hero(id: String,amount: int) -> int:
		if id.is_empty() or hero_battle_state[id].hp<=0:return 0
		var actual:=mini(hero_battle_state[id].max_hp-hero_battle_state[id].hp,maxi(0,amount))
		hero_battle_state[id].hp+=actual
		return actual
	func _perform_hero_healing(p: Dictionary,_visual: Array,_source: String) -> void:
		for id in RULES.healing_targets(p,hero_battle_state,_alive_hero_ids()):_heal_hero(id,RULES.heal_amount(p,hero_battle_state[id]))
	func _perform_hero_guard(id: String,p: Dictionary) -> void:
		var duration:=float(p.get("duration",2.4))
		if p.get("guard_scope","self")=="party":
			for aid in _alive_hero_ids():hero_battle_state[aid].guard=maxf(hero_battle_state[aid].guard,duration)
		else:
			hero_battle_state[id].guard=maxf(hero_battle_state[id].guard,duration)
			hero_battle_state[id].taunt=maxf(hero_battle_state[id].taunt,duration+.8)
		if p.get("self_heal",0)>0:_heal_hero(id,int(hero_battle_state[id].max_hp*p.self_heal))
	func _damage_enemy(index: int,raw: int,_slot: int) -> int:
		if not _can_attack_enemy("",index) or raw<=0:return 0
		var actual:=int(minf(enemy_wave[index].hp,raw*(1.25 if enemy_wave[index].vulnerable_seconds>0 else 1.0)))
		enemy_wave[index].hp-=actual
		return actual
	func _hero_short_name(id: String) -> String: return id
	func _sync_party_hp_from_heroes() -> void: pass
	func _emit_skill_cast_fx(_id,_target,_area,_profile,_ultimate) -> void: pass
	func _emit_ultimate_cutin(_id,_name) -> void: pass
	func _emit_passive_proc_fx(_id,_target,_profile,_lowest) -> void: pass

func _initialize() -> void:
	var cases:=[]
	for id in ROSTER.HEROES:
		for slot in ["a1","a2","ultimate"]:
			for scenario in 3:
				var main:=Adapter.new();main.setup(id,scenario)
				var can:=KITS.can_use(main,id,slot)
				var damage:=KITS.cast(main,id,slot,0)
				cases.append({"hero":id,"slot":slot,"scenario":scenario,"can_use":can,"damage":damage,"heroes":main.hero_battle_state,"enemies":main.enemy_wave,"runtime":main.hero_skill_runtime[id]})
				main.free()
	var path:="res://Unity/Assets/Game/Resources/Eternal/skill-execution-fixtures.json"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:push_error("Cannot write skill execution fixtures");quit(1);return
	file.store_string(JSON.stringify({"schema":1,"source":"HeroKitRuntime.cast and event production functions; isolated state only","cases":cases},"  "));file.close()
	print("UNITY_SKILL_EXECUTION_EXPORT_OK: ",cases.size()," active cast scenarios using original production runtime")
	quit(0)
