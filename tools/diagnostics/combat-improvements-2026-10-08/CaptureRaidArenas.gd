extends SceneTree
## Actual production scene, disposable progress only; native pixels, no mockups.
var game: Node
var output: String
var captures: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for frame in 12:await process_frame
func freeze() -> void:
	game.set_process(false);game.set_physics_process(false)
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var pixels:=root.get_texture().get_image()
	assert(pixels.save_png(output.path_join(label+'.png'))==OK)
	var field=game.content_root.get_node('PortraitRaidView').battlefield_3d
	captures.append({'file':label+'.png','size':[pixels.get_width(),pixels.get_height()],
		'zone':game.raid_encounter_zone,'arena':field.map_root.get_meta('dedicated_raid_arena'),
		'phase':game.raid_phase,'running':game.raid_running,'boss_hp':game.raid_boss_hp,'boss_max_hp':game.raid_boss_max_hp})
func run() -> void:
	assert(DisplayServer.get_name()!='headless')
	output=ProjectSettings.globalize_path('res://checks/combat-improvements-2026-10-08/raids')
	DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://raid-arena-review-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(game);await settle();freeze()
	root.size=Vector2i(1280,720);await settle()
	game._offline_checked=true;game.tutorial_completed=true
	game.selected_faction='aurelia';game.current_zone_id='gray_meadow';game.idle_stage=154
	game.wallet_gold=49000;game.wallet_gems=840;game.party_slot_legacy_cap=10
	game.combat_effects_enabled=false;game.sound_effects_enabled=false
	var ids: Array[String]=[]
	for hero in game._hero_roster_for_faction().slice(0,10):
		ids.append(str(hero.id));game.hero_progress[str(hero.id)]={'level':60,'xp':0}
	game._restore_deployed_heroes(ids)
	for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
		game.selected_raid_id=zone;game._build_raid_screen();freeze()
		await capture(zone+'-ready')
		game._start_raid();freeze()
		for step in 12:game._advance_raid_encounter(.05)
		await create_timer(1.05).timeout
		await capture(zone+'-running')
		if zone=='moonrest_forest':
			root.size=Vector2i(960,540);await capture(zone+'-small')
			root.size=Vector2i(1280,720);await settle()
		game.raid_running=false
	var notes: Dictionary={'native_godot_pixels':true,'player_save_used':false,'performance_measurement':false,
		'fixture':'Actual PortraitMain/raid routes, 10 Aurelia heroes, Level60, Stage154; 0.60 seconds of actual raid simulation. Effects/sound disabled only in this UI/map review.',
		'captures':captures}
	FileAccess.open(output.path_join('capture-fixture.json'),FileAccess.WRITE).store_string(JSON.stringify(notes,'\t'))
	game.presentation_runtime.audio.shutdown();await create_timer(.3).timeout
	game.free();await settle();print('RAID_ARENA_CAPTURE_OK captures=',captures.size());quit()
