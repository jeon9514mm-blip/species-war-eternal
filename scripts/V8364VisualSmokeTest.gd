extends "res://scripts/V83UpgradeTestBase.gd"
func _init() -> void:run.call_deferred()
func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var folder:=OS.get_environment('MAP_CAPTURE_DIR')
	if not folder.is_empty():check(root.get_texture().get_image().save_png(folder.path_join(label+'.png'))==OK,'capture '+label)
func orient(main,landscape: bool) -> void:
	main.presentation_options.orientation='landscape' if landscape else 'portrait'
	preload('res://scripts/DisplayOrientation.gd').apply(main,false)
	root.size=Vector2i(1280,720) if landscape else Vector2i(720,1280)
	await settle();main._apply_portrait_resize();await settle()
func run() -> void:
	var main=await make_main('aurelia',10)
	main._build_combat_screen();await settle()
	main.combat_running=false
	var terrain=main.combat_labels.terrain
	terrain._toggle_overview();await capture('ice-overview-portrait');terrain._toggle_overview()
	# A labelled fixture makes densely overlapping, injured units reproducible.
	for bar in main.hero_hp_bars.values():bar.value=25
	for bar in main.enemy_hp_bars:bar.value=50
	main.roaming_hunt.aggro_active=true;main.roaming_hunt.current_target=0
	await capture('injured-labels-portrait')
	await orient(main,true);await capture('injured-labels-landscape')
	for zone in ['forgotten_mine','moonrest_forest']:
		main.current_zone_id=zone;main._build_combat_screen();await settle()
		main.combat_running=false
		await capture(zone+'-landscape')
	main.selected_raid_id='gray_meadow';main._build_raid_screen();await settle()
	main._start_raid();main.combat_timer.stop();main._advance_raid_encounter(.1)
	await orient(main,false);await capture('ice-raid-portrait')
	var raid=main.content_root.get_node('PortraitRaidView')
	# Reproducible warning geometry, without advancing or changing damage rules.
	raid.set_process(false);main.set_process(false)
	raid.telegraph.active=true
	raid.telegraph.shape=preload('res://scripts/RaidBattlefield.gd').footprint('double_lane',Vector2(635,397),[Vector2(519,383)])
	raid.telegraph.progress=.55
	await capture('raid-warning-portrait')
	main._finish_raid('cancelled');await dispose(main)
	main=await make_main('noxfera',10)
	main._build_combat_screen();await settle();main.combat_running=false
	await capture('noxfera-hunt-portrait')
	await dispose(main);done('v8364_visual')
