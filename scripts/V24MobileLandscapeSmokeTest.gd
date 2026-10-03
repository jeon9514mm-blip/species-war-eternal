extends SceneTree

func _fail(message: String, main = null) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if str(ProjectSettings.get_setting("display/window/stretch/aspect")) != "expand":
		_fail("V24: stretch aspect must be expand")
		return
	if int(ProjectSettings.get_setting("display/window/handheld/orientation")) != DisplayServer.SCREEN_LANDSCAPE:
		_fail("V24: app orientation must remain landscape")
		return
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	var safe := Vector4(32, 18, 32, 14)
	var base_layout: Dictionary = main._combat_layout_for_width(1280.0, safe)
	var wide_layout: Dictionary = main._combat_layout_for_width(1600.0, safe)
	var base_field: Rect2 = base_layout["field"]
	var wide_field: Rect2 = wide_layout["field"]
	var wide_side: Rect2 = wide_layout["side"]
	if wide_field.size.x <= base_field.size.x + 200.0:
		_fail("V24: 20:9 width does not expand battle field enough", main)
		return
	if wide_side.end.x > 1600.0 - 30.0:
		_fail("V24: wide HUD exceeds mobile safe frame", main)
		return
	main.selected_faction = "aurelia"
	main.idle_stage = 8
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._build_combat_screen()
	await process_frame
	if main.combat_field_rect.size.x < 760.0:
		_fail("V24: combat field collapsed", main)
		return
	var party_pos: Vector2 = main._map_world_position(main.expedition_position)
	if not main.combat_field_rect.grow(-30.0).has_point(party_pos):
		_fail("V24: camera-follow party anchor left the combat field", main)
		return
	if main.content_root.get_node_or_null("CombatTacticalStrip") == null:
		_fail("V24: mobile tactical HUD missing", main)
		return
	print("v24_mobile_landscape_smoke_test_ok orientation=landscape legacy_landscape_layout=ok aspect=expand wide_field=%.0f base_field=%.0f camera=follow safe=ok" % [wide_field.size.x, base_field.size.x])
	main.queue_free()
	for frame in 3: await process_frame
	await create_timer(0.12).timeout
	quit(0)
