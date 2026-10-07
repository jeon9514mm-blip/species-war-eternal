extends SceneTree
## Actual player frame intervals. Recording is a separate, fixed-step run.
const ROSTER=preload('res://scripts/heroes/HeroRosterCatalog.gd')
var game: Node
var output: String
var report: Dictionary={'android_measured':false,'profiles':[],'assets':[]}
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 8:await process_frame
func fixture(faction: String) -> void:
	game.selected_faction=faction;game.party_slot_legacy_cap=10;game.idle_stage=154;game.current_zone_id='gray_meadow';game.battle_speed=1
	var ids: Array[String]=[]
	for hero in ROSTER.roster(faction).slice(0,10):ids.append(hero.id);game.hero_progress[hero.id]={'level':60,'xp':0}
	game._restore_deployed_heroes(ids);game._build_combat_screen();await settle()
func measure(label: String,seconds: float) -> void:
	await create_timer(2).timeout
	var times: Array[float]=[];var start:=Time.get_ticks_usec();var previous:=start
	while Time.get_ticks_usec()-start<seconds*1000000:
		await process_frame
		var now:=Time.get_ticks_usec();times.append((now-previous)/1000.);previous=now
	var elapsed: float=(previous-start)/1000000.;var sum_ms:=0.
	for value in times:sum_ms+=value
	times.sort()
	report.profiles.append({'label':label,'frames':times.size(),'seconds':elapsed,'mean_fps':times.size()/elapsed,'mean_frame_ms':sum_ms/times.size(),'p95_frame_ms':times[int(times.size()*.95)],'texture_bytes':RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),'buffer_bytes':RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),'draw_calls':Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),'objects':Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),'enemy_alive':game._enemy_wave_alive_count(),'hero_alive':game._alive_hero_ids().size()})
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(label+'.png'))
func asset_budget() -> void:
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/mobile25d/catalog.json'))
	for entry in catalog.entries:
		var texture: Texture2D=load('res://assets/mobile25d/'+entry.id+'/poses_1024.png')
		var image: Image=texture.get_image();var scene: PackedScene=load(entry.mesh);var node:=scene.instantiate();var mesh_bytes:=0;var triangles:=0
		for part in node.find_children('*','MeshInstance3D',true,false):
			for i in part.mesh.get_surface_count():
				var arrays: Array=part.mesh.surface_get_arrays(i);triangles+=int(arrays[Mesh.ARRAY_INDEX].size()/3)
				for array in arrays:
					if array!=null and typeof(array)!=TYPE_NIL:mesh_bytes+=var_to_bytes(array).size()
		node.free()
		report.assets.append({'id':entry.id,'hero':entry.hero,'triangles':triangles,'texture_format':image.get_format(),'compressed_texture_bytes_with_mips':image.get_data().size(),'decoded_mesh_array_bytes':mesh_bytes,'png_bytes':entry.png_bytes,'glb_bytes':entry.glb_bytes})
func record() -> void:
	await fixture('aurelia');game.set_process(false);game.set_physics_process(false)
	game.presentation_runtime.contact_time.enabled=false;game.presentation_runtime.contact_time.restore()
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	var field=game.combat_labels.terrain;field.set_process(false)
	var frames:=output.path_join('frames');DirAccess.make_dir_recursive_absolute(frames)
	game.combat_running=false;field._process(0);await settle();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join('circle-10-heroes.png'))
	game.combat_running=true
	for i in 160:
		game._advance_auto_hunt(.05)
		for actor in game.hero_map_sprites+game.enemy_wave_sprites:actor.set_process(false)
		field._process(.05);await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(frames.path_join('%04d.png'%i))
		if i==99:root.get_texture().get_image().save_png(output.path_join('hunt-review.png'))
func run() -> void:
	assert(DisplayServer.get_name()!='headless');output=OS.get_environment('GAME_AUDIT_OUTPUT');assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://mobile25d-benchmark.json';game._offline_checked=true;root.add_child(game);await settle()
	game.sound_effects_enabled=false;game.combat_effects_enabled=true;game.combat_fx.enabled=true;game.tutorial_completed=true;game._set_presentation_option('music_enabled',false,false)
	report.renderer=RenderingServer.get_current_rendering_method();report.device=RenderingServer.get_video_adapter_name();report.engine=Engine.get_version_info().string
	for mode in ['balanced','battery']:
		game._set_presentation_option('performance',mode,false);await fixture('aurelia');game.combat_running=true;await measure('hunt-'+mode,8)
	game._set_presentation_option('performance','balanced',false);game.selected_raid_id='gray_meadow';game._build_raid_screen();await settle();game._start_raid();await measure('raid-balanced',4)
	game.raid_running=false;asset_budget()
	var file=FileAccess.open(output.path_join('performance.json'),FileAccess.WRITE);file.store_string(JSON.stringify(report,'  '));file.close()
	await record();game.combat_running=false;game.presentation_runtime.audio.shutdown();game.background_hunt.discard();game.queue_free();await settle()
	print('MOBILE25D_BENCHMARK_OK');quit()
