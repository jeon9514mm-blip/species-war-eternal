extends "res://scripts/ArtDirectionPilotSmokeTest.gd"
## Headless resource, multipart geometry and unchanged-controller integration.
## Final painted composition and motion readability require the separate GPU review.
const PARTS_CATALOG_PATH := "res://scripts/art/HeroPartsCatalog.gd"
const PARTS_RIG_PATH := "res://scripts/art/HeroPartsRig3D.gd"
const PARTS_ROOT := "res://assets/art-direction/aurelia-4head/"
const PARTS_ACTIONS := ["idle", "walk", "run", "attack_1", "attack_2", "skill", "ultimate", "hit", "knockback", "dodge", "guard", "buff", "debuff", "victory", "death", "spawn"]
const CONTINUOUS_ACTIONS := ["idle", "walk", "run", "debuff"]
const CORE_COMPONENTS := ["head", "hair_back", "chest", "left_upper_arm", "left_forearm", "left_hand", "right_upper_arm", "right_forearm", "right_hand", "left_thigh", "left_shin", "left_foot", "right_thigh", "right_shin", "right_foot", "weapon"]
var parts_results: Dictionary = {}
var parts_catalog
var parts_rig_script
var requested_ids: Array[String] = []

func run() -> void:
	if not prepare_sentinels():
		finish()
		return
	check(ResourceLoader.exists(PARTS_CATALOG_PATH) and ResourceLoader.exists(PARTS_RIG_PATH), "multipart catalog and renderer exist")
	if not ResourceLoader.exists(PARTS_CATALOG_PATH) or not ResourceLoader.exists(PARTS_RIG_PATH):
		finish()
		return
	parts_catalog = load(PARTS_CATALOG_PATH)
	parts_rig_script = load(PARTS_RIG_PATH)
	var roster: Array[String] = []
	for id: String in HeroRosterCatalog.HEROES:
		if HeroRosterCatalog.HEROES[id].faction == "aurelia": roster.append(id)
	check(roster.size() == 15, "test obtains all fifteen existing Aurelia identities from the production roster")
	var filter := OS.get_environment("AURELIA_PARTS_TEST_IDS")
	if not filter.is_empty():
		for id in filter.split(",", false):
			check(id in roster, "requested development fixture is a real Aurelia hero: " + id)
			if id in roster: requested_ids.append(id)
	var selected: Array[String] = roster if requested_ids.is_empty() else requested_ids
	var definitions := validate_parts_resources(roster, selected)
	if definitions.size() != selected.size():
		finish()
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var game = load(PILOT_SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	await settle()
	await create_timer(.35).timeout
	check(bool(game.get_meta("pilot_ready", false)) and game.active_screen == "combat", "production hunt starts in the disposable art study")
	check(game.is_physics_processing() and not game.is_processing(), "multipart study starts under the unchanged physics-only simulation loop")
	game.set_process(false)
	game.set_physics_process(false)
	game.sound_effects_enabled = false
	game.combat_effects_enabled = false
	game.presentation_runtime.audio.shutdown()
	var field = game.combat_labels.terrain
	field.set_process(false)
	for source in game.hero_map_sprites:
		source.set_process(false)
		source.observe_game = false
		source.hold_demo = true
		source.get_node("PortraitHeroSkeletalRig").set_process(false)
	for source in game.enemy_wave_sprites: source.set_process(false)
	var before: Dictionary = gameplay_snapshot(game)
	await test_multipart_heroes(game, field, definitions)
	test_field_gate(game, field, definitions)
	await test_parts_gallery(definitions)
	check(gameplay_snapshot(game) == before, "all fifteen multipart fixtures preserve live combat, positions, economy and gameplay RNG")
	check_sentinels("multipart resources and sixteen actions")
	if requested_ids.is_empty(): await test_directions(game)
	check_sentinels("multipart eight-direction real combat")
	game.set_process(false)
	game.set_physics_process(false)
	game.presentation_runtime.audio.shutdown()
	await create_timer(.35).timeout
	current_scene = null
	game.free()
	await create_timer(.35).timeout
	check_sentinels("multipart study shutdown")
	finish()

func validate_parts_resources(roster: Array[String], selected: Array[String]) -> Dictionary:
	var definitions: Dictionary = {}
	var registered: Array = parts_catalog.HERO_IDS.duplicate()
	registered.sort()
	var expected := roster.duplicate()
	expected.sort()
	check(registered == expected, "multipart registry matches exactly the fifteen existing Aurelia hero IDs")
	var concept_hashes: Dictionary = {}
	var parts_hashes: Dictionary = {}
	for id: String in selected:
		var definition: Dictionary = parts_catalog.load_definition(id, true)
		var pending_issues: Array = []
		if definition.is_empty() and FileAccess.file_exists(PARTS_ROOT + id + "/parts.json"):
			var raw = JSON.parse_string(FileAccess.get_file_as_string(PARTS_ROOT + id + "/parts.json"))
			if raw is Dictionary: pending_issues = parts_catalog.validate_definition(raw, true).get("issues", [])
		check(not definition.is_empty(), id + " has its own multipart definition: " + str(pending_issues))
		if definition.is_empty(): continue
		var validation: Dictionary = parts_catalog.validate_definition(definition, true)
		var reviewed := bool(definition.get("reviewed", false)) and bool(definition.get("component_integrity_verified", false))
		check(parts_catalog.has_ready_parts(id) == reviewed, id + " default gameplay gate follows completed assembled-art review")
		check(bool(validation.get("valid", false)), id + " definition validates: " + str(validation.get("issues", [])))
		if not bool(validation.get("valid", false)): continue
		var concept_path := PARTS_ROOT + id + "/concept.png"
		var parts_path := PARTS_ROOT + id + "/parts.png"
		check(ResourceLoader.exists(concept_path) and ResourceLoader.exists(parts_path), id + " owns imported concept and independent-part artwork")
		if not ResourceLoader.exists(concept_path) or not ResourceLoader.exists(parts_path): continue
		concept_hashes[FileAccess.get_sha256(concept_path)] = true
		parts_hashes[FileAccess.get_sha256(parts_path)] = true
		var texture := load(parts_path) as Texture2D
		var art: Image = texture.get_image()
		check(art != null and art.detect_alpha() != Image.ALPHA_NONE, id + " multipart atlas preserves transparent gaps")
		check(int(validation.get("part_count", 0)) >= CORE_COMPONENTS.size(), id + " contains many independent painted body and equipment pieces")
		var region_keys: Dictionary = {}
		for part: Dictionary in definition.get("parts", []):
			var raw: Array = part.get("region", [])
			check(raw.size() == 4, id + " painted part has a rectangular atlas region")
			if raw.size() != 4: continue
			var region := Rect2i(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]))
			check(Rect2i(Vector2i.ZERO, art.get_size()).encloses(region) and region.has_area(), id + " part " + str(part.id) + " stays inside its atlas")
			if not Rect2i(Vector2i.ZERO, art.get_size()).encloses(region) or not region.has_area(): continue
			check(art.get_region(region).get_used_rect().has_area(), id + " part " + str(part.id) + " contains actual painted pixels")
			region_keys[str(region)] = true
		check(region_keys.size() >= CORE_COMPONENTS.size(), id + " paints at least sixteen different anatomical component regions instead of reusing a whole character")
		var present: Array = []
		for part: Dictionary in definition.parts: present.append(str(part.id))
		for required: String in CORE_COMPONENTS: check(required in present, id + " retains independently articulated component " + required)
		if bool(parts_catalog.profile(id).offhand_required): check("offhand" in present, id + " retains its identity's separate shield or second weapon")
		test_joint_rest_contract(id, definition)
		definitions[id] = definition
	check(concept_hashes.size() == selected.size(), "each selected hero concept is a distinct image")
	check(parts_hashes.size() == selected.size(), "each selected multipart atlas is a distinct image")
	return definitions

