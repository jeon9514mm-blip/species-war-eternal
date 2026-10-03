extends Node3D
## Original procedural art study. All decoration sits outside the 32 x 20
## gameplay lawn. There are no new colliders, navigation rules or spawn points.
var _art_rng := RandomNumberGenerator.new()
var _leaf_mesh: SphereMesh
var _rock_mesh: SphereMesh
var _leaf_materials: Array[StandardMaterial3D] = []
var _stone_materials: Array[StandardMaterial3D] = []
var _crown_layers: Array = [[], [], [], [], []]
var _leaf_layers: Array = [[], [], [], [], []]
const GROUND_ART := "res://assets/art-direction/pilot-01/meadow-ground.png"

func _ready() -> void:
	_art_rng.seed = 10032026
	_leaf_mesh = SphereMesh.new()
	_leaf_mesh.radius = 1
	_leaf_mesh.height = 2
	_leaf_mesh.radial_segments = 9
	_leaf_mesh.rings = 5
	_rock_mesh = SphereMesh.new()
	_rock_mesh.radius = 1
	_rock_mesh.height = 2
	_rock_mesh.radial_segments = 7
	_rock_mesh.rings = 3
	for color: String in ["356841", "487748", "5f844b", "729554", "94ab66"]:
		_leaf_materials.append(_material(Color(color)))
	for color: String in ["afb3a0", "929b8c", "c1bd9f"]:
		_stone_materials.append(_material(Color(color)))
	_build_light()
	_build_ground()
	_build_distant_landscape()
	_build_border()
	_finish_foliage()
	_build_meadow_detail()
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
	env.background_mode = Environment.BG_COLOR
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
render_mode specular_disabled;
uniform sampler2D ground_art : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_ground_art = false;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_position.xz;
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
        vec2 art_uv=(p-vec2(-16.0,-12.0))/vec2(64.0,44.0);
        float edge=min(min(art_uv.x,1.0-art_uv.x),min(art_uv.y,1.0-art_uv.y));
        float blend=smoothstep(0.0,.04,edge);
        vec3 painted=texture(ground_art,clamp(art_uv,vec2(0.0),vec2(1.0))).rgb;
        ground=mix(ground,painted,blend);
    }
    ALBEDO=ground;
    ROUGHNESS=1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	if ResourceLoader.exists(GROUND_ART):
		var texture := load(GROUND_ART) as Texture2D
		if texture != null:
			material.set_shader_parameter("ground_art", texture)
			material.set_shader_parameter("has_ground_art", true)
	var floor := PlaneMesh.new()
	floor.size = Vector2(120, 100)
	_mesh("QuietPlayLawn", floor, material, Vector3(16, -.035, 10))

func _build_distant_landscape() -> void:
	# Desaturated distance layers; deliberate broad shapes keep the battlefield
	# readable instead of adding the texture noise of the earlier cavern scene.
	var far_material := _material(Color("8eaeb0"))
	var middle_material := _material(Color("91aa8b"))
	for i in 9:
		var at := Vector3(-42 + i * 14, -2, -39 - _art_rng.randf_range(0, 8))
		_mesh("DistantBlueHill", _leaf_mesh, far_material, at, Vector3(15, _art_rng.randf_range(12, 19), 11))
	for i in 10:
		var at := Vector3(-40 + i * 12, -3, -25 - _art_rng.randf_range(0, 5))
		_mesh("SageHill", _leaf_mesh, middle_material, at, Vector3(13, _art_rng.randf_range(6, 10), 8))
	var clouds := _material(Color("e9ede0"))
	clouds.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 12:
		_mesh("SoftCloud", _leaf_mesh, clouds, Vector3(-40 + i * 11, 19 + sin(i * 1.7) * 2, -54), Vector3(8, 1.5, 3))

func _build_border() -> void:
	for i in 12:
		_tree(Vector3(-9 + i * 4.7, 0, -5.3 - _art_rng.randf_range(0, 3)), _art_rng.randf_range(.78, 1.18))
	for i in 5:
		_tree(Vector3(-5 - _art_rng.randf_range(0, 2), 0, i * 6 + 1), _art_rng.randf_range(.85, 1.15))
		_tree(Vector3(37 + _art_rng.randf_range(0, 2), 0, i * 6 + 1), _art_rng.randf_range(.85, 1.15))
	for point: Vector3 in [Vector3(-3, 0, 25), Vector3(4, 0, 27), Vector3(30, 0, 27), Vector3(37, 0, 25)]:
		_tree(point, .85)
	for i in 32:
		var point := _border_point(i % 4, 2, 5)
		var scale_value := Vector3(_art_rng.randf_range(.4, 1.2), _art_rng.randf_range(.3, .85), _art_rng.randf_range(.4, .9))
		var rock := _mesh("WeatheredStone", _rock_mesh, _stone_materials[i % _stone_materials.size()], point, scale_value)
		rock.rotation.y = _art_rng.randf_range(0, TAU)

