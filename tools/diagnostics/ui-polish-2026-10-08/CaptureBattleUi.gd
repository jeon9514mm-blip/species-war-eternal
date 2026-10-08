extends SceneTree
## Native review only: isolated save, real menus, presentation effects off for clarity.
var game: Node
var output: String
var captures: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for frame in 12:await process_frame
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var pixels:=root.get_texture().get_image()
	assert(pixels.save_png(output.path_join(label+'.png'))==OK)
	captures.append({'file':label+'.png','width':pixels.get_width(),'height':pixels.get_height(),'active_screen':game.active_screen})
func freeze() -> void:
	game.set_process(false);game.set_physics_process(false)
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
func run() -> void:
	assert(DisplayServer.get_name()!='headless')
	output=ProjectSettings.globalize_path('res://checks/ui-polish-2026-10-08/battle')
	DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://ui-battle-review-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(game);await settle();freeze()
	root.size=Vector2i(1280,720);await settle()
	game._offline_checked=true;game.tutorial_completed=true
	game.selected_faction='noxfera';game.current_zone_id='gray_meadow';game.idle_stage=154
	game.wallet_gold=49000;game.wallet_gems=840;game.party_slot_legacy_cap=10
	game.combat_effects_enabled=false;game.sound_effects_enabled=false
	var ids: Array[String]=[]
	for hero in game._hero_roster_for_faction().slice(0,10):
		ids.append(str(hero.id));game.hero_progress[str(hero.id)]={'level':60,'xp':0}
	game._restore_deployed_heroes(ids);game._build_combat_screen();freeze()
	for step in 120:game._advance_auto_hunt(.05)
	game.portrait_hud.refresh();await capture('hunt')
	game.portrait_hud._toggle_options();await capture('hunt-options')
	game.portrait_hud._set_options_visible(false)
	game._open_battle_formation();await capture('formation')
	game.content_root.get_node('FormationOverlay').free()
	root.size=Vector2i(960,540);await capture('hunt-small')
	root.size=Vector2i(1280,720);await settle()
	game.selected_raid_id='gray_meadow';game._build_raid_screen();freeze();await capture('raid-ready')
	game._start_raid();freeze()
	for step in 40:game._advance_raid_encounter(.05)
	# The real entrance curtain uses wall-clock tween time, not simulated raid time.
	await create_timer(1.05).timeout
	await capture('raid-running')
	var notes: Dictionary={'native_godot_pixels':true,'player_save_used':false,'performance_measurement':false,
		'fixture':'Stage154/Level60/49,000gold/840gems; actual production menu/battle calls; effects disabled only in this disposable UI review.',
		'captures':captures}
	FileAccess.open(output.path_join('capture-fixture.json'),FileAccess.WRITE).store_string(JSON.stringify(notes,'\t'))
	game.presentation_runtime.audio.shutdown();await create_timer(.3).timeout
	game.free();await settle();print('BATTLE_UI_CAPTURE_OK captures=',captures.size());quit()
