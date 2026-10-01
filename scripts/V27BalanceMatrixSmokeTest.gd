extends SceneTree

# Production combat, targeting, movement, skills and reward paths run intact.
# Isolate persistence and HUD painting so rows cannot inherit one another's XP.
class BalanceFixture:
	extends "res://scripts/Main.gd"
	func _load_idle_state() -> void:
		pass
	func _save_idle_state() -> void:
		pass
	func _update_hunt_hud() -> void:
		pass
	func _update_map_tiles() -> void:
		pass

const SEEDS := [2701, 2713, 2741]
const STEP := 0.1
const SECONDS := 60
const ZONES := ["gray_meadow", "forgotten_mine", "moonrest_forest"]
var failures: Array[String] = []
var checks := 0
var reports: Array[Dictionary] = []
var hero_reports: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("V27 BALANCE FAIL: ", message)

func _fixture(faction: String, zone_id: String, party_size: int, level: int, equipment_level: int, fixture_seed: int):
	var main = BalanceFixture.new()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	main.selected_faction = faction
	main.current_zone_id = zone_id
	main.idle_stage = 25 # Both three- and ten-person formations are legal here.
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, party_size).duplicate(true)
	for hero in main.deployed_heroes:
		var hero_id := str(hero["id"])
		main.hero_progress[hero_id] = {"level": level, "xp": 0}
		main.hero_equipment[hero_id] = {"weapon": equipment_level, "armor": equipment_level, "accessory": equipment_level}
	main._offline_checked = true
	main.combat_effects_enabled = false
	main.battle_speed = 1.0
	main.loot_rng.seed = fixture_seed
	main._build_combat_screen()
	# The same patrol and loot seed in both factions isolates composition effects.
	main.roaming_hunt.configure(main.expedition_position, fixture_seed)
	main.roaming_hunt.spawn_group(main.enemy_wave)
	return main

func _run_row(faction: String, zone_id: String, party_size: int, level: int, equipment_level: int, fixture_seed: int, boundary := false) -> void:
	var main = _fixture(faction, zone_id, party_size, level, equipment_level, fixture_seed)
	await process_frame
	var initial_power := int(main._calculate_party_power())
	var initial_hp := int(main.party_max_hp)
	var initial_attack := 0
	for hero_id in main.hero_battle_state:
		var state: Dictionary = main.hero_battle_state[hero_id]
		initial_attack += int(state["attack"])
		if party_size == 10 and zone_id == ZONES[0] and not boundary:
			hero_reports.append({"faction": faction, "hero_id": hero_id, "role": state["role_group"], "level": level, "max_hp": state["max_hp"], "attack": state["attack"], "defense": state["defense"], "attack_interval_mult": state["attack_interval_mult"]})
	var offline: Dictionary = main.idle_hunt_estimator.estimate(SECONDS, initial_power, party_size, main._current_zone(), main.idle_stage, 0, main.idle_stage_target)
	var previous_state: int = main.hunt_ai.state
	var recoveries := 0
	var health_valid := true
	var min_alive := party_size
	var last_kill_step := 0
	var previous_kills := 0
	var longest_gap := 0.0
	for step in int(SECONDS / STEP):
		main._advance_auto_hunt(STEP)
		if main.hunt_ai.state == AutoHuntController.State.RECOVERING and previous_state != AutoHuntController.State.RECOVERING:
			recoveries += 1
		previous_state = main.hunt_ai.state
		min_alive = mini(min_alive, main._alive_hero_ids().size())
		var summed_hp := 0
		for state in main.hero_battle_state.values():
			health_valid = health_valid and int(state["hp"]) >= 0 and int(state["hp"]) <= int(state["max_hp"]) and bool(state["alive"]) == (int(state["hp"]) > 0)
			summed_hp += int(state["hp"])
		health_valid = health_valid and int(main.party_hp) == summed_hp
		if int(main.combat_kills) > previous_kills:
			longest_gap = maxf(longest_gap, float(step - last_kill_step) * STEP)
			last_kill_step = step
			previous_kills = int(main.combat_kills)
		if step % 30 == 0:
			await process_frame
	longest_gap = maxf(longest_gap, SECONDS - float(last_kill_step) * STEP)
	var prefix := "%s/%s/%d/Lv%d/seed%d" % [faction, zone_id, party_size, level, fixture_seed]
	_check(health_valid, prefix + ": HP/alive/sum invariants")
	_check(int(main.combat_kills) > 0, prefix + ": at least one full encounter completes")
	_check(int(main.unclaimed_gold) >= 0 and int(main.unclaimed_xp) >= 0, prefix + ": reward counters remain nonnegative")
	_check(initial_power > 0 and initial_hp > 0 and initial_attack > 0, prefix + ": actual combat stats remain positive")
	var report := {
		"faction": faction, "zone": zone_id, "party_size": party_size, "hero_level": level,
		"equipment_level": equipment_level, "seed": fixture_seed, "seconds": SECONDS, "boundary": boundary,
		"initial_power": initial_power, "initial_hp": initial_hp, "initial_attack_sum": initial_attack,
		"encounters_cleared": int(main.combat_kills), "online_gold": int(main.unclaimed_gold), "online_xp": int(main.unclaimed_xp),
		"offline_gold_estimate": int(offline["gold"]), "offline_encounters_estimate": int(offline["kills"]),
		"offline_online_gold_ratio": snappedf(float(offline["gold"]) / maxf(1.0, float(main.unclaimed_gold)), 0.001),
		"recoveries": recoveries, "minimum_alive": min_alive, "health_valid": health_valid,
		"longest_clear_gap_seconds": snappedf(longest_gap, 0.1)
	}
	reports.append(report)
	print("V27 BALANCE ROW: ", JSON.stringify(report))
	main.free()
	await process_frame

