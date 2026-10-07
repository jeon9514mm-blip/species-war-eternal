extends SceneTree
## Controlled encounter inspection using production attacks and unchanged stats.
## Positions, initial cooldowns, auto-skill settings and encounter resets are
## explicit fixture choices; this is not footage of an ordinary spawned wave.
var game: Node
var output: String
var frames: String
var records: Array[Dictionary]=[]
var captures: Dictionary={}
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 3:await process_frame
func run() -> void:
	if DisplayServer.get_name()=='headless':quit(1);return
	output=OS.get_environment('MAP_CAPTURE_OUTPUT');frames=OS.get_environment('PILOT_MOVIE_FRAMES')
	assert(not output.is_empty() and not frames.is_empty())
	game=load('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path=OS.get_environment('MAP_CAPTURE_USER_DATA').path_join('duel-inspection.json');game._offline_checked=true
	root.add_child(game);await settle()
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	game.set_process(false);game.set_physics_process(false);game.sound_effects_enabled=false
	game.tutorial_completed=true;game.selected_faction='aurelia';game.current_zone_id='gray_meadow';game.idle_stage=1
	game.hero_progress.leonhardt={'level':1,'xp':0}
	var ids: Array[String]=['leonhardt'];game._restore_deployed_heroes(ids);game._build_combat_screen();await settle()
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	var selected: Dictionary={}
	for enemy in game.enemy_wave:
		if str(enemy.name)=='초원 고블린':selected=enemy.duplicate(true);break
	assert(not selected.is_empty())
	for source in game.enemy_wave_sprites:source.queue_free()
	for bar in game.enemy_hp_bars:bar.queue_free()
	game.enemy_wave.clear();game.enemy_wave_sprites.clear();game.enemy_hp_bars.clear()
	game.enemy_wave.append(selected);game.roaming_hunt.clear_enemies();game.roaming_hunt.append_corps([selected],1)
	game._spawn_enemy_wave_sprites();game._sync_enemy_wave_summary();await settle()
	game.skill_auto=false;game.ultimate_auto=false;game.pet_runtime={};game.combat_running=true;game.battle_speed=1.0
	game.hunt_ai.set_state(AutoHuntController.State.FIGHTING);game.combat_engage_settle_remaining=0.0
	var terrain=game.combat_labels.terrain;terrain.set_process(false);terrain.hunt_overlay.set_process(false)
	var hero=game.hero_map_sprites[0];var goblin=game.enemy_wave_sprites[0]
	hero.set_process(false);goblin.set_process(false)
	var label:=Label.new();label.position=Vector2(30,136);label.add_theme_font_size_override('font_size',19)
	label.add_theme_color_override('font_outline_color',Color('#14202b'));label.add_theme_constant_override('outline_size',5)
	label.text='전투 동작 검수 · 1대1 배치 / 기본 공격 / 능력치 유지 / 시작 대기시간 설정';root.add_child(label)
	var baseline: Dictionary={'hero':game.hero_battle_state.leonhardt.duplicate(true),'goblin':selected.duplicate(true)}
	for n in 180:
		if n==0 or n==90:
			var reverse: bool=n==90
			var hero_point:=Vector2(16.84 if reverse else 16.0,10)
			var enemy_point:=Vector2(16.0 if reverse else 16.84,10)
			game.party_movement.positions.leonhardt=hero_point;game.party_movement.targets.leonhardt=0
			game.roaming_hunt.enemy_positions[0]=enemy_point;game.roaming_hunt.enemy_home_positions[0]=enemy_point
			game.hero_battle_state.leonhardt.hp=game.hero_battle_state.leonhardt.max_hp
			selected.hp=selected.max_hp;selected.erase('attack_intent');selected.attack_remaining=.22
			var runtime: Dictionary=game.hero_skill_runtime.leonhardt
			runtime.windup=-1.0;runtime.attack_remaining=.8;runtime.prepared_action='basic';runtime.target_index=0
			hero.play_idle();goblin.play_idle()
			hero.set_direction_from_vector(enemy_point-hero_point);goblin.set_direction_from_vector(hero_point-enemy_point)
		game._advance_skill_cooldowns(1.0/30.0);game._advance_hunt_attacks(1.0/30.0)
		game._sync_enemy_wave_summary();terrain._process(1.0/30.0);terrain.hunt_overlay._process(1.0/30.0)
		# Terrain resumes source timers for ordinary gameplay. This fixture steps
		# simulation/rendering manually, so retain the hidden 2D source until draw.
		goblin.set_process(false)
		terrain._set_focus(Vector2(16.42,10));terrain.camera.size=3.8
		var record: Dictionary={'frame':n,'hero_hp':game.hero_battle_state.leonhardt.hp,'goblin_hp':selected.hp,'pilots':[]}
		for actor in terrain.actors.values():
			var pilot=actor.get_node_or_null('HuntFramePilot')
			if pilot!=null:record.pilots.append(pilot.debug_snapshot())
		await process_frame;await RenderingServer.frame_post_draw
		if n==8:
			var sources: Array[Dictionary]=[]
			for node in game.find_children('*','AnimatedSprite2D',true,false):
				sources.append({'path':str(node.get_path()),'self_alpha':node.self_modulate.a,'visible':node.is_visible_in_tree(),'processing':node.is_processing(),'animation':str(node.animation)})
			var diagnostic:=FileAccess.open(output.path_join('duel-source-visibility.json'),FileAccess.WRITE)
			diagnostic.store_string(JSON.stringify(sources,'  '));diagnostic.close()
		var image:=root.get_texture().get_image();assert(image.save_png(frames.path_join('frame-%04d.png'%n))==OK)
		for state: Dictionary in record.pilots:
			if state.sheet!='attack':continue
			var name: String=('mirrored-' if n>=90 else '')+str(state.id)+'-attack-%d'%state.frame
			if not captures.has(name):assert(image.save_png(output.path_join(name+'.png'))==OK);captures[name]=n
		records.append(record)
	var file:=FileAccess.open(output.path_join('combat-duel-inspection.json'),FileAccess.WRITE)
	file.store_string(JSON.stringify({'natural_hunting':false,'stat_overrides':false,'fixture_overrides':['single goblin encounter','starting positions','initial attack cooldowns','basic attacks only','encounter reset at 3 seconds','inspection camera'],'baseline':baseline,'fps':30,'frames':records,'captures':captures},'  '));file.close()
	game.combat_running=false;game.presentation_runtime.audio.shutdown();game.background_hunt.discard()
	await create_timer(1.0).timeout
	game.queue_free();label.queue_free();await settle()
	print('HUNT_FRAME_DUEL_OK');quit.call_deferred()
