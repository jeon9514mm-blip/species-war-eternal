extends SceneTree
## Production raid scenes rendered with an identical camera and lighting for review.
func _init() -> void:run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=='headless':push_error('Raid capture requires a display renderer.');quit(1);return
	root.size=Vector2i(1440,1000);root.content_scale_size=Vector2i.ZERO;root.msaa_3d=Viewport.MSAA_4X
	var folder:=OS.get_environment('RAID_CAPTURE_DIR')
	if folder.is_empty():folder=ProjectSettings.globalize_path('res://checks/raid-quality/captures')
	DirAccess.make_dir_recursive_absolute(folder)
	for theme in ['Evergreen','Crimson','Arcane','IceCavern']:
		var world: Node3D=load('res://scenes/maps3d/'+theme+'Raid.tscn').instantiate();root.add_child(world)
		var camera: Camera3D=world.get_node('BattleCamera')
		camera.size=37 if theme=='IceCavern' else 30
		camera.position=Vector3(24,38,45);camera.look_at(Vector3(16,1,7));camera.current=true
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder.path_join(theme+'.png'))==OK)
		print('RAID_CAPTURE ',theme,' draw_calls=',RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		world.free();await process_frame
	quit()
