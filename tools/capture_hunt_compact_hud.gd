extends SceneTree
## Review fixtures only; use isolated XDG directories to avoid player save data.
var game: Node
func _init() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	root.content_scale_size=Vector2i(1280,720); root.size=Vector2i(1280,720)
	game=preload("res://scenes/PortraitMain.tscn").instantiate()
	game.save_state_path="user://hunt-dock-preview-"+str(Time.get_ticks_usec())+".json"
	game._offline_checked=true;root.add_child(game);await settle()
	game.set_process(false);game.set_physics_process(false)
	game.selected_faction="aurelia";game.idle_stage=2;game.tutorial_completed=true
	game.sound_effects_enabled=false;game.combat_effects_enabled=true
	game.party_slot_legacy_cap=10
	var ids: Array[String]=[]
	for hero in preload("res://scripts/heroes/HeroRosterCatalog.gd").roster("aurelia"):
		if ids.size()<3:ids.append(str(hero.id))
	game._restore_deployed_heroes(ids);game._build_combat_screen();await settle()
	root.size=Vector2i(1280,720);await settle()
	game.combat_running=true
	for n in 25:game._advance_auto_hunt(.1)
	for i in ids.size():
		game.hero_battle_state[ids[i]].hp=float(game.hero_battle_state[ids[i]].max_hp)*(.85-i*.19)
		game.hero_battle_state[ids[i]].ultimate=34+i*28
	game.portrait_hud.refresh();await settle()
	var out:=OS.get_environment("HUNT_CAPTURE_DIR")
	if out.is_empty():out="/tmp/hunt-dock-preview"
	DirAccess.make_dir_recursive_absolute(out)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("hunt-3-heroes.png"))
	ids.clear()
	for hero in preload("res://scripts/heroes/HeroRosterCatalog.gd").roster("aurelia"):ids.append(str(hero.id))
	game.idle_stage=154
	game._restore_deployed_heroes(ids);ids=game._deployed_hero_ids();game._build_combat_screen();await settle()
	for n in 25:game._advance_auto_hunt(.1)
	for i in ids.size():
		game.hero_battle_state[ids[i]].hp=float(game.hero_battle_state[ids[i]].max_hp)*(.45+.05*i)
		game.hero_battle_state[ids[i]].ultimate=i*11
	game.portrait_hud.refresh();await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("hunt-10-heroes.png"))
	print("HUNT_DOCK_PREVIEW ",out)
	game.presentation_runtime.audio.shutdown();game.queue_free();await create_timer(.4).timeout;quit()
