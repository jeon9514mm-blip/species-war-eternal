extends SceneTree
const ATLAS = preload("res://scripts/portrait/CasualMonsterAtlas.gd")
var checks: int = 0
var failures: Array[String] = []
var main: Node
func _init() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for frame in 8: await process_frame
func _run() -> void:
	var misses: int = ATLAS.cache_misses
	var first: AtlasTexture = ATLAS.frame("초원 고블린",0)
	var all_frames_valid: bool = true
	for index in 10000:
		var atlas: AtlasTexture = ATLAS.frame("초원 고블린",index % 4)
		all_frames_valid = all_frames_valid and atlas != null
	check(all_frames_valid, "all 10000 cached frame requests valid")
	check(ATLAS.cache_misses - misses == 4, "10001 requests allocate only four atlas frames")
	check(ATLAS.frame("초원 고블린",0) == first, "identical immutable atlas resource reused")
	check(ATLAS.frame("초원 고블린",100) == ATLAS.frame("초원 고블린",3), "pose sanitized before cache key")
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	main=preload("res://scenes/PortraitMain.tscn").instantiate();main.save_state_path="user://v82-performance.json"
	root.add_child(main);await settle();main.set_physics_process(false);main.set_process(false);main._offline_checked=true
	main.selected_faction="aurelia";main._restore_deployed_heroes(["leonhardt","mira","elisia"])
	main.combat_effects_enabled=false;main.sound_effects_enabled=false
	main._set_presentation_option("music_enabled",false,false)
	main._build_combat_screen();await settle()
	var hud: Node=main.portrait_hud;hud.set_process(false)
	var tick_rate: int=Engine.physics_ticks_per_second;var physics_delta: float=main.battle_speed
	var metrics: Dictionary={}
	for mode in ["balanced","battery"]:
		main._set_presentation_option("performance",mode,false)
		hud._elapsed=0.0;hud._power_elapsed=0.0
		var old_refresh: int=hud.refresh_count;var old_power: int=hud.power_evaluations
		for index in 200: hud._process(0.01)
		metrics[mode]={"hud":hud.refresh_count-old_refresh,"power":hud.power_evaluations-old_power}
	check(metrics["balanced"]["power"]<=4 and metrics["balanced"]["power"]>0,"power calculation amortized")
	check(metrics["battery"]["power"]<=2 and metrics["battery"]["hud"]<=10,"battery HUD frequency bounded")
	check(metrics["battery"]["hud"]<metrics["balanced"]["hud"],"fewer display refreshes in same two simulated seconds")
	check(Engine.physics_ticks_per_second==tick_rate and main.battle_speed==physics_delta,"physics and battle speed untouched")
	main._application_suspended=true;var before:int=hud.refresh_count
	for index in 50:hud._process(0.1)
	check(hud.refresh_count==before,"HUD does no repeated updates in background")
	main._application_suspended=false
	main.combat_effects_enabled=true;main.combat_fx.enabled=true
	var layer:Control=main.skill_fx_layer
	for index in 55:layer.add_child(Control.new())
	var count:int=main.combat_fx.projectile_sequence
	main.combat_fx.projectile(Vector2(50,50),Vector2(120,50),Color.WHITE)
	check(main.combat_fx.projectile_sequence==count,"optional projectile respects saturation")
	var danger:int=main.combat_fx.boss_telegraph_sequence
	main.combat_fx.boss_telegraph(Vector2(150,150),80,Color.RED,0.4,"test warning")
	check(main.combat_fx.boss_telegraph_sequence==danger+1,"boss warning never suppressed by optional budget")
	print("PERFORMANCE_COUNTS "+JSON.stringify(metrics)+" atlas_cache_misses_for_10001_requests=4 android_fps_measured=false")
	main.queue_free();await settle();await create_timer(0.12).timeout
	print("v82_performance checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
