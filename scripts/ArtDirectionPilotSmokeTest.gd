extends SceneTree
## Run in a disposable XDG_DATA_HOME whose path contains `art-pilot`.
## Existing production save files are never replaced by this diagnostic.
const PILOT_SCENE := "res://scenes/art/ArtDirectionLab.tscn"
const INVASION := preload("res://scripts/InvasionHuntDirector.gd")
const REPORT := preload("res://scripts/RaidReportArchive.gd")
const SIDES := ["east", "west", "north", "south", "northeast", "southwest", "northwest", "southeast"]
const LAYERS := ["Sky", "FarClouds", "Mountains", "NearClouds", "Foothills", "Treeline", "Village", "Midtrees", "HorizonHaze", "Ground", "GroundDapple", "GroundDetails", "LightShafts", "ForegroundFar", "ForegroundNear", "EdgeDust", "AmbientButterflies", "ForegroundBokeh"]
var checks := 0
var failures: Array[String] = []
var protected: Dictionary = {}
var direction_results: Array[Dictionary] = []
var startup_runtime: Dictionary = {}

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
	var startup_backdrop = game.combat_labels.terrain.backdrop
	var before_atmosphere: float = startup_backdrop.atmosphere_time
	await create_timer(0.3).timeout
	check(game.invasion.clock > before_clock, "actual physics frames advance live invasion time")
	check(startup_backdrop.atmosphere_time > before_atmosphere and bool(startup_backdrop.atmosphere_state().running), "actual unmodified startup frames advance atmosphere through the production physics loop")
	startup_runtime = {"regular_processing": game.is_processing(), "physics_processing": game.is_physics_processing(),
		"invasion_elapsed": game.invasion.clock - before_clock, "atmosphere_elapsed": startup_backdrop.atmosphere_time - before_atmosphere,
		"atmosphere_running": startup_backdrop.atmosphere_state().running}
	print("ART_PILOT_LIVE_STARTUP ", JSON.stringify(startup_runtime))
	game.set_process(false)
	game.set_physics_process(false)
	game.combat_effects_enabled = false
	game.sound_effects_enabled = false
	game.presentation_runtime.audio.shutdown()
	check_sentinels("startup and real physics")
	await test_geometry(game)
	await test_backdrop(game)
	await test_atmosphere_clock(game)
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
		var observed: Dictionary = actor_alignment(game, true)
		check(observed.inside and observed.samples > 0, "all live actor heads and feet stay below the horizon and inside the safe area " + str(dimensions) + " " + str(observed.issues))
		check(observed.aligned, "rendered feet and 2D combat anchors use the same world positions after resize " + str(dimensions))
		check(field.backdrop.foreground_clear_rect().is_equal_approx(field.safe_play_rect()), "foreground shader preserves the actual safe area after resize " + str(dimensions))
	root.size = Vector2i(1280, 720)
	await settle()
	var before: Dictionary = gameplay_snapshot(game)
	field._update_hunt_camera(0.0, true)
	field._process(0.0)
	var before_projection: Array[Vector2] = []
	for point: Vector2 in landmark_points: before_projection.append(field.project_world(point))
	var controls_before := {"compare": field.comparison_button.get_global_rect(), "overview": field.view_button.get_global_rect()}
	await pointer_click(field.comparison_button)
	check(not field.painterly_active, "comparison button opens the original map")
	check(not field.backdrop.visible and not field.backdrop.foreground_root.visible, "original map comparison hides both painted background and foreground")
	check(gameplay_snapshot(game) == before, "comparing original map consumes no gameplay time or RNG and changes no HP")
	await pointer_click(field.comparison_button)
	check(field.painterly_active, "comparison button restores the new meadow")
	check(gameplay_snapshot(game) == before, "returning new art preserves the same encounter")
	field._update_hunt_camera(0.0, true)
	field._process(0.0)
	var restored_projection := true
	for i in landmark_points.size(): restored_projection = restored_projection and field.project_world(landmark_points[i]).distance_to(before_projection[i]) < 0.01
	check(restored_projection, "returning from original map restores the same world-to-ground projection")
	check(field.comparison_button.get_global_rect() == controls_before.compare and field.view_button.get_global_rect() == controls_before.overview, "map comparison never shifts UI controls")
	await pointer_click(field.view_button)
	check(field.overview_mode, "actual view control opens the full battlefield overview")
	var complete_lawn_visible := true
	for corner: Vector2 in [Vector2.ZERO, Vector2(32, 0), Vector2(0, 20), Vector2(32, 20)]:
		complete_lawn_visible = complete_lawn_visible and field.safe_play_rect().grow(0.6).has_point(field.project_world(corner))
	check(complete_lawn_visible, "overview contains the complete unchanged 32x20 ground below the horizon")
	await pointer_click(field.view_button)
	check(not field.overview_mode and gameplay_snapshot(game) == before, "returning to combat view preserves all simulation state")
	var note: Label = game.content_root.get_node_or_null("ArtDirectionLabNotice")
	check(note != null and note.text.contains("기존 동작") and note.text.contains("저장 안 함"), "visible pilot notice discloses existing hero motion and disposable progress")
	var leon = game.hero_map_sprites[game._deployed_hero_ids().find("leonhardt")]
	var rig = leon.get_node_or_null("PortraitHeroSkeletalRig")
	check(rig != null and rig.rest_frame != null and rig.rest_frame.atlas != null, "pilot uses the existing single-rest-image skeleton, not invented separated art")
	if rig != null:
		check(rig.bones.size() > 1 and rig.rendered_in_3d, "existing weighted joints are connected to actual 3D billboard rendering")

