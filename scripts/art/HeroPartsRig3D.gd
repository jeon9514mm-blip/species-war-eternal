extends Node3D
## True cutout articulation: 21 hinge nodes, each holding independent texture
## regions. No single-body deformation mesh and no writes to the source actor.
const CATALOG = preload("res://scripts/art/HeroPartsCatalog.gd")
const MOTIONS = preload("res://scripts/portrait/HeroRigMotionCatalog.gd")
const PART_MOTION = preload("res://scripts/art/HeroPartsMotion.gd")
const PART_SHADER = preload("res://assets/art-direction/pilot-01/shaders/hero-contour.gdshader")
var source: AnimatedSprite2D
var definition: Dictionary = {}
var joints: Dictionary = {}
var parts: Dictionary = {}
var validation: Dictionary = {}
var motion_profile: Dictionary = {}
var action_time := 0.0
var motion_clock := 0.0
var gait_phase := 0.0
var rest_pose_preview := false
var _breath_phase := 0.0
var _hair := 0.0
var _cape := 0.0
var _hair_speed := 0.0
var _cape_speed := 0.0
var _rest_positions: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _current_pose: Dictionary = {}
var _transition_pose: Dictionary = {}
var _transition_time := 0.0
var _current_action := ""
var _sequence := -1
var _last_distance := -1.0
var _was_active := false
var _ready_parts := false
var _last_debug: Dictionary = {}
var _support_points: Dictionary = {}
var _ground_offset := 0.0
var _authored_part_depths: Dictionary = {}
var _front_attack_parts: Array[String] = []
var _draw_order_override := ""

func bind(actor: AnimatedSprite2D, part_definition: Dictionary, allow_unreviewed := false) -> bool:
	_clear()
	name = "HeroPartsRig3D"
	validation = CATALOG.validate_definition(part_definition, allow_unreviewed)
	if not bool(validation.valid) or not is_instance_valid(actor): return false
	if str(actor.get("atlas_key")) != str(part_definition.get("hero_id", "")):
		validation.valid = false
		validation.issues.append("Source hero ID differs from the part art")
		return false
	source = actor
	definition = CATALOG.normalize_definition(part_definition)
	motion_profile = CATALOG.profile(str(definition.hero_id))
	# An artist-reviewed hand override must drive both weapon parenting and the
	# action's lead arm. Legacy side +1 becomes anatomical Left after key swapping.
	var weapon_hand := str(definition.get("weapon_hand", motion_profile.weapon_hand))
	motion_profile.side = 1 if weapon_hand == "left" else -1
	var rest: Dictionary = CATALOG.joint_positions(str(definition.hero_id), definition)
	for key in CATALOG.BONE_NAMES:
		var joint := Node3D.new()
		joint.name = "Joint" + key
		joint.set_meta("bone_key", key)
		var parent_key: String = rest[key].parent
		var global_point: Vector2 = rest[key].position
		var parent_point: Vector2 = rest[parent_key].position if not parent_key.is_empty() else Vector2.ZERO
		var local := global_point - parent_point
		joint.position = Vector3(local.x, -local.y, 0.0)
		_rest_positions[key] = joint.position
		if parent_key.is_empty(): add_child(joint)
		else: joints[parent_key].add_child(joint)
		joints[key] = joint
	var texture: Texture2D = load(str(definition.atlas))
	var atlas_image := texture.get_image()
	if atlas_image != null and atlas_image.is_compressed(): atlas_image.decompress()
	for entry: Dictionary in definition.parts:
		if str(entry.id) in ["weapon", "offhand"]:
			# Older metadata places the grip with an offset inside the rotated
			# painting. Promote that exact rest-space point to a fixed wrist mount;
			# otherwise an equipment aim rotates the offset away from the glove.
			var mount := _equipment_mount(entry)
			var equipment_joint: Node3D = joints[str(entry.bone)]
			equipment_joint.position += mount
			equipment_joint.set_meta("grip_mount_local", mount)
			_rest_positions[str(entry.bone)] = equipment_joint.position
		var part := _make_part(entry, texture)
		joints[str(entry.bone)].add_child(part)
		parts[str(entry.id)] = part
		_authored_part_depths[str(entry.id)] = part.position.z
		_support_points[str(entry.id)] = _silhouette_support(entry, atlas_image)
	_ready_parts = true
	return true

