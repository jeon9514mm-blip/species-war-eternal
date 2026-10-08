extends 'res://tools/diagnostics/game-audit-2026-10-07/Mobile25dBenchmark.gd'
const BODY=preload('res://scripts/hunting/HuntBodyCollision.gd')
func sample(seconds: float) -> Dictionary:
	var field=game.combat_labels.terrain
	var gap:=INF;var points: Array[Vector2]=[];var clipped:=0
	var bounds:=Rect2(field.position,field.size)
	for i in mini(game.deployed_heroes.size(),game.hero_map_sprites.size()):
		var id: String=game.deployed_heroes[i].id
		if id not in game._alive_hero_ids():continue
		var source=game.hero_map_sprites[i]
		points.append(field.project_world(field.display_world(source,game._hero_field_position(id))))
		var paint: Rect2=field._paint_rects.get(source.get_instance_id(),Rect2())
		if paint.has_area() and not bounds.grow(.1).encloses(paint):clipped+=1
	for a in points.size():
		for b in range(a+1,points.size()):gap=minf(gap,points[a].distance_to(points[b]))
	var rendered: Array[Dictionary]=BODY.actors(game)
	for body in rendered:
		if body.hero:body.position=field._render_hero_points.get(str(body.id),body.position)
		elif int(body.id)<game.enemy_wave_sprites.size():body.position=field.display_world(game.enemy_wave_sprites[int(body.id)],body.position)
	var render_overlaps:=0
	for a in rendered.size():
		for b in range(a+1,rendered.size()):
			if BODY.body_distance(rendered[a].position,rendered[b].position)<BODY.clearance(rendered[a],rendered[b])-.01:render_overlaps+=1
	return {'seconds':seconds,'hero_gap_pixels':gap,'body_overlap':BODY.overlapping(game),'render_overlap_pairs':render_overlaps,'hero_original_clipped':clipped,'field_size':[field.size.x,field.size.y],'heroes_alive':game._alive_hero_ids().size(),'enemies_alive':game._enemy_wave_alive_count(),'corps':game.combat_hunt_cycle,'hp':game.party_hp,'formation':game.formation_id,'heading':[game.party_movement.formation_facing.x,game.party_movement.formation_facing.y]}
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+'.png'))
func run() -> void:
	assert(DisplayServer.get_name()!='headless')
	output=OS.get_environment('GAME_AUDIT_OUTPUT');assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://hunt-formation-native.json';game._offline_checked=true;root.add_child(game);await settle()
	game.sound_effects_enabled=false;game.combat_effects_enabled=true;game.combat_fx.enabled=true;game.tutorial_completed=true;game._set_presentation_option('music_enabled',false,false)
	game._set_presentation_option('performance','balanced',false)
	report.renderer=RenderingServer.get_current_rendering_method();report.device=RenderingServer.get_video_adapter_name();report.engine=Engine.get_version_info().string;report.samples=[];report.peak_zoom=[]
	for faction: String in ['aurelia','noxfera']:
		game.combat_running=false;game.formation_id='balanced';await fixture(faction);game.combat_running=false;await settle();await capture('ready-'+faction)
		game.combat_running=true
		var start:=Time.get_ticks_usec();var next_sample:=0.0
		while Time.get_ticks_usec()-start<10000000:
			await process_frame
			var elapsed: float=(Time.get_ticks_usec()-start)/1000000.0
			if elapsed>=next_sample:
				var row:=sample(elapsed);row.faction=faction;report.samples.append(row);next_sample+=.2
		await capture('hunt-'+faction)
	# Explicit native peak-punch framing cases, using unchanged real originals.
	game.set_process(false);game.set_physics_process(false)
	for choice: String in ['balanced','assault','bulwark','volley']:
		game.combat_running=false;game.formation_id=choice;await fixture('aurelia')
		var field=game.combat_labels.terrain;field.set_process(false)
		if is_instance_valid(game.combat_timer):game.combat_timer.stop()
		game.combat_running=true;field.hunt_interpolation.reset();field.mobile_camera.impact(true);field._process(.05)
		for actor in game.hero_map_sprites+game.enemy_wave_sprites:actor.set_process(false)
		await settle();await capture('formation-'+choice+'-peak-zoom')
		report.peak_zoom.append(sample(0))
	game.combat_running=false;game.presentation_runtime.contact_time.restore()
	FileAccess.open(output.path_join('observations.json'),FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
	game.presentation_runtime.audio.shutdown();game.background_hunt.discard();game.queue_free();await settle()
	print('HUNT_FORMATION_CAPTURE_OK');quit()
