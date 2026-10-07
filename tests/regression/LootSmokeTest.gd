extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false); main.set_physics_process(false)
	main._offline_checked = true
	main.selected_faction = "aurelia"
	var roster: Array = main._hero_roster_for_faction()
	main.hero_progress = {}
	main.hero_equipment = {}
	main.hero_equipment_rarity = {}
	main.hero_equipment_names = {}
	main.hero_equipment_items = {}
	main.hero_equipment_sets = {}
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
		return
	if main._rarity_multiplier("전설") <= main._rarity_multiplier("희귀") or main._rarity_multiplier("희귀") <= main._rarity_multiplier("일반"):
		push_error("Rarity multipliers are not ordered")
		quit(1)
		return
	# Role-specific rare drops have affixes and require an explicit choice.
	# Pure gear still auto-equips when it preserves the current defensive set.
	var plain: Dictionary = main.GEAR.normalize({"id":"plain_auto_test","slot":"weapon","rarity":"전설","level":1,"set":"초보자","origin":"hunt"})
	var target: String = main._best_auto_equipment_target(plain, main.deployed_heroes)
	if target.is_empty():
		push_error("Unprotected upgrade preserving the defensive set has no auto target")
		main.free(); quit(1); return
	main.loot_inventory.append(plain)
	if not main._equip_item_direct(main.loot_inventory.size()-1,target):
		push_error("Unprotected auto upgrade cannot be equipped")
		main.free(); quit(1); return
	var manually_equipped := false
	for item: Dictionary in main.loot_inventory.duplicate(true):
		if str(item.get("rarity","")) != "전설" or not main.GEAR.protected(item): continue
		for hero: Dictionary in main.deployed_heroes:
			var hero_id: String = str(hero.id)
			if not main._gear_role_matches(item,hero_id):continue
			if main._automatic_equipment_gain(item,hero_id)!=0:
				push_error("Protected affix gear unexpectedly auto-equips")
				main.free(); quit(1); return
			manually_equipped=bool(main._gear_equip_item(str(item.id),hero_id).get("ok",false))
			break
		if manually_equipped:break
	if not manually_equipped:
		push_error("Role-compatible legendary affix gear cannot be manually equipped")
		main.free(); quit(1); return
	print("loot_smoke_test_ok total=%d common=%d rare=%d legendary=%d inventory=%d" % [main.loot_inventory.size(), counts["일반"], counts["희귀"], counts["전설"], main.loot_inventory.size()])
	for frame in 5: await process_frame
	if main.presentation_runtime != null: main.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	main.free()
	await create_timer(0.35).timeout
	quit(0)
