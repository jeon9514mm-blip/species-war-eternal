extends SceneTree
## Capture actual live hunting, then expand that same battlefield for art review.
const OUT := "res://checks/hunting-quality-03/"
var game: Node
var captures: Array[Dictionary] = []

func _init() -> void: run.call_deferred()

func settle(frames := 12) -> void:
	for frame in frames: await process_frame

func capture(label: String, field: Control) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+label+".png") == OK)
	captures.append({"file":label+".png","size":[root.size.x,root.size.y],"renderer":RenderingServer.get_current_rendering_method(),
		"layers":field.backdrop.layer_manifest().size(),"atmosphere_time":field.backdrop.atmosphere_time,
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"texture_memory_bytes":int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"ground_sha256":FileAccess.get_sha256(preload("res://scripts/art/HuntingSceneryCatalog.gd").profile(field.art_theme).ground)})
	print("MEADOW_CAPTURE ",label)

func capture_scene(scene_path: String, theme: String) -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	game = load(scene_path).instantiate()
	root.add_child(game)
	root.size = Vector2i(1280,720)
	await settle(12)
	await create_timer(1.0).timeout
	var field: Control = game.combat_labels.terrain
	if "--movie" in OS.get_cmdline_user_args():
		await create_timer(6.0).timeout
		await capture(theme+"-live",field)
	else:
		game.set_physics_process(false)
		game.set_process(false)
		await capture(theme+"-hunt",field)
		field._toggle_overview()
		await capture(theme+"-overview",field)
		root.size = Vector2i(960,540)
		await capture(theme+"-mobile-size",field)
		root.size = Vector2i(1280,720)
		await settle()
		# Reparent the actual field, retaining its actors and world positions.
		# This is an unobstructed viewport capture, never a generated mockup.
		field.reparent(root)
		game.hide()
		field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		field.comparison_button.hide()
		field.scene_label.hide()
		field.view_button.hide()
		for button: Button in field.find_children("*","Button",true,false): button.hide()
		field.set_process(false)
		await settle()
		field._resize_world()
		field._update_hunt_camera(0.0,true)
		await capture(theme+"-map-design",field)
		field.reparent(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.presentation_runtime.audio.shutdown()
	await create_timer(.3).timeout
	game.free()
	await settle()

func run() -> void:
	for row: Array in [["res://scenes/art/ArtDirectionLab.tscn","meadow"],["res://scenes/art/CanyonHuntArtLab.tscn","canyon"],["res://scenes/art/ElvenRuinsHuntArtLab.tscn","ruins"]]:
		await capture_scene(row[0],row[1])
	var report := FileAccess.open(OUT+"render-review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"scope":"Actual Godot pilot captures; art review pending; renderer counters are not Android FPS.","captures":captures},"  ")+"\n")
	report.close()
	quit()
