extends "res://scripts/V27BalanceMatrixSmokeTest.gd"

func _run() -> void:
	_test_habitat_kiting()
	for faction in ["aurelia", "noxfera"]:
		await _run_row(faction, "moonrest_forest", 3, 10, 3, 2701)
	var low := mini(int(reports[0]["encounters_cleared"]), int(reports[1]["encounters_cleared"]))
	var high := maxi(int(reports[0]["encounters_cleared"]), int(reports[1]["encounters_cleared"]))
	_check(high <= maxi(2, low * 2), "Forest starter parties retain the existing twofold throughput guard")
	for report in reports:
		_check(float(report["longest_clear_gap_seconds"]) < 30.0, "Forest party does not stall by repeatedly pulling the last assassin out of its habitat")
	if failures.is_empty():
		print("v28_kiting_regression_smoke_test_ok checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)

func _test_habitat_kiting() -> void:
	var home := Vector2(16.0, 10.0)
	var chase := RoamingHuntDirector.new()
	chase.configure(home + Vector2(2.4, 0), 28)
	var enemies: Array = [{"hp":1000,"max_hp":1000,"archetype":"assassin","leash_radius":3.05,"sight_radius":2.8}]
	chase.spawn_group(enemies)
	chase.enemy_positions[0] = home
	chase.enemy_home_positions[0] = home
	chase.aggro_active = true
	chase.current_target = 0
	chase.mode = RoamingHuntDirector.Mode.ENGAGED
	var heroes: Array = [{"id":"healer"}]
	var states := {"healer":{"hp":1000,"range":3,"slot":0}}
	var movement := PartyMovementDirector.new()
	movement.configure(heroes, states, home + Vector2(2.4, 0))
	movement.positions["healer"] = home + Vector2(2.4, 0)
	var runtimes := {"healer":{"windup":-1.0}}
	var resets := 0
	var max_distance := 0.0
	var max_step := 0.0
	for tick in 300:
		var target_positions: Array[Vector2] = [movement.positions["healer"]]
		var result := chase.advance(0.05, [true], [], target_positions)
		resets += result["returned_indices"].size()
		var before: Vector2 = movement.positions["healer"]
		movement.advance(0.05, heroes, states, runtimes, chase.party_position, enemies, chase.enemy_positions, chase.enemy_returning, true, false, chase.enemy_home_positions)
		var after: Vector2 = movement.positions["healer"]
		max_distance = maxf(max_distance, after.distance_to(home))
		max_step = maxf(max_step, before.distance_to(after))
	_check(resets == 0, "A ranged hero does not trigger repeated full-health leash resets while kiting one assassin")
	_check(max_distance <= 3.05, "Ranged retreat remains inside the contested habitat")
	_check(max_step <= PartyMovementDirector.WALK_SPEED * 0.05 + 0.00001, "Habitat-aware retreat does not teleport")
	_check(float(movement.distance_walked["healer"]) > 0.3, "Ranged hero still repositions under pressure")
