extends "res://tests/regression/V29RosterKitSmokeTest.gd"

func _fx(main) -> Array:
	var clip = main.skill_fx_layer.get_node_or_null("HeroSkillClip")
	return clip.get_children() if is_instance_valid(clip) else []

func _clear_fx(main) -> void:
	for child in _fx(main): child.free()
	# Each icon case is isolated. This tight loop does not advance render time;
	# remove previous hit shards/rings so the real optional FX budget starts empty.
	# The v82 performance test separately verifies saturation and warning priority.
	for child in main.skill_fx_layer.get_children():
		if child.name != "HeroSkillClip": child.free()

func fixture(main, id: String, raid: bool) -> void:
	super.fixture(main, id, raid)
	# v75 introduced a cumulative short-stun break gauge. Both halves of an
	# effects-on/off comparison must start from the SAME raid-control state.
	main.raid_break_gauge = 0.0
	main.raid_second_wave_remaining = 0.0
	main.raid_interrupt_count = 0
	main._weaken_seconds = 0.0
	main._vulnerable_seconds = 0.0
	main._stun_seconds = 0.0

func _enable(main) -> void:
	main.combat_effects_enabled = true
	main.combat_fx.enabled = true

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt","mira","elisia"])
	main._build_combat_screen()
	if is_instance_valid(main.combat_timer): main.combat_timer.stop()
	await process_frame
	# Normalize the first fixture just like later ones; setup reads movement origins.
	main.party_movement.positions.clear()
	main.expedition_position = Vector2(1,2)
	# Exercise every active/ultimate through the actual production cast path.
	for raid in [false,true]:
		for id in CATALOG.HEROES:
			for skill_slot in ["a1","a2","ultimate"]:
				fixture(main,id,raid)
				_enable(main)
				_clear_fx(main)
				var before_catalog := JSON.stringify(CATALOG.skill(id,skill_slot))
				var damage_on := KITS.cast(main,id,skill_slot,0)
				var state_on := JSON.stringify([main.hero_battle_state,main.enemy_wave,main.hero_skill_runtime,main._weaken_seconds,main._vulnerable_seconds,main._stun_seconds,main.raid_break_gauge,main.raid_control_immunity])
				var own = null
				for fx in _fx(main):
					if fx.hero_id == id and fx.slot == skill_slot: own = fx
				_check(is_instance_valid(own) and own.icon != null,"%s/%s/%s uses actual cast and unique icon" % [id,skill_slot,"raid" if raid else "field"])
				_check(JSON.stringify(CATALOG.skill(id,skill_slot)) == before_catalog,"canonical profile was not mutated")
				fixture(main,id,raid)
				var damage_off := KITS.cast(main,id,skill_slot,0)
				var state_off := JSON.stringify([main.hero_battle_state,main.enemy_wave,main.hero_skill_runtime,main._weaken_seconds,main._vulnerable_seconds,main._stun_seconds,main.raid_break_gauge,main.raid_control_immunity])
				_check(damage_on == damage_off and state_on == state_off,"effects toggle preserves all combat state: %s/%s" % [id,skill_slot])
	# The AI calls Main for A1, including the original twenty heroes' legacy path.
	for raid in [false,true]:
		for id in CATALOG.HEROES:
			fixture(main,id,raid)
			_enable(main)
			_clear_fx(main)
			var damage_on: int = main._cast_hero_skill(id) if raid else main._cast_combat_skill(id,0)
			var state_on := JSON.stringify([main.hero_battle_state,main.enemy_wave,main.hero_skill_runtime,main._weaken_seconds,main._vulnerable_seconds,main._stun_seconds,main.raid_break_gauge,main.raid_control_immunity])
			var own = null
			for fx in _fx(main):
				if fx.hero_id == id and fx.slot == "a1": own = fx
			_check(is_instance_valid(own) and own.icon != null,"%s/%s real Main A1 entry emits the hero signature" % [id,"raid" if raid else "field"])
			if is_instance_valid(own):
				var kind := str(own.profile.get("kind","damage"))
				if kind in ["guard","heal","barrier"]:
					_check(own.profile["fx_targets"].is_empty() and not own.profile["fx_allies"].is_empty(),"support A1 has only actual ally recipients")
				elif raid:
					_check(own.profile["fx_targets"] == [-1],"raid A1 anchors only to the real boss")
			fixture(main,id,raid)
			var damage_off: int = main._cast_hero_skill(id) if raid else main._cast_combat_skill(id,0)
			var state_off := JSON.stringify([main.hero_battle_state,main.enemy_wave,main.hero_skill_runtime,main._weaken_seconds,main._vulnerable_seconds,main._stun_seconds,main.raid_break_gauge,main.raid_control_immunity])
			_check(damage_on == damage_off and state_on == state_off,"Main A1 effects toggle preserves all combat state: " + id)
	# All thirty passive icons are reached by their real event/condition rules.
	for id in CATALOG.HEROES:
		fixture(main,id,false)
		_enable(main)
		_clear_fx(main)
		var passive_profile := CATALOG.skill(id,"passive")
		var runtime: Dictionary = main.hero_skill_runtime[id]
		runtime["secondary_remaining"] = 5.0
		runtime["kit_basic_count"] = 3
		runtime["kit_last_move_position"] = Vector2(-10,-10)
		main.hero_battle_state[id]["ultimate"] = 0.0
		main.hero_battle_state[id]["guard"] = 0.0 if id == "bora" else 1.0
		main.hero_battle_state[id]["shield"] = 10
		for enemy in main.enemy_wave:
			enemy["hp"] = 3000
			enemy["stun_seconds"] = 1.0
			enemy["weaken_seconds"] = 1.0
			enemy["vulnerable_seconds"] = 1.0
		for _i in int(passive_profile["every"]): KITS.event(main,id,str(passive_profile["event"]),0)
		var own = null
		for fx in _fx(main):
			if fx.hero_id == id and fx.slot == "passive": own = fx
		_check(is_instance_valid(own) and own.icon != null,id + " actual passive proc selects its unique icon")
	# A kill during Seria's volley must not visually invent three hits per recipient.
	fixture(main,"seria",false)
	_enable(main)
	_clear_fx(main)
	main.enemy_wave[0]["hp"] = 1
	main._cast_combat_skill("seria",0)
	var volley = _fx(main)[0]
	var hit_total := 0
	for count in volley.profile["fx_target_hits"].values(): hit_total += int(count)
	_check(hit_total == 3 and volley.profile["fx_target_hits"].size() == 2,"retargeted volley preserves exact per-target visual hit counts")
	# Recipient capture: the ally shield excludes its caster and uses the chosen low-HP ally.
	fixture(main,"leonhardt",false)
	_enable(main)
	_clear_fx(main)
	KITS.cast(main,"leonhardt","a2",0)
	var shield_fx = _fx(main)[0]
	_check(shield_fx.profile["fx_allies"].size() == 1 and shield_fx.profile["fx_allies"][0]["hero_id"] != "leonhardt","shield visual uses actual non-caster recipient")
	# Passive visuals only happen on a successful condition, once per proc.
	_clear_fx(main)
	main.hero_battle_state["leonhardt"]["guard"] = 0.0
	KITS.event(main,"leonhardt","hit",0)
	_check(_fx(main).is_empty(),"failed passive condition emits nothing")
	main.hero_battle_state["leonhardt"]["ultimate"] = 0.0
	main.hero_battle_state["leonhardt"]["guard"] = 1.0
	KITS.event(main,"leonhardt","hit",0)
	_check(_fx(main).size() == 1 and _fx(main)[0].slot == "passive","confirmed passive emits one badge")
	KITS.event(main,"leonhardt","hit",0)
	KITS.tick(main,.01)
	_check(_fx(main).size() == 1,"cooldown/tick never repeats passive badge")
	# Pause and application suspension do not advance the short burst.
	var passive = _fx(main)[0]
	passive.set_process(false)
	var before_time: float = passive.elapsed
	main.combat_running = false
	passive._process(.2)
	_check(passive.elapsed == before_time,"paused hunt freezes signature")
	main.combat_running = true
	main._application_suspended = true
	passive._process(.2)
	_check(passive.elapsed == before_time,"suspended application freezes signature")
	main._application_suspended = false
	passive._process(.1)
	_check(passive.elapsed > before_time,"resume advances signature")
	var clip = main.skill_fx_layer.get_node("HeroSkillClip")
	_check(clip.clip_contents and Rect2(clip.position,clip.size) == main.combat_field_rect,"signatures are clipped to the actual field")
	main.combat_effects_enabled = false
	passive._process(.01)
	_check(passive.is_queued_for_deletion(),"effects OFF clears existing signature")
	_clear_fx(main)
	KITS.event(main,"leonhardt","hit",0)
	_check(_fx(main).is_empty(),"effects OFF creates no new signature")
	# Screen changes and finite lifetime clean up without orphaned effects.
	_enable(main)
	main._emit_skill_cast_fx("mira",0,false,CATALOG.skill("mira","a1"))
	var burst = _fx(main)[0]
	main.active_screen = "heroes"
	burst._process(.01)
	_check(burst.is_queued_for_deletion(),"navigation cleans up existing signature")
	main.active_screen = "combat"
	_clear_fx(main)
	main._emit_skill_cast_fx("mira",0,false,CATALOG.skill("mira","a1"))
	burst = _fx(main)[0]
	burst._process(1.0)
	_check(burst.is_queued_for_deletion(),"signature expires after its finite lifetime")
	# Stop playback while its owner still exists, release cached WAV references,
	# then let the mixer acknowledge the stop before destroying the scene.
	if is_instance_valid(main.skill_audio_bus):
		main.skill_audio_bus.stop()
		main.skill_audio_bus.stream = null
	main._skill_sound_cache.clear()
	await create_timer(0.3).timeout
	main.free()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
	await process_frame
	print("v31_hero_fx checks=%d failures=%d kit_casts=180 main_a1_casts=60 passive_procs=30" % [checks,failures.size()])
	if not failures.is_empty(): push_error("; ".join(failures))
	quit(0 if failures.is_empty() else 1)
