extends SceneTree

const STEP_SECONDS := 0.1
const TOTAL_STEPS := 1800
const WIPE_STEP := 900

var failures: Array[String] = []
var reports: Array[Dictionary] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("V26 SOAK FAIL: ", message)

func _health_valid(main) -> bool:
	var summed_hp := 0
	var summed_max := 0
	for state in main.hero_battle_state.values():
		var hp := int(state.get("hp", -1))
		var maximum := int(state.get("max_hp", 0))
		if maximum <= 0 or hp < 0 or hp > maximum or bool(state.get("alive", false)) != (hp > 0):
			return false
		summed_hp += hp
		summed_max += maximum
	for enemy in main.enemy_wave:
		if int(enemy.get("hp", -1)) < 0 or int(enemy.get("hp", 0)) > int(enemy.get("max_hp", 0)):
			return false
	return int(main.party_hp) == summed_hp and int(main.party_max_hp) == summed_max

func _run_faction(faction: String) -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = faction
	main.idle_stage = 8
	main.idle_stage_kills = 0
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, 10).duplicate(true)
	main._offline_checked = true
	main.combat_effects_enabled = false
	main.battle_speed = 1.0
	main.loot_rng.seed = 2602 if faction == "aurelia" else 2603
	main._build_combat_screen()
	await process_frame
	_check(main.deployed_heroes.size() == 10 and main.hero_battle_state.size() == 10, faction + ": full 10-person party initialized")
	var gold_before := int(main.unclaimed_gold)
	var xp_before := int(main.unclaimed_xp)
	var previous_kills := int(main.combat_kills)
	var last_kill_time := 0.0
	var longest_kill_gap := 0.0
	var wipe_kills := 0
	var recovery_seconds := -1.0
	var recovery_seen := false
	var health_ok := true
	var checkpoints: Array[int] = []
	var completed_actions: Dictionary = {}
	for hero in main.deployed_heroes:
		completed_actions[str(hero["id"])] = 0
	for step in TOTAL_STEPS:
		var elapsed := float(step + 1) * STEP_SECONDS
		if step == WIPE_STEP:
			wipe_kills = int(main.combat_kills)
			for state in main.hero_battle_state.values():
				state["hp"] = 0
				state["alive"] = false
			main._sync_party_hp_from_heroes()
			# A wipe during looting should finish its already-earned loot transition;
			# put the fixture in active combat to exercise immediate retreat entry.
			main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
		var windups: Dictionary = {}
		for hero_id in completed_actions:
			windups[hero_id] = float(main.hero_skill_runtime[hero_id].get("windup", -1.0))
		var gold_at_step := int(main.unclaimed_gold)
		var enemy_hp_at_step := int(main.enemy_hp)
		main._advance_auto_hunt(STEP_SECONDS)
		if step == WIPE_STEP:
			recovery_seen = main.hunt_ai.state == AutoHuntController.State.RECOVERING
			_check(recovery_seen, faction + ": wipe enters recovery on next combat update")
			_check(int(main.combat_kills) == wipe_kills and int(main.unclaimed_gold) == gold_at_step, faction + ": wipe produces no kill or reward")
			_check(int(main.enemy_hp) == enemy_hp_at_step, faction + ": dead party deals no damage")
		if step > WIPE_STEP and recovery_seconds < 0.0 and main.hunt_ai.state != AutoHuntController.State.RECOVERING and main._alive_hero_ids().size() == 10:
			recovery_seconds = float(step - WIPE_STEP) * STEP_SECONDS
		for hero_id in completed_actions:
			var runtime: Dictionary = main.hero_skill_runtime[hero_id]
			if float(windups[hero_id]) >= 0.0 and float(runtime.get("windup", -1.0)) < 0.0 and float(runtime.get("attack_remaining", 0.0)) > 0.20:
				completed_actions[hero_id] = int(completed_actions[hero_id]) + 1
		if not _health_valid(main):
			health_ok = false
			_check(false, "%s: invalid health state at %.1f seconds" % [faction, elapsed])
			break
		if int(main.combat_kills) > previous_kills:
			longest_kill_gap = maxf(longest_kill_gap, elapsed - last_kill_time)
			last_kill_time = elapsed
			previous_kills = int(main.combat_kills)
		if (step + 1) % 600 == 0:
			checkpoints.append(int(main.combat_kills))
		# Flush queued sprite removals periodically; automatic physics remains off.
		if (step + 1) % 30 == 0:
			await process_frame
	longest_kill_gap = maxf(longest_kill_gap, 180.0 - last_kill_time)
	var active_heroes := 0
	for actions in completed_actions.values():
		if int(actions) > 0:
			active_heroes += 1
	_check(health_ok, faction + ": health remains bounded and party sum stays consistent")
	_check(active_heroes == 10, faction + ": every deployed hero completes combat actions")
	_check(checkpoints.size() == 3 and checkpoints[0] > 0 and checkpoints[1] > checkpoints[0] and checkpoints[2] > checkpoints[1], faction + ": encounter kills advance during every 60-second window")
	_check(longest_kill_gap < 60.0, faction + ": no minute-long combat stall")
	_check(recovery_seen and recovery_seconds > 0.0 and recovery_seconds < 15.0, faction + ": all 10 heroes return from wipe recovery within 15 seconds")
	_check(int(main.combat_kills) > wipe_kills, faction + ": encounter clears resume after wipe")
	_check(int(main.unclaimed_gold) > gold_before and int(main.unclaimed_xp) > xp_before, faction + ": ongoing combat awards gold and experience")
	var report := {
		"faction": faction, "simulated_seconds": 180, "party_size": main.deployed_heroes.size(),
		"kills_at_60_120_180_seconds": checkpoints, "kill_count": int(main.combat_kills),
		"gold_earned": int(main.unclaimed_gold) - gold_before, "xp_earned": int(main.unclaimed_xp) - xp_before,
		"wipe_recovery_seconds": recovery_seconds, "longest_kill_gap_seconds": snappedf(longest_kill_gap, 0.1),
		"heroes_with_completed_actions": active_heroes, "completed_actions_by_hero": completed_actions,
		"health_valid": health_ok, "distance_walked": snappedf(main.roaming_hunt.distance_walked, 0.1)
	}
	reports.append(report)
	print("V26 SOAK REPORT: ", JSON.stringify(report))
	main.free()
	await process_frame

func _run() -> void:
	await _run_faction("aurelia")
	await _run_faction("noxfera")
	if not failures.is_empty():
		push_error("v26_combat_soak_smoke_test_failed: " + "; ".join(failures))
		quit(1)
		return
	print("v26_combat_soak_smoke_test_ok checks=%d factions=2 heroes_per_party=10 simulated_seconds=360 wipe_recovery=ok continuous_rewards=ok" % checks)
	quit(0)
