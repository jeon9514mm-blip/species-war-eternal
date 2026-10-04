extends SceneTree

# Behavioral regressions use the real Main combat loop and fixed field positions.
# No wall-clock timers, sprites, rewards, or user save data are needed.
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("V26 PASS: ", label)
	else:
		failures.append(label)
		print("V26 FAIL: ", label)

func _prepare(main, hero_ids: Array, enemies: Array, positions: Array[Vector2]) -> void:
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(hero_ids)
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._setup_hero_skills()
	main.active_screen = "combat"
	main.combat_running = true
	main.battle_speed = 1.0
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	main.combat_engage_settle_remaining = 0.0
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main.hunt_ai.state_time = 2.0
	main.enemy_wave = enemies.duplicate(true)
	# Fixtures are one registered live corps, so ordinary reinforcement cannot
	# retire a target lacking a corps identity during the range assertion.
	main.invasion.reset()
	main.invasion.register({})
	for enemy in main.enemy_wave: enemy["corps_id"] = main.invasion.serial
	main.roaming_hunt.configure(Vector2(1.0, 2.0), 2601)
	main.roaming_hunt.spawn_group(main.enemy_wave)
	main.roaming_hunt.enemy_positions = positions.duplicate()
	main.roaming_hunt.aggro_active = true
	main.roaming_hunt.current_target = 0
	main.roaming_hunt.mode = RoamingHuntDirector.Mode.ENGAGED
	main.expedition_position = main.roaming_hunt.party_position
	main.pet_runtime["remaining"] = 1000.0
	for runtime in main.hero_skill_runtime.values():
		runtime["remaining"] = 1000.0
		runtime["attack_remaining"] = 1000.0
		runtime["windup"] = -1.0
		runtime["cast"] = false
		runtime["cast_ultimate"] = false
	main._sync_enemy_wave_summary()

func _enemy(row := 0, archetype := "brute") -> Dictionary:
	return {
		"name": "Decision regression target", "hp": 10000, "max_hp": 10000,
		"attack": 100, "row": row, "archetype": archetype, "elite": false,
		"attack_remaining": 1000.0
	}

func _test_unreachable_front_hero_does_not_block_others(main) -> void:
	_prepare(main, ["leonhardt", "mira", "elisia"], [_enemy(0, "ranged")], [Vector2(2.2, 2.0)])
	# The first actor cannot reach 1.2 cells; the next actor and enemy can.
	main.hero_skill_runtime["leonhardt"]["windup"] = 0.01
	main.hero_skill_runtime["mira"]["windup"] = 0.01
	main.enemy_wave[0]["attack_remaining"] = 0.0
	var enemy_before := int(main.enemy_wave[0]["hp"])
	var party_before := int(main.party_hp)
	main._advance_hunt_attacks(0.05)
	_check(int(main.enemy_wave[0]["hp"]) < enemy_before, "out-of-range front hero does not starve ready ranged ally")
	_check(int(main.party_hp) < party_before, "out-of-range front hero does not skip enemy turn")

func _test_heal_finishes_without_an_enemy_in_attack_range(main) -> void:
	_prepare(main, ["leonhardt", "mira", "elisia"], [_enemy()], [Vector2(4.0, 2.0)])
	var tank: Dictionary = main.hero_battle_state["leonhardt"]
	tank["hp"] = int(int(tank["max_hp"]) * 0.30)
	main._sync_party_hp_from_heroes()
	var before := int(tank["hp"])
	var healer: Dictionary = main.hero_skill_runtime["elisia"]
	healer["remaining"] = 0.0
	healer["windup"] = 0.01
	healer["cast"] = true
	main._advance_hunt_attacks(0.05)
	_check(int(tank["hp"]) > before, "started emergency heal survives enemy leaving attack range")
	_check(float(healer["remaining"]) > 0.0, "successful emergency heal starts its cooldown")

