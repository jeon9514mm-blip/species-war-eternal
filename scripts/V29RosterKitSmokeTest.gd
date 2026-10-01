extends "res://scripts/V27HeroRolesSmokeTest.gd"

const CATALOG = preload("res://scripts/HeroRosterCatalog.gd")
const KITS = preload("res://scripts/HeroKitRuntime.gd")
var measurements: Array = []

func _init() -> void:
	_run.call_deferred()

func fixture(main, id: String, raid: bool) -> void:
	var h: Dictionary = CATALOG.HEROES[id]
	var allies: Array = [id]
	for other in CATALOG.HEROES:
		if CATALOG.HEROES[other]["faction"] == h["faction"] and other != id and allies.size() < 3:
			allies.append(other)
	_prepare(main, allies, h["faction"], 3)
	main.party_movement.positions.clear()
	main.active_screen = "raid" if raid else "combat"
	main.raid_running = raid
	main.raid_boss_hp = 100000
	main.raid_boss_max_hp = 100000
	main.raid_damage_dealt = 0
	main.raid_control_immunity = 0.0
	main.boss_telegraph_pending = true
	main.boss_telegraph_remaining = .8
	for state in main.hero_battle_state.values():
		state["hp"] = int(float(state["max_hp"]) * .30)
		state["ultimate"] = 100.0
	for runtime in main.hero_skill_runtime.values():
		runtime["secondary_remaining"] = 0.0
		runtime["remaining"] = 0.0
	main._sync_party_hp_from_heroes()

func test_catalog() -> void:
	var names: Dictionary = {}
	var ids: Dictionary = {}
	_check(CATALOG.HEROES.size() == 30, "thirty canonical hero IDs")
	for faction in ["aurelia", "noxfera"]:
		var roster: Array = CATALOG.roster(faction)
		var counts := {"딜러":0, "방어/보조":0, "디버프":0}
		for hero in roster:
			counts[hero["category"]] += 1
			var slots: Array = []
			for skill in hero["skills"]:
				slots.append(skill["slot"])
				_check(not names.has(skill["skill"]) and not ids.has(skill["id"]), "%s name/id unique" % skill["id"])
				names[skill["skill"]] = true
				ids[skill["id"]] = true
			_check(slots == ["a1", "a2", "passive", "ultimate"], "%s has exactly two actives, one passive, one ultimate" % hero["id"])
		_check(roster.size() == 15 and counts == {"딜러":8,"방어/보조":4,"디버프":3}, faction + " exact 8/4/3 quota")
	_check(ids.size() == 120, "one hundred twenty distinct skill IDs")
	var old_save := {"save_version":27, "selected_faction":"aurelia", "hero_progress":{"leonhardt":{"level":37,"xp":42},"selene":{"level":12,"xp":7},"fake":{"level":100}}, "hero_shards":{"adrien":50,"mira":20}, "deployed_hero_ids":["leonhardt","adrien","fake"]}
	var clean: Dictionary = SaveValidation.sanitize(old_save, ["gray_meadow"])
	_check(clean["hero_progress"]["leonhardt"] == {"level":37,"xp":42} and clean["hero_progress"].has("selene") and not clean["hero_progress"].has("fake"), "old progress preserved and new hero progress accepted")
	_check(clean["hero_shards"]["adrien"] == 50 and clean["deployed_hero_ids"] == ["leonhardt","adrien"], "new shards/party persist, unknown IDs rejected")

func test_skills(main) -> void:
	for raid in [false, true]:
		for id in CATALOG.HEROES:
			for slot in ["a1", "a2", "ultimate"]:
				fixture(main, id, raid)
				var before := JSON.stringify([main.hero_battle_state, main.enemy_wave, main._weaken_seconds, main._vulnerable_seconds, main._stun_seconds])
				var damage := 0
				if slot == "a1":
					damage = main._cast_hero_skill(id) if raid else main._cast_combat_skill(id, 0)
				elif slot == "ultimate":
					damage = main._cast_raid_ultimate(id) if raid else main._cast_combat_ultimate(id, 0)
				else:
					damage = KITS.cast(main, id, slot, 0)
				if raid: main._apply_raid_damage(damage)
				var r: Dictionary = main.hero_skill_runtime[id]
				var spent := float(main.hero_battle_state[id]["ultimate"]) < 100.0 if slot == "ultimate" else float(r.get("remaining" if slot == "a1" else "secondary_remaining", 0.0)) > 0.0
				var after := JSON.stringify([main.hero_battle_state, main.enemy_wave, main._weaken_seconds, main._vulnerable_seconds, main._stun_seconds])
				_check(spent and (before != after or damage > 0), "%s/%s/%s actual effect and resource consumed" % [id,slot,"raid" if raid else "field"])
				measurements.append({"hero":id,"slot":slot,"mode":"raid" if raid else "field","damage":damage,"spent":spent})
				var resource_before := float(main.hero_battle_state[id]["ultimate"]) if slot == "ultimate" else float(r.get("remaining" if slot == "a1" else "secondary_remaining",0.0))
				_check(KITS.cast(main,id,slot,0) == 0, "%s/%s immediate recast refused" % [id,slot])
				var resource_after := float(main.hero_battle_state[id]["ultimate"]) if slot == "ultimate" else float(r.get("remaining" if slot == "a1" else "secondary_remaining",0.0))
				_check(is_equal_approx(resource_before, resource_after), "refused recast preserves resources")

