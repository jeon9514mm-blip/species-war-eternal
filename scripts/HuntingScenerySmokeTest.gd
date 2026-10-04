extends "res://scripts/ArtDirectionPilotSmokeTest.gd"
const SCENERY = preload("res://scripts/art/HuntingSceneryCatalog.gd")

func run() -> void:
	if not prepare_sentinels():
		finish()
		return
	root.content_scale_size=Vector2i(1280,720)
	root.size=Vector2i(1280,720)
	for scene: String in [PILOT_SCENE,"res://scenes/art/CanyonHuntArtLab.tscn","res://scenes/art/ElvenRuinsHuntArtLab.tscn"]:
		var game=load(scene).instantiate()
		root.add_child(game)
		await settle(12)
		game.set_process(false)
		game.set_physics_process(false)
		game.presentation_runtime.audio.shutdown()
		game.combat_effects_enabled=false
		game.sound_effects_enabled=false
		var field=game.combat_labels.terrain
		field.set_process(false)
		var zone: String=game.current_zone_id
		var theme: String=SCENERY.theme_for_zone(zone)
		check(field.art_theme==theme and field.world.art_theme==theme,"zone selects its matching scenery: "+zone)
		var state: Dictionary=gameplay_snapshot(game)
		var point:=Vector2(12,8)
		var before: Vector2=field.project_world(point)
		field.backdrop.atmosphere_time=12.25
		for next: String in SCENERY.IDS:
			field.set_art_theme(next)
			await settle()
			check(gameplay_snapshot(game)==state and game.current_zone_id==zone,"scenery selection preserves actual hunt and RNG: "+next)
			check(is_equal_approx(field.backdrop.atmosphere_time,12.25),"selection retains frozen atmosphere clock: "+next)
			check(field.project_world(point).distance_to(before)<.001,"selection retains actor projection: "+next)
			check(field.backdrop.layer_manifest().size()==(21 if next=="meadow" else 18),"actual layer composition: "+next)
			check(field.world.find_children("*","CollisionObject3D",true,false).is_empty(),"scenery has no hunting collisions: "+next)
			check(field.world.get_node("MeadowProps").get_child_count()==12,"twelve grounded peripheral props: "+next)
			check(field.world.get_node("QuietPlayLawn").material_override.get_shader_parameter("ground_art").resource_path==SCENERY.profile(next).ground,"actual floor uses selected painting: "+next)
			check(field.backdrop.foreground_clear_rect().is_equal_approx(field.safe_play_rect()),"foreground protects hunting area: "+next)
		field.set_art_theme(theme)
		field.set_process(true)
		await test_geometry(game)
		await test_atmosphere_clock(game)
		await test_directions(game,zone)
		await create_timer(1.2).timeout
		check(not FileAccess.file_exists(game.save_state_path),"actual rewards never create a pilot autosave: "+zone)
		check_sentinels(zone+" hunting")
		game.set_process(false)
		game.set_physics_process(false)
		game.presentation_runtime.audio.shutdown()
		game.free()
		await settle()
	finish()
