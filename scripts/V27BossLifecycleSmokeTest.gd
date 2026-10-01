extends SceneTree

var failures: Array[String] = []
var assertions := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		push_error(message)

func quiet_party(main) -> void:
	main.pet_runtime = {"kind": "none"}
	main._stun_seconds = 0.0
	main._guard_seconds = 0.0
	main._weaken_seconds = 0.0
	main._vulnerable_seconds = 0.0
	for hero_id in main.hero_battle_state:
		var state: Dictionary = main.hero_battle_state[hero_id]
		state["hp"] = 100000
		state["max_hp"] = 100000
		state["role_group"] = "탱커"
		state["guard"] = 0.0
		state["taunt"] = 0.0
		state["ultimate"] = 0.0
		state["ult_gain_mult"] = 0.0
		main.hero_skill_runtime[hero_id]["remaining"] = 9999.0
		main.hero_skill_runtime[hero_id]["attack_remaining"] = 9999.0

	main._sync_party_hp_from_heroes()

func fresh(main, zone := "gray_meadow") -> void:
	main.raid_running = false
	main.current_zone_id = zone
	main._start_raid()
	if is_instance_valid(main.combat_timer):
		main.combat_timer.stop()

func _init() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.combat_effects_enabled = false
	main.selected_faction = "aurelia"
	main.hero_progress = {}
	main.hero_equipment = {}
	main.hero_equipment_rarity = {}
	main.hero_equipment_names = {}
	main.raid_clears = {}
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, 10)
	main.current_zone_id = "gray_meadow"
	main._build_raid_screen()
	main._start_raid()
	main.combat_timer.stop()
	check(main.raid_outcome == "running" and main.raid_phase == 1, "Raid starts with a fresh phase and outcome")
	var serial: int = main.raid_encounter_serial
	main._start_raid()
	check(main.raid_encounter_serial == serial, "Duplicate entry is rejected while active")
	check(main.combat_labels["raid_start"].disabled, "Start button is disabled during raid")
	check(main.combat_labels["raid_rewards"].text.contains("미획득 가능"), "Reward description discloses two rolls rather than guaranteed equipment")
	await process_frame
	await process_frame
	var grid = main.content_root.get_node("RaidPartyGrid")
	for panel_name in ["RaidBossPanel", "RaidStatusPanel"]:
		var panel = main.content_root.get_node(panel_name)
		check(panel.position.y + panel.size.y <= grid.position.y, "Raid panel must stay above individual hero HP cards: %s bottom=%s" % [panel_name, panel.position.y + panel.size.y])
	check(grid.position.x + grid.size.x <= 1280 and grid.position.y + grid.size.y <= 720, "Raid hero HP grid fits viewport")

	# Telegraph must not deal early damage, then resolve once at the visible deadline.
	quiet_party(main)
	main.raid_boss_turns = 5
	main.raid_boss_attack_remaining = 0.01
	main._advance_raid_encounter(0.05)
	check(main.boss_telegraph_pending, "Meadow sixth action telegraphs its pattern")
	var hp_before: int = main.party_hp
	main._advance_raid_encounter(0.05)
	check(main.party_hp == hp_before and main.raid_pattern_count == 0, "Telegraph warning has no early damage")
	for i in 23:
		main._advance_raid_encounter(0.05)
	check(not main.boss_telegraph_pending and main.raid_pattern_count == 1 and main.party_hp < hp_before, "Telegraph resolves once after 1.2 seconds")

	# A controller cancels a cast, immunity prevents permanent chain interruption.
	main.boss_telegraph_pending = true
	main.boss_telegraph_remaining = 0.7
	check(main._raid_apply_control(0.8), "Control is accepted outside immunity")
	check(not main.boss_telegraph_pending and main.raid_interrupt_count == 1, "Control cancels pending pattern")
	main.boss_telegraph_pending = true
	main.boss_telegraph_remaining = 0.7
	check(not main._raid_apply_control(1.0) and main.boss_telegraph_pending, "Control immunity does not silently cancel another cast")
	main.boss_telegraph_pending = false
	main._stun_seconds = 0.0

	# Automatic controller casting reserves the cooldown until a useful counter window.
	main.selected_faction = "noxfera"
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, 10)
	fresh(main)
	quiet_party(main)
	var controller_id := ""
	for hero_id in main.hero_skill_runtime:
		if main.hero_skill_runtime[hero_id]["profile"].get("kind", "") == "stun":
			controller_id = hero_id
			break
	check(not controller_id.is_empty(), "Noxfera roster includes a control skill")
	if not controller_id.is_empty():
		var runtime: Dictionary = main.hero_skill_runtime[controller_id]
		runtime["remaining"] = 0.0
		runtime["attack_remaining"] = 0.0
		main._advance_raid_encounter(0.05)
		check(runtime["remaining"] == 0.0, "Automatic AI reserves control outside telegraph")
		main.boss_telegraph_pending = true
		main.boss_telegraph_remaining = 0.8
		runtime["attack_remaining"] = 0.0
		main._advance_raid_encounter(0.05)
		check(runtime["remaining"] > 0.0, "Automatic AI spends saved control during telegraph")
	main.boss_telegraph_pending = false
	main._stun_seconds = 0.0

	main.selected_faction = "aurelia"
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, 10)
	fresh(main)
	quiet_party(main)

	# HP phases cannot regress after boss healing; elapsed time independently enrages.
	main.raid_boss_hp = int(main.raid_boss_max_hp * 0.59)
	main._advance_raid_encounter(0.05)
	check(main.raid_phase == 2, "Phase two starts at 60 percent HP")
	main.raid_boss_hp = int(main.raid_boss_max_hp * 0.29)
	main._advance_raid_encounter(0.05)
	check(main.raid_phase == 3, "Phase three starts at 30 percent HP")
	main.raid_boss_hp = main.raid_boss_max_hp
	main._advance_raid_encounter(0.05)
	check(main.raid_phase == 3, "Boss healing cannot roll back phase")
	main.raid_elapsed = 179.95
	main._advance_raid_encounter(0.05)
	check(main.raid_enraged, "180 second enrage is independent of HP phase")

	# Regional pattern shapes: front damage differs, drain is limited by actual damage.
	fresh(main, "forgotten_mine")
	quiet_party(main)
	var ids: Array = main._alive_hero_ids()
	main.hero_battle_state[ids[0]]["row"] = "front"
	main.hero_battle_state[ids[1]]["row"] = "back"
	main._apply_boss_pattern(main._boss_pattern_profile("forgotten_mine"))
	check(main.hero_battle_state[ids[0]]["hp"] < main.hero_battle_state[ids[1]]["hp"], "Mine front blast hits front harder than rear")
	fresh(main, "moonrest_forest")
	quiet_party(main)
	main.raid_boss_hp = int(main.raid_boss_max_hp / 2)
	var boss_before: int = main.raid_boss_hp
	main._apply_boss_pattern(main._boss_pattern_profile("moonrest_forest"))
	var unguarded_heal: int = main.raid_boss_hp - boss_before
	quiet_party(main)
	main.raid_boss_hp = boss_before
	main._guard_seconds = 2.0
	main._weaken_seconds = 2.0
	for state in main.hero_battle_state.values():
		state["guard"] = 2.0
	main._apply_boss_pattern(main._boss_pattern_profile("moonrest_forest"))
	check(main.raid_boss_hp - boss_before < unguarded_heal, "Guard and weaken reduce forest boss drain")

	# Already dead heroes neither act nor heal and a pet cannot win after a wipe.
	fresh(main)
	for state in main.hero_battle_state.values():
		state["hp"] = 0
	main.raid_boss_hp = 1
	main.pet_runtime["remaining"] = 0.0
	var gold_before: int = main.unclaimed_gold
	var clears_before: int = int(main.raid_clears.get("gray_meadow", 0))
	main._on_raid_tick()
	check(main.raid_outcome == "defeat" and main.raid_boss_hp == 1, "Wipe is resolved before pet damage")
	check(main.unclaimed_gold == gold_before and int(main.raid_clears.get("gray_meadow", 0)) == clears_before, "Defeat grants no clear or currency")
	check(main._select_raid_hero_target().is_empty(), "Dead heroes are excluded from targeting")
	check(main._advance_raid_pet(10.0) == 0, "Pet adapter rejects a dead expedition")

	# A kill pays once, captures both rolls and avoids spending subsequent ultimates.
	fresh(main)
	quiet_party(main)
	ids = main._alive_hero_ids()
	main.hero_skill_runtime[ids[0]]["attack_remaining"] = 0.0
	main.hero_battle_state[ids[1]]["ultimate"] = 100.0
	main.hero_skill_runtime[ids[1]]["attack_remaining"] = 0.0
	main.raid_boss_hp = 1
	main._on_raid_tick()
	check(main.raid_outcome == "victory" and main.raid_damage_dealt == 1, "Killing damage is capped to actual HP")
	check(main.hero_battle_state[ids[1]]["ultimate"] == 100.0, "Later heroes do not spend ultimate on dead boss")
	check(main.raid_reward_receipt.get("drop_results", []).size() == 2, "Both equipment roll outcomes are retained")
	check(main.unclaimed_gold == gold_before + 500, "Correct zone reward applied once")
	main._on_raid_tick()
	main._finish_raid("victory")
	check(main.unclaimed_gold == gold_before + 500 and int(main.raid_clears.get("gray_meadow", 0)) == clears_before + 1, "Repeated callbacks cannot settle reward twice")
	check(main.combat_labels["raid_record"].text.contains("1회"), "Boss clear count updates immediately")

	# Restart clears statuses, results and damage; callbacks from former encounter are ignored.
	serial = main.raid_encounter_serial
	fresh(main)
	check(main.raid_elapsed == 0.0 and main.raid_phase == 1 and main.raid_damage_dealt == 0 and main.raid_reward_receipt.is_empty(), "Retry clears time phase damage and receipt")
	check(main.raid_last_result.is_empty() and not main.raid_reward_settled and not main.boss_telegraph_pending and main.raid_control_immunity == 0.0, "Retry clears outcome telegraph and control immunity")
	main._on_raid_tick(serial)
	check(main.raid_elapsed == 0.0, "Stale timer callback is ignored after retry")
	main._application_suspended = true
	main._on_raid_tick()
	check(main.raid_elapsed == 0.0, "Application suspension freezes raid clock")
	main._application_suspended = false
	main.raid_elapsed = 239.95
	gold_before = main.unclaimed_gold
	main._on_raid_tick()
	check(main.raid_outcome == "timeout" and main.raid_elapsed == 240.0 and main.unclaimed_gold == gold_before, "Hard timeout stops with no clear reward")

	fresh(main)
	main.current_zone_id = "moonrest_forest"
	main._on_raid_tick()
	check(main.raid_outcome == "running" and main.raid_encounter_zone == "gray_meadow" and main.unclaimed_gold == gold_before, "Changing hunting zone cannot redirect a live raid or its reward")
	main._finish_raid("cancelled")

	# Both supported UI speeds must produce identical damage/cooldown.
	var snapshots: Array = []
	for speed in [1.0, 2.0]:
		fresh(main)
		quiet_party(main)
		main.raid_boss_max_hp = 1000000
		main.raid_boss_hp = 1000000
		main.battle_speed = speed
		for runtime in main.hero_skill_runtime.values():
			runtime["attack_remaining"] = 0.0
		for tick in int(48 / speed):
			main._on_raid_tick()
		snapshots.append([main.raid_damage_dealt, main.raid_boss_turns, main.raid_pattern_count, snappedf(main.raid_elapsed, 0.001), main.party_hp])
	check(snapshots[0] == snapshots[1], "x1 and x2 must agree after twelve simulated seconds: %s" % str(snapshots))

	# Both factions and all regional bosses must terminate under normal game actions.
	var encounter_results: Array = []
	for faction in ["aurelia", "noxfera"]:
		main.selected_faction = faction
		main.deployed_heroes = main._hero_roster_for_faction().slice(0, 10)
		main.hero_progress = {}
		main.hero_equipment = {}
		main.hero_skill_tree = {}
		main.battle_speed = 2.0
		for zone in ["gray_meadow", "forgotten_mine", "moonrest_forest"]:
			fresh(main, zone)
			for tick in 241:
				main._on_raid_tick()
				if not main.raid_running:
					break
			check(not main.raid_running and main.raid_outcome in ["victory", "defeat", "timeout"], "Normal raid must reach terminal state %s/%s" % [faction, zone])
			check(main.raid_boss_hp >= 0 and main.party_hp >= 0 and main.raid_elapsed <= 240.0, "Bounded HP/time for %s/%s" % [faction, zone])
			encounter_results.append({"faction": faction, "zone": zone, "outcome": main.raid_outcome, "seconds": snappedf(main.raid_elapsed, 0.1), "phase": main.raid_phase, "patterns": main.raid_pattern_count})
	print("v27_boss_lifecycle assertions=%d failures=%d speed=%s encounters=%s" % [assertions, failures.size(), str(snapshots), JSON.stringify(encounter_results)])
	main.free()
	quit(0 if failures.is_empty() else 1)