func test_joint_rest_contract(id: String, definition: Dictionary) -> void:
	# Metadata-only fixtures test new proportions safely. They neither replace
	# artwork nor claim that cropping an old atlas creates the new approved art.
	var long_leg_rest := {
		"Pelvis": [0.0, -.52], "Torso": [0.0, -.61], "Chest": [0.0, -.735], "Head": [0.0, -.825],
		"Hair": [0.0, -.96], "Cape": [0.0, -.755],
		"LeftUpperArm": [.12, -.74], "RightUpperArm": [-.12, -.74],
		"LeftForearm": [.165, -.56], "RightForearm": [-.165, -.56],
		"LeftHand": [.18, -.385], "RightHand": [-.18, -.385],
		"LeftThigh": [.075, -.51], "RightThigh": [-.075, -.51],
		"LeftShin": [.08, -.28], "RightShin": [-.08, -.28],
		"LeftFoot": [.08, -.055], "RightFoot": [-.08, -.055],
	}
	var fixture: Dictionary = definition.duplicate(true)
	fixture.joint_rest = long_leg_rest
	var baseline := JSON.stringify(fixture)
	check(bool(parts_catalog.validate_definition(fixture, true).valid), id + " accepts a bounded longer-leg rest skeleton without changing parent anatomy")
	check(JSON.stringify(fixture) == baseline, id + " rest validation does not mutate the authored definition")
	var rest: Dictionary = parts_catalog.joint_positions(id, fixture)
	check(rest.LeftThigh.position.y < parts_catalog.joint_positions(id).LeftThigh.position.y and is_equal_approx(rest.LeftFoot.position.y, -.055), id + " longer legs raise the hip while retaining the foot reference")
	check(rest.Root.position == Vector2.ZERO and rest.LeftShin.parent == "LeftThigh" and rest.RightShin.parent == "RightThigh", id + " custom proportions keep the fixed world foot and leg hierarchy")
	check(rest.Weapon.position == rest[str(rest.Weapon.parent)].position and rest.Offhand.position == rest[str(rest.Offhand.parent)].position, id + " both held objects inherit the overridden wrist rest positions")
	for hand: String in ["left", "right"]:
		fixture.weapon_hand = hand
		rest = parts_catalog.joint_positions(id, fixture)
		var expected := "LeftHand" if hand == "left" else "RightHand"
		check(rest.Weapon.parent == expected and rest.Weapon.position == rest[expected].position, id + " anatomical " + hand + " weapon follows that actual wrist")
	var invalid := {
		"nonfinite": {"Head": [NAN, -.8]},
		"outside body": {"Head": [0.0, -9.0]},
		"moved foot origin": {"Root": [.1, 0.0]},
		"unknown joint": {"InventedJoint": [0.0, -.4]},
		"derived weapon override": {"Weapon": [0.0, -.4]},
		"reversed knee": {"LeftShin": [.08, -.8]},
		"zero forearm": {"LeftForearm": [.18, -.365], "LeftHand": [.18, -.365]},
		"parent injection": {"LeftShin": {"parent": "Head", "position": [.08, -.28]}},
	}
	for label: String in invalid:
		var bad: Dictionary = definition.duplicate(true)
		bad.joint_rest = invalid[label]
		check(not bool(parts_catalog.validate_definition(bad, true).valid), id + " rejects unsafe rest geometry: " + label)
	# A joined chest/waist drawing is a supported part design; it remains an
	# independent body component, while every limb and weapon stays separate.
	var unified: Dictionary = definition.duplicate(true)
	for part: Dictionary in unified.parts:
		if part.id == "chest":
			part.id = "core"
			part.bone = "Torso"
	var normalized: Dictionary = parts_catalog.normalize_definition(unified)
	check(bool(parts_catalog.validate_definition(unified, true).valid), id + " accepts a continuous painted body core without demanding extra cosmetic cuts")
	var canonical_core := false
	for part: Dictionary in normalized.parts:
		if part.id == "chest" and part.get("source_part_id", "") == "core": canonical_core = true
	check(canonical_core, id + " normalizes the core name while retaining source-art provenance")

