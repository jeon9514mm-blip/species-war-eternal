extends SceneTree

# Keep production spawn, movement, combat, growth and reward paths intact.
# Isolate save data and repeated HUD painting, matching the balance matrix.
class HuntFixture:
	extends "res://scripts/app/Main.gd"
	func _load_idle_state() -> void:
		pass
	func _save_idle_state() -> void:
		pass
	func _update_hunt_hud() -> void:
		pass
	func _update_map_tiles() -> void:
		pass

const STEP := 0.1
const SECONDS := 60
const ECOLOGY = preload("res://scripts/hunting/FieldEcology.gd")
var checks := 0
var failures: Array[String] = []
var reports: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("V52 HUNT INTEGRATION FAIL: ", message)

func _fixture(faction: String, party_size: int, zone_id := "gray_meadow"):
	var main = HuntFixture.new()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	main.selected_faction = faction
	main.current_zone_id = zone_id
	main.idle_stage = 1 if party_size == 1 else (8 if party_size == 3 else 25)
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, party_size).duplicate(true)
	for hero in main.deployed_heroes:
		var id := str(hero["id"])
		main.hero_progress[id] = {"level": 1 if party_size == 1 else 10, "xp": 0}
		main.hero_equipment[id] = {"weapon": 1 if party_size == 1 else 3, "armor": 1 if party_size == 1 else 3, "accessory": 1 if party_size == 1 else 3}
	main._offline_checked = true
	main.combat_effects_enabled = false
	main.battle_speed = 1.0
	main.loot_rng.seed = 5201 + party_size
	main._build_combat_screen()
	main.roaming_hunt.configure(main.expedition_position, 5201 + party_size)
	main.roaming_hunt.spawn_group(main.enemy_wave)
	return main

func _health_valid(main) -> bool:
	var total := 0
	for state in main.hero_battle_state.values():
		var hp := int(state.get("hp", -1))
		var maximum := int(state.get("max_hp", 0))
		if maximum <= 0 or hp < 0 or hp > maximum or bool(state.get("alive", false)) != (hp > 0):
			return false
		total += hp
	for enemy in main.enemy_wave:
		if int(enemy.get("hp", -1)) < 0 or int(enemy.get("hp", 0)) > int(enemy.get("max_hp", 0)):
			return false
	return int(main.party_hp) == total

func _population_contracts() -> void:
	var main = _fixture("aurelia", 10)
	for zone_id in main._zone_data():
		main.current_zone_id = zone_id
		for party_size in [1, 3, 4, 7, 10]:
			main.deployed_heroes = main._hero_roster_for_faction().slice(0, party_size).duplicate(true)
			main._spawn_enemy_wave(main._current_zone())
			var population := int(main.enemy_wave.size())
			var prefix := "%s/%d" % [zone_id, party_size]
			_check(population >= 15 and population <= 20, prefix + ": corps population stays within the published 15-to-20 range")
			_check(population == main.roaming_hunt.enemy_positions.size() and population == main.enemy_wave_sprites.size() and population == main.enemy_hp_bars.size(), prefix + ": model, movement and visible monster counts agree")
			var valid_species := true
			for enemy in main.enemy_wave:
				valid_species = valid_species and str(enemy["archetype"]) == str(ECOLOGY.species_profile(str(enemy["name"]))["role"])
			_check(valid_species, prefix + ": each species retains its declared combat role")
		_check(main.enemy_wave.size() >= 15, zone_id + ": full party retains the fifteen-member corps")
	if main.presentation_runtime != null: main.presentation_runtime.audio.shutdown()
	main.queue_free()

func _pause_snapshot(main) -> Dictionary:
	return {"clock": main.hunt_ai.clock, "party_position": main.expedition_position, "enemy_positions": main.roaming_hunt.enemy_positions.duplicate(), "heroes": main.hero_battle_state.duplicate(true), "skills": main.hero_skill_runtime.duplicate(true), "enemies": main.enemy_wave.duplicate(true), "gold": main.unclaimed_gold, "xp": main.unclaimed_xp, "clears": main.combat_kills}

func _check_pause(main, prefix: String) -> void:
	main._toggle_combat(null)
	var paused := _pause_snapshot(main)
	for tick in 10:
		main._advance_auto_hunt(STEP)
	_check(not main.combat_running and _pause_snapshot(main) == paused, prefix + ": pause freezes movement, cooldowns, HP and rewards")
	main._toggle_combat(null)
	main._advance_auto_hunt(STEP)
	_check(main.combat_running and float(main.hunt_ai.clock) > float(paused["clock"]), prefix + ": resume advances production combat clock")

