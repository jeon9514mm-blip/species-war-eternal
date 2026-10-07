extends Control
## Independent multipart-art viewer. The hidden source controller supplies only
## action names/frame progress; this scene never creates Main, saves or economy.
const UI = preload("res://scripts/ui/GameUiTheme.gd")
const FONT = preload("res://scripts/ui/UIFontProvider.gd")
const FACTORY = preload("res://scripts/heroes/HeroSpriteFactory.gd")
const ROSTER = preload("res://scripts/heroes/HeroRosterCatalog.gd")
const CATALOG_PATH := "res://scripts/art/HeroPartsCatalog.gd"
const RIG_PATH := "res://scripts/art/HeroPartsRig3D.gd"
const ART_ROOT := "res://assets/art-direction/aurelia-4head/"
const HERO_IDS: Array[String] = ["leonhardt", "mira", "elisia", "kairen", "orwin", "seria", "astel", "darius", "lunea", "caelum", "adrien", "tessa", "naia", "sael", "odelia"]
const ACTION_LABELS := {
	"idle": "대기", "walk": "걷기", "run": "달리기", "attack_1": "기본 공격 1",
	"attack_2": "기본 공격 2", "skill": "스킬", "ultimate": "궁극기", "hit": "피격",
	"knockback": "밀려남", "dodge": "회피", "guard": "방어", "buff": "강화",
	"debuff": "약화", "victory": "승리", "death": "사망", "spawn": "등장",
}
const LOOP_ACTIONS := ["idle", "walk", "run", "debuff"]
const HERO_HEIGHT := 3.2
const GALLERY_CAMERA_SIZE := 3.8
const VIEWPORT_SIZE := Vector2i(728, 350)
const SPEEDS := [0.5, 1.0, 1.5, 2.0]

var selected_hero := "leonhardt"
var selected_action := "idle"
var animation_playing := true
var animation_time := 0.0
var animation_speed := 1.0
var mirrored := false
var rest_pose_preview := false
var viewport_3d: SubViewport
var camera: Camera3D
var world: Node3D
var parts_rig: Node3D
var source: AnimatedSprite2D
var _catalog: Script
var _definition: Dictionary = {}
var _validation: Dictionary = {}
var _bound := false
var _hero_buttons: Dictionary = {}
var _action_buttons: Dictionary = {}
var _play_button: Button
var _speed_button: Button
var _mirror_button: Button
var _rest_button: Button
var _title: Label
var _role_label: Label
var _status: Label
var _stage_note: Label
var _reference: TextureRect
var _reference_note: Label
var _action_note: Label
var _progress: ProgressBar
var _source_root: Node2D
var _shadow: MeshInstance3D
var _duration := 1.0
var _demo_distance := 0.0
var _ready_for_capture := false


func _ready() -> void:
	theme = UI.make_theme()
	get_window().content_scale_size = Vector2i(1280, 720)
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if ResourceLoader.exists(CATALOG_PATH): _catalog = load(CATALOG_PATH) as Script
	_build()
	select_hero(selected_hero)
	_ready_for_capture = true


