extends "res://tests/regression/V29RosterKitSmokeTest.gd"
## Hero skill graphics were removed at the user's request. Verify actual casts
## still resolve identically with cosmetic settings ON/OFF, including passives.

func fixture(main, id: String, raid: bool) -> void:
	super.fixture(main, id, raid)
	main.raid_break_gauge = 0.0
	main.raid_second_wave_remaining = 0.0
	main.raid_interrupt_count = 0
	main._weaken_seconds = 0.0
	main._vulnerable_seconds = 0.0
	main._stun_seconds = 0.0

func combat_state(main) -> String:
	return JSON.stringify([main.hero_battle_state,main.enemy_wave,main.hero_skill_runtime,main._weaken_seconds,main._vulnerable_seconds,main._stun_seconds,main.raid_break_gauge,main.raid_control_immunity])

func no_skill_graphics(main) -> bool:
	return main.skill_fx_layer.get_node_or_null("HeroSkillClip") == null and main.skill_fx_layer.find_child("PortraitSkillBurst",true,false) == null and main.content_root.get_node_or_null("FieldUltimateNotice") == null and main.content_root.get_node_or_null("PortraitUltimateNotice") == null

func enable_cosmetics(main) -> void:
	main.combat_effects_enabled = true
	main.combat_fx.enabled = true
	for child in main.skill_fx_layer.get_children(): child.free()

func passive_fixture(main, id: String) -> void:
	fixture(main,id,false)
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

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_process(false);main.set_physics_process(false)
	main.sound_effects_enabled = false
	main.party_slot_legacy_cap = 10;main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt","mira","elisia"])
	main._build_combat_screen()
	if is_instance_valid(main.combat_timer): main.combat_timer.stop()
	await process_frame
	main.party_movement.positions.clear();main.expedition_position = Vector2(1,2)
	for raid in [false,true]:
		for id in CATALOG.HEROES:
			for skill_slot in ["a1","a2","ultimate"]:
				fixture(main,id,raid);enable_cosmetics(main)
				var canonical := JSON.stringify(CATALOG.skill(id,skill_slot))
				var damage_on := KITS.cast(main,id,skill_slot,0)
				var state_on := combat_state(main)
				_check(no_skill_graphics(main),"%s/%s/%s creates no removed skill graphics" % [id,skill_slot,"raid" if raid else "hunt"])
				_check(JSON.stringify(CATALOG.skill(id,skill_slot)) == canonical,"canonical skill unchanged")
				fixture(main,id,raid)
				var damage_off := KITS.cast(main,id,skill_slot,0)
				_check(damage_on == damage_off and state_on == combat_state(main),"cosmetic settings preserve combat state: %s/%s" % [id,skill_slot])
	for raid in [false,true]:
		for id in CATALOG.HEROES:
			fixture(main,id,raid);enable_cosmetics(main)
			var damage_on: int = main._cast_hero_skill(id) if raid else main._cast_combat_skill(id,0)
			var state_on := combat_state(main)
			_check(no_skill_graphics(main),id+" legacy A1 creates no removed graphics")
			fixture(main,id,raid)
			var damage_off: int = main._cast_hero_skill(id) if raid else main._cast_combat_skill(id,0)
			_check(damage_on == damage_off and state_on == combat_state(main),id+" legacy A1 combat state unchanged")
	for id in CATALOG.HEROES:
		passive_fixture(main,id);enable_cosmetics(main)
		var passive_profile := CATALOG.skill(id,"passive")
		var damage_on := 0
		for _i in int(passive_profile["every"]): damage_on += KITS.event(main,id,str(passive_profile["event"]),0)
		var state_on := combat_state(main)
		_check(int(main.hero_skill_runtime[id].get("passive_procs",0)) > 0,id+" passive actually activates")
		_check(no_skill_graphics(main),id+" passive creates no badge")
		passive_fixture(main,id)
		var damage_off := 0
		for _i in int(passive_profile["every"]): damage_off += KITS.event(main,id,str(passive_profile["event"]),0)
		_check(damage_on == damage_off and state_on == combat_state(main),id+" passive combat state unchanged")
	main.presentation_runtime.audio.shutdown()
	await create_timer(.35).timeout
	main.free();await create_timer(.3).timeout
	print("v31_hero_fx_removed checks=%d failures=%d kit_casts=180 main_a1_casts=60 passive_procs=30" % [checks,failures.size()])
	if not failures.is_empty(): push_error("; ".join(failures))
	quit(0 if failures.is_empty() else 1)
