extends SceneTree

func _fail(message: String, main) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, 3)
	main._offline_checked = true
	main._build_combat_screen()
	await process_frame
	await process_frame
	# Persistent field controls must fit without overlap. Navigation controls
	# live inside the optional scrolling details panel and are checked there.
	var keys = ["claim", "toggle", "speed", "details_button"]
	var viewport = root.get_visible_rect()
	for index in keys.size():
		var control: Control = main.combat_labels[keys[index]]
		if not control.is_visible_in_tree() or not viewport.encloses(control.get_global_rect()):
			_fail("Combat control is hidden or outside viewport: %s" % keys[index], main)
			return
		for other_index in range(index + 1, keys.size()):
			var other: Control = main.combat_labels[keys[other_index]]
			if control.get_global_rect().intersects(other.get_global_rect()):
				_fail("Combat controls overlap: %s / %s" % [keys[index], keys[other_index]], main)
				return
	var details: Control = main.combat_labels["details_panel"]
	var scroll: ScrollContainer = main.combat_labels["details_scroll"]
	if details.visible:
		_fail("Hunt details should start closed", main)
		return
	# A real boss appearance exposes the conditional raid-entry button.
	main.combat_effects_enabled = false
	main._spawn_open_map_boss()
	main._toggle_hunt_details()
	await process_frame
	await process_frame
	if not details.is_visible_in_tree() or not viewport.encloses(details.get_global_rect()):
		_fail("Open hunt details do not fit the viewport", main)
		return
	var detail_keys = ["zone_button", "raid_button", "boss_raid_button"]
	for key in detail_keys:
		var control: Control = main.combat_labels[key]
		scroll.ensure_control_visible(control)
		await process_frame
		await process_frame
		if not control.is_visible_in_tree() or not viewport.encloses(control.get_global_rect()) or not scroll.get_global_rect().grow(1.0).encloses(control.get_global_rect()):
			_fail("Scrolled hunt control cannot be reached: %s" % key, main)
			return
		for other_key in detail_keys:
			if other_key == key:
				continue
			var other: Control = main.combat_labels[other_key]
			if control.get_global_rect().intersects(other.get_global_rect()):
				_fail("Hunt details controls overlap: %s / %s" % [key, other_key], main)
				return
	main._toggle_hunt_details()
	if details.visible:
		_fail("Hunt details did not close", main)
		return
	main._advance_auto_hunt(0.1)
	main._toggle_combat(main.combat_labels["toggle"])
	var position: Vector2 = main.hero_map_sprites[0].position
	var monster_position: Vector2 = main.monster_sprite.position
	await create_timer(0.25).timeout
	if main.hero_map_sprites[0].position != position or main.monster_sprite.position != monster_position or main.hero_map_sprites[0].speed_scale != 0.0:
		_fail("Paused sprite movement or animation continued", main)
		return
	main._toggle_combat(main.combat_labels["toggle"])
	if main.hero_map_sprites[0].speed_scale != 1.0 or not main.monster_sprite.is_processing():
		_fail("Sprite animation did not resume", main)
		return
	print("combat_controls_ok visible_buttons=4 scrollable_buttons=3 no_overlap=true pause_resume=true")
	main.set_process(false)
	main.presentation_runtime.audio.shutdown()
	await create_timer(0.3).timeout
	main.free()
	await process_frame
	quit(0)
