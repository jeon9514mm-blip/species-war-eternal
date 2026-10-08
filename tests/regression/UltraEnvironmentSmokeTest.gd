extends 'res://tests/support/V83UpgradeTestBase.gd'
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',10);main.combat_effects_enabled=true
	main._build_combat_screen();await settle()
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	var field=main.combat_labels.terrain;field.set_process(false)
	var floor: MeshInstance3D=field.world.get_node('PBRStoneSlabs1024')
	var material: ShaderMaterial=floor.material_override
	check(material.get_shader_parameter('stone_micro_normal').get_size()==Vector2(1024,1024),'Mobile binds the real 1024 micro normal')
	check(material.get_shader_parameter('stone_surface').get_size()==Vector2(1024,1024),'height cavity curvature wetness are actually bound')
	var surface: Dictionary=floor.get_meta('surface_spec')
	check(surface.wetness and surface.puddles and surface.triplanar and is_equal_approx(surface.height,.08),'floor records active height wetness and triplanar surface')
	var forward:=RenderingServer.get_current_rendering_method()=='forward_plus'
	check(material.get_shader_parameter('parallax_steps')==4,'balanced profile bounds parallax traversal at four steps')
	check(field.camera.attributes is CameraAttributesPractical and not field.camera.attributes.dof_blur_far_enabled,'balanced keeps native depth blur disabled')
	var profile=preload('res://scripts/maps3d/MythicDetailProfile.gd')
	profile.configure_camera_dof(field.map_root,true)
	var attributes: CameraAttributesPractical=field.camera.attributes
	check(attributes.dof_blur_far_enabled==forward and is_equal_approx(attributes.dof_blur_amount,.08 if forward else 0.0),'native DOF is Forward quality only, including when Mobile requests quality')
	if forward:
		var farthest:=0.0;var plane: PlaneMesh=floor.mesh
		for x in [-.5,.5]:
			for z in [-.5,.5]:
				var corner: Vector3=floor.to_global(Vector3(plane.size.x*x,0,plane.size.y*z))
				farthest=maxf(farthest,-field.camera.to_local(corner).z)
		check(attributes.dof_blur_far_distance>farthest and field.map_root.get_node('UltraDofFocus').wait_time==.5,'far DOF threshold reserves complete floor bounds with throttled refresh')
	profile.configure_camera_dof(field.map_root,false)
	check(not attributes.dof_blur_far_enabled and is_zero_approx(attributes.dof_blur_amount),'leaving quality disables blur immediately')
	check(preload('res://scripts/maps3d/MobileAmbientDust.gd').GROUP_COUNT==20,'Ultra atmosphere uses twenty batched dust groups')
	var environment: Environment=field.world.get_node('Atmosphere').environment
	check(environment.sky!=null and environment.sky.sky_material is ShaderMaterial and environment.sky.sky_material.shader.resource_path=='res://shaders/UltraMoonSky.gdshader','real moon and stars sky supplies reflections')
	check(environment.reflected_light_source==Environment.REFLECTION_SOURCE_SKY,'wet floor uses native image-based sky reflection')
	check(environment.ssr_enabled==forward and environment.ssao_enabled==forward and environment.ssil_enabled==forward,'unsupported Mobile screen-space passes remain off')
	check(environment.volumetric_fog_enabled==forward and environment.fog_enabled!=forward,'Mobile fog and native Forward volumetrics route separately')
	var footprints=field.world.get_node('UltraFloorFootprints');footprints.set_process(false)
	check(footprints.prints.multimesh.instance_count==50 and footprints._marks.size()==50,'footprints allocate exactly fifty reused instances')
	var rng: int=main.loot_rng.state;var battle: Dictionary=economic(main)
	for i in 120:footprints.emit_step(Vector2(i*.01,1),Vector2.RIGHT)
	check(footprints._next_slot==20 and footprints._marks.size()==50,'footprint overload reuses old slots rather than allocating nodes')
	check(main.loot_rng.state==rng and economic(main)==battle,'footprints cannot alter gameplay state or gameplay RNG')
	main.combat_running=false;var age: float=footprints._marks[0].age;footprints._process(2)
	check(is_equal_approx(age,footprints._marks[0].age),'pause holds the footprint lifetime clock')
	main.combat_effects_enabled=false;footprints._process(.5)
	check(not footprints.visible,'effects-off hides all pooled footprints')
	main.combat_effects_enabled=true;main.presentation_options['performance']='battery';footprints._process(.5)
	check(not footprints.visible,'battery profile omits pooled ground traces')
	await dispose(main);done('ULTRA_ENVIRONMENT')
