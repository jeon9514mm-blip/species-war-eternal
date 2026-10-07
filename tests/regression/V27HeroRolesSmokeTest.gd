extends SceneTree

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
	print("V27 HERO %s: %s" % ["PASS" if condition else "FAIL", label])

func _enemy(hp := 10000) -> Dictionary:
	return {"hp":hp, "max_hp":10000, "attack":100, "row":0, "elite":true, "archetype":"brute", "name":"영웅 검증 표적", "attack_remaining":1000.0}

func _prepare(main, ids: Array, faction := "aurelia", enemy_count := 4) -> void:
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = faction
	main.hero_progress = {}
	main.hero_skill_tree = {}
	main.hero_equipment = {}
	main.hero_equipment_rarity = {}
	main.hero_equipment_names = {}
	main._restore_deployed_heroes(ids)
	main._setup_hero_skills()
	main.active_screen = "combat"
	main.combat_running = false
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	main.enemy_wave = []
	for index in enemy_count:
		main.enemy_wave.append(_enemy())
	main.roaming_hunt.configure(Vector2(1.0, 2.0), 2703)
	main.roaming_hunt.spawn_group(main.enemy_wave)
	var positions: Array[Vector2] = []
	for index in enemy_count:
		positions.append(Vector2(1.4 + index * 0.04, 2.0))
	main.roaming_hunt.enemy_positions = positions
	main.expedition_position = main.roaming_hunt.party_position
	for runtime in main.hero_skill_runtime.values():
		runtime["remaining"] = 0.0
	for state in main.hero_battle_state.values():
		state["attack"] = 100
	main._sync_enemy_wave_summary()

func _test_roster(main) -> void:
	var total := 0
	for faction in ["aurelia", "noxfera"]:
		main.selected_faction = faction
		var roster: Array = main._hero_roster_for_faction()
		for hero in roster:
			var hero_id := str(hero["id"])
			_prepare(main, [hero_id], faction)
			main.hero_battle_state[hero_id]["hp"] = int(main.hero_battle_state[hero_id]["max_hp"]) / 3
			var before_hp := int(main.hero_battle_state[hero_id]["hp"])
			var damage := int(main._cast_combat_skill(hero_id, 0))
			var kind := str(main.hero_skill_runtime[hero_id]["profile"]["kind"])
			var useful := damage > 0
			if kind == "heal":
				useful = int(main.hero_battle_state[hero_id]["hp"]) > before_hp
			elif kind == "barrier":
				useful = int(main.hero_battle_state[hero_id].get("shield",0)) > 0
			elif kind == "guard":
				useful = float(main.hero_battle_state[hero_id]["guard"]) > 0.0
			elif kind in ["weaken", "vulnerable"]:
				useful = float(main._enemy_status_remaining(0, kind)) > 0.0
			_check(useful and float(main.hero_skill_runtime[hero_id]["remaining"]) > 0.0, "%s active skill produces its declared effect" % hero_id)
			total += 1
	_check(total == 30, "both complete fifteen-hero rosters execute")

func _test_distinct_damage(main) -> void:
	_prepare(main, ["darius"])
	main.enemy_wave[0]["hp"] = 5000
	var normal := int(main._cast_combat_skill("darius", 0))
	main.hero_skill_runtime["darius"]["remaining"] = 0.0
	main.enemy_wave[0]["hp"] = 3500
	var execution := int(main._cast_combat_skill("darius", 0))
	_check(execution > int(float(normal) * 1.5), "Darius execute activates at 35 percent HP")
	_prepare(main, ["mira"])
	main.enemy_wave[0]["elite"] = false
	var ordinary := int(main._cast_combat_skill("mira", 0))
	main.hero_skill_runtime["mira"]["remaining"] = 0.0
	main.enemy_wave[0]["elite"] = true
	var elite := int(main._cast_combat_skill("mira", 0))
	_check(elite >= int(float(ordinary) * 1.18), "Mira precision actually increases damage against elites")
	_prepare(main, ["seria"])
	main.enemy_wave[0]["hp"] = 1
	main._cast_combat_skill("seria", 0)
	_check(int(main.enemy_wave[0]["hp"]) == 0 and int(main.enemy_wave[1]["hp"]) < 10000, "Seria remaining shots retarget after a first-hit kill")
	_prepare(main, ["ragna"], "noxfera")
	main._cast_combat_skill("ragna", 0)
	_check(int(main.enemy_wave[2]["hp"]) < 10000 and int(main.enemy_wave[3]["hp"]) == 10000, "Ragna cleave respects its three-target limit")
	_prepare(main, ["fenris"], "noxfera")
	main._cast_combat_skill("fenris", 0)
	_check(float(main.hero_battle_state["fenris"]["ultimate"]) >= 20.0, "Fenris flurry grants the advertised extra ultimate charge")
	_prepare(main, ["valeria"], "noxfera")
	var state: Dictionary = main.hero_battle_state["valeria"]
	state["hp"] = int(float(state["max_hp"]) * 0.70)
	var before := int(state["hp"])
	main._cast_combat_skill("valeria", 0)
	var ordinary_heal := int(state["hp"]) - before
	state["hp"] = int(float(state["max_hp"]) * 0.30)
	before = int(state["hp"])
	main.hero_skill_runtime["valeria"]["remaining"] = 0.0
	main._cast_combat_skill("valeria", 0)
	_check(int(state["hp"]) - before > int(float(ordinary_heal) * 1.45), "Valeria low-health sustain increases actual healing")
	main.enemy_wave[0]["hp"] = 1
	state["hp"] = 50
	main.hero_skill_runtime["valeria"]["remaining"] = 0.0
	main._cast_combat_skill("valeria", 0)
	_check(int(state["hp"]) == 50, "lifesteal uses one point of actual damage and cannot heal from overkill")

