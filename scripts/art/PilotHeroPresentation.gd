extends RefCounted
## Leonhardt-only presentation adapter. Call AFTER Battlefield3DView.sync_actor.
## Reads the simulation's distance/velocity; writes only the rendered GPU pose and
## material. No actor state, 2D rig, combat clock, movement, save or RNG mutation.
const CONTOUR = preload("res://assets/art-direction/pilot-01/shaders/hero-contour.gdshader")
const TARGET_HERO := "leonhardt"
const STRIDE_DISTANCE := 1.40 # A complete left/right cycle in battle-world units.
const MAX_DISTANCE_DELTA := 1.0 # Reposition/load discontinuities never drive a step.
const STATE_META := "pilot_hero_internal"
const DEBUG_META := "pilot_hero_presentation"

func sync(field, source: AnimatedSprite2D, rendered: Sprite3D, point: Vector2, delta: float, active: bool) -> void:
	if not is_instance_valid(source) or not is_instance_valid(rendered): return
	if str(source.get("atlas_key")) != TARGET_HERO: return
	var skin = rendered.get_node_or_null("HeroSkeletalBillboard")
	if skin == null or not is_instance_valid(skin.rig): return
	var rig = skin.rig
	var skeleton: Skeleton3D = skin.bones_3d
	if not is_instance_valid(skeleton) or rig.rest_frame == null: return
	var movement := _movement_sample(field, point)
	var state: Dictionary = rendered.get_meta(STATE_META, {})
	if state.is_empty():
		state = _make_state(skin, movement, point)
		rendered.set_meta(STATE_META, state)
	var material: ShaderMaterial = state.material
	# Keep skin.surface as StandardMaterial3D: its production sync still updates it.
	skin.material_override = material
	material.set_shader_parameter("actor_tint", rendered.modulate)
	material.set_shader_parameter("facing_sign", -1.0 if source.flip_h else 1.0)
	var action: String = str(source.get("visual_action")) if source.has_method("play_visual") else str(source.get("state"))
	var alive := action != "death" and str(source.get("state")) != "death"
	var running := active and source.speed_scale > 0.0 and alive
	var dt := clampf(delta, 0.0, .1) if is_finite(delta) and running else 0.0
	var distance_delta := _distance_delta(state, movement, point)
	if not running or not bool(state.was_active): distance_delta = 0.0
	var locomotion := action in ["walk", "run"]
	var velocity: Vector2 = movement.velocity
	var speed := velocity.length()
	if dt > 0.0:
		state.clock = fposmod(float(state.clock) + dt, 600.0)
		state.breath_phase = fposmod(float(state.breath_phase) + dt * 2.05, TAU)
		if locomotion:
			state.gait_phase = fposmod(float(state.gait_phase) + distance_delta / STRIDE_DISTANCE * TAU, TAU)
		# Modest blend-in/out avoids a new pose snap when movement starts or ends.
		var gait_target := 1.0 if locomotion and (speed > .025 or distance_delta > .00001) else 0.0
		state.gait_weight = move_toward(float(state.gait_weight), gait_target, dt / .12)
		state.idle_weight = move_toward(float(state.idle_weight), 1.0 if action == "idle" else 0.0, dt / .16)
		var facing := -1.0 if source.flip_h else 1.0
		var target_lean := clampf(velocity.x * facing / 1.95, -1.0, 1.0) * .024 if locomotion else 0.0
		state.lean = lerpf(float(state.lean), target_lean, 1.0 - exp(-dt * 9.0))
		_update_secondary(state, rig, action, dt)
	state.was_active = running
	# The original source can still animate independently while a menu is open.
	# Only this adapter's additional clocks/secondary simulation are frozen here.
	if alive:
		_apply_pose(skeleton, rig, state, action)
	var atlas_size: Vector2 = rig.rest_frame.atlas.get_size()
	var region: Rect2 = rig.rest_frame.region
	var debug := {
		"hero_id": TARGET_HERO, "active": running, "clock": float(state.clock),
		"breath_phase": float(state.breath_phase), "gait_phase": float(state.gait_phase),
		"distance_delta": distance_delta, "movement_speed": speed,
		"distance_source": str(movement.kind), "gait_weight": float(state.gait_weight),
		"hair_angle": float(state.hair), "cape_angle": float(state.cape),
		"lean": float(state.lean), "source_action": action, "alive": alive,
		"outline_px": 1.05, "rim_strength": .18, "source_frame_size": region.size,
		"atlas_rect": Vector4(region.position.x / atlas_size.x, region.position.y / atlas_size.y, region.size.x / atlas_size.x, region.size.y / atlas_size.y),
		"gpu_bone_count": skeleton.get_bone_count(), "new_art_parts": 0,
		"source_state_modified": false, "source_rig_modified": false,
	}
	rendered.set_meta(DEBUG_META, debug)