func _panel(rect: Rect2, fill := Color("f4f5e9")) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("bfceba")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _label(parent: Node, value: String, rect: Rect2, points := 18, color := Color("284438")) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", FONT.get_font())
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, value: String, rect: Rect2, callback: Callable, points := 16) -> Button:
	var button := Button.new()
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", FONT.get_font())
	button.add_theme_font_size_override("font_size", points)
	button.add_theme_color_override("font_color", Color("294737"))
	button.add_theme_color_override("font_hover_color", Color("182f25"))
	button.add_theme_color_override("font_pressed_color", Color("182f25"))
	button.add_theme_color_override("font_focus_color", Color("182f25"))
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e6ecdf") if state_name == "normal" else Color("d7e4ce")
		if state_name == "pressed": style.bg_color = Color("efdfad")
		style.border_color = Color("c0cfb7") if state_name != "pressed" else Color("bc9550")
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		style.content_margin_left = 8
		style.content_margin_right = 8
		if state_name == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("668b66")
		button.add_theme_stylebox_override(state_name, style)
	button.clip_text = true
	button.tooltip_text = value
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("dfe8d9")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label(self, "아우렐리아 · 영웅 아트 스튜디오", Rect2(22, 17, 910, 42), 29)
	_label(self, "새 기준 원화와 부위 조립 동작을 한 명씩 살펴보세요.", Rect2(24, 62, 920, 27), 16, Color("59705a"))
	var back := _button(self, "초원 사냥으로 돌아가기", Rect2(1020, 22, 238, 42), _back_to_lab)
	back.name = "OpenArtDirectionLab"
	var roster_panel := _panel(Rect2(20, 100, 204, 440))
	_label(roster_panel, "영웅 15명", Rect2(13, 9, 178, 27), 18)
	for index in HERO_IDS.size():
		var id: String = HERO_IDS[index]
		var full_name := str(ROSTER.HEROES.get(id, {}).get("name", id))
		var name_text := "%02d   %s" % [index + 1, full_name.split(" ")[0]]
		var button := _button(roster_panel, name_text, Rect2(11, 43 + index * 25.6, 182, 24), select_hero.bind(id), 14)
		button.name = "Hero_" + id
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_hero_buttons[id] = button
	var stage := _panel(Rect2(236, 100, 748, 440), Color("edf1e4"))
	_title = _label(stage, "", Rect2(20, 9, 700, 31), 25)
	_role_label = _label(stage, "", Rect2(21, 40, 700, 20), 14, Color("617362"))
	_build_viewport(stage)
	_stage_note = _label(stage, "", Rect2(18, 412, 712, 24), 14, Color("486747"))
	_stage_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reference_panel := _panel(Rect2(996, 100, 264, 440))
	_label(reference_panel, "원화 · 정적 참고", Rect2(16, 9, 232, 28), 19)
	_reference = TextureRect.new()
	_reference.name = "StaticConceptReference"
	_reference.position = Vector2(16, 45)
	_reference.size = Vector2(232, 280)
	_reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reference.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference_panel.add_child(_reference)
	_reference_note = _label(reference_panel, "", Rect2(16, 330, 232, 41), 14, Color("647360"))
	_reference_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = _label(reference_panel, "", Rect2(16, 376, 232, 51), 14, Color("647360"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_play_button = _button(self, "일시 정지", Rect2(20, 552, 144, 42), _toggle_playback)
	_play_button.name = "ToggleHeroAnimation"
	_speed_button = _button(self, "속도 1×", Rect2(174, 552, 124, 42), _cycle_speed)
	_speed_button.name = "HeroAnimationSpeed"
	_mirror_button = _button(self, "방향 반전", Rect2(308, 552, 144, 42), func(): set_mirrored(not mirrored))
	_mirror_button.name = "MirrorHero"
	_mirror_button.toggle_mode = true
	var replay := _button(self, "처음부터", Rect2(462, 552, 130, 42), func(): select_action(selected_action))
	replay.name = "ReplayHeroAction"
	_rest_button = _button(self, "기준 자세", Rect2(602, 552, 144, 42), func(): set_rest_pose_preview(not rest_pose_preview))
	_rest_button.name = "ToggleHeroRestPose"
	_rest_button.toggle_mode = true
	_rest_button.tooltip_text = "움직임 없이 부위의 기본 연결과 비율을 확인합니다."
	_action_note = _label(self, "", Rect2(766, 550, 494, 28), 16)
	_progress = ProgressBar.new()
	_progress.position = Vector2(766, 584)
	_progress.size = Vector2(494, 7)
	_progress.min_value = 0
	_progress.max_value = 1
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for style_name: String in ["background", "fill"]:
		var progress_style := StyleBoxFlat.new()
		progress_style.bg_color = Color("d4dfca") if style_name == "background" else Color("819969")
		progress_style.set_corner_radius_all(3)
		_progress.add_theme_stylebox_override(style_name, progress_style)
	_progress.size = Vector2(494, 7)
	add_child(_progress)
	_progress.set_deferred("size", Vector2(494, 7))
	var index := 0
	for action: String in ACTION_LABELS:
		var button := _button(self, ACTION_LABELS[action], Rect2(20 + (index % 8) * 156.0, 610 + (index / 8) * 43.0, 148, 37), select_action.bind(action), 16)
		button.name = "Action_" + action
		button.toggle_mode = true
		_action_buttons[action] = button
		index += 1
	_source_root = Node2D.new()
	_source_root.name = "HiddenActionController"
	_source_root.visible = false
	add_child(_source_root)


func _build_viewport(stage: Control) -> void:
	var container := SubViewportContainer.new()
	container.name = "AssembledHeroViewport"
	container.position = Vector2(10, 61)
	container.size = Vector2(VIEWPORT_SIZE)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(container)
	viewport_3d = SubViewport.new()
	viewport_3d.name = "HeroPartsWorld"
	viewport_3d.own_world_3d = true
	viewport_3d.transparent_bg = true
	viewport_3d.msaa_3d = Viewport.MSAA_2X
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport_3d)
	world = Node3D.new()
	world.name = "IndependentArtStage"
	viewport_3d.add_child(world)
	camera = Camera3D.new()
	camera.name = "GalleryCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = GALLERY_CAMERA_SIZE
	world.add_child(camera)
	camera.position = Vector3(0, 3.55, 9)
	camera.look_at(Vector3(0, 1.67, 0))
	camera.current = true
	var floor := MeshInstance3D.new()
	floor.name = "StudioFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 12)
	floor.mesh = plane
	var floor_shader := Shader.new()
	floor_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
    vec2 p=(UV-vec2(.5))*2.0;
    float falloff=1.0-smoothstep(.10,.88,length(p));
    ALBEDO=mix(vec3(.60,.70,.49),vec3(.76,.81,.65),UV.y);
    ALPHA=falloff*.23;
}
"""
	var floor_material := ShaderMaterial.new()
	floor_material.shader = floor_shader
	floor.material_override = floor_material
	floor.position.y = -.025
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(floor)
	_shadow = MeshInstance3D.new()
	_shadow.name = "GroundContactShadow"
	var shadow_plane := PlaneMesh.new()
	shadow_plane.size = Vector2(1.8, 1.05)
	_shadow.mesh = shadow_plane
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://assets/art-direction/pilot-01/shaders/contact-shadow.gdshader")
	shadow_material.set_shader_parameter("shadow_color", Color(.075, .11, .055, .35))
	_shadow.material_override = shadow_material
	_shadow.position.y = .004
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_shadow)


func select_hero(hero_id: String) -> void:
	if hero_id not in HERO_IDS: return
	selected_hero = hero_id
	for id: String in _hero_buttons: _hero_buttons[id].set_pressed_no_signal(id == hero_id)
	var identity: Dictionary = ROSTER.HEROES.get(hero_id, {})
	_title.text = str(identity.get("name", hero_id))
	var concept_path := ART_ROOT + hero_id + "/concept.png"
	var long_leg_reference := ART_ROOT + hero_id + "/concept-v2-candidate.png"
	var has_long_leg_reference := hero_id == "leonhardt" and ResourceLoader.exists(long_leg_reference)
	if has_long_leg_reference: concept_path = long_leg_reference
	_reference.texture = load(concept_path) as Texture2D if ResourceLoader.exists(concept_path) else null
	_reference_note.text = "움직이지 않는 원화입니다.\n중앙에서 실제 조립 동작을 확인하세요." if _reference.texture != null else "이 영웅의 새 원화를 준비하고 있습니다."
	if has_long_leg_reference: _reference_note.text = "긴 다리 비율의 기준 원화\n중앙 조립 초안과 비교하세요."
	_definition = {}
	_validation = {}
	if _catalog != null:
		_definition = _catalog.load_definition(hero_id, true)
		_validation = _catalog.validate_definition(_definition, true)
	var proportion_note := "4.5~5등신 기준 원화" if has_long_leg_reference else "새 부위 원화"
	var review_note := "조립 검토 완료" if bool(_validation.get("reviewed", false)) else "조립 초안"
	_role_label.text = "%s · %s · %s" % [str(identity.get("class", identity.get("role", "아우렐리아"))), proportion_note, review_note]
	var retain_rest_pose := rest_pose_preview
	_rebuild_actor()
	select_action(selected_action)
	if retain_rest_pose: set_rest_pose_preview(true)
	_refresh_status()


func _rebuild_actor() -> void:
	if is_instance_valid(parts_rig):
		parts_rig.get_parent().remove_child(parts_rig)
		parts_rig.queue_free()
	parts_rig = null
	if is_instance_valid(source):
		_source_root.remove_child(source)
		source.queue_free()
	source = FACTORY.create_hero(selected_hero)
	source.observe_game = false
	source.hold_demo = true
	source.auto_play = false
	_source_root.add_child(source)
	source.set_process(false)
	source.pause()
	source.visible = false
	_bound = false
	if bool(_validation.get("valid", false)) and ResourceLoader.exists(RIG_PATH):
		var rig_script := load(RIG_PATH) as Script
		parts_rig = rig_script.new() as Node3D
		parts_rig.name = "AssembledHeroParts"
		world.add_child(parts_rig)
		_bound = bool(parts_rig.bind(source, _definition, true))
		if _bound and parts_rig.has_method("set_rest_pose_preview"):
			parts_rig.set_rest_pose_preview(rest_pose_preview)
		if not _bound:
			parts_rig.queue_free()
			parts_rig = null
	_shadow.visible = _bound


func select_action(action: String) -> void:
	if not ACTION_LABELS.has(action): return
	if rest_pose_preview: set_rest_pose_preview(false)
	selected_action = action
	animation_time = 0.0
	_demo_distance = 0.0
	camera.size = GALLERY_CAMERA_SIZE
	for key: String in _action_buttons: _action_buttons[key].set_pressed_no_signal(key == action)
	if is_instance_valid(source):
		source.direction = "left" if mirrored else "right"
		source.play_visual(action)
		source.pause()
		source.speed_scale = 1.0
		source.flip_h = mirrored
		_duration = _action_duration()
	_update_source_frame()
	_sync_rig(0.0, true)
	_refresh_playback_ui()


func _action_duration() -> float:
	if not is_instance_valid(source) or source.sprite_frames == null or not source.sprite_frames.has_animation(selected_action): return 1.0
	var weights := 0.0
	for index in source.sprite_frames.get_frame_count(selected_action):
		weights += source.sprite_frames.get_frame_duration(selected_action, index)
	return maxf(.1, weights / maxf(.001, source.sprite_frames.get_animation_speed(selected_action)))


func _update_source_frame() -> void:
	if not is_instance_valid(source) or source.sprite_frames == null or not source.sprite_frames.has_animation(selected_action): return
	var frames: SpriteFrames = source.sprite_frames
	var position_in_action := fmod(animation_time, _duration) if selected_action in LOOP_ACTIONS else minf(animation_time, _duration)
	var remaining := position_in_action * frames.get_animation_speed(selected_action)
	var count := frames.get_frame_count(selected_action)
	for index in count:
		var weight := frames.get_frame_duration(selected_action, index)
		if remaining <= weight or index == count - 1:
			source.set_frame_and_progress(index, clampf(remaining / maxf(.001, weight), 0.0, 1.0))
			break
		remaining -= weight


func _sync_rig(delta: float, active: bool) -> void:
	if not _bound or not is_instance_valid(parts_rig): return
	var speed := 1.0 if selected_action == "walk" else 1.8 if selected_action == "run" else 0.0
	var velocity := Vector2(-speed if mirrored else speed, 0)
	parts_rig.sync(camera, HERO_HEIGHT, Color.WHITE, delta, active and not rest_pose_preview, velocity, _demo_distance)
	_fit_camera_to_parts()


func _fit_camera_to_parts() -> void:
	# Keep the standing figure large, widening only when a real posed part needs
	# space. Never shrink within an action: breathing cannot pump the camera zoom.
	var meshes: Dictionary = parts_rig.get("parts")
	var camera_inverse := camera.global_transform.affine_inverse()
	var extent := Vector2.ZERO
	for mesh: MeshInstance3D in meshes.values():
		var bounds := mesh.get_aabb()
		var to_camera := camera_inverse * mesh.global_transform
		for index in 8:
			var point := to_camera * bounds.get_endpoint(index)
			extent.x = maxf(extent.x, absf(point.x))
			extent.y = maxf(extent.y, absf(point.y))
	var usable_height := 1.0 - 16.0 / float(VIEWPORT_SIZE.y)
	var usable_width := 1.0 - 24.0 / float(VIEWPORT_SIZE.x)
	var aspect := float(VIEWPORT_SIZE.x) / float(VIEWPORT_SIZE.y)
	var required := maxf(extent.y * 2.0 / usable_height, extent.x * 2.0 / (aspect * usable_width))
	camera.size = maxf(camera.size, required)


func _process(delta: float) -> void:
	if not _ready_for_capture: return
	if animation_playing and not rest_pose_preview and is_finite(delta):
		var elapsed := clampf(delta, 0.0, .1) * animation_speed
		animation_time += elapsed
		if selected_action not in LOOP_ACTIONS and animation_time > _duration + .7:
			select_action(selected_action)
		else:
			_demo_distance += elapsed * (1.0 if selected_action == "walk" else 1.8 if selected_action == "run" else 0.0)
			_update_source_frame()
			_sync_rig(elapsed, true)
	else:
		_sync_rig(0.0, false)
	_refresh_playback_ui()


func set_animation_playing(enabled: bool) -> void:
	if enabled and rest_pose_preview: set_rest_pose_preview(false)
	animation_playing = enabled
	_refresh_playback_ui()


func _toggle_playback() -> void:
	set_animation_playing(true if rest_pose_preview else not animation_playing)


func set_rest_pose_preview(enabled: bool) -> void:
	if enabled and (not _bound or not is_instance_valid(parts_rig) or not parts_rig.has_method("set_rest_pose_preview")): return
	rest_pose_preview = enabled
	if is_instance_valid(parts_rig) and parts_rig.has_method("set_rest_pose_preview"):
		parts_rig.set_rest_pose_preview(enabled)
	camera.size = GALLERY_CAMERA_SIZE
	_sync_rig(0.0, not enabled)
	_rest_button.set_pressed_no_signal(enabled)
	_refresh_playback_ui()


func set_animation_speed(value: float) -> void:
	if not is_finite(value): return
	animation_speed = clampf(value, .25, 2.0)
	_refresh_playback_ui()


func _cycle_speed() -> void:
	var index := SPEEDS.find(animation_speed)
	set_animation_speed(SPEEDS[(index + 1) % SPEEDS.size()])


func set_mirrored(enabled: bool) -> void:
	mirrored = enabled
	if is_instance_valid(source):
		source.flip_h = enabled
		source.direction = "left" if enabled else "right"
	_mirror_button.set_pressed_no_signal(enabled)
	_sync_rig(0.0, false)


func seek_animation(seconds: float) -> void:
	## Deterministic capture hook. Recreate the local visual rig; no game exists here.
	if not is_finite(seconds): return
	if rest_pose_preview:
		_sync_rig(0.0, false)
		return
	var target := clampf(seconds, 0.0, 30.0)
	_rebuild_actor()
	select_action(selected_action)
	while animation_time + .00001 < target:
		var step := minf(1.0 / 60.0, target - animation_time)
		animation_time += step
		_demo_distance += step * (1.0 if selected_action == "walk" else 1.8 if selected_action == "run" else 0.0)
		_update_source_frame()
		_sync_rig(step, true)
	_refresh_playback_ui()


func _refresh_status() -> void:
	var reviewed := bool(_validation.get("reviewed", false))
	var count := int(_validation.get("part_count", 0))
	if _bound:
		_stage_note.text = "2D 부위 원화 조립 · %d개 부위%s" % [count, "" if reviewed else " · 초안"]
		_status.text = "조립 검토 완료 · 16가지 동작" if reviewed else "조립 초안 · 확정 전\n비율과 움직임 검토 중"
	else:
		_stage_note.text = "부위 원화 준비 중 · 오른쪽의 정적 원화를 참고하세요."
		_status.text = "부위 원화 준비 중" if _definition.is_empty() else "부위 연결 확인 중"


func _refresh_playback_ui() -> void:
	if is_instance_valid(_play_button): _play_button.text = "동작 재생" if rest_pose_preview else "일시 정지" if animation_playing else "재생"
	if is_instance_valid(_speed_button): _speed_button.text = "속도 %s×" % str(animation_speed).trim_suffix(".0")
	if is_instance_valid(_action_note):
		_action_note.text = "기준 자세 · 부위 연결과 비율 확인" if rest_pose_preview else "%s · %s" % [ACTION_LABELS[selected_action], "반복 재생" if animation_playing else "일시 정지"]
	if is_instance_valid(_progress):
		_progress.visible = not rest_pose_preview
		_progress.value = fmod(animation_time, _duration) / _duration if selected_action in LOOP_ACTIONS else minf(1.0, animation_time / _duration)


func gallery_state() -> Dictionary:
	var rig_state: Dictionary = parts_rig.debug_snapshot() if _bound and is_instance_valid(parts_rig) else {}
	return {"hero_id": selected_hero, "action": selected_action, "playing": animation_playing,
		"time": animation_time, "duration": _duration, "speed": animation_speed, "mirrored": mirrored,
		"rest_pose_preview": rest_pose_preview,
		"camera_size": camera.size, "viewport_size": VIEWPORT_SIZE,
		"hero_count": HERO_IDS.size(), "action_count": ACTION_LABELS.size(),
		"parts_ready": _bound, "reviewed": bool(_validation.get("reviewed", false)),
		"part_count": int(_validation.get("part_count", 0)), "rig": rig_state,
		"source_is_hidden": is_instance_valid(source) and not source.is_visible_in_tree(),
		"static_reference_visible": _reference.texture != null,
		"has_main_or_save": false, "ready_for_capture": _ready_for_capture}


func _back_to_lab() -> void:
	get_tree().change_scene_to_file("res://scenes/art/ArtDirectionLab.tscn")
