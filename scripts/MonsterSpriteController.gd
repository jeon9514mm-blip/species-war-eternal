extends AnimatedSprite2D
class_name MonsterSpriteController

## Supports a future atlas sprite sheet and the current single-image monster art.
## With a single image, idle/attack/hit/death are rendered through lightweight
## procedural motion so the existing assets are immediately animated in-game.
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
var _single_image_mode := false
var _base_scale := Vector2.ONE
var _base_position := Vector2.ZERO
var _motion_time := 0.0
var visual_state_time := 0.0
var _hit_flash_time := 0.0
var spawn_scale := 1.0
var sheet_layout := "legacy"
var atlas_column := -1
var native_visual_height := 0.0
var pixel_monster_name := ""
var presentation_scale := Vector2(0.12, 0.12)

signal action_finished(action_name: String)

func _ready() -> void:
	_base_scale = scale
	_base_position = position
	_build_sprite_frames()
	animation_finished.connect(_on_animation_finished)
	if auto_play:
		play_state("idle", direction)

func set_sprite_sheet(texture: Texture2D) -> void:
	sprite_sheet = texture
	_build_sprite_frames()
	play_state(state, direction)

func set_bright_sheet(texture: Texture2D, column: int) -> void:
	sheet_layout = "bright"
	atlas_column = column
	set_sprite_sheet(texture)

func set_pixel_sheet(texture: Texture2D, monster_name: String) -> void:
	sheet_layout = "pixel_v32"
	pixel_monster_name = monster_name
	set_sprite_sheet(texture)

func set_casual_sheet(texture: Texture2D, monster_name: String) -> void:
	sheet_layout = "casual_v58"
	pixel_monster_name = monster_name
	set_sprite_sheet(texture)

func set_presentation_scale(value: Vector2) -> void:
	_base_scale = value
	scale = value * spawn_scale

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

func set_world_position(value: Vector2) -> void:
	_base_position = value
	if _single_image_mode:
		_apply_single_image_motion()
	else:
		position = value

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
	var direction_changed: bool = next_direction in DIRECTIONS and next_direction != direction
	if next_direction in DIRECTIONS:
		direction = next_direction
	var resolved_state: String = next_state if next_state in STATES else "idle"
	if resolved_state == state and not direction_changed and animation == "%s_%s" % [state, direction] and is_playing():
		return
	state = resolved_state
	visual_state_time = 0.0
	_motion_time = 0.0
	if sheet_layout in ["bright", "pixel_v32", "casual_v58"]:
		flip_h = direction == "left"
	if state != "death":
		modulate.a = 1.0
	if state == "hit":
		_hit_flash_time = 0.18
	if _frames_ready:
		var animation_name := "%s_%s" % [state, direction]
		if sprite_frames.has_animation(animation_name):
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
	# Single-image action duration is driven by elapsed time, not its one frame.
	if _single_image_mode:
		return
	if state == "attack" or state == "hit":
		action_finished.emit(state)
		play_idle(direction)

func _process(delta: float) -> void:
	# Main pauses animation with speed_scale = 0; visual timers must pause too.
	if speed_scale <= 0.0:
		return
	var visual_delta := delta * absf(speed_scale)
	_motion_time += visual_delta
	visual_state_time += visual_delta
	if _single_image_mode:
		var duration := 0.30 if state == "attack" else 0.22
		if state in ["attack", "hit"] and _motion_time >= duration:
			var finished := state
			play_idle(direction)
			action_finished.emit(finished)
		_apply_single_image_motion()
	elif sheet_layout in ["bright", "pixel_v32", "casual_v58"]:
		scale = _base_scale * spawn_scale
	if state == "death":
		modulate.a = maxf(0.08, 1.0 - _motion_time * 1.8)
	if _hit_flash_time > 0.0:
		_hit_flash_time -= visual_delta
		self_modulate = Color("#ffb0b0") if int(_hit_flash_time * 30.0) % 2 == 0 else Color.WHITE
	elif self_modulate != Color.WHITE:
		self_modulate = Color.WHITE

