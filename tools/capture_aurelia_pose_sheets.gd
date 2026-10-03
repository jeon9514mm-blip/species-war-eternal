extends SceneTree
## Actual Godot-rendered multipart contact sheets, never image compositing.
## Run with a GPU display. AURELIA_CAPTURE_PREPARE=1 validates construction only.
const CATALOG = preload("res://scripts/art/HeroPartsCatalog.gd")
const RIG = preload("res://scripts/art/HeroPartsRig3D.gd")
const FACTORY = preload("res://scripts/HeroSpriteFactory.gd")
const FONT = preload("res://scripts/UIFontProvider.gd")
const LABELS := {
	"idle": "대기", "walk": "걷기", "run": "달리기", "attack_1": "기본 공격 1",
	"attack_2": "기본 공격 2", "skill": "스킬", "ultimate": "궁극기", "hit": "피격",
	"knockback": "밀려남", "dodge": "회피", "guard": "방어", "buff": "강화",
	"debuff": "약화", "victory": "승리", "death": "사망", "spawn": "등장",
}
const OUTPUT := "res://checks/aurelia-four-head/pose-sheets/"
const CELL_SIZE := Vector2(306, 151)
var page: Control
var metrics: Array[Dictionary] = []
var failures: Array[String] = []

func _init() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.set_default_clear_color(Color("dce6d5"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var ids: Array[String] = CATALOG.HERO_IDS.duplicate()
	var requested := OS.get_environment("AURELIA_CAPTURE_IDS")
	if not requested.is_empty():
		ids.clear()
		for id in requested.split(",", false):
			if id in CATALOG.HERO_IDS: ids.append(id)
	var prepare_only := OS.get_environment("AURELIA_CAPTURE_PREPARE") == "1"
	if ids.is_empty(): failures.append("No valid Aurelia IDs selected")
	for id: String in ids:
		if is_instance_valid(page):
			root.remove_child(page)
			page.free()
		var definition := CATALOG.load_definition(id, true)
		if definition.is_empty():
			failures.append(id + ": separated artwork is not ready")
			continue
		page = Control.new()
		page.name = "AureliaPoseSheet"
		page.size = Vector2(1280, 720)
		root.add_child(page)
		var background := ColorRect.new()
		background.color = Color("dce6d5")
		background.size = page.size
		page.add_child(background)
		var profile := CATALOG.profile(id)
		add_label(page, str(profile.name) + " · 16가지 조립 동작", Rect2(18, 9, 1244, 29), 24)
		add_label(page, "분리 원화 · 기존 16가지 동작 곡선 적용 · 자세 확인을 위해 사망도 불투명 표시", Rect2(19, 42, 1242, 24), 14)
		var states: Array[Dictionary] = []
		for index in CATALOG.ACTIONS.size():
			var action: String = CATALOG.ACTIONS[index]
			var cell: Dictionary = create_cell(id, action, index, definition)
			states.append(cell)
		for frame in 5: await process_frame
		if not prepare_only:
			await RenderingServer.frame_post_draw
			var screenshot := root.get_texture().get_image()
			var error := screenshot.save_png(OUTPUT + id + ".png")
			if error != OK: failures.append(id + ": PNG save error " + str(error))
		var result := {"hero_id": id, "reviewed": bool(definition.get("reviewed", false)),
			"rendered": not prepare_only, "neutral_preview": false, "logical_size": [1280, 720], "cells": states,
			"capture": OUTPUT + id + ".png" if not prepare_only else "",
			"scope": "Sixteen actual independent multipart Godot rigs in source-action poses, not neutral rest previews; existing procedural curves, not sixteen newly drawn image sequences. Death pose is deliberately opaque for art review."}
		metrics.append(result)
		write_json(OUTPUT + id + ".json", result)
		print("AURELIA_POSE_SHEET ", id, " cells=", states.size(), " rendered=", not prepare_only)
	write_json(OUTPUT + "capture-summary.json", {"heroes": metrics.size(), "failures": failures, "prepare_only": prepare_only, "results": metrics})
	if is_instance_valid(page): page.free()
	for frame in 3: await process_frame
	print("aurelia_pose_sheets heroes=%d failures=%s" % [metrics.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func create_cell(id: String, action: String, index: int, definition: Dictionary) -> Dictionary:
	var panel := Panel.new()
	panel.position = Vector2(16 + (index % 4) * 314, 77 + int(index / 4.0) * 159)
	panel.size = CELL_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("eef2e8")
	style.border_color = Color("bfccb8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	page.add_child(panel)
	add_label(panel, "%02d · %s" % [index + 1, str(LABELS[action])], Rect2(10, 3, 288, 22), 14)
	var container := SubViewportContainer.new()
	container.position = Vector2(4, 26)
	container.size = Vector2(298, 121)
	container.stretch = true
	panel.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(298, 121)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = .01
	camera.far = 32
	camera.position = Vector3(0, 1.6, 8)
	world.add_child(camera)
	camera.current = true
	var source := FACTORY.create_hero(id)
	source.observe_game = false
	source.hold_demo = true
	source.auto_play = false
	world.add_child(source)
	source.set_process(false)
	source.visible = false
	source.play_visual(action)
	source.pause()
	var rig := RIG.new()
	world.add_child(rig)
	if not rig.bind(source, definition, true):
		failures.append(id + "/" + action + ": rig bind failed")
		return {"action": action, "ready": false}
	var duration := animation_duration(source)
	var progress := .94 if action == "death" else .20 if action in ["walk", "run"] else .45
	var target_time := duration * progress
	if action == "idle": target_time = duration * .68
	var step := target_time / 36.0
	for tick in range(37):
		set_source_time(source, tick * step)
		rig.sync(camera, 3.2, Color.WHITE, 0.0 if tick == 0 else step, true, Vector2.RIGHT if action in ["walk", "run"] else Vector2.ZERO, -1.0)
	var bounds := rig_world_bounds(rig)
	var center := bounds.get_center()
	var aspect := float(viewport.size.x) / float(viewport.size.y)
	camera.size = maxf(.25, maxf(bounds.size.y, bounds.size.x / aspect) * 1.18)
	camera.position = Vector3(center.x, center.y, maxf(8.0, bounds.end.z + 6.0))
	# All meshes share this fixed-facing camera, so reframing changes position
	# and orthographic scale without distorting the sampled rig.
	rig.sync(camera, 3.2, Color.WHITE, 0.0, false)
	var inside := true
	var screen_rect := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-2)
	for corner in aabb_corners(bounds):
		inside = inside and screen_rect.has_point(camera.unproject_position(corner))
	if not inside: failures.append(id + "/" + action + ": artwork bounds leave its capture cell")
	return {"action": action, "kind": "source_action", "neutral_preview": false, "ready": true, "source_animation": source.animation,
		"source_frame": source.frame, "source_frame_progress": source.frame_progress,
		"normalized_progress": target_time / duration, "duration": duration,
		"all_mesh_bounds_inside_cell": inside, "camera_size": camera.size,
		"bounds_position": [bounds.position.x, bounds.position.y, bounds.position.z],
		"bounds_size": [bounds.size.x, bounds.size.y, bounds.size.z], "rig": rig.debug_snapshot()}

func rig_world_bounds(rig: Node3D) -> AABB:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for key in rig.parts:
		var part: MeshInstance3D = rig.parts[key]
		for point in aabb_corners(part.get_aabb()):
			var world_point: Vector3 = part.global_transform * point
			low = low.min(world_point)
			high = high.max(world_point)
	return AABB(low, high - low)

func aabb_corners(bounds: AABB) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for x in 2:
		for y in 2:
			for z in 2: corners.append(bounds.position + Vector3(bounds.size.x * x, bounds.size.y * y, bounds.size.z * z))
	return corners

func animation_duration(source: AnimatedSprite2D) -> float:
	var frames: SpriteFrames = source.sprite_frames
	var total := 0.0
	for frame in frames.get_frame_count(source.animation): total += frames.get_frame_duration(source.animation, frame)
	return total / frames.get_animation_speed(source.animation)

func set_source_time(source: AnimatedSprite2D, time: float) -> void:
	var frames: SpriteFrames = source.sprite_frames
	var remaining := clampf(time / animation_duration(source), 0, .99999)
	var total := 0.0
	var count := frames.get_frame_count(source.animation)
	for index in count: total += frames.get_frame_duration(source.animation, index)
	remaining *= total
	for index in count:
		var weight := frames.get_frame_duration(source.animation, index)
		if remaining < weight or index == count - 1:
			source.set_frame_and_progress(index, remaining / weight)
			return
		remaining -= weight

func add_label(parent: Node, value: String, rect: Rect2, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", FONT.get_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("264439"))
	parent.add_child(label)

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write " + path)
		return
	file.store_string(JSON.stringify(value, "  "))
	file.close()
