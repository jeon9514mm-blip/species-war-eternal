extends RefCounted
## Floor-space contact and a bounded dust pool. No simulation RNG or actor writes.
const SHADER = preload("res://assets/art-direction/pilot-01/shaders/contact-shadow.gdshader")
const MAX_DUST := 16
const STEP_DISTANCE := .70
var _tracks: Dictionary = {}
var _dust: Array[Dictionary] = []
var _world: Node3D
var emitted := 0

func tick(world: Node3D, delta: float, active: bool) -> void:
	if _world != world:
		for puff in _dust:
			if is_instance_valid(puff.node): puff.node.queue_free()
		_dust.clear()
		_tracks.clear()
		_world = world
	if not active: return
	for index in range(_dust.size() - 1, -1, -1):
		var puff: Dictionary = _dust[index]
		if not is_instance_valid(puff.node):
			_dust.remove_at(index)
			continue
		puff.age += clampf(delta, 0, .1)
		var progress: float = puff.age / .38
		if progress >= 1:
			puff.node.queue_free()
			_dust.remove_at(index)
			continue
		puff.node.scale = Vector3.ONE * lerpf(.65, 1.5, progress)
		puff.node.material_override.set_shader_parameter("shadow_color", Color(.67, .64, .43, .18 * (1 - progress)))

func sync(source: AnimatedSprite2D, rendered: Sprite3D, point: Vector2, hero: bool, active: bool) -> void:
	var shadow := rendered.get_node_or_null("ContactShadow") as MeshInstance3D
	if shadow == null: return
	if not shadow.mesh is PlaneMesh:
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.36, .90) if hero else Vector2(1.40, .94)
		shadow.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = SHADER
		shadow.material_override = material
	# Billboard mode affects the sprite shader, not the floor-space child node.
	# Set world Y explicitly so root bobbing never lifts the contact patch.
	shadow.global_position = Vector3(point.x, -.008, point.y)
	var strength: float = .42 if hero else .34
	shadow.material_override.set_shader_parameter("shadow_color", Color(.055, .08, .045, strength * source.modulate.a))
	shadow.set_meta("pilot_ground_contact", true)
	var id := source.get_instance_id()
	if not _tracks.has(id): _tracks[id] = {"position": point, "distance": 0.0, "side": 1.0}
	var track: Dictionary = _tracks[id]
	var travel: float = point.distance_to(track.position)
	track.position = point
	if not active or not hero or source.state not in ["walk", "run"] or source.speed_scale <= 0 or travel > 2:
		track.distance = 0.0
		return
	track.distance += travel
	if track.distance >= STEP_DISTANCE:
		track.distance = fmod(track.distance, STEP_DISTANCE)
		track.side *= -1
		_emit(point + Vector2(.13 * float(track.side), .05))

func _emit(point: Vector2) -> void:
	if not is_instance_valid(_world) or _dust.size() >= MAX_DUST: return
	var puff := MeshInstance3D.new()
	puff.name = "PilotFootDust"
	var plane := PlaneMesh.new()
	plane.size = Vector2(.50, .35)
	puff.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("shadow_color", Color(.67, .64, .43, .18))
	puff.material_override = material
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(puff)
	puff.position = Vector3(point.x, -.004, point.y)
	_dust.append({"node": puff, "age": 0.0})
	emitted += 1

func prune(live_ids: Dictionary) -> void:
	for id in _tracks.keys():
		if not live_ids.has(id): _tracks.erase(id)

func debug_state() -> Dictionary:
	return {"dust_count": _dust.size(), "dust_cap": MAX_DUST, "emitted": emitted, "tracked_actors": _tracks.size()}
