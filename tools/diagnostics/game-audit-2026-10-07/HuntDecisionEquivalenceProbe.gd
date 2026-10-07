extends 'res://tests/regression/V27HeroRolesSmokeTest.gd'
## Compare live decision results against the pre-optimization scripts supplied
## by the runner. Timing is observational; correctness never depends on a PC.
const TARGET=preload('res://scripts/hunting/HuntingTargetDirector.gd')
const KITS=preload('res://scripts/heroes/HeroKitRuntime.gd')
const CATALOG=preload('res://scripts/heroes/HeroRosterCatalog.gd')
class Roam extends RefCounted:
	var enemy_positions: Array[Vector2]=[]
	func enemy_position(index: int) -> Vector2:return enemy_positions[index]
class TargetHost extends Node:
	var hero_battle_state: Dictionary={}
	var enemy_wave: Array=[]
	var positions: Dictionary={}
	var roaming_hunt:=Roam.new()
	func _hero_field_position(id: String) -> Vector2:return positions[id]
var observations: Dictionary={}
func _init() -> void:probe.call_deferred()
func _check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:failures.append(label)
func target_fixture(rng: RandomNumberGenerator) -> TargetHost:
	var host:=TargetHost.new()
	for i in 10:
		var id:='hero_'+str(i)
		host.positions[id]=Vector2(rng.randf_range(-3,3),rng.randf_range(-2,2))
		host.hero_battle_state[id]={'hp':rng.randi_range(1,100),'max_hp':100,'taunt':1.0 if rng.randf()<.15 else 0.0,'role_group':['탱커','딜러','서포터'][i%3],'row':['front','middle','rear'][i%3]}
	for i in 19:
		host.enemy_wave.append({'hp':0 if rng.randf()<.2 else 100,'target_id':'hero_'+str(rng.randi_range(0,11)),'hunt_target_lock':.5 if rng.randf()<.4 else 0.0,'archetype':['brute','assassin','ranged','support'][i%4]})
		host.roaming_hunt.enemy_positions.append(Vector2(rng.randf_range(-3,3),rng.randf_range(-2,2)))
	return host
func target_decisions(baseline) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=20261008
	var before_us:=0;var after_us:=0
	for sample in 200:
		var host:=target_fixture(rng)
		var candidates: Array=[]
		for id in host.hero_battle_state:
			if rng.randf()>.2:candidates.append(id)
		for index in host.enemy_wave.size():
			var original: Dictionary=host.enemy_wave[index].duplicate(true)
			var start:=Time.get_ticks_usec();var expected: String=baseline.select(host,index,candidates);before_us+=Time.get_ticks_usec()-start
			var old_lock: float=host.enemy_wave[index].get('hunt_target_lock',0)
			host.enemy_wave[index]=original
			start=Time.get_ticks_usec();var actual:=TARGET.select(host,index,candidates);after_us+=Time.get_ticks_usec()-start
			_check(actual==expected and old_lock==float(host.enemy_wave[index].get('hunt_target_lock',0)),'target decision '+str(sample)+':'+str(index))
			# Sequential decisions must observe the choice just committed.
			host.enemy_wave[index].target_id=actual
		host.free()
	observations.target={'checks':3800,'reference_ms':before_us/1000.0,'optimized_ms':after_us/1000.0}
func priorities(main,baseline) -> void:
	var before_us:=0;var after_us:=0;var evaluations:=0
	for faction in ['aurelia','noxfera']:
		var ids: Array=[]
		for hero in CATALOG.roster(faction):ids.append(hero.id)
		for offset in [0,5]:
			var party: Array=ids.slice(offset,offset+10)
			_prepare(main,party,faction,19)
			for i in party.size():main.party_movement.positions[party[i]]=Vector2(1.1+float(i)*.03,2)
			for scenario in 12:
				main.active_screen='raid' if scenario%2==1 else 'combat'
				main.raid_boss_hp=30 if scenario==1 else 100000;main.raid_boss_max_hp=100000
				main.raid_boss_attack=100;main.boss_telegraph_pending=scenario%3==0;main.boss_telegraph_remaining=.8
				for i in party.size():
					var state: Dictionary=main.hero_battle_state[party[i]]
					state.hp=int(state.max_hp*([1.0,.3,.65,.85][(i+scenario)%4]));state.ultimate=100 if scenario%4!=0 else 0
					state.guard=1 if scenario%3==1 else 0;state.shield=100 if scenario%3==2 else 0;state.shield_seconds=2 if scenario%3==2 else 0
					var runtime: Dictionary=main.hero_skill_runtime[party[i]]
					runtime.remaining=0 if scenario%4!=2 else 2;runtime.secondary_remaining=0 if scenario%4!=3 else 2
					runtime.kit_last_move_position=Vector2(-10,-10);runtime.kit_basic_count=10
				for i in main.enemy_wave.size():
					var enemy: Dictionary=main.enemy_wave[i]
					enemy.hp=0 if scenario==10 else (30 if scenario==8 else 10000)
					enemy.elite=scenario%3==0;enemy.target_id=party[i%party.size()]
					for status in ['stun_seconds','weaken_seconds','vulnerable_seconds']:enemy[status]=1 if scenario%3==2 else 0
				for id in party:
					for slot in ['a1','a2','ultimate']:
						var start:=Time.get_ticks_usec();var expected: int=baseline.priority(main,id,slot);before_us+=Time.get_ticks_usec()-start
						start=Time.get_ticks_usec();var actual:=KITS.priority(main,id,slot);after_us+=Time.get_ticks_usec()-start
						_check(actual==expected,'priority '+faction+':'+str(scenario)+':'+id+':'+slot);evaluations+=1
						var expected_profile: Dictionary=baseline.auto_profile(main,id,slot)
						var actual_profile:=KITS.auto_profile(main,id,slot)
						_check(expected_profile==actual_profile,'profile '+id+':'+slot)
	observations.priority={'checks':evaluations,'reference_ms':before_us/1000.0,'optimized_ms':after_us/1000.0}
func probe() -> void:
	var baseline_dir:=OS.get_environment('HUNT_DECISION_BASELINE')
	var old_target=load(baseline_dir+'/HuntingTargetDirector.gd')
	var old_kits=load(baseline_dir+'/HeroKitRuntime.gd')
	_check(old_target!=null and old_kits!=null,'baseline scripts load')
	if old_target==null or old_kits==null:quit(1);return
	target_decisions(old_target)
	var main=preload('res://scenes/Main.tscn').instantiate();main._offline_checked=true;root.add_child(main)
	await process_frame;main.set_process(false);main.set_physics_process(false)
	priorities(main,old_kits)
	if is_instance_valid(main.presentation_runtime):main.presentation_runtime.audio.shutdown()
	main.queue_free();old_target=null;old_kits=null
	for i in 5:await process_frame
	await create_timer(.4).timeout
	observations.checks=checks;observations.failures=failures
	print('HUNT_DECISION_EQUIVALENCE '+JSON.stringify(observations))
	quit(0 if failures.is_empty() else 1)
