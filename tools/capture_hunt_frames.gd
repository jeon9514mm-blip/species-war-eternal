extends SceneTree
## Real default game and actual combat steps, one hero, unchanged production
## stats. No inspection zoom: visible height is checked throughout the movie.
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
	DirAccess.make_dir_recursive_absolute(output);DirAccess.make_dir_recursive_absolute(frames)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	game=load('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path=OS.get_environment('MAP_CAPTURE_USER_DATA').path_join('hunt-frames.json');game._offline_checked=true
	root.add_child(game);await settle()
	game.set_process(false);game.set_physics_process(false);game.sound_effects_enabled=false
	game.combat_effects_enabled=true;game.tutorial_completed=true;game.selected_faction='aurelia';game.current_zone_id='gray_meadow'
	game.idle_stage=1;game.party_slot_legacy_cap=10;game.loot_rng.seed=20261007
	game.hero_progress.leonhardt={'level':1,'xp':0}
	var ids: Array[String]=['leonhardt'];game._restore_deployed_heroes(ids);game._build_combat_screen();await settle()
	game.combat_running=true;game.battle_speed=1.0
	var terrain=game.combat_labels.terrain;terrain.set_process(false);terrain.hunt_overlay.set_process(false)
	for n in 360:
		game._advance_auto_hunt(1.0/30.0)
		for source in game.hero_map_sprites:source.set_process(false)
		for source in game.enemy_wave_sprites:source.set_process(false)
		terrain._process(1.0/30.0);terrain.hunt_overlay._process(1.0/30.0)
		for source in game.enemy_wave_sprites:source.set_process(false)
		var close: bool=false
		var record: Dictionary={'frame':n,'inspection_camera':close,'camera_size':terrain.camera.size,'pilots':[],'enemy_hp':game.enemy_hp,'hero_hp':game.hero_battle_state.get('leonhardt',{}).get('hp',0)}
		for actor in terrain.actors.values():
			var pilot=actor.get_node_or_null('HuntFramePilot')
			if pilot!=null:
				var state: Dictionary=pilot.debug_snapshot()
				state.pixel_height=terrain._actor_height(pilot.source,pilot._hero)*terrain.size.y/terrain.camera.size
				record.pilots.append(state)
		await process_frame;await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image();assert(image.save_png(frames.path_join('frame-%04d.png'%n))==OK)
		if n==180:assert(image.save_png(output.path_join('actual-hunt.png'))==OK)
		for state: Dictionary in record.pilots:
			if state.id!='leonhardt':continue
			var name: String=''
			if state.action=='attack_1':name='actual-attack-%d'%state.frame
			elif state.action=='walk':name='actual-walk'
			if not name.is_empty() and not captures.has(name):
				assert(image.save_png(output.path_join(name+'.png'))==OK);captures[name]=n
		records.append(record)
	var file:=FileAccess.open(output.path_join('actual-hunt.json'),FileAccess.WRITE)
	file.store_string(JSON.stringify({'scene':'scenes/PortraitMain.tscn','natural_hunting':true,'stat_overrides':false,'fps':30,'frames':records,'captures':captures},'  '));file.close()
	game.combat_running=false;game.presentation_runtime.audio.shutdown();game.background_hunt.discard()
	# Let in-flight hit flashes and combat-effect callbacks release their
	# resources before tearing down the manually stepped inspection scene.
	await create_timer(1.0).timeout
	game.queue_free();await settle()
	print('HUNT_FRAME_CAPTURE_OK');quit.call_deferred()
