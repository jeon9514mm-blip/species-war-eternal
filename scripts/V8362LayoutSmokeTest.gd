extends "res://scripts/V83UpgradeTestBase.gd"
func _init() -> void: _run.call_deferred()
func capture(label: String) -> void:
	var directory: String=OS.get_environment("V8362_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"capture "+label)
func orient(main,choice: String) -> void:
	main.presentation_options.orientation=choice
	preload("res://scripts/DisplayOrientation.gd").apply(main,false)
	root.size=Vector2i(1280,720) if choice=="landscape" else Vector2i(720,1280)
	await settle();main._apply_portrait_resize();await settle()
func _run() -> void:
	var main=await make_main("aurelia",10)
	main._build_combat_screen();await settle()
	for i in 130: main._advance_auto_hunt(.1)
	main.combat_running=false
	await capture("hunt-portrait")
	await orient(main,"landscape");await capture("hunt-landscape")
	main._open_battle_formation();await settle();await capture("formation-landscape")
	main.content_root.get_node("FormationOverlay").free()
	main._open_presentation_settings();await settle();await capture("settings-landscape")
	main.content_root.get_node("PresentationSettingsOverlay").free()
	main.selected_raid_id="gray_meadow";main._build_raid_screen();await settle();await capture("raid-landscape")
	main._start_raid();main.combat_timer.stop();main._advance_raid_encounter(.1)
	var hp: int=main.raid_boss_hp;var heroes: Dictionary=main.hero_battle_state.duplicate(true)
	await orient(main,"portrait");await capture("raid-portrait")
	check(main.raid_boss_hp==hp and main.hero_battle_state==heroes and main.raid_running,"raid rotation preserves active battle")
	await orient(main,"landscape");check(main.raid_boss_hp==hp and main.raid_running,"raid rotates back without reset")
	main._finish_raid("cancelled");main._build_lobby_screen();await settle();await capture("lobby-landscape")
	main._build_growth_screen();await settle();await capture("growth-landscape")
	await dispose(main);done("v8362_layout")
