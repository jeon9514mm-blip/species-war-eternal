extends SceneTree

const KITS = preload("res://scripts/HeroKitRuntime.gd")
const CATALOG = preload("res://scripts/HeroRosterCatalog.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _enemy(hp := 1000, attack := 80) -> Dictionary:
	return {"hp":hp, "max_hp":1000, "attack":attack, "row":0, "elite":false, "archetype":"brute", "attack_remaining":1000.0, "name":"전술 검증 표적"}

func _prepare(main, id: String, count := 3, raid := false) -> void:
	main.party_slot_legacy_cap = 10
	main.selected_faction = CATALOG.HEROES[id]["faction"]
	var ids: Array = [id]
	for other in CATALOG.HEROES:
		if CATALOG.HEROES[other]["faction"] == main.selected_faction and other != id and ids.size() < 3:
			ids.append(other)
	main._restore_deployed_heroes(ids)
	main._setup_hero_skills()
	main.party_movement.positions.clear()
	main.active_screen = "raid" if raid else "combat"
	main.combat_running = false
	main.raid_running = raid
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	main.enemy_wave = []
	for _index in count:
		main.enemy_wave.append(_enemy())
	main.roaming_hunt.configure(Vector2(1.0, 2.0), 5204)
	main.roaming_hunt.spawn_group(main.enemy_wave)
	var positions: Array[Vector2] = []
	for index in count:
		positions.append(Vector2(1.35 + index * .03, 2.0))
	main.roaming_hunt.enemy_positions = positions
	main.expedition_position = main.roaming_hunt.party_position
	main.raid_boss_hp = 10000
	main.raid_boss_max_hp = 10000
	main.raid_boss_attack = 120
	main.raid_control_immunity = 0.0
	main.boss_telegraph_pending = false
	main._skill_spacing = 0.0
	for state in main.hero_battle_state.values():
		state["hp"] = 1000
		state["max_hp"] = 1000
		state["attack"] = 100
		state["ultimate"] = 100.0
		state["shield"] = 0
		state["shield_seconds"] = 0.0
	for runtime in main.hero_skill_runtime.values():
		runtime["remaining"] = 0.0
		runtime["secondary_remaining"] = 0.0
		runtime["attack_remaining"] = 0.0
		runtime["passive_remaining"] = 10.0
	main._sync_enemy_wave_summary()
	main._sync_party_hp_from_heroes()

func _test_specific_targets(main) -> void:
	_prepare(main, "leonhardt")
	main.enemy_wave[0]["row"] = 2
	_check(main._can_attack_enemy("leonhardt", 0), "an adjacent enemy remains attackable regardless of its spawn row")
	var row_only: Dictionary = main.hero_battle_state["leonhardt"].duplicate(true)
	_check(not main.combat_decisions.can_attack_enemy(row_only, main.enemy_wave, 0), "row-only simulations retain front-line protection")
	main.roaming_hunt.enemy_positions[0] = Vector2(30.0, 18.0)
	_check(not main._can_attack_enemy("leonhardt", 0), "free-field row release never extends physical attack range")
	_prepare(main, "naia")
	main.enemy_wave[0]["hp"] = 450
	_check(KITS.select_target(main, "naia", "a1") == 1, "Naia selects a healthy enemy for her high-HP bonus instead of generic weakest targeting")
	_prepare(main, "corvin")
	main.enemy_wave[1]["vulnerable_seconds"] = 2.0
	_check(KITS.select_target(main, "corvin", "a1") == 1, "Corvin exploits an ally's debuff")
	_prepare(main, "darius")
	main.enemy_wave[1]["hp"] = 340
	_check(KITS.select_target(main, "darius", "a1") == 1, "Darius chooses an enemy below his execute threshold")
	_prepare(main, "valeria")
	main.hero_battle_state["valeria"]["hp"] = 250
	main.enemy_wave[0]["hp"] = 1
	_check(KITS.select_target(main, "valeria", "a1") == 1, "injured lifesteal hero avoids a one-HP target that cannot return useful healing")
	_check(KITS.priority(main, "valeria", "a1") >= 95, "critical lifesteal is prioritized over ordinary damage")
	_prepare(main, "mira")
	main.hero_skill_runtime["mira"]["target_index"] = 1
	main.enemy_wave[0]["hp"] = 850
	_check(KITS.select_target(main, "mira", "basic") == 1, "Mira keeps consecutive basic attacks through a minor HP change")
	main.enemy_wave[1]["hp"] = 0
	_check(KITS.select_target(main, "mira", "basic") == 0, "dead retained targets are released immediately")
	_prepare(main, "mira")
	main.enemy_wave[2]["elite"] = true
	_check(KITS.select_target(main, "mira", "a1") == 2, "Mira precision selects the reachable elite")
	main.roaming_hunt.enemy_positions[2] = Vector2(30.0, 18.0)
	_check(KITS.select_target(main, "mira", "a1") != 2, "bonus targeting never bypasses actual attack range")

func _test_control_and_aoe(main) -> void:
	_prepare(main, "nyx")
	for enemy in main.enemy_wave:
		enemy["vulnerable_seconds"] = 2.0
	_check(not KITS.should_use(main, "nyx", "a1"), "holds a duplicate vulnerability while all reachable enemies are affected")
	main.enemy_wave[2]["vulnerable_seconds"] = 0.0
	_check(KITS.should_use(main, "nyx", "a1"), "releases vulnerability when a fresh enemy appears")
	_check(KITS.select_target(main, "nyx", "a1") == 2, "control spends limited hits on the fresh threat")
	_prepare(main, "kairen")
	main.enemy_wave[0]["stun_seconds"] = 2.0
	main.enemy_wave[1]["attack"] = 300
	main.enemy_wave[2]["attack"] = 150
	var profile := KITS.auto_profile(main, "kairen", "a1")
	var targets: Array[int] = main._hero_skill_enemy_targets("kairen", KITS.select_target(main, "kairen", "a1"), profile)
	_check(targets == [1, 2], "two-target control chooses the two unblocked threats in danger order")
	main.enemy_wave[0]["attack"] = 1000
	_check(KITS.select_target(main, "kairen", "a1") == 1, "a high-attack already stunned enemy cannot crowd fresh threats out of limited control")
	_prepare(main, "mira")
	main.hero_battle_state["mira"]["ultimate"] = 0.0
	_check(KITS.preferred_slot(main, "mira") == "a2", "a dense pack favors the two-target second skill over single-target primary")
	main._advance_hunt_attacks(.1)
	main._advance_hunt_attacks(.2)
	_check(int(main.hero_skill_runtime["mira"].get("casts_a2", 0)) == 1, "production hunt windup chooses and settles the area skill")
	_prepare(main, "mira", 1)
	main.enemy_wave[0]["hp"] = 50
	_check(not KITS.should_use(main, "mira", "a2"), "holds area cooldown when one basic hit finishes the sole enemy")
	_check(not KITS.should_use(main, "mira", "ultimate"), "holds ultimate resource on a one-hit cleanup target")
	_prepare(main, "lunea", 1)
	main.enemy_wave[0]["hp"] = 50
	_check(not KITS.should_use(main, "lunea", "a1"), "does not apply damage-free weakening to a one-hit cleanup target")

func _test_support(main) -> void:
	_prepare(main, "leonhardt")
	main.hero_battle_state["mira"]["hp"] = 300
	main.hero_battle_state["mira"]["shield"] = 150
	main.hero_battle_state["mira"]["shield_seconds"] = 3.0
	main.hero_battle_state["elisia"]["hp"] = 450
	main.enemy_wave[0]["target_id"] = "elisia"
	_check(KITS.can_use(main, "leonhardt", "a2"), "a protected low-HP ally does not hide the next useful shield recipient")
	KITS.cast(main, "leonhardt", "a2")
	_check(main.hero_battle_state["elisia"]["shield"] == 90, "pure barrier protects the unshielded threatened ally")
	_check(main.hero_battle_state["mira"]["shield"] == 150, "existing stronger shield stays intact")
	main.hero_skill_runtime["leonhardt"]["secondary_remaining"] = 0.0
	main.hero_battle_state["elisia"]["shield_seconds"] = .1
	_check(KITS.can_use(main, "leonhardt", "a2"), "expiring shield can be refreshed before it vanishes")
	_prepare(main, "elisia")
	main.hero_battle_state["mira"]["hp"] = 200
	main.hero_skill_runtime["elisia"]["remaining"] = 10.0
	_check(KITS.priority(main, "elisia", "a2") == 100, "secondary heal receives emergency priority while the primary is cooling down")
	_check(KITS.preferred_slot(main, "elisia") in ["ultimate", "a2"], "support spends an available emergency recovery action")
	_prepare(main, "elisia")
	_check(not KITS.should_use(main, "elisia", "a1"), "full-health party holds healing")
	_prepare(main, "leonhardt")
	for index in main.enemy_wave.size(): main.roaming_hunt.enemy_positions[index] = Vector2(30, 18)
	_check(not KITS.should_use(main, "leonhardt", "a2"), "does not expire a short barrier during long approach before anyone is in contact")
	_prepare(main, "elisia", 0)
	main.hero_battle_state["mira"]["hp"] = 200
	_check(KITS.should_use(main, "elisia", "a1"), "injured allies can receive field healing between cleared packs")
	main._cast_combat_skill("elisia", -1)
	_check(main.hero_battle_state["mira"]["hp"] > 200 and main.hero_skill_runtime["elisia"]["remaining"] > 0.0, "legacy field heal still settles its effect and cooldown with no living enemies")
	_prepare(main, "leonhardt", 0)
	_check(not KITS.can_use(main, "leonhardt", "a1") and not KITS.can_use(main, "leonhardt", "a2"), "empty field still holds guard and barrier cooldowns")
	_prepare(main, "mira", 0)
	_check(not KITS.can_use(main, "mira", "a1"), "empty field cannot spend offensive cooldowns")
	_prepare(main, "elisia", 1, true)
	main.hero_battle_state["mira"]["hp"] = 200
	main.raid_boss_hp = 0
	_check(not KITS.can_use(main, "elisia", "a1"), "defeated raid encounter still blocks healing casts")

func _test_roster_safety(main) -> void:
	var catalog_before := JSON.stringify(CATALOG.HEROES)
	for raid in [false, true]:
		for id in CATALOG.HEROES:
			_prepare(main, id, 3, raid)
			for state in main.hero_battle_state.values():
				state["hp"] = 350
			main.boss_telegraph_pending = raid
			var resources_before := JSON.stringify([main.hero_battle_state, main.hero_skill_runtime, main.enemy_wave])
			for slot in ["a1", "a2", "ultimate"]:
				var score := KITS.priority(main, id, slot)
				_check(score > 0 and score <= 100, "%s/%s/%s auto priority has bounded output" % [id, slot, "raid" if raid else "field"])
			_check(resources_before == JSON.stringify([main.hero_battle_state, main.hero_skill_runtime, main.enemy_wave]), "%s priority queries never spend HP, energy or cooldown" % id)
			if not raid:
				for index in main.enemy_wave.size(): main.roaming_hunt.enemy_positions[index] = Vector2(30, 18)
				_check(KITS.select_target(main, id, "a1") == -1, id + " cannot select a distant target")
	_check(catalog_before == JSON.stringify(CATALOG.HEROES), "all thirty heroes retain their original skill definitions and numbers")

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	_test_specific_targets(main)
	_test_control_and_aoe(main)
	_test_support(main)
	_test_roster_safety(main)
	main.free()
	await create_timer(.3).timeout
	print("v52_role_combat checks=%d failures=%d" % [checks, failures.size()])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks":checks, "failures":failures}, "\t"))
	quit(0 if failures.is_empty() else 1)
