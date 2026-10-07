extends SceneTree

const KITS = preload("res://scripts/heroes/HeroKitRuntime.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _prepare(main, hp := 600) -> void:
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["elisia", "leonhardt", "mira"])
	main._setup_hero_skills()
	main.active_screen = "combat"
	main.combat_running = true
	main._application_suspended = false
	main.battle_speed = 1.0
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	main.enemy_wave.clear()
	main.party_movement.positions.clear()
	main.roaming_hunt.configure(Vector2(1, 2), 5303)
	main.roaming_hunt.clear_enemies()
	main.roaming_wave_spawn_cooldown = 10.0
	main.hunt_ai.set_state(AutoHuntController.State.MOVING)
	main._skill_spacing = 0.0
	for state in main.hero_battle_state.values():
		state["max_hp"] = 1000
		state["hp"] = hp
		state["ultimate"] = 0.0
		state["alive"] = true
	for runtime in main.hero_skill_runtime.values():
		runtime["remaining"] = 1000.0
		runtime["secondary_remaining"] = 1000.0
		runtime["attack_remaining"] = 0.0
		runtime["passive_remaining"] = 1000.0
	main.hero_skill_runtime["elisia"]["remaining"] = 0.0
	main._sync_party_hp_from_heroes()

func _steps(main, seconds: float) -> void:
	for _tick in int(round(seconds / .05)):
		main._advance_auto_hunt(.05)

func _test_patrol_and_loot_heals(main) -> void:
	for state in [AutoHuntController.State.MOVING, AutoHuntController.State.LOOTING]:
		_prepare(main)
		main.hunt_ai.set_state(state)
		main.hero_battle_state["leonhardt"]["hp"] = 300
		main._sync_party_hp_from_heroes()
		_check(main._should_use_skill("elisia"), "fixture has a useful ready heal before state %d" % state)
		_steps(main, .4)
		_check(main.hero_battle_state["leonhardt"]["hp"] > 300, "natural state %d heals the injured ally without a living enemy" % state)
		_check(main.hero_skill_runtime["elisia"]["remaining"] > 0.0, "state %d successful heal starts the existing skill cooldown" % state)
		_check(int(main.hero_skill_runtime["elisia"].get("casts_a1", 0)) == 1, "state %d settles exactly one heal, with no duplicate support/combat tick" % state)
		_check(main.hunt_ai.state != AutoHuntController.State.RECOVERING, "ordinary patrol healing does not force recovery")

func _test_emergency_before_retreat(main) -> void:
	_prepare(main, 180)
	_check(main._should_enter_hunt_recovery() and main._should_use_skill("elisia"), "critical fixture has both retreat pressure and a ready useful heal")
	_steps(main, .4)
	_check(main.party_hp > 540, "critical party gives ready support a chance before automatic recovery")
	_check(main.hunt_ai.state != AutoHuntController.State.RECOVERING, "successful emergency heal prevents an unnecessary retreat")
	_check(int(main.hero_skill_runtime["elisia"].get("casts_a1", 0)) == 1, "emergency rescue consumes its normal cooldown exactly once")
	_prepare(main, 180)
	main.hero_skill_runtime["elisia"]["remaining"] = 10.0
	_steps(main, .05)
	_check(main.hunt_ai.state == AutoHuntController.State.RECOVERING, "an unavailable healer does not indefinitely delay necessary recovery")
	_prepare(main, 180)
	main.hero_battle_state["elisia"]["hp"] = 0
	main.hero_battle_state["elisia"]["alive"] = false
	main._sync_party_hp_from_heroes()
	_steps(main, .05)
	_check(main.hunt_ai.state == AutoHuntController.State.RECOVERING, "dead support cannot defer the party's retreat")
	_prepare(main, 0)
	for state in main.hero_battle_state.values(): state["alive"] = false
	main._sync_party_hp_from_heroes()
	_steps(main, .05)
	_check(main.hunt_ai.state == AutoHuntController.State.RECOVERING, "party wipe still immediately enters recovery")
	_check(int(main.hero_skill_runtime["elisia"].get("casts_a1", 0)) == 0, "dead healer cannot spend resources or cast during wipe recovery")

