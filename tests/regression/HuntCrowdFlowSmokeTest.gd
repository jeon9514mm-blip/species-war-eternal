extends 'res://tests/support/V83UpgradeTestBase.gd'
const BODY=preload('res://scripts/hunting/HuntBodyCollision.gd')
const LAYOUT=preload('res://scripts/maps3d/HeroCircleFormation.gd')
class FlowHost extends 'res://tests/support/V83GameplayBattleHost.gd':
	var releases: Dictionary={}
	var ordinary_healing:=0
	func _notify_hunt_frame_release(index: int,hero: bool,action: String,windup: float) -> void:
		if hero and index>=0 and index<deployed_heroes.size():
			var id: String=deployed_heroes[index].id
			releases[id]=int(releases.get(id,0))+1
		super._notify_hunt_frame_release(index,hero,action,windup)
	func _heal_hero(id: String,amount: int) -> int:
		var actual: int=super._heal_hero(id,amount)
		ordinary_healing+=actual
		return actual
class CornerNavigation extends 'res://scripts/hunting/MeadowNavigation.gd':
	const LOW=Vector2(.35,.35)
	const HIGH=Vector2(3.6,4.8)
	func is_walkable(point: Vector2) -> bool:return point==point.clamp(LOW,HIGH)
	func has_clear_path(start: Vector2,end: Vector2) -> bool:return is_walkable(start) and is_walkable(end)
	func clamp_to_walkable(point: Vector2) -> Vector2:return point.clamp(LOW,HIGH)
func _init() -> void:run.call_deferred()
func flow_main(faction: String,zone: String,formation: String):
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	var main:=FlowHost.new();main.save_state_path='user://crowd-flow-'+str(Time.get_ticks_usec())+'.json';main._offline_checked=true
	root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await settle()
	main.set_process(false);main.set_physics_process(false)
	main.selected_faction=faction;main.current_zone_id=zone;main.idle_stage=154;main.party_slot_legacy_cap=10;main.formation_id=formation
	var ids: Array[String]=[]
	for hero: Dictionary in ROSTER.roster(faction).slice(0,10):ids.append(hero.id)
	main._restore_deployed_heroes(ids)
	for id in ids:main.hero_progress[id]={'level':60,'xp':0}
	main.combat_effects_enabled=false;main.combat_fx.enabled=false;main.sound_effects_enabled=false;main.battle_speed=1;main.skill_auto=true;main.ultimate_auto=true
	main._build_combat_screen();await settle()
	main.combat_labels.terrain.set_process(false)
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	# Ordinary injured-party fixture makes healing measurable without forcing a cast.
	for state: Dictionary in main.hero_battle_state.values():state.hp=roundi(state.max_hp*.68)
	main._sync_party_hp_from_heroes();main.combat_running=true
	return main
