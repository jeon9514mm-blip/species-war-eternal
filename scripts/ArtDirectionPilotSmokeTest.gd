extends SceneTree
## Run in a disposable XDG_DATA_HOME whose path contains `art-pilot`.
## Existing production save files are never replaced by this diagnostic.
const PILOT_SCENE := "res://scenes/art/ArtDirectionLab.tscn"
const INVASION := preload("res://scripts/InvasionHuntDirector.gd")
const REPORT := preload("res://scripts/RaidReportArchive.gd")
const SIDES := ["east", "west", "north", "south", "northeast", "southwest", "northwest", "southeast"]
var checks := 0
var failures: Array[String] = []
var protected: Dictionary = {}
var direction_results: Array[Dictionary] = []

func _init() -> void:
	run.call_deferred()

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)
		push_error(note)

func settle(frames := 8) -> void:
	for i in frames: await process_frame

func pointer_click(target: Button) -> void:
	check(target != null and target.is_visible_in_tree() and not target.disabled, "pointer target is available: " + str(target.name if target != null else "missing"))
	if target == null: return
	var viewport_point: Vector2 = target.get_global_transform_with_canvas() * (target.size * 0.5)
	var physical_point: Vector2 = root.get_final_transform() * viewport_point
	check(root.get_final_transform().affine_inverse() * physical_point == viewport_point, "physical pointer uses the actual viewport transform: " + str(target.name))
	var motion := InputEventMouseMotion.new()
	motion.position = physical_point
	motion.global_position = physical_point
	Input.parse_input_event(motion)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	check(hovered == target, "pointer hit reaches visible button: " + str(target.name) + " (hovered " + str(hovered.get_path() if hovered != null else "nothing") + ")")
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = physical_point
		event.global_position = physical_point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()