func test_multipart_heroes(game, field, definitions: Dictionary) -> void:
	var sources: Dictionary = {}
	for id: String in definitions:
		var source := HeroSpriteFactory.create_hero(id)
		source.observe_game = false
		source.hold_demo = true
		root.add_child(source)
		sources[id] = source
	await settle()
	var attack_signatures: Dictionary = {}
	for id: String in sources:
		var source: AnimatedSprite2D = sources[id]
		source.set_process(false)
		var rig = parts_rig_script.new()
		field.world.add_child(rig)
		var bound: bool = rig.bind(source, definitions[id], true)
		check(bound, id + " binds its own painted parts to the actual production animation controller")
		if not bound:
			rig.free()
			source.free()
			continue
		check(rig.joints.size() >= 21 and rig.parts.size() >= CORE_COMPONENTS.size(), id + " creates independent articulated joints and many separate drawable parts")
		var actual_parts := 0
		var body_parents: Dictionary = {}
		for part_id in rig.parts:
			var part = rig.parts[part_id]
			check(part is MeshInstance3D and part.mesh != null and part.material_override != null, id + " component " + str(part_id) + " is an independent drawable mesh")
			if part is MeshInstance3D:
				actual_parts += 1
				body_parents[part.get_parent().get_instance_id()] = true
		check(actual_parts == rig.parts.size() and body_parents.size() >= 10, id + " separates body components across real joint parents")
		test_mesh_regions(id, rig, definitions[id])
		var weapon = rig.joints.get("Weapon")
		check(weapon != null and weapon.get_parent() in [rig.joints.get("LeftHand"), rig.joints.get("RightHand")], id + " weapon joint is attached to the actual wrist")
		var samples := 0
		var action_results: Dictionary = {}
		var attack_pose_signature: Array = []
		var distance := 0.0
		for action: String in PARTS_ACTIONS:
			check(source.play_visual(action), id + " production controller supports " + action)
			var seen: Dictionary = {}
			for progress: float in [0.0, .20, .40, .70, .98]:
				set_source_progress(source, progress)
				var source_before := source_timing_snapshot(source)
				var gameplay_before: Dictionary = gameplay_snapshot(game)
				distance += .14
				rig.sync(field.camera, 2.25, Color.WHITE, .07, true, Vector2(1, 0), distance)
				var state: Dictionary = rig.debug_snapshot()
				check(state.get("source_action", "") == action, id + " rendered parts follow source action " + action)
				if action not in CONTINUOUS_ACTIONS:
					check(is_equal_approx(float(state.get("action_time", -1)), weighted_source_time(source)), id + " " + action + " uses the original weighted frame timing")
				check(source_timing_snapshot(source) == source_before and gameplay_snapshot(game) == gameplay_before, id + " " + action + " renderer preserves source and gameplay state")
				check(parts_pose_is_finite(rig), id + " " + action + " produces finite independent mesh transforms")
				var pose := joint_transforms(rig)
				seen[str(pose)] = true
				if action == "attack_1": attack_pose_signature.append(pose)
				samples += 1
			check(seen.size() > 1, id + " " + action + " changes an articulated pose across its timeline")
			action_results[action] = seen.size()
		attack_signatures[str(attack_pose_signature)] = id
		test_neutral_rest(id, source, rig, field, definitions[id])
		test_parts_wrist_follow(id, rig)
		test_equipment_grip_offsets(id, source, field, definitions[id])
		test_attack_draw_order(id, source, rig, field, definitions[id])
		var attack_ergonomics := test_attack_ergonomics(id, source, rig, field)
		test_equipment_wrists(id, source, rig, field)
		test_parts_pause_and_mirror(id, source, rig, field, distance)
		parts_results[id] = {"parts": rig.parts.size(), "joints": rig.joints.size(), "states": action_results, "pose_samples": samples,
			"reviewed": bool(definitions[id].get("reviewed", false)), "component_integrity_verified": bool(definitions[id].get("component_integrity_verified", false)), "attack_ergonomics": attack_ergonomics}
		rig.free()
		source.free()
	check(attack_signatures.size() == definitions.size(), "each hero's actual articulated attack signature is distinct")

