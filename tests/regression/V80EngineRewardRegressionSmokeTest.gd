extends SceneTree

## Settlement regression fixture: enemies are marked defeated here deliberately.
## This checks event payout ownership/replay guards, NOT real-AI combat difficulty.
var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 engine reward regression: " + label)

func _snapshot(main: Node) -> Array:
	return [main.unclaimed_gold, main.unclaimed_xp, main.wallet_gold, main.wallet_xp,
		JSON.stringify(main.loot_inventory), JSON.stringify(main.hero_progress)]

func _run() -> void:
	# The legacy scene owns field boss spawning; portrait intentionally keeps bosses in menus.
	var legacy = preload("res://scenes/Main.tscn").instantiate()
	legacy.save_state_path = "user://v80-engine-legacy-event-%d.json" % OS.get_process_id()
	root.add_child(legacy)
	await process_frame
	legacy.set_process(false)
	legacy.set_physics_process(false)
	legacy.combat_effects_enabled = false
	legacy.sound_effects_enabled = false
	legacy.selected_faction = "aurelia"
	legacy._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	legacy._offline_checked = true
	legacy._build_combat_screen()
	legacy.hunt_treasure_captured = true
	var legacy_before: Array = _snapshot(legacy)
	legacy._spawn_open_map_boss()
	_check(legacy.open_map_boss_active, "legacy boss appearance executes")
	_check(legacy_before == _snapshot(legacy), "legacy boss appearance does not grant pending treasure")
	legacy._spawn_open_map_boss()
	_check(legacy_before == _snapshot(legacy), "legacy repeated appearance cannot grant event rewards")
	legacy.free()
	await process_frame
	var main = preload("res://scenes/PortraitMain.tscn").instantiate()
	main.save_state_path = "user://v80-engine-event-%d.json" % OS.get_process_id()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.combat_effects_enabled = false
	main.sound_effects_enabled = false
	main.selected_faction = "aurelia"
	main.party_slot_legacy_cap = 10
	main.idle_stage = 2
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._offline_checked = true
	main._build_combat_screen()
	main.hunt_treasure_captured = true
	main.hunt_treasure_expired = false
	main.hunt_variety_profile = {"type": "treasure", "reward_mult": 1.0}
	main.invasion.groups[main.invasion.serial] = main.hunt_variety_profile.duplicate(true)
	main.enemy_wave[0]["treasure_captured"] = true
	var before: Array = _snapshot(main)
	main._spawn_open_map_boss()
	_check(not main.open_map_boss_active, "portrait keeps bosses in the content menu")
	_check(before == _snapshot(main), "boss appearance gives no field event reward")
	main._spawn_open_map_boss()
	_check(before == _snapshot(main), "repeated boss appearance remains reward-neutral")
	# Synthetic defeated-wave state is confined to this settlement unit fixture.
	for enemy in main.enemy_wave:
		enemy["hp"] = 0
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main.hunt_combo = 0
	main.hunt_combo_remaining = 0.0
	main.combat_kills = 0
	main.idle_stage_kills = 0
	main._rewarded_encounter = -1
	var packs: Dictionary = {}
	for enemy in main.enemy_wave:
		packs[int(enemy.get("habitat_pack", 0))] = true
	var units: int = clampi(packs.size(), 1, 3)
	var zone: Dictionary = main._current_zone()
	var difficulty: int = int(zone["difficulty"])
	var expected_gold: int = main._guardian_reward(int(zone["gold"]) * (2 + difficulty), "online_gold")
	var expected_xp: int = main._guardian_reward(int(zone["xp"]) * 2, "online_xp")
	for count in range(1, units + 1):
		expected_gold += main._guardian_reward(int(zone["gold"]) + (count % 3) * difficulty * 7, "online_gold")
		expected_xp += main._guardian_reward(int(zone["xp"]) + (count % 4) * difficulty * 5, "online_xp")
	var gold_before: int = int(main.unclaimed_gold) + int(main.wallet_gold)
	var xp_before: int = int(main.unclaimed_xp) + int(main.wallet_xp)
	main._finish_hunt_target()
	_check(int(main.unclaimed_gold) + int(main.wallet_gold) == gold_before + expected_gold, "treasure gold paid at encounter settlement exactly once")
	_check(int(main.unclaimed_xp) + int(main.wallet_xp) == xp_before + expected_xp, "treasure experience paid at encounter settlement exactly once")
	_check("보물 포획 보상" in str(main.last_drop_text), "guaranteed treasure drop uses settlement path")
	var settled: Array = _snapshot(main)
	main._finish_hunt_target()
	_check(settled == _snapshot(main), "replayed settlement cannot grant event reward again")
	main._build_hero_detail_screen("leonhardt")
	await process_frame
	_check(main.find_child("HeroDeploymentState", true, false) != null, "hero detail compiles and opens")
	main._build_growth_screen()
	await process_frame
	_check(main.find_child("FocusedHeroSummary", true, false) != null, "growth hero selection compiles and opens")
	main.free()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
	await process_frame
	print("v80_engine_reward_regression checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
