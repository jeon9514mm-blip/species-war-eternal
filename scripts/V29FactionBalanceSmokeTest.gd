extends "res://scripts/V27BalanceMatrixSmokeTest.gd"

const ROSTER = preload("res://scripts/HeroRosterCatalog.gd")
var samples: Array = []
var seen: Dictionary = {}
var second_actions: Dictionary = {}

func _init() -> void:
	_run.call_deferred()

func squad(faction: String, rotation: int) -> Array:
	var groups := {"딜러":[],"방어/보조":[],"디버프":[]}
	for h in ROSTER.roster(faction): groups[h["category"]].append(h)
	var result: Array = []
	for category in ["방어/보조","딜러","디버프"]:
		var count: int = {"방어/보조":3,"딜러":5,"디버프":2}[category]
		var pool: Array = groups[category]
		for i in count: result.append(pool[(i + rotation) % pool.size()])
	return result

func make_fixture(faction: String, rotation: int, raid: bool):
	var main = BalanceFixture.new()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	main._offline_checked = true
	main.selected_faction = faction
	main.current_zone_id = "moonrest_forest" if raid or rotation % 2 == 1 else "gray_meadow"
	main.idle_stage = 25
	main.deployed_heroes = squad(faction,rotation)
	for hero in main.deployed_heroes:
		var id := str(hero["id"])
		seen[id] = true
		main.hero_progress[id] = {"level":20,"xp":0}
		main.hero_equipment[id] = {"weapon":3,"armor":3,"accessory":3}
		main.hero_ascension[id] = 2 - main._hero_base_grade_index(id)
	main.combat_effects_enabled = false
	main.battle_speed = 1.0
	if raid:
		main.active_screen = "raid"
		main._start_raid()
		main.combat_timer.stop()
		# Indestructible stationary training boss. Production raid AI, boss
		# patterns, healing, interruption and shield handling remain enabled.
		main.raid_boss_hp = 10000000
		main.raid_boss_max_hp = 10000000
		main.raid_boss_attack = 140
		main.pet_runtime = {"kind":"none"}
	else:
		main._build_combat_screen()
		main.pet_runtime = {"kind":"none"}
		main.roaming_hunt.configure(main.expedition_position,2901 + rotation)
		main.roaming_hunt.spawn_group(main.enemy_wave)
	return main

func run_sample(faction: String, rotation: int, raid: bool) -> void:
	var main = make_fixture(faction,rotation,raid)
	await process_frame
	var actions := 0
	for tick in 600:
		if raid: main._advance_raid_encounter(.1)
		else: main._advance_auto_hunt(.1)
		if tick % 60 == 0: await process_frame
	for id in main.hero_skill_runtime:
		var count := int(main.hero_skill_runtime[id].get("casts_a2",0))
		second_actions[id] = int(second_actions.get(id,0)) + count
		actions += count
	var row := {"faction":faction,"rotation":rotation,"mode":"raid" if raid else "field","zone":main.current_zone_id,"seconds":60,"damage":main.raid_damage_dealt if raid else 0,"packs":main.combat_kills if not raid else 0,"alive":main._alive_hero_ids().size(),"hp_ratio":float(main.party_hp)/maxf(1.0,float(main.party_max_hp)),"a2_casts":actions}
	samples.append(row)
	_check(actions > 0, "%s: second actives naturally execute" % JSON.stringify(row))
	_check(main._alive_hero_ids().size() >= 9, "%s: stable party survival" % faction)
	if not raid: _check(main.combat_kills > 0, "%s: moving hunt clears packs" % faction)
	print("V29 BALANCE ROW ", JSON.stringify(row))
	main.free()
	await process_frame

func _run() -> void:
	for raid in [true,false]:
		for rotation in range(4):
			for faction in ["aurelia","noxfera"]:
				await run_sample(faction,rotation,raid)
	var comparison: Dictionary = {}
	for mode in ["raid","field"]:
		var metric := "damage" if mode == "raid" else "packs"
		var totals := {"aurelia":0.0,"noxfera":0.0}
		for row in samples:
			if row["mode"] == mode: totals[row["faction"]] += float(row[metric])
		var gap := absf(totals["aurelia"]-totals["noxfera"])/maxf(1.0,(totals["aurelia"]+totals["noxfera"])*.5)
		comparison[mode] = {"metric":metric,"totals":totals,"relative_gap":gap}
		_check(gap <= .15, mode + ": combined faction gap within predeclared 15% gate")
	_check(seen.size()==30, "rotations exercise all thirty heroes")
	for id in seen: _check(int(second_actions.get(id,0))>0, id + ": second active used by production AI")
	var report := {"conditions":"four 5-damage/3-defense-support/2-debuff squads per faction; Lv20, equipment+3, SSR, no pets; 60s per row; two field zones and raid training boss","checks":checks,"failures":failures,"comparison":comparison,"samples":samples,"a2_casts_by_hero":second_actions}
	var output := "res://docs/v29-faction-balance-results.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("v29_faction_balance checks=%d failures=%d comparison=%s" % [checks,failures.size(),JSON.stringify(comparison)])
	if not failures.is_empty(): push_error("; ".join(failures))
	quit(0 if failures.is_empty() else 1)
