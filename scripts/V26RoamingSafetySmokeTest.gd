extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func make_director(archetypes: Array) -> RoamingHuntDirector:
	var director := RoamingHuntDirector.new()
	director.configure(Vector2(3.0, 2.0), 260922)
	var enemies: Array = []
	for archetype in archetypes:
		enemies.append({"archetype": archetype, "hp": 100})
	director.spawn_group(enemies)
	return director

func place_pair(director: RoamingHuntDirector, first_distance: float, second_distance: float) -> void:
	director.party_position = Vector2(3.0, 2.0)
	director.enemy_positions[0] = Vector2(3.0 - first_distance, 2.0)
	director.enemy_positions[1] = Vector2(3.0 + second_distance, 2.0)

func _init() -> void:
	_test_stable_targeting()
	_test_dead_targets_and_zero_time()
	_test_recovery()
	_test_attack_reach_and_spacing()
	_test_engagement_boundary()
	if failures.is_empty():
		print("v26_roaming_safety_smoke_test_ok target_lock=ok dead_target=ok recovery=ok melee_reach=ok spacing=ok engagement=ok")
	quit(0 if failures.is_empty() else 1)

func _test_stable_targeting() -> void:
	var director := make_director(["brute", "brute"])
	director.aggro_active = true
	director.current_target = 0
	director.mode = RoamingHuntDirector.Mode.ENGAGED
	# Nearly tied monsters on opposite sides must not flip the party's heading.
	for step in 60:
		place_pair(director, 0.70, 0.69 if step % 2 == 0 else 0.71)
		var result := director.advance(0.05, [true, true])
		check(int(result["target_index"]) == 0, "Nearly tied monsters caused target oscillation")
	place_pair(director, 1.2, 0.65)
	director.advance(0.01, [true, true])
	check(director.current_target == 1, "Materially closer target was never adopted")
	place_pair(director, 0.65, 1.2)
	director.advance(0.01, [true, true])
	check(director.current_target == 1, "Target lock did not survive the next frame")
	for _step in 14:
		place_pair(director, 0.65, 1.2)
		director.advance(0.05, [true, true])
	check(director.current_target == 0, "Target lock prevented a needed switch indefinitely")
	var result := director.advance(0.01, [false, true])
	check(int(result["target_index"]) == 1, "Dead target was retained during its lock")
	# A live target beyond the leash must not hide another reachable monster.
	director.party_position = Vector2(0.4, 0.4)
	director.enemy_positions[1] = Vector2(5.8, 3.6)
	director.enemy_positions[0] = director.party_position + Vector2(0.6, 0.0)
	director.advance(0.01, [true, true])
	check(director.current_target == 0 and director.aggro_active, "Lost target did not retarget a reachable monster")

func _test_dead_targets_and_zero_time() -> void:
	var director := make_director(["brute"])
	director.aggro_active = true
	director.current_target = 0
	director.mode = RoamingHuntDirector.Mode.ENGAGED
	var result := director.advance(0.1, [false])
	check(int(result["target_index"]) == -1 and director.current_target == -1, "All-dead result leaked a stale target")
	check(not bool(result["engaged"]) and not director.aggro_active, "All-dead wave remained engaged")
	director.aggro_active = true
	director.current_target = 0
	director.mode = RoamingHuntDirector.Mode.ENGAGED
	var before := director.party_position
	result = director.advance(0.0, [true])
	check(bool(result["engaged"]) and int(result["mode"]) == RoamingHuntDirector.Mode.ENGAGED, "Zero-time snapshot contradicted an active engagement")
	check(director.party_position == before, "Zero-time update moved the party")
	result = director.advance(0.0, [])
	check(int(result["target_index"]) == -1 and not bool(result["engaged"]), "Short alive mask leaked a dead target at zero time")
	result = director.advance(INF, [])
	check(director.party_position == before, "Non-finite delta corrupted movement")

func _test_recovery() -> void:
	var director := make_director(["assassin"])
	director.enemy_positions[0] = director.party_position + Vector2(0.4, 0.0)
	director.aggro_active = true
	director.current_target = 0
	director.mode = RoamingHuntDirector.Mode.RECOVER
	var before := director.party_position
	var enemy_before := director.enemy_positions[0]
	for _step in 30:
		var result := director.advance(0.1, [true])
		check(int(result["mode"]) == RoamingHuntDirector.Mode.RECOVER, "Recovery was overwritten by chase")
		check(not bool(result["engaged"]) and not bool(result["encounter_started"]), "Recovery re-entered combat")
	check(director.party_position == before and director.enemy_positions[0] == enemy_before, "Recovery advanced combat movement")
	check(director.current_target == -1 and not director.aggro_active, "Recovery retained an active target")
	director.mode = RoamingHuntDirector.Mode.PATROL
	var resumed := director.advance(0.1, [true])
	check(bool(resumed["encounter_started"]), "Explicit recovery exit failed to resume hunting")

func _test_attack_reach_and_spacing() -> void:
	for archetype in ["brute", "ranged", "support", "assassin", "skirmisher"]:
		var director := make_director([archetype])
		director.party_position = Vector2(0.5, 2.0)
		director.enemy_positions[0] = Vector2(3.0, 2.0)
		director.aggro_active = true
		director.current_target = 0
		director.mode = RoamingHuntDirector.Mode.CHASE
		var reached_melee := false
		for _step in 200:
			director.advance(0.05, [true])
			reached_melee = reached_melee or director.enemy_distance(0) <= 0.95
		check(reached_melee, "Party stalled outside melee range against %s" % archetype)
		check(director.enemy_distance(0) > 0.1, "Party overlapped %s during chase" % archetype)
	var slow_frame := make_director(["support"])
	slow_frame.enemy_positions[0] = slow_frame.party_position + Vector2(1.8, 0.0)
	slow_frame.aggro_active = true
	slow_frame.current_target = 0
	slow_frame.mode = RoamingHuntDirector.Mode.CHASE
	slow_frame.advance(3.0, [true])
	check(slow_frame.enemy_distance(0) > 0.8 and slow_frame.enemy_distance(0) <= 0.95, "Slow frame stepped through the enemy instead of stopping in melee range")

func _test_engagement_boundary() -> void:
	var director := make_director(["support"])
	director.enemy_positions[0] = director.party_position + Vector2(1.43, 0.0)
	director.aggro_active = true
	director.current_target = 0
	director.mode = RoamingHuntDirector.Mode.ENGAGED
	var result := director.advance(0.001, [true])
	check(bool(result["engaged"]), "Small attack-boundary drift reset an existing engagement")
	director.mode = RoamingHuntDirector.Mode.CHASE
	result = director.advance(0.001, [true])
	check(not bool(result["engaged"]), "A new encounter started beyond the attack zone")