func _test_pause_and_resource_safety(main) -> void:
	_prepare(main, 1000)
	_steps(main, .5)
	_check(int(main.hero_skill_runtime["elisia"].get("casts_a1", 0)) == 0, "healthy patrol retains healing cooldowns")
	_prepare(main)
	main.hero_battle_state["leonhardt"]["hp"] = 300
	main._sync_party_hp_from_heroes()
	main.combat_running = false
	_steps(main, .5)
	_check(main.hero_battle_state["leonhardt"]["hp"] == 300 and main.hero_skill_runtime["elisia"]["remaining"] == 0.0, "paused hunt never heals or spends support cooldowns")
	main.combat_running = true
	main._application_suspended = true
	_steps(main, .5)
	_check(main.hero_battle_state["leonhardt"]["hp"] == 300 and main.hero_skill_runtime["elisia"]["remaining"] == 0.0, "suspended hunt never advances support actions")
	_prepare(main)
	main.hero_battle_state["leonhardt"]["hp"] = 300
	for runtime in main.hero_skill_runtime.values():
		runtime["remaining"] = 0.0
		runtime["secondary_remaining"] = 0.0
	_steps(main, .4)
	_check(main.hero_skill_runtime["mira"]["remaining"] == 0.0 and main.hero_skill_runtime["mira"]["secondary_remaining"] == 0.0, "support phase never spends offensive skills without enemies")
	_check(main.hero_skill_runtime["leonhardt"]["remaining"] == 0.0 and main.hero_skill_runtime["leonhardt"]["secondary_remaining"] == 0.0, "support phase never spends empty-field guard or barrier cooldowns")
	_prepare(main)
	main.hero_battle_state["leonhardt"]["hp"] = 300
	main._sync_party_hp_from_heroes()
	_steps(main, .05)
	for state in main.hero_battle_state.values(): state["hp"] = state["max_hp"]
	main._sync_party_hp_from_heroes()
	_steps(main, .4)
	_check(main.hero_skill_runtime["elisia"]["remaining"] == 0.0, "a now-unneeded queued heal cancels without spending its cooldown")

func _test_secondary_support(main) -> void:
	_prepare(main)
	main.hero_battle_state["leonhardt"]["hp"] = 300
	main.hero_battle_state["mira"]["hp"] = 320
	main._sync_party_hp_from_heroes()
	main.hero_skill_runtime["elisia"]["remaining"] = 10.0
	main.hero_skill_runtime["elisia"]["secondary_remaining"] = 0.0
	_steps(main, .4)
	_check(main.hero_battle_state["leonhardt"]["hp"] > 300 and main.hero_battle_state["mira"]["hp"] > 320, "patrol support can use the available secondary heal while primary is cooling down")
	_check(main.hero_battle_state["leonhardt"]["shield"] > 0 and main.hero_battle_state["mira"]["shield"] > 0, "secondary heal retains its matching shield recipients")
	_check(int(main.hero_skill_runtime["elisia"].get("casts_a2", 0)) == 1, "secondary support settles once")

func _close_enemy(main, target: String, attack := 1) -> void:
	main.enemy_wave = [{"hp":10000, "max_hp":10000, "attack":attack, "row":0, "archetype":"brute", "target_id":target, "attack_remaining":0.0}]
	main.roaming_hunt.spawn_group(main.enemy_wave)
	main.roaming_hunt.enemy_positions.assign([Vector2(1.4, 2.0)])
	main.roaming_hunt.enemy_home_positions.assign([Vector2(1.4, 2.0)])
	main.roaming_hunt.party_position = Vector2(1, 2)
	main.expedition_position = main.roaming_hunt.party_position
	for id in main.hero_battle_state: main.party_movement.positions[id] = Vector2(1, 2)
	main.roaming_hunt.aggro_active = true
	main.roaming_hunt.current_target = 0
	main.roaming_hunt.mode = RoamingHuntDirector.Mode.ENGAGED
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main._sync_enemy_wave_summary()

