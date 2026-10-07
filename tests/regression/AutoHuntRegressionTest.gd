extends SceneTree

var failures := 0
var checks := 0

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func simulate(main: Node, seconds: float, delta := 0.12) -> void:
	for _step in int(ceil(seconds / delta)):
		main._advance_auto_hunt(delta)

func _run() -> void:
	# Navigation fallback remains available for non-roaming systems.
	var nav := AutoHuntController.new()
	nav.configure([Vector2(6, 4), Vector2(4, 2), Vector2.ZERO], Vector2(3, 2))
	check(nav.acquire_target() and nav.target_index == 1, "Nearest reachable target was not selected")
	var selected: int = nav.target_index
	var smooth := true
	for _step in 60:
		var before: Vector2 = nav.position
		if nav.state == AutoHuntController.State.MOVING:
			nav.advance_movement(1.0 / 60.0)
		var walked: float = ((nav.position - before) * nav.CELL_SIZE).length()
		smooth = smooth and walked <= nav.MOVE_SPEED / 60.0 + 0.001 and nav.target_index == selected
	check(smooth and nav.position == Vector2(4, 2), "Navigation jumped, changed target, or failed to arrive")

	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.combat_effects_enabled = false
	main._offline_checked = true
	# Keep this combat fixture at its original difficulty with valid legacy capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, 3)
	main.hero_progress = {}
	main.hero_equipment = {}
	main.hero_equipment_rarity = {}
	main.hero_equipment_names = {}
	main.loot_inventory = []
	main.idle_stage = 1
	main.idle_stage_kills = 0
	main.current_zone_id = "gray_meadow"
	main.loot_rng.seed = 42
	main._build_combat_screen()
	await process_frame

	# Real-time roaming must move both the field state and sprites without legacy fixed targets.
	var start_position: Vector2 = main.roaming_hunt.party_position
	simulate(main, 2.0)
	check(main.roaming_hunt.distance_walked > 0.25 and main.roaming_hunt.party_position != start_position, "Roaming party did not move")
	check(main.enemy_wave.size() == main.roaming_hunt.enemy_positions.size(), "Enemy combat data and roaming positions diverged")
	check(main.hunt_ai.target_index < 0, "Roaming hunt fell back to legacy fixed spawn targeting")
	check(main.party_hp >= 0 and main.party_hp <= main.party_max_hp, "Party HP left valid bounds")

	# Pause must freeze movement, combat clocks and rewards.
	var before_position: Vector2 = main.expedition_position
	var before_gold: int = main.unclaimed_gold
	var before_clock: float = main.hunt_ai.clock
	var toggle: Button = main.combat_labels["toggle"]
	main._toggle_combat(toggle)
	simulate(main, 2.0)
	check(main.expedition_position == before_position and main.hunt_ai.clock == before_clock, "Paused hunt continued movement/timers")
	check(main.unclaimed_gold == before_gold, "Paused hunt granted rewards")
	main._toggle_combat(toggle)
	simulate(main, 1.0)
	check(main.hunt_ai.clock > before_clock, "Resumed hunt did not advance")

	# Zero-HP party must enter bounded recovery and never farm rewards while recovering.
	for hero_id in main.hero_battle_state.keys():
		main.hero_battle_state[hero_id]["hp"] = 0
		main.hero_battle_state[hero_id]["alive"] = false
	main._sync_party_hp_from_heroes()
	before_gold = main.unclaimed_gold
	var xp_before_recovery: int = main.unclaimed_xp
	var kills_before_recovery: int = main.combat_kills
	main._advance_auto_hunt(0.12)
	check(main.hunt_ai.state == AutoHuntController.State.RECOVERING, "Zero-HP party did not enter recovery")
	# Inspect only updates that begin in recovery, including the update that exits.
	# A fixed eight-second simulation can legitimately resume combat and earn loot.
	var recovery_elapsed := 0.0
	var recovery_rewards_unchanged := true
	var recovery_heroes_safe := true
	var recovery_enemies_idle := true
	while main.hunt_ai.state == AutoHuntController.State.RECOVERING and recovery_elapsed < 8.0:
		var hero_hp_before: Dictionary = {}
		for hero_id in main.hero_battle_state.keys():
			hero_hp_before[hero_id] = int(main.hero_battle_state[hero_id]["hp"])
		var enemy_state_before: Array = []
		for enemy in main.enemy_wave:
			enemy_state_before.append([int(enemy["hp"]), float(enemy.get("attack_remaining", 0.9))])
		var recovery_step := minf(0.12, 8.0 - recovery_elapsed)
		main._advance_auto_hunt(recovery_step)
		recovery_elapsed += recovery_step
		recovery_rewards_unchanged = recovery_rewards_unchanged \
			and main.unclaimed_gold == before_gold \
			and main.unclaimed_xp == xp_before_recovery \
			and main.combat_kills == kills_before_recovery
		for hero_id in hero_hp_before.keys():
			recovery_heroes_safe = recovery_heroes_safe and int(main.hero_battle_state[hero_id]["hp"]) >= int(hero_hp_before[hero_id])
		recovery_enemies_idle = recovery_enemies_idle and main.enemy_wave.size() == enemy_state_before.size()
		for enemy_index in mini(main.enemy_wave.size(), enemy_state_before.size()):
			var enemy: Dictionary = main.enemy_wave[enemy_index]
			recovery_enemies_idle = recovery_enemies_idle \
				and int(enemy["hp"]) == int(enemy_state_before[enemy_index][0]) \
				and float(enemy.get("attack_remaining", 0.9)) == float(enemy_state_before[enemy_index][1])
	check(recovery_rewards_unchanged, "Recovering party received gold, XP, or kill credit")
	check(recovery_heroes_safe and recovery_enemies_idle, "Damage or enemy attacks occurred during recovery")
	check(main.party_hp > 0 and main.hunt_ai.state != AutoHuntController.State.RECOVERING and recovery_elapsed <= 8.0, "Party did not leave recovery within eight seconds")

	# Force one deterministic melee engagement and lethal hero windup.
	main.roaming_hunt.party_position = Vector2(3.0, 2.0)
	main.expedition_position = main.roaming_hunt.party_position
	# Place the actual actors, not only the old shared party anchor.
	main.party_movement.configure(main.deployed_heroes, main.hero_battle_state, main.expedition_position)
	main.party_movement.positions["leonhardt"] = main.expedition_position
	if not main.roaming_hunt.enemy_positions.is_empty():
		main.roaming_hunt.enemy_positions[0] = Vector2(3.55, 2.0)
		main.roaming_hunt.enemy_home_positions[0] = main.roaming_hunt.enemy_positions[0]
		main.roaming_hunt.enemy_returning[0] = false
	main.roaming_hunt.current_target = 0
	main.roaming_hunt.aggro_active = true
	main.roaming_hunt.mode = RoamingHuntDirector.Mode.ENGAGED
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	for index in main.hero_map_sprites.size():
		main.hero_map_sprites[index].position = main._hero_roaming_destination(index)
	for index in main.enemy_wave.size():
		main.enemy_wave[index]["hp"] = 0
	main.enemy_wave[0]["hp"] = 1
	main._sync_enemy_wave_summary()
	main.enemy_wave[0]["attack_remaining"] = 0.0
	main.hero_skill_runtime["leonhardt"]["windup"] = 0.001
	main.hero_skill_runtime["leonhardt"]["cast"] = false
	main.hero_skill_runtime["leonhardt"]["cast_ultimate"] = false
	main.hero_skill_runtime["leonhardt"]["target_index"] = 0
	var hp_before_kill: int = main.party_hp
	var max_hp_before_kill: int = main.party_max_hp
	var heroes_before_kill: Dictionary = main.hero_battle_state.duplicate(true)
	var kills_before_lethal: int = main.combat_kills
	var expected_packs: int = main.roaming_hunt.pack_centers.size()
	main._advance_auto_hunt(0.01)
	var kills_after: int = main.combat_kills
	var gold_after: int = main.unclaimed_gold
	# Kill rewards can immediately equip stronger loot or grant a level. Those
	# changes increase max/current HP while preserving each hero's HP ratio.
	# A fixed party HP equality incorrectly treats this legitimate growth as
	# retaliation. Verify attack counters, each hero, and the enemy clock instead.
	var no_retaliation := float(main.enemy_wave[0]["attack_remaining"]) == 0.0
	for hero_id in heroes_before_kill:
		var old: Dictionary = heroes_before_kill[hero_id]
		var after: Dictionary = main.hero_battle_state.get(hero_id, {})
		var old_ratio := float(old["hp"]) / maxf(1.0, float(old["max_hp"]))
		var new_max := maxf(1.0, float(after.get("max_hp", 1)))
		var new_ratio := float(after.get("hp", 0)) / new_max
		no_retaliation = no_retaliation \
			and int(after.get("hp", 0)) >= int(old["hp"]) \
			and new_ratio + 1.0 / new_max + 0.000001 >= old_ratio \
			and int(after.get("incoming_hits", 0)) == int(old.get("incoming_hits", 0))
	print("auto_hunt_lethal hp=%d->%d max_hp=%d->%d no_retaliation=%s enemy_hp=%d kill_delta=%d reward=%s" % [hp_before_kill, main.party_hp, max_hp_before_kill, main.party_max_hp, no_retaliation, main.enemy_hp, kills_after - kills_before_lethal, main.last_drop_text])
	check(no_retaliation and main.enemy_hp == 0 and expected_packs > 0 and kills_after == kills_before_lethal + expected_packs, "Lethal hit allowed retaliation or did not credit each defeated pack once")
	main._finish_hunt_target()
	simulate(main, 0.3)
	check(main.combat_kills == kills_after and main.unclaimed_gold == gold_after, "Kill reward duplicated")

	# Healer and tank skills must react to state rather than fire blindly.
	main._setup_hero_skills()
	main.hero_skill_runtime["elisia"]["remaining"] = 0.0
	main._cast_combat_skill("elisia", 0)
	check(main.hero_skill_runtime["elisia"]["remaining"] == 0.0, "Healer wasted cooldown at full HP")
	var injured: Dictionary = main.hero_battle_state["mira"]
	injured["hp"] = int(injured["max_hp"] * 0.5)
	main._sync_party_hp_from_heroes()
	var injured_before: int = int(injured["hp"])
	main._cast_combat_skill("elisia", 0)
	check(int(main.hero_battle_state["mira"]["hp"]) > injured_before, "Healer failed to heal injured ally")

	var leon_state: Dictionary = main.hero_battle_state["leonhardt"]
	leon_state["hp"] = leon_state["max_hp"]
	leon_state["alive"] = true
	# Skill AI intentionally holds guard in a safe situation. Test the guard timer
	# damage modifier directly; tactical trigger behavior has its own smoke tests.
	leon_state["guard"] = 2.0
	var guarded: int = main._incoming_damage_to_hero("leonhardt", 100)
	main._advance_skill_cooldowns(3.0)
	leon_state["hp"] = leon_state["max_hp"]
	leon_state["alive"] = true
	var unguarded: int = main._incoming_damage_to_hero("leonhardt", 100)
	check(guarded < unguarded, "Tank guard did not expire cleanly")

	main.free()
	await process_frame
	print("auto_hunt_regression checks=%d failures=%d realtime_roaming=ok" % [checks, failures])
	quit(1 if failures > 0 else 0)