func sync(camera: Camera3D, height: float, tint: Color, delta: float, active: bool, real_velocity := Vector2.ZERO, real_distance := -1.0) -> void:
	if not _ready_parts or not is_instance_valid(source) or not is_instance_valid(camera): return
	var mirror := -1.0 if source.flip_h else 1.0
	var safe_height := maxf(.01, height) if is_finite(height) else 1.0
	# Camera facing is shared by every part and its hinge. The foot-space origin
	# stays fixed; source movement, collision and damage anchors are untouched.
	basis = camera.global_basis.scaled_local(Vector3(safe_height * mirror, safe_height, safe_height))
	for material in _materials:
		material.set_shader_parameter("actor_tint", tint)
		material.set_shader_parameter("facing_sign", mirror)
	var sample := _source_sample()
	var action: String = sample.action
	var changed := action != _current_action or int(sample.sequence) != _sequence
	var running := active and source.speed_scale > 0.0 and not rest_pose_preview
	var dt := clampf(delta, 0.0, .1) * clampf(source.speed_scale, 0.0, 4.0) if running and is_finite(delta) else 0.0
	# Sampling can be reconciled at delta=0 for the gallery's explicit action/seek
	# controls. During pause, retain the last assembled pose and all local clocks.
	var should_sample := not rest_pose_preview and (running or _current_pose.is_empty())
	var distance_delta := 0.0
	if real_distance >= 0.0 and is_finite(real_distance):
		if _last_distance >= 0.0 and _was_active and running:
			distance_delta = real_distance - _last_distance
			if distance_delta < 0.0 or distance_delta > 1.0: distance_delta = 0.0
		_last_distance = real_distance
	else:
		_last_distance = -1.0
	if dt > 0.0:
		motion_clock = fposmod(motion_clock + dt, 600.0)
		_breath_phase = fposmod(_breath_phase + dt * 2.15 * float(motion_profile.cadence), TAU)
		if action in ["walk", "run"]:
			if real_distance >= 0.0:
				gait_phase = fposmod(gait_phase + distance_delta / float(motion_profile.stride_distance) * TAU, TAU)
			else:
				# A gallery has no battle distance. It previews the same cadence using
				# its controlled source timeline rather than a gameplay movement write.
				gait_phase = fposmod(float(sample.time) * (10.0 if action == "run" else 7.0) * float(motion_profile.cadence), TAU)
	if rest_pose_preview:
		_current_pose.clear()
		_apply_pose({})
		_apply_part_layers("")
		_ground_offset = 0.0
	elif should_sample:
		if changed:
			_transition_pose = _current_pose.duplicate()
			_transition_time = 0.0
			_current_action = action
			_sequence = int(sample.sequence)
		action_time = float(sample.time)
		_transition_time += dt
		var pose := _adapt_pose(action, action_time, float(sample.duration), real_velocity, real_distance)
		if dt > 0.0 and action != "death": _secondary(pose, dt)
		if action != "death":
			pose.Hair = float(pose.get("Hair", 0.0)) + _hair
			pose.Cape = float(pose.get("Cape", 0.0)) + _cape
		# Source events and normalized action progress are not delayed by a new
		# transition. Blend only continuous states after a change of intent.
		if action in ["idle", "walk", "run"] and not _transition_pose.is_empty() and _transition_time < .10:
			var blend := smoothstep(0.0, .10, _transition_time)
			for key in _transition_pose:
				if not pose.has(key): pose[key] = 0.0
			for key in pose:
				if key in ["_weapon_angle", "_offhand_angle"]:
					pose[key] = lerp_angle(float(_transition_pose.get(key, pose[key])), float(pose[key]), blend)
				else:
					pose[key] = lerpf(float(_transition_pose.get(key, 0.0)), float(pose[key]), blend)
		_current_pose = pose
		_apply_pose(pose)
		_apply_part_layers(action)
		if str(definition.hero_id) == "leonhardt": _ground_pose(action)
	_was_active = running
	_last_debug = {
		"hero_id": str(definition.hero_id), "ready": _ready_parts,
		"reviewed": bool(validation.reviewed), "source_action": action,
		"applied_action": "rest_pose" if rest_pose_preview else _current_action,
		"rest_pose_preview": rest_pose_preview,
		"action_time": action_time, "source_frame_time": float(sample.time),
		"action_duration": float(sample.duration), "source_sequence": int(sample.sequence),
		"motion_clock": motion_clock, "gait_phase": gait_phase,
		"distance_delta": distance_delta, "active": running, "flip": source.flip_h,
		"part_count": parts.size(), "joint_count": joints.size(),
		"independent_texture_regions": int(validation.independent_texture_regions),
		"weapon_parent": str(joints.Weapon.get_parent().name),
		"offhand_parent": str(joints.Offhand.get_parent().name),
		"source_state_modified": false, "source_rig_modified": false,
		"renderer": "independent_cutout_parts_on_21_hinges",
		"action_set": CATALOG.ACTIONS.duplicate(),
		"pose": _current_pose.duplicate(), "height": safe_height,
		"tint": tint, "atlas": str(definition.atlas),
		"motion_provenance": str(motion_profile.motion_provenance),
		"custom_joint_rest": definition.has("joint_rest"),
		"ground_offset": _ground_offset,
		"draw_order_override": _draw_order_override,
		"front_attack_parts": _front_attack_parts.duplicate(),
		"motion_revision": PART_MOTION.REVISION if str(definition.hero_id) == "leonhardt" else "legacy_adapted_curves",
	}

