extends RefCounted
## Presentation-only atlas adapter for the meadow art pilot. The source
## MonsterSpriteController still owns animation completion, flash, fade, spawn
## scale and every combat event. Only the rendered Sprite3D's texture, offset
## and pixel size are replaced, after Battlefield3DView.sync_actor has run.
## Eight authored poses are NOT eight skeletal animations or a 3D monster rig.

const ART_ROOT := "res://assets/art-direction/pilot-01/monsters/"
const LAYOUT_PATH := ART_ROOT + "atlas-layout.json"
const COLUMNS := 4
const ROWS := 2
const POSE_COUNT := COLUMNS * ROWS
const SPECIES := {
	"초원 고블린": "meadow-goblin",
	"들개 무리": "meadow-hound",
	"가시 멧돼지": "bristle-boar",
	"바람 까마귀": "wind-crow",
}
const STATE_POSES := {
	"idle": [0, 1], "walk": [2, 3], "attack": [4, 5],
	"hit": [6], "death": [7],
}
const HEIGHT_FACTORS := {
	"초원 고블린": 0.80, "들개 무리": 0.64,
	"가시 멧돼지": 0.72, "바람 까마귀": 0.55,
}

var _layout: Dictionary = {}
var _entries: Dictionary = {}
var _frames: Dictionary = {}
var _actors: Dictionary = {}
var _sync_count := 0


func sync(field: Node, source: AnimatedSprite2D, rendered: Sprite3D,
		point: Vector2, delta: float, active: bool) -> void:
	if not is_instance_valid(source) or not is_instance_valid(rendered):
		return
	if not source is MonsterSpriteController:
		return
	var monster_name: String = source.pixel_monster_name
	var entry: Dictionary = _entry(monster_name)
	if entry.is_empty():
		return # Unsupported species keep the complete original renderer result.
	var id := source.get_instance_id()
	var running: bool = active and source.speed_scale > 0.0
	var state_name: String = str(source.state)
	var source_time: float = float(source._motion_time)
	var state: Dictionary = _actors.get(id, {})
	if state.is_empty() or str(state.get("species", "")) != monster_name:
		state = {
			"source": weakref(source), "species": monster_name,
			"rendered_id": rendered.get_instance_id(),
			"state": state_name, "clock": 0.0, "state_clock": 0.0,
			"source_time": source_time, "pose": _pose(source, state_name, 0.0),
			"idle_phase": fposmod(point.x * 0.19 + point.y * 0.13, 1.0),
		}
	# Comparison can run the battle while this helper is inactive. If it is
	# reopened while paused, reconcile a changed action without advancing time;
	# otherwise a cached walking pose could replace the current death pose.
	var restarted: bool = state_name != str(state.state) or source_time + 0.00001 < float(state.source_time) or int(state.rendered_id) != rendered.get_instance_id()
	if restarted:
		state.rendered_id = rendered.get_instance_id()
		state.state_clock = 0.0
		state.state = state_name
		state.source_time = source_time
		state.pose = _pose(source, state_name, 0.0)
	if running:
		# A repeated attack is observed above, never started or advanced here.
		var elapsed: float = maxf(delta, 0.0) * maxf(source.speed_scale, 0.0)
		state.clock = float(state.clock) + elapsed
		state.state_clock = float(state.state_clock) + elapsed
		state.state = state_name
		state.source_time = source_time
		var pose_clock: float = float(state.clock) + float(state.idle_phase) if state_name == "idle" else float(state.state_clock)
		state.pose = _pose(source, state_name, pose_clock)
	var pose: int = int(state.pose)
	var texture := frame_texture(monster_name, pose)
	if texture == null:
		return
	var cell: Vector2 = texture.region.size
	var anchor: Vector2 = entry.anchors[pose]
	var offset := Vector2(cell.x * 0.5 - anchor.x, anchor.y - cell.y * 0.5)
	# Sprite3D.flip_h mirrors its sampled art around the quad centre. Mirror
	# the horizontal anchor correction too, so asymmetric feet stay planted.
	if rendered.flip_h:
		offset.x = -offset.x
	rendered.texture = texture
	rendered.offset = offset
	# Native height is measured from one idle body, not from each pose's
	# varying bounds: attacks/deaths never resize the creature to fit a cell.
	# ArtDirectionBattlefield applies the species factor once in its visual
	# height hook, shared with health bars and target markers.
	var rendered_height: float = float(field._actor_height(source, false))
	rendered.pixel_size = rendered_height / float(entry.native_height)
	state.running = running
	state.frame_region = texture.region
	state.baseline = anchor
	state.native_height = float(entry.native_height)
	state.visual_height_factor = float(HEIGHT_FACTORS[monster_name])
	state.rendered_height = rendered_height
	state.cell = cell
	state.pixel_size = rendered.pixel_size
	state.rendered_offset = offset
	_actors[id] = state
	_sync_count += 1
	if _sync_count % 64 == 0:
		prune_invalid()


func _pose(source: AnimatedSprite2D, state_name: String, clock: float) -> int:
	match state_name:
		"walk":
			return 2 + int(floor(clock * 7.0)) % 2
		"attack":
			# Follow the existing controller's weighted frame progress so haste,
			# completion signals and attack cadence remain exactly as authored.
			return 4 if _animation_progress(source) < 0.42 else 5
		"hit":
			return 6
		"death":
			return 7
	return int(floor(clock * 1.6)) % 2


