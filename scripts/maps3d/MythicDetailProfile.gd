extends RefCounted
## Renderer-aware Ultra floor/light profile. Presentation never writes battle data.
static func configure(map_root: Node3D) -> void:
	var forward:=RenderingServer.get_current_rendering_method()=='forward_plus'
	for node in map_root.find_children('*','WorldEnvironment',true,false):
		var environment: Environment=node.environment
		if environment==null:continue
		environment.ssao_enabled=forward
		environment.ssao_radius=.75;environment.ssao_intensity=.7
		environment.ssil_enabled=forward
		environment.ssil_radius=2.5;environment.ssil_intensity=.30
		environment.ssr_enabled=forward;environment.ssr_max_steps=16
		environment.sdfgi_enabled=forward;environment.sdfgi_bounce_feedback=.65 if forward else 0.0
		environment.sdfgi_use_occlusion=forward
		environment.glow_enabled=forward;environment.glow_intensity=.6;environment.glow_strength=.9
		environment.volumetric_fog_enabled=forward;environment.volumetric_fog_density=.006
		environment.volumetric_fog_length=48;environment.volumetric_fog_anisotropy=.25
		environment.volumetric_fog_albedo=Color('#a8b89e');environment.volumetric_fog_ambient_inject=.05
		environment.fog_enabled=not forward;environment.fog_density=.0018
		environment.fog_light_color=Color('#a8b8bf');environment.fog_light_energy=.6
		environment.fog_sun_scatter=.15;environment.fog_sky_affect=.15
		var sky:=Sky.new();sky.radiance_size=Sky.RADIANCE_SIZE_128
		var moon:=ShaderMaterial.new();moon.shader=preload('res://shaders/UltraMoonSky.gdshader')
		sky.sky_material=moon;sky.process_mode=Sky.PROCESS_MODE_QUALITY
		environment.sky=sky;environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	for node in map_root.find_children('*','DirectionalLight3D',true,false):
		node.light_angular_distance=.65;node.shadow_blur=1.15
		node.shadow_bias=.04;node.shadow_normal_bias=.7
		node.light_energy=1.0
	var field: Node=map_root.get_parent()
	while field!=null and not field.has_method('battle_clock_running'):field=field.get_parent()
	var raid: bool=field!=null and field.raid_mode
	var floor: MeshInstance3D=map_root.get_node_or_null('Arena/PBRStoneSlabs1024')
	if floor!=null:
		var material:=ShaderMaterial.new();material.shader=preload('res://shaders/FinalStonePBR.gdshader')
		material.set_shader_parameter('stone_art',load('res://assets/mobile25d/floor/stone_1024_albedo_ao.png'))
		material.set_shader_parameter('stone_normal',load('res://assets/mobile25d/floor/stone_1024_normal.png'))
		material.set_shader_parameter('stone_micro_normal',load('res://assets/mobile25d/floor/stone_1024_micro_normal.png'))
		material.set_shader_parameter('stone_surface',load('res://assets/mobile25d/floor/stone_1024_surface.png'))
		material.set_shader_parameter('parallax_steps',8 if forward else 4)
		# Each 1024 tile already contains three slabs across. The closer hunt
		# camera needs 2x slabs; the wider raid composition benefits from 4x.
		var display_scale:=4.0 if raid else 2.0
		var tile_scale:=Vector2(80.0/36.0*10,60.0/24.0*7)/display_scale
		material.set_shader_parameter('tile_scale',tile_scale)
		material.set_shader_parameter('moss_glow',.25);floor.material_override=material
		floor.set_meta('surface_spec',{'moss':.18,'patina':.25,'edge_wear':.8,'edge_wear_stages':2,'crack_dark':.4,'ao':.7,'height':.08,'wetness':true,'puddles':true,'triplanar':true,'micro_normal':1024,'slab_display_scale':display_scale,'tile_scale':tile_scale})
	if field!=null and map_root.get_node_or_null('Arena/UltraFloorFootprints')==null:
		var footprints:=preload('res://scripts/maps3d/UltraFloorFootprints.gd').new();footprints.field=field
		map_root.get_node('Arena').add_child(footprints)
	if raid:
		var mood:=preload('res://scripts/maps3d/RaidFinalAtmosphere.gd').new();mood.field=field
		map_root.get_node('Arena').add_child(mood)
	map_root.set_meta('ultra_environment',{'native_forward_plus':forward,'sky':'moon and stars reflection sky','ssr':forward,'ssao':forward,'ssil':forward,'sdfgi':forward,'volumetric_fog':forward,'mobile_fog':'exponential fog plus analytic shafts','requested_sdfgi_bounces':2,'actual_sdfgi_bounce_feedback':.65 if forward else 0.0})