func _test_support_during_fight(main) -> void:
	_prepare(main, 180)
	for runtime in main.hero_skill_runtime.values(): runtime["attack_remaining"] = 1000.0
	main.hero_skill_runtime["elisia"]["attack_remaining"] = 0.0
	_close_enemy(main, "leonhardt")
	main._advance_auto_hunt(.05)
	_check(main.enemy_wave[0]["attack_remaining"] > 0.5, "emergency support does not freeze the enemy's attack clock")
	_check(main.hero_skill_runtime["elisia"]["windup"] >= .10, "support and combat loops cannot advance the same new windup twice in one tick")
	_steps(main, .35)
	_check(int(main.hero_skill_runtime["elisia"].get("casts_a1", 0)) == 1, "emergency support in live combat settles once across both loops")
	_check(main.hunt_ai.state != AutoHuntController.State.RECOVERING, "successful combat heal prevents unnecessary retreat without freezing battle")
	_prepare(main, 180)
	main.hero_skill_runtime["elisia"]["attack_remaining"] = 1.0
	_steps(main, .05)
	_check(main.hunt_ai.state == AutoHuntController.State.RECOVERING, "a healer waiting on its action clock cannot prolong a dangerous rescue window")

func _test_support_encounter_transitions(main) -> void:
	_prepare(main, 180)
	main.roaming_wave_spawn_cooldown = 0.0
	_steps(main, .4)
	_check(int(main.hero_skill_runtime["elisia"].get("casts_a1", 0)) == 1, "spawning the next pack preserves an already scheduled ally heal")
	_check(main.hunt_ai.state != AutoHuntController.State.RECOVERING and main.party_hp > 540, "pack respawn cannot cancel a viable emergency rescue")
	_prepare(main, 180)
	_close_enemy(main, "leonhardt")
	main.roaming_hunt.aggro_active = false
	main.roaming_hunt.current_target = -1
	main.roaming_hunt.mode = RoamingHuntDirector.Mode.PATROL
	main.hunt_ai.set_state(AutoHuntController.State.MOVING)
	_steps(main, .4)
	_check(int(main.hero_skill_runtime["elisia"].get("casts_a1", 0)) == 1, "new aggro acquisition preserves an already scheduled ally heal")
	_check(main.hunt_ai.state != AutoHuntController.State.RECOVERING and main.party_hp > 540, "entering combat cannot cancel a viable emergency rescue")

func _test_disengaged_actions_resume_support(main) -> void:
	_prepare(main)
	main.hero_battle_state["leonhardt"]["hp"] = 300
	main._sync_party_hp_from_heroes()
	main.roaming_hunt.configure(Vector2(16, 10), 53032)
	main.expedition_position = Vector2(16, 10)
	main.party_movement.configure(main.deployed_heroes, main.hero_battle_state, Vector2(16, 10))
	main.enemy_wave = [{"hp":10000, "max_hp":10000, "attack":1, "row":0, "archetype":"brute", "attack_remaining":1000.0}]
	main.roaming_hunt.spawn_group(main.enemy_wave)
	main.roaming_hunt.enemy_positions.assign([Vector2(23, 10)])
	main.roaming_hunt.enemy_home_positions.assign([Vector2(23, 10)])
	main.roaming_hunt.enemy_wander_targets.assign([Vector2(23, 10)])
	main.roaming_hunt.aggro_active = true
	main.roaming_hunt.current_target = 0
	main.roaming_hunt.mode = RoamingHuntDirector.Mode.ENGAGED
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main._sync_enemy_wave_summary()
	# A healer was preparing a basic hit and an archer an offensive skill when
	# their enemy left the engagement. Neither stale action belongs to patrol.
	main.hero_skill_runtime["elisia"]["windup"] = .15
	main.hero_skill_runtime["elisia"]["cast"] = false
	main.hero_skill_runtime["mira"]["windup"] = .15
	main.hero_skill_runtime["mira"]["cast"] = true
	var origin: Vector2 = main.party_movement.positions["elisia"]
	_steps(main, 1.0)
	_check(main.hunt_ai.state == AutoHuntController.State.MOVING, "distant enemy naturally releases combat into patrol")
	_check(main.hero_skill_runtime["elisia"]["windup"] < 0.0 and main.hero_skill_runtime["mira"]["windup"] < 0.0, "disengagement clears stale basic and offensive skill windups")
	_check(main.hero_battle_state["leonhardt"]["hp"] > 300 and int(main.hero_skill_runtime["elisia"].get("casts_a1", 0)) == 1, "released healer can schedule and settle patrol healing")
	_check(Vector2(main.party_movement.positions["elisia"]).distance_to(origin) > .1, "released healer rejoins movement instead of remaining frozen in attack anticipation")
	_check(main.enemy_wave[0]["hp"] == 10000 and int(main.hero_skill_runtime["mira"].get("casts_a1", 0)) == 0, "abandoned offensive action causes no remote hit or cooldown consumption")

