extends SceneTree
## Screenshots of the real renderer with controlled time advancement. Warnings
## are reached through the production encounter update, not assigned by fixtures.
var game: Node
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for i in 12:await process_frame
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var output:=ProjectSettings.globalize_path("res://checks/raid-quality-01/captures")
	DirAccess.make_dir_recursive_absolute(output)
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK)
	print("RAID_DESIGN_CAPTURE ",label," elapsed=",game.raid_elapsed," hp=",game.raid_boss_hp)
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Use the display renderer for captures.");quit(1);return
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	game=load("res://scenes/art/RaidDesignLab.tscn").instantiate()
	root.add_child(game);await settle()
	game.set_process(false);game.set_physics_process(false)
	for zone: String in ["gray_meadow","forgotten_mine","moonrest_forest"]:
		game.selected_raid_id=zone;game._build_raid_screen();await capture(zone+"-ready")
		game._start_raid();game.combat_timer.stop()
		var guard:=0
		while game.raid_running and not game.boss_telegraph_pending and guard<600:
			game._advance_raid_encounter(.05);guard+=1
		game.content_root.get_node("PortraitRaidView").refresh()
		assert(game.boss_telegraph_pending,"A natural boss warning must occur.")
		# Simulation is intentionally stopped for a stable inspection frame; allow
		# the real-time phase transition banner to finish before capturing the cast.
		await create_timer(1.3).timeout
		await capture(zone+"-warning")
		game._finish_raid("cancelled")
	var view=game.content_root.get_node("PortraitRaidView")
	view._open_options();await capture("options")
	view.options_sheet.hide()
	game._start_raid();game.combat_timer.stop()
	for id: String in game._alive_hero_ids():
		for hit in 8:game._incoming_damage_to_hero(id,1000000)
	game._finish_raid("defeat");await capture("defeat")
	game._start_raid();game.combat_timer.stop();await capture("retry")
	game.presentation_runtime.audio.shutdown()
	game.free();await settle();quit()