func _check_wipe(main, prefix: String) -> Dictionary:
	for state in main.hero_battle_state.values():
		state["hp"] = 0
		state["alive"] = false
	main._sync_party_hp_from_heroes()
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	var clears_before := int(main.combat_kills)
	var gold_before := int(main.unclaimed_gold)
	var expected_enemies: Array = main.enemy_wave.duplicate(true)
	# Recovery is an active simulation step, so existing debuffs keep counting
	# down. All other enemy data, including HP and attack state, must stay fixed.
	for enemy in expected_enemies:
		for status in ["stun_seconds", "weaken_seconds", "vulnerable_seconds"]:
			enemy[status] = maxf(0.0, float(enemy.get(status, 0.0)) - STEP)
	main._advance_auto_hunt(STEP)
	_check(main.hunt_ai.state == AutoHuntController.State.RECOVERING, prefix + ": wipe enters recovery on next update")
	_check(int(main.combat_kills) == clears_before and int(main.unclaimed_gold) == gold_before and main.enemy_wave == expected_enemies, prefix + ": dead party cannot damage monsters or receive clear rewards")
	var recovery_seconds := -1.0
	for tick in 150:
		main._advance_auto_hunt(STEP)
		if main.hunt_ai.state != AutoHuntController.State.RECOVERING:
			recovery_seconds = float(tick + 1) * STEP
			break
		if tick % 30 == 0:
			await process_frame
	_check(recovery_seconds > 0.0 and recovery_seconds < 15.0 and main._alive_hero_ids().size() == main.deployed_heroes.size(), prefix + ": full party returns within fifteen seconds")
	var resumed_clear_seconds := -1.0
	for tick in 450:
		main._advance_auto_hunt(STEP)
		if int(main.combat_kills) > clears_before:
			resumed_clear_seconds = float(tick + 1) * STEP
			break
		if tick % 30 == 0:
			await process_frame
	_check(resumed_clear_seconds > 0.0 and _health_valid(main), prefix + ": hunt clears another habitat after recovery")
	return {"recovery_seconds": recovery_seconds, "clear_after_recovery_seconds": resumed_clear_seconds}

func _run_row(faction: String, party_size: int) -> void:
	var zone := "moonrest_forest" if party_size == 10 else "gray_meadow"
	var main = _fixture(faction, party_size, zone)
	await process_frame
	var prefix := "%s/%s/%d" % [faction, zone, party_size]
	var population := int(main.enemy_wave.size())
	_check(main.deployed_heroes.size() == party_size and main.hero_battle_state.size() == party_size, prefix + ": actual selected party survives setup")
	_check_pause(main, prefix)
	var completed: Dictionary = {}
	for id in main.hero_skill_runtime:
		completed[id] = 0
	var health_ok := true
	var recoveries := 0
	var previous_state: int = main.hunt_ai.state
	var previous_clears := int(main.combat_kills)
	var last_clear_step := 0
	var longest_gap := 0.0
	var minimum_alive := party_size
	for tick in int(SECONDS / STEP):
		var windups: Dictionary = {}
		for id in completed:
			windups[id] = float(main.hero_skill_runtime[id].get("windup", -1.0))
		main._advance_auto_hunt(STEP)
		health_ok = health_ok and _health_valid(main)
		minimum_alive = mini(minimum_alive, main._alive_hero_ids().size())
		if main.hunt_ai.state == AutoHuntController.State.RECOVERING and previous_state != AutoHuntController.State.RECOVERING:
			recoveries += 1
		previous_state = main.hunt_ai.state
		for id in completed:
			var runtime: Dictionary = main.hero_skill_runtime[id]
			if float(windups[id]) >= 0.0 and float(runtime.get("windup", -1.0)) < 0.0 and float(runtime.get("attack_remaining", 0.0)) > .20:
				completed[id] = int(completed[id]) + 1
		if int(main.combat_kills) > previous_clears:
			longest_gap = maxf(longest_gap, float(tick + 1 - last_clear_step) * STEP)
			last_clear_step = tick + 1
			previous_clears = int(main.combat_kills)
		if tick % 30 == 0:
			await process_frame
	longest_gap = maxf(longest_gap, SECONDS - float(last_clear_step) * STEP)
	var active_heroes := 0
	var secondary_casts := 0
	for id in completed:
		if int(completed[id]) > 0:
			active_heroes += 1
		secondary_casts += int(main.hero_skill_runtime[id].get("casts_a2", 0))
	_check(health_ok, prefix + ": HP remains bounded and synchronized for the full run")
	_check(active_heroes == party_size, prefix + ": every deployed hero completes combat actions")
	_check(int(main.combat_hunt_cycle) >= (1 if party_size==1 else 2) and longest_gap < (120.0 if party_size==1 else 60.0), prefix + ": solo first corps clears in two minutes; larger parties sustain repeated clears")
	_check(int(main.unclaimed_gold) > 0 and int(main.unclaimed_xp) > 0, prefix + ": moving hunt awards gold and XP")
	if party_size >= 3:
		_check(secondary_casts > 0, prefix + ": second active skills execute through production AI")
	var report := {"faction": faction, "zone": zone, "party_size": party_size, "starting_population": population, "seconds": SECONDS, "packs_cleared": int(main.combat_kills), "habitats_cleared": int(main.combat_hunt_cycle), "gold": int(main.unclaimed_gold), "xp": int(main.unclaimed_xp), "longest_clear_gap_seconds": snappedf(longest_gap, .1), "recoveries": recoveries, "minimum_alive": minimum_alive, "completed_actions": completed, "secondary_casts": secondary_casts, "health_valid": health_ok}
	if party_size == 10:
		report["forced_wipe"] = await _check_wipe(main, prefix)
	reports.append(report)
	print("V52 HUNT INTEGRATION ROW: ", JSON.stringify(report))
	if main.presentation_runtime != null: main.presentation_runtime.audio.shutdown()
	main.queue_free()
	await process_frame