func debug_snapshot() -> Dictionary:
	return _last_debug.duplicate(true)

func rest_joint_positions() -> Dictionary:
	# Local, Y-up body-height units. Anatomical joints retain Catalog positions;
	# Weapon/Offhand additionally contain their immutable equipment grip mounts.
	return _rest_positions.duplicate()

func set_rest_pose_preview(enabled: bool) -> void:
	if rest_pose_preview == enabled: return
	rest_pose_preview = enabled
	_current_pose.clear()
	_transition_pose.clear()
	_current_action = ""
	_sequence = -1
	_last_distance = -1.0
	_was_active = false
	if enabled and _ready_parts:
		_apply_pose({})
		_apply_part_layers("")
		_ground_offset = 0.0

func set_rest_pose(enabled: bool) -> void:
	set_rest_pose_preview(enabled)

func _source_sample() -> Dictionary:
	var action := str(source.get("visual_action")) if source.has_method("play_visual") else str(source.get("state"))
	if action == "attack": action = "attack_1"
	if action not in CATALOG.ACTIONS: action = "idle"
	var frames := source.sprite_frames
	var animation := source.animation
	var time := 0.0
	var duration := .6
	if frames != null and frames.has_animation(animation):
		var count := frames.get_frame_count(animation)
		var fps := maxf(.001, frames.get_animation_speed(animation))
		var total := 0.0
		for index in count:
			var weight := frames.get_frame_duration(animation, index)
			total += weight
			if index < source.frame: time += weight
			elif index == source.frame: time += weight * clampf(source.frame_progress, 0.0, 1.0)
		time /= fps
		duration = total / fps
	return {"action": action, "time": time, "duration": maxf(duration, .001), "sequence": int(source.get("visual_sequence"))}