func _check_growth_and_zones() -> void:
	var main = _fixture("aurelia", "gray_meadow", 10, 1, 1, SEEDS[0])
	var previous_power := 0
	var previous_hp := 0
	var previous_attack := 0
	for level in [1, 10, 50, 100]:
		for hero in main.deployed_heroes:
			main.hero_progress[str(hero["id"])] = {"level": level, "xp": 0}
		main._setup_hero_battle_state()
		var power := int(main._calculate_party_power())
		var attack := 0
		for state in main.hero_battle_state.values():
			attack += int(state["attack"])
		_check(power > previous_power and int(main.party_max_hp) > previous_hp and attack > previous_attack, "actual level growth remains strictly monotonic through Lv%d" % level)
		previous_power = power
		previous_hp = int(main.party_max_hp)
		previous_attack = attack
	var previous_cost := 0
	for level in range(1, 11):
		var cost := int(main._equipment_upgrade_cost("weapon", level))
		_check(cost > previous_cost, "equipment gold cost grows at +%d" % level)
		previous_cost = cost
	var previous_enemy_hp := 0
	var previous_reward := 0
	for zone_id in ZONES:
		main.current_zone_id = zone_id
		main.hunt_ai.encounter_id = 1
		main.hunt_ai.target_index = -1
		main._spawn_enemy_wave(main._current_zone())
		var total_enemy_hp := 0
		for enemy in main.enemy_wave:
			total_enemy_hp += int(enemy["max_hp"])
		_check(total_enemy_hp > previous_enemy_hp, zone_id + ": actual spawned wave health increases")
		_check(int(main._current_zone()["gold"]) > previous_reward, zone_id + ": per-encounter reward increases")
		previous_enemy_hp = total_enemy_hp
		previous_reward = int(main._current_zone()["gold"])
	main.free()

