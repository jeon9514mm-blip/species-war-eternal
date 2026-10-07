extends SceneTree
## Real production scenes; manually step the simulation, retain default stats.
var game: Node
var output: String
var records: Array[Dictionary]=[]
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 3:await process_frame
func capture(label: String,terrain) -> void:
	terrain._process(0);terrain._process(0)
	var bodies: Array[Dictionary]=[]
	for actor in terrain.actors.values():
		var pilot=actor.get_node_or_null('HuntFramePilot')
		if pilot!=null:bodies.append(pilot.debug_snapshot())
	var overlap:=0;var rectangles: Array=terrain._paint_rects.values()
	for a in rectangles.size():
		for b in range(a+1,rectangles.size()):
			if rectangles[a].intersects(rectangles[b]):overlap+=1
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	var hero_scales: Array[float]=[]
	var display_heights: Array[Dictionary]=[]
	var layout_items: Array[Dictionary]=[]
	for actor in terrain.actors.values():
		var pilot=actor.get_node_or_null('HuntFramePilot')
		if pilot!=null and pilot._hero:hero_scales.append(terrain._body_scales[pilot.source.get_instance_id()])
		if pilot!=null:display_heights.append({'id':str(pilot.entry.id),'hero':pilot._hero,'nominal_height':terrain._actor_height(pilot.source,pilot._hero),'pixels':terrain._actor_height(pilot.source,pilot._hero)*terrain.size.y/terrain.camera.size})
		if pilot!=null and pilot.source.state!='death':
			var rect: Rect2=pilot.footprint(terrain._base_actor_height(pilot.source,pilot._hero))
			if pilot.source.flip_h:rect.position.x=-rect.end.x
			var foot: Vector2=terrain.project_world(Vector2(actor.position.x,actor.position.z))*terrain.camera.size/terrain.size.y
			layout_items.append({'id':str(pilot.entry.id),'point':[foot.x,foot.y],'bounds':[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	records.append({'capture':label,'bodies':bodies,'projected_paint_overlaps':overlap,'hero_scales':hero_scales,'scales':terrain._body_scales.values(),'display_heights':display_heights,'layout_items':layout_items,'camera_size':terrain.camera.size,'stat_overrides':false})
func run() -> void:
	if DisplayServer.get_name()=='headless':quit(1);return
	output=OS.get_environment('MAP_CAPTURE_OUTPUT');assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game._offline_checked=true
	game.save_state_path=OS.get_environment('MAP_CAPTURE_USER_DATA').path_join('rollout.json');root.add_child(game);await settle()
	game.set_process(false);game.set_physics_process(false);game.sound_effects_enabled=false;game.combat_effects_enabled=true
	game.tutorial_completed=true;game.idle_stage=100;game.party_slot_legacy_cap=10;game.loot_rng.seed=20261007
	for faction in ['aurelia','noxfera']:
		game.selected_faction=faction;var ids: Array[String]=[]
		for hero in game._hero_roster_for_faction():
			if ids.size()<10:ids.append(str(hero.id))
		game._restore_deployed_heroes(ids);game.current_zone_id='gray_meadow';game._build_combat_screen();await settle()
		game.combat_running=true
		if is_instance_valid(game.combat_timer):game.combat_timer.stop()
		var terrain=game.combat_labels.terrain;terrain.set_process(false)
		for n in 180:
			game._advance_auto_hunt(1.0/30)
			for source in game.hero_map_sprites+game.enemy_wave_sprites:source.set_process(false)
			terrain._process(1.0/30)
			for source in game.enemy_wave_sprites:source.set_process(false)
			if n%15==0:await process_frame
		await capture(faction+'-ten-hero-hunt',terrain);game.combat_running=false
	game.selected_faction='aurelia';var ids: Array[String]=[]
	for hero in game._hero_roster_for_faction():
		if ids.size()<10:ids.append(str(hero.id))
	game._restore_deployed_heroes(ids)
	for hunt_zone in ['forgotten_mine','moonrest_forest']:
		game.current_zone_id=hunt_zone;game._build_combat_screen();await settle();game.combat_running=true
		if is_instance_valid(game.combat_timer):game.combat_timer.stop()
		var field=game.combat_labels.terrain;field.set_process(false)
		for tick in 180:
			game._advance_auto_hunt(1.0/30)
			for actor in game.hero_map_sprites+game.enemy_wave_sprites:actor.set_process(false)
			field._process(1.0/30)
			if tick%15==0:await process_frame
		await capture(hunt_zone+'-ten-hero-hunt',field);game.combat_running=false
	for zone in ['gray_meadow','forgotten_mine','moonrest_forest']:
		game.selected_raid_id=zone;game._build_raid_screen();await settle();game._start_raid();game.combat_timer.stop()
		var view=game.content_root.get_node('PortraitRaidView');var terrain=view.battlefield_3d
		await create_timer(.85).timeout
		view.set_process(false);terrain.set_process(false)
		for n in 120:
			game._advance_raid_encounter(1.0/30);view._process(1.0/30)
			for source in view.hero_actors.values():source.set_process(false)
			game.raid_boss_sprite.set_process(false);terrain._process(1.0/30);game.raid_boss_sprite.set_process(false)
			if n%15==0:await process_frame
		await capture(zone+'-raid',terrain);game.raid_running=false
	var file:=FileAccess.open(output.path_join('captures.json'),FileAccess.WRITE);file.store_string(JSON.stringify(records,'  '));file.close()
	game.presentation_runtime.audio.shutdown();game.background_hunt.discard();await create_timer(1.0).timeout
	game.hide()
	# Labelled size inspection: same standing height, no per-hero crowd scaling.
	var gallery:=Node3D.new();root.add_child(gallery)
	var camera:=Camera3D.new();gallery.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=10.2;camera.position.z=10;camera.current=true
	var light:=DirectionalLight3D.new();gallery.add_child(light);light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.4
	var labels:=Control.new();root.add_child(labels)
	var title:=Label.new();labels.add_child(title);title.text='30 HEROES / SAME STANDING HEIGHT / SIZE INSPECTION';title.position=Vector2(24,12)
	var sources:=Node2D.new();root.add_child(sources);sources.hide()
	var gallery_ids: Array=preload('res://scripts/heroes/HeroRosterCatalog.gd').HEROES.keys()
	for i in gallery_ids.size():
		var source:=HeroSpriteFactory.create_hero(gallery_ids[i]);sources.add_child(source);source.set_process(false)
		if source.has_method('play_visual'):source.observe_game=false;source.hold_demo=true
		source.play_idle('right')
		var paint=preload('res://scripts/art/HuntFramePilot.gd').new();gallery.add_child(paint);assert(paint.bind(source,true))
		paint.present(camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
		paint.position=Vector3((i%6-2.5)*2.5,3.1-int(i/6.0)*1.85,0)
		var name_label:=Label.new();labels.add_child(name_label);name_label.text=str(gallery_ids[i]);name_label.position=camera.unproject_position(paint.position)+Vector2(-35,6)
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join('thirty-heroes-same-height.png'))==OK)
	camera.size=13.0;title.text='30 HEROES / ORIGINAL PAINTED ATTACK CONTACT'
	for paint in gallery.get_children():
		if not paint.has_method('debug_snapshot'):continue
		paint.timeline.release('attack_1',.15)
		var point: Vector3=paint.position;paint.present(camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false);paint.position=point
	for i in gallery_ids.size():labels.get_child(i+1).position=camera.unproject_position(gallery.get_child(i+1).position)+Vector2(-35,6)
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join('thirty-heroes-original-attack.png'))==OK)
	gallery.free();sources.free();labels.free()
	gallery=Node3D.new();root.add_child(gallery);camera=Camera3D.new();gallery.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12.4;camera.position.z=10;camera.current=true
	light=DirectionalLight3D.new();gallery.add_child(light);light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.4
	labels=Control.new();root.add_child(labels);title=Label.new();labels.add_child(title);title.text='13 MONSTERS + 3 BOSSES / ORIGINAL PAINTED BODIES';title.position=Vector2(24,12)
	sources=Node2D.new();root.add_child(sources);sources.hide()
	var monster_ids: Array=preload('res://scripts/art/HuntFrameCatalog.gd').MONSTERS.keys()
	for i in monster_ids.size():
		var source:=MonsterSpriteFactory.create_monster(monster_ids[i]);MonsterSpriteFactory.apply_casual(source,monster_ids[i]);sources.add_child(source);source.set_process(false);source.play_idle('right')
		var paint=preload('res://scripts/art/HuntFramePilot.gd').new();gallery.add_child(paint);assert(paint.bind(source,false));paint.present(camera,1.6 if i<13 else 2.2,Color.WHITE,0,true,Vector2.ZERO,{},false)
		paint.position=Vector3((i%4-1.5)*4.0,3.0-int(i/4.0)*2.7,0)
		var name_label:=Label.new();labels.add_child(name_label);name_label.text=str(paint.entry.id);name_label.position=camera.unproject_position(paint.position)+Vector2(-35,6)
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join('original-monsters-and-bosses.png'))==OK)
	gallery.free();sources.free();labels.free();game.queue_free();await settle();print('ART25D_CAPTURE_OK');quit.call_deferred()
