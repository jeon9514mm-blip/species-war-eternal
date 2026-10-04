extends SceneTree
const Ecology = preload("res://scripts/FieldEcology.gd")
var checks := 0
var failures := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var director := RoamingHuntDirector.new()
	director.configure(Vector2(3.0, 2.0), 27)
	director.spawn_group([{"archetype":"brute", "leash_radius":1.0, "sight_radius":2.5}])
	director.enemy_home_positions[0] = Vector2(1.0, 2.0)
	director.enemy_positions[0] = Vector2(4.0, 2.0)
	director.enemy_alerted[0] = true
	director.aggro_active = true
	director.current_target = 0
	var result := director.advance(0.1, [true])
	_check(director.is_returning(0), "Pulled monster returns to its habitat")
	_check(int(result["target_index"]) == -1 and not result["engaged"], "Returning monster cannot hold a combat target")
	var home_events := 0
	for tick in 40:
		result = director.advance(0.1, [true])
		home_events += result["returned_indices"].size()
		if home_events > 0: break
	_check(home_events == 1 and not director.is_returning(0), "Home completion emits one reset event")
	_check(director.enemy_position(0).distance_to(director.enemy_home_positions[0]) < 0.09, "Return lands at habitat")

	director.configure(Vector2(3.0, 2.0), 27)
	director.spawn_group([{"archetype":"assassin"}, {"archetype":"ranged"}])
	director.enemy_positions[0] = Vector2(4.0, 2.0)
	director.enemy_positions[1] = Vector2(5.0, 2.5)
	director.aggro_active = true
	var frozen := director.enemy_position(0)
	var mobile := director.enemy_position(1)
	director.advance(0.1, [true, true], [true, false])
	_check(director.enemy_position(0) == frozen and director.enemy_position(1) != mobile, "Stun freezes only the affected monster")

	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_skills()
	main.active_screen = "combat"
	main.combat_running = true
	main.combat_fx.enabled = false
	main.combat_effects_enabled = false
	for zone_id in main._zone_data():
		main.current_zone_id = zone_id
		var zone: Dictionary = main._current_zone()
		main._spawn_enemy_wave(zone)
		_check(main.enemy_wave.size() == main.roaming_hunt.enemy_positions.size(), zone_id + " field/runtime population agrees")
		for enemy in main.enemy_wave:
			_check(str(enemy["archetype"]) == str(Ecology.species_profile(str(enemy["name"]))["role"]), "Species combat identity remains stable")
			_check(float(enemy["leash_radius"]) > 0.0 and float(enemy["healing_range"]) > 0.0, "Spawned ecology reaches combat data")
	main.current_zone_id = "gray_meadow"
	main.enemy_wave = [{"hp":1000,"max_hp":1000,"attack":100}, {"hp":1000,"max_hp":1000,"attack":100}]
	main.enemy_wave_sprites.clear()
	main.enemy_hp_bars.clear()
	main.enemy_wave[0]["vulnerable_seconds"] = 0.5
	_check(main._damage_enemy(0, 100) == 125 and main._damage_enemy(1, 100) == 100, "Vulnerability is local to each enemy")
	main._advance_skill_cooldowns(0.6)
	_check(main._damage_enemy(0, 100) == 100, "Local vulnerability expires")
	main.enemy_wave[0]["weaken_seconds"] = 0.5
	var tank: Dictionary = main.hero_battle_state["leonhardt"]
	var hp: int = tank["hp"]
	var reduced: int = main._incoming_damage_to_hero("leonhardt", 100, 0)
	tank["hp"] = hp
	var full: int = main._incoming_damage_to_hero("leonhardt", 100, 1)
	_check(reduced < full, "Only the weakened enemy deals reduced damage")
	_check(main._damage_enemy(0, 0) == 0 and main._damage_enemy(0, -10) == 0, "Nonpositive attacks produce no damage")
	_check(main._incoming_damage_to_hero("leonhardt", 0) == 0, "Nonpositive incoming attack cannot damage or charge ultimate")
	main.enemy_wave[0]["vulnerable_seconds"] = 1.0
	var remaining: int = main.enemy_wave[0]["hp"]
	_check(main._damage_enemy(0, 9223372036854775807) == remaining and main.enemy_wave[0]["hp"] == 0, "Extreme damage is bounded and returns actual damage")
	_check(Ecology.stage_pressure(1000000, 1) < 2.5, "High stages have bounded encounter pressure")
	# Exercise the live support turn with a nearer injured ally and a more injured
	# distant ally. Hero and pet turns are paused so only this monster can act.
	main._setup_hero_skills()
	for hero_id in main.hero_skill_runtime:
		main.hero_skill_runtime[hero_id]["windup"] = -1.0
		main.hero_skill_runtime[hero_id]["attack_remaining"] = 1000.0
	main.pet_runtime["remaining"] = 1000.0
	main.enemy_wave = [
		{"hp":1000,"max_hp":1000,"attack":20,"archetype":"support","attack_remaining":0.0,"healing_range":1.6},
		{"hp":400,"max_hp":1000,"attack":20,"archetype":"brute","attack_remaining":1000.0},
		{"hp":100,"max_hp":1000,"attack":20,"archetype":"brute","attack_remaining":1000.0}]
	# This isolated encounter uses a deliberately small local origin. Keep the
	# actual heroes there too, so a support attack tests range rather than a
	# stale fallback at the full map's center.
	main.expedition_position = Vector2(1.0, 2.0)
	main.party_movement.configure(main.deployed_heroes, main.hero_battle_state, main.expedition_position)
	main.roaming_hunt.configure(main.expedition_position, 27)
	main.roaming_hunt.spawn_group(main.enemy_wave)
	main.roaming_hunt.enemy_positions[0] = Vector2(2.3, 2.0)
	main.roaming_hunt.enemy_positions[1] = Vector2(2.4, 2.0)
	main.roaming_hunt.enemy_positions[2] = Vector2(5.5, 2.0)
	main.hunt_ai.state = AutoHuntController.State.FIGHTING
	main._advance_hunt_attacks(0.1)
	_check(main.enemy_wave[1]["hp"] > 400 and main.enemy_wave[2]["hp"] == 100, "Support heals an injured ally inside its range, not a distant one")
	for enemy in main.enemy_wave:
		enemy["hp"] = enemy["max_hp"]
	main.enemy_wave[0]["attack_remaining"] = 0.0
	main._sync_party_hp_from_heroes()
	var party_before: int = main.party_hp
	main._advance_hunt_attacks(0.1)
	_check(main.party_hp < party_before, "Support attacks when no nearby ally needs healing")
	# Stage-cap kills may grant ordinary loot, but never another stage chest.
	for enemy in main.enemy_wave:
		enemy["hp"] = 0
	main.idle_stage = 10000
	main.idle_stage_kills = main.idle_stage_target - 1
	main.hunt_ai.state = AutoHuntController.State.FIGHTING
	main.hunt_ai.encounter_id += 1
	main._rewarded_encounter = -1
	# The fake enemies must belong to a live corps before settlement.
	main.invasion.reset()
	var corps_id: int=main.invasion.register({})
	for enemy in main.enemy_wave: enemy["corps_id"]=corps_id;enemy["habitat_pack"]=0
	var chest_before: int = main.idle_chest_gold
	var reward_before: int = main.unclaimed_gold
	main._finish_hunt_target()
	_check(main.idle_stage == 10000 and main.idle_stage_kills < main.idle_stage_target and main.idle_chest_gold == chest_before and main.unclaimed_gold > reward_before, "Online stage-cap kills preserve ordinary rewards without repeated stage chests")
	if main.presentation_runtime != null: main.presentation_runtime.audio.shutdown()
	main.queue_free()
	await create_timer(0.35).timeout
	print("v27_field_lifecycle checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
