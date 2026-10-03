extends SceneTree
## Same camera, resolution and renderer for before/after art comparisons.
func _init() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,1000);root.content_scale_size=Vector2i.ZERO;root.msaa_3d=Viewport.MSAA_4X
	var folder:=OS.get_environment('MAP_CAPTURE_DIR')
	if folder.is_empty():push_error('Set MAP_CAPTURE_DIR');quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var selection:=OS.get_environment('MAP_CAPTURE_THEMES')
	var themes: Array=['IceCavern','Crimson','Arcane','Evergreen'] if selection.is_empty() else Array(selection.split(','))
	for theme: String in themes:
		var world: Node3D=load('res://scenes/maps3d/'+theme+'Field.tscn').instantiate();root.add_child(world)
		var camera: Camera3D=world.get_node('BattleCamera')
		camera.size=49 if theme=='IceCavern' else 38
		camera.position=Vector3(25,42,53);camera.look_at(Vector3(16,1,5))
		for frame in 12:await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder.path_join(theme+'.png'))==OK)
		print('CAPTURE ',theme,' renderer=',RenderingServer.get_current_rendering_method(),' draws=',RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		world.free();await process_frame
	quit()