func _adapt_pose(action: String, time: float, duration: float, velocity: Vector2, real_distance: float) -> Dictionary:
	# Legacy labels were screen-side, new hinges are anatomical. Swap the paired
	# keys exactly once; family/weapon hand still refer to each existing identity.
	var raw: Dictionary = MOTIONS.sample(motion_profile, action, time, duration)
	var pose: Dictionary = {}
	for old_key in raw:
		var key := str(old_key)
		if key.begins_with("Left"): key = "Right" + key.trim_prefix("Left")
		elif key.begins_with("Right"): key = "Left" + key.trim_prefix("Right")
		pose[key] = float(raw[old_key])
	var breath := sin(_breath_phase)
	if action == "idle":
		pose.Torso = breath * .012
		pose.Head = -breath * .010
		pose.LeftUpperArm = -breath * .015
		pose.RightUpperArm = breath * .015
		pose.chest_lift = breath * .0025
	if action in ["walk", "run"]:
		var phase := gait_phase
		if real_distance < 0.0: phase = time * (10.0 if action == "run" else 7.0) * float(motion_profile.cadence)
		var step := sin(phase)
		var fast := action == "run"
		var stride := (.23 if fast else .17) * float(motion_profile.power)
		# Four-head legs are longer than the old chibi mesh. Use smaller pelvis
		# translation and keep feet close to the floor during a complete stride.
		pose.root_y = -absf(step) * (.009 if fast else .005)
		pose.Pelvis = step * .016
		pose.Torso = -step * .024
		pose.Head = step * .016
		pose.LeftThigh = step * stride
		pose.RightThigh = -step * stride
		pose.LeftShin = -maxf(-step, 0.0) * .29
		pose.RightShin = maxf(step, 0.0) * .29
		pose.LeftFoot = maxf(-step, 0.0) * .12
		pose.RightFoot = -maxf(step, 0.0) * .12
		pose.LeftUpperArm = -step * .11
		pose.RightUpperArm = step * .11
		pose.Hair = sin(phase - .48) * .015 * float(motion_profile.cloth)
		pose.Cape = -sin(phase - .8) * .04 * float(motion_profile.cloth)
		if velocity.is_finite():
			var facing := -1.0 if source.flip_h else 1.0
			pose.Torso += clampf(velocity.x * facing / 1.95, -1.0, 1.0) * .022
	# Original curve root translations are pose accents, never world movement.
	pose.root_x = clampf(float(pose.get("root_x", 0.0)), -.08, .08)
	pose.root_y = clampf(float(pose.get("root_y", 0.0)), -.08, .16)
	var weapon_rest := -float(parts.weapon.rotation.z) if parts.has("weapon") else 0.0
	var offhand_rest := -float(parts.offhand.rotation.z) if parts.has("offhand") else 0.0
	pose = PART_MOTION.apply(motion_profile, action, time, duration, pose, weapon_rest, offhand_rest)
	# Every pose carries aim, so recovery can blend angularly back to the painted
	# rest instead of snapping through a full turn when the action ends.
	if not pose.has("_weapon_angle"): pose._weapon_angle = _pose_art_angle("Weapon", pose, weapon_rest)
	if not pose.has("_offhand_angle"): pose._offhand_angle = _pose_art_angle("Offhand", pose, offhand_rest)
	return pose

func _secondary(pose: Dictionary, dt: float) -> void:
	var gesture := float(pose.get("Torso", 0.0)) + float(pose.get("Chest", 0.0))
	var cloth := float(motion_profile.cloth)
	var hair_target := sin(_breath_phase - .65) * .008 * cloth - gesture * .12
	var cape_target := sin(_breath_phase - 1.0) * .010 * cloth - gesture * .20
	var steps := maxi(1, int(ceil(dt / .012)))
	var step_dt := dt / float(steps)
	for _index in steps:
		_hair_speed = clampf(_hair_speed + ((hair_target - _hair) * 145.0 - _hair_speed * 21.0) * step_dt, -.65, .65)
		_cape_speed = clampf(_cape_speed + ((cape_target - _cape) * 78.0 - _cape_speed * 14.0) * step_dt, -.65, .65)
		_hair = clampf(_hair + _hair_speed * step_dt, -.06, .06)
		_cape = clampf(_cape + _cape_speed * step_dt, -.10, .10)

func _apply_pose(pose: Dictionary) -> void:
	for key in joints:
		var joint: Node3D = joints[key]
		joint.position = _rest_positions[key]
		joint.rotation = Vector3(0.0, 0.0, -float(pose.get(key, 0.0)))
	joints.Root.position += Vector3(float(pose.get("root_x", 0.0)), -float(pose.get("root_y", 0.0)), 0.0)
	joints.Chest.position.y += float(pose.get("chest_lift", 0.0))
	if pose.has("_weapon_angle"): _aim_gripped_part("weapon", "Weapon", float(pose._weapon_angle))
	if pose.has("_offhand_angle"): _aim_gripped_part("offhand", "Offhand", float(pose._offhand_angle))

