extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.selected_faction = "aurelia"
	var roster: Array = main._hero_roster_for_faction()
	main._setup_hero_progress(roster)
	main.deployed_heroes = [roster[0]]
	main.wallet_gold = 1000
	var hero_id = str(roster[0]["id"])
	main.hero_equipment[hero_id] = {"weapon": 1, "armor": 1, "accessory": 1}
	var before_power: int = main._calculate_party_power()
	main._enhance_equipment(roster[0], "weapon")
	var equipment: Dictionary = main._get_hero_equipment(hero_id)
	if int(equipment["weapon"]) != 2:
		push_error("Weapon enhancement did not reach +2")
		quit(1)
	var after_power: int = main._calculate_party_power()
	if after_power <= before_power:
		push_error("Equipment power was not added to party power")
		quit(1)
	if main.wallet_gold != 825:
		push_error("Unexpected weapon enhancement cost")
		quit(1)
	main.wallet_gold = 0
	main._enhance_equipment(roster[0], "armor")
	if int(equipment["armor"]) != 1:
		push_error("Armor should not enhance without enough gold")
		quit(1)
	print("equipment_smoke_test_ok before_power=%d after_power=%d weapon=%d gold=%d" % [before_power, after_power, equipment["weapon"], main.wallet_gold])
	main.set_process(false);main.set_physics_process(false)
	main.presentation_runtime.audio.shutdown();await create_timer(.3).timeout
	main.free();await process_frame
	quit(0)
