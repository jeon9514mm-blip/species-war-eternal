extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V27 growth: " + label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main.hero_progress.clear()
	main.hero_equipment.clear()
	main.hero_equipment_rarity.clear()
	main.hero_equipment_names.clear()
	main.hero_equipment_sets.clear()
	main.hero_skill_tree.clear()
	main.pet_progress.clear()
	main.hero_ascension.clear()
	main.hero_breakthrough.clear()
	main.loot_inventory.clear()
	main.idle_stage = 1
	var roster: Array = main._hero_roster_for_faction()
	main._setup_hero_progress(roster)
	main.deployed_heroes = roster.slice(0, 3)
	main.wallet_gold = 10000
	var hero_id := str(roster[0]["id"])

	var gold_before: int = main.wallet_gold
	main._enhance_equipment({"id": "ghost", "name": "invalid"}, "weapon")
	main._enhance_equipment(roster[0], "head")
	main._upgrade_skill_tree("ghost", "offense")
	check(not main._try_ascend_hero("ghost") and not main._try_breakthrough("ghost"), "unknown hero progression rejected")
	check(main.wallet_gold == gold_before and not main.hero_equipment.has("ghost") and not main.hero_skill_tree.has("ghost"), "invalid hero/slot do not mutate resources")
	main.hero_equipment[hero_id]["weapon"] = -10
	main._enhance_equipment(roster[0], "weapon")
	check(main.wallet_gold == gold_before - 175 and main.hero_equipment[hero_id]["weapon"] == 2, "negative loaded level cannot generate gold")
	main.hero_equipment[hero_id]["weapon"] = 10
	gold_before = main.wallet_gold
	main._enhance_equipment(roster[0], "weapon")
	check(main.wallet_gold == gold_before, "equipped +10 cannot consume gold")
	main.wallet_gold = 174
	main.hero_equipment[hero_id]["weapon"] = 1
	main._enhance_equipment(roster[0], "weapon")
	check(main.wallet_gold == 174 and main.hero_equipment[hero_id]["weapon"] == 1, "insufficient gold has no partial mutation")

	var source := {"slot": "weapon", "level": -7, "rarity": "invalid", "set": "invalid"}
	var normalized: Dictionary = main._normalize_inventory_item(source)
	check(source["level"] == -7 and not source.has("power"), "inventory normalization does not modify source")
	check(normalized["level"] == 1 and normalized["rarity"] == "일반" and normalized["power"] == 22, "inventory power and metadata normalized")
	main.loot_inventory = [{"id": "invalid_slot", "slot": "head", "level": 1}]
	check(not main._equip_item_direct(0, hero_id), "unknown item slot cannot equip")
	main.loot_inventory = [{"id": "rare", "slot": "weapon", "level": 2, "rarity": "희귀", "name": "시험검", "set": "월광"}]
	check(not main._equip_item_direct(0, "ghost"), "direct equip rejects unknown hero")
	check(main._equip_item_direct(0, hero_id), "manual swap succeeds")
	check(main.loot_inventory.size() == 1 and main.loot_inventory[0]["level"] == 1 and main.hero_equipment_sets[hero_id]["weapon"] == "월광", "swapped equipment and set preserved")
	gold_before = main.wallet_gold
	main._decompose_inventory_item(0, "rare")
	main._enhance_inventory_item(0, "rare")
	check(main.loot_inventory.size() == 1 and main.wallet_gold == gold_before, "stale item callbacks cannot consume replacement")
	var returned_id := str(main.loot_inventory[0]["id"])
	main._decompose_inventory_item(0, returned_id)
	main._decompose_inventory_item(0, returned_id)
	check(main.loot_inventory.is_empty() and main.wallet_gold == gold_before + 80, "decomposition claims exactly once")

	main.hero_equipment[hero_id] = {"weapon": 10, "armor": 10, "accessory": 10}
	main.hero_equipment_sets[hero_id] = {"weapon": "강철", "armor": "강철", "accessory": "강철"}
	var weak_rare := {"id": "weak_rare", "slot": "weapon", "level": 1, "rarity": "전설", "set": "월광"}
	check(main._automatic_equipment_gain(weak_rare, hero_id) == 0, "automatic drops cannot downgrade enhanced equipment")
	main.hero_equipment[hero_id] = {"weapon": 1, "armor": 1, "accessory": 1}
	weak_rare["level"] = 10
	check(main._automatic_equipment_gain(weak_rare, hero_id) == 0, "automatic equipment protects defensive set bonuses")
	main.hero_equipment_sets[hero_id] = {"weapon": "초보자", "armor": "초보자", "accessory": "초보자"}
	main.loot_inventory = [weak_rare]
	var power_before: int = main._calculate_party_power()
	main._recommend_equip_all()
	check(main._calculate_party_power() > power_before and main.loot_inventory.size() == 1, "recommendation raises party power without item loss")
	power_before = main._calculate_party_power()
	main._recommend_equip_all()
	check(main._calculate_party_power() == power_before, "recommendation reaches a stable result")
	main.loot_inventory.clear()
	main.auto_salvage_min_rarity = "일반"
	for index in main.INVENTORY_CAP:
		main.loot_inventory.append({"id": "full_%d" % index, "slot": "armor", "level": 10, "rarity": "일반"})
	gold_before = main.wallet_gold
	main._store_or_salvage_loot({"id": "new_weak", "slot": "armor", "level": 1, "rarity": "희귀"})
	check(main.loot_inventory.size() == main.INVENTORY_CAP and main.loot_inventory[0]["level"] == 10 and main.wallet_gold == gold_before + 115, "full bag preserves stronger enhanced gear and salvages weaker arrival")

	main.hero_progress.clear()
	main._setup_hero_progress(roster)
	main._grant_hero_xp(1)
	main._grant_hero_xp(1)
	main._grant_hero_xp(1)
	for hero in main.deployed_heroes:
		check(main.hero_progress[str(hero["id"])]["xp"] == 1, "tiny shared XP reaches each hero without inflation")
	main._grant_hero_xp(7)
	var total_xp := 0
	for hero in main.deployed_heroes:
		total_xp += int(main.hero_progress[str(hero["id"])]["xp"])
	check(total_xp == 10, "shared XP remainder conserved")
	main.deployed_heroes = [roster[0], roster[0]]
	main.hero_progress[hero_id] = {"level": 1, "xp": 0}
	main._grant_hero_xp(12)
	check(main.hero_progress[hero_id]["xp"] == 12, "duplicate party entry cannot mint XP")
	main.deployed_heroes = [roster[0]]
	main.hero_progress[hero_id] = {"level": 99, "xp": main._hero_xp_to_next(99) - 1}
	main._grant_hero_xp(9223372036854775807)
	check(main.hero_progress[hero_id]["level"] == 100 and main.hero_progress[hero_id]["xp"] == 0, "extreme XP terminates at level cap")
	main._grant_hero_xp(1)
	check(main.hero_progress[hero_id]["xp"] == 0 and main._hero_xp_to_next(-99) == 100, "max-level and negative-level boundary stable")
	main.hero_skill_tree[hero_id] = {"offense": 10, "survival": 10, "utility": 10}
	check(main._skill_tree_total_points(hero_id) == 30 and main._skill_tree_available_points(hero_id) == 0, "max-level tree has no unusable leftover points")
	main.hero_progress[hero_id] = {"level": 4, "xp": 0}
	main.hero_skill_tree[hero_id] = {"offense": 10, "survival": 10, "utility": 10}
	check(main._skill_tree_spent(hero_id) == 1 and main._skill_tree_available_points(hero_id) == 0, "skill allocations cannot exceed earned budget")
	main.pet_progress["aurelia"] = {"level": 4, "xp": main._pet_xp_to_next(4) - 1, "evolution": 0}
	main._setup_pet_runtime()
	main.pet_runtime["remaining"] = 0.7
	main._grant_pet_xp(1)
	check(main.pet_runtime["level"] == 5 and main.pet_runtime["evolution"] == 1 and main.pet_runtime["remaining"] == 0.7, "pet evolution immediately applied without resetting cooldown")
	main._grant_pet_xp(9223372036854775807)
	check(main._get_pet_progress()["level"] == 100 and main._get_pet_progress()["xp"] == 0, "pet extreme XP terminates at cap")

	var estimator := IdleHuntEstimator.new()
	var zone := {"power": 180, "difficulty": 1, "gold": 35, "xp": 22}
	var capped: Dictionary = estimator.estimate(28800, 500, 3, zone, 1, 0, 10)
	check(capped == estimator.estimate(9223372036854775807, 500, 3, zone, 1, 0, 10), "estimator enforces its own 8-hour cap")
	check(estimator.estimate(-1, 500, 3, zone, 1, 0, 10)["kills"] == 0 and estimator.estimate(60, 500, 0, zone, 1, 0, 10)["kills"] == 0, "negative time and empty party give no rewards")
	check(estimator.estimate(60, 500, 3, zone, 1, 0, 0)["kills"] == 0, "zero stage target rejected")
	var nonfinite: Dictionary = estimator.estimate(60, 500, 3, {"power": NAN, "difficulty": INF, "gold": INF, "xp": {}}, 1, 0, 10)
	check(nonfinite["gold"] == 0 and nonfinite["xp"] == 0 and nonfinite["kills"] > 0, "nonfinite zone metadata cannot mint resources or crash")
	var edge: Dictionary = estimator.estimate(28800, 500, 3, zone, 9999, 9, 10)
	check(edge["stage_clears"] == 1 and int(edge["stage_kills"]) < 10 and edge["chest_gold"] == 6493, "offline final stage and chest stay consistent")
	check(capped["stage_clears"] == 5 and capped["chest_gold"] == 2000 and capped["chest_xp"] == 875, "offline five stage chest totals exact")

	main.idle_stage = 1
	main.idle_stage_kills = 0
	main.loot_inventory.clear()
	main.unclaimed_gold = 0
	main.unclaimed_xp = 0
	main.idle_chest_gold = 0
	main.idle_chest_xp = 0
	main._offline_checked = false
	main.last_idle_timestamp = 0
	main._calculate_offline_reward()
	check(main.unclaimed_gold == 0, "missing initial timestamp does not mint eight hours")
	var future := int(Time.get_unix_time_from_system()) + 3600
	main.last_idle_timestamp = future
	main._offline_checked = false
	main._calculate_offline_reward()
	check(main.last_idle_timestamp == future and main.unclaimed_gold == 0, "clock rollback cannot lower reward checkpoint")
	main.last_idle_timestamp = int(Time.get_unix_time_from_system()) - 120
	main._offline_checked = false
	main._calculate_offline_reward()
	check(main.unclaimed_gold > 0 and main.offline_reward_seconds >= 120, "offline loop grants real pending rewards")
	var pending: int = main.unclaimed_gold + main.idle_chest_gold
	main._calculate_offline_reward()
	check(main.unclaimed_gold + main.idle_chest_gold == pending, "offline award is idempotent in session")
	gold_before = main.wallet_gold
	main._claim_rewards()
	main._claim_rewards()
	check(main.wallet_gold == gold_before + pending and main.unclaimed_gold == 0, "pending hunt and chest claims pay once")

	print("v27_growth_economy_smoke_test checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), JSON.stringify(failures)])
	main.free()
	await create_timer(0.5).timeout
	await process_frame
	quit(0 if failures.is_empty() else 1)
