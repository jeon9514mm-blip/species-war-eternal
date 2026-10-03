extends SceneTree
const DESIGN=preload('res://scripts/RaidBossDesign.gd')
const FIELD=preload('res://scripts/RaidBattlefield.gd')
var game: Node
var output: String
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for i in 12:await process_frame
func capture(label: String) -> void:
	await settle()
	if game.raid_running:await create_timer(.85).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	print('RAID_QUALITY_CAPTURE ',label,' viewport=',game.get_viewport_rect().size)
func run() -> void:
	if DisplayServer.get_name()=='headless':push_error('A display renderer is required.');quit(1);return
	output=ProjectSettings.globalize_path('res://checks/raid-strength-quality/captures');DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://raid-quality-preview-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(game);await settle();game.set_process(false);game.set_physics_process(false);game._offline_checked=true
	game.tutorial_completed=true;game.selected_faction='aurelia';game.idle_stage=100;game.party_slot_legacy_cap=10;game.wallet_gold=48260;game.wallet_gems=1280;game.raid_crystals=240
	game._restore_deployed_heroes(['leonhardt','mira','elisia','kairen','orwin','seria','astel','darius','lunea','caelum'])
	for hero: Dictionary in game.deployed_heroes:game.hero_progress[str(hero.id)]={'level':35,'xp':0}
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await settle()
	game._build_boss_select_screen();await capture('raid-catalog')
	root.size=Vector2i(1600,720);await capture('raid-catalog-wide')
	root.size=Vector2i(960,540);await capture('raid-catalog-small')
	root.size=Vector2i(1280,720);await settle();game.idle_stage=1;game._build_boss_select_screen();await capture('raid-catalog-locked');game.idle_stage=100
	for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
		game.selected_raid_id=zone;game._build_raid_screen();await capture(zone+'-ready')
		game._start_raid();game.combat_timer.stop();game.set_process(false)
		var view=game.content_root.get_node('PortraitRaidView')
		game.raid_elapsed=34.5;game.raid_phase=2;game.raid_boss_hp=int(game.raid_boss_max_hp*.58)
		game.boss_telegraph_pending=true;game.boss_telegraph_remaining=.9
		game.raid_cast_profile=DESIGN.pattern(zone,2);game.boss_telegraph_skill=game.raid_cast_profile.name
		var targets: Array[Vector2]=[Vector2(390,390),Vector2(490,430)]
		game.raid_pattern_shape=FIELD.footprint(str(game.raid_cast_profile.kind),game.raid_boss_position,targets,game.raid_cast_profile)
		view.refresh();await capture(zone+'-warning')
		game.boss_telegraph_pending=false;game.raid_running=false
	game._build_raid_screen();game._start_raid();game.combat_timer.stop();game.set_process(false)
	for hero_id: String in game._alive_hero_ids():
		for hit in 8:game._incoming_damage_to_hero(hero_id,1000000)
	game._finish_raid('defeat');await capture('raid-defeat')
	game._start_raid();game.combat_timer.stop();game.set_process(false);await capture('raid-retry')
	game._build_hero_detail_screen('mira');await capture('hero-after-quality-pass')
	game.presentation_runtime.audio.shutdown();await create_timer(.3).timeout;game.free();await settle();quit()
