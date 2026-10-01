extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.selected_faction = "aurelia"
	var roster: Array = main._hero_roster_for_faction()
	main.hero_progress = {}
	main.hero_equipment = {}
	main.hero_equipment_rarity = {}
	main.hero_equipment_names = {}
	main.loot_inventory = []
	main._setup_hero_progress(roster)
	main.deployed_heroes = [roster[0], roster[1], roster[2]]
	main.loot_rng.seed = 12345
	var zone: Dictionary = main._zone_data()["moonrest_forest"]
	var counts = {"일반": 0, "희귀": 0, "전설": 0}
	for index in range(200):
		var item: Dictionary = main._roll_equipment_drop(zone)
		if not item.is_empty():
			counts[item["rarity"]] = int(counts[item["rarity"]]) + 1
	if main.loot_inventory.is_empty() or int(counts["일반"]) <= 0 or int(counts["희귀"]) <= 0 or int(counts["전설"]) <= 0:
		push_error("Expected all three equipment rarities to drop")
		quit(1)
	if main._rarity_multiplier("전설") <= main._rarity_multiplier("희귀") or main._rarity_multiplier("희귀") <= main._rarity_multiplier("일반"):
		push_error("Rarity multipliers are not ordered")
		quit(1)
	var equipped_rarity: Dictionary = main._get_hero_equipment_rarity(str(roster[0]["id"]))
	var upgraded = false
	for slot in ["weapon", "armor", "accessory"]:
		if main._rarity_rank(str(equipped_rarity[slot])) > 1:
			upgraded = true
	if not upgraded:
		push_error("A higher rarity item was never auto-equipped")
		quit(1)
	print("loot_smoke_test_ok total=%d common=%d rare=%d legendary=%d inventory=%d" % [main.loot_inventory.size(), counts["일반"], counts["희귀"], counts["전설"], main.loot_inventory.size()])
	main.free()
	quit(0)
