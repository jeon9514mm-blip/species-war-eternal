extends Node3D
## Painted floor and world-anchored scenery. Peripheral decoration never adds
## colliders, navigation rules or spawn points to the 32 x 20 hunting field.
var _art_rng := RandomNumberGenerator.new()
var _rock_mesh: SphereMesh
var _stone_materials: Array[StandardMaterial3D] = []
const GROUND_ART := "res://assets/art-direction/meadow-quality-02/meadow-ground.png"
const DETAIL_ART := "res://assets/art-direction/pilot-01/layers/ground-details.png"
const GRASS_SHADER := preload("res://assets/art-direction/meadow-quality-02/meadow-grass.gdshader")
const PROP_ART := "res://assets/art-direction/meadow-quality-02/environment-props.png"
const SCENERY := preload("res://scripts/art/HuntingSceneryCatalog.gd")
# Actual painted alpha bounds with gutters, rather than assuming equal cells.
const PROP_REGIONS := [Rect2(9,8,568,591),Rect2(593,3,403,593),Rect2(1001,56,531,518),Rect2(8,637,537,352),Rect2(557,603,481,399),Rect2(1043,594,472,421)]
const PROP_SITES := [
	[0,Vector2(-5,5),8.2], [1,Vector2(37,8),8.0],
	[1,Vector2(-7,21),6.5], [0,Vector2(39,24),7.2],
	[2,Vector2(2,-6),4.3], [3,Vector2(32,-5),2.6],
	[4,Vector2(-2,13),1.5], [4,Vector2(35,18),1.8],
	[5,Vector2(-1,19),1.2], [5,Vector2(33,3),1.1],
	[5,Vector2(8,24),1.0], [5,Vector2(25,-4),.9]
]
var _ground_material: ShaderMaterial
var _dapple_material: ShaderMaterial
var _detail_material: ShaderMaterial
var _grass_material: ShaderMaterial
var _prop_shadow_material: ShaderMaterial
var art_theme := "meadow"
var _profile: Dictionary