func _test_tank_survival(main) -> void:
	for fixture in [["leonhardt", "aurelia", "mira", "elisia"], ["garm", "noxfera", "valeria", "morgas"]]:
		_prepare(main, 1000)
		var tank: String = fixture[0]
		main.selected_faction = fixture[1]
		main._restore_deployed_heroes([tank, fixture[2], fixture[3]])
		main._setup_hero_skills()
		for state in main.hero_battle_state.values():
			state["hp"] = 1000
			state["max_hp"] = 1000
			state["ultimate"] = 0.0
		for runtime in main.hero_skill_runtime.values():
			runtime["remaining"] = 1000.0
			runtime["secondary_remaining"] = 1000.0
			runtime["attack_remaining"] = 1000.0
		main.hero_battle_state[tank]["hp"] = 100
		main.hero_skill_runtime[tank]["remaining"] = 0.0
		main.hero_skill_runtime[tank]["attack_remaining"] = 0.0
		main._sync_party_hp_from_heroes()
		_close_enemy(main, tank, 200)
		main.enemy_wave[0]["attack_remaining"] = 1000.0
		_check(main._should_use_skill(tank), tank + " protects its own critical HP despite a healthy back line")
		main._advance_hunt_attacks(.05)
		main._advance_hunt_attacks(.2)
		_check(main.hero_battle_state[tank]["guard"] > 0.0 and main.hero_skill_runtime[tank]["remaining"] > 0.0, tank + " uses actual guard and cooldown in the production fight loop")
		if tank == "garm":
			_check(main.hero_battle_state[tank]["hp"] == 180, "Garm retains the existing 8 percent self-heal without a coefficient change")
		main.hero_battle_state[tank]["guard"] = 0.0
		main.hero_battle_state[tank]["hp"] = 100
		main.hero_battle_state[tank]["ultimate"] = 100.0
		main._sync_party_hp_from_heroes()
		_check(main._should_use_ultimate(tank), tank + " can use ready defensive ultimate for its own survival")
		main.hero_battle_state[tank]["hp"] = 1000
		main.hero_skill_runtime[tank]["remaining"] = 0.0
		main._sync_party_hp_from_heroes()
		_check(not main._should_use_skill(tank), tank + " still holds guard against harmless single-target combat when healthy")

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	_test_patrol_and_loot_heals(main)
	_test_emergency_before_retreat(main)
	_test_pause_and_resource_safety(main)
	_test_secondary_support(main)
	_test_support_during_fight(main)
	_test_support_encounter_transitions(main)
	_test_disengaged_actions_resume_support(main)
	_test_tank_survival(main)
	main.free()
	await create_timer(.3).timeout
	print("v53_hunt_support checks=%d failures=%d" % [checks, failures.size()])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks":checks, "failures":failures}, "\t"))
	quit(0 if failures.is_empty() else 1)
