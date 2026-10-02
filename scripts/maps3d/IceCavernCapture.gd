extends SceneTree
func _init() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(3840,2160) if OS.get_environment('MAP_CAPTURE_4K')=='1' else Vector2i(1536,1024);root.content_scale_size=Vector2i.ZERO;root.msaa_3d=Viewport.MSAA_4X
	var world: Node3D=load('res://scenes/maps3d/IceCavernField.tscn').instantiate();root.add_child(world)
	var camera: Camera3D=world.get_node('BattleCamera');camera.size=44;camera.position=Vector3(29,41,52);camera.look_at(Vector3(16,1,5))
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	var path:=OS.get_environment('MAP_CAPTURE_PATH');if path.is_empty():path='/workspace/map-redesign/ice-preview.png'
	root.get_texture().get_image().save_png(path)
	print('CAPTURED ',path,' renderer=',RenderingServer.get_current_rendering_method(),' draws=',RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	world.free();await process_frame;quit()