func _test_guard_and_healing(main) -> void:
	_prepare(main, ["orwin", "mira", "elisia"])
	main._cast_combat_skill("orwin", -1)
	_check(float(main.hero_battle_state["mira"]["guard"]) > 0.0 and float(main.hero_battle_state["elisia"]["guard"]) > 0.0, "Orwin active protects the entire living party")
	main.hero_skill_runtime["orwin"]["remaining"] = 0.0
	_check(not main._should_use_skill("orwin"), "Orwin holds duplicate team protection")
	_prepare(main, ["leonhardt", "mira"])
	main._cast_combat_skill("leonhardt", -1)
	_check(float(main.hero_battle_state["leonhardt"]["taunt"]) > 0.0 and float(main.hero_battle_state["mira"]["guard"]) == 0.0, "Leonhardt specializes in self protection and taunt")
	_prepare(main, ["garm", "valeria"], "noxfera")
	main.hero_battle_state["garm"]["hp"] = 100
	main._cast_combat_skill("garm", -1)
	_check(int(main.hero_battle_state["garm"]["hp"]) > 100, "Garm guard restores his own health")
	_prepare(main, ["isolde", "garm", "valeria", "veyra"], "noxfera")
	for id in ["garm", "valeria", "veyra"]:
		main.hero_battle_state[id]["hp"] = 100
	main.hero_battle_state["veyra"]["hp"] = 0
	main._cast_combat_skill("isolde", -1)
	_check(int(main.hero_battle_state["garm"]["hp"]) > 100 and int(main.hero_battle_state["valeria"]["hp"]) > 100 and int(main.hero_battle_state["veyra"]["hp"]) == 0, "Isolde heals two injured allies and never revives a dead ally")
	_prepare(main, ["elisia", "mira"])
	main.hero_battle_state["elisia"]["ultimate"] = 100.0
	main._cast_combat_skill("elisia", -1)
	main._cast_combat_ultimate("elisia", -1)
	_check(float(main.hero_skill_runtime["elisia"]["remaining"]) == 0.0 and float(main.hero_battle_state["elisia"]["ultimate"]) == 100.0, "full-health direct healing preserves skill cooldown and ultimate")
	_prepare(main, ["astel", "mira", "elisia"])
	for state in main.hero_battle_state.values():
		state["hp"] = 100
	main._cast_combat_skill("astel", -1)
	_check(int(main.hero_battle_state["astel"]["hp"]) > 100 and int(main.hero_battle_state["mira"]["hp"]) > 100 and int(main.hero_battle_state["elisia"]["hp"]) > 100, "Astel applies party healing to all three injured allies")