func test_backdrop(game) -> void:
	var field = game.combat_labels.terrain
	var backdrop = field.backdrop
	var manifest: Array = backdrop.layer_manifest()
	check(manifest.size() == LAYERS.size(), "eighteen declared layers back the actual meadow composition")
	check(field.viewport_3d.transparent_bg, "live 3D actors and ground composite over the painted background")
	var actual_names: Array[String] = []
	var ratios: Dictionary = {}
	var sources: Dictionary = {}
	var moving: Array[Control] = []
	for layer: Dictionary in manifest:
		var named: String = str(layer.get("name", ""))
		actual_names.append(named)
		ratios[str(layer.get("ratio", ""))] = true
		var kind: String = str(layer.get("kind", ""))
		var source: String = str(layer.get("source", ""))
		if kind == "world":
			var mesh = field.world.get_node_or_null(source.trim_prefix("world/"))
			check(mesh is MeshInstance3D and mesh.mesh != null and mesh.visible, "world layer is actual rendered geometry: " + named)
			if named == "GroundDetails" and mesh is MeshInstance3D:
				var atlas: Texture2D = ground_detail_atlas(mesh)
				check(atlas != null and atlas.resource_path == "res://assets/art-direction/pilot-01/layers/ground-details.png", "world ground details bind their actual ninth painted atlas")
				if atlas != null: sources[atlas.resource_path] = true
				test_ground_detail_geometry(field, mesh)
			continue
		var node: Control = backdrop.find_child(named, true, false)
		if node == null: node = backdrop.foreground_root.find_child(named, true, false)
		check(node != null and node.is_visible_in_tree(), "declared layer is an actual visible node: " + named)
		if node == null: continue
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "painted decoration never captures player input: " + named)
		moving.append(node)
		if kind in ["painted", "reused"]:
			var expected_source := source if source.begins_with("res://") else "res://assets/art-direction/pilot-01/layers/" + source
			var texture: Texture2D = node.texture if node is TextureRect else null
			if texture is AtlasTexture: texture = texture.atlas
			check(texture != null and texture.resource_path == expected_source, "painted layer binds its declared imported texture: " + named)
			sources[source] = true
	for named: String in LAYERS: check(actual_names.count(named) == 1, "composition contains exactly one " + named)
	check(sources.size() == 9, "nine independent paintings supply depth layers and world ground details")
	check(ratios.size() >= 6, "layers have meaningfully distinct parallax depth ratios")
	check(backdrop.foreground_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "foreground root passes pointer input through")
	check(backdrop.foreground_clear_rect().is_equal_approx(field.safe_play_rect()), "foreground shader clears the same rectangle that contains the battle")
	var safe: Rect2 = field.safe_play_rect()
	check(safe.position.y > field.size.y * 0.285 and Rect2(Vector2.ZERO, field.size).encloses(safe), "battle clear area is wholly below the painted horizon")
	var state: Dictionary = gameplay_snapshot(game)
	backdrop.sync_camera(Vector2(16, 10), 0.0)
	var previous: Dictionary = {}
	for node: Control in moving: previous[node.name] = node.position
	backdrop.sync_camera(Vector2(24, 14), 0.2)
	var deltas: Dictionary = {}
	for node: Control in moving:
		var delta: Vector2 = node.position - previous[node.name]
		if delta.length() > 0.001: deltas[str(delta.snapped(Vector2.ONE * 0.001))] = true
	check(deltas.size() >= 4, "camera movement produces at least four different actual layer offsets")
	backdrop.sync_camera(field.focus, 0.0)
	check(gameplay_snapshot(game) == state, "parallax camera and procedural atmosphere consume no gameplay RNG or simulation state")

