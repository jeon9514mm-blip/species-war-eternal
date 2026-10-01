extends SceneTree
var main: Node
var out := '/mnt/data/portrait-preview'
func _init() -> void:
	run.call_deferred()
func shot(view: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var error:=image.save_png(out.path_join(view+'.png'))
	print('CAPTURE ',view,' ',image.get_size(),' ',error)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(720,1560)
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction='aurelia';main.idle_stage=8
	main.wallet_gold=6560;main.wallet_gems=100
	main.tutorial_completed=true
	main._offline_checked=true
	main._restore_deployed_heroes(['leonhardt','mira','elisia'])
	main._setup_hero_progress(main._hero_roster_for_faction())
	for hero in main.deployed_heroes:
		main.hero_progress[str(hero['id'])]={'level':12,'xp':43}
	main.loot_rng.seed=350123
	main._build_combat_screen()
	await process_frame
	for i in 260:
		main._advance_auto_hunt(.05)
		if i%30==0:await process_frame
	main.portrait_hud.refresh()
	await shot('combat-portrait-20x9')
	main._build_hero_select_screen()
	await shot('heroes-portrait')
	main._build_inventory_screen()
	await shot('inventory-portrait')
	main._build_meta_hub_screen()
	await shot('growth-portrait')
	main._build_lobby_screen()
	await shot('lobby-portrait')
	main._build_raid_screen()
	main._start_raid()
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	for i in 20:main._advance_raid_encounter(.05)
	await shot('raid-portrait')
	main._build_faction_war_screen()
	await shot('war-portrait')
	main._build_combat_screen()
	await process_frame
	root.size=Vector2i(720,1280)
	for i in 10:await process_frame
	await shot('combat-portrait-16x9')
	main._clear_screen()
	main.free()
	quit()
