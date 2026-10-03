extends SceneTree
const DESIGN=preload('res://scripts/RaidBossDesign.gd')
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=='headless':push_error('Raid capture requires a display renderer.');quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path('res://checks/raid-quality/captures'))
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	var game=load('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://raid-quality-capture.json';root.add_child(game)
	for i in 4:await process_frame
	game._offline_checked=true;game.sound_effects_enabled=false;game.combat_effects_enabled=false
	game.selected_faction='aurelia';game.party_slot_legacy_cap=10;game.idle_stage=100
	game._restore_deployed_heroes(['leonhardt','mira','elisia','kairen','orwin','seria','astel','darius','lunea','caelum'])
	for zone in ['gray_meadow','forgotten_mine','moonrest_forest']:
		game.selected_raid_id=zone;game._build_raid_screen()
		await create_timer(.9).timeout
		var view=game.content_root.get_node('PortraitRaidView')
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png('res://checks/raid-quality/captures/'+zone+'-mobile.png')
		# An actual boss pattern is rendered through the production warning overlay.
		game._start_raid();game.combat_timer.stop();game.set_process(false)
		game.boss_telegraph_pending=true;game.boss_telegraph_remaining=.9
		game.raid_cast_profile=DESIGN.pattern(zone,2);game.boss_telegraph_skill=game.raid_cast_profile.name
		var origin: Vector2=game.raid_boss_position
		game.raid_pattern_shape=preload('res://scripts/RaidBattlefield.gd').footprint(str(game.raid_cast_profile.kind),origin,[Vector2(390,390),Vector2(490,430)],game.raid_cast_profile)
		view.refresh()
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png('res://checks/raid-quality/captures/'+zone+'-warning.png')
		game.boss_telegraph_pending=false;game.raid_running=false
	game.presentation_runtime.audio.shutdown();await create_timer(.3).timeout
	game.free();await process_frame;quit()