func ground_detail_atlas(mesh: MeshInstance3D) -> Texture2D:
	var material := mesh.material_override as ShaderMaterial
	if material == null: return null
	return material.get_shader_parameter("detail_atlas") as Texture2D

func test_ground_detail_geometry(field, details: MeshInstance3D) -> void:
	check(details.mesh != null and details.mesh.get_surface_count() > 0, "ground atlas has real world geometry")
	if details.mesh == null or details.mesh.get_surface_count() == 0: return
	var samples := 0
	var tiles: Dictionary = {}
	var flat := true
	var valid_uv := true
	var touches_play_lawn := false
	var projection_error := 0.0
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for surface in details.mesh.get_surface_count():
		var arrays: Array = details.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		check(vertices.size() == uvs.size() and vertices.size() >= 3, "ground atlas maps a UV to every rendered vertex")
		for i in vertices.size():
			var world: Vector3 = details.to_global(vertices[i])
			var point := Vector2(world.x, world.z)
			flat = flat and absf(world.y) < 0.1
			touches_play_lawn = touches_play_lawn or Rect2(0, 0, 32, 20).has_point(point)
			low = low.min(point)
			high = high.max(point)
			projection_error = maxf(projection_error, point.distance_to(field.local_to_world(field.project_world(point))))
			if i < uvs.size(): valid_uv = valid_uv and uvs[i].x >= 0 and uvs[i].y >= 0 and uvs[i].x <= 1 and uvs[i].y <= 1
			samples += 1
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count - 2, 3):
			var centroid := Vector2.ZERO
			for corner in 3:
				var index: int = indices[i + corner] if not indices.is_empty() else i + corner
				centroid += uvs[index] / 3.0
			tiles[Vector2i(mini(2, int(centroid.x * 3)), mini(1, int(centroid.y * 2)))] = true
	check(samples >= 36 and high.distance_to(low) > 5 and touches_play_lawn, "ground details populate the actual world lawn and presentation apron")
	check(flat, "decorative ground patches remain on the floor rather than floating with the camera")
	check(valid_uv and tiles.size() == 6, "all six painted atlas cells are used by actual ground triangles")
	check(projection_error < 0.001, "ground decoration vertices share the actor world projection")

