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
	main.deployed_heroes = [roster[0], roster[1], roster[2]]
	main.current_zone_id = "forgotten_mine"
	main._build_combat_screen()
	await process_frame
	main.combat_kills = 4
	main.combat_hunt_cycle = 4
	main._spawn_open_map_boss()
	if not main.open_map_boss_active:
		push_error("Open-map boss did not become active")
		quit(1)
	if main.open_map_boss_name != "광맥의 거인 모르굴":
		push_error("Wrong regional boss spawned: %s" % main.open_map_boss_name)
		quit(1)
	if main.open_map_boss_sprite == null or not is_instance_valid(main.open_map_boss_sprite):
		push_error("Open-map boss sprite was not created")
		quit(1)
	if main.open_map_boss_position == Vector2.ZERO:
		push_error("Open-map boss position was not assigned")
		quit(1)
	var button: Button = main.combat_labels.get("boss_raid_button")
	if button == null or not button.visible:
		push_error("Boss raid entry button was not shown")
		quit(1)
	print("boss_encounter_smoke_test_ok boss=%s position=%s raid_button_visible=%s" % [main.open_map_boss_name, main.open_map_boss_position, button.visible])
	main.free()
	quit(0)
