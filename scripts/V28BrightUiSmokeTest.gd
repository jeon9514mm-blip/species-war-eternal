extends SceneTree

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.save_state_path = "user://v28-bright-ui-smoke.json"
	main.selected_faction = "aurelia"
	main._offline_checked = true
	main.idle_stage = 8
	main._restore_deployed_heroes(["leonhardt", "mira", "orwin", "darius", "caelum"])
	main._build_combat_screen()
	await process_frame
	await process_frame
	check(main.combat_field_rect == Rect2(28, 76, 1224, 460), "1280×720 layout reserves a wide, unobstructed field")
	check(main.combat_labels["details_panel"].visible == false, "Long hunt details are initially collapsed")
	check(main.theme.default_font.has_char(0xC0AC), "Bundled font contains Korean syllables")
	check(main.theme.default_font.has_char(0xC601), "Bundled font contains hero text")
	check((main.PANEL.srgb_to_linear().get_luminance() + 0.05) / (main.TEXT.srgb_to_linear().get_luminance() + 0.05) > 7.0, "Dark body text has strong contrast on cream panels")
	var viewport := root.get_visible_rect()
	for key in ["claim", "toggle", "speed", "details_button", "header_stage", "header_progress", "gold", "gems", "tactical_strip"]:
		var control: Control = main.combat_labels[key]
		check(control.is_visible_in_tree(), "Visible HUD control: " + key)
		check(viewport.encloses(control.get_global_rect()), "HUD remains inside the viewport: " + key)
	for index in range(10):
		var slot: Node = main.content_root.find_child("PartyPortrait%d" % index, true, false)
		check(slot != null, "Party slot remains accessible: %d" % index)
	for hero in main.deployed_heroes:
		var hero_id := str(hero["id"])
		check(main._combat_portrait_texture(hero_id) != null, "Portrait is drawn from actual character art: " + hero_id)
		var hp: ProgressBar = main.combat_labels["portrait_hp_%s" % hero_id]
		var ultimate: ProgressBar = main.combat_labels["portrait_ultimate_%s" % hero_id]
		check(is_equal_approx(hp.value, 100.0), "Initial hero health appears in portrait: " + hero_id)
		main._gain_ultimate(hero_id, 37.0)
		main._update_combat_tactical_strip()
		check(is_equal_approx(ultimate.value, float(main.hero_battle_state[hero_id]["ultimate"])), "Ultimate gauge follows battle state after real charge gain: " + hero_id)
		check(ultimate.value > 0.0, "Ultimate charge is visible: " + hero_id)
	main.idle_stage_kills = 3
	main._update_stage_label()
	check(main.combat_labels["header_progress"].text == "무리 격파  3 / 10", "Progress describes monster groups, matching reward accounting")
	var terrain: MapTerrainRenderer = main.combat_labels["terrain"]
	check(terrain.MOOD_BRIGHTNESS == 0.90 and terrain.MOOD_SATURATION == 0.88, "Terrain uses the user's reduced brightness")
	terrain.configure_world_view(61.333333, Vector2(612, 239.2))
	terrain.set_camera_position(Vector2(16, 10))
	var point := Vector2(17.5, 12.1)
	check(terrain.local_to_world(terrain._map_point(point)).distance_to(point) < 0.001, "Terrain projection is reversible in world coordinates")
	var old_screen := terrain._map_point(point)
	terrain.set_camera_position(Vector2(17, 10.5))
	check((terrain._map_point(point) - old_screen).distance_to(-Vector2(1, 0.5) * terrain.pixels_per_unit) < 0.001, "Camera movement translates terrain at the actor scale")
	var wide: Dictionary = main._combat_layout_for_width(1600, Vector4(52, 18, 40, 14))
	check(wide["field"] == Rect2(52, 76, 1508, 460), "Wider displays respect safe margins and reveal more field")
	main.wallet_gold = 9876543210123
	main.wallet_gems = 1234567890
	main._update_reward_labels()
	await process_frame
	await process_frame
	check(main.combat_labels["gold"].text == "골드  9.9조", "Late-game gold is abbreviated to keep the header readable")
	check(main.combat_labels["gems"].text == "보석 12.3억", "Large gem balances fit the header")
	for key in ["gold", "gems", "header_stage", "header_progress"]:
		check(viewport.encloses(main.combat_labels[key].get_global_rect()), "Large wallet balance stays inside viewport: " + key)
	check(main.combat_labels["gold"].tooltip_text == "골드 9876543210123", "Exact gold balance remains available")
	# Check real laid-out rectangles after the text changed, not label minimums.
	check(not main.combat_labels["gold"].get_global_rect().intersects(main.combat_labels["gems"].get_global_rect()), "Large currency labels do not overlap")
	main.free()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("v28_bright_ui_ok checks=%d" % checks)
	quit(0)
