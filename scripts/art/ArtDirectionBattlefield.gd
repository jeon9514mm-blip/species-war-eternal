extends "res://scripts/maps3d/Battlefield3DView.gd"
## Presentation-only field. The inherited sync_actor / projection / health layer
## continues to consume the exact production hunting world coordinates.
const MEADOW = preload("res://scripts/art/PainterlyMeadow.gd")
const LAB_CAMERA_OFFSET := Vector3(0, 30, 43)
var painterly_active := true
var comparison_button: Button
var scene_label: Label

func _ready() -> void:
	super._ready()
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
	scene_label.text = "밝은 초원 · 시범"
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
	scene_label.text = "밝은 초원 · 시범" if painterly_active else "현재 맵 · 비교 중"

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
	if overview_mode:
		_set_focus(Vector2(16, 10))
		camera.v_offset = 0
		camera.size = maxf(24, 40 / maxf(.1, size.x / size.y))
		return
	var frame: Dictionary = FRAMING.fit(camera_points(), size, sine)
	var next: Vector2 = frame.center
	if not snap and _camera_initialized:
		if focus.distance_to(next) < .18: next = focus
		else: next = focus.lerp(next, 1 - exp(-maxf(delta, 0) * 3))
	_set_focus(next)
	camera.v_offset = 0
	var required: float = FRAMING.size_at_center(frame.bounds, focus, size, sine)
	if snap or not _camera_initialized or required > camera.size: camera.size = required
	else: camera.size = lerpf(camera.size, required, 1 - exp(-maxf(delta, 0) * 1.8))
	_camera_initialized = true
