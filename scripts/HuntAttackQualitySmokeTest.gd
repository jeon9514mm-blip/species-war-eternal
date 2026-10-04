extends 'res://scripts/V83UpgradeTestBase.gd'
const ATTACK=preload('res://scripts/HuntAttackDirector.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',3)
	main._build_combat_screen();await settle()
	main.skill_auto=false;main.ultimate_auto=false;main.pet_runtime={}
	var id: String=main.deployed_heroes[0].id
	var other: String=main.deployed_heroes[1].id
	for hero_id in main.hero_battle_state:
		main.hero_battle_state[hero_id].hp=1000 if hero_id==id else 0
		main.hero_battle_state[hero_id].max_hp=1000
		main.hero_skill_runtime[hero_id].windup=-1
		main.hero_skill_runtime[hero_id].attack_remaining=99
	for enemy in main.enemy_wave:
		enemy.hp=1000;enemy.max_hp=1000;enemy.attack_remaining=99;enemy.stun_seconds=0
	main.hero_battle_state[id].attack=20;main.hero_battle_state[id].range=1
	main.party_movement.positions[id]=Vector2(16,10)
	for i in main.enemy_wave.size():main.roaming_hunt.enemy_positions[i]=Vector2(25,18)
	main.roaming_hunt.enemy_positions[0]=Vector2(16.6,10)
	main.roaming_hunt.enemy_positions[1]=Vector2(16,10.5)
	var runtime: Dictionary=main.hero_skill_runtime[id]
	runtime.prepared_action='basic';runtime.target_index=0
	check(ATTACK.committed_target(main,id,'basic','basic')==0,'commit retains the aimed target despite another reachable enemy')
	check(ATTACK.committed_target(main,id,'basic','a1')==-1,'a changed action cannot redirect an already released attack')
	runtime.windup=.05;runtime.cast=false;runtime.cast_secondary=false;runtime.cast_ultimate=false
	main.enemy_wave[0].hp=0
	main._advance_hunt_attacks(.06)
	check(int(main.enemy_wave[1].hp)==1000,'dead aimed target cancels actual contact without switching to another enemy')
	main.enemy_wave[0].hp=1000;runtime.target_index=0;runtime.windup=.05
	main.roaming_hunt.enemy_positions[0]=Vector2(25,10)
	main._advance_hunt_attacks(.06)
	check(int(main.enemy_wave[0].hp)==1000 and int(main.enemy_wave[1].hp)==1000,'out of reach cancels actual contact')
	main.roaming_hunt.enemy_positions[0]=Vector2(16.6,10);runtime.target_index=0;runtime.windup=.05
	main._advance_hunt_attacks(.06)
	check(int(main.enemy_wave[0].hp)==980,'valid basic contact damages the aimed enemy once')
	main._advance_hunt_attacks(.01)
	check(int(main.enemy_wave[0].hp)==980,'follow-through does not cause a second hit')
	var enemy: Dictionary=main.enemy_wave[0]
	enemy.archetype='brute';enemy.attack_remaining=.30;enemy.target_id=id;enemy.hunt_target_lock=1
	var hp: int=main.hero_battle_state[id].hp
	check(not bool(ATTACK.advance_enemy(main,0,.10).ready) and enemy.has('attack_intent'),'enemy enters anticipation before contact')
	check(int(main.hero_battle_state[id].hp)==hp,'anticipation itself cannot apply damage')
	var before: Vector2=main.roaming_hunt.enemy_positions[0]
	main._advance_roaming_hunt(.01)
	check(main.roaming_hunt.enemy_positions[0]==before,'preparing attacker holds its contact position')
	main.party_movement.positions[id]=Vector2(22,10)
	main.hero_battle_state[other].hp=1000;main.party_movement.positions[other]=Vector2(16.5,10)
	var result: Dictionary=ATTACK.advance_enemy(main,0,.25)
	check(not bool(result.ready) and not enemy.has('attack_intent'),'departed target cancels enemy contact despite another hero in range')
	enemy.attack_remaining=.30;enemy.target_id=other;enemy.hunt_target_lock=1
	ATTACK.advance_enemy(main,0,.10);enemy.stun_seconds=.5
	result=ATTACK.advance_enemy(main,0,.25)
	check(not bool(result.ready) and not enemy.has('attack_intent'),'stun cancels intent and prevents a queued strike')
	enemy.stun_seconds=0
	check(not bool(ATTACK.advance_enemy(main,0,.01).ready),'stun recovery must prepare again rather than instantly hit')
	enemy.attack_intent=id;enemy.attack_remaining=.1
	main.hero_battle_state[other].hp=0
	main._advance_roaming_hunt(.01)
	check(not enemy.has('attack_intent'),'movement cancels departed-target intent even when no hero can attack')
	main.combat_running=false
	var wave: Array=main.enemy_wave.duplicate(true);var rt: Dictionary=main.hero_skill_runtime.duplicate(true)
	main._advance_auto_hunt(.4)
	check(main.enemy_wave==wave and main.hero_skill_runtime==rt,'pause freezes prepared actions without delayed damage callbacks')
	main.combat_running=true;main.combat_effects_enabled=true;main.combat_fx.enabled=true
	var terrain=main.combat_labels.terrain
	main.battle_speed=2;terrain._process(0)
	var sprite=main.enemy_wave_sprites[0]
	var time: float=sprite.visual_state_time;sprite._process(.05)
	check(sprite.speed_scale==2 and is_equal_approx(sprite.visual_state_time-time,.1),'double speed synchronizes the actor presentation clock')
	main.combat_running=false;terrain._process(0)
	time=sprite.visual_state_time;sprite._process(.05)
	check(sprite.speed_scale==0 and sprite.visual_state_time==time,'pause stops the actor presentation clock')
	main.combat_running=true;main.battle_speed=1;terrain._process(0)
	var position: Vector2=main.content_root.position;var scale: Vector2=main.content_root.scale
	main.combat_fx.camera_impact(4,.16,.01);terrain._process(.04)
	check(main.content_root.position==position and main.content_root.scale==scale,'impact leaves HUD and touch controls fixed')
	check(absf(terrain.camera.h_offset)>0,'impact moves only the world camera')
	terrain._process(.4)
	check(is_zero_approx(terrain.camera.h_offset) and is_zero_approx(terrain.camera.v_offset),'camera returns to its resting projection')
	main.combat_fx.camera_impact(4,.16,.01);terrain._process(.04)
	check(absf(terrain.camera.h_offset)>0,'camera accepts a later impact after recovery')
	for i in 100:terrain.hunt_hit(Vector2(16,10),Vector2(15,10),Color.WHITE,false)
	check(terrain.hunt_overlay.hits.size()<=32,'heavy contact keeps a bounded single overlay')
	main.combat_running=false
	var hits: Array=terrain.hunt_overlay.hits.duplicate(true);terrain.hunt_overlay._process(.5)
	check(terrain.hunt_overlay.hits==hits,'pause freezes impact presentation')
	main.combat_effects_enabled=false;terrain.hunt_overlay._process(.01)
	check(terrain.hunt_overlay.hits.is_empty(),'effects setting clears optional presentation')
	await dispose(main)
	done('hunt_attack_quality')
