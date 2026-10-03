extends Node3D
## Painted world floor with atmosphere. All decoration sits outside the 32 x 20
## gameplay lawn. There are no new colliders, navigation rules or spawn points.
var _art_rng := RandomNumberGenerator.new()
var _rock_mesh: SphereMesh
var _stone_materials: Array[StandardMaterial3D] = []
const GROUND_ART := "res://assets/art-direction/pilot-01/meadow-ground.png"
const DETAIL_ART := "res://assets/art-direction/pilot-01/layers/ground-details.png"
var _ground_material: ShaderMaterial
var _dapple_material: ShaderMaterial
var _detail_material: ShaderMaterial

func _ready() -> void:
	_art_rng.seed = 10032026
	_rock_mesh = SphereMesh.new()
	_rock_mesh.radius = 1
	_rock_mesh.height = 2
	_rock_mesh.radial_segments = 7
	_rock_mesh.rings = 3
	for color: String in ["afb3a0", "929b8c", "c1bd9f"]:
		_stone_materials.append(_material(Color(color)))
	_build_light()
	_build_ground()
	_build_ground_dapple()
	_build_ground_details()
	# Painted layers now own trees, village and mountains. Retain only a few
	# quiet 3D stones outside the unmodified playable rectangle.
	for i in 8:
		var point := _border_point(i % 4, 2.5, 5)
		_mesh("EdgeStone", _rock_mesh, _stone_materials[i%3], point, Vector3(.34,.20,.27))
	var camera := Camera3D.new()
	camera.name = "BattleCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.far = 240
	add_child(camera)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material