func test_atmosphere_clock(game) -> void:
	var field = game.combat_labels.terrain
	var backdrop = field.backdrop
	var original_process: bool = game.is_processing()
	var original_physics_process: bool = game.is_physics_processing()
	var original_field_process: bool = field.is_processing()
	var original_running: bool = game.combat_running
	var original_suspended: bool = game._application_suspended
	var original_screen: String = game.active_screen
	var original_environment: bool = field.animate_environment
	var original_tree_pause := paused
	field.set_process(false)
	# Main really owns only _physics_process. Exercise that mode rather than
	# accidentally making an otherwise inactive regular loop satisfy the guard.
	game.set_process(false)
	game.set_physics_process(true)
	game.combat_running = true
	game._application_suspended = false
	game.active_screen = "combat"
	field.animate_environment = true
	paused = false
	var state: Dictionary = gameplay_snapshot(game)
	var foreground: Control = backdrop.foreground_root.find_child("ForegroundNear", true, false)
	var light: Control = backdrop.foreground_root.find_child("LightShafts", true, false)
	if light == null: light = backdrop.find_child("LightShafts", true, false)
	var prior_foreground := foreground.position
	var before: float = backdrop.atmosphere_time
	field._process(0.075)
	check(not game.is_processing() and game.is_physics_processing() and is_equal_approx(backdrop.atmosphere_time - before, 0.075), "a physics-only game advances atmosphere exactly once per presentation frame")
	check(foreground.position.distance_to(prior_foreground) > 0.001, "active atmosphere moves the actual foreground presentation")
	check(light != null and light.material is ShaderMaterial and is_equal_approx(float(light.material.get_shader_parameter("art_time")), backdrop.atmosphere_time), "animated light receives the actual local atmosphere clock")
	before = backdrop.atmosphere_time
	game.combat_running = false
	field._process(0.075)
	check(is_equal_approx(backdrop.atmosphere_time, before), "pausing hunting freezes atmosphere")
	game.combat_running = true
	game._application_suspended = true
	field._process(0.075)
	check(is_equal_approx(backdrop.atmosphere_time, before), "application suspension freezes atmosphere")
	game._application_suspended = false
	game.active_screen = "inventory"
	backdrop.sync_camera(field.focus, 0.075)
	check(is_equal_approx(backdrop.atmosphere_time, before), "leaving combat for a menu freezes atmosphere")
	game.active_screen = "combat"
	field.animate_environment = false
	field._process(0.075)
	check(is_equal_approx(backdrop.atmosphere_time, before), "disabling environment animation freezes atmosphere")
	field.animate_environment = true
	paused = true
	field._process(0.075)
	check(is_equal_approx(backdrop.atmosphere_time, before), "scene-tree pause freezes atmosphere")
	paused = false
	game.set_process(false)
	game.set_physics_process(false)
	field._process(0.075)
	check(is_equal_approx(backdrop.atmosphere_time, before), "disabling both game loops freezes the review atmosphere")
	game.set_physics_process(true)
	field._switch_art(false)
	backdrop.sync_camera(field.focus, 0.075)
	check(is_equal_approx(backdrop.atmosphere_time, before), "original-map comparison freezes the hidden atmosphere")
	field._switch_art(true)
	field._process(0.075)
	check(is_equal_approx(backdrop.atmosphere_time - before, 0.075), "returning to the new map resumes the same local clock without resetting it")
	before = backdrop.atmosphere_time
	for delta: float in [-1.0, NAN, INF]: backdrop.sync_camera(field.focus, delta)
	check(is_equal_approx(backdrop.atmosphere_time, before), "invalid or negative presentation deltas cannot corrupt atmosphere time")
	backdrop.sync_camera(field.focus, 4.0)
	check(backdrop.atmosphere_time > before and backdrop.atmosphere_time - before <= 0.10001, "a delayed frame cannot burst the atmosphere clock forward")
	check(gameplay_snapshot(game) == state, "atmosphere run-pause-resume and comparison never consume gameplay RNG or mutate combat")
	game.combat_running = original_running
	game._application_suspended = original_suspended
	game.active_screen = original_screen
	field.animate_environment = original_environment
	game.set_process(original_process)
	game.set_physics_process(original_physics_process)
	field.set_process(original_field_process)
	paused = original_tree_pause