func _border_point(side: int, near: float, far: float) -> Vector3:
	var margin := _art_rng.randf_range(near, far)
	match side:
		0: return Vector3(-margin, 0, _art_rng.randf_range(-2, 22))
		1: return Vector3(32 + margin, 0, _art_rng.randf_range(-2, 22))
		2: return Vector3(_art_rng.randf_range(-2, 34), 0, -margin)
		_: return Vector3(_art_rng.randf_range(-2, 34), 0, 20 + margin)

func _tree(point: Vector3, factor: float) -> void:
	var bark := _material(Color("7c7450"))
	var trunk := CylinderMesh.new()
	trunk.top_radius = .24
	trunk.bottom_radius = .46
	trunk.height = 3.8
	trunk.radial_segments = 7
	_mesh("SoftOakTrunk", trunk, bark, point + Vector3(0, 1.8 * factor, 0), Vector3.ONE * factor)
	# Small overlapping, flattened clusters form an irregular crown silhouette.
	# Global MultiMesh layers retain five draw groups across all trees.
	for j in 68:
		var u := float(j) / 68.0
		var angle := j * 2.3999632
		var radius := sqrt(u) * 2.25
		var crown := point + Vector3(cos(angle) * radius, 3.35 + sqrt(1 - u) * 1.8 + _art_rng.randf_range(-.16, .16), sin(angle) * radius * .86) * factor
		var scale_value := Vector3(_art_rng.randf_range(.38, .76), _art_rng.randf_range(.19, .36), _art_rng.randf_range(.35, .65)) * factor
		var basis := Basis(Vector3.UP, _art_rng.randf_range(0, TAU)).scaled(scale_value)
		var tone := clampi(int((1 - u) * 3) + _art_rng.randi_range(0, 1), 0, 4)
		_crown_layers[tone].append(Transform3D(basis, crown))
	for j in 160:
		var u := _art_rng.randf()
		var angle := j * 2.3999632
		var radius := sqrt(u) * 2.7
		var position_value := point + Vector3(cos(angle) * radius, 3.60 + sqrt(1 - u) * 1.75, sin(angle) * radius * .87) * factor
		var scale_value := Vector3(_art_rng.randf_range(.23, .44), .5, _art_rng.randf_range(.23, .44)) * factor
		var basis := Basis(Vector3.UP, angle + .7).rotated(Vector3.RIGHT, _art_rng.randf_range(-.4, .4)).scaled(scale_value)
		_leaf_layers[_art_rng.randi_range(1, 4)].append(Transform3D(basis, position_value))
	# A broad moss bank blends the trunk into the lawn without hiding arrivals.
	for j in 4:
		var offset := Vector3(cos(j * 1.7) * .62, .1, sin(j * 1.7) * .55) * factor
		_mesh("MossBank", _leaf_mesh, _leaf_materials[j % 2], point + offset, Vector3(.95, .20, .70) * factor)

func _finish_foliage() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := [Vector3(-1, 0, 0), Vector3(-.45, .02, .58), Vector3(.4, .06, .48), Vector3(1, 0, 0), Vector3(.4, .03, -.5), Vector3(-.5, .01, -.55)]
	for i in rim.size():
		surface.add_vertex(Vector3(0, .16, 0))
		surface.add_vertex(rim[(i + 1) % rim.size()])
		surface.add_vertex(rim[i])
	surface.generate_normals()
	var leaf_mesh := surface.commit()
	for tone in _leaf_materials.size():
		_batch_foliage("LeafClusterLayer", _leaf_mesh, _leaf_materials[tone], _crown_layers[tone])
		var material := _leaf_materials[tone].duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_batch_foliage("PointedLeafLayer", leaf_mesh, material, _leaf_layers[tone])

func _batch_foliage(named: String, mesh: Mesh, material: Material, transforms: Array) -> void:
	if transforms.is_empty(): return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size(): multi.set_instance_transform(i, transforms[i])
	var layer := MultiMeshInstance3D.new()
	layer.name = named
	layer.multimesh = multi
	layer.material_override = material
	add_child(layer)

func _build_meadow_detail() -> void:
	var blade := QuadMesh.new()
	blade.size = Vector2(.13, .36)
	var grass_material := _material(Color("87995b"))
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grass := MultiMesh.new()
	grass.transform_format = MultiMesh.TRANSFORM_3D
	grass.mesh = blade
	grass.instance_count = 360
	for i in grass.instance_count:
		var point := _border_point(i % 4, .35, 4)
		# Decoration never changes navigability, and stays low near the edge.
		var transform_value := Transform3D(Basis(Vector3.UP, _art_rng.randf_range(0, TAU)), point + Vector3(0, .18, 0))
		grass.set_instance_transform(i, transform_value)
	var blades := MultiMeshInstance3D.new()
	blades.name = "EdgeGrassBrushes"
	blades.multimesh = grass
	blades.material_override = grass_material
	blades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blades)
	var petals := _material(Color("e5deb4"))
	for i in 55:
		var x := _art_rng.randf_range(-1, 33)
		var z := _art_rng.randf_range(20.5, 23) if i % 2 == 0 else _art_rng.randf_range(-3, -.5)
		_mesh("MeadowFlower", _leaf_mesh, petals, Vector3(x, .20, z), Vector3(.13, .08, .13))