func prepare_sentinels() -> bool:
	var user_dir := ProjectSettings.globalize_path("user://")
	if not user_dir.contains("art-pilot"):
		check(false, "diagnostic requires an isolated art-pilot XDG_DATA_HOME")
		return false
	for base: String in ["user://pixel_war_save.json", PresentationSettings.PATH, REPORT.PATH]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".corrupt"]:
			if FileAccess.file_exists(base + suffix):
				check(false, "refuse to replace pre-existing save fixture: " + base + suffix)
				return false
	var sentinel := {"selected_faction": "noxfera", "current_zone_id": "forgotten_mine",
		"idle_stage": 73, "wallet_gold": 987654, "deployed_hero_ids": [],
		"last_idle_timestamp": int(Time.get_unix_time_from_system())}
	var store := SaveStore.new()
	check(bool(store.write_save("user://pixel_war_save.json", sentinel).get("ok", false)), "production sentinel writes successfully")
	check(PresentationSettings.save_preferences(false, false, {"music_volume": 0.13, "performance": "battery"}) == OK, "production config sentinel writes successfully")
	var report_file := FileAccess.open(REPORT.PATH, FileAccess.WRITE)
	report_file.store_string('{"sentinel":"production-raid-archive-must-survive"}')
	report_file.close()
	for base: String in ["user://pixel_war_save.json", PresentationSettings.PATH, REPORT.PATH]:
		check(DirAccess.copy_absolute(ProjectSettings.globalize_path(base), ProjectSettings.globalize_path(base + ".bak")) == OK, "production backup sentinel writes: " + base)
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".corrupt"]:
			var path := base + suffix
			protected[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return true

func check_sentinels(stage: String) -> void:
	for path: String in protected:
		var fingerprint := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
		check(fingerprint == protected[path], stage + " preserves " + path)

func run() -> void:
	if not prepare_sentinels():
		finish()
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var packed = load(PILOT_SCENE)
	if packed == null:
		check(false, "pilot scene can be loaded")
		finish()
		return
	var game = packed.instantiate()
	check(game.save_state_path != "user://pixel_war_save.json", "progression path is isolated before ready")
	check(game.presentation_preferences_path != PresentationSettings.PATH, "settings path is isolated before ready")
	check(str(game.get_meta("raid_report_path", REPORT.PATH)) != REPORT.PATH, "raid archive path is isolated before ready")
	root.add_child(game)
	current_scene = game
	await settle()
	for frame in 180:
		if bool(game.get_meta("pilot_ready", false)): break
		await process_frame
	check(bool(game.get_meta("pilot_ready", false)), "pilot completes its real startup")
	check(game.active_screen == "combat" and game.current_zone_id == "gray_meadow", "startup opens the meadow hunt")
	check(game.selected_faction == "aurelia" and game._deployed_hero_ids().has("leonhardt"), "startup uses Leonhardt and never imports the production faction")
	check(game.wallet_gold != 987654 and game.idle_stage != 73, "production progression sentinel was not loaded")
	check(game.presentation_options.get("performance") != "battery", "production presentation sentinel was not loaded")
	check(game.roaming_hunt.get_script() == INVASION, "pilot retains the actual eight-direction invasion director")
	check(game._FIELD == preload("res://scripts/HuntFieldService.gd"), "pilot retains the production hunt orchestrator")
	check(game.hunt_ai is AutoHuntController and game.party_movement is PartyMovementDirector, "pilot retains production targeting and movement engines")
	check(game.combat_running and game.is_physics_processing(), "startup enables the inherited combat physics loop")
	var before_clock: float = game.invasion.clock
	await create_timer(0.3).timeout
	check(game.invasion.clock > before_clock, "actual physics frames advance live invasion time")
	game.set_process(false)
	game.set_physics_process(false)
	game.combat_effects_enabled = false
	game.sound_effects_enabled = false
	game.presentation_runtime.audio.shutdown()
	check_sentinels("startup and real physics")
	await test_geometry(game)
	await test_directions(game)
	await test_routes_and_writes(game)
	game = await test_concept_roundtrip(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.presentation_runtime.audio.shutdown()
	await create_timer(0.35).timeout
	current_scene = null
	game.free()
	await create_timer(0.35).timeout
	check_sentinels("shutdown")
	finish()

func test_geometry(game) -> void:
	var field = game.combat_labels.terrain
	check(field.get_script().resource_path == "res://scripts/art/ArtDirectionBattlefield.gd", "actual hunt uses the independent art adapter")
	check(field.painterly_active, "pilot starts with the new meadow art")
	check(field.world.find_children("*", "CollisionObject3D", true, false).is_empty(), "new decoration adds no gameplay collision objects")
	var landmark_points: Array[Vector2] = [Vector2.ZERO, Vector2(32, 0), Vector2(0, 20), Vector2(32, 20),
		Vector2(16, 10), Vector2(2, 10), Vector2(30, 10), Vector2(16, 2), Vector2(16, 18)]
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(960, 540), Vector2i(720, 1280)]:
		var before: Dictionary = gameplay_snapshot(game)
		root.size = dimensions
		await settle(12)
		check(gameplay_snapshot(game) == before, "resize preserves encounter and gameplay RNG: " + str(dimensions))
		check(game.get_viewport_rect().size.x > game.get_viewport_rect().size.y, "logical canvas remains landscape: " + str(dimensions))
		check(game.combat_field_rect.size.x > game.combat_field_rect.size.y, "battlefield remains wide: " + str(dimensions))
		for point: Vector2 in landmark_points:
			var projected: Vector2 = field.project_world(point)
			var restored: Vector2 = field.local_to_world(projected)
			check(restored.distance_to(point) < 0.001, "32x20 world projection roundtrip " + str(point) + " @ " + str(dimensions))
			check(game._map_world_position(point).distance_to(game.combat_field_rect.position + projected) < 0.001, "actors share terrain projection " + str(point) + " @ " + str(dimensions))
		check(is_instance_valid(field.comparison_button) and field.comparison_button.is_visible_in_tree(), "comparison remains accessible after resize " + str(dimensions))
	root.size = Vector2i(1280, 720)
	await settle()
	var before: Dictionary = gameplay_snapshot(game)
	await pointer_click(field.comparison_button)
	check(not field.painterly_active, "comparison button opens the original map")
	check(gameplay_snapshot(game) == before, "comparing original map consumes no gameplay time or RNG and changes no HP")
	await pointer_click(field.comparison_button)
	check(field.painterly_active, "comparison button restores the new meadow")
	check(gameplay_snapshot(game) == before, "returning new art preserves the same encounter")
	var note: Label = game.content_root.get_node_or_null("ArtDirectionLabNotice")
	check(note != null and note.text.contains("기존 동작") and note.text.contains("저장 안 함"), "visible pilot notice discloses existing hero motion and disposable progress")
	var leon = game.hero_map_sprites[game._deployed_hero_ids().find("leonhardt")]
	var rig = leon.get_node_or_null("PortraitHeroSkeletalRig")
	check(rig != null and rig.rest_frame != null and rig.rest_frame.atlas != null, "pilot uses the existing single-rest-image skeleton, not invented separated art")
	if rig != null:
		check(rig.bones.size() > 1 and rig.rendered_in_3d, "existing weighted joints are connected to actual 3D billboard rendering")

func gameplay_snapshot(game) -> Dictionary:
	return {"enemy_wave": game.enemy_wave.duplicate(true), "hero_states": game.hero_battle_state.duplicate(true),
		"hero_runtime": game.hero_skill_runtime.duplicate(true), "enemy_positions": game.roaming_hunt.enemy_positions.duplicate(),
		"party_position": game.party_movement.positions.duplicate(true), "encounter": game.hunt_ai.encounter_id,
		"invasion_clock": game.invasion.clock, "invasion_serial": game.invasion.serial,
		"rng": game.loot_rng.state, "gold": game.wallet_gold, "xp": game.wallet_xp,
		"stage": game.idle_stage, "hunt_cycle": game.combat_hunt_cycle}

func test_directions(game) -> void:
	for serial in range(1, 9):
		game.current_zone_id = "gray_meadow"
		game.idle_stage = 1
		game.hero_progress["leonhardt"] = {"level": 35, "xp": 0}
		game.loot_rng.seed = 90217
		game._build_combat_screen()
		await settle()
		game.combat_running = true
		game.roaming_hunt.clear_enemies()
		game.roaming_hunt.append_corps(game.enemy_wave, serial)
		var entry: String = SIDES[serial - 1]
		var first_wave: Array = game.enemy_wave.duplicate()
		var first_positions: Array = game.roaming_hunt.enemy_positions.duplicate()
		check(not first_wave.is_empty(), entry + " has actual generated enemy stats")
		var centroid := Vector2.ZERO
		for point: Vector2 in first_positions: centroid += point
		centroid /= maxf(1.0, first_positions.size())
		var correct_edge := true
		if entry.contains("east"): correct_edge = correct_edge and centroid.x > 22.0
		if entry.contains("west"): correct_edge = correct_edge and centroid.x < 10.0
		if entry.contains("north"): correct_edge = correct_edge and centroid.y < 7.0
		if entry.contains("south"): correct_edge = correct_edge and centroid.y > 13.0
		check(correct_edge, entry + " actually spawns in the corresponding world quadrant")
		var all_entered := true
		for enemy: Dictionary in first_wave:
			all_entered = all_entered and str(enemy.get("entry_side", "")) == entry
		check(all_entered, entry + " positions every member at the selected entrance")
		var initial_hp := 0
		for enemy: Dictionary in first_wave: initial_hp += int(enemy.hp)
		var cycle: int = game.combat_hunt_cycle
		var steps := 0
		var maximum_alive := 0
		var maximum_groups := 0
		var approached := false
		while game.combat_hunt_cycle == cycle and steps < 1800:
			game._advance_auto_hunt(0.1)
			steps += 1
			if steps <= 10:
				for index in mini(first_positions.size(), game.roaming_hunt.enemy_positions.size()):
					var target: Vector2 = game._hero_field_position("leonhardt")
					approached = approached or game.roaming_hunt.enemy_position(index).distance_to(target) + 0.02 < first_positions[index].distance_to(target)
			maximum_alive = maxi(maximum_alive, game._enemy_wave_alive_count())
			maximum_groups = maxi(maximum_groups, game.invasion.groups.size())
			if steps % 120 == 0: await process_frame
		var remaining_hp := 0
		for enemy: Dictionary in first_wave: remaining_hp += maxi(0, int(enemy.hp))
		check(remaining_hp < initial_hp, entry + " receives real combat HP damage")
		check(game.combat_hunt_cycle > cycle, entry + " naturally clears through the production reward loop")
		check(maximum_alive <= 25 and maximum_groups <= 2, entry + " respects normal invasion admission caps")
		check(approached, entry + " enemies move toward the party before the first clear")
		direction_results.append({"entrance": entry, "seconds": steps * 0.1,
			"removed_hp": initial_hp - remaining_hp, "initial_hp": initial_hp,
			"clears": game.combat_hunt_cycle - cycle, "maximum_alive": maximum_alive,
			"maximum_groups": maximum_groups})
		print("ART_PILOT_DIRECTION ", JSON.stringify(direction_results.back()))
	check_sentinels("eight entrances and automatic reward saves")

func test_routes_and_writes(game) -> void:
	game._build_inventory_screen()
	await settle()
	check(game.active_screen == "inventory", "pilot can visit the real inventory")
	game._build_combat_screen()
	await settle()
	check(game.active_screen == "combat" and game.current_zone_id == "gray_meadow", "menu return preserves the meadow hunt")
	check(game.combat_labels.terrain.get_script().resource_path == "res://scripts/art/ArtDirectionBattlefield.gd", "menu return recreates the pilot presentation adapter")
	game._save_idle_state()
	check(game.last_save_status == "art_lab_no_persistence" and not FileAccess.file_exists(game.save_state_path), "pilot intentionally keeps progression in memory without creating a save")
	game._save_ui_preferences()
	check(game.presentation_settings_error == OK and not FileAccess.file_exists(game.presentation_preferences_path), "pilot intentionally keeps preferences in memory without creating a config")
	# Exercise the inherited report writer, rather than merely checking a path string.
	game.selected_raid_id = "gray_meadow"
	game._build_raid_screen()
	await settle()
	game._start_raid()
	game.combat_timer.stop()
	game._finish_raid("defeat")
	check(bool(game.get_meta("raid_report_saved", false)), "pilot inherited raid writes an isolated report")
	check(FileAccess.file_exists(str(game.get_meta("raid_report_path"))), "isolated raid archive exists after finish")
	check_sentinels("menu, explicit saves, and raid report")

func test_concept_roundtrip(game):
	game._build_combat_screen()
	await settle()
	var previous_id: int = game.get_instance_id()
	var open_concept: Button = game.content_root.find_child("ArtDirectionConceptButton", true, false)
	await pointer_click(open_concept)
	for frame in 60:
		if current_scene != null and current_scene.scene_file_path == "res://scenes/art/HeroConceptStudy.tscn": break
		await process_frame
	var reached: bool = current_scene != null and current_scene.scene_file_path == "res://scenes/art/HeroConceptStudy.tscn"
	check(reached, "real pointer opens the separate hero concept scene")
	if not reached: return game
	check(not is_instance_id_valid(previous_id), "scene transition frees the prior game instead of running hidden combat")
	var concept = current_scene
	var concept_image: TextureRect = concept.find_child("NewHeroConcept", true, false)
	check(concept_image != null and concept_image.texture != null and concept_image.is_visible_in_tree(), "concept scene displays the actual new hero artwork")
	var return_button: Button = concept.find_child("OpenArtDirectionLab", true, false)
	await pointer_click(return_button)
	for frame in 180:
		if current_scene != null and current_scene.scene_file_path == PILOT_SCENE and bool(current_scene.get_meta("pilot_ready", false)): break
		await process_frame
	var returned: bool = current_scene != null and current_scene.scene_file_path == PILOT_SCENE
	check(returned, "real pointer returns from concept art to the actual meadow scene")
	if not returned:
		# Keep cleanup safe even when a route is broken, without hiding the failure.
		change_scene_to_file(PILOT_SCENE)
		await settle(30)
	var next_game = current_scene
	next_game.set_process(false)
	next_game.set_physics_process(false)
	check(next_game.active_screen == "combat" and bool(next_game.get_meta("pilot_ready", false)), "concept return creates a ready playable meadow")
	check(next_game.save_state_path != "user://pixel_war_save.json" and next_game.save_load_status == "art_lab_no_persistence", "concept return remains isolated from production progress")
	check_sentinels("actual concept scene roundtrip")
	return next_game

func finish() -> void:
	var result := {"checks": checks, "failures": failures, "directions": direction_results,
		"scope": "Actual independent pilot scene; isolated progression, preferences and raid archive; live production hunt engine"}
	var out := FileAccess.open("user://art-pilot-results.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "  "))
		out.close()
	print("art_direction_pilot checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
