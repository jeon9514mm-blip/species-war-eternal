extends SceneTree
## Real default game, isolated saves and deterministic simulated combat.
var game: Node
var output: String
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 3:await process_frame
func capture(label: String,field: Control) -> void:
	if not field.raid_mode and is_instance_valid(game.portrait_hud):game.portrait_hud.refresh()
	await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	var environments: Array=[]
	for node in field.map_root.find_children('*','WorldEnvironment',true,false):
		var env: Environment=node.environment
		if env!=null:environments.append({'ssao':env.ssao_enabled,'sdfgi':env.sdfgi_enabled,'glow':env.glow_enabled})
	var scenery_meshes: Array=[]
	for mesh in field.map_root.find_children('*','MeshInstance3D',true,false):
		var actor_part:=false
		for actor in field.actors.values():
			if actor==mesh or actor.is_ancestor_of(mesh):actor_part=true;break
		if not actor_part:scenery_meshes.append(mesh)
	var state: Dictionary={'capture' :label,'renderer':RenderingServer.get_current_rendering_method(),'size':[root.size.x,root.size.y],'map_meshes':scenery_meshes.size(),'ground':(field.rune_ground.stone_material.get_shader_parameter('stone_art') as Texture2D).resource_path,'raid':field.raid_mode,'zone':field.zone_id}
	assert(state.map_meshes==1,'Only the new artist stone floor is allowed')
	assert(state.ground==preload('res://scripts/FieldArtCatalog.gd').texture_path(field.zone_id),'Approved biome ground must be loaded')
	var file:=FileAccess.open(output.path_join(label+'.json'),FileAccess.WRITE)
	file.store_string(JSON.stringify(state,'  '));file.close()
	print('MEADOW_APPLIED_CAPTURE ',label,' camera=',field.camera.size)
func run() -> void:
	if DisplayServer.get_name()=='headless':quit(1);return
	output=ProjectSettings.globalize_path('res://checks/rune-stone-applied/captures')
	if RenderingServer.get_current_rendering_method()=='forward_plus':
		output=ProjectSettings.globalize_path('res://checks/rune-stone-applied/forward-plus/captures')
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
		if OS.get_environment('MAP_CAPTURE_RAID_ONLY')=='1':continue
		if OS.get_environment('MAP_CAPTURE_ZONE')!='' and zone!=OS.get_environment('MAP_CAPTURE_ZONE'):continue
		seed(20261005)
		game=preload('res://scenes/PortraitMain.tscn').instantiate()
		game.save_state_path='user://meadow-applied-'+zone+'-'+str(Time.get_ticks_usec())+'.json'
		game._offline_checked=true;root.add_child(game);await settle()
		game.set_process(false);game.set_physics_process(false)
		game.sound_effects_enabled=false;game.combat_effects_enabled=true;game.tutorial_completed=true
		game.selected_faction='aurelia';game.party_slot_legacy_cap=10;game.loot_rng.seed=20261005
		game.current_zone_id=zone;game.idle_stage=54
		var ids: Array[String]=[]
		for hero in preload('res://scripts/HeroRosterCatalog.gd').roster('aurelia'):
			if ids.size()<3:
				ids.append(str(hero.id));game.hero_progress[str(hero.id)]={'level':35,'xp':0}
		game._restore_deployed_heroes(ids);game._build_combat_screen();await settle()
		var ready_field: Control=game.combat_labels.terrain
		ready_field._resize_world();ready_field._process(0);ready_field.rune_ground._process(0)
		await capture(zone+'-ready',ready_field)
		game.combat_running=true
		for n in 100:
			game._advance_auto_hunt(.1)
			if n%10==0:await process_frame
		var field: Control=game.combat_labels.terrain
		field._resize_world();field._process(0)
		await capture(zone+'-combat',field)
		game.presentation_runtime.audio.shutdown();game.background_hunt.discard()
		game.queue_free();await settle()
	game=null
	await settle();await RenderingServer.frame_post_draw;await settle()
	quit.call_deferred()
