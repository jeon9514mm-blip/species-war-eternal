extends "res://scripts/V83UpgradeTestBase.gd"
func _init() -> void: run.call_deferred()
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var folder:=OS.get_environment('MAP_CAPTURE_DIR')
	if not folder.is_empty():check(root.get_texture().get_image().save_png(folder.path_join(label+'.png'))==OK,'capture '+label)
func run() -> void:
	var main=await make_main('aurelia',10)
	main._build_combat_screen();await settle()
	for i in 40:main._advance_auto_hunt(.1)
	main.combat_running=false;await capture('ice-hunt-portrait')
	main.presentation_options.orientation='landscape';preload('res://scripts/DisplayOrientation.gd').apply(main,false);root.size=Vector2i(1280,720)
	await settle();main._apply_portrait_resize();await capture('ice-hunt-landscape')
	main.selected_raid_id='gray_meadow';main._build_raid_screen();await settle();main._start_raid();main.combat_timer.stop();main._advance_raid_encounter(.1)
	await capture('ice-raid-landscape')
	main._finish_raid('cancelled');await dispose(main);done('v8363_ice_visual')