func _ready() -> void:
	_profile = SCENERY.profile(art_theme)
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
	_build_meadow_grass()
	_build_environment_props()
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
	env.ambient_light_color = Color(_profile.ambient)
	env.ambient_light_energy = .30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(_profile.exposure)
	env.ssao_enabled = true
	env.ssao_radius = .9
	env.ssao_intensity = .45
	env.ssao_power = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(_profile.fog)
	env.fog_density = .0015
	env.fog_sky_affect = 0
	var environment := WorldEnvironment.new()
	environment.name = "MeadowAtmosphere"
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "WarmAfternoonSun"
	sun.rotation_degrees = Vector3(-49, -32, 0)
	sun.light_color = Color(_profile.sun)
	sun.light_energy = float(_profile.sun_energy)
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
uniform vec3 distance_tint=vec3(.22,.30,.17);
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
        // Match the painting's 3:2 aspect on the ground. The old 64x88
        // mapping stretched every painted shape along the world Z axis.
        vec2 art_uv=(p-vec2(-16.0,-11.333333))/vec2(64.0,42.666667);
        // Preserve the painted feature scale throughout the scenery apron.
        // Mirroring outside the source avoids clamping a row into a grass wall.
        // In the actual 32x20 hunt this evaluates to the original affine UVs.
        art_uv=1.0-abs(mod(art_uv,vec2(2.0))-1.0);
        vec3 painted=texture(ground_art,clamp(art_uv,vec2(0.0),vec2(1.0))).rgb;
        float distant=(1.0-smoothstep(-36.0,-5.0,p.y))*.22;
        ground=mix(painted,distance_tint,distant);
    }
    ALBEDO=ground;
    ROUGHNESS=1.0;
    ALPHA=smoothstep(horizon_z,horizon_z+1.1,p.y+(noise(p*.8)-.5)*.35);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_ground_material = material
	if art_theme != "meadow":
		material.set_shader_parameter("distance_tint",Color(_profile.fog).srgb_to_linear())
	if ResourceLoader.exists(str(_profile.ground)):
		var texture := load(str(_profile.ground)) as Texture2D
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
uniform float art_time=0.0;
uniform vec3 shade_tint=vec3(.035,.075,.052);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_position.xz;
    if(p.y < horizon_z) { discard; }
    // Small canopy motion around fixed world points, never sliding the lawn.
    vec2 sway=vec2(sin(art_time*.46+p.y*.13),cos(art_time*.37+p.x*.09))*.14;
    float leaves=noise((p+sway)*.82)*.70+noise((p+sway)*2.1)*.30;
    float edge=1.0-smoothstep(2.0,8.0,min(min(p.x,32.0-p.x),min(p.y,20.0-p.y)));
    ALBEDO=shade_tint;
    ALPHA=smoothstep(.48,.74,leaves)*mix(.018,.10,edge)*smoothstep(horizon_z,horizon_z+2.8,p.y);
}
"""
	_dapple_material = ShaderMaterial.new()
	_dapple_material.shader = shader
	if art_theme == "canyon": _dapple_material.set_shader_parameter("shade_tint",Vector3(.085,.04,.024))
	var plane := PlaneMesh.new()
	plane.size = Vector2(120,100)
	var node := _mesh("GroundDapple",plane,_dapple_material,Vector3(16,-.02,10))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_horizon_z(value: float) -> void:
	if _ground_material != null: _ground_material.set_shader_parameter("horizon_z",value)
	if _dapple_material != null: _dapple_material.set_shader_parameter("horizon_z",value)
	if _detail_material != null: _detail_material.set_shader_parameter("horizon_z",value)
	if _grass_material != null: _grass_material.set_shader_parameter("horizon_z",value)
	if _prop_shadow_material != null: _prop_shadow_material.set_shader_parameter("horizon_z",value)

func set_atmosphere_time(value: float) -> void:
	# Use the existing pause-aware presentation clock; no shader TIME or RNG.
	if not is_finite(value): return
	if _dapple_material != null: _dapple_material.set_shader_parameter("art_time",value)
	if _grass_material != null: _grass_material.set_shader_parameter("art_time",value)

func _build_meadow_grass() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var palette: Array[Color] = []
	for color: String in _profile.grass: palette.append(Color(color).srgb_to_linear())
	# One batch of short upright blades around the outside of the engagement
	# area. No grass at the central party position and no new navigation nodes.
	var grass_rng := RandomNumberGenerator.new()
	grass_rng.seed = 1004202602
	for clump in 176:
		var at: Vector2
		match clump % 4:
			0: at = Vector2(grass_rng.randf_range(-7,4),grass_rng.randf_range(-7,27))
			1: at = Vector2(grass_rng.randf_range(28,39),grass_rng.randf_range(-7,27))
			2: at = Vector2(grass_rng.randf_range(4,28),grass_rng.randf_range(-7,2))
			_: at = Vector2(grass_rng.randf_range(4,28),grass_rng.randf_range(18,27))
		for blade in 5:
			var base := Vector3(at.x+grass_rng.randf_range(-.28,.28),-.012,at.y+grass_rng.randf_range(-.28,.28))
			var height := grass_rng.randf_range(.18,.44)
			var width := grass_rng.randf_range(.025,.055)
			var angle := grass_rng.randf_range(0,TAU)
			var side := Vector3(cos(angle),0,sin(angle))*width
			var lean := Vector3(grass_rng.randf_range(-.10,.10),0,grass_rng.randf_range(-.10,.10))
			var middle := base+Vector3.UP*height*.55+lean*.4
			var tip := base+Vector3.UP*height+lean
			var color := palette[clump%palette.size()]
			for vertex: Vector3 in [base-side,base+side,middle+side*.5,base-side,middle+side*.5,middle-side*.5,middle-side*.5,middle+side*.5,tip]:
				surface.set_normal(Vector3.UP)
				surface.set_color(color)
				surface.add_vertex(vertex)
	_grass_material = ShaderMaterial.new()
	_grass_material.shader = GRASS_SHADER
	var grass := _mesh("MeadowGrass",surface.commit(),_grass_material,Vector3.ZERO)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.set_meta("clump_count",176)
	grass.set_meta("central_clear_world_rect",Rect2(4,2,24,16))

func _build_environment_props() -> void:
	# Painted upright cards are 2.5D props, not newly modeled 3D trees. Their
	# roots, depth sorting and shadows belong to the same world as actor feet.
	var texture := load(str(_profile.props)) as Texture2D
	if texture == null: return
	var root := Node3D.new()
	root.name = "MeadowProps"
	add_child(root)
	var cells: Array[AtlasTexture] = []
	for cell in 6:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = _profile.regions[cell]
		cells.append(frame)
	var shadows := SurfaceTool.new()
	shadows.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in PROP_SITES.size():
		var site: Array = PROP_SITES[index]
		var cell: int = site[0]
		var at: Vector2 = site[1]
		var height: float = site[2]
		var sprite := Sprite3D.new()
		sprite.name = "MeadowProp%02d"%index
		sprite.texture = cells[cell]
		sprite.pixel_size = height/cells[cell].get_height()
		sprite.offset.y = cells[cell].get_height()*.5
		sprite.position = Vector3(at.x,0,at.y)
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = false
		sprite.double_sided = true
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = .12
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.set_meta("world_anchor",at)
		sprite.set_meta("prop_cell",cell)
		root.add_child(sprite)
		var span := Vector2(height*.47,height*.22) if cell<2 else Vector2(height*.42,height*.30)
		var corners: Array[Vector2] = [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
		var uvs: Array[Vector2] = [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
		for vertex in [0,2,1,0,3,2]:
			var point := at+Vector2(.35,.25)+(corners[vertex]*span).rotated(-.4)
			shadows.set_normal(Vector3.UP)
			shadows.set_color(Color(1,1,1,.19 if cell<2 else .14))
			shadows.set_uv(uvs[vertex])
			shadows.add_vertex(Vector3(point.x,-.006,point.y))
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float horizon_z=-30.0;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    if(world_position.z < horizon_z) { discard; }
    vec2 p=(UV-.5)*2.0;
    float distance=dot(p,p);
    ALBEDO=vec3(.025,.045,.032);
    ALPHA=exp(-distance*3.0)*(1.0-smoothstep(.65,1.0,length(p)))*COLOR.a;
}
"""
	_prop_shadow_material = ShaderMaterial.new()
	_prop_shadow_material.shader = shader
	var shadow := _mesh("PropContactShadows",shadows.commit(),_prop_shadow_material,Vector3.ZERO)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_ground_details() -> void:
	# One atlas and one mesh batch. Every patch is fixed to the real world floor;
	# it neither moves with parallax layers nor adds collisions or spawn rules.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D detail_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_atlas=true;
uniform vec3 detail_tint=vec3(.16,.12,.07);
uniform float horizon_z=-30.0;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec4 paint=texture(detail_atlas,UV);
    if(!use_atlas) {
        vec2 p=fract(UV*vec2(3.0,2.0))*2.0-1.0;
        float shape=1.0-smoothstep(.45,.75,length(p*vec2(1.0,1.3)));
        paint=vec4(detail_tint*(1.0+.15*p.y),shape);
    }
    ALBEDO=paint.rgb;
    ALPHA=paint.a*COLOR.a*.88*smoothstep(horizon_z,horizon_z+2.8,world_position.z);
}
"""
	_detail_material = ShaderMaterial.new()
	_detail_material.shader = shader
	_detail_material.set_shader_parameter("detail_atlas", load(DETAIL_ART))
	_detail_material.set_shader_parameter("use_atlas",art_theme=="meadow")
	_detail_material.set_shader_parameter("detail_tint",Color("987954" if art_theme=="canyon" else "476756").srgb_to_linear())
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
		var patch_size := _art_rng.randf_range(1.35,2.65) if art_theme=="meadow" else _art_rng.randf_range(.4,.9)
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
