extends SceneTree
func _init() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,850);root.content_scale_size=Vector2i.ZERO
	var gallery=load('res://scenes/MapGallery.tscn').instantiate();root.add_child(gallery)
	var folder:=OS.get_environment('MAP_CAPTURE_DIR')
	for id in 4:
		gallery.select_map(id)
		for i in 5:await process_frame
		if not folder.is_empty() and DisplayServer.get_name()!='headless':
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(folder.path_join('map-gallery-'+str(id)+'.png'))==OK)
		assert(gallery.map_root.has_node('NavigationRegion3D'))
		print('MapGallery scene ',id,' loaded; camera=',gallery.camera.position)
	gallery.free();await process_frame;print('v8363_map_gallery checks=4 failures=[]');quit()
