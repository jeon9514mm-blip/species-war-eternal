extends SceneTree

# Exercise committed actions, resource spending and encounter rewards through Main.
# Run in an isolated user-data directory, as the reward path saves progression.
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("V26 ACTION PASS: ", label)
	else:
		failures.append(label)
		print("V26 ACTION FAIL: ", label)

func _enemy(elite := false) -> Dictionary:
	return {
		"name": "Action safety target", "hp": 10000, "max_hp": 10000,
		"attack": 100, "row": 0, "archetype": "brute", "elite": elite,
		"attack_remaining": 1000.0
	}

func _prepare(main, hero_ids: Array, enemies: Array, positions: Array[Vector2]) -> void:
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main.current_zone_id = "gray_meadow"
	main.hero_progress = {}
	main.hero_equipment = {}
	main.hero_equipment_rarity = {}
	main.hero_equipment_names = {}
	main._restore_deployed_heroes(hero_ids)
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._setup_hero_skills()
	main.active_screen = "combat"
	main.combat_running = true
	main.battle_speed = 1.0
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	main.combat_engage_settle_remaining = 0.0
	main._skill_spacing = 0.0
	main._guard_seconds = 0.0
	main._weaken_seconds = 0.0
	main._vulnerable_seconds = 0.0
	main._stun_seconds = 0.0
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main.hunt_ai.encounter_id = 26
	main._rewarded_encounter = -1
	main.enemy_wave = enemies.duplicate(true)
	main.roaming_hunt.configure(Vector2(1.0, 2.0), 2602)
	main.roaming_hunt.spawn_group(main.enemy_wave)
	main.roaming_hunt.enemy_positions = positions.duplicate()
	main.roaming_hunt.aggro_active = true
	main.roaming_hunt.current_target = 0
	main.roaming_hunt.mode = RoamingHuntDirector.Mode.ENGAGED
	main.expedition_position = main.roaming_hunt.party_position
	main.pet_runtime["remaining"] = 1000.0
	main.party_power = main._calculate_party_power()
	for runtime in main.hero_skill_runtime.values():
		runtime["remaining"] = 1000.0
		runtime["attack_remaining"] = 1000.0
		runtime["windup"] = -1.0
		runtime["cast"] = false
		runtime["cast_ultimate"] = false
		runtime["target_index"] = -1
	main._sync_enemy_wave_summary()

func _test_tank_ultimate_coverage(main) -> void:
	_prepare(main, ["leonhardt", "orwin", "mira"], [_enemy(true), _enemy()], [Vector2(1.5, 2.0), Vector2(1.7, 2.0)])
	main.hero_battle_state["leonhardt"]["ultimate"] = 100.0
	main.hero_battle_state["orwin"]["ultimate"] = 100.0
	_check(main._should_use_ultimate("orwin"), "dangerous encounter permits an unprotected tank ultimate")
	main._cast_combat_ultimate("leonhardt", -1)
	_check(not main._should_use_ultimate("orwin"), "second tank holds ultimate while the whole party is protected")
	var second_tank: Dictionary = main.hero_skill_runtime["orwin"]
	second_tank["windup"] = 0.01
	second_tank["cast_ultimate"] = true
	second_tank["target_index"] = 0
	main._advance_hunt_attacks(0.05)
	_check(float(main.hero_battle_state["orwin"]["ultimate"]) == 100.0, "windup revalidation preserves the second tank ultimate gauge")
	for hero_id in main._alive_hero_ids():
		main.hero_battle_state[hero_id]["guard"] = 1.0
	_check(not main._should_use_ultimate("orwin"), "one full second of party protection still holds the ultimate")
	for hero_id in main._alive_hero_ids():
		main.hero_battle_state[hero_id]["guard"] = 0.4
	_check(main._should_use_ultimate("orwin"), "expiring party protection permits a useful refresh")

