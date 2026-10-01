extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main._offline_checked = true
	main.selected_faction = "aurelia"
	main.hero_progress.clear()
	main.hero_equipment.clear()
	main.current_zone_id = "gray_meadow"
	main.idle_stage = 8
	main._restore_deployed_heroes(["leonhardt", "mira", "orwin", "darius", "caelum"])
	main.combat_effects_enabled = false
	main.battle_speed = 1.0
	main.loot_rng.seed = 280028
	main._build_combat_screen()
	await process_frame
	check(main.party_movement.positions.size() == 5, "All five heroes own world positions")
	check(main.roaming_hunt.FIELD_MAX.x > 30.0 and main.roaming_hunt.FIELD_MAX.y > 19.0, "World expands to 32 by 20")
	var initial_positions: Dictionary = main.party_movement.positions.duplicate()
	var initial_relative: Vector2 = initial_positions["mira"] - initial_positions["leonhardt"]
	var relative_changed := false
	var maximum_step := 0.0
	var walkable := true
	var camera_moved := false
	var initial_camera: Vector2 = main.combat_camera_position
	for tick in 600:
		var before: Dictionary = main.party_movement.positions.duplicate()
		main._advance_auto_hunt(0.1)
		for id in main.party_movement.positions:
			var position: Vector2 = main.party_movement.positions[id]
			maximum_step = maxf(maximum_step, position.distance_to(before[id]))
			walkable = walkable and main.field_navigation.is_walkable(position)
		var relative: Vector2 = main.party_movement.positions["mira"] - main.party_movement.positions["leonhardt"]
		relative_changed = relative_changed or relative.distance_to(initial_relative) > 0.4
		camera_moved = camera_moved or main.combat_camera_position.distance_to(initial_camera) > 1.0
		if tick % 30 == 0:
			await process_frame
	check(relative_changed, "Heroes maneuver independently rather than retaining a fixed formation")
	check(maximum_step <= PartyMovementDirector.WALK_SPEED * 0.1 + 0.00001, "No hero teleports between packs")
	check(walkable, "Every hero movement remains on navigable terrain")
	check(main.combat_kills >= 3, "Continuous roaming acquires and clears multiple packs")
	check(camera_moved, "Camera follows moving party across expanded map")
	for id in main.party_movement.distance_walked:
		check(float(main.party_movement.distance_walked[id]) > 3.0, "%s travels while hunting" % id)
	var frozen: Dictionary = main.party_movement.positions.duplicate()
	main.combat_running = false
	main._advance_auto_hunt(0.4)
	check(main.party_movement.positions == frozen, "Pause freezes every world position")
	main.combat_running = true
	# Reach assertions require living actors independently of preceding battle outcomes.
	for hero_id in ["leonhardt", "mira"]:
		main.hero_battle_state[hero_id]["hp"] = main.hero_battle_state[hero_id]["max_hp"]
		main.hero_battle_state[hero_id]["alive"] = true
	# The preceding simulation may end between packs. Reach tests need a live wave.
	main.roaming_wave_spawn_cooldown = 0.0
	main._ensure_roaming_wave()
	var origin: Vector2 = main.party_movement.positions["leonhardt"]
	main.roaming_hunt.enemy_positions[0] = origin + Vector2(0.65, 0)
	main.roaming_hunt.enemy_returning[0] = false
	main.enemy_wave[0]["hp"] = 100
	main.party_movement.positions["mira"] = origin + Vector2(-4, 0)
	check(main._can_attack_enemy("leonhardt", 0), "Melee checks its own world reach")
	check(not main._can_attack_enemy("mira", 0), "A distant ranged hero cannot inherit party-centre reach")
	main.roaming_hunt.enemy_returning[0] = true
	check(not main._can_attack_enemy("leonhardt", 0), "Returning monsters cannot be attacked")
	var projected_a: Vector2 = main._map_world_position(origin)
	var projected_b: Vector2 = main._map_world_position(origin + Vector2(1, 1))
	check(is_equal_approx(projected_b.x - projected_a.x, projected_b.y - projected_a.y), "Projection uses the same scale on both axes")
	var outside: Vector2 = main._map_world_position(main.combat_camera_position + Vector2(100, 0))
	check(outside.x > main.combat_field_rect.end.x, "Offscreen actors project beyond viewport without edge sticking")
	check(main.combat_labels["actor_clip"].clip_contents, "Field clips actors at the viewport boundary")
	check(main.hero_map_sprites[0].get_parent() == main.combat_labels["actor_layer"], "Heroes use the shared clipped actor layer")
	check(main.enemy_wave_sprites[0].get_parent() == main.combat_labels["actor_layer"], "Enemies use the shared clipped actor layer")
	var scale: Vector2 = main._combat_map_scale()
	var anchor: Vector2 = main._combat_camera_anchor() - main.combat_field_rect.position
	var low: Vector2 = main._clamp_combat_camera(Vector2(-100, -100))
	var high: Vector2 = main._clamp_combat_camera(Vector2(100, 100))
	check((low - anchor / scale).length() < 0.0001, "Camera preserves top-left world boundary without showing empty space")
	check((high + (main.combat_field_rect.size - anchor) / scale - RoamingHuntDirector.WORLD_SIZE).length() < 0.0001, "Camera preserves bottom-right world boundary without stretching terrain")
	print("V28 moving hunt: checks=%d clears=%d max_step=%.5f nav=%s" % [checks, main.combat_kills, maximum_step, JSON.stringify(main.field_navigation.get_debug_stats())])
	main.free()
	if failures.is_empty():
		print("v28_moving_hunt_smoke_test_ok")
	quit(0 if failures.is_empty() else 1)