func _pose_art_angle(joint_key: String, pose: Dictionary, rest_angle: float) -> float:
	var angle := rest_angle
	var node: Node = joints[joint_key]
	while node != self:
		angle += float(pose.get(str(node.get_meta("bone_key", "")), 0.0))
		node = node.get_parent()
	return angle

func _aim_gripped_part(part_key: String, joint_key: String, angle: float) -> void:
	if not parts.has(part_key): return
	var node: Node3D = joints[joint_key]
	var hand: Node3D = node.get_parent()
	var parent: Node3D = hand.get_parent()
	var parents_angle := 0.0
	while parent != self:
		parents_angle += parent.rotation.z
		parent = parent.get_parent()
	# Aim through the wrist, keeping both the painted glove and its equipment
	# together. A full-turn source angle resolves to the shortest wrist rotation;
	# the equipment's own rest angle and grip translation never change.
	node.rotation.z = 0.0
	hand.rotation.z = wrapf(-angle - parents_angle - float(parts[part_key].rotation.z), -PI, PI)

func _equipment_mount(entry: Dictionary) -> Vector3:
	var offset: Array = entry.get("offset", [0.0, 0.0])
	var local := Vector3(float(offset[0]), -float(offset[1]), 0.0)
	return local.rotated(Vector3.BACK, -float(entry.get("rotation", 0.0)))

func _geometry_offset(entry: Dictionary) -> Vector2:
	if str(entry.id) in ["weapon", "offhand"]: return Vector2.ZERO
	var offset: Array = entry.get("offset", [0.0, 0.0])
	return Vector2(float(offset[0]), float(offset[1]))

func _apply_part_layers(action: String) -> void:
	# Restore from authored values every sampled pose; never accumulate offsets.
	# An inactive sync does not sample a new pose, so pause also freezes its order.
	for id in _authored_part_depths:
		parts[id].position.z = float(_authored_part_depths[id])
	_front_attack_parts.clear()
	_draw_order_override = ""
	if str(definition.hero_id) != "leonhardt" or action not in ["attack_1", "attack_2"]: return
	var side := "left" if float(motion_profile.side) > 0.0 else "right"
	var top_depth := -INF
	var lead_depth := INF
	for id in _authored_part_depths:
		top_depth = maxf(top_depth, float(_authored_part_depths[id]))
	for id in [side + "_upper_arm", side + "_forearm", side + "_hand", side + "_shoulder", "weapon"]:
		if not parts.has(id): continue
		_front_attack_parts.append(id)
		lead_depth = minf(lead_depth, float(_authored_part_depths[id]))
	if _front_attack_parts.is_empty(): return
	# The swing crosses the chest and shield in screen space. Move the whole
	# articulated arm/equipment group in front with one shared depth translation;
	# its hand/weapon plane separation and grip geometry remain unchanged.
	var delta := maxf(0.0, top_depth + .0016 - lead_depth)
	for id in _front_attack_parts:
		parts[id].position.z = float(_authored_part_depths[id]) + delta
	_draw_order_override = "lead_arm_in_front"

func _ground_pose(action: String) -> void:
	_ground_offset = 0.0
	if not is_inside_tree(): return
	var minimum := INF
	var use_all := action == "death"
	for id in parts:
		if not use_all and id not in ["left_foot", "right_foot"]: continue
		var part: MeshInstance3D = parts[id]
		var transform := part.global_transform
		for point: Vector3 in _support_points.get(id, PackedVector3Array()):
			minimum = minf(minimum, (transform * point).y)
	var up_y := global_basis.y.y
	if not is_finite(minimum) or up_y < .01: return
	# Ground only the visual Root, leaving this node's world-foot anchor and the
	# source untouched. Use opaque painted outlines, not transparent quad corners.
	_ground_offset = clampf((global_position.y + .001 * global_basis.y.length() - minimum) / up_y, -.50, .50)
	joints.Root.position.y += _ground_offset

