extends SceneTree
## Actual volume and animation inspection from three independent camera angles.
func _init() -> void:run.call_deferred()
func run() -> void:
	var output:=OS.get_environment('MAP_CAPTURE_OUTPUT');assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	var gallery:=Node3D.new();root.add_child(gallery)
	var environment:=WorldEnvironment.new();gallery.add_child(environment)
	environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color('#232836');environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color('#b6c3d5');environment.environment.ambient_light_energy=.6
	var light:=DirectionalLight3D.new();gallery.add_child(light);light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=1.1
	var camera:=Camera3D.new();gallery.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.35;camera.current=true
	var catalog=preload('res://scripts/art/Model3DCatalog.gd').new()
	for id in ['leonhardt','mira','fenris','goblin','moon_wolf','crystal_spider','morgul','selene_boss']:
		var model=(load(str(catalog.load_entry(id).path)) as PackedScene).instantiate();gallery.add_child(model)
		var player: AnimationPlayer=model.find_children('*','AnimationPlayer',true,false)[0]
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;player.play('idle');player.seek(0,true)
		for angle in [0,45,180]:
			camera.position=Vector3(sin(deg_to_rad(angle))*7,2.8,cos(deg_to_rad(angle))*7);camera.look_at(Vector3(0,.95,0))
			await process_frame;await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output.path_join(id+'-'+str(angle)+'.png'))==OK)
		model.free()
	gallery.free();print('MODEL_TURNTABLE_OK');quit()
