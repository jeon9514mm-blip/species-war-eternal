extends SceneTree

func _fail(message: String, main) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main.idle_stage = 8
	var roster: Array = main._hero_roster_for_faction()
	main.deployed_heroes = roster.slice(0, 10).duplicate()
	main._offline_checked = true
	main._build_combat_screen()
	await process_frame

	if main.hero_battle_state.size() != 10 or main.hero_hp_bars.size() != 10:
		_fail("V6 requires independent battle state and HP bars for all 10 heroes", main)
		return
	var expected_population := preload("res://scripts/hunting/FieldEcology.gd").population_count(10, 1)
	if main.enemy_wave.size() != expected_population or main.enemy_wave_sprites.size() != expected_population or main.enemy_hp_bars.size() != expected_population:
		_fail("A full 10-person party should populate the denser v70 field", main)
		return
	for hero_id in main.hero_battle_state.keys():
		var state: Dictionary = main.hero_battle_state[hero_id]
		if int(state["hp"]) <= 0 or int(state["max_hp"]) <= 0:
			_fail("Hero battle HP initialization failed", main)
			return

	# A nearby enemy must respect tank guard. Field combat now measures each
	# hero's actual position, so distant spawn packs are not a melee fixture.
	var leonhardt_position: Vector2 = main._hero_field_position("leonhardt")
	main.roaming_hunt.enemy_positions[3] = leonhardt_position + Vector2(0.35, 0.0)
	main.hero_skill_runtime["leonhardt"]["remaining"] = 0.0
	main._cast_combat_skill("leonhardt", 0)
	if main._select_hero_target_for_enemy(3, true) != "leonhardt":
		_fail("Tank taunt/aggro priority failed", main)
		return
	# Taunt cannot make a distant tank reachable. Put a living ally beside the
	# same enemy while retaining Leonhardt's active guard/taunt state.
	var mira_position: Vector2 = main._hero_field_position("mira")
	main.party_movement.positions["mira"] = leonhardt_position + Vector2(4.0, 0.0)
	main.roaming_hunt.enemy_positions[3] = main._hero_field_position("mira") + Vector2(0.25, 0.0)
	main.enemy_wave[3]["target_id"] = "leonhardt"
	if main._select_hero_target_for_enemy(3, true) != "mira":
		_fail("Remote tank taunt bypassed the actual hero attack range", main)
		return
	main.party_movement.positions["mira"] = mira_position

	# A healer should pick the lowest-health living ally rather than healing a shared party pool.
	var mira: Dictionary = main.hero_battle_state["mira"]
	mira["hp"] = maxi(1, int(mira["max_hp"] * 0.25))
	main._sync_party_hp_from_heroes()
	var before_heal = int(mira["hp"])
	main.hero_skill_runtime["elisia"]["remaining"] = 0.0
	main._cast_combat_skill("elisia", 0)
	if int(main.hero_battle_state["mira"]["hp"]) <= before_heal:
		_fail("Lowest-HP ally healing failed", main)
		return

	# Caelum's V6 combat adapter is an AoE skill and must damage multiple enemies.
	# V28 obeys live hero range. Put the encounter beside Caelum, retaining
	# the original multi-target expectation instead of attacking distant spawns.
	for index in main.roaming_hunt.enemy_positions.size():
		main.roaming_hunt.enemy_positions[index] = main._hero_field_position("caelum") + Vector2(0.55 + float(index) * 0.04, 0.05 * float(index % 2))
	main.hero_skill_runtime["caelum"]["remaining"] = 0.0
	var before: Array[int] = []
	for enemy in main.enemy_wave:
		before.append(int(enemy["hp"]))
	main._cast_combat_skill("caelum", main._select_enemy_target("caelum"))
	var damaged = 0
	for index in main.enemy_wave.size():
		if int(main.enemy_wave[index]["hp"]) < before[index]:
			damaged += 1
	if damaged < 2:
		_fail("AoE skill did not damage multiple enemies", main)
		return

	print("v6_combat_smoke_test_ok heroes=10 enemies=%d aoe_targets=%d tank_target=%s" % [main.enemy_wave.size(), damaged, main._select_hero_target_for_enemy(1)])
	main.free()
	# AudioServer releases stopped playback on its next mix, not the render frame.
	await create_timer(0.3).timeout
	quit(0)
