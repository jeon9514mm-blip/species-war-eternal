extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame

	main.selected_faction = "aurelia"
	var roster: Array = main._hero_roster_for_faction()
	if roster.size() != 15:
		push_error("V5 requires 15 heroes per faction")
		quit(1)
		return

	main.idle_stage = 1
	if not main._is_zone_unlocked("gray_meadow") or main._is_zone_unlocked("forgotten_mine"):
		push_error("Zone unlock gating failed at stage 1")
		quit(1)
		return
	main.idle_stage = 4
	if not main._is_zone_unlocked("forgotten_mine") or main._is_zone_unlocked("moonrest_forest"):
		push_error("Zone unlock gating failed at stage 4")
		quit(1)
		return
	main.idle_stage = 8
	if not main._is_zone_unlocked("moonrest_forest"):
		push_error("Moonrest forest did not unlock at stage 8")
		quit(1)
		return

	main._restore_deployed_heroes(["leonhardt", "mira", "elisia", "kairen"])
	if main.deployed_heroes.size() != 4 or main._deployed_hero_ids()[0] != "leonhardt":
		push_error("Party save/restore foundation failed")
		quit(1)
		return

	main.deployed_heroes = roster.slice(0, 10).duplicate()
	main._setup_hero_progress(roster)
	var synergy: Dictionary = main._calculate_party_synergy()
	if float(synergy["power_multiplier"]) <= 1.0 or float(synergy["hp_multiplier"]) <= 1.0:
		push_error("10-person synergy did not activate")
		quit(1)
		return
	main.party_power = main._calculate_party_power()
	main._setup_hero_skills()
	if main.hero_skill_runtime.size() != 10:
		push_error("Expected ten hero skill runtimes")
		quit(1)
		return

	main.loot_inventory = []
	main.wallet_gold = 0
	for index in range(main.INVENTORY_CAP):
		main.loot_inventory.append({"id": "common_%d" % index, "slot": "weapon", "rarity": "일반", "name": "시험용 장비", "level": 1, "power": 30})
	var result: String = main._store_or_salvage_loot({"id": "legendary_test", "slot": "weapon", "rarity": "전설", "name": "시험용 전설 장비", "level": 1, "power": 90})
	if main.loot_inventory.size() != main.INVENTORY_CAP or main.wallet_gold <= 0 or result.find("자동 분해") < 0:
		push_error("Inventory overflow protection failed")
		quit(1)
		return

	print("v5_foundation_smoke_test_ok heroes=%d synergy=%s inventory=%d gold=%d" % [roster.size(), synergy["summary"], main.loot_inventory.size(), main.wallet_gold])
	main.free()
	quit(0)
