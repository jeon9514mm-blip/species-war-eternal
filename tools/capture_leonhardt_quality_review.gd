extends SceneTree
## Large, honest master-vs-rig comparison rendered by Godot. The left panel is
## explicitly static; the right uses the same independent parts as the pilot.
const CATALOG = preload("res://scripts/art/HeroPartsCatalog.gd")
const RIG = preload("res://scripts/art/HeroPartsRig3D.gd")
const FACTORY = preload("res://scripts/HeroSpriteFactory.gd")
const FONT = preload("res://scripts/UIFontProvider.gd")
const OUTPUT := "res://checks/aurelia-four-head/leonhardt-v2/"
const VIEW_SIZE := Vector2i(604, 586)
var page: Control
var world: Node3D
var camera: Camera3D
var source: AnimatedSprite2D
var rig: Node3D
var subtitle: Label
var definition: Dictionary
var records: Array[Dictionary] = []
var action := "idle"
var duration := 1.0
var stage_size := VIEW_SIZE
var locked_camera_size := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Quality review requires the real display renderer")
		quit(1)
		return
	definition = CATALOG.load_definition("leonhardt", true)
	if definition.is_empty():
		push_error("Leonhardt's separated art did not validate")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if "--movie" in OS.get_cmdline_user_args(): stage_size = Vector2i(922, 586)
	_build()
	await _settle(8)
	if "--movie" in OS.get_cmdline_user_args():
		await _movie()
	else:
		_set_action("idle")
		if not rig.has_method("set_rest_pose"):
			push_error("Neutral review requires the explicit rest-pose API")
			quit(1)
			return
		rig.set_rest_pose(true)
		_sample(0.0, 0.0)
		subtitle.text = "기준 자세 · 관절 움직임 없이 연결 확인"
		await _capture("neutral")
		if "--neutral-only" not in OS.get_cmdline_user_args():
			for pose: Array in [["idle", .65, "대기"], ["walk", .22, "걷기"], ["attack_1", .24, "공격 · 준비"], ["attack_1", .48, "공격 · 타격"], ["attack_1", .80, "공격 · 회복"]]:
				_set_action(str(pose[0]))
				_seek(float(pose[1]) * duration)
				subtitle.text = str(pose[2]) + " · 실제 조립 렌더"
				await _capture("%s-%02d" % [pose[0], roundi(float(pose[1]) * 100)])
	var file := FileAccess.open(OUTPUT + "render-review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"hero_id": "leonhardt", "reviewed": bool(definition.get("reviewed", false)), "part_count": definition.parts.size(), "captures": records, "scope": "Left: static concept. Right: actual independent multipart renderer. Visual review remains a separate decision."}, "  ") + "\n")
	page.free()
	await _settle(3)
	quit()

func _build() -> void:
	page = Control.new()
	page.size = Vector2(1280, 720)
	root.add_child(page)
	var background := ColorRect.new()
	background.color = Color("e4e9df")
	background.size = page.size
	page.add_child(background)
	_label("레온하르트 · 비율과 관절 연결 검토", Rect2(26, 13, 1210, 40), 26)
	_label("수정 원화 · 정적 참고", Rect2(26, 62, 596, 30), 19)
	var movie := "--movie" in OS.get_cmdline_user_args()
	var stage_x := 332.0 if movie else 650.0
	subtitle = _label("실제 부위 조립", Rect2(stage_x, 62, stage_size.x, 30), 19)
	var reference := TextureRect.new()
	reference.position = Vector2(26, 99)
	reference.size = Vector2(280 if movie else 596, 586)
	reference.texture = load("res://assets/art-direction/aurelia-4head/leonhardt/concept.png")
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	page.add_child(reference)
	var container := SubViewportContainer.new()
	container.position = Vector2(stage_x, 99)
	container.size = Vector2(stage_size)
	container.stretch = true
	page.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = stage_size
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 3.35
	camera.position = Vector3(0, 1.6, 8)
	world.add_child(camera)
	camera.current = true
	_label("검토용 시안 · 전투 수치와 게임 진행에는 영향을 주지 않습니다.", Rect2(26, 686, 1228, 24), 14)

func _label(value: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = value
	label.add_theme_font_override("font", FONT.get_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("294137"))
	page.add_child(label)
	return label

func _set_action(value: String) -> void:
	if is_instance_valid(rig): rig.free()
	if is_instance_valid(source): source.free()
	action = value
	source = FACTORY.create_hero("leonhardt")
	source.observe_game = false
	source.hold_demo = true
	source.auto_play = false
	world.add_child(source)
	source.set_process(false)
	source.visible = false
	source.play_visual(action)
	source.pause()
	duration = 0.0
	for frame in source.sprite_frames.get_frame_count(source.animation):
		duration += source.sprite_frames.get_frame_duration(source.animation, frame)
	duration /= source.sprite_frames.get_animation_speed(source.animation)
	rig = RIG.new()
	world.add_child(rig)
	assert(rig.bind(source, definition, true))
	camera.size = 3.35
	camera.position = Vector3(0, 1.6, 8)
	_sample(0.0, 0.0)

func _sample(seconds: float, delta: float) -> void:
	var time := fposmod(seconds, duration) if action in ["idle", "walk", "run"] else minf(seconds, duration)
	var remaining := time * source.sprite_frames.get_animation_speed(source.animation)
	var count := source.sprite_frames.get_frame_count(source.animation)
	for index in count:
		var weight := source.sprite_frames.get_frame_duration(source.animation, index)
		if remaining <= weight or index == count - 1:
			source.set_frame_and_progress(index, clampf(remaining / weight, 0.0, 1.0))
			break
		remaining -= weight
	var speed := 1.0 if action == "walk" else 1.8 if action == "run" else 0.0
	rig.sync(camera, 3.2, Color.WHITE, delta, true, Vector2(speed, 0), seconds * speed)
	_fit_camera()

func _seek(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed + .00001 < seconds:
		var step := minf(1.0 / 60.0, seconds - elapsed)
		elapsed += step
		_sample(elapsed, step)

func _fit_camera() -> void:
	if locked_camera_size > 0.0:
		camera.size = locked_camera_size
		return
	var inverse := camera.global_transform.affine_inverse()
	var extent := Vector2.ZERO
	for part: MeshInstance3D in rig.parts.values():
		for index in 8:
			var point: Vector3 = inverse * part.global_transform * part.get_aabb().get_endpoint(index)
			extent = extent.max(Vector2(absf(point.x), absf(point.y)))
	var aspect := float(stage_size.x) / float(stage_size.y)
	camera.size = maxf(camera.size, maxf(extent.y * 2.0, extent.x * 2.0 / aspect) * 1.045)

func _settle(count := 4) -> void:
	for frame in count: await process_frame

func _capture(label: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + label + ".png") == OK)
	records.append({"capture": label, "camera_size": camera.size, "rig": rig.debug_snapshot()})
	print("LEONHARDT_QUALITY_CAPTURE ", label)

func _movie() -> void:
	# Godot movie writer is a deterministic recording, not a device FPS measure.
	# Fit once across all source phases, then keep the hero's display size steady.
	var required := 3.35
	for action_name: String in ["idle", "walk", "attack_1", "guard"]:
		_set_action(action_name)
		for tick in 61: _sample(duration * float(tick) / 60.0, 1.0 / 60.0)
		required = maxf(required, camera.size)
	locked_camera_size = required * 1.025
	for segment: Array in [["idle", 2.0, "대기"], ["walk", 3.0, "걷기"], ["attack_1", 3.0, "기본 공격"], ["guard", 2.0, "방어"]]:
		_set_action(str(segment[0]))
		subtitle.text = str(segment[2]) + " · 실제 부위 조립 애니메이션"
		var total_frames := roundi(float(segment[1]) * 24)
		for frame in total_frames:
			var time := float(frame) / 24.0
			if action not in ["idle", "walk", "run"]: time = fposmod(time, duration + .25)
			_sample(time, 1.0 / 24.0)
			await process_frame
		await _capture("movie-" + action)