func _apply_single_image_motion() -> void:
	var next_scale := _base_scale * spawn_scale
	var offset := Vector2.ZERO
	match state:
		"idle":
			offset.y = sin(_motion_time * 3.0) * 3.0
			next_scale *= 1.0 + sin(_motion_time * 3.0) * 0.015
		"walk":
			offset.y = abs(sin(_motion_time * 8.0)) * -4.0
			next_scale *= 1.0 + sin(_motion_time * 8.0) * 0.02
		"attack":
			var facing := -1.0 if direction == "left" else 1.0
			offset.x = sin(min(_motion_time * 18.0, PI)) * 14.0 * facing
			next_scale *= 1.0 + sin(min(_motion_time * 18.0, PI)) * 0.08
		"hit":
			offset.x = sin(_motion_time * 45.0) * 5.0
		"death":
			next_scale.y = _base_scale.y * max(0.1, 1.0 - _motion_time * 1.7)
	position = _base_position + offset
	scale = next_scale

func _build_sprite_frames() -> void:
	if sprite_sheet == null:
		_frames_ready = false
		_single_image_mode = false
		return
	if sheet_layout == "bright" and atlas_column >= 0:
		_build_bright_frames()
		return
	if sheet_layout == "pixel_v32" and MonsterPixelAtlasLayout.has_monster(pixel_monster_name):
		_build_pixel_frames()
		return
	if sheet_layout == "casual_v58" and preload('res://scripts/portrait/CasualMonsterAtlas.gd').has_monster(pixel_monster_name):
		_build_casual_frames()
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	if frame_columns <= 1 or frame_rows <= 1:
		_single_image_mode = true
		for direction_name in DIRECTIONS:
			for state_name in STATES:
				_add_single_frame_animation(frames, "%s_%s" % [state_name, direction_name])
	else:
		_single_image_mode = false
		var atlas_size := sprite_sheet.get_size()
		var frame_size := Vector2(atlas_size.x / float(frame_columns), atlas_size.y / float(frame_rows))
		for row in frame_rows:
			var direction_name: String = DIRECTIONS[row] if row < DIRECTIONS.size() else "down"
			_add_atlas_animation(frames, "idle_%s" % direction_name, row, [0, 1], 3.0, true, frame_size)
			_add_atlas_animation(frames, "walk_%s" % direction_name, row, [2, 3, 2, 1], 8.0, true, frame_size)
			_add_atlas_animation(frames, "attack_%s" % direction_name, row, [1, 2, 1, 0], 12.0, false, frame_size)
			_add_atlas_animation(frames, "hit_%s" % direction_name, row, [0, 1, 0], 10.0, false, frame_size)
			_add_atlas_animation(frames, "death_%s" % direction_name, row, [0, 1, 2, 3], 6.0, false, frame_size)
	sprite_frames = frames
	_frames_ready = true
	_align_legacy_feet()

func _build_bright_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction_name in DIRECTIONS:
		for action in STATES:
			var rows: Array = [0]
			if action == "walk":
				rows = [1, 2]
			elif action == "attack":
				rows = [0, 3, 0]
			var animation_name: String = "%s_%s" % [action, direction_name]
			frames.add_animation(animation_name)
			frames.set_animation_speed(animation_name, 8.0 if action == "walk" else 10.0)
			frames.set_animation_loop(animation_name, action in ["idle", "walk"])
			for row in rows:
				frames.add_frame(animation_name, BrightSpriteAtlasLayout.frame_texture(sprite_sheet, "monsters", int(row) * 6 + atlas_column, atlas_column))
	var canvas := BrightSpriteAtlasLayout.canvas_size("monsters", atlas_column)
	centered = false
	offset = Vector2(-canvas.x * 0.5, -canvas.y + 5.0)
	native_visual_height = float(BrightSpriteAtlasLayout.REGIONS["monsters"][atlas_column].size.y - 6)
	_single_image_mode = false
	sprite_frames = frames
	_frames_ready = true

