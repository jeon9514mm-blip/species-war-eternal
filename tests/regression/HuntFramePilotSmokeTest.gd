extends 'res://tests/support/V83UpgradeTestBase.gd'
const CLOCK=preload('res://scripts/art/HuntFrameTimeline.gd')
const CATALOG=preload('res://scripts/art/HuntFrameCatalog.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var clock=CLOCK.new()
	var sample: Dictionary=clock.sample({'windup':.075,'attack_windup_duration':.15,'visual_action':'attack_1'},false,false,.033,true)
	check(is_equal_approx(float(sample.time)/float(sample.duration),.22),'preparation follows remaining simulation windup')
	check(CATALOG.attack_frame(.4399)==2 and CATALOG.attack_frame(.44)==3,'painted impact cannot appear before the actual release phase')
	var clock30=CLOCK.new();var frames30: Dictionary={}
	for tick in 5:
		var prepare30: Dictionary=clock30.sample({'windup':.15-float(tick)/30.0,'attack_windup_duration':.15},false,false,0,true)
		frames30[CATALOG.attack_frame(float(prepare30.time)/float(prepare30.duration))]=true
	clock30.release('attack_1',.15)
	for tick in 6:
		var recovery30: Dictionary=clock30.sample({},false,false,0.0 if tick==0 else 1.0/30.0,true)
		frames30[CATALOG.attack_frame(float(recovery30.time)/float(recovery30.duration))]=true
	check(frames30.size()==8,'30 FPS playback includes all eight poses, including final recovery')
	clock.release('attack_1',.15);sample=clock.sample({},false,false,.1,false)
	check(is_equal_approx(float(sample.time),.15),'real hero release reconciles even during critical hit-stop')
	var held:=sample.duplicate(true)
	for i in 20:sample=clock.sample({},false,false,.1,false)
	check(sample.time==held.time and sample.action==held.action,'pause and hit-stop retain the contact frame')
	sample=clock.sample({},false,false,.05,true)
	check(float(sample.time)>float(held.time),'recovery resumes without a second release')
	var monster_clock=CLOCK.new()
	sample=monster_clock.sample({'windup':.11,'attack_windup_duration':.22,'visual_action':'attack_1'},false,false,0,true)
	check(is_equal_approx(float(sample.time)/float(sample.duration),.22),'goblin anticipation uses 220 ms of simulation time')
	monster_clock.release('attack_1',.22);sample=monster_clock.sample({},false,false,0,true)
	check(is_equal_approx(float(sample.time),.22),'club impact matches the actual enemy release')
	sample=monster_clock.sample({},false,true,0,true)
	check(sample.action=='death','fallen full-body frame comes from actual death')
	sample=monster_clock.sample({},false,false,0,false)
	check(sample.action!='death','revival reconciles without retaining a stale death frame')
	var catalog=CATALOG.new()
	for id in ['leonhardt','goblin']:
		var entry: Dictionary=catalog.load_entry(id)
		check(not entry.is_empty(),id+' atlas, alpha contours and foot pivots validate')
		if entry.is_empty():done('hunt_frame_pilot');return
		check(entry.attack.frames.size()==8 and entry.motion.frames.size()==8,id+' has complete body attack and motion poses')
	var main=await make_main('aurelia',2)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	main.current_zone_id='gray_meadow';main.idle_stage=1;main._build_combat_screen();await settle()
	main.skill_auto=false;main.ultimate_auto=false;main.pet_runtime={}
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	var terrain=main.combat_labels.terrain;terrain.set_process(false);terrain.hunt_overlay.set_process(false)
	for source in main.hero_map_sprites:source.set_process(false);source.hold_demo=true;source.observe_game=false
	for source in main.enemy_wave_sprites:source.set_process(false)
	for runtime in main.hero_skill_runtime.values():runtime.windup=-1;runtime.attack_remaining=99
	var hero=main.hero_map_sprites[0];var goblin=main.enemy_wave_sprites[0]
	MonsterSpriteFactory.apply_casual(goblin,'초원 고블린',goblin.presentation_scale)
	var id: String=main.deployed_heroes[0].id
	main.combat_running=true;terrain._process(0)
	var rendered=terrain.actors[hero.get_instance_id()]
	var pilot=rendered.get_node_or_null('HuntFramePilot')
	var enemy_pilot=terrain.actors[goblin.get_instance_id()].get_node_or_null('HuntFramePilot')
	check(id=='leonhardt' and pilot!=null and enemy_pilot!=null,'actual default battlefield selects both full-body pilots')
	if pilot==null or enemy_pilot==null:await dispose(main);done('hunt_frame_pilot');return
	check(pilot.skin==null and pilot.find_children('*','Skeleton3D',true,false).is_empty() and pilot.get_child_count()==0,'hero uses one complete painting without anatomical joints')
	check(enemy_pilot.skin==null and enemy_pilot.get_child_count()==0,'goblin has no segmented limbs or neck hinges')
	check(terrain.actors[main.hero_map_sprites[1].get_instance_id()].get_node_or_null('HuntFramePilot')==null,'other heroes retain their existing renderer')
	var before:=economic(main);var rng: int=main.loot_rng.state
	var positions: Dictionary=main.party_movement.positions.duplicate(true)
	var enemy_positions: Array=main.roaming_hunt.enemy_positions.duplicate(true)
	var meshes: Dictionary={}
	for flip in [false,true]:
		hero.flip_h=flip;goblin.flip_h=flip
		terrain.frame_release(hero,true,'attack_1',.15);terrain.frame_release(goblin,false,'attack_1',.22)
		for i in 24:
			terrain._process(1.0/60.0)
			var state: Dictionary=pilot.debug_snapshot()
			check(state.bones==0 and state.body_parts==1,'every action remains a complete body frame')
			check(is_equal_approx(pilot.basis.x.length(),pilot.basis.y.length()),'mirroring never stretches the painted anatomy')
			check(rendered.scale==Vector3.ONE,'pilot bypasses whole-image squash and roll')
			if state.sheet=='attack':meshes[state.frame]=pilot.mesh
	check(meshes.size()>=4,'real release and recovery display distinct fully painted poses')
	check(main.loot_rng.state==rng and economic(main)==before,'presentation consumes no RNG and changes no economy')
	check(main.party_movement.positions==positions and main.roaming_hunt.enemy_positions==enemy_positions,'frame playback cannot change combat reach or world movement')
	main.combat_running=false;terrain._process(0)
	var hero_snapshot: Dictionary=pilot.debug_snapshot();var enemy_snapshot: Dictionary=enemy_pilot.debug_snapshot()
	for i in 20:terrain._process(.1)
	check(pilot.debug_snapshot()==hero_snapshot and enemy_pilot.debug_snapshot()==enemy_snapshot,'pause freezes painted frames and distance clocks')
	main.combat_running=true;terrain.set_presentation_suspended(true);terrain._process(.1)
	check(not terrain.visual_running() and pilot.debug_snapshot().frame==hero_snapshot.frame,'background suspension freezes frame playback')
	terrain.set_presentation_suspended(false)
	for key in main.hero_battle_state:
		main.hero_battle_state[key].hp=1000 if key==id else 0;main.hero_battle_state[key].max_hp=1000
	for enemy in main.enemy_wave:enemy.hp=1000;enemy.max_hp=1000;enemy.attack_remaining=99;enemy.erase('attack_intent')
	main.hero_battle_state[id].attack=20;main.hero_battle_state[id].range=1
	main.party_movement.positions[id]=Vector2(16,10)
	for i in main.enemy_wave.size():main.roaming_hunt.enemy_positions[i]=Vector2(25,18)
	main.roaming_hunt.enemy_positions[0]=Vector2(16.84,10)
	var runtime: Dictionary=main.hero_skill_runtime[id]
	runtime.prepared_action='basic';runtime.target_index=0;runtime.windup=.05;runtime.attack_windup_duration=.15
	runtime.cast=false;runtime.cast_secondary=false;runtime.cast_ultimate=false
	main._advance_hunt_attacks(.06);terrain._process(0)
	check(int(main.enemy_wave[0].hp)==980,'real attack still applies exactly its original single damage')
	check(pilot.debug_snapshot().frame==3 and is_equal_approx(float(pilot.debug_snapshot().phase),.44),'sword impact and actual damage are on the same committed release')
	check(enemy_pilot.timeline.hit_age==0.0 and enemy_pilot.timeline.recoil.x>0,'actual hit drives directional whole-body recoil')
	var sequence: int=pilot.timeline.sequence
	main._advance_hunt_attacks(.01);terrain._process(0)
	check(int(main.enemy_wave[0].hp)==980 and pilot.timeline.sequence==sequence,'follow-through cannot apply another hit')
	runtime.windup=.01;runtime.target_index=0;main.roaming_hunt.enemy_positions[0]=Vector2(25,10)
	main._advance_hunt_attacks(.02);terrain._process(0)
	check(int(main.enemy_wave[0].hp)==980 and pilot.timeline.sequence==sequence,'out-of-reach targets cancel without a false release')
	main.roaming_hunt.enemy_positions[0]=Vector2(16.84,10)
	var enemy: Dictionary=main.enemy_wave[0]
	enemy.attack_intent=id;enemy.attack_remaining=.01;enemy.attack=35;enemy.archetype='brute';enemy.stun_seconds=0
	runtime.windup=-1;runtime.attack_remaining=99
	var hp: int=main.hero_battle_state[id].hp
	main._advance_hunt_attacks(.02);terrain._process(0)
	check(int(main.hero_battle_state[id].hp)<hp,'goblin preserves original incoming damage logic')
	check(enemy_pilot.debug_snapshot().frame==3 and is_equal_approx(float(enemy_pilot.debug_snapshot().phase),.44),'club release matches its actual damage event')
	terrain.frame_hit(goblin,false,Vector2.LEFT);terrain._process(0)
	check(enemy_pilot.timeline.recoil.x<0,'recoil reads incoming direction without changing facing')
	main.enemy_wave[0].hp=0;terrain._process(0)
	check(enemy_pilot.debug_snapshot().action=='death' and enemy_pilot.debug_snapshot().frame==7,'zero HP selects the complete fallen painting')
	main.enemy_wave[0].hp=1000;goblin.play_idle();terrain._process(0)
	check(enemy_pilot.debug_snapshot().action!='death','revival cannot retain a cached fallen pose')
	var economy:=economic(main)
	terrain.frame_pilot_enabled=false;terrain._process(0)
	check(not pilot.visible and not enemy_pilot.visible,'renderer fallback remains reversible')
	check(economic(main)==economy,'fallback has no gameplay or save mutation')
	main.combat_running=false;await dispose(main);done('hunt_frame_pilot')
