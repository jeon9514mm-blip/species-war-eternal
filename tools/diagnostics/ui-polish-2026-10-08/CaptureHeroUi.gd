extends SceneTree
## Native menu captures use disposable progression data and the original paintings.
var game: Node
var output: String

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for frame in 10:
		await process_frame

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	print('HERO_UI_CAPTURE ',label,' viewport=',game.get_viewport_rect().size)

func task(key: String) -> void:
	var button: Button=game.content_root.find_child('HeroTab_'+key,true,false)
	assert(button!=null)
	button.pressed.emit()
	await settle()

func run() -> void:
	if DisplayServer.get_name()=='headless':
		push_error('Native renderer required for hero UI captures.')
		quit(1)
		return
	output=ProjectSettings.globalize_path('res://checks/ui-polish-2026-10-08/heroes')
	DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://ui-hero-preview-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.set_physics_process(false)
	game._offline_checked=true
	game.tutorial_completed=true
	game.selected_faction='aurelia'
	game.idle_stage=60
	game.wallet_gold=48260
	game.wallet_gems=1280
	game.raid_crystals=240
	game._restore_deployed_heroes(['leonhardt','mira','elisia','kairen','orwin'])
	for hero: Dictionary in game._hero_roster_for_faction():
		game.hero_progress[str(hero.id)]={'level':25,'xp':460}
	root.content_scale_size=Vector2i(1280,720)
	root.size=Vector2i(1280,720)
	await settle()
	game._build_hero_detail_screen('leonhardt')
	await task('growth')
	await capture('hero-growth')
	game._build_hero_detail_screen('mira')
	await task('skills')
	await capture('hero-skills')
	await task('equipment')
	await capture('hero-equipment')
	game.selected_faction='noxfera'
	game._restore_deployed_heroes(['valeria'])
	for hero: Dictionary in game._hero_roster_for_faction():
		game.hero_progress[str(hero.id)]={'level':25,'xp':460}
	game._build_hero_detail_screen('valeria')
	await task('skills')
	await capture('hero-noxfera-skills')
	game.presentation_runtime.audio.shutdown()
	await create_timer(.3).timeout
	game.free()
	await settle()
	print('HERO_UI_CAPTURE_OK')
	quit()
