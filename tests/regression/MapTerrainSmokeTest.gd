extends SceneTree

func _fail(message: String, main) -> void:
	push_error(message)
	main.free()
	quit(1)

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main._offline_checked = true
	main.selected_faction = "aurelia"
	var roster: Array = main._hero_roster_for_faction()
	main.hero_progress = {}
	main.hero_equipment = {}
	main.hero_equipment_rarity = {}
	main.hero_equipment_names = {}
	main.deployed_heroes = [roster[0], roster[1], roster[2]]
	for zone_id in ["gray_meadow", "forgotten_mine", "moonrest_forest"]:
		main.current_zone_id = zone_id
		main._build_combat_screen()
		await process_frame
		var terrain: MapTerrainRenderer = main.combat_labels.get("terrain")
		if terrain == null:
			_fail("Map terrain renderer missing for %s" % zone_id, main)
			return
		if terrain.zone_id != zone_id:
			_fail("Map terrain zone mismatch for %s" % zone_id, main)
			return
		if terrain.get_parent() != main.content_root or terrain.position != main.combat_field_rect.position or terrain.size != main.combat_field_rect.size or not terrain.clip_contents:
			_fail("Terrain does not cover the clipped combat field for %s" % zone_id, main)
			return
		for camera in [Vector2(12, 7), Vector2(20, 13)]:
			main.combat_camera_position = camera
			main._update_combat_camera(0.0)
			for world_point in [camera, camera + Vector2(2.0, -1.0), camera + Vector2(-3.0, 1.5)]:
				var local_point: Vector2 = terrain._map_point(world_point)
				var actor_point: Vector2 = main._map_world_position(world_point)
				if (terrain.position + local_point).distance_to(actor_point) > 0.01 or terrain.local_to_world(local_point).distance_to(world_point) > 0.0001:
					_fail("Terrain and actor world projections diverge for %s" % zone_id, main)
					return
	print("map_terrain_smoke_test_ok zones=3 field_clip=true camera_positions=2 world_projection=aligned")
	main.free()
	quit(0)
