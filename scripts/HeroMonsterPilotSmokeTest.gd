extends "res://scripts/ArtDirectionPilotSmokeTest.gd"
## Actual pilot rendering integration; original combat/source animation assets
## remain the authority for state, position, facing, health and action timing.
const MEADOW_SPECIES := ["초원 고블린", "들개 무리", "가시 멧돼지", "바람 까마귀"]
const MONSTER_POSES := {"idle": [0, 1], "walk": [2, 3], "attack": [4, 5], "hit": [6], "death": [7]}
var presentation_results: Dictionary = {}

func run() -> void:
	if not prepare_sentinels():
		finish()
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var game = load(PILOT_SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	await settle()
	await create_timer(0.35).timeout
	check(bool(game.get_meta("pilot_ready", false)) and game.active_screen == "combat", "actual art pilot starts its production hunt")
	check(game.is_physics_processing() and not game.is_processing(), "presentation boots under the real physics-only game loop")
	var field = game.combat_labels.terrain
	check(field.get_script().resource_path == "res://scripts/art/ArtDirectionBattlefield.gd", "real pilot uses the presentation integration adapter")
	var naturally_animated := 0
	for source in game.enemy_wave_sprites:
		var observed: Dictionary = field.monster_presentation.debug_state(source)
		if float(observed.get("clock", 0.0)) > 0 and bool(observed.get("running", false)): naturally_animated += 1
	check(naturally_animated > 0, "actual physics-only startup drives painted monsters before any test changes processing flags")
	presentation_results["naturally_animated_monsters"] = naturally_animated
	var natural_leon = game.hero_map_sprites[game._deployed_hero_ids().find("leonhardt")]
	var natural_hero: Dictionary = field.hero_presentation.snapshot(field.actors[natural_leon.get_instance_id()])
	check(float(natural_hero.get("clock", 0)) > 0 and bool(natural_hero.get("active", false)), "actual physics-only startup drives Leonhardt presentation before artificial flags")
	presentation_results["natural_hero_clock"] = natural_hero.get("clock", 0.0)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound_effects_enabled = false
	game.combat_effects_enabled = false
	game.presentation_runtime.audio.shutdown()
	field.set_process(false)
	for source in game.hero_map_sprites:
		source.set_process(false)
		source.observe_game = false
		source.hold_demo = true
		source.get_node("PortraitHeroSkeletalRig").set_process(false)
	for source in game.enemy_wave_sprites: source.set_process(false)
	await test_monster_rendering(game, field)
	await test_hero_rendering(game, field)
	check_sentinels("hero and monster presentation tests")
	game.set_process(false)
	game.set_physics_process(false)
	game.presentation_runtime.audio.shutdown()
	await create_timer(0.35).timeout
	current_scene = null
	game.free()
	await create_timer(0.35).timeout
	check_sentinels("hero and monster presentation shutdown")
	finish()

func test_monster_rendering(game, field) -> void:
	var adapter = field.monster_presentation
	var catalog: Dictionary = adapter.catalog()
	check(catalog.size() == 4, "pilot catalog covers exactly the four actual meadow species")
	var bodies: Dictionary = {}
	for source in game.enemy_wave_sprites:
		if not bodies.has(source.pixel_monster_name): bodies[source.pixel_monster_name] = source
	var gameplay: Dictionary = gameplay_snapshot(game)
	# Enable the actual production loop flag, without yielding or executing
	# gameplay steps while rendering presentation-only fixtures below.
	game.set_physics_process(true)
	var pose_observations: Dictionary = {}
	for species: String in MEADOW_SPECIES:
		check(bodies.has(species) and adapter.supports(species), "live generated wave uses supported painted species " + species)
		if not bodies.has(species) or not adapter.supports(species): continue
		var source: MonsterSpriteController = bodies[species]
		var entry: Dictionary = catalog.get(species, {})
		check(bool(entry.get("available", false)) and int(entry.get("pose_count", 0)) == 8, species + " has eight available painted poses")
		var regions: Dictionary = {}
		var sheet_image: Image
		var expected_regions: Array = entry.frame_regions
		for pose in 8:
			var frame: AtlasTexture = adapter.frame_texture(species, pose)
			check(frame != null and frame.atlas != null, species + " pose " + str(pose) + " has imported art")
			if frame == null or frame.atlas == null: continue
			if sheet_image == null: sheet_image = frame.atlas.get_image()
			check(Rect2(Vector2.ZERO, frame.atlas.get_size()).encloses(frame.region) and frame.region == expected_regions[pose], species + " pose cell stays within its sheet")
			check(frame.filter_clip, species + " pose cell clips filtering at its own border")
			check(sheet_image != null and sheet_image.get_region(Rect2i(frame.region)).get_used_rect().has_area(), species + " pose contains visible pixels")
			check(adapter.frame_texture(species, pose) == frame, species + " cached pose resource is reused")
			regions[str(frame.region)] = true
		check(regions.size() == 8, species + " paints eight distinct atlas cells")
		var observed_poses: Dictionary = {}
		for action: String in MONSTER_POSES:
			source.stop()
			source.play_state(action, "right")
			source.speed_scale = 1.0
			var source_before := controller_snapshot(source)
			field._process(0.0)
			var base_pixel_size: float = field.actors[source.get_instance_id()].pixel_size
			for sample in 9:
				if action == "attack":
					var count: int = source.sprite_frames.get_frame_count(source.animation)
					source.set_frame_and_progress(0 if sample < 4 else count - 1, 0.0 if sample < 4 else 0.99)
					source_before = controller_snapshot(source)
				field._process(0.1)
				var state: Dictionary = adapter.debug_state(source)
				var rendered: Sprite3D = field.actors[source.get_instance_id()]
				check(str(state.get("state", "")) == action and int(state.get("pose", -1)) in MONSTER_POSES[action], species + " source " + action + " selects an appropriate painted pose")
				check(rendered.texture == adapter.frame_texture(species, int(state.pose)), species + " selected pose reaches the actual Sprite3D")
				check(controller_snapshot(source) == source_before, species + " presentation never rewrites source controller state or frame timing")
				check(is_equal_approx(rendered.pixel_size, base_pixel_size), species + " pose changes do not rescale its body")
				check(atlas_anchor_error(rendered, state) < 0.001, species + " pose foot anchor stays at the same world root")
				observed_poses[int(state.pose)] = true
		check(observed_poses.size() == 8, species + " real source states exercise all eight visible poses")
		pose_observations[species] = observed_poses.keys()
		# Face, flash and death opacity remain the source controller's decisions.
		source.stop(); source.play_state("walk", "left")
		source.modulate = Color(.7, .8, .9, .64)
		source.self_modulate = Color(1.0, .55, .4, 0.0)
		field._process(0.1)
		var rendered: Sprite3D = field.actors[source.get_instance_id()]
		var state: Dictionary = adapter.debug_state(source)
		check(rendered.flip_h and atlas_anchor_error(rendered, state) < 0.001, species + " facing mirrors artwork without sliding its asymmetric foot anchor")
		check(rendered.modulate.is_equal_approx(source.modulate * Color(1, .55, .4, 1)), species + " painted art retains hit tint and source opacity")
		source.stop(); source.play_state("death", "left"); source._process(0.25)
		field._process(0.1)
		rendered = field.actors[source.get_instance_id()]
		check(int(adapter.debug_state(source).pose) == 7 and is_equal_approx(rendered.modulate.a, source.modulate.a) and rendered.modulate.a < 1, species + " death pose follows the real controller fade")
		# Pausing reapplies the same painted resource after base sync has run.
		source.stop(); source.play_state("walk", "right"); source.speed_scale = 1
		field._process(0.1)
		var frozen: Dictionary = adapter.debug_state(source)
		var frozen_texture: Texture2D = field.actors[source.get_instance_id()].texture
		game.combat_running = false
		field._process(0.1)
		state = adapter.debug_state(source)
		check(is_equal_approx(state.clock, frozen.clock) and int(state.pose) == int(frozen.pose) and field.actors[source.get_instance_id()].texture == frozen_texture, species + " paused hunt retains the painted frame instead of reverting to old art")
		game.combat_running = true; source.speed_scale = 0
		field._process(0.1)
		check(is_equal_approx(adapter.debug_state(source).clock, frozen.clock), species + " individual source speed zero freezes its painted clock")
		source.speed_scale = 1
		field._process(.1)
		var scenery_clock: float = field.backdrop.atmosphere_time
		var actor_clock: float = adapter.debug_state(source).clock
		field.animate_environment = false
		field._process(.1)
		check(adapter.debug_state(source).clock > actor_clock and is_equal_approx(field.backdrop.atmosphere_time, scenery_clock), species + " disabling scenery animation keeps combatant animation running")
		field.animate_environment = true
		source.modulate = Color.WHITE; source.self_modulate = Color.WHITE
		source.stop(); source.play_state("idle", "right")
	check(adapter.cached_frame_count() == 32, "all four eight-pose sheets use a bounded cache of 32 frame resources")
	check(gameplay_snapshot(game) == gameplay, "source-state rendering fixtures preserve combat state, rewards, coordinates and gameplay RNG")
	presentation_results["monster_poses"] = pose_observations
	game.set_physics_process(false)
	await test_species_fallback(game, field)

func atlas_anchor_error(rendered: Sprite3D, state: Dictionary) -> float:
	var cell: Vector2 = state.cell
	var anchor: Vector2 = state.baseline
	var sampled_x: float = cell.x - anchor.x if rendered.flip_h else anchor.x
	return Vector2(sampled_x - cell.x * .5 + rendered.offset.x, cell.y * .5 - anchor.y + rendered.offset.y).length()

func test_species_fallback(game, field) -> void:
	var source := MonsterSpriteFactory.create_monster("광산 오크")
	MonsterSpriteFactory.apply_casual(source, "광산 오크", source.presentation_scale)
	root.add_child(source)
	await settle()
	source.set_process(false)
	var before := controller_snapshot(source)
	var original: Texture2D = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	var state: Dictionary = gameplay_snapshot(game)
	field.sync_actor(source, Vector2(16, 10), false, {})
	var rendered: Sprite3D = field.actors[source.get_instance_id()]
	check(not field.monster_presentation.supports("광산 오크") and field.monster_presentation.debug_state(source).is_empty(), "unsupported mine species uses an explicit untouched fallback")
	check(rendered.texture == original and controller_snapshot(source) == before, "unsupported species retains original art, pose and source data")
	check(gameplay_snapshot(game) == state, "unsupported species fallback changes no combat or economy state")
	rendered.free(); field.actors.erase(source.get_instance_id()); source.free()

func test_hero_rendering(game, field) -> void:
	var source = game.hero_map_sprites[game._deployed_hero_ids().find("leonhardt")]
	var rig = source.get_node("PortraitHeroSkeletalRig")
	var adapter = field.hero_presentation
	var director = game.party_movement
	var positions: Dictionary = director.positions.duplicate(true)
	var distances: Dictionary = director.distance_walked.duplicate(true)
	var velocities: Dictionary = director.velocities.duplicate(true)
	var gameplay: Dictionary = gameplay_snapshot(game)
	game.set_physics_process(true)
	source.speed_scale = 1
	source.play_visual("idle")
	rig._process(.2)
	director.velocities["leonhardt"] = Vector2.ZERO
	field._process(.1)
	var rendered: Sprite3D = field.actors[source.get_instance_id()]
	var skin = rendered.get_node("HeroSkeletalBillboard")
	check(skin.material_override is ShaderMaterial and skin.material_override.shader.resource_path.ends_with("hero-contour.gdshader"), "Leonhardt actual GPU mesh uses the pilot contour material")
	var material: ShaderMaterial = skin.material_override
	check(material.get_shader_parameter("source_texture") == rig.rest_frame.atlas, "hero contour samples the existing bind-pose artwork without substituting an invented multipart hero")
	var atlas: Vector4 = material.get_shader_parameter("atlas_rect")
	var tex_size: Vector2 = rig.rest_frame.atlas.get_size()
	var expected := Vector4(rig.rest_frame.region.position.x / tex_size.x, rig.rest_frame.region.position.y / tex_size.y, rig.rest_frame.region.size.x / tex_size.x, rig.rest_frame.region.size.y / tex_size.y)
	check(atlas == expected and atlas.x >= 0 and atlas.y >= 0 and atlas.x + atlas.z <= 1 and atlas.y + atlas.w <= 1, "hero outline is constrained to its actual atlas region")
	var source_before := hero_source_snapshot(source, rig)
	var skeleton_before := gpu_pose(skin.bones_3d)
	var before: Dictionary = adapter.snapshot(rendered)
	for i in 12: field._process(.1)
	var after: Dictionary = adapter.snapshot(rendered)
	check(after.clock > before.clock and after.breath_phase != before.breath_phase, "stationary hero breath advances through the field's actual render integration")
	check(gpu_pose(skin.bones_3d) != skeleton_before, "breathing changes actual GPU bone poses with the source skeleton held fixed")
	check(hero_source_snapshot(source, rig) == source_before, "GPU breathing preserves source animation timing, sequence, bones and motion pose")
	check(absf(after.hair_angle) <= .07 and absf(after.cape_angle) <= .095, "secondary hair and cape movement remains bounded")
	# A camera move changes projected pixels but must never create a footstep.
	source.play_visual("walk")
	rig._process(.2)
	director.velocities["leonhardt"] = Vector2(1, 0)
	field._process(.1)
	before = adapter.snapshot(rendered)
	var camera_focus: Vector2 = field.focus
	field._set_focus(camera_focus + Vector2(1, 0))
	field._process(.1)
	after = adapter.snapshot(rendered)
	check(is_equal_approx(after.gait_phase, before.gait_phase) and is_zero_approx(after.distance_delta), "camera motion alone never drives hero gait")
	field._set_focus(camera_focus)
	var actual_delta := .35
	director.positions["leonhardt"] += Vector2(actual_delta, 0)
	director.distance_walked["leonhardt"] += actual_delta
	var fixture_state: Dictionary = gameplay_snapshot(game)
	source_before = hero_source_snapshot(source, rig)
	field._process(.1)
	after = adapter.snapshot(rendered)
	check(after.distance_source == "party_movement.distance_walked" and is_equal_approx(after.distance_delta, actual_delta), "hero presentation reads real director distance instead of frame count")
	check(is_equal_approx(fposmod(after.gait_phase - before.gait_phase, TAU), TAU * .25), "a real quarter-stride distance produces a quarter gait cycle")
	check(hero_source_snapshot(source, rig) == source_before and gameplay_snapshot(game) == fixture_state, "walking polish changes neither source rig nor actual gameplay positions and state")
	var phase: float = after.gait_phase
	director.distance_walked["leonhardt"] += 5.0
	field._process(.1)
	check(is_equal_approx(adapter.snapshot(rendered).gait_phase, phase), "teleport-sized cumulative-distance discontinuity cannot launch a false step")
	director.distance_walked["leonhardt"] -= 5.0
	field._process(.1)
	check(is_equal_approx(adapter.snapshot(rendered).gait_phase, phase), "distance reset is treated as a new baseline")
	# Pause and individual speed zero freeze only the new simulation, not claims
	# about production animations that run independently of this helper.
	before = adapter.snapshot(rendered)
	game.combat_running = false
	director.distance_walked["leonhardt"] += .3
	field._process(.1)
	after = adapter.snapshot(rendered)
	check(hero_clock_state(after) == hero_clock_state(before), "paused hunt freezes added breathing, gait and secondary spring clocks")
	game.combat_running = true
	field._process(.1)
	check(is_equal_approx(adapter.snapshot(rendered).gait_phase, phase), "resume cannot catch up steps accumulated while presentation was paused")
	before = adapter.snapshot(rendered)
	source.speed_scale = 0
	field._process(.1)
	check(hero_clock_state(adapter.snapshot(rendered)) == hero_clock_state(before), "individual hero animation freeze also freezes added presentation")
	source.speed_scale = 1
	# Authored combat poses retain their limb timings under the added contour.
	for action: String in ["attack_1", "attack_2", "skill", "ultimate", "hit", "knockback", "dodge", "guard", "buff", "debuff", "victory", "spawn", "death"]:
		source.play_visual(action)
		rig._process(.2)
		source_before = hero_source_snapshot(source, rig)
		before = adapter.snapshot(rendered)
		field._process(.1)
		check(hero_source_snapshot(source, rig) == source_before, "pilot never replaces source action " + action)
		check(gpu_limb_pose_matches_source(skin.bones_3d, rig, action == "death"), "authored GPU limb pose is preserved for " + action)
		if action == "death":
			check(not adapter.snapshot(rendered).alive and is_equal_approx(adapter.snapshot(rendered).clock, before.clock), "death stops added motion and preserves the full original death pose")
	source.play_visual("hit")
	source.flip_h = true
	source.modulate = Color(.8, .7, .6, .4)
	source.self_modulate = Color(.7, 1, .9, 0)
	field._process(.1)
	check(skin.basis.determinant() < 0 and is_equal_approx(material.get_shader_parameter("facing_sign"), -1), "hero facing mirrors the real skeleton and reverses the contour rim")
	check((material.get_shader_parameter("actor_tint") as Color).is_equal_approx(rendered.modulate) and is_equal_approx(rendered.modulate.a, .4), "hero contour material preserves hit color and death opacity")
	for other in game.hero_map_sprites:
		if other == source: continue
		var other_rendered: Sprite3D = field.actors[other.get_instance_id()]
		var other_skin = other_rendered.get_node("HeroSkeletalBillboard")
		check(adapter.snapshot(other_rendered).is_empty() and other_skin.material_override is StandardMaterial3D, "non-pilot hero " + str(other.atlas_key) + " keeps original material and motion")
	source.modulate = Color.WHITE
	source.self_modulate = Color.WHITE
	source.flip_h = false
	source.play_visual("walk")
	rig._process(.2)
	test_ground_contact(game, field, source)
	director.positions = positions
	director.distance_walked = distances
	director.velocities = velocities
	source.play_visual("idle")
	rig._process(.2)
	field._process(0)
	check(gameplay_snapshot(game) == gameplay and director.distance_walked == distances and director.velocities == velocities, "all hero rendering fixtures restore movement and preserve gameplay RNG, combat and economy")
	game.set_physics_process(false)
	var original_state: Dictionary = gameplay_snapshot(game)
	field._switch_art(false)
	field._process(0)
	rendered = field.actors[source.get_instance_id()]
	check(rendered.get_node("HeroSkeletalBillboard").material_override is StandardMaterial3D, "original-map comparison rebuilds the original hero material")
	for monster in game.enemy_wave_sprites:
		var original_texture: Texture2D = monster.sprite_frames.get_frame_texture(monster.animation, monster.frame)
		check(field.actors[monster.get_instance_id()].texture == original_texture, "original-map comparison restores source monster artwork")
	field._switch_art(true)
	field._process(0)
	rendered = field.actors[source.get_instance_id()]
	check(rendered.get_node("HeroSkeletalBillboard").material_override is ShaderMaterial and field.hero_presentation.snapshot(rendered).clock == 0, "returning to the pilot recreates a clean hero presentation state")
	check(gameplay_snapshot(game) == original_state, "presentation comparison and return leave the live encounter unchanged")
	presentation_results["hero_gpu_bones"] = rig.bone_names.size()
	presentation_results["ground_contact"] = field.ground_contact.debug_state()

func test_ground_contact(game, field, source) -> void:
	var point: Vector2 = game.party_movement.positions["leonhardt"]
	field._process(0)
	var rendered: Sprite3D = field.actors[source.get_instance_id()]
	var shadow: MeshInstance3D = rendered.get_node("ContactShadow")
	check(shadow.mesh is PlaneMesh and shadow.material_override is ShaderMaterial and shadow.get_meta("pilot_ground_contact", false), "hero contact shadow is an actual transparent floor plane")
	check(shadow.global_position.distance_to(Vector3(point.x, -.008, point.y)) < .00001, "contact shadow is fixed to world ground beneath the actor")
	var before: Dictionary = field.ground_contact.debug_state()
	for i in 48:
		var movement := Vector2(.4 if i % 4 < 2 else -.4, 0)
		game.party_movement.positions["leonhardt"] += movement
		game.party_movement.distance_walked["leonhardt"] += movement.length()
		field._process(0)
	var filled: Dictionary = field.ground_contact.debug_state()
	check(filled.emitted > before.emitted and filled.dust_count > 0 and filled.dust_count <= filled.dust_cap and filled.dust_cap == 16, "actual world footsteps emit dust into a bounded pool of sixteen")
	check(is_equal_approx(shadow.global_position.y, -.008), "walking body motion never lifts its floor contact patch")
	game.combat_running = false
	field._process(.1)
	check(field.ground_contact.debug_state() == filled, "pausing freezes the existing dust pool and stops emission")
	game.combat_running = true
	source.play_visual("idle")
	for i in 5: field._process(.1)
	check(field.ground_contact.debug_state().dust_count == 0, "dust particles expire after their lifetime without permanent scene accumulation")
	presentation_results["dust_peak"] = filled.dust_count

func hero_clock_state(state: Dictionary) -> Array:
	return [state.clock, state.breath_phase, state.gait_phase, state.hair_angle, state.cape_angle]

func hero_source_snapshot(source, rig) -> Dictionary:
	var result := controller_snapshot(source)
	result.visual_action = source.visual_action
	result.visual_sequence = source.visual_sequence
	result.motion_pose = rig.pose.duplicate(true)
	var transforms: Array[Transform2D] = []
	for key in rig.bone_names: transforms.append(rig.bones[key].transform)
	result.bones = transforms
	return result

func gpu_pose(skeleton: Skeleton3D) -> Array:
	var result: Array = []
	for i in skeleton.get_bone_count(): result.append(skeleton.get_bone_pose(i))
	return result

func gpu_limb_pose_matches_source(skeleton: Skeleton3D, rig, include_secondary: bool) -> bool:
	for i in rig.bone_names.size():
		var key: String = rig.bone_names[i]
		if not include_secondary and key in ["Hair", "Cape"]: continue
		var bone: Bone2D = rig.bones[key]
		if not skeleton.get_bone_pose_position(i).is_equal_approx(Vector3(bone.position.x, -bone.position.y, 0)): return false
		if not skeleton.get_bone_pose_rotation(i).is_equal_approx(Quaternion(Vector3.BACK, -bone.rotation)): return false
	return true

func controller_snapshot(source: AnimatedSprite2D) -> Dictionary:
	return {"state": source.state, "animation": source.animation, "frame": source.frame,
		"frame_progress": source.frame_progress, "frames_resource": source.sprite_frames.get_instance_id(),
		"offset": source.offset, "scale": source.scale,
		"speed_scale": source.speed_scale, "flip_h": source.flip_h,
		"modulate": source.modulate, "native_height": source.native_visual_height}

func finish() -> void:
	var result := {"checks": checks, "failures": failures, "presentation": presentation_results,
		"scope": "Actual pilot hero/monster rendering integration; headless state, resource and geometry validation, not GPU visual quality"}
	var out := FileAccess.open("user://hero-monster-pilot-results.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "  "))
		out.close()
	print("hero_monster_pilot checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
