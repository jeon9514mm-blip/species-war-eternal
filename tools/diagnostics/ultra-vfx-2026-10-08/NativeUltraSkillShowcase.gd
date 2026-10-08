extends 'res://tools/diagnostics/game-audit-2026-10-07/Mobile25dBenchmark.gd'
## Native renderer review fixtures; not a performance or natural-proc replay.
const KITS=preload('res://scripts/heroes/HeroKitRuntime.gd')
const VISUAL=preload('res://scripts/presentation/HeroSkillVfxCatalog.gd')
const FORMATION=preload('res://scripts/maps3d/HeroCircleFormation.gd')
var field: Control
var notes: Dictionary={'schema':1,'art_review_fixture':true,'performance_measurement':false,
	'native_godot_pixels':true,'player_save_used':false,'natural_passive_proc_claim':false,
	'fixture_rules':['Level60 and ready cooldowns/ultimate meters are review fixtures.',
		'High-HP living enemies are moved into real cast range, allies are wounded.',
		'Active/ultimate captures use actual HeroKitRuntime.cast.',
		'Passive review calls the registered proc observer with an explicit fixture serial; not a natural proc.',
		'Automatic timers/simulation and contact slowmo are disabled for deterministic phase review.',
		'GPU particles run through the native renderer; PNG extraction is outside any timing measurement.'],
	'lineups':[],'coverage':[],'captures':[]}

func _stop_automatic_motion() -> void:
	game.set_process(false);game.set_physics_process(false)
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	field.set_process(false);field.set_physics_process(false)
	field.skill_overlay.set_process(false);field.hunt_overlay.set_process(false)
	for actor in game.hero_map_sprites+game.enemy_wave_sprites:
		if is_instance_valid(actor):actor.set_process(false);actor.set_physics_process(false)

func _reset_visuals() -> void:
	var overlay=field.skill_overlay
	while not overlay.casts.is_empty():overlay._retire(0)
	overlay._cutin.visible=false;overlay._cutin_age=1;overlay._cutin_cooldown=0
	field.hunt_overlay.hits.clear();field.hunt_overlay.queue_redraw()
	for burst in overlay.gpu_pool.bursts:
		burst.busy=false
		for emitter in [burst.main,burst.secondary]:emitter.emitting=false;emitter.visible=false
	if is_instance_valid(game._damage_pool):
		for label in game._damage_pool.pool:
			if is_instance_valid(label):label.retire()
	overlay.queue_redraw()

func _ready_cast(hero_id: String,target: int) -> void:
	for state in game.hero_battle_state.values():
		state.hp=maxi(1,int(state.max_hp*.60));state.shield=0;state.shield_seconds=0;state.guard=0
		state.ultimate=100
	for runtime in game.hero_skill_runtime.values():
		runtime.remaining=0;runtime.secondary_remaining=0;runtime.passive_remaining=9999
	for enemy in game.enemy_wave:enemy.hp=1000000;enemy.max_hp=1000000
	game.roaming_hunt.enemy_positions[target]=game._hero_field_position(hero_id)+Vector2(.35,0)
	game.roaming_hunt.enemy_returning[target]=false
	game.hero_skill_runtime[hero_id]['target_index']=target
	field.hunt_interpolation=preload('res://scripts/maps3d/HuntRenderInterpolation.gd').new()
	field._process(0);_stop_automatic_motion()

func _active_cast(hero_id: String,slot: String,target: int) -> Dictionary:
	_ready_cast(hero_id,target)
	var before:=int(field.skill_overlay.accepted_casts)
	var runtime_before:=int(game.hero_skill_runtime[hero_id].get('casts_'+slot,0))
	var settled: int=KITS.cast(game,hero_id,slot,target)
	var accepted: bool=int(field.skill_overlay.accepted_casts)>before
	var result: Dictionary={'hero':hero_id,'slot':slot,'registered_skill_id':ROSTER.skill(hero_id,slot).id,
		'cast_accepted':int(game.hero_skill_runtime[hero_id].get('casts_'+slot,0))>runtime_before,
		'visual_accepted':accepted,'settled_damage':settled,'method':'HeroKitRuntime.cast'}
	return result

func _passive_fixture(hero_id: String,target: int) -> Dictionary:
	_ready_cast(hero_id,target)
	var profile: Dictionary=ROSTER.skill(hero_id,'passive')
	var before:=int(field.skill_overlay.accepted_casts)
	game.hero_skill_runtime[hero_id].passive_procs=int(game.hero_skill_runtime[hero_id].get('passive_procs',0))+1
	game._emit_passive_proc_fx(hero_id,target,profile,game._lowest_hp_hero_id())
	return {'hero':hero_id,'slot':'passive','registered_skill_id':profile.id,
		'visual_accepted':int(field.skill_overlay.accepted_casts)>before,
		'method':'explicit registered passive visual fixture','natural_proc':false}

func _capture(name: String,metadata: Dictionary) -> void:
	_stop_automatic_motion();field._process(0);_stop_automatic_motion()
	await process_frame;await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var status:=image.save_png(output.path_join(name+'.png'));assert(status==OK)
	metadata['file']=name+'.png';metadata['width']=image.get_width();metadata['height']=image.get_height()
	metadata['texture_bytes']=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	metadata['buffer_bytes']=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
	metadata['memory_bytes']=Performance.get_monitor(Performance.MEMORY_STATIC)
	notes.captures.append(metadata)