func _test_distant_row_does_not_hide_adjacent_enemy(main) -> void:
	_prepare(main, ["leonhardt"], [_enemy(0), _enemy(1)], [Vector2(4.8, 2.0), Vector2(1.6, 2.0)])
	_check(main._select_enemy_target("leonhardt") == 1, "distant formation row does not block adjacent living enemy")
	main.hero_skill_runtime["leonhardt"]["windup"] = 0.01
	main._advance_hunt_attacks(0.05)
	_check(int(main.enemy_wave[1]["hp"]) < 10000, "melee damages adjacent enemy despite distant front row")
	_check(int(main.enemy_wave[0]["hp"]) == 10000, "melee does not damage distant enemy")

func _test_emergency_heal_starts_during_natural_chase(main) -> void:
	_prepare(main, ["leonhardt", "mira", "elisia"], [_enemy()], [Vector2(4.0, 2.0)])
	main.hunt_ai.set_state(AutoHuntController.State.MOVING)
	main.roaming_hunt.mode = RoamingHuntDirector.Mode.CHASE
	var tank: Dictionary = main.hero_battle_state["leonhardt"]
	tank["hp"] = int(int(tank["max_hp"]) * 0.30)
	main._sync_party_hp_from_heroes()
	var before := int(tank["hp"])
	main.hero_skill_runtime["elisia"]["remaining"] = 0.0
	main.hero_skill_runtime["elisia"]["attack_remaining"] = 0.0
	var minimum_distance := INF
	var all_damage_reachable := true
	for _step in 6:
		var enemy_hp_before := int(main.enemy_wave[0]["hp"])
		main._advance_auto_hunt(0.05)
		minimum_distance = minf(minimum_distance, main.roaming_hunt.enemy_distance(0))
		if int(main.enemy_wave[0]["hp"]) < enemy_hp_before:
			var reachable := false
			for hero_id in main._alive_hero_ids(): reachable = reachable or main._can_attack_enemy(hero_id, 0)
			all_damage_reachable = all_damage_reachable and reachable
	_check(minimum_distance > 1.75, "chase fixture keeps enemy far from the party anchor")
	_check(int(tank["hp"]) > before, "natural chase starts and completes emergency healing")
	_check(all_damage_reachable, "natural chase only deals damage within an individual hero attack range")

func _test_aoe_does_not_damage_disconnected_enemies(main) -> void:
	_prepare(main, ["caelum"], [_enemy(), _enemy(), _enemy()], [Vector2(1.6, 2.0), Vector2(1.7, 2.15), Vector2(5.7, 3.5)])
	main.hero_skill_runtime["caelum"]["remaining"] = 0.0
	main._cast_combat_skill("caelum", 0)
	_check(int(main.enemy_wave[0]["hp"]) < 10000 and int(main.enemy_wave[1]["hp"]) < 10000, "area skill damages its local enemy group")
	_check(int(main.enemy_wave[2]["hp"]) == 10000, "area skill cannot hit enemy across the field")
	for enemy in main.enemy_wave:
		enemy["hp"] = 10000
	main.hero_battle_state["caelum"]["ultimate"] = 100.0
	main._cast_combat_ultimate("caelum", 0)
	_check(int(main.enemy_wave[0]["hp"]) < 10000 and int(main.enemy_wave[1]["hp"]) < 10000, "area ultimate damages its local enemy group")
	_check(int(main.enemy_wave[2]["hp"]) == 10000, "area ultimate cannot hit enemy across the field")

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	_test_unreachable_front_hero_does_not_block_others(main)
	_test_heal_finishes_without_an_enemy_in_attack_range(main)
	_test_distant_row_does_not_hide_adjacent_enemy(main)
	_test_emergency_heal_starts_during_natural_chase(main)
	_test_aoe_does_not_damage_disconnected_enemies(main)
	main.free()
	if not failures.is_empty():
		push_error("v26_combat_decision_smoke_test_failed checks=%d failures=%d: %s" % [checks, failures.size(), "; ".join(failures)])
		quit(1)
		return
	print("v26_combat_decision_smoke_test_ok checks=%d independent_turns=ok emergency_heal=ok spatial_target=ok local_aoe=ok" % checks)
	quit(0)