func _check_faction_matrix() -> void:
	# Starter roles intentionally differ. This broad dominance guard does not
	# imply that a sixty-second sample proves faction parity.
	for zone_id in ZONES:
		for party_size in [3, 10]:
			var pair: Array[Dictionary] = []
			for row in reports:
				if not row["boundary"] and row["zone"] == zone_id and row["party_size"] == party_size:
					pair.append(row)
			_check(pair.size() == 2, "faction comparison has both rows: %s/%d" % [zone_id, party_size])
			if pair.size() == 2:
				var low := mini(int(pair[0]["encounters_cleared"]), int(pair[1]["encounters_cleared"]))
				var high := maxi(int(pair[0]["encounters_cleared"]), int(pair[1]["encounters_cleared"]))
				_check(high <= maxi(2, low * 2), "neither faction exceeds twice the actual encounter throughput: %s/%d" % [zone_id, party_size])
				if party_size == 10:
					for stat in ["initial_power", "initial_hp", "initial_attack_sum"]:
						var low_stat := minf(float(pair[0][stat]), float(pair[1][stat]))
						var high_stat := maxf(float(pair[0][stat]), float(pair[1][stat]))
						_check(high_stat <= low_stat * 1.10, "ten-person actual stat gap remains within 10 percent: %s/%s" % [zone_id, stat])
	_check(hero_reports.size() == 20, "all twenty actual hero stat records captured")

func _check_idle_monotonic() -> void:
	var main = BalanceFixture.new()
	var estimator := IdleHuntEstimator.new()
	for zone_id in ZONES:
		var zone: Dictionary = main._zone_data()[zone_id]
		var previous_kills := 0
		var previous_gold := 0
		for power in [1, 100, 1000, 10000, 1000000000]:
			var estimate := estimator.estimate(3600, power, 3, zone, 25, 0, 10)
			_check(int(estimate["kills"]) >= previous_kills and int(estimate["gold"]) >= previous_gold, "%s: raising party power to %d cannot reduce idle payout" % [zone_id, power])
			previous_kills = int(estimate["kills"])
			previous_gold = int(estimate["gold"])
		previous_gold = 0
		for party_size in [1, 3, 6, 10]:
			var estimate := estimator.estimate(3600, 1000, party_size, zone, 25, 0, 10)
			_check(int(estimate["gold"]) >= previous_gold, "%s: raising party size to %d cannot reduce idle payout at fixed power" % [zone_id, party_size])
			previous_gold = int(estimate["gold"])
		previous_gold = 0
		for seconds in [0, 1, 60, 3600, 28800]:
			var estimate := estimator.estimate(seconds, 1000, 3, zone, 25, 0, 10)
			_check(int(estimate["gold"]) >= previous_gold, "%s: increasing idle duration to %d cannot reduce gold" % [zone_id, seconds])
			previous_gold = int(estimate["gold"])
	main.free()

func _run() -> void:
	var contracts_only := "--contracts-only" in OS.get_cmdline_user_args()
	if not contracts_only:
		for faction in ["aurelia", "noxfera"]:
			for zone_id in ZONES:
				for party_size in [3, 10]:
					await _run_row(faction, zone_id, party_size, 10, 3, SEEDS[0])
		# Low-power teams at the same unlocked stage exercise three patrol seeds.
		for fixture_seed in SEEDS:
			await _run_row("aurelia", "gray_meadow", 3, 1, 1, fixture_seed, true)
	_check_growth_and_zones()
	_check_idle_monotonic()
	if not contracts_only:
		_check_faction_matrix()
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			output_path = argument.trim_prefix("--report=")
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		_check(file != null, "report path can be written")
		if file != null:
			file.store_string(JSON.stringify({"schema": 1, "checks": checks, "failures": failures, "rows": reports, "heroes": hero_reports}, "\t") + "\n")
	if not failures.is_empty():
		push_error("v27_balance_matrix_smoke_test_failed: " + "; ".join(failures))
		quit(1)
		return
	print("v27_balance_matrix_smoke_test_ok checks=%d rows=%d heroes=%d faction_throughput_guard=2x measured_not_rating=true" % [checks, reports.size(), hero_reports.size()])
	quit(0)
