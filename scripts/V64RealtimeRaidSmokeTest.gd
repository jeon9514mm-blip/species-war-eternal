extends SceneTree
## Checks gameplay positions against the same shapes rendered by the arena.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("Realtime raid: " + label)

func _run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	var field := preload("res://scripts/RaidBattlefield.gd")
	var designs := preload("res://scripts/RaidBossDesign.gd")
	var game := preload("res://scenes/PortraitMain.tscn").instantiate()
	game.save_state_path="user://v64-raid-motion-test.json"
	root.add_child(game)
	for i in 6: await process_frame
	game.combat_effects_enabled=false
	game.selected_faction="aurelia"
	game.idle_stage=40
	game.deployed_heroes=game._hero_roster_for_faction().slice(0,10)
	for zone in ["gray_meadow", "forgotten_mine", "moonrest_forest"]:
		game.deployed_heroes=game._hero_roster_for_faction().slice(0,10)
		game.selected_raid_id=zone
		game._build_raid_screen()
		for i in 5: await process_frame
		game._start_raid()
		game.combat_timer.stop()
		var view=game.content_root.get_node("PortraitRaidView")
		_check(view.dodge_button!=null and view.skill_cast_button!=null and view.boss_motion.actor==game.raid_boss_sprite,zone+" has dodge, manual skills and moving boss art")
		var first: String=str(game.deployed_heroes[0]["id"])
		var second: String=str(game.deployed_heroes[1]["id"])
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
		view.hero_slots[second].gui_input.emit(click)
		_check(view.selected_hero_id==second,zone+" hero card selects a controllable spell caster")
		game.hero_battle_state[second]["ultimate"]=100.0
		if preload("res://scripts/HeroKitRuntime.gd").can_use(game,second,"ultimate"):
			_check(game._raid_manual_cast(true,second) and float(game.hero_battle_state[second]["ultimate"])<100.0,zone+" manual ultimate consumes the selected hero gauge")
		var original: Vector2=game.raid_positions[first]
		game._advance_raid_encounter(.05)
		_check(game.raid_boss_position.distance_to(field.ENTRY)>0.1,zone+" boss walks during live combat")
		game._raid_order_move(Vector2(245,460))
		for step in 12:game._advance_raid_encounter(.05)
		_check(game.raid_positions[first].distance_to(original)>15.0,zone+" heroes travel toward touch orders")
		game.raid_rally_active=false
		var kind: String=str(designs.pattern(zone,2)["kind"])
		var profile: Dictionary=designs.pattern(zone,2)
		var inside: Vector2
		match kind:
			"earthquake":inside=field.clamp_to_floor(game.raid_boss_position+Vector2(-160,0))
			"rear_blast":inside=Vector2(400,390)
			"moon_mark":inside=Vector2(415,390)
		var shape: Dictionary=field.footprint(kind,game.raid_boss_position,[inside])
		_check(field.contains(shape,inside),zone+" visual attack shape contains its center")
		var safe: Vector2=field.escape_position(shape,inside)
		_check(not field.contains(shape,safe),zone+" has a reachable safe floor spot")
		for id in game._alive_hero_ids():game.raid_positions[id]=inside
		game.raid_pattern_shape=shape
		var hp_before: int=int(game.hero_battle_state[first]["hp"])
		game._apply_boss_pattern(profile)
		_check(int(game.hero_battle_state[first]["hp"])<hp_before,zone+" pattern hits heroes still in the footprint")
		game.raid_positions[first]=safe
		hp_before=int(game.hero_battle_state[first]["hp"])
		game._apply_boss_pattern(profile)
		_check(int(game.hero_battle_state[first]["hp"])==hp_before,zone+" moved hero avoids the same footprint")
		game.raid_positions[first]=inside
		game._raid_dodge()
		hp_before=int(game.hero_battle_state[first]["hp"])
		game._apply_boss_pattern(profile)
		_check(int(game.hero_battle_state[first]["hp"])==hp_before and game.raid_dodge_cooldown>4.9,zone+" dodge grants short immunity and starts cooldown")
		view.refresh()
		_check(view.telegraph.active==false or view.telegraph.shape==game.raid_second_wave_shape or view.telegraph.shape==game.raid_pattern_shape,zone+" warning uses simulated shape")
		game._finish_raid("cancelled")
	if game.presentation_runtime != null:game.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	game.free()
	await create_timer(0.35).timeout
	print("v64_realtime_raid ",checks-failures.size(),"/",checks," pass")
	quit(0 if failures.is_empty() else 1)