func test_field_gate(game, field, definitions: Dictionary) -> void:
	var cached_before: Dictionary = field.hero_parts_definitions.duplicate(true)
	var before: Dictionary = gameplay_snapshot(game)
	for source in game.hero_map_sprites:
		var id: String = source.atlas_key
		if not definitions.has(id): continue
		var point: Vector2 = game._hero_field_position(id)
		field.sync_actor(source, point, true, {})
		var rendered: Sprite3D = field.actors[source.get_instance_id()]
		var ready: bool = parts_catalog.has_ready_parts(id)
		check((rendered.get_node_or_null("HeroPartsRig3D") != null) == ready, id + " actual field admits only reviewed part art")
		if not ready:
			check(rendered.get_node("HeroSkeletalBillboard").visible, id + " unreviewed art keeps the original rendered hero visible")
		# This dictionary is a disposable in-memory gate fixture, never an art
		# approval or an edit to the real definition on disk.
		var approved_fixture: Dictionary = definitions[id].duplicate(true)
		approved_fixture.reviewed = true
		approved_fixture.component_integrity_verified = true
		approved_fixture.test_cache_marker = "transient-only"
		field.hero_parts_definitions[id] = approved_fixture
		field.sync_actor(source, point, true, {})
		rendered = field.actors[source.get_instance_id()]
		var rig = rendered.get_node_or_null("HeroPartsRig3D")
		check(rig != null and rig.parts.size() >= CORE_COMPONENTS.size(), id + " actual field builds the separate-parts child after the review gate")
		if rig == null: continue
		var instance: int = rig.get_instance_id()
		check(not rendered.get_node("HeroSkeletalBillboard").visible and rendered.texture == null, id + " multipart rendering hides both old hero draw paths")
		check(is_equal_approx(float(rig.debug_snapshot().height), field._actor_height(source, true)), id + " multipart body height agrees with field and health-overlay presentation height")
		check(Vector2(rendered.position.x, rendered.position.z).is_equal_approx(point), id + " multipart child preserves the real world actor foot position")
		field.sync_actor(source, point, true, {})
		check(rendered.get_node("HeroPartsRig3D").get_instance_id() == instance and field.hero_parts_definitions[id].get("test_cache_marker", "") == "transient-only", id + " render sync reuses its child and cached definition")
	field.hero_parts_definitions = cached_before
	field._switch_art(false)
	field._process(0)
	for source in game.hero_map_sprites:
		var rendered: Sprite3D = field.actors[source.get_instance_id()]
		check(rendered.get_node_or_null("HeroPartsRig3D") == null and rendered.get_node("HeroSkeletalBillboard").visible, str(source.atlas_key) + " original-map comparison restores the original hero renderer")
	field._switch_art(true)
	field._process(0)
	check(gameplay_snapshot(game) == before, "multipart gate, cache and comparison fixtures leave the real encounter untouched")

func test_parts_gallery(definitions: Dictionary) -> void:
	var gallery = load("res://scenes/art/HeroPartsStudy.tscn").instantiate()
	root.add_child(gallery)
	await settle()
	gallery.set_process(false)
	var state: Dictionary = gallery.gallery_state()
	check(state.hero_count == 15 and state.action_count == 16, "actual gallery exposes fifteen production identities and sixteen motions")
	for id: String in definitions:
		gallery.select_hero(id)
		state = gallery.gallery_state()
		check(bool(state.parts_ready) and int(state.part_count) >= CORE_COMPONENTS.size() and bool(state.source_is_hidden) and bool(state.static_reference_visible), id + " gallery draws assembled parts separately from its static concept")
		for action: String in ["walk", "attack_1", "skill", "guard", "death"]:
			gallery.select_action(action)
			gallery.seek_animation(.21)
			state = gallery.gallery_state()
			check(state.action == action and state.rig.source_action == action and float(state.time) > .20, id + " actual gallery previews " + action)
		gallery.set_animation_playing(false)
		state = gallery.gallery_state()
		var paused: Dictionary = state.rig
		gallery._process(.1)
		check(is_equal_approx(gallery.gallery_state().time, state.time) and gallery.gallery_state().rig.motion_clock == paused.motion_clock, id + " gallery pause stops playback and local motion")
		gallery.set_mirrored(true)
		check(gallery.gallery_state().rig.flip, id + " gallery mirror control reaches the actual multipart renderer")
		gallery.set_mirrored(false)
		check(gallery.has_method("set_rest_pose_preview"), id + " gallery exposes neutral inspection separately from its sixteen actions")
		if gallery.has_method("set_rest_pose_preview"):
			gallery.set_rest_pose_preview(true)
			state = gallery.gallery_state()
			var neutral_source := source_timing_snapshot(gallery.source)
			gallery._process(.1)
			var rest_state: Dictionary = gallery.gallery_state()
			check(bool(rest_state.rest_pose_preview) and rest_state.rig.applied_action == "rest_pose" and rest_state.action_count == 16, id + " gallery neutral view does not masquerade as another action")
			check(is_equal_approx(rest_state.time, state.time) and is_equal_approx(rest_state.rig.motion_clock, state.rig.motion_clock) and source_timing_snapshot(gallery.source) == neutral_source, id + " gallery neutral inspection freezes timeline and source frames")
			gallery.select_action("walk")
			check(not bool(gallery.gallery_state().rest_pose_preview) and gallery.gallery_state().rig.applied_action == "walk", id + " selecting an action exits neutral into the actual chosen motion")
		gallery.set_animation_playing(true)
		await process_frame
	gallery.free()
	await settle()
	check_sentinels("separate multipart gallery")

func joint_transforms(rig) -> Array:
	var result: Array = []
	for key in rig.joints: result.append(rig.joints[key].transform)
	return result

func parts_pose_is_finite(rig) -> bool:
	for key in rig.parts:
		var transform: Transform3D = rig.parts[key].global_transform
		if not transform.is_finite() or is_zero_approx(transform.basis.determinant()): return false
	return true