func _test_local_control(main) -> void:
	for data in [["kairen", "aurelia", "stun"], ["lunea", "aurelia", "weaken"], ["nyx", "noxfera", "vulnerable"]]:
		var hero_id := str(data[0])
		var kind := str(data[2])
		_prepare(main, [hero_id], str(data[1]), 3)
		main.roaming_hunt.enemy_positions[2] = Vector2(7.0, 2.0)
		main._cast_combat_skill(hero_id, 0)
		_check(float(main._enemy_status_remaining(0, kind)) > 0.0 and float(main._enemy_status_remaining(1, kind)) > 0.0 and float(main._enemy_status_remaining(2, kind)) == 0.0, "%s affects reachable enemies and leaves disconnected enemies unchanged" % hero_id)
		main.hero_skill_runtime[hero_id]["remaining"] = 0.0
		_check(not main._should_use_skill(hero_id), "%s holds an already active status" % hero_id)
	_check(not main._apply_enemy_status(-1, "stun", 1.0) and not main._apply_enemy_status(0, "stun", NAN) and not main._apply_enemy_status(0, "stun", -1.0), "invalid status indices, NaN and negative duration are rejected")
	main.enemy_wave[0]["hp"] = 0
	_check(not main._apply_enemy_status(0, "stun", 2.0), "dead enemies cannot receive new status")
	_prepare(main, ["morgas"], "noxfera")
	main.hero_battle_state["morgas"]["ultimate"] = 100.0
	var damage := int(main._cast_combat_ultimate("morgas", 0))
	_check(damage > 0 and float(main._enemy_status_remaining(0, "vulnerable")) > 0.0, "Morgas full-health ultimate applies offensive curse")
	_prepare(main, ["morgas"], "noxfera", 2)
	main._apply_enemy_status(0, "vulnerable", 1.0)
	main._cast_combat_skill("morgas", 0)
	_check(float(main._enemy_status_remaining(0, "vulnerable")) == 1.0 and float(main._enemy_status_remaining(1, "vulnerable")) > 0.0, "single-target curse finds a fresh target instead of refreshing an active curse")

func _test_raid_and_refresh(main) -> void:
	_prepare(main, ["darius", "elisia"])
	main.active_screen = "raid"
	main.raid_boss_hp = 3500
	main.raid_boss_max_hp = 10000
	var execution := int(main._cast_hero_skill("darius"))
	main.hero_skill_runtime["darius"]["remaining"] = 0.0
	main.raid_boss_hp = 6000
	var normal := int(main._cast_hero_skill("darius"))
	_check(execution > int(float(normal) * 1.5), "raid adapter preserves execute mechanics")
	main.raid_boss_hp = 0
	main.hero_battle_state["darius"]["ultimate"] = 100.0
	main.hero_skill_runtime["darius"]["remaining"] = 0.0
	_check(main._cast_hero_skill("darius") == 0 and main._cast_raid_ultimate("darius") == 0 and float(main.hero_battle_state["darius"]["ultimate"]) == 100.0, "dead raid boss cannot consume skills or ultimate")
	_prepare(main, ["leonhardt", "mira"])
	var original: Dictionary = main.hero_battle_state["leonhardt"].duplicate(true)
	main.hero_battle_state["leonhardt"]["hp"] = int(original["max_hp"]) / 2
	main.hero_battle_state["leonhardt"]["ultimate"] = 73.0
	main.hero_battle_state["leonhardt"]["guard"] = 1.7
	main.hero_battle_state["mira"]["hp"] = 0
	main.hero_skill_runtime["leonhardt"]["remaining"] = 2.1
	main.hero_skill_runtime["leonhardt"]["windup"] = 0.15
	main.hero_progress["leonhardt"]["level"] = 10
	main._refresh_hero_growth_stats()
	var refreshed: Dictionary = main.hero_battle_state["leonhardt"]
	_check(int(refreshed["max_hp"]) > int(original["max_hp"]) and absf(float(refreshed["hp"]) / float(refreshed["max_hp"]) - 0.5) < 0.002, "growth refresh updates stats while preserving health ratio")
	_check(int(main.hero_battle_state["mira"]["hp"]) == 0 and float(refreshed["ultimate"]) == 73.0 and float(refreshed["guard"]) == 1.7 and float(main.hero_skill_runtime["leonhardt"]["remaining"]) == 2.1 and float(main.hero_skill_runtime["leonhardt"]["windup"]) == 0.15, "growth refresh preserves deaths, ultimate, protection, cooldown and committed windup")

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	_test_roster(main)
	_test_distinct_damage(main)
	_test_guard_and_healing(main)
	_test_local_control(main)
	_test_raid_and_refresh(main)
	main.free()
	if not failures.is_empty():
		push_error("v27_hero_roles_smoke_test_failed checks=%d failures=%d: %s" % [checks, failures.size(), "; ".join(failures)])
		quit(1)
		return
	print("v27_hero_roles_smoke_test_ok checks=%d roster=30 mechanics=ok status_range=ok resource_safety=ok raid=ok growth=ok" % checks)
	quit(0)