func _test_invalid_offensive_actions_preserve_resources(main) -> void:
	_prepare(main, ["mira"], [_enemy(), _enemy(), _enemy()], [Vector2(1.6, 2.0), Vector2(1.7, 2.0), Vector2(5.0, 2.0)])
	main.enemy_wave[1]["hp"] = 0
	main._sync_enemy_wave_summary()
	var runtime: Dictionary = main.hero_skill_runtime["mira"]
	var state: Dictionary = main.hero_battle_state["mira"]
	for target_index in [-1, 99, 1, 2]:
		runtime["remaining"] = 0.0
		state["ultimate"] = 100.0
		var before_hp := int(main.enemy_hp)
		var skill_damage := int(main._cast_combat_skill("mira", target_index))
		_check(skill_damage == 0 and float(runtime["remaining"]) == 0.0 and int(main.enemy_hp) == before_hp,
			"invalid/dead/distant skill target %d spends no cooldown and deals no damage" % target_index)
		var ultimate_damage := int(main._cast_combat_ultimate("mira", target_index))
		_check(ultimate_damage == 0 and float(state["ultimate"]) == 100.0 and int(main.enemy_hp) == before_hp,
			"invalid/dead/distant ultimate target %d preserves the full gauge" % target_index)

func _test_dead_windup_target_is_replaced(main) -> void:
	for action in ["basic", "skill", "ultimate"]:
		_prepare(main, ["mira"], [_enemy(), _enemy(true)], [Vector2(1.6, 2.0), Vector2(1.7, 2.0)])
		var runtime: Dictionary = main.hero_skill_runtime["mira"]
		runtime["remaining"] = 0.0 if action == "skill" else 1000.0
		runtime["windup"] = 0.01
		runtime["cast"] = action == "skill"
		runtime["cast_ultimate"] = action == "ultimate"
		runtime["target_index"] = 0
		main.hero_battle_state["mira"]["ultimate"] = 100.0 if action == "ultimate" else 0.0
		# Another actor kills the locked target after windup began.
		main.enemy_wave[0]["hp"] = 0
		main._advance_hunt_attacks(0.05)
		_check(int(runtime["target_index"]) == 1 and int(main.enemy_wave[1]["hp"]) < 10000,
			"%s windup retargets a living reachable enemy" % action)
		_check(int(main.enemy_wave[0]["hp"]) == 0 and int(main.combat_kills) == 0,
			"%s retarget does not revive the old target or falsely finish the wave" % action)
		if action == "skill":
			_check(float(runtime["remaining"]) > 0.0, "retargeted skill consumes cooldown only after landing")
		elif action == "ultimate":
			_check(float(main.hero_battle_state["mira"]["ultimate"]) == 0.0, "retargeted ultimate lands and then consumes its gauge")

func _test_pet_last_hit_rewards_once(main) -> void:
	_prepare(main, ["leonhardt"], [_enemy()], [Vector2(1.6, 2.0)])
	main.enemy_wave[0]["hp"] = 1
	main._sync_enemy_wave_summary()
	main.pet_runtime["remaining"] = 0.0
	main.combat_kills = 0
	main.idle_stage = 1
	main.idle_stage_kills = 0
	main.idle_stage_target = 20
	main.unclaimed_gold = 0
	main.unclaimed_xp = 0
	main.loot_rng.seed = 2602
	var zone: Dictionary = main._current_zone()
	var expected_gold := int(zone["gold"]) + int(zone["difficulty"]) * 7
	var expected_xp := int(zone["xp"]) + int(zone["difficulty"]) * 5
	main._advance_hunt_attacks(0.05)
	_check(int(main.enemy_hp) == 0 and int(main.combat_kills) == 1 and main.hunt_ai.state == AutoHuntController.State.LOOTING,
		"pet final hit completes the encounter and enters looting")
	_check(int(main.unclaimed_gold) == expected_gold and int(main.unclaimed_xp) == expected_xp,
		"pet final hit grants the exact encounter gold and XP")
	main._finish_hunt_target()
	main._advance_hunt_attacks(0.05)
	# The encounter identity must also reject a delayed duplicate after a state change.
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main._finish_hunt_target()
	_check(int(main.combat_kills) == 1 and int(main.unclaimed_gold) == expected_gold and int(main.unclaimed_xp) == expected_xp,
		"repeated final-hit callbacks cannot duplicate encounter rewards")

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.combat_kills = 0
	_test_tank_ultimate_coverage(main)
	_test_invalid_offensive_actions_preserve_resources(main)
	_test_dead_windup_target_is_replaced(main)
	_test_pet_last_hit_rewards_once(main)
	main.free()
	if not failures.is_empty():
		push_error("v26_action_safety_smoke_test_failed checks=%d failures=%d: %s" % [checks, failures.size(), "; ".join(failures)])
		quit(1)
		return
	print("v26_action_safety_smoke_test_ok checks=%d tank_guard=ok resources=ok retarget=ok pet_reward=ok" % checks)
	quit(0)
