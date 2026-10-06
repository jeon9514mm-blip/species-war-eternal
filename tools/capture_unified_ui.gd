extends SceneTree
## Actual production UI captures using a separate test save, never a user account.
var game: Node
var folder: String
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for i in 6:await process_frame
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder.path_join(label+'.png'))==OK)
	print('UI_CAPTURE ',label,' viewport=',game.get_viewport_rect().size)
	if game.active_screen=='raid':
		var view=game.content_root.get_node('PortraitRaidView')
		print('RAID_RECTS stage=',view.stage.size,' terrain=',view.battlefield_3d.size,' subviewport=',view.battlefield_3d.viewport_3d.size,' container=',view.battlefield_3d.get_node('Live3DViewport').size)
func run() -> void:
	if DisplayServer.get_name()=='headless':push_error('UI capture requires a display renderer.');quit(1);return
	var output:='res://checks/unified-ui/captures'
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with('--output='):output=arg.trim_prefix('--output=')
	folder=ProjectSettings.globalize_path(output);DirAccess.make_dir_recursive_absolute(folder)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://unified-ui-capture-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(game);await settle();game.set_process(false);game.set_physics_process(false);game._offline_checked=true
	var quick: bool='--combat-only' in OS.get_cmdline_user_args()
	game.sound_effects_enabled=false;game.combat_effects_enabled=false;game.tutorial_completed=true
	game.selected_faction='aurelia';game.idle_stage=100;game.party_slot_legacy_cap=10
	game.wallet_gold=48260;game.wallet_gems=840
	game.loot_inventory=[{'id':'ui-weapon','name':'성역 수호자의 검','slot':'weapon','rarity':'전설','level':8,'set':'월광'},{'id':'ui-armor','name':'숲 파수꾼의 갑옷','slot':'armor','rarity':'희귀','level':5},{'id':'ui-charm','name':'새벽의 목걸이','slot':'accessory','rarity':'희귀','level':6}]
	var ids: Array[String]=[]
	for hero in game._hero_roster_for_faction().slice(0,10):ids.append(str(hero.id))
	game._restore_deployed_heroes(ids)
	for id in ids:game.hero_progress[id]={'level':60,'xp':180}
	game.presentation_options.orientation='portrait';root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	await settle()
	for entry in [['lobby','_build_lobby_screen'],['heroes','_build_hero_select_screen'],['growth','_build_growth_screen'],['inventory','_build_inventory_screen'],['content','_build_meta_hub_screen'],['summon','_build_summon_screen'],['world','_build_world_map_screen'],['rewards','_build_bm_screen'],['war','_build_faction_war_screen']]:
		if quick:continue
		game.call(entry[1]);await capture(entry[0])
	if not quick:
		game._build_hero_detail_screen(ids[0]);await capture('hero-detail')
		game._build_lobby_screen();game._show_main_menu();await capture('menu')
	game._build_combat_screen();await settle();if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	game.combat_running=false
	await capture('hunt')
	game.portrait_hud._toggle_options();await capture('hunt-settings');game.portrait_hud._toggle_options()
	game.selected_raid_id='moonrest_forest';game._build_raid_screen();await capture('raid')
	game.presentation_options.orientation='landscape';root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await settle()
	game._build_combat_screen();await settle();if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	game.combat_running=false;await capture('hunt-landscape')
	game._build_raid_screen();await capture('raid-landscape')
	game.presentation_options.orientation='portrait';root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280);await settle()
	game._build_combat_screen();await settle();game.combat_running=false
	for serial in range(1,9):
		for enemy in game.enemy_wave:enemy.hp=0
		game._finish_hunt_target();game.invasion.clock+=4;game.invasion.serial=serial-1
		preload('res://scripts/HuntFieldService.gd').admit(game)
		game.portrait_hud.refresh()
		await capture('entry-'+game.roaming_hunt.entry_side(serial).id)
	# A real scaled mobile window also checks the viewport/overlay coordinate path.
	game.selected_raid_id='moonrest_forest';game._build_raid_screen();await settle()
	game._start_raid();if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	game.boss_telegraph_pending=true;game.boss_telegraph_remaining=.9
	game.raid_cast_profile=preload('res://scripts/RaidBossDesign.gd').pattern('moonrest_forest',2)
	game.boss_telegraph_skill=game.raid_cast_profile.name
	game.raid_pattern_shape=preload('res://scripts/RaidBattlefield.gd').footprint(str(game.raid_cast_profile.kind),game.raid_boss_position,[Vector2(390,390),Vector2(490,430)],game.raid_cast_profile)
	game.content_root.get_node('PortraitRaidView').refresh();await capture('raid-warning')
	root.size=Vector2i(450,800);await settle();await capture('raid-mobile-scale')
	game.presentation_runtime.audio.shutdown();await create_timer(.3).timeout;game.free();await process_frame;quit()