func _animation_progress(source: AnimatedSprite2D) -> float:
	var frames: SpriteFrames = source.sprite_frames
	if frames == null or not frames.has_animation(source.animation):
		return 0.0
	var count := frames.get_frame_count(source.animation)
	var total := 0.0
	var elapsed := 0.0
	for index in count:
		var weight := frames.get_frame_duration(source.animation, index)
		total += weight
		if index < source.frame:
			elapsed += weight
		elif index == source.frame:
			elapsed += weight * source.frame_progress
	return clampf(elapsed / maxf(total, 0.0001), 0.0, 1.0)


func _entry(monster_name: String) -> Dictionary:
	if not SPECIES.has(monster_name):
		return {}
	if _entries.has(monster_name):
		return _entries[monster_name]
	if _layout.is_empty():
		if not FileAccess.file_exists(LAYOUT_PATH):
			return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
		if not parsed is Dictionary:
			return {}
		_layout = parsed
	var slug: String = SPECIES[monster_name]
	var measured: Dictionary = _layout.get("species", {}).get(slug, {})
	var raw_anchors: Array = measured.get("anchors", [])
	if raw_anchors.size() != POSE_COUNT or float(measured.get("native_height", 0.0)) <= 0.0:
		return {}
	var path := ART_ROOT + slug + ".png"
	if not ResourceLoader.exists(path):
		return {}
	var atlas := load(path) as Texture2D
	if atlas == null:
		return {}
	var cell := atlas.get_size() / Vector2(COLUMNS, ROWS)
	var raw_regions: Array = measured.get("regions", [])
	var regions: Array[Rect2] = []
	var maximum_size := Vector2.ZERO
	for pose in POSE_COUNT:
		var region := Rect2(Vector2(pose % COLUMNS, int(pose / float(COLUMNS))) * cell, cell)
		if raw_regions.size() == POSE_COUNT:
			var value: Variant = raw_regions[pose]
			if not value is Array or value.size() != 4:
				return {}
			region = Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
		if not region.has_area() or not Rect2(Vector2.ZERO, atlas.get_size()).encloses(region):
			return {}
		regions.append(region)
		maximum_size = maximum_size.max(region.size)
	var anchors: Array[Vector2] = []
	for pose in POSE_COUNT:
		var value: Variant = raw_anchors[pose]
		if not value is Array or value.size() != 2:
			return {}
		var anchor := Vector2(float(value[0]), float(value[1]))
		# Airborne release/recoil poses may have a floor pivot just below the
		# cropped bitmap. Keep this authored gap; do not force toes to its edge.
		var floor_gap_limit: float = float(measured.native_height) * 0.12
		if anchor.x < 0.0 or anchor.y < 0.0 or anchor.x > regions[pose].size.x or anchor.y > regions[pose].size.y + floor_gap_limit:
			return {}
		anchors.append(anchor)
	var entry := {
		"name": monster_name, "slug": slug, "path": path,
		"atlas": atlas, "cell": cell, "anchors": anchors,
		"regions": regions, "maximum_frame_size": maximum_size,
		"native_height": float(measured.native_height),
		"alpha_bounds": measured.get("alpha_bounds", []),
	}
	_entries[monster_name] = entry
	return entry


func frame_texture(monster_name: String, pose: int) -> AtlasTexture:
	var entry := _entry(monster_name)
	if entry.is_empty():
		return null
	pose = clampi(pose, 0, POSE_COUNT - 1)
	var key := monster_name + ":" + str(pose)
	if _frames.has(key):
		return _frames[key]
	var texture := AtlasTexture.new()
	texture.atlas = entry.atlas
	texture.region = entry.regions[pose]
	texture.filter_clip = true
	_frames[key] = texture
	return texture


func supports(monster_name: String) -> bool:
	return not _entry(monster_name).is_empty()


func height_factor(monster_name: String) -> float:
	return float(HEIGHT_FACTORS.get(monster_name, 1.0))


func catalog() -> Dictionary:
	var result: Dictionary = {}
	for monster_name: String in SPECIES:
		var entry: Dictionary = _entry(monster_name)
		result[monster_name] = {
			"slug": SPECIES[monster_name], "available": not entry.is_empty(),
			"path": ART_ROOT + str(SPECIES[monster_name]) + ".png",
			"columns": COLUMNS, "rows": ROWS, "pose_count": POSE_COUNT,
			"state_poses": STATE_POSES.duplicate(true),
			"cell": entry.get("cell", Vector2.ZERO),
			"frame_regions": entry.get("regions", []).duplicate(),
			"maximum_frame_size": entry.get("maximum_frame_size", Vector2.ZERO),
			"native_height": entry.get("native_height", 0.0),
			"visual_height_factor": HEIGHT_FACTORS[monster_name],
			"anchors": entry.get("anchors", []).duplicate(),
			"alpha_bounds": entry.get("alpha_bounds", []).duplicate(true),
		}
	return result


func debug_state(source: AnimatedSprite2D) -> Dictionary:
	if not is_instance_valid(source):
		return {}
	var result: Dictionary = _actors.get(source.get_instance_id(), {}).duplicate(true)
	result.erase("source")
	return result


func cached_frame_count() -> int:
	return _frames.size()


func prune_invalid() -> void:
	for id in _actors.keys():
		var reference: WeakRef = _actors[id].source
		if not is_instance_valid(reference.get_ref()):
			_actors.erase(id)