func _silhouette_support(entry: Dictionary, atlas: Image) -> PackedVector3Array:
	var result := PackedVector3Array()
	if atlas == null: return result
	var rect := Rect2i(int(entry.region[0]), int(entry.region[1]), int(entry.region[2]), int(entry.region[3]))
	var size := Vector2(float(entry.display_size[0]), float(entry.display_size[1]))
	var anchor := Vector2(float(entry.anchor[0]), float(entry.anchor[1]))
	var offset := _geometry_offset(entry)
	# Read-only alpha analysis at bind time. Ends of 21 sampled columns approximate
	# the actual painted outline even when a separated part rotates in a fall.
	for column in 21:
		var x := int(round(float(rect.size.x - 1) * float(column) / 20.0))
		var top := -1
		var bottom := -1
		for y in rect.size.y:
			if atlas.get_pixel(rect.position.x + x, rect.position.y + y).a > .15:
				if top < 0: top = y
				bottom = y
		if top < 0: continue
		for y in [top, bottom]:
			var local := (Vector2(float(x) / float(rect.size.x), float(y) / float(rect.size.y)) - anchor) * size + offset
			result.append(Vector3(local.x, -local.y, 0.0))
	return result

func _make_part(entry: Dictionary, texture: Texture2D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = "Part_" + str(entry.id)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var size := Vector2(float(entry.display_size[0]), float(entry.display_size[1]))
	var anchor := Vector2(float(entry.anchor[0]), float(entry.anchor[1]))
	var offset := _geometry_offset(entry)
	var low := -anchor * size + offset
	var high := low + size
	var region := Rect2(float(entry.region[0]), float(entry.region[1]), float(entry.region[2]), float(entry.region[3]))
	var atlas_size := texture.get_size()
	var uv_low := region.position / atlas_size
	var uv_high := region.end / atlas_size
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(low.x, -low.y, 0), Vector3(high.x, -low.y, 0), Vector3(high.x, -high.y, 0), Vector3(low.x, -high.y, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([uv_low, Vector2(uv_high.x, uv_low.y), uv_high, Vector2(uv_low.x, uv_high.y)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	part.mesh = mesh
	part.position.z = float(entry.get("z_order", 0)) * .0008
	part.rotation.z = -float(entry.get("rotation", 0.0))
	var material := ShaderMaterial.new()
	material.shader = PART_SHADER
	material.set_shader_parameter("source_texture", texture)
	material.set_shader_parameter("atlas_rect", Vector4(uv_low.x, uv_low.y, region.size.x / atlas_size.x, region.size.y / atlas_size.y))
	material.set_shader_parameter("atlas_texel", Vector2.ONE / atlas_size)
	# Paint already contains linework. Avoid thick outlines at overlapping joints.
	material.set_shader_parameter("outline_px", .40)
	material.set_shader_parameter("rim_strength", .06)
	# Ignore low-alpha matte left outside the painted shapes. With alpha scissor,
	# those faint values otherwise become opaque rectangular fragments.
	material.set_shader_parameter("alpha_cutoff", .12)
	part.material_override = material
	part.set_meta("part_id", str(entry.id))
	part.set_meta("atlas_region", region)
	part.set_meta("joint_anchor", anchor)
	_materials.append(material)
	return part

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_ready_parts = false
	source = null
	definition.clear()
	joints.clear()
	parts.clear()
	_rest_positions.clear()
	_support_points.clear()
	_authored_part_depths.clear()
	_front_attack_parts.clear()
	_draw_order_override = ""
	_materials.clear()
	_current_pose.clear()
	_transition_pose.clear()
	_last_debug.clear()
	_current_action = ""
	_sequence = -1
	_transition_time = 0.0
	action_time = 0.0
	motion_clock = 0.0
	gait_phase = 0.0
	_breath_phase = 0.0
	_hair = 0.0
	_cape = 0.0
	_hair_speed = 0.0
	_cape_speed = 0.0
	_last_distance = -1.0
	_was_active = false
	_ground_offset = 0.0
	rest_pose_preview = false
