extends SceneTree
## Actual simulated combat; isolated save path, no actor poses or HP overrides.
var game: Node
var output: String
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 8:await process_frame
func capture(name: String) -> void:
	if is_instance_valid(game.portrait_hud):game.portrait_hud.refresh()
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+'.png'))
func run() -> void:
	output=OS.get_environment('HUNT_CAPTURE_DIR')
	if output.is_empty():output='/tmp/hunt-coordination-captures'
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	game=preload('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://hunt-coordination-preview-'+str(Time.get_ticks_usec())+'.json'
	game._offline_checked=true;root.add_child(game);await settle()
	game.set_process(false);game.set_physics_process(false)
	game.sound_effects_enabled=false;game.combat_effects_enabled=true;game.tutorial_completed=true
	game.selected_faction='aurelia';game.party_slot_legacy_cap=10;game.loot_rng.seed=1004;game.wallet_gold=10000
	var ids: Array[String]=[]
	for hero in preload('res://scripts/HeroRosterCatalog.gd').roster('aurelia'):
		ids.append(str(hero.id));game.hero_progress[str(hero.id)]={'level':60,'xp':0}
	game._restore_deployed_heroes(ids);game.idle_stage=154;game._build_combat_screen();await settle()
	game.combat_running=true
	for n in 300:
		game._advance_auto_hunt(.1)
		if n%10==0:await process_frame
	print('CAPTURE_BODY_CLEARANCE ',preload('res://scripts/HuntBodyCollision.gd').overlapping(game))
	await capture('hunt-10-heroes')
	game._toggle_hunt_details();await capture('hunt-efficiency')
	game._toggle_hunt_details()
	game.presentation_options.performance='battery';game.presentation_runtime.apply()
	await capture('hunt-battery')
	var field: Control=game.combat_labels.terrain
	var point:=Vector2(16,10)
	assert(field.local_to_world(field.project_world(point)).distance_to(point)<.02)
	print('BATTERY_PROJECTION_OK logical=',field.size,' render=',field.viewport_3d.size)
	game.presentation_options.performance='balanced';game.presentation_runtime.apply()
	game._build_inventory_screen();await settle();game._bulk_enhance_equipped();await capture('bulk-enhance-preview')
	print('HUNT_COORDINATION_CAPTURE ',output)
	game.presentation_runtime.audio.shutdown();game.background_hunt.discard()
	game.queue_free();await settle();await create_timer(.8).timeout;quit()