func _advance_visuals(seconds: float) -> void:
	# Advance the actual fixed-capacity presenters. No economy/combat step runs.
	field.skill_overlay.advance(seconds);field.hunt_overlay._process(seconds)
	field.skill_overlay.gpu_pool._process(seconds);field._process(seconds);_stop_automatic_motion()

func _lineup(faction: String,ids: Array[String],name: String) -> void:
	game.combat_running=false;game.selected_faction=faction;game.party_slot_legacy_cap=10
	game.idle_stage=154;game.current_zone_id='gray_meadow';game.battle_speed=1
	for hero_id in ids:game.hero_progress[hero_id]={'level':60,'xp':0}
	game._restore_deployed_heroes(ids);game._build_combat_screen()
	game.set_process(false);game.set_physics_process(false)
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	await settle()
	field=game.combat_labels.terrain
	game.set_process(false);game.set_physics_process(false)
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	game.combat_running=true
	FORMATION.hunt(game,field,true);field._process(0);_stop_automatic_motion()
	assert(game.enemy_wave.size()>=3)
	notes.lineups.append({'name':name,'faction':faction,'heroes':ids.duplicate(),'level_fixture':60})
	for hero_id in ids:
		for slot in ['a1','a2','ultimate']:
			_reset_visuals();var result:=_active_cast(hero_id,slot,0);notes.coverage.append(result)
			assert(result.cast_accepted and result.visual_accepted)
		_reset_visuals();var passive:=_passive_fixture(hero_id,0);notes.coverage.append(passive)
		assert(passive.visual_accepted)
		await process_frame
	_reset_visuals()
	# Three actual casts remain separated by three living targets. The first
	# active retains readable timing while the ultimate shows its own cadence.
	var selected: Array=[ids[0],ids[mini(1,ids.size()-1)],ids[mini(2,ids.size()-1)]]
	var selected_slots: Array=['a1','a2','ultimate']
	var cast_metadata: Array=[]
	for index in 3:cast_metadata.append(_active_cast(str(selected[index]),str(selected_slots[index]),index))
	var phases: Array=[['charge',.045],['flight',.205],['impact',.50],['trail',.68],['afterglow',1.01],['fade',1.23]]
	var previous:=0.0
	for phase in phases:
		_advance_visuals(float(phase[1])-previous);previous=float(phase[1])
		await _capture(name+'-'+str(phase[0]),{'lineup':name,'phase':phase[0],'manual_visual_age':previous,'actual_casts':cast_metadata,'natural_proc':false})
	_reset_visuals()
	var passive_metadata: Array=[]
	for index in mini(3,ids.size()):passive_metadata.append(_passive_fixture(ids[index],index))
	_advance_visuals(.15)
	await _capture(name+'-passive-fixture',{'lineup':name,'phase':'passive','manual_visual_age':.15,'casts':passive_metadata,'natural_proc':false})
	game.combat_running=false

func run() -> void:
	assert(DisplayServer.get_name()!='headless')
	output=OS.get_environment('GAME_AUDIT_OUTPUT');assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://ultra-showcase-isolated.json'
	game._offline_checked=true;root.add_child(game);await settle()
	game.sound_effects_enabled=false;game.combat_effects_enabled=true;game.combat_fx.enabled=true;game.tutorial_completed=true
	game.skill_auto=false;game.ultimate_auto=false;game.presentation_options.haptics='off'
	game._set_presentation_option('music_enabled',false,false);game._set_presentation_option('performance','balanced',false)
	game.presentation_runtime.contact_time.enabled=false;game.presentation_runtime.contact_time.restore()
	game.wallet_gold=49000;game.wallet_gems=840
	notes.renderer=RenderingServer.get_current_rendering_method();notes.device=RenderingServer.get_video_adapter_name();notes.engine=Engine.get_version_info().string
	for faction in ['aurelia','noxfera']:
		var heroes: Array=ROSTER.roster(faction)
		for offset in [0,10]:
			var ids: Array[String]=[]
			for hero in heroes.slice(offset,mini(offset+10,heroes.size())):ids.append(str(hero.id))
			await _lineup(faction,ids,faction+('-core10' if offset==0 else '-reserve5'))
	var identities: Dictionary={}
	for entry in notes.coverage:identities[str(entry.hero)+':'+str(entry.slot)]=true
	notes.hero_count=ROSTER.HEROES.size();notes.registered_identity_count=identities.size()
	notes.actual_active_cast_count=90;notes.explicit_passive_fixture_count=30
	assert(identities.size()==120)
	var file=FileAccess.open(output.path_join('showcase-fixture.json'),FileAccess.WRITE);file.store_string(JSON.stringify(notes,'  '));file.close()
	game.combat_running=false;game.presentation_runtime.audio.shutdown();game.background_hunt.discard();game.queue_free();await settle()
	print('NATIVE_ULTRA_SKILL_SHOWCASE_OK');quit()
