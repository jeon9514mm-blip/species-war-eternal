extends SceneTree
## Capture actual live hunting, then expand that same battlefield for art review.
const OUT := "res://checks/meadow-quality-02/"
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
		"ground_sha256":FileAccess.get_sha256("res://assets/art-direction/meadow-quality-02/meadow-ground.png")})
	print("MEADOW_CAPTURE ",label)

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	game = load("res://scenes/art/ArtDirectionLab.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(1280,720)
	await settle(24)
	await create_timer(1.8).timeout
	var field: Control = game.combat_labels.terrain
	if "--movie" in OS.get_cmdline_user_args():
		await create_timer(6.0).timeout
		await capture("live",field)
	else:
		game.set_physics_process(false)
		game.set_process(false)
		await capture("hunt",field)
		field._toggle_overview()
		await capture("overview",field)
		root.size = Vector2i(960,540)
		await capture("mobile-size",field)
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
		await capture("map-design",field)
		field.reparent(game)
	var report := FileAccess.open(OUT+"render-review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"scope":"Actual Godot pilot captures; art review pending; renderer counters are not Android FPS.","captures":captures},"  ")+"\n")
	report.close()
	game.set_physics_process(false)
	game.set_process(false)
	game.presentation_runtime.audio.shutdown()
	await create_timer(.3).timeout
	game.free()
	quit()