func run() -> void:
	var metrics: Array=[];var choices: Array=['balanced','assault','bulwark','volley'];var serial:=0
	for faction: String in ['aurelia','noxfera']:
		for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
			var choice: String=choices[serial%choices.size()];serial+=1
			var main=await flow_main(faction,zone,choice)
			check(main.field_navigation.zone_id==zone and main.current_zone_id==zone,'real zone routing '+faction+zone)
			var overlap_frames:=0;var caps:=true;var walkable:=true;var min_alive:=10;var used_targets: Dictionary={};var entrances: Dictionary={}
			for tick in 1200:
				main._advance_auto_hunt(.1)
				var bodies: Array[Dictionary]=BODY.actors(main)
				if tick>=20 and not BODY.clear(bodies):overlap_frames+=1
				min_alive=mini(min_alive,main._alive_hero_ids().size())
				caps=caps and main._enemy_wave_alive_count()<=25 and main.invasion.groups.size()<=2
				for body in bodies:walkable=walkable and main.field_navigation.is_walkable(body.position)
				for enemy: Dictionary in main.enemy_wave:
					entrances[str(enemy.get('entry_side',''))]=true
					if int(enemy.hp)>0 and not str(enemy.get('target_id','')).is_empty():used_targets[enemy.target_id]=true
				if tick%100==0:await process_frame
			check(overlap_frames==0,'natural combat retains all-team body clearance '+faction+zone+choice)
			check(caps and walkable,'natural movement preserves population and terrain bounds '+faction+zone+choice)
			check(min_alive==10,'ten living heroes stay in the measured flow '+faction+zone+choice)
			check(main.combat_hunt_cycle>=4,'formation does not stall corps progression '+faction+zone+choice)
			check(entrances.has('west'),'real west entrance reaches the natural formation flow '+faction+zone+choice)
			for id in main._deployed_hero_ids():check(int(main.releases.get(id,0))>0,'each hero executes a real attack or support action '+faction+zone+id)
			check(main.ordinary_healing>0,'injured party still receives real healing '+faction+zone+choice)
			metrics.append({'faction':faction,'zone':zone,'formation':choice,'seconds':120,'overlap_frames':overlap_frames,'minimum_living_heroes':min_alive,'corps_cleared':main.combat_hunt_cycle,'heroes_with_actions':main.releases.size(),'actions':main.releases.duplicate(),'healing':main.ordinary_healing,'enemy_target_heroes':used_targets.size(),'entrances':entrances.keys()})
			# Ten originals in a narrow corner: a fixed caster remains an obstacle,
			# nearby walking proposals yield without a whole-party rollback or jump.
			main.combat_running=false
			for enemy: Dictionary in main.enemy_wave:enemy.hp=0
			for runtime: Dictionary in main.hero_skill_runtime.values():runtime.windup=-1.0
			main.expedition_position=Vector2(1.5,1.9);main.roaming_hunt.party_position=main.expedition_position
			main.party_movement.formation_facing=Vector2.RIGHT;main.party_movement.formation_threat=-1
			main.formation_id='balanced';main.party_movement.apply_formation(main.deployed_heroes,'balanced')
			main.field_navigation=CornerNavigation.new();main.party_movement.field_navigation=main.field_navigation
			LAYOUT.hunt(main,main.combat_labels.terrain,true)
			var ids: Array=main._deployed_hero_ids();var fixed: String=ids[0];var walker: String=ids[1]
			main.hero_skill_runtime[fixed].windup=1.0
			var fixed_point: Vector2=main._hero_field_position(fixed);var nearest:=INF
			for id in ids:
				if id==fixed:continue
				var distance:=BODY.body_distance(fixed_point,main._hero_field_position(id))
				if distance<nearest:walker=id;nearest=distance
			var edge_clear:=BODY.clear(BODY.actors(main));var edge_safe:=true;var edge_fixed:=true;var max_shift:=0.0
			for tick in 80:
				var previous: Array[Dictionary]=BODY.actors(main)
				var before: Dictionary=main.party_movement.positions.duplicate()
				var point: Vector2=main.party_movement.positions[walker]
				main.party_movement.positions[walker]=point+(fixed_point-point).normalized()*.06
				BODY.resolve(main,[.025,.05,.1][tick%3],previous)
				edge_clear=edge_clear and BODY.clear(BODY.actors(main))
				edge_fixed=edge_fixed and main._hero_field_position(fixed)==fixed_point
				for id in ids:
					var current: Vector2=main.party_movement.positions[id]
					edge_safe=edge_safe and current.is_finite() and main.field_navigation.is_walkable(current)
					max_shift=maxf(max_shift,current.distance_to(before[id]))
			check(edge_clear and edge_safe and edge_fixed,'narrow corner yields to committed caster without overlap '+faction+zone)
			check(max_shift<.15,'corner correction stays local instead of jumping actors '+faction+zone)
			metrics[-1].corner_max_world_shift=max_shift
			await dispose(main)
	print('HUNT_CROWD_FLOW_METRICS ',JSON.stringify(metrics))
	done('HUNT_CROWD_FLOW')
