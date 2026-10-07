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
	for node in map_root.find_children('*','DirectionalLight3D',true,false):
		node.light_angular_distance=.65;node.shadow_blur=1.15
		node.shadow_bias=.04;node.shadow_normal_bias=.7