func test_neutral_rest(id: String, source: AnimatedSprite2D, rig, field, definition: Dictionary) -> void:
	check(rig.has_method("set_rest_pose_preview"), id + " offers an actual neutral rest mode separate from the sixteen actions")
	if not rig.has_method("set_rest_pose_preview"): return
	var original: Dictionary = source_timing_snapshot(source)
	var clock: float = rig.motion_clock
	rig.set_rest_pose_preview(true)
	rig.sync(field.camera, 2.25, Color.WHITE, .1, true)
	var state: Dictionary = rig.debug_snapshot()
	check(bool(state.get("rest_pose_preview", false)) and state.get("applied_action", "") == "rest_pose" and state.source_action == source.visual_action, id + " rest preview is disclosed without inventing a seventeenth controller action")
	check(is_equal_approx(rig.motion_clock, clock) and source_timing_snapshot(source) == original, id + " neutral inspection freezes added clocks and preserves controller timing")
	var rest: Dictionary = parts_catalog.joint_positions(id, definition)
	var local_rest: Dictionary = rig.rest_joint_positions()
	var exact_rest := true
	for key in rig.joints:
		var joint: Node3D = rig.joints[key]
		var parent: String = rest[key].parent
		var point: Vector2 = rest[key].position - (rest[parent].position if not parent.is_empty() else Vector2.ZERO)
		var expected := Vector3(point.x, -point.y, 0)
		if key in ["Weapon", "Offhand"]: expected += joint.get_meta("grip_mount_local", Vector3.ZERO)
		exact_rest = exact_rest and joint.rotation.is_zero_approx() and joint.position.distance_to(expected) < .00001 and local_rest[key].distance_to(expected) < .00001
	check(exact_rest and is_zero_approx(float(state.get("ground_offset", 0))), id + " neutral hinges use authored rest coordinates plus equipment mounts without animated bend or floor adjustment")
	source.play_visual("guard")
	set_source_progress(source, .4)
	rig.sync(field.camera, 2.25, Color.WHITE, 0, true)
	check(rig.debug_snapshot().applied_action == "rest_pose" and rig.debug_snapshot().source_action == "guard", id + " neutral preview remains independent of changing source actions")
	rig.set_rest_pose_preview(false)
	rig.sync(field.camera, 2.25, Color.WHITE, 0, true)
	check(rig.debug_snapshot().applied_action == "guard" and not bool(rig.debug_snapshot().rest_pose_preview), id + " leaving neutral preview restores the current source action")
	check(is_equal_approx(float(rig.debug_snapshot().action_time), weighted_source_time(source)), id + " neutral exit resumes the current weighted source phase without a timing restart")

func test_parts_wrist_follow(id: String, rig) -> void:
	var weapon = rig.joints.get("Weapon")
	if weapon == null: return
	var hand: Node3D = weapon.get_parent()
	var original: Transform3D = hand.transform
	var weapon_local: Transform3D = weapon.transform
	var old_global: Transform3D = weapon.global_transform
	var torso_global: Transform3D = rig.joints.Chest.global_transform
	var painted_weapon = rig.parts.get("weapon")
	var old_painted: Transform3D = painted_weapon.global_transform
	hand.rotate_z(.25)
	check(weapon.transform == weapon_local and not weapon.global_transform.is_equal_approx(old_global), id + " rotating the wrist carries its weapon without detaching the local grip")
	check(not painted_weapon.global_transform.is_equal_approx(old_painted) and rig.joints.Chest.global_transform.is_equal_approx(torso_global), id + " wrist articulation moves the weapon artwork independently of the torso")
	hand.transform = original

func test_equipment_grip_offsets(id: String, source: AnimatedSprite2D, field, definition: Dictionary) -> void:
	# Deliberately nonzero offsets and rotations expose a grip that incorrectly
	# orbits the glove. This fixture does not replace any art or approved metadata.
	var fixture: Dictionary = definition.duplicate(true)
	var equipment: Dictionary = {}
	for entry: Dictionary in fixture.parts:
		if entry.id == "weapon":
			entry.offset = [.13, -.09]
			entry.rotation = .61
			equipment.weapon = entry
		elif entry.id == "offhand":
			entry.offset = [-.08, .12]
			entry.rotation = -.43
			equipment.offhand = entry
	var rig = parts_rig_script.new()
	field.world.add_child(rig)
	var bound: bool = rig.bind(source, fixture, true)
	check(bound, id + " accepts nonzero weapon and shield grip-offset regression fixtures")
	if not bound:
		rig.free()
		return
	var original_flip: bool = source.flip_h
	rig.set_rest_pose_preview(true)
	rig.sync(field.camera, 2.25, Color.WHITE, 0, false)
	for part_id: String in equipment:
		var entry: Dictionary = equipment[part_id]
		var joint_name := "Weapon" if part_id == "weapon" else "Offhand"
		var part: MeshInstance3D = rig.parts[part_id]
		var hand: Node3D = rig.joints[joint_name].get_parent()
		var vertices: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var size := Vector2(float(entry.display_size[0]), float(entry.display_size[1]))
		var anchor := Vector2(float(entry.anchor[0]), float(entry.anchor[1]))
		var offset := Vector2(float(entry.offset[0]), float(entry.offset[1]))
		var low := -anchor * size + offset
		var corners: Array[Vector2] = [low, low + Vector2(size.x, 0), low + size, low + Vector2(0, size.y)]
		var neutral_preserved := true
		for index in 4:
			var original_corner := Vector3(corners[index].x, -corners[index].y, 0).rotated(Vector3.BACK, -float(entry.rotation))
			original_corner.z += float(entry.z_order) * .0008
			var actual: Vector3 = hand.to_local(part.to_global(vertices[index]))
			neutral_preserved = neutral_preserved and actual.distance_to(original_corner) < .00001
		check(neutral_preserved, id + " " + part_id + " mount promotion preserves all four authored neutral quad corners")
		var mount: Vector3 = rig.joints[joint_name].get_meta("grip_mount_local", Vector3.ZERO)
		check(mount.length() > .05, id + " " + part_id + " fixture exercises a genuinely nonzero wrist mount")
		for mirrored: bool in [false, true]:
			source.flip_h = mirrored
			rig.sync(field.camera, 2.25, Color.WHITE, 0, false)
			for degrees: float in [-170.0, -75.0, 145.0, 500.0]:
				var before := source_timing_snapshot(source)
				rig._aim_gripped_part(part_id, joint_name, deg_to_rad(degrees))
				# Interpolate the actual texture anchor inside the actual GPU quad.
				# No metadata-only position claim can satisfy this geometry check.
				var grip_vertex: Vector3 = vertices[0] + (vertices[1] - vertices[0]) * anchor.x + (vertices[3] - vertices[0]) * anchor.y
				var actual_grip: Vector3 = hand.to_local(part.to_global(grip_vertex))
				check(Vector2(actual_grip.x, actual_grip.y).distance_to(Vector2(mount.x, mount.y)) < .00001, id + " " + part_id + " grip stays fixed to its hand under aim=" + str(degrees) + " mirror=" + str(mirrored))
				check(is_equal_approx(actual_grip.z, mount.z + float(entry.z_order) * .0008), id + " " + part_id + " aimed grip preserves its paint-layer depth")
				var relative: Basis = hand.global_basis.inverse() * part.global_basis
				check(relative.is_equal_approx(Basis(Vector3.BACK, -float(entry.rotation))) and rig.joints[joint_name].rotation.is_zero_approx(), id + " " + part_id + " rotates with its wrist without an extra equipment twist")
				check(absf(hand.rotation.z) <= PI + .00001 and source_timing_snapshot(source) == before, id + " " + part_id + " resolves a bounded wrist angle without changing the source controller")
		rig.sync(field.camera, 2.25, Color.WHITE, 0, false)
	source.flip_h = original_flip
	rig.free()