static func configure_quality(map_root: Node3D,high_quality: bool) -> void:
	configure_camera_dof(map_root,high_quality)
	var floor: MeshInstance3D=map_root.get_node_or_null('Arena/PBRStoneSlabs1024')
	if floor==null or not floor.material_override is ShaderMaterial:return
	var material: ShaderMaterial=floor.material_override
	var micro_size:=4096 if high_quality else 1024
	material.set_shader_parameter('stone_micro_normal',load('res://assets/mobile25d/floor/stone_'+str(micro_size)+'_micro_normal.png'))
	material.set_shader_parameter('parallax_steps',8 if high_quality else 4)
	var specification: Dictionary=floor.get_meta('surface_spec',{})
	specification['micro_normal']=micro_size;floor.set_meta('surface_spec',specification)
static func configure_camera_dof(map_root: Node3D,high_quality: bool) -> void:
	var camera: Camera3D=map_root.get_node_or_null('Arena/BattleCamera')
	if camera==null:return
	var enabled: bool=high_quality and RenderingServer.get_current_rendering_method()=='forward_plus'
	var attributes:=camera.attributes as CameraAttributesPractical
	if attributes==null:
		attributes=CameraAttributesPractical.new();camera.attributes=attributes
	attributes.dof_blur_near_enabled=false;attributes.dof_blur_far_enabled=enabled
	attributes.dof_blur_amount=.08 if enabled else 0.0;attributes.dof_blur_far_transition=6.0
	var timer:=map_root.get_node_or_null('UltraDofFocus') as Timer
	if enabled:
		var floor:=map_root.get_node_or_null('Arena/PBRStoneSlabs1024') as MeshInstance3D
		refresh_dof(camera,floor)
		if timer==null:
			timer=Timer.new();timer.name='UltraDofFocus';timer.wait_time=.5
			map_root.add_child(timer);timer.timeout.connect(refresh_dof.bind(camera,floor))
		timer.start()
	elif timer!=null:timer.stop()
	camera.set_meta('ultra_dof',{'enabled':enabled,'renderer_gate':'Forward+ quality only','focus':'complete combat floor remains sharp','amount':attributes.dof_blur_amount})
static func refresh_dof(camera: Camera3D,floor: MeshInstance3D) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(floor):return
	var attributes:=camera.attributes as CameraAttributesPractical
	if attributes==null or not attributes.dof_blur_far_enabled:return
	var plane:=floor.mesh as PlaneMesh
	if plane==null:return
	# Ortho depth varies across a tilted floor. Reserve the entire actual floor,
	# not just its center, so distant heroes and boss paint stay in focus.
	var center_depth: float=-camera.to_local(floor.global_position).z
	var half_x: float=absf(floor.global_basis.x.dot(camera.global_basis.z))*plane.size.x*.5
	var half_z: float=absf(floor.global_basis.z.dot(camera.global_basis.z))*plane.size.y*.5
	attributes.dof_blur_far_distance=maxf(camera.near+1.0,center_depth+half_x+half_z+maxf(1.0,camera.size*.05))