func snapshot(rendered: Sprite3D) -> Dictionary:
	if not is_instance_valid(rendered): return {}
	return rendered.get_meta(DEBUG_META, {}).duplicate(true)

func _make_state(skin, movement: Dictionary, point: Vector2) -> Dictionary:
	var rig = skin.rig
	var material := ShaderMaterial.new()
	material.shader = CONTOUR
	var size: Vector2 = rig.rest_frame.atlas.get_size()
	var region: Rect2 = rig.rest_frame.region
	material.set_shader_parameter("source_texture", rig.rest_frame.atlas)
	material.set_shader_parameter("atlas_texel", Vector2.ONE / size)
	material.set_shader_parameter("atlas_rect", Vector4(region.position.x / size.x, region.position.y / size.y, region.size.x / size.x, region.size.y / size.y))
	return {"material": material, "clock": 0.0, "breath_phase": 0.0,
		"gait_phase": 0.0, "gait_weight": 0.0, "idle_weight": 0.0,
		"hair": 0.0, "hair_velocity": 0.0, "cape": 0.0, "cape_velocity": 0.0,
		"lean": 0.0, "last_distance": float(movement.distance),
		"last_point": point, "last_kind": str(movement.kind), "was_active": false}

func _movement_sample(field, point: Vector2) -> Dictionary:
	# Fallback remains read-only and world-space; projected source.position must
	# never drive gait because following/zooming the camera also changes it.
	var result := {"distance": 0.0, "velocity": Vector2.ZERO, "kind": "world_position"}
	if not is_instance_valid(field) or not is_instance_valid(field.game): return result
	var director = field.game.get("party_movement")
	if director == null: return result
	var distances: Dictionary = director.distance_walked
	var velocities: Dictionary = director.velocities
	if distances.has(TARGET_HERO):
		var walked := float(distances[TARGET_HERO])
		if is_finite(walked):
			result.distance = walked
			result.kind = "party_movement.distance_walked"
	var velocity: Vector2 = velocities.get(TARGET_HERO, Vector2.ZERO)
	if velocity.is_finite(): result.velocity = velocity
	return result

func _distance_delta(state: Dictionary, movement: Dictionary, point: Vector2) -> float:
	var distance := 0.0
	if str(state.last_kind) == str(movement.kind):
		if str(movement.kind) == "party_movement.distance_walked":
			distance = float(movement.distance) - float(state.last_distance)
		else:
			distance = point.distance_to(state.last_point)
	state.last_distance = float(movement.distance)
	state.last_point = point
	state.last_kind = str(movement.kind)
	if not is_finite(distance) or distance < 0.0 or distance > MAX_DISTANCE_DELTA: return 0.0
	return distance

