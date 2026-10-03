extends SceneTree
## Capture the production landscape UI using a separate, disposable save file.
var game: Node
var output: String
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for i in 10:await process_frame
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	print('HERO_MENU_CAPTURE ',label,' viewport=',game.get_viewport_rect().size)
func tab(key: String) -> void:
	var button: Button=game.content_root.find_child('HeroTab_'+key,true,false)
	assert(button!=null);button.pressed.emit();await settle()
func run() -> void:
	if DisplayServer.get_name()=='headless':push_error('A display renderer is required.');quit(1);return
	output=ProjectSettings.globalize_path('res://checks/hero-menu/captures');DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://hero-menu-preview-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(game);await settle();game.set_process(false);game.set_physics_process(false);game._offline_checked=true
	game.tutorial_completed=true;game.selected_faction='aurelia';game.idle_stage=60;game.wallet_gold=48260;game.wallet_gems=1280;game.raid_crystals=240
	game._restore_deployed_heroes(['leonhardt','mira','elisia','kairen','orwin'])
	for hero: Dictionary in game._hero_roster_for_faction():game.hero_progress[str(hero.id)]={'level':25,'xp':460}
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await settle()
	game._build_hero_detail_screen('mira');await capture('hero-growth')
	await tab('skills');await capture('hero-skills')
	await tab('equipment');await capture('hero-equipment')
	await tab('ascension');await capture('hero-ascension')
	game._build_hero_detail_screen('leonhardt');await tab('growth');await capture('hero-leonhardt')
	game._build_hero_detail_screen('elisia');root.size=Vector2i(1600,720);await capture('hero-wide')
	root.size=Vector2i(960,540);await capture('hero-small')
	root.size=Vector2i(1280,720);await settle();game.current_zone_id='gray_meadow';game._build_combat_screen();await settle();game.combat_running=false
	game._show_main_menu();await capture('menu-hunt')
	root.size=Vector2i(1600,720);await capture('menu-wide')
	root.size=Vector2i(960,540);await capture('menu-small')
	game.content_root.get_node('PortraitActionSheet').close();game._build_inventory_screen();game._show_main_menu();await capture('menu-inventory')
	root.size=Vector2i(1280,720);await settle();game._build_hero_select_screen();await capture('party-roster')
	root.size=Vector2i(1600,720);await capture('party-roster-wide')
	root.size=Vector2i(1280,720);await settle();game._build_faction_screen();await capture('faction-selection')
	root.size=Vector2i(1280,720);await settle();game.selected_faction='noxfera';game._restore_deployed_heroes(['valeria']);game._build_hero_detail_screen('valeria');await capture('hero-noxfera')
	game.presentation_runtime.audio.shutdown();await create_timer(.3).timeout;game.free();await settle();quit()
