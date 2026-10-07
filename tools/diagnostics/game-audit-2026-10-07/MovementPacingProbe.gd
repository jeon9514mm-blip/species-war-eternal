extends "res://tools/diagnostics/game-audit-2026-10-07/Mobile25dBenchmark.gd"
## Real-time production loop, including contact feedback. No manual simulation.
func measure(label: String, seconds: float) -> void:
	await create_timer(2).timeout
	var times: Array[float]=[];var start:=Time.get_ticks_usec();var previous:=start
	var slowed:=0;var walking:=0;var held:=0;var last: Dictionary={};var max_step:=0.0
	var physics_ms:=0.0;var process_ms:=0.0
	while Time.get_ticks_usec()-start<seconds*1000000:
		await process_frame
		var now:=Time.get_ticks_usec();times.append((now-previous)/1000.);previous=now
		if Engine.time_scale<.99:slowed+=1
		physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		process_ms+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
		var field=game.combat_labels.get('terrain') if game.active_screen=='combat' else game.content_root.get_node('PortraitRaidView').battlefield_3d
		var sources: Array=game.hero_map_sprites if game.active_screen=='combat' else game.content_root.get_node('PortraitRaidView').hero_actors.values()
		for source in sources:
			if not is_instance_valid(source):continue
			var id: int=source.get_instance_id();var sprite=field.actors.get(id)
			if sprite==null:continue
			var foot:=Vector2(sprite.position.x,sprite.position.z)
			if source.state=='walk' and last.has(id):
				walking+=1
				var distance: float=foot.distance_to(last[id]);max_step=maxf(max_step,distance)
				if distance<.00001:held+=1
			last[id]=foot
	var elapsed: float=(previous-start)/1000000.;times.sort()
	report.profiles.append({'label':label,'frames':times.size(),'seconds':elapsed,'mean_fps':times.size()/elapsed,'p95_frame_ms':times[int(times.size()*.95)],'slowed_frames':slowed,'slowed_frame_ratio':float(slowed)/maxi(1,times.size()),'walking_actor_frames':walking,'held_walking_frames':held,'held_walking_ratio':float(held)/maxi(1,walking),'max_world_step':max_step,'physics_ms_mean':physics_ms/times.size(),'process_ms_mean':process_ms/times.size(),'texture_bytes':RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),'draw_calls':Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(label+'.png'))

func run() -> void:
	assert(DisplayServer.get_name()!='headless');output=OS.get_environment('GAME_AUDIT_OUTPUT');DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://movement-pacing.json';game._offline_checked=true;root.add_child(game);await settle()
	game.sound_effects_enabled=false;game.combat_effects_enabled=true;game.combat_fx.enabled=true;game.tutorial_completed=true;game._set_presentation_option('music_enabled',false,false)
	game._set_presentation_option('performance','balanced',false)
	report.renderer=RenderingServer.get_current_rendering_method();report.device=RenderingServer.get_video_adapter_name();report.engine=Engine.get_version_info().string;report.assets=[]
	for faction in ['aurelia','noxfera']:
		await fixture(faction);game.combat_running=true;await measure('hunt-'+faction,8)
	game.selected_raid_id='gray_meadow';game._build_raid_screen();await settle();game._start_raid();await measure('raid',6)
	game.raid_running=false;game.combat_running=false;game.presentation_runtime.contact_time.restore()
	var file=FileAccess.open(output.path_join('performance.json'),FileAccess.WRITE);file.store_string(JSON.stringify(report,'  '));file.close()
	game.presentation_runtime.audio.shutdown();game.background_hunt.discard();game.queue_free();await settle()
	print('MOVEMENT_PACING_OK');quit()
