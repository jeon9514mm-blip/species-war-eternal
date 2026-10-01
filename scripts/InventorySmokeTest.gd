extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.selected_faction = "aurelia"
	main.hero_progress = {}
	main.hero_equipment = {}
	main.hero_equipment_rarity = {}
	main.hero_equipment_names = {}
	main.loot_inventory = []
	var roster: Array = main._hero_roster_for_faction()
	main._setup_hero_progress(roster)
	main.deployed_heroes = [roster[0]]
	main.wallet_gold = 1000
	var hero_id = str(roster[0]["id"])
	main.loot_inventory.append({"id": "test_rare_weapon", "slot": "weapon", "rarity": "희귀", "name": "시험용 푸른 별의 활", "level": 1, "power": 32})
	main._enhance_inventory_item(0)
	var upgraded: Dictionary = main.loot_inventory[0]
	if int(upgraded["level"]) != 2 or main.wallet_gold != 825:
		push_error("Inventory enhancement failed")
		quit(1)
	main._equip_inventory_item(0, hero_id)
	var equipped_rarity: Dictionary = main._get_hero_equipment_rarity(hero_id)
	var equipped: Dictionary = main._get_hero_equipment(hero_id)
	if str(equipped_rarity["weapon"]) != "희귀" or int(equipped["weapon"]) != 2 or main.loot_inventory.size() != 1:
		push_error("Inventory equip and old item return failed")
		quit(1)
	main._decompose_inventory_item(0)
	if not main.loot_inventory.is_empty() or main.wallet_gold <= 825:
		push_error("Inventory decomposition failed")
		quit(1)
	print("inventory_smoke_test_ok rarity=%s level=%d gold=%d" % [equipped_rarity["weapon"], equipped["weapon"], main.wallet_gold])
	main.free()
	quit(0)
