extends RefCounted
## Working Godot equivalents of the supplied Meta v33 visual intentions.
## No external plugin, neural model, skeletal deformation or stat changes.
static func configure(map_root: Node3D) -> void:
	var forward:=RenderingServer.get_current_rendering_method()=='forward_plus'
	for node in map_root.find_children('*','WorldEnvironment',true,false):
		var environment: Environment=node.environment
		if environment==null:continue
		environment.ssao_enabled=forward
		environment.ssao_radius=.75;environment.ssao_intensity=.65
		environment.ssil_enabled=forward
		environment.ssil_radius=2.5;environment.ssil_intensity=.30
		environment.glow_intensity=.45;environment.glow_strength=.9
	for node in map_root.find_children('*','DirectionalLight3D',true,false):
		node.light_angular_distance=.65;node.shadow_blur=1.15
		node.shadow_bias=.04;node.shadow_normal_bias=.7
		node.light_energy=.9
	var field: Node=map_root.get_parent()
	while field!=null and not field.has_method('battle_clock_running'):field=field.get_parent()
	var raid: bool=field!=null and field.raid_mode
	var floor: MeshInstance3D=map_root.get_node_or_null('Arena/PBRStoneSlabs1024')
	if floor!=null:
		var material:=ShaderMaterial.new();material.shader=preload('res://shaders/FinalStonePBR.gdshader')
		material.set_shader_parameter('stone_art',load('res://assets/mobile25d/floor/stone_1024_albedo_ao.png'))
		material.set_shader_parameter('stone_normal',load('res://assets/mobile25d/floor/stone_1024_normal.png'))
		# Each 1024 tile already contains three slabs across. The closer hunt
		# camera needs 2x slabs; the wider raid composition benefits from 4x.
		var display_scale:=4.0 if raid else 2.0
		var tile_scale:=Vector2(80.0/36.0*10,60.0/24.0*7)/display_scale
		material.set_shader_parameter('tile_scale',tile_scale)
		material.set_shader_parameter('moss_glow',.15);floor.material_override=material
		floor.set_meta('surface_spec',{'moss':.15,'patina':.20,'edge_wear':.6,'crack_dark':.35,'ao':.5,'slab_display_scale':display_scale,'tile_scale':tile_scale})
	if raid:
		var mood:=preload('res://scripts/maps3d/RaidFinalAtmosphere.gd').new();mood.field=field
		map_root.get_node('Arena').add_child(mood)