func test_attack_draw_order(id: String, source: AnimatedSprite2D, rig, field, definition: Dictionary) -> void:
	var baseline: Dictionary = {}
	var weapon_entry: Dictionary = {}
	for entry: Dictionary in definition.parts:
		baseline[str(entry.id)] = float(entry.get("z_order", 0)) * .0008
		if entry.id == "weapon": weapon_entry = entry
	var original_flip: bool = source.flip_h
	var hand: Node3D = rig.joints.Weapon.get_parent()
	var side := "left" if hand == rig.joints.LeftHand else "right"
	var expected_front: Array[String] = [side + "_upper_arm", side + "_forearm", side + "_hand", "weapon"]
	if rig.parts.has(side + "_shoulder"): expected_front.append(side + "_shoulder")
	expected_front.sort()
	for action: String in ["attack_1", "attack_2"]:
		source.speed_scale = 1
		source.play_visual(action)
		set_source_progress(source, .45)
		var before := source_timing_snapshot(source)
		rig.sync(field.camera, 2.25, Color.WHITE, .1, true)
		var state: Dictionary = rig.debug_snapshot()
		check(source_timing_snapshot(source) == before, id + " " + action + " layer correction leaves source timing intact")
		if id != "leonhardt":
			check(depths_match(rig, baseline) and state.get("draw_order_override", "") != "lead_arm_in_front", id + " does not inherit Leonhardt's attack-only layer override")
			continue
		var declared: Array = state.get("front_attack_parts", []).duplicate()
		declared.sort()
		check(state.get("draw_order_override", "") == "lead_arm_in_front" and declared == expected_front, action + " declares exactly its real weapon-side arm and equipment group")
		var delta: float = rig.parts.weapon.position.z - float(baseline.weapon)
		var group_moves_together := delta > 0
		var unrelated_unchanged := true
		var front_min := INF
		for part_id: String in rig.parts:
			var difference: float = rig.parts[part_id].position.z - float(baseline[part_id])
			if part_id in expected_front:
				group_moves_together = group_moves_together and is_equal_approx(difference, delta)
				front_min = minf(front_min, rig.parts[part_id].position.z)
			else: unrelated_unchanged = unrelated_unchanged and is_zero_approx(difference)
		check(group_moves_together and unrelated_unchanged, action + " moves the complete arm group forward by one common depth translation")
		check(front_min > rig.parts.chest.position.z and (not rig.parts.has("offhand") or front_min > rig.parts.offhand.position.z), action + " places the moving arm and sword in front of their actual chest and shield blockers")
		check(is_equal_approx(rig.parts.weapon.position.z - rig.parts[side + "_hand"].position.z, float(baseline.weapon) - float(baseline[side + "_hand"])), action + " retains the authored weapon-to-glove plane separation")
		var part: MeshInstance3D = rig.parts.weapon
		var vertices: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var anchor := Vector2(float(weapon_entry.anchor[0]), float(weapon_entry.anchor[1]))
		var grip := vertices[0] + (vertices[1] - vertices[0]) * anchor.x + (vertices[3] - vertices[0]) * anchor.y
		var actual_grip: Vector3 = hand.to_local(part.to_global(grip))
		var mount: Vector3 = rig.joints.Weapon.get_meta("grip_mount_local", Vector3.ZERO)
		check(Vector2(actual_grip.x, actual_grip.y).distance_to(Vector2(mount.x, mount.y)) < .00001 and is_equal_approx(actual_grip.z, mount.z + float(baseline.weapon) + delta), action + " real quad grip keeps its hand-local XY while its layer moves with the glove")
		var frozen := depth_map(rig)
		source.play_visual("idle")
		rig.sync(field.camera, 2.25, Color.WHITE, .1, false)
		check(depth_map(rig) == frozen and rig.debug_snapshot().applied_action == action, action + " pause freezes layers with the currently displayed pose even if source intent changes")
		source.flip_h = not source.flip_h
		rig.sync(field.camera, 2.25, Color.WHITE, 0, false)
		check(depth_map(rig) == frozen, action + " paused mirror retains foreground ordering")
		source.speed_scale = 0
		rig.sync(field.camera, 2.25, Color.WHITE, .1, true)
		check(depth_map(rig) == frozen, action + " individual speed zero preserves its current layer group")
		source.speed_scale = 1
		rig.sync(field.camera, 2.25, Color.WHITE, .1, true)
		check(depths_match(rig, baseline) and rig.debug_snapshot().get("draw_order_override", "") == "", action + " resume into idle restores every authored layer")
		source.play_visual(action)
		set_source_progress(source, .5)
		rig.sync(field.camera, 2.25, Color.WHITE, .1, true)
		rig.set_rest_pose_preview(true)
		check(depths_match(rig, baseline), action + " entering neutral immediately restores metadata depths")
		rig.sync(field.camera, 2.25, Color.WHITE, 0, false)
		check(rig.debug_snapshot().applied_action == "rest_pose" and rig.debug_snapshot().get("draw_order_override", "") == "", action + " neutral preview does not retain the attack foreground override")
		rig.set_rest_pose_preview(false)
	if id == "leonhardt":
		for action: String in PARTS_ACTIONS:
			if action in ["attack_1", "attack_2"]: continue
			source.play_visual("attack_1")
			set_source_progress(source, .45)
			rig.sync(field.camera, 2.25, Color.WHITE, .1, true)
			source.play_visual(action)
			set_source_progress(source, .4)
			rig.sync(field.camera, 2.25, Color.WHITE, .1, true)
			check(depths_match(rig, baseline) and rig.debug_snapshot().get("draw_order_override", "") == "", action + " transition restores authored depths without accumulated attack offsets")
	source.flip_h = original_flip
	source.speed_scale = 1