func _update_secondary(state: Dictionary, rig, action: String, dt: float) -> void:
	var breath := float(state.breath_phase)
	var step := float(state.gait_phase)
	var weight := float(state.gait_weight)
	# Preserve the authored attack/guard gesture; the spring is an extra small
	# follow-through, not a replacement weapon animation or an independent cape.
	var gesture := float(rig.pose.get("Torso", 0.0)) + float(rig.pose.get("Chest", 0.0))
	var action_motion := gesture * .13 if action not in ["idle", "walk", "run"] else 0.0
	var hair_target := sin(breath - .58) * .010 + sin(step - .48) * weight * .020 - float(state.lean) * .48 - action_motion
	var cape_target := sin(breath - .98) * .013 - sin(step - .80) * weight * .035 - float(state.lean) * .85 - action_motion * 1.35
	# Small substeps keep the damped springs bounded after a slow rendered frame.
	var steps := maxi(1, int(ceil(dt / .012)))
	var step_dt := dt / float(steps)
	for _index in steps:
		_spring(state, "hair", hair_target, 150.0, 21.0, .070, step_dt)
		_spring(state, "cape", cape_target, 78.0, 14.0, .095, step_dt)

func _spring(state: Dictionary, key: String, target: float, stiffness: float, damping: float, limit: float, dt: float) -> void:
	var speed_key := key + "_velocity"
	var speed: float = float(state[speed_key]) + ((target - float(state[key])) * stiffness - float(state[speed_key]) * damping) * dt
	speed = clampf(speed, -.65, .65)
	state[key] = clampf(float(state[key]) + speed * dt, -limit, limit)
	state[speed_key] = speed

func _apply_pose(skeleton: Skeleton3D, rig, state: Dictionary, action: String) -> void:
	var body_height: float = rig.body_height
	var phase := float(state.gait_phase)
	var step := sin(phase)
	var fast := action == "run"
	var stride := .205 if fast else .155
	var gait := {
		"Pelvis": step * .024, "Torso": -step * .035 + float(state.lean),
		"Chest": -.022 if fast else -.010, "Head": step * .018 - float(state.lean) * .65,
		"LeftThigh": -step * stride, "RightThigh": step * stride,
		"LeftShin": maxf(step, 0.0) * .19, "RightShin": -maxf(-step, 0.0) * .19,
		"LeftFoot": -maxf(step, 0.0) * .095, "RightFoot": maxf(-step, 0.0) * .095,
		"LeftUpperArm": step * .085, "RightUpperArm": -step * .085,
		"LeftForearm": -absf(step) * .065, "RightForearm": absf(step) * .065,
	}
	var breath := sin(float(state.breath_phase))
	var idle := {"Torso": breath * .014, "Head": -breath * .009,
		"LeftUpperArm": breath * .016, "RightUpperArm": -breath * .016}
	# Only continuous states are replaced. Hits, dodges, death, casting and weapon
	# release keep their production authored timing and pose in full.
	var gait_weight := float(state.gait_weight) if action in ["idle", "walk", "run"] else 0.0
	var idle_weight := float(state.idle_weight) if action == "idle" else 0.0
	for index in rig.bone_names.size():
		var key: String = rig.bone_names[index]
		var bone: Bone2D = rig.bones[key]
		var angle: float = bone.rotation
		var position := Vector3(bone.position.x, -bone.position.y, 0.0)
		if gait.has(key): angle = lerpf(angle, float(gait[key]), gait_weight)
		if idle.has(key): angle = lerpf(angle, float(idle[key]), idle_weight)
		if key == "Root" and gait_weight > 0.0:
			# Keep the foot pivot in place. The smaller double-step bob comes from
			# travelled distance, instead of the old independent action timer.
			var lift := absf(step) * body_height * (.010 if fast else .006)
			position.y = lerpf(position.y, -bone.rest.origin.y + lift, gait_weight)
		if key == "Chest" and action in ["idle", "walk", "run"]:
			# Chest-only expansion avoids a whole-character float or face squash.
			position.y += breath * body_height * .0025
		if key == "Hair": angle += float(state.hair)
		if key == "Cape": angle += float(state.cape)
		skeleton.set_bone_pose_position(index, position)
		skeleton.set_bone_pose_rotation(index, Quaternion(Vector3.BACK, -angle))
