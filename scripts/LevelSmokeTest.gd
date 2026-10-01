extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.selected_faction = "aurelia"
	var roster: Array = main._hero_roster_for_faction()
	main.deployed_heroes = [roster[0], roster[1], roster[2]]
	main._setup_hero_progress(roster)
	for hero in main.deployed_heroes:
		var progress: Dictionary = main._get_hero_progress(str(hero["id"]))
		progress["level"] = 1
		progress["xp"] = 95
		main.hero_progress[str(hero["id"])] = progress
	var before_power: int = main._calculate_party_power()
	main._grant_hero_xp(30)
	var leveled = 0
	for hero in main.deployed_heroes:
		var progress: Dictionary = main._get_hero_progress(str(hero["id"]))
		if int(progress["level"]) >= 2:
			leveled += 1
	if leveled != 3:
		push_error("All deployed heroes should level up")
		quit(1)
	var after_power: int = main._calculate_party_power()
	if after_power <= before_power:
		push_error("Party power did not increase after level up")
		quit(1)
	if main.hero_level_event.is_empty():
		push_error("Level up event was not recorded")
		quit(1)
	print("level_smoke_test_ok leveled=%d before_power=%d after_power=%d event=%s" % [leveled, before_power, after_power, main.hero_level_event])
	main.free()
	quit(0)