func test_passives(main) -> void:
	for raid in [false, true]:
		for id in CATALOG.HEROES:
			fixture(main,id,raid)
			var p := CATALOG.skill(id,"passive")
			var r: Dictionary = main.hero_skill_runtime[id]
			r["secondary_remaining"] = 5.0
			r["kit_basic_count"] = 3
			r["kit_last_move_position"] = Vector2(-10,-10)
			main.hero_battle_state[id]["ultimate"] = 0.0
			main.hero_battle_state[id]["guard"] = 1.0
			if id == "bora": main.hero_battle_state[id]["guard"] = 0.0
			main.hero_battle_state[id]["shield"] = 10
			for e in main.enemy_wave:
				e["hp"] = 3000
				e["stun_seconds"] = 1.0
				e["weaken_seconds"] = 1.0
				e["vulnerable_seconds"] = 1.0
			main.raid_boss_hp = 30000
			main._weaken_seconds = 1.0
			main._vulnerable_seconds = 1.0
			main._stun_seconds = 1.0
			# Multi-enemy passive intentionally has no raid proc: a boss is one target.
			var expected := 0 if raid and p["condition"] == "many_enemies" else 1
			var before := JSON.stringify([main.hero_battle_state,main.enemy_wave,r.get("secondary_remaining")])
			var raw := 0
			for _i in int(p["every"]): raw += KITS.event(main,id,str(p["event"]),0)
			var after := JSON.stringify([main.hero_battle_state,main.enemy_wave,r.get("secondary_remaining")])
			_check(int(r.get("passive_procs",0)) == expected, "%s %s conditional passive proc count" % [id,"raid" if raid else "field"])
			_check(expected == 0 or before != after or raw > 0, id + " passive changes actual combat state")
			main.hero_battle_state[id]["hp"] = 0
			r["passive_remaining"] = 0.0
			for _i in 5: KITS.event(main,id,str(p["event"]),0)
			_check(int(r.get("passive_procs",0)) == expected, id + " dead hero cannot proc")

func test_boundaries(main) -> void:
	fixture(main,"selene",false)
	KITS.shield(main,"selene",1.0)
	var state: Dictionary = main.hero_battle_state["selene"]
	_check(int(state["shield"]) <= int(float(state["max_hp"])*.20), "shield capped at 20 percent max HP")
	var hp_before := int(state["hp"])
	main._incoming_damage_to_hero("selene",10,0)
	_check(int(state["hp"]) == hp_before, "shield absorbs actual incoming damage")
	main._advance_skill_cooldowns(4.1)
	_check(int(state.get("shield",0)) == 0, "shield expires")
	fixture(main,"lucien",true)
	state = main.hero_battle_state["lucien"]
	state["hp"] = 1
	main._cast_hero_skill("lucien")
	_check(int(state["hp"]) >= 1, "blood cost cannot kill the caster")
	fixture(main,"mira",false)
	main.roaming_hunt.enemy_positions.assign([Vector2(30,19),Vector2(30,18),Vector2(31,19)])
	_check(KITS.cast(main,"mira","a2",0)==0 and main.hero_skill_runtime["mira"]["secondary_remaining"]==0.0, "out-of-range A2 spends no cooldown")
	fixture(main,"mira",false)
	main.hero_skill_runtime["mira"]["secondary_remaining"] = 3.0
	main.hero_progress["mira"]["level"] = 50
	main._refresh_hero_growth_stats()
	_check(main.hero_skill_runtime["mira"]["secondary_remaining"] == 3.0, "growth preserves second cooldown")
	main.combat_running = false
	main._advance_auto_hunt(.1)
	_check(main.hero_skill_runtime["mira"]["secondary_remaining"] == 3.0, "paused hunt cannot advance second cooldown")
	fixture(main,"kairen",true)
	main.raid_control_immunity = 5.0
	main._cast_raid_ultimate("kairen")
	_check(main.hero_battle_state["kairen"]["ultimate"] == 100.0, "boss control immunity preserves stun ultimate")
	fixture(main,"mira",false)
	main.hero_skill_runtime["mira"]["remaining"] = 100.0
	main.hero_skill_runtime["mira"]["attack_remaining"] = 0.0
	main.hero_battle_state["mira"]["ultimate"] = 0.0
	main._advance_hunt_attacks(.1)
	main._advance_hunt_attacks(.2)
	_check(int(main.hero_skill_runtime["mira"].get("casts_a2",0)) == 1, "real field windup selects and settles A2 exactly once")

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.set_process(false)
	test_catalog()
	test_skills(main)
	test_passives(main)
	test_boundaries(main)
	var report := {"checks":checks,"failures":failures,"skill_casts":measurements}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"\t"))
	main.free()
	print("v29_roster_kit checks=%d failures=%d casts=%d" % [checks,failures.size(),measurements.size()])
	if not failures.is_empty(): push_error("; ".join(failures))
	quit(0 if failures.is_empty() else 1)
