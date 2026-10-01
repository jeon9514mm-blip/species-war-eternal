extends AnimatedSprite2D
class_name HeroSpriteController

## 4x4 sprite sheet layout:
## rows: down, left, right, up
## columns: idle_1, idle_2, walk_1, walk_2
@export var sprite_sheet: Texture2D
@export var frame_columns: int = 4
@export var frame_rows: int = 4
@export var default_direction: String = "down"
@export var auto_play: bool = true

const DIRECTIONS := ["down", "left", "right", "up"]
const STATES := ["idle", "walk", "attack", "hit", "death"]

var direction := "down"
var state := "idle"
var _frames_ready := false
var sheet_layout := "legacy"
var atlas_key := ""
var native_visual_height := 0.0
var _death_time := 0.0
var _hit_flash_time := 0.0

signal action_finished(action_name: String)

func _ready() -> void:
	if not default_direction.is_empty() and default_direction in DIRECTIONS:
		direction = default_direction
	_build_sprite_frames()
	animation_finished.connect(_on_animation_finished)
	if auto_play:
		play_state("idle", direction)

func set_sprite_sheet(texture: Texture2D) -> void:
	sprite_sheet = texture
	_build_sprite_frames()
	play_state(state, direction)

func set_bright_sheet(texture: Texture2D, hero_id: String) -> void:
	sheet_layout = "bright"
	atlas_key = hero_id
	set_sprite_sheet(texture)

func set_animation_atlas(texture: Texture2D, hero_id: String) -> bool:
	if HeroAnimationAtlas.layout(texture, hero_id).is_empty():
		return false
	sheet_layout = "heroes_v31"
	atlas_key = hero_id
	set_sprite_sheet(texture)
	return _frames_ready

func get_visual_height() -> float:
	if sheet_layout == "bright" and _frames_ready and sprite_frames.has_animation(animation):
		var current := sprite_frames.get_frame_texture(animation, frame) as AtlasTexture
		if current != null:
			return (current.region.size.y - 6.0) * absf(scale.y)
	return native_visual_height * absf(scale.y)

func get_head_offset() -> Vector2:
	return Vector2(0, -get_visual_height())

func get_foot_offset() -> Vector2:
	return Vector2.ZERO

func set_direction(next_direction: String) -> void:
	if next_direction in DIRECTIONS and next_direction != direction:
		direction = next_direction
		play_state(state, direction)

func set_direction_from_vector(velocity: Vector2) -> void:
	if velocity.length_squared() < 0.01:
		return
	if abs(velocity.x) > abs(velocity.y):
		set_direction("right" if velocity.x > 0.0 else "left")
	else:
		set_direction("down" if velocity.y > 0.0 else "up")

func play_state(next_state: String, next_direction := "") -> void:
	if next_direction in DIRECTIONS:
		direction = next_direction
	var next: String = next_state if next_state in STATES else "idle"
	if next != state:
		_death_time = 0.0
		_hit_flash_time = 0.18 if next == "hit" else 0.0
	state = next
	if sheet_layout == "heroes_v31":
		# The source has a three-quarter right pose. Vertical travel keeps that
		# pose; it is deliberately not described as a four-direction sheet.
		flip_h = direction == "left"
	if state != "death":
		modulate.a = 1.0
	if not _frames_ready:
		return
	var animation_name := "%s_%s" % [state, direction]
	if sprite_frames.has_animation(animation_name):
		if animation == animation_name and is_playing():
			return
		play(animation_name)

func play_idle(next_direction := "") -> void:
	play_state("idle", next_direction)

func play_walk(velocity := Vector2.ZERO) -> void:
	set_direction_from_vector(velocity)
	play_state("walk", direction)

func play_attack(next_direction := "") -> void:
	play_state("attack", next_direction)

func play_hit(next_direction := "") -> void:
	play_state("hit", next_direction)

func play_death(next_direction := "") -> void:
	play_state("death", next_direction)

func _on_animation_finished() -> void:
	if state == "attack" or state == "hit":
		action_finished.emit(state)
		play_idle(direction)

func _process(delta: float) -> void:
	var visual_delta := delta * absf(speed_scale)
	_hit_flash_time = maxf(0.0, _hit_flash_time - visual_delta)
	self_modulate = Color("#ffb0b0") if _hit_flash_time > 0.0 else Color.WHITE
	if state == "death":
		_death_time += visual_delta
		modulate.a = maxf(0.12, 1.0 - _death_time * 1.7)

