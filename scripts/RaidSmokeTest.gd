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
	main.raid_clears = {}
	main._setup_hero_progress(roster)
	main.deployed_heroes = [roster[0], roster[1], roster[2]]
	var zones: Dictionary = main._zone_data()
	if zones["gray_meadow"]["monsters"].size() < 4 or zones["forgotten_mine"]["monsters"].size() < 4 or zones["moonrest_forest"]["monsters"].size() < 5:
		push_error("Monster variety was not added to all zones")
		quit(1)
	for zone_id in ["gray_meadow", "forgotten_mine", "moonrest_forest"]:
		if not zones[zone_id].has("boss") or not zones[zone_id].has("boss_skill"):
			push_error("Zone boss data is missing")
			quit(1)
	main.current_zone_id = "forgotten_mine"
	main._build_raid_screen()
	main._start_raid()
	main.raid_boss_hp = 1
	var before_gold: int = main.unclaimed_gold
	main._on_raid_tick()
	if int(main.raid_clears.get("forgotten_mine", 0)) != 1:
		push_error("Raid clear was not recorded")
		quit(1)
	if main.unclaimed_gold <= before_gold or main.raid_running:
		push_error("Raid reward or stop state failed")
		quit(1)
	print("raid_smoke_test_ok boss=%s clears=%d gold_reward=%d drops=%d" % [zones["forgotten_mine"]["boss"], main.raid_clears["forgotten_mine"], main.unclaimed_gold - before_gold, main.loot_inventory.size()])
	main.free()
	quit(0)