func _reward_snapshot(main) -> Dictionary:
	return {"gold": main.unclaimed_gold, "xp": main.unclaimed_xp, "clears": main.combat_kills, "rations": main.faction_war_state.rations, "hero_progress": main.hero_progress.duplicate(true), "loot": main.loot_inventory.duplicate(true), "stage": main.idle_stage, "stage_kills": main.idle_stage_kills, "chest_gold": main.idle_chest_gold, "chest_xp": main.idle_chest_xp, "habitats": main.combat_hunt_cycle, "boss_active": main.open_map_boss_active}

func _reward_idempotency() -> void:
	var main = _fixture("aurelia", 3)
	var packs: Dictionary = {}
	for enemy in main.enemy_wave:
		packs[int(enemy["habitat_pack"])] = true
	_check(packs.size() == 3, "first 15-member corps contains three independent packs")
	main.combat_kills = 4
	main.idle_stage_kills = main.idle_stage_target - 1
	var stage_before := int(main.idle_stage)
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main.enemy_wave[0]["hp"] = 0
	var unfinished := _reward_snapshot(main)
	main._finish_hunt_target()
	_check(_reward_snapshot(main) == unfinished, "partial habitat cannot pay full clear rewards")
	for enemy in main.enemy_wave:
		enemy["hp"] = 0
	main._finish_hunt_target()
	var earned := _reward_snapshot(main)
	_check(int(earned["clears"]) == 4 + packs.size() and int(earned["habitats"]) == 1 and int(earned["gold"]) > 0, "complete habitat grants rewards for each pack exactly once")
	_check(int(earned["stage"]) == stage_before + 1 and int(earned["stage_kills"]) == packs.size() - 1 and int(earned["chest_gold"]) == 250 + stage_before * 50, "batched packs preserve a stage crossing and its remainder")
	_check(bool(earned["boss_active"]), "batched clears crossing five spawn the field boss")
	main._finish_hunt_target()
	_check(_reward_snapshot(main) == earned, "duplicate clear callback grants no additional reward")
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main._finish_hunt_target()
	_check(_reward_snapshot(main) == earned, "same encounter cannot repay even after combat-state reentry")
	main.hunt_ai.encounter_id += 1
	main._spawn_enemy_wave(main._current_zone())
	main.idle_stage = 10000
	main.idle_stage_kills = main.idle_stage_target - 1
	for enemy in main.enemy_wave:
		enemy["hp"] = 0
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main._finish_hunt_target()
	_check(main.idle_stage == 10000 and main.idle_stage_kills == main.idle_stage_target - 1 and main.idle_chest_gold == earned["chest_gold"], "stage cap cannot grant repeated chests from batched packs")
	_check(int(main.unclaimed_gold) > int(earned["gold"]), "new habitat still pays ordinary loot at the stage cap")
	if main.presentation_runtime != null: main.presentation_runtime.audio.shutdown()
	main.queue_free()

func _run() -> void:
	_population_contracts()
	await process_frame
	for faction in ["aurelia", "noxfera"]:
		for party_size in [1, 3, 10]:
			await _run_row(faction, party_size)
	_reward_idempotency()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			_check(file != null, "integration report is writable")
			if file != null:
				file.store_string(JSON.stringify({"checks": checks, "failures": failures, "rows": reports}, "\t") + "\n")
	if not failures.is_empty():
		push_error("v52_hunt_integration_failed: " + "; ".join(failures))
	print("v52_hunt_integration checks=%d failures=%d rows=%d pause_recovery_reward_contracts=true" % [checks, failures.size(), reports.size()])
	await create_timer(0.35).timeout
	quit(0 if failures.is_empty() else 1)
