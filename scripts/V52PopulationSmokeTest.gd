extends SceneTree

const Ecology = preload("res://scripts/FieldEcology.gd")
const Navigation = preload("res://scripts/MeadowNavigation.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _enemies(count: int) -> Array:
	var enemies: Array = []
	for index in count:
		enemies.append(Ecology.prepare_enemy({"name":"", "archetype":["brute", "ranged", "support", "assassin"][index % 4], "max_hp":100, "attack":10}, 1, 1, 1))
	return enemies

func _spawn_matrix() -> void:
	for heroes in range(1, 11):
		var easy := Ecology.population_count(heroes, 1)
		_check(easy >= 8 and easy <= 16, "v70 easy-field density remains bounded: %d" % heroes)
		_check(Ecology.population_count(heroes, 3) == mini(20, easy + 4), "Harder fields add two reserve packs: %d" % heroes)
	_check(Ecology.population_count(-100, -100) == 8 and Ecology.population_count(100000, 1000) == 20, "Population has v70 safe lower and upper bounds")
	var nav := Navigation.new()
	var origins: Array[Vector2] = [Vector2(0.35, 0.35), Vector2(31.65, 0.35), Vector2(0.35, 19.65), Vector2(31.65, 19.65), Vector2(6.9, 6.2), Vector2(16, 10)]
	for origin in origins:
		for seed_value in 16:
			for population in [8, 20]:
				var director := RoamingHuntDirector.new()
				director.field_navigation = nav
				director.configure(origin, 52000 + seed_value)
				director.spawn_group(_enemies(population))
				var walkable := true
				var safe := true
				var separated := true
				var packs_separated := true
				for index in director.enemy_positions.size():
					var point := director.enemy_position(index)
					walkable = walkable and nav.is_walkable(point) and nav.travel_distance(director.party_position, point) < INF
					safe = safe and point.distance_to(director.party_position) >= RoamingHuntDirector.SPAWN_SAFE_DISTANCE - 0.00001
					for other in range(index):
						separated = separated and point.distance_to(director.enemy_position(other)) >= RoamingHuntDirector.SPAWN_SEPARATION - 0.00001
				for index in director.pack_centers.size():
					for other in range(index):
						packs_separated = packs_separated and director.pack_centers[index].distance_to(director.pack_centers[other]) >= RoamingHuntDirector.PACK_SEPARATION - 0.00001
				if not (walkable and safe and separated and packs_separated):
					print("SPAWN DIAGNOSTIC: ", [walkable, safe, separated, packs_separated], " centers=", director.pack_centers, " positions=", director.enemy_positions)
				_check(walkable and safe and separated and packs_separated, "Navigable, safe, separated pack spawn %s seed=%d population=%d" % [origin, seed_value, population])
				_check(director.pack_centers.size() >= 2 and director.enemy_alerted.count(true) == 0, "A fresh habitat has multiple unalerted packs")
	# Patrol crosses the pond using real routes and deliberately visits each
	# remaining pack. Simulated kills remove only targets reached in melee.
	for seed_value in 8:
		var director := RoamingHuntDirector.new()
		director.field_navigation = nav
		director.configure(Vector2(6.9, 6.2), 52200 + seed_value)
		director.spawn_group(_enemies(20))
		var alive: Array = []
		alive.resize(20)
		alive.fill(true)
		var traversable := true
		for tick in 1800:
			var before := director.party_position
			director.advance(0.1, alive)
			traversable = traversable and nav.is_walkable(director.party_position) and nav.has_clear_path(before, director.party_position) and before.distance_to(director.party_position) <= RoamingHuntDirector.PARTY_SPEED * 0.1 + 0.00001
			for index in alive.size():
				if bool(alive[index]) and not director.is_returning(index) and director.enemy_distance(index) <= 1.1 and nav.has_clear_path(director.party_position, director.enemy_position(index)):
					alive[index] = false
			if alive.count(true) == 0:
				break
		_check(traversable and alive.count(true) == 0, "Every separated pack remains reachable without movement jumps seed=%d" % seed_value)
	var local := RoamingHuntDirector.new()
	local.configure(Vector2(10, 10), 52)
	local.spawn_group(_enemies(4))
	local.enemy_positions.assign([Vector2(10.8, 10), Vector2(11.3, 10), Vector2(17, 10), Vector2(17.5, 10)])
	local.enemy_home_positions = local.enemy_positions.duplicate()
	local.current_target = 0
	local.aggro_active = true
	local.advance(0.1, [true, true, true, true])
	_check(local.enemy_alerted[0] and local.enemy_alerted[1] and not local.enemy_alerted[2] and not local.enemy_alerted[3], "Fighting a near pack does not globally alert reserve packs")
	local.clear_enemies()
	_check(local.enemy_pack_ids.is_empty() and local.pack_centers.is_empty() and local.enemy_positions.is_empty(), "Respawn removes all old habitat metadata")

func _live_party(faction: String, heroes: int) -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.party_slot_legacy_cap = 10
	main.selected_faction = faction
	main.hero_progress.clear()
	main.hero_equipment.clear()
	main.current_zone_id = "gray_meadow"
	main.idle_stage = 1 if heroes == 1 else 3
	main.idle_stage_kills = 0
	main._offline_checked = true
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, heroes).duplicate(true)
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	main.battle_speed = 1.0
	main.loot_rng.seed = 52400 + heroes
	main._build_combat_screen()
	await process_frame
	_check(main.enemy_wave.size() == Ecology.population_count(heroes, 1), "Live habitat uses expanded population %s/%d" % [faction, heroes])
	_check(main.enemy_wave.size() == main.enemy_wave_sprites.size() and main.enemy_wave.size() == main.enemy_hp_bars.size(), "Live actors and health bars cover every monster")
	var elite_count := 0
	for enemy in main.enemy_wave:
		if bool(enemy.get("elite", false)): elite_count += 1
	_check(elite_count == (0 if heroes == 1 else 1), "Population increase does not duplicate elites")
	var navigable := true
	var bounded := true
	var kills_before: int = main.combat_kills
	var gold_before: int = main.unclaimed_gold
	for tick in 900:
		main._advance_auto_hunt(0.1)
		for point: Vector2 in main.roaming_hunt.enemy_positions:
			navigable = navigable and main.field_navigation.is_walkable(point)
		for state in main.hero_battle_state.values():
			bounded = bounded and int(state["hp"]) >= 0 and int(state["hp"]) <= int(state["max_hp"])
		if tick % 30 == 0:
			await process_frame
	_check(main.combat_kills > kills_before, "Live party clears separated habitat %s/%d" % [faction, heroes])
	_check(navigable and bounded, "Live navigation and health remain valid %s/%d" % [faction, heroes])
	print("V52 POPULATION LIVE: faction=%s heroes=%d clears=%d gold=%d position=%s" % [faction, heroes, main.combat_kills - kills_before, main.unclaimed_gold - gold_before, main.roaming_hunt.party_position])
	# The enlarged habitat still grants its encounter reward exactly once.
	main.roaming_wave_spawn_cooldown = 0.0
	main._ensure_roaming_wave()
	for enemy in main.enemy_wave:
		enemy["hp"] = 0
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main._rewarded_encounter = -1
	for state in main.hero_battle_state.values():
		state["hp"] = state["max_hp"]
		state["alive"] = true
	main._sync_party_hp_from_heroes()
	main._finish_hunt_target()
	var gold: int = main.unclaimed_gold
	var xp: int = main.unclaimed_xp
	var kills: int = main.combat_kills
	main._finish_hunt_target()
	_check(main.unclaimed_gold == gold and main.unclaimed_xp == xp and main.combat_kills == kills, "Repeated habitat completion cannot duplicate rewards")
	main.free()
	await process_frame

func _run() -> void:
	_spawn_matrix()
	for faction in ["aurelia", "noxfera"]:
		await _live_party(faction, 1)
		await _live_party(faction, 10)
	print("V52PopulationSmokeTest: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