func _build_sprite_frames() -> void:
	if sprite_sheet == null:
		_frames_ready = false
		return
	if frame_columns <= 0 or frame_rows <= 0:
		_frames_ready = false
		return
	if sheet_layout == "bright" and BrightSpriteAtlasLayout.REGIONS.has(atlas_key):
		_build_bright_frames()
		return
	if sheet_layout == "heroes_v31":
		_build_animation_atlas_frames()
		return
	var atlas_size := sprite_sheet.get_size()
	var frame_size := Vector2(atlas_size.x / float(frame_columns), atlas_size.y / float(frame_rows))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in frame_rows:
		var direction_name: String = DIRECTIONS[row] if row < DIRECTIONS.size() else "down"
		var idle_name := "idle_%s" % direction_name
		var walk_name := "walk_%s" % direction_name
		var attack_name := "attack_%s" % direction_name
		var hit_name := "hit_%s" % direction_name
		var death_name := "death_%s" % direction_name
		_add_animation(frames, idle_name, row, [0, 1], 3.0, true, frame_size)
		_add_animation(frames, walk_name, row, [2, 3, 2, 1], 8.0, true, frame_size)
		_add_animation(frames, attack_name, row, [2, 3, 2, 1], 12.0, false, frame_size)
		_add_animation(frames, hit_name, row, [0, 3, 0], 10.0, false, frame_size)
		_add_animation(frames, death_name, row, [0, 1, 2, 3], 6.0, false, frame_size)
	sprite_frames = frames
	_frames_ready = true
	_align_legacy_feet(frame_size)

func _build_bright_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var rows := ["down", "right", "up", "left"]
	for row in 4:
		for action in STATES:
			var columns: Array = [0]
			if action == "walk":
				columns = [1, 2]
			elif action == "attack":
				columns = [0, 3, 0]
			var animation_name: String = "%s_%s" % [action, rows[row]]
			frames.add_animation(animation_name)
			frames.set_animation_speed(animation_name, 9.0 if action == "walk" else 10.0)
			frames.set_animation_loop(animation_name, action in ["idle", "walk"])
			for column in columns:
				frames.add_frame(animation_name, BrightSpriteAtlasLayout.frame_texture(sprite_sheet, atlas_key, row * 4 + int(column)))
	var canvas := BrightSpriteAtlasLayout.canvas_size(atlas_key)
	centered = false
	offset = Vector2(-canvas.x * 0.5, -canvas.y + 5.0)
	native_visual_height = float(BrightSpriteAtlasLayout.REGIONS[atlas_key][0].size.y - 6)
	sprite_frames = frames
	_frames_ready = true

func _build_animation_atlas_frames() -> void:
	var data := HeroAnimationAtlas.layout(sprite_sheet, atlas_key)
	if data.is_empty():
		_frames_ready = false
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var textures: Array = data["frames"]
	for facing in DIRECTIONS:
		for action in STATES:
			var columns: Array = [0]
			if action == "walk":
				columns = [1, 2]
			elif action == "attack":
				columns = [0, 3, 0]
			var animation_name := "%s_%s" % [action, facing]
			frames.add_animation(animation_name)
			frames.set_animation_speed(animation_name, 8.0 if action == "walk" else 10.0)
			frames.set_animation_loop(animation_name, action in ["idle", "walk"])
			for column in columns:
				frames.add_frame(animation_name, textures[int(column)])
	centered = false
	offset = -Vector2(data["canvas_pivot"])
	native_visual_height = float(data["visual_height"])
	sprite_frames = frames
	_frames_ready = true

func _align_legacy_feet(frame_size: Vector2) -> void:
	var image := sprite_sheet.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	var first := image.get_region(Rect2i(Vector2i.ZERO, Vector2i(frame_size)))
	var bounds := first.get_used_rect()
	native_visual_height = bounds.size.y
	centered = false
	offset = -Vector2(bounds.position) - Vector2(bounds.size.x * 0.5, bounds.size.y)

func _add_animation(frames: SpriteFrames, animation_name: String, row: int, columns: Array, speed: float, looped: bool, frame_size: Vector2) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, looped)
	for column in columns:
		var atlas := AtlasTexture.new()
		atlas.atlas = sprite_sheet
		atlas.region = Rect2(Vector2(column, row) * frame_size, frame_size)
		frames.add_frame(animation_name, atlas)
