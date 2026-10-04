extends SceneTree
var game: Node
var output: String
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for frame in 8:await process_frame
func shot(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	print('UX_CAPTURE ',label)
func run() -> void:
	if DisplayServer.get_name()=='headless':quit(1);return
	output=ProjectSettings.globalize_path('res://checks/simple-ux/captures');DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://ux-preview-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(game);await settle();game.set_process(false);game.set_physics_process(false)
	game.tutorial_completed=true;game._offline_checked=true;game.selected_faction='aurelia';game.idle_stage=35
	game.wallet_gold=48260;game.wallet_gems=180;game.raid_crystals=120
	game._restore_deployed_heroes(['leonhardt','mira','elisia','kairen','orwin'])
	for hero: Dictionary in game._hero_roster_for_faction():game.hero_progress[str(hero.id)]={'level':25,'xp':460}
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await settle()
	game._build_combat_screen();await settle();game.combat_running=true;await shot('hunt')
	game.portrait_hud._toggle_options();await shot('hunt-controls');game.portrait_hud._toggle_options()
	game._show_main_menu();await shot('menu-battle')
	var menu=game.content_root.get_node('PortraitActionSheet');menu._select_group('heroes');await shot('menu-heroes')
	menu._select_group('account');await shot('menu-account');menu.close();await settle()
	game._build_boss_select_screen();await shot('challenges')
	game.set_meta('content_meta_tab','daily');game._build_meta_hub_screen();await shot('daily')
	game._build_hero_detail_screen('mira');await shot('hero')
	game._roll_equipment_drop(game._current_zone());game._build_inventory_screen();await shot('bag')
	game._build_combat_screen();game._show_main_menu();root.size=Vector2i(1920,1080);await shot('menu-wide')
	game.presentation_runtime.audio.shutdown();game.queue_free();await create_timer(.4).timeout;quit()
