extends SceneTree
## Real default game, isolated saves and deterministic simulated combat.
var game: Node
var output: String
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 3:await process_frame
func capture(label: String) -> void:
	game.portrait_hud.refresh();await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	print('MAP_PATCH_CAPTURE ',label,' camera=',game.combat_labels.terrain.camera.size)
func run() -> void:
	if DisplayServer.get_name()=='headless':quit(1);return
	output=ProjectSettings.globalize_path('res://checks/map-patch-01/captures')
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
		if OS.get_environment('MAP_CAPTURE_ZONE')!='' and zone!=OS.get_environment('MAP_CAPTURE_ZONE'):continue
		seed(20261005)
		game=preload('res://scenes/PortraitMain.tscn').instantiate()
		game.save_state_path='user://map-patch-'+zone+'-'+str(Time.get_ticks_usec())+'.json'
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
		game.combat_running=true
		for n in 100:
			game._advance_auto_hunt(.1)
			if n%10==0:await process_frame
		var field: Control=game.combat_labels.terrain
		field._resize_world();field._process(0)
		await capture(zone+'-combat')
		game.presentation_runtime.audio.shutdown();game.background_hunt.discard()
		game.queue_free();await settle()
	quit()