func actor_alignment(game, update: bool) -> Dictionary:
	var field = game.combat_labels.terrain
	if update: field._process(0.1)
	var safe: Rect2 = field.safe_play_rect().grow(0.6)
	var result := {"inside": true, "aligned": true, "samples": 0, "issues": [], "minimum_head_y": INF, "maximum_foot_y": -INF}
	var bodies: Array[Dictionary] = []
	for i in game.deployed_heroes.size():
		var id: String = str(game.deployed_heroes[i].id)
		if int(game.hero_battle_state.get(id, {}).get("hp", 0)) <= 0: continue
		bodies.append({"id": id, "point": game._hero_field_position(id), "sprite": game.hero_map_sprites[i], "hero": true})
	for i in game.enemy_wave.size():
		if int(game.enemy_wave[i].get("hp", 0)) <= 0: continue
		bodies.append({"id": "enemy_" + str(i), "point": game.roaming_hunt.enemy_position(i), "sprite": game.enemy_wave_sprites[i], "hero": false})
	for body: Dictionary in bodies:
		var point: Vector2 = body.point
		var height: float = field._actor_height(body.sprite, body.hero) + 0.6
		var foot: Vector2 = field.project_world(point)
		var head: Vector2 = field.project_world(point, height)
		result.minimum_head_y = minf(result.minimum_head_y, head.y)
		result.maximum_foot_y = maxf(result.maximum_foot_y, foot.y)
		result.samples += 2
		if not safe.has_point(foot) or not safe.has_point(head):
			result.inside = false
			if result.issues.size() < 4: result.issues.append({"id": body.id, "head": head, "foot": foot, "safe": safe})
		var billboard = field.actors.get(body.sprite.get_instance_id())
		if billboard == null:
			result.aligned = false
		else:
			result.aligned = result.aligned and Vector2(billboard.position.x, billboard.position.z).distance_to(point) < 0.001
			result.aligned = result.aligned and body.sprite.position.distance_to(field.position + foot) < 0.001
	return result

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
		var framing: Dictionary = actor_alignment(game, true)
		var all_visible: bool = framing.inside
		var all_aligned: bool = framing.aligned
		var screen_samples: int = framing.samples
		var framing_issues: Array = framing.issues.duplicate(true)
		while game.combat_hunt_cycle == cycle and steps < 1800:
			game._advance_auto_hunt(0.1)
			steps += 1
			if steps <= 10:
				for index in mini(first_positions.size(), game.roaming_hunt.enemy_positions.size()):
					var target: Vector2 = game._hero_field_position("leonhardt")
					approached = approached or game.roaming_hunt.enemy_position(index).distance_to(target) + 0.02 < first_positions[index].distance_to(target)
			maximum_alive = maxi(maximum_alive, game._enemy_wave_alive_count())
			maximum_groups = maxi(maximum_groups, game.invasion.groups.size())
			if steps % 10 == 0:
				framing = actor_alignment(game, true)
				all_visible = all_visible and framing.inside
				all_aligned = all_aligned and framing.aligned
				screen_samples += int(framing.samples)
				if framing_issues.is_empty() and not framing.inside: framing_issues = framing.issues.duplicate(true)
			if steps % 120 == 0: await process_frame
		var remaining_hp := 0
		for enemy: Dictionary in first_wave: remaining_hp += maxi(0, int(enemy.hp))
		check(remaining_hp < initial_hp, entry + " receives real combat HP damage")
		check(game.combat_hunt_cycle > cycle, entry + " naturally clears through the production reward loop")
		check(maximum_alive <= 25 and maximum_groups <= 2, entry + " respects normal invasion admission caps")
		check(approached, entry + " enemies move toward the party before the first clear")
		check(all_visible and screen_samples > 0, entry + " live heroes and enemies remain in the safe ground area throughout combat: " + str(framing_issues))
		check(all_aligned, entry + " moving billboards and combat anchors remain attached to their real world feet")
		var maximum_projection_error := 0.0
		var field = game.combat_labels.terrain
		for x in range(0, 33, 8):
			for y in range(0, 21, 5):
				var point := Vector2(x, y)
				maximum_projection_error = maxf(maximum_projection_error, point.distance_to(field.local_to_world(field.project_world(point))))
		check(maximum_projection_error < 0.001, entry + " camera movement preserves the complete field projection roundtrip")
		direction_results.append({"entrance": entry, "seconds": steps * 0.1,
			"removed_hp": initial_hp - remaining_hp, "initial_hp": initial_hp,
			"clears": game.combat_hunt_cycle - cycle, "maximum_alive": maximum_alive,
			"maximum_groups": maximum_groups, "screen_samples": screen_samples,
			"all_actor_points_inside_safe_area": all_visible, "world_render_alignment": all_aligned,
			"maximum_projection_error": maximum_projection_error})
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
	var result := {"checks": checks, "failures": failures, "directions": direction_results, "startup_runtime": startup_runtime,
		"scope": "Actual independent pilot scene; isolated progression, preferences and raid archive; live production hunt engine"}
	var out := FileAccess.open("user://art-pilot-results.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "  "))
		out.close()
	print("art_direction_pilot checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