func _build_pixel_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction_name in DIRECTIONS:
		for action in STATES:
			var poses: Array = [0]
			if action == "walk":
				poses = [1, 2]
			elif action == "attack":
				poses = [0, 3, 0]
			var animation_name: String = "%s_%s" % [action, direction_name]
			frames.add_animation(animation_name)
			frames.set_animation_speed(animation_name, 8.0 if action == "walk" else 10.0)
			frames.set_animation_loop(animation_name, action in ["idle", "walk"])
			for pose in poses:
				frames.add_frame(animation_name, MonsterPixelAtlasLayout.frame_texture(sprite_sheet, pixel_monster_name, int(pose)))
	var canvas := MonsterPixelAtlasLayout.canvas_size(pixel_monster_name)
	centered = false
	offset = Vector2(-canvas.x * 0.5, -canvas.y + 4.0)
	native_visual_height = float(MonsterPixelAtlasLayout.PROFILES[pixel_monster_name]["idle_visual_height"])
	_single_image_mode = false
	sprite_frames = frames
	_frames_ready = true

func _build_casual_frames() -> void:
	var source:=preload('res://scripts/portrait/CasualMonsterAtlas.gd')
	var four_pose: bool=source.uses_four_pose_sheet(pixel_monster_name)
	var frames:=SpriteFrames.new()
	frames.remove_animation('default')
	for direction_name in DIRECTIONS:
		for action in STATES:
			var poses: Array=[0]
			if action=='walk':poses=[1,0] if four_pose else [1,2]
			elif action=='attack':poses=[0,2,0] if four_pose else [0,3,0]
			elif four_pose and action in ['hit','death']:poses=[3]
			var animation_name: String='%s_%s'%[action,direction_name]
			frames.add_animation(animation_name)
			frames.set_animation_speed(animation_name,8.0 if action=='walk' else 10.0)
			frames.set_animation_loop(animation_name,action in ['idle','walk'])
			for pose in poses:frames.add_frame(animation_name,source.frame(pixel_monster_name,int(pose)))
	var sheet_profile: Dictionary=MonsterPixelAtlasLayout.PROFILES[pixel_monster_name]
	var canvas: Vector2=sprite_sheet.get_size()/(Vector2(2,2) if four_pose else Vector2(float(sheet_profile['columns']),4.0))
	centered=false
	offset=Vector2(-canvas.x*.5,-canvas.y+4.0)
	native_visual_height=canvas.y*.84
	_single_image_mode=false
	sprite_frames=frames
	_frames_ready=true

func _align_legacy_feet() -> void:
	var image := sprite_sheet.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	if not _single_image_mode:
		image = image.get_region(Rect2i(Vector2i.ZERO, Vector2i(sprite_sheet.get_size() / Vector2(frame_columns, frame_rows))))
	var bounds := image.get_used_rect()
	native_visual_height = bounds.size.y
	centered = false
	offset = -Vector2(bounds.position) - Vector2(bounds.size.x * 0.5, bounds.size.y)

func _add_single_frame_animation(frames: SpriteFrames, animation_name: String) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, 8.0)
	frames.set_animation_loop(animation_name, animation_name.begins_with("idle"))
	frames.add_frame(animation_name, sprite_sheet)

func _add_atlas_animation(frames: SpriteFrames, animation_name: String, row: int, columns: Array, speed: float, looped: bool, frame_size: Vector2) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, looped)
	for column in columns:
		var atlas := AtlasTexture.new()
		atlas.atlas = sprite_sheet
		atlas.region = Rect2(Vector2(column, row) * frame_size, frame_size)
		frames.add_frame(animation_name, atlas)
