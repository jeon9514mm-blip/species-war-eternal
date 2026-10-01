extends "res://scripts/HeroSpriteController.gd"
## Visual-only adapter: one approved pose, affine motion, not new authored action poses.
const VISUALS = preload("res://scripts/sd/SDHeroVisuals.gd")
func configure_sd(hero_id: String) -> void:
	atlas_key = hero_id
	sheet_layout = "sd_v36_single_pose"
	sprite_sheet = VISUALS.sheet(hero_id)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material = null
	_build_sprite_frames()
	play_state("idle", "right")
func _build_sprite_frames() -> void:
	if sprite_sheet == null:
		_frames_ready = false
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var textures: Array[Texture2D] = []
	for index in 7:
		var tile := AtlasTexture.new()
		tile.atlas = sprite_sheet
		tile.region = Rect2(index * 256, 0, 256, 256)
		tile.filter_clip = true
		textures.append(tile)
	for facing: String in DIRECTIONS:
		for action: String in STATES:
			var columns: Array = [0, 1]
			var fps: float = 3.0
			match action:
				"walk": columns = [2, 3]; fps = 8.0
				"attack": columns = [0, 4, 0]; fps = 10.0
				"hit": columns = [5, 0]; fps = 10.0
				"death": columns = [6]; fps = 6.0
			var key: String = "%s_%s" % [action, facing]
			frames.add_animation(key)
			frames.set_animation_speed(key, fps)
			frames.set_animation_loop(key, action in ["idle", "walk"])
			for index: int in columns:
				frames.add_frame(key, textures[index])
	sprite_frames = frames
	centered = false
	offset = Vector2(-128, -248)
	native_visual_height = VISUALS.native_height(atlas_key)
	_frames_ready = true
func play_state(next_state: String, next_direction := "") -> void:
	super.play_state(next_state, next_direction)
	flip_h = direction == "left"