func _mesh(named: String, mesh: Mesh, material: Material, at: Vector3, scale_value := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = named
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.scale = scale_value
	add_child(node)
	return node

func _build_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color("b5d4d1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c5dacb")
	env.ambient_light_energy = .30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = .85
	env.ssao_enabled = true
	env.ssao_radius = .9
	env.ssao_intensity = .45
	env.ssao_power = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("c7dfd0")
	env.fog_density = .0015
	env.fog_sky_affect = 0
	var environment := WorldEnvironment.new()
	environment.name = "MeadowAtmosphere"
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "WarmAfternoonSun"
	sun.rotation_degrees = Vector3(-49, -32, 0)
	sun.light_color = Color("fff3df")
	sun.light_energy = .84
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.light_angular_distance = 1.6
	add_child(sun)

func _build_ground() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode specular_disabled, depth_prepass_alpha;
uniform sampler2D ground_art : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_ground_art = false;
uniform float horizon_z = -30.0;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_position.xz;
    if (p.y < horizon_z) { discard; }
    float patch=noise(p*.22)*.62+noise(p*.61+17.0)*.26+noise(p*2.2)*.12;
    // ALBEDO values are linear; these intentionally remain below sRGB swatches.
    vec3 grass=mix(vec3(.105,.175,.065),vec3(.24,.32,.12),smoothstep(.1,.95,patch));
    float brush=noise(p*vec2(5.0,1.7));
    grass+=vec3(.013,.018,.008)*(brush-.5);
    float lane=abs(p.y-(10.0+sin(p.x*.20)*1.25));
    float trail=(1.0-smoothstep(1.0,3.6,lane+noise(p*1.4)*.72))*.27;
    vec3 soil=vec3(.32,.29,.15);
    vec3 ground=mix(grass,soil,trail);
    if (has_ground_art) {
        // Presentation apron: the painting extends well beyond the unchanged
        // 32 x 20 hunting bounds, so overview never exposes a carpet-like edge.
        vec2 art_uv=(p-vec2(-16.0,-34.0))/vec2(64.0,88.0);
        float edge=min(min(art_uv.x,1.0-art_uv.x),min(art_uv.y,1.0-art_uv.y));
        float blend=smoothstep(0.0,.04,edge);
        vec3 painted=texture(ground_art,clamp(art_uv,vec2(0.0),vec2(1.0))).rgb;
        ground=mix(ground,painted,blend);
    }
    ALBEDO=ground;
    ROUGHNESS=1.0;
    ALPHA=smoothstep(horizon_z,horizon_z+2.8,p.y+(noise(p*.8)-.5)*.55);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_ground_material = material
	if ResourceLoader.exists(GROUND_ART):
		var texture := load(GROUND_ART) as Texture2D
		if texture != null:
			material.set_shader_parameter("ground_art", texture)
			material.set_shader_parameter("has_ground_art", true)
	var floor := PlaneMesh.new()
	floor.size = Vector2(120, 100)
	_mesh("QuietPlayLawn", floor, material, Vector3(16, -.035, 10))

func _build_ground_dapple() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float horizon_z=-30.0;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_position.xz;
    if(p.y < horizon_z) { discard; }
    float patch=sin(p.x*.41+sin(p.y*.26)*1.6)*sin(p.y*.55-p.x*.13);
    ALBEDO=vec3(.07,.13,.08);
    ALPHA=smoothstep(.20,.8,patch)*.075*smoothstep(horizon_z,horizon_z+.8,p.y);
}
"""
	_dapple_material = ShaderMaterial.new()
	_dapple_material.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(120,100)
	var node := _mesh("GroundDapple",plane,_dapple_material,Vector3(16,-.02,10))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_horizon_z(value: float) -> void:
	if _ground_material != null: _ground_material.set_shader_parameter("horizon_z",value)
	if _dapple_material != null: _dapple_material.set_shader_parameter("horizon_z",value)
	if _detail_material != null: _detail_material.set_shader_parameter("horizon_z",value)

func _build_ground_details() -> void:
	# One atlas and one mesh batch. Every patch is fixed to the real world floor;
	# it neither moves with parallax layers nor adds collisions or spawn rules.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D detail_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float horizon_z=-30.0;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec4 paint=texture(detail_atlas,UV);
    ALBEDO=paint.rgb;
    ALPHA=paint.a*COLOR.a*.88*smoothstep(horizon_z,horizon_z+2.8,world_position.z);
}
"""
	_detail_material = ShaderMaterial.new()
	_detail_material.shader = shader
	_detail_material.set_shader_parameter("detail_atlas", load(DETAIL_ART))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Irregular edge groups leave the central engagement space quiet. Original
	# six atlas cells are reused at different sizes and rotations, never tiled.
	var sites: Array[Vector2] = [Vector2(-3,1),Vector2(1,3),Vector2(5,-3),
		Vector2(11,-5),Vector2(23,-4),Vector2(29,1),Vector2(35,5),
		Vector2(-2,8),Vector2(2,15),Vector2(29,16),Vector2(34,11),
		Vector2(-4,22),Vector2(3,23),Vector2(8,26),Vector2(14,24),
		Vector2(23,25),Vector2(29,23),Vector2(35,21),Vector2(-9,12),
		Vector2(41,15),Vector2(1,-9),Vector2(28,-10),Vector2(8,19),Vector2(24,4)]
	for i in sites.size():
		var cell := i % 6
		var patch_size := _art_rng.randf_range(1.35,2.65)
		var angle := _art_rng.randf_range(-.55,.55)
		var uv_origin := Vector2(cell % 3, cell / 3) / Vector2(3,2)
		var local: Array[Vector2] = [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]
		var uvs: Array[Vector2] = [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
		for index in [0,2,1,0,3,2]:
			var at: Vector2 = sites[i]+(local[index]*patch_size).rotated(angle)
			surface.set_normal(Vector3.UP)
			surface.set_color(Color(1,1,1,.90 if i<11 else 1.0))
			surface.set_uv(uv_origin+(uvs[index]*.96+Vector2(.02,.02))/Vector2(3,2))
			surface.add_vertex(Vector3(at.x,-.011,at.y))
	var details := _mesh("GroundDetails",surface.commit(),_detail_material,Vector3.ZERO)
	details.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	details.set_meta("patch_count", sites.size())
	details.set_meta("atlas_cells", Vector2i(3,2))

func _border_point(side: int, near: float, far: float) -> Vector3:
	var margin := _art_rng.randf_range(near, far)
	match side:
		0: return Vector3(-margin, 0, _art_rng.randf_range(-2, 22))
		1: return Vector3(32 + margin, 0, _art_rng.randf_range(-2, 22))
		2: return Vector3(_art_rng.randf_range(-2, 34), 0, -margin)
		_: return Vector3(_art_rng.randf_range(-2, 34), 0, 20 + margin)