func test_attack_ergonomics(id: String, source: AnimatedSprite2D, rig, field) -> Dictionary:
	if id != "leonhardt": return {}
	var result: Dictionary = {}
	var lead := "Left" if float(rig.motion_profile.side) > 0 else "Right"
	var side := float(rig.motion_profile.side)
	for action: String in ["attack_1", "attack_2"]:
		source.speed_scale = 1
		source.play_visual(action)
		var max_wrist := 0.0
		var max_jump := 0.0
		var elbow_flexion_valid := true
		var previous: Dictionary = {}
		var timing_preserved := true
		# The short strike legitimately covers about twenty degrees in 1/60 of
		# the source action. Sample its continuous curve more densely to detect
		# discontinuities without mistaking the intended fast swing for a snap.
		for tick in 241:
			set_source_progress(source, float(tick) / 240.0)
			var timing := source_timing_snapshot(source)
			rig.sync(field.camera, 2.25, Color.WHITE, 0.0, true)
			timing_preserved = timing_preserved and source_timing_snapshot(source) == timing
			max_wrist = maxf(max_wrist, absf(rig.joints[lead + "Hand"].rotation.z))
			elbow_flexion_valid = elbow_flexion_valid and rig.joints[lead + "Forearm"].rotation.z * side >= -.00001
			for joint: String in [lead + "UpperArm", lead + "Forearm", lead + "Hand"]:
				var angle: float = rig.joints[joint].rotation.z
				if previous.has(joint): max_jump = maxf(max_jump, absf(angle - float(previous[joint])))
				previous[joint] = angle
		check(max_wrist < deg_to_rad(8.0), action + " full preparation strike and recovery keep the actual wrist below eight degrees")
		check(elbow_flexion_valid, action + " elbow flexion does not reverse through an impossible backward bend")
		check(max_jump < .10, action + " 240 source-phase intervals contain no wrist or elbow angle snap")
		check(timing_preserved, action + " ergonomic pose sampling preserves every source frame and weighted phase")
		result[action] = {"samples": 241, "maximum_wrist_degrees": rad_to_deg(max_wrist), "maximum_joint_step_radians": max_jump, "elbow_flexion_valid": elbow_flexion_valid}
	return result

func test_equipment_wrists(id: String, source: AnimatedSprite2D, rig, field) -> void:
	if id != "leonhardt": return
	for action: String in PARTS_ACTIONS:
		source.speed_scale = 1.0
		source.play_visual(action)
		var maximum := 0.0
		for tick in 81:
			set_source_progress(source, float(tick) / 80.0)
			rig.sync(field.camera, 2.25, Color.WHITE, .02, true)
			for hand: String in ["LeftHand", "RightHand"]:
				maximum = maxf(maximum, absf(rig.joints[hand].rotation.z))
		check(maximum < deg_to_rad(15), action + " sword and shield wrists remain within fifteen degrees throughout the source action")

func depth_map(rig) -> Dictionary:
	var result: Dictionary = {}
	for key in rig.parts: result[key] = rig.parts[key].position.z
	return result

func depths_match(rig, expected: Dictionary) -> bool:
	for key in rig.parts:
		if not is_equal_approx(rig.parts[key].position.z, float(expected[key])): return false
	return true

