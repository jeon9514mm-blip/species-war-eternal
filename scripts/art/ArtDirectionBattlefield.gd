extends "res://scripts/maps3d/Battlefield3DView.gd"
## Presentation-only field. The inherited sync_actor / projection / health layer
## continues to consume the exact production hunting world coordinates.
const MEADOW = preload("res://scripts/art/PainterlyMeadow.gd")
const BACKDROP = preload("res://scripts/art/LayeredMeadowBackdrop.gd")
const LAB_CAMERA_OFFSET := Vector3(0, 18, 48)
const HORIZON_RATIO := .285
var painterly_active := true
var comparison_button: Button
var scene_label: Label
var backdrop: Control

func _ready() -> void:
	super._ready()
	backdrop = BACKDROP.new()
	add_child(backdrop)
	move_child(backdrop, 0)
	backdrop.bind(self)
	_switch_art(true)
	comparison_button = preload("res://scripts/portrait/PortraitSkin.gd").button("원래 맵과 비교", _toggle_art)
	comparison_button.name = "ArtDirectionCompare"
	comparison_button.add_theme_font_size_override("font_size", 14)
	comparison_button.position = Vector2(10, 10)
	comparison_button.size = Vector2(160, 38)
	comparison_button.z_index = 80
	add_child(comparison_button)
	scene_label = Label.new()
	scene_label.name = "ArtDirectionSceneLabel"
	scene_label.text = "빛바람 초원 · 패럴랙스 시범"
	scene_label.position = Vector2(14, 53)
	scene_label.add_theme_font_size_override("font_size", 18)
	scene_label.add_theme_color_override("font_color", Color("eef4de"))
	scene_label.add_theme_color_override("font_outline_color", Color("263d30"))
	scene_label.add_theme_constant_override("outline_size", 5)
	scene_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_label.z_index = 80
	add_child(scene_label)

func _toggle_art() -> void:
	_switch_art(not painterly_active)
	comparison_button.text = "원래 맵과 비교" if painterly_active else "새 초원으로 복귀"
	scene_label.text = "빛바람 초원 · 패럴랙스 시범" if painterly_active else "현재 맵 · 비교 중"

func _switch_art(painterly: bool) -> void:
	# The optional comparison replaces rendering nodes only. Never call any
	# encounter/wave initializer or consume the gameplay random generator here.
	actors.clear()
	if is_instance_valid(map_root):
		if bool(map_root.get_meta("art_lab_map", false)):
			viewport_3d.remove_child(map_root)
			map_root.queue_free()
		else:
			map_loader.unload_map(viewport_3d)
	painterly_active = painterly
	viewport_3d.transparent_bg = painterly
	if is_instance_valid(backdrop): backdrop.set_active(painterly)
	if painterly:
		map_root = Node3D.new()
		map_root.name = "PainterlyMeadowMap"
		map_root.set_meta("art_lab_map", true)
		var arena := MEADOW.new()
		arena.name = "Arena"
		map_root.add_child(arena)
		viewport_3d.add_child(map_root)
	else:
		map_root = map_loader.load_zone(zone_id, viewport_3d, false)
	world = map_root.get_node("Arena")
	camera = world.get_node("BattleCamera")
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	_camera_initialized = false
	_apply_battle_contrast()
	_resize_world()

func _set_focus(point: Vector2) -> void:
	if not painterly_active:
		super._set_focus(point)
		return
	focus = point
	var target := Vector3(point.x, 0, point.y)
	camera.position = target + LAB_CAMERA_OFFSET
	camera.look_at(target)

func _update_hunt_camera(delta: float, snap := false) -> void:
	if not painterly_active:
		super._update_hunt_camera(delta, snap)
		return
	if not is_instance_valid(camera) or size.x < 1 or size.y < 1: return
	var sine := LAB_CAMERA_OFFSET.normalized().y
	var frame := _layered_frame(sine, overview_mode)
	var next: Vector2 = frame.center
	if not snap and _camera_initialized:
		if focus.distance_to(next) < .18: next = focus
		else: next = focus.lerp(next, 1 - exp(-maxf(delta, 0) * 3))
	_set_focus(next)
	var safe := safe_play_rect()
	var required: float = FRAMING.size_at_center(frame.bounds, focus, safe.size, sine) * size.y / safe.size.y
	if snap or not _camera_initialized or required > camera.size: camera.size = required
	else: camera.size = lerpf(camera.size, required, 1 - exp(-maxf(delta, 0) * 1.8))
	# Move the optical centre upward: all actors share this actual camera, while
	# their safe screen band moves down to make room for sky and distant layers.
	camera.v_offset = (safe.get_center().y / size.y - .5) * camera.size
	_camera_initialized = true
	_sync_layers(delta)

func safe_play_rect() -> Rect2:
	return Rect2(Vector2(24, size.y * .31), Vector2(maxf(1,size.x - 48), size.y * .65))

func _layered_frame(sine: float, overview: bool) -> Dictionary:
	var points := camera_points()
	if overview:
		points.append(Vector3(0, 3.4, 0))
		points.append(Vector3(32, 0, 20))
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for point: Vector3 in points:
		var plane := Vector2(point.x,point.z*sine-point.y)
		low = low.min(plane)
		high = high.max(plane)
	if points.is_empty():
		low = Vector2(16,10*sine) - Vector2(24,10.5)*.5
		high = low + Vector2(24,10.5)
	var center := (low+high)*.5
	var span := (high-low+Vector2(3.6,2.5)).max(Vector2(24,10.5))
	return {"center":Vector2(center.x,center.y/sine),"bounds":Rect2(center-span*.5,span)}

func _sync_layers(delta: float) -> void:
	if not painterly_active or not is_instance_valid(camera): return
	if is_instance_valid(backdrop): backdrop.sync_camera(focus,delta)
	if is_instance_valid(world) and world.has_method("set_horizon_z"):
		# This is a real ground-plane intersection. Backdrop meets the y=0 floor
		# at the same camera ray used by damage effects, feet and hit markers.
		world.set_horizon_z(local_to_world(Vector2(size.x*.5,size.y*HORIZON_RATIO)).y)