func test_parts_pause_and_mirror(id: String, source: AnimatedSprite2D, rig, field, distance: float) -> void:
	source.play_visual("walk")
	rig.sync(field.camera, 2.25, Color.WHITE, .05, true, Vector2.RIGHT, distance)
	var clock: float = float(rig.debug_snapshot().get("motion_clock", -1))
	var pose := joint_transforms(rig)
	var layers := part_depths(rig)
	set_source_progress(source, .7)
	rig.sync(field.camera, 2.25, Color.WHITE, .1, false, Vector2.RIGHT, distance + .1)
	check(is_equal_approx(float(rig.debug_snapshot().get("motion_clock", -2)), clock) and joint_transforms(rig) == pose, id + " inactive multipart renderer freezes its pose and added clock")
	source.speed_scale = 0
	rig.sync(field.camera, 2.25, Color.WHITE, .1, true, Vector2.RIGHT, distance + .2)
	check(is_equal_approx(float(rig.debug_snapshot().get("motion_clock", -2)), clock), id + " source speed zero freezes additional motion")
	source.speed_scale = 1
	source.flip_h = false
	rig.sync(field.camera, 2.25, Color.WHITE, 0, false)
	var position: Vector3 = rig.global_position
	var basis_sign: float = signf(rig.global_basis.determinant())
	source.flip_h = true
	rig.sync(field.camera, 2.25, Color(.8, .6, .9, .4), 0, false)
	check(rig.global_position.is_equal_approx(position) and signf(rig.global_basis.determinant()) == -basis_sign, id + " mirroring reverses the assembled rig around its fixed world-foot anchor")
	check(parts_pose_is_finite(rig), id + " mirrored assembled parts retain finite camera-facing transforms")
	check(part_depths(rig) == layers, id + " pause and mirror preserve the separate painted layers' depth order")
	var tint_applied := true
	for key in rig.parts:
		var material: ShaderMaterial = rig.parts[key].material_override
		tint_applied = tint_applied and (material.get_shader_parameter("actor_tint") as Color).is_equal_approx(Color(.8, .6, .9, .4))
	check(tint_applied, id + " every independent part receives the same hit color and death alpha")

func test_mesh_regions(id: String, rig, definition: Dictionary) -> void:
	var texture := load(str(definition.atlas)) as Texture2D
	var dimensions: Vector2 = texture.get_size()
	var uv_rects: Dictionary = {}
	for entry: Dictionary in definition.parts:
		var part: MeshInstance3D = rig.parts[str(entry.id)]
		check(part.get_parent() == rig.joints[str(entry.bone)], id + " " + str(entry.id) + " hangs from its declared actual joint")
		check(part.mesh.get_surface_count() == 1, id + " " + str(entry.id) + " is one independent painted plane")
		var surface: Array = part.mesh.surface_get_arrays(0)
		check(surface[Mesh.ARRAY_VERTEX].size() == 4 and surface[Mesh.ARRAY_INDEX].size() == 6, id + " " + str(entry.id) + " uses its own quad, not a warped whole-body skin")
		var region := Rect2(float(entry.region[0]), float(entry.region[1]), float(entry.region[2]), float(entry.region[3]))
		var uv_region := Rect2(region.position / dimensions, region.size / dimensions)
		var uv_valid := true
		for uv: Vector2 in surface[Mesh.ARRAY_TEX_UV]: uv_valid = uv_valid and uv_region.grow(.00001).has_point(uv)
		check(uv_valid, id + " " + str(entry.id) + " samples only its own atlas component")
		var material: ShaderMaterial = part.material_override
		check(material.get_shader_parameter("source_texture") == texture, id + " " + str(entry.id) + " renders the new separated art")
		var crop: Vector4 = material.get_shader_parameter("atlas_rect")
		check(crop == Vector4(uv_region.position.x, uv_region.position.y, uv_region.size.x, uv_region.size.y), id + " " + str(entry.id) + " shader clips its outline to the same component region")
		uv_rects[str(crop)] = true
	check(uv_rects.size() == rig.parts.size(), id + " actual GPU parts have distinct texture regions")

func part_depths(rig) -> Array:
	var result: Array = []
	for key in rig.parts: result.append(rig.parts[key].position.z)
	return result

func source_timing_snapshot(source: AnimatedSprite2D) -> Dictionary:
	return {"state": source.state, "action": source.visual_action, "sequence": source.visual_sequence,
		"animation": source.animation, "frame": source.frame, "progress": source.frame_progress,
		"speed_scale": source.speed_scale, "frames": source.sprite_frames.get_instance_id(),
		"position": source.position, "scale": source.scale, "offset": source.offset,
		"flip_h": source.flip_h, "modulate": source.modulate, "self_modulate": source.self_modulate}

func weighted_source_time(source: AnimatedSprite2D) -> float:
	var frames: SpriteFrames = source.sprite_frames
	var weights := 0.0
	for index in source.frame: weights += frames.get_frame_duration(source.animation, index)
	weights += frames.get_frame_duration(source.animation, source.frame) * source.frame_progress
	return weights / frames.get_animation_speed(source.animation)

func set_source_progress(source: AnimatedSprite2D, progress: float) -> void:
	var frames: SpriteFrames = source.sprite_frames
	var count := frames.get_frame_count(source.animation)
	var total := 0.0
	for index in count: total += frames.get_frame_duration(source.animation, index)
	var remaining := clampf(progress, 0, .99999) * total
	for index in count:
		var duration := frames.get_frame_duration(source.animation, index)
		if remaining < duration or index == count - 1:
			source.set_frame_and_progress(index, remaining / duration)
			return
		remaining -= duration

func finish() -> void:
	var result := {"checks": checks, "failures": failures, "parts": parts_results, "directions": direction_results,
		"requested_development_ids": requested_ids, "scope": "Painted multipart 2.5D hero fixtures and sixteen source-timed procedural motion tracks; selected IDs and visual review status are recorded separately; not volumetric 3D models or hand-drawn sixteen-frame sequences"}
	var out := FileAccess.open("user://aurelia-hero-parts-results.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "  "))
		out.close()
	print("aurelia_hero_parts checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
