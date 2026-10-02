extends SceneTree
## Godot-native cavern construction. All output objects are editable geometry.
var scene: Node3D
var rng:=RandomNumberGenerator.new()
var author=preload('res://tools/ForestMeshAuthor.gd').new()
var rocks: Array[ArrayMesh]=[]
var stone: ShaderMaterial
var ice: ShaderMaterial
var dark: StandardMaterial3D
var frost: StandardMaterial3D
var trim: StandardMaterial3D
var rune: StandardMaterial3D
var glow: StandardMaterial3D
var sigils: SurfaceTool
var column_mesh: CylinderMesh
var tip_mesh: CylinderMesh
func _init() -> void: build.call_deferred()
func build() -> void:
	rng.seed=837014
	for i in 4:rocks.append(author.rock(120+i))
	materials()
	column_mesh=CylinderMesh.new();column_mesh.top_radius=.60;column_mesh.bottom_radius=1;column_mesh.height=1;column_mesh.radial_segments=7;column_mesh.rings=4
	tip_mesh=CylinderMesh.new();tip_mesh.top_radius=0;tip_mesh.bottom_radius=.60;tip_mesh.height=.9;tip_mesh.radial_segments=7
	for raid in [false,true]:
		rng.seed=837014
		scene=Node3D.new();scene.set_script(load('res://scripts/maps3d/CavernRuntime.gd'));scene.name='IceCavernRaid' if raid else 'IceCavernField';root.add_child(scene)
		lighting();arena_floor();cliffs();walls();door();atmosphere()
		var packed:=PackedScene.new();assert(packed.pack(scene)==OK)
		assert(ResourceSaver.save(packed,'res://scenes/maps3d/'+scene.name+'.tscn')==OK)
		print('Built ',scene.name,' nodes=',scene.get_child_count());scene.free()
	quit()
func own(node: Node,parent: Node=null) -> void:
	(parent if parent!=null else scene).add_child(node);node.owner=scene
func plain(c: String,rough:=.8) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(c);m.roughness=rough;return m
func materials() -> void:
	stone=ShaderMaterial.new();stone.shader=load('res://assets/maps3d/materials/detail_rock.gdshader');stone.set_shader_parameter('rock_texture',load('res://assets/maps3d/pbr/rock_boulder_cracked_diff.jpg'));stone.set_shader_parameter('tint',Color('#637986'));stone.set_shader_parameter('texture_scale',.34)
	ice=ShaderMaterial.new();ice.shader=load('res://assets/maps3d/materials/ice.gdshader');ice.set_shader_parameter('ice_color',load('res://assets/maps3d/pbr/ice2k/Ice003_2K-JPG_Color.jpg'));ice.set_shader_parameter('ice_normal',load('res://assets/maps3d/pbr/ice2k/Ice003_2K-JPG_NormalGL.jpg'))
	dark=plain('#142430',.72);frost=plain('#b0d3de',.52);trim=plain('#64818c',.36);trim.metallic=.65
	rune=plain('#429bad',.32);rune.emission_enabled=true;rune.emission=Color('#1392c1');rune.emission_energy_multiplier=1.7
	glow=plain('#96f4ff',.2);glow.emission_enabled=true;glow.emission=Color('#3eceff');glow.emission_energy_multiplier=4.0
func mesh_node(name_key: String,mesh: Mesh,p: Vector3,material: Material,scale_value:=Vector3.ONE) -> MeshInstance3D:
	var n:=MeshInstance3D.new();n.name=name_key;n.mesh=mesh;n.material_override=material;n.position=p;n.scale=scale_value;own(n);return n
func block(name_key: String,p: Vector3,dimensions: Vector3,material: Material=stone) -> MeshInstance3D:
	return mesh_node(name_key,rocks[rng.randi_range(0,3)],p,material,dimensions)
func cylinder(name_key: String,p: Vector3,radius: float,height: float,material: Material) -> MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=128
	return mesh_node(name_key,mesh,p,material)
func lighting() -> void:
	var env:=WorldEnvironment.new();env.name='CavernAtmosphere';env.environment=Environment.new();var e:=env.environment
	e.background_mode=Environment.BG_COLOR;e.background_color=Color('#1c3046')
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color('#6e91bd');e.ambient_light_energy=.34
	var sky:=Sky.new();var sky_mat:=ProceduralSkyMaterial.new();sky_mat.sky_top_color=Color('#263e64');sky_mat.sky_horizon_color=Color('#a0c0d4');sky_mat.ground_bottom_color=Color('#060c14');sky_mat.ground_horizon_color=Color('#344757');sky.sky_material=sky_mat;e.sky=sky;e.reflected_light_source=1
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;e.tonemap_exposure=1.0
	e.ssao_enabled=true;e.ssao_radius=2.0;e.ssao_intensity=2.1;e.ssao_power=1.4
	e.glow_enabled=true;e.glow_intensity=.7;e.glow_bloom=.12;e.glow_hdr_threshold=1.1
	e.volumetric_fog_enabled=true;e.volumetric_fog_density=.004;e.volumetric_fog_albedo=Color('#6f8aa3');e.volumetric_fog_length=140
	e.fog_enabled=true;e.fog_light_color=Color('#142840');e.fog_density=.004;e.fog_sky_affect=0
	own(env)
	var sun:=DirectionalLight3D.new();sun.name='MoonlightThroughIce';sun.rotation_degrees=Vector3(-56,-32,0);sun.light_color=Color('#bedfff');sun.light_energy=1.6;sun.shadow_enabled=true;sun.directional_shadow_max_distance=130;sun.shadow_bias=.025;sun.shadow_normal_bias=.45;sun.light_angular_distance=1.5;own(sun)
	var fill:=DirectionalLight3D.new();fill.name='VioletCavernBounce';fill.rotation_degrees=Vector3(-25,115,0);fill.light_color=Color('#8c78c9');fill.light_energy=.42;own(fill)
	for p in [Vector3(-6,5,10),Vector3(37,6,7),Vector3(16,5,-11),Vector3(16,-5,31)]:
		var lamp:=OmniLight3D.new();lamp.name='CrystalBounce';lamp.position=p;lamp.light_color=Color('#8370c9') if p.x>30 else Color('#469adf');lamp.light_energy=5;lamp.omni_range=17;own(lamp)
	var camera:=Camera3D.new();camera.name='BattleCamera';camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=40;camera.position=Vector3(16,38,49);own(camera);camera.look_at(Vector3(16,0,4));camera.far=220;camera.current=true
func arena_floor() -> void:
	cylinder('AncientArenaFoundation',Vector3(16,-1.40,10),20,2.5,stone)
	var floor_mat:=ShaderMaterial.new();floor_mat.shader=load('res://assets/maps3d/materials/arena_carving.gdshader');floor_mat.set_shader_parameter('carving',load('res://assets/maps3d/ornament/arena-carving.png'));floor_mat.set_shader_parameter('border_stone',load('res://assets/maps3d/pbr/rock_boulder_cracked_diff.jpg'))
	var floor_node:=cylinder('CarvedStoneArena',Vector3(16,-.06,10),19.6,.12,floor_mat)
	var body:=StaticBody3D.new();body.name='ArenaCollision';own(body,floor_node);var collision:=CollisionShape3D.new();collision.shape=floor_node.mesh.create_trimesh_shape();own(collision,body)
	# Closely fitted masonry around a perfectly round boundary, with slight wear.
	for i in 96:
		var a: float=i*TAU/96;var p:=Vector3(16+cos(a)*19.25,-.08,10+sin(a)*19.25)
		var n:=block('PerimeterAshlar',p,Vector3(1.18,.24,.80));n.rotation.y=-a+PI*.5
	# Concentric engraved seams are dark grooves under the luminous inlay.
	for radius in [4.8,9.0,13.8,17.6,18.9]:torus('CarvedCircularGroove',Vector3(16,.012,10),radius,.042,dark)
func torus(name_key: String,p: Vector3,radius: float,width: float,material: Material) -> MeshInstance3D:
	var m:=TorusMesh.new();m.inner_radius=radius-width;m.outer_radius=radius+width;m.rings=160;m.ring_segments=6
	return mesh_node(name_key,m,p,material)
func cliffs() -> void:
	for i in 64:
		var a: float=i*TAU/64.0;var r:=20.5+rng.randf_range(-.5,1.3)
		for layer in 3:
			var h:=rng.randf_range(3.2,6.0);var p:=Vector3(16+cos(a)*r,-float(layer)*3.6-1.6,10+sin(a)*r)
			var n:=block('FracturedArenaCliff',p,Vector3(rng.randf_range(2,4),h,rng.randf_range(2,3.8)));n.rotation.y=-a
		if i%3==0:shard(Vector3(16+cos(a)*(r+1.0),-7,10+sin(a)*(r+1.0)),rng.randf_range(3,8),rng.randf_range(.5,1.2),ice,a*.2)
	# Lower canyon shelf and separated foreground spires reveal the vertical drop.
	for i in 30:
		var x:=rng.randf_range(-16,49);var z:=rng.randf_range(29,44)
		var p:=Vector3(x,-11,z)
		block('DeepCanyonShelf',p,Vector3(4.5,rng.randf_range(3,6),4),stone)
		if i%2==0:shard(p+Vector3(0,2,0),rng.randf_range(4,10),rng.randf_range(.8,1.8),ice,rng.randf_range(-.25,.25))
func shard(p: Vector3,h: float,radius: float,material: Material,tilt: float=0.0) -> void:
	var n:=mesh_node('AncientIceColumn',column_mesh,p+Vector3(0,h*.5,0),material,Vector3(radius,h,radius));n.rotation.z=tilt;n.rotation.y=rng.randf_range(0,TAU)
	var cap:=mesh_node('IceColumnTip',tip_mesh,p+Vector3(-sin(tilt)*h*.5,h+radius*.45,0),material,Vector3.ONE*radius);cap.rotation=n.rotation;cap.position=n.position+n.transform.basis.y.normalized()*(h*.5+radius*.45)

func walls() -> void:
	for i in 32:
		var x: float=-17+i*2.1;var z: float=-17+sin(i*.7)*2
		if x>9 and x<23:z-=4.5
		var h:=rng.randf_range(10,17)
		block('CavernBackWall',Vector3(x,h*.40-1,z),Vector3(4,h,5))
		for j in 3:shard(Vector3(x+rng.randf_range(-1,1),rng.randf_range(-1,1),z+1.3+j*.45),h*rng.randf_range(.65,1.12),rng.randf_range(.45,1.2),ice,rng.randf_range(-.12,.12))
	for side in [-1,1]:
		for i in 8:
			var x: float=-10 if side<0 else 43;var z: float=-7+i*4.9
			block('CavernSideWall',Vector3(x+side*2.0,1,z),Vector3(5,rng.randf_range(7,13),6))
			shard(Vector3(x,0,z),rng.randf_range(5,12),rng.randf_range(.9,1.8),ice,side*.15)
			crystal_cluster(Vector3(x-side*.4,0,z+1))
	# Long icicles hang from overhanging upper ledges; no roof hides the arena.
	for i in 46:
		var x:=rng.randf_range(-14,46);var z:=rng.randf_range(-20,-14);var h:=rng.randf_range(1.0,4)
		var m:=CylinderMesh.new();m.top_radius=rng.randf_range(.2,.55);m.bottom_radius=.015;m.height=h;m.radial_segments=7
		mesh_node('HangingStalactite',m,Vector3(x,13-h*.5,z),ice)
	for x in [-4.0,34.0]:
		for i in 9:
			var p:=Vector3(x+(i-4)*.29,-1,-13.1+sin(i)*.25)
			shard(p,7.0+sin(i*.7)*2,.29,ice)
		block('FrozenWaterfallLip',Vector3(x,7.5,-14.0),Vector3(4,.7,1.3),ice)
func crystal_cluster(p: Vector3) -> void:
	for i in 4:shard(p+Vector3((i-1.5)*.37,0,sin(i)*.3),rng.randf_range(1.1,2.7),.18 if i%2==0 else .27,glow,(i-1.5)*.16)
func door() -> void:
	var z: float=-12.6
	var backing:=CylinderMesh.new();backing.top_radius=5.35;backing.bottom_radius=5.35;backing.height=.30;backing.radial_segments=96
	var arch_fill:=mesh_node('FrozenDoorArchPanel',backing,Vector3(16,9.4,z-.42),dark,Vector3(1,.65,1));arch_fill.rotation.x=PI*.5
	# Recessed double leaves, stepped stone jambs and carved concentric archivolts.
	for x in [10.4,21.6]:
		for tier in 3:block('FrozenDoorJamb',Vector3(x+(.22*tier if x<16 else -.22*tier),5.0,z-.3*tier),Vector3(.8,10,1.3),stone)
		block('DoorPedestal',Vector3(x,.2,z+.3),Vector3(2.2,.4,2.0),frost)
		for y in [2.0,6.0,9.5]:block('JambCarving',Vector3(x,y,z+.65),Vector3(1.4,.22,1.5),trim)
	var door_material:=ShaderMaterial.new();door_material.shader=load('res://assets/maps3d/materials/door_carving.gdshader');door_material.set_shader_parameter('carving',load('res://assets/maps3d/ornament/frozen-door.png'))
	var face:=QuadMesh.new();face.size=Vector2(10.0,12.7)
	mesh_node('CarvedFrozenDoubleDoorFace',face,Vector3(16,6.4,z+.5),door_material)
	for tier in 3:
		for i in 25:
			var a: float=i*PI/24;var radius: float=5.5+tier*.42
			var p:=Vector3(16+cos(a)*radius,9.65+sin(a)*radius*.58,z-tier*.32)
			var n:=block('FrozenArchivolt',p,Vector3(.76,.56,1.0),stone if tier!=1 else trim);n.rotation.z=a-PI*.5
	for i in 5:block('DoorStair',Vector3(16,.14-i*.08,z+1.0+i*.50),Vector3(11+i*.3,.22,.65),stone)
	for p in [Vector3(9.3,0,z+2),Vector3(22.7,0,z+2)]:crystal_cluster(p)
func line(a: Vector2,b: Vector2,width: float=.018) -> void:
	var d: Vector2=(b-a).normalized().orthogonal()*width*1.7
	for p in [a-d,a+d,b-d,b-d,a+d,b+d]:
		sigils.set_normal(Vector3.UP);sigils.add_vertex(Vector3(16+p.x,.028,10+p.y))
func circle(center: Vector2,radius: float,width: float=.018,segments: int=160) -> void:
	for i in segments:line(center+Vector2.from_angle(i*TAU/segments)*radius,center+Vector2.from_angle((i+1)*TAU/segments)*radius,width)
func runes() -> void:
	sigils=SurfaceTool.new();sigils.begin(Mesh.PRIMITIVE_TRIANGLES)
	for radius in [1.1,1.25,4.7,4.85,8.7,8.9,13.6,13.8,16.8,17.0,18.0]:circle(Vector2.ZERO,radius,.012 if radius<10 else .018)
	for i in 12:
		var a: float=i*TAU/12;var p:=Vector2.from_angle(a)*11.35
		circle(p,1.45,.018,80);circle(p,1.25,.01,72)
		line(Vector2.from_angle(a)*5.0,Vector2.from_angle(a)*8.5,.014)
		line(Vector2.from_angle(a)*14.05,Vector2.from_angle(a)*16.6,.015)
		for k in 5:
			line(p+Vector2.from_angle(k*TAU/5+a)*1.05,p+Vector2.from_angle((k+2)*TAU/5+a)*1.05,.012)
	# Interlaced celestial geometry with small carved rune strokes, no text decal.
	for i in 8:
		var a: float=i*TAU/8
		line(Vector2.from_angle(a)*8.65,Vector2.from_angle(a+3*TAU/8)*8.65,.010)
	for i in 96:
		var a: float=i*TAU/96;var d:=Vector2.from_angle(a);var tangent:=d.orthogonal();var p:=d*17.5
		line(p-d*.20,p+d*.20,.022)
		line(p+d*.14,p+tangent*.12,.018)
		if i%3==0:line(p-d*.06-tangent*.12,p+d*.05+tangent*.12,.015)
		if i%4==0:circle(d*15.5,.22,.01,20)
	mesh_node('EngravedBioluminescentSigils',sigils.commit(),Vector3.ZERO,rune)
func atmosphere() -> void:
	var mist_material:=ShaderMaterial.new();mist_material.shader=load('res://assets/maps3d/materials/cavern_mist.gdshader')
	for y in [-13.0,-8.0,-4.0]:
		var sheet:=PlaneMesh.new();sheet.size=Vector2(100,90)
		var fog_node:=mesh_node('ChasmMistLayer',sheet,Vector3(16,y,10),mist_material);fog_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 40:
		var a:=rng.randf_range(0,TAU);var r:=rng.randf_range(23,27)
		var p:=Vector3(16+cos(a)*r,rng.randf_range(-3,2),10+sin(a)*r)
		block('IceBearingCanyonSpire',Vector3(p.x,-7,p.z),Vector3(rng.randf_range(1.8,3.2),14+p.y*2,rng.randf_range(1.8,3.2)))
		var n:=block('BrokenBlueIceMass',p,Vector3(rng.randf_range(1.5,3.5),rng.randf_range(2,5),rng.randf_range(2,4)),ice);n.rotation=Vector3(rng.randf_range(-.4,.4),a,rng.randf_range(-.3,.3))
	# Dust motes and fine ice fragments are batched into one draw call.
	var mesh:=SphereMesh.new();mesh.radius=.035;mesh.height=.07;mesh.radial_segments=6;mesh.rings=3
	mesh.material=plain('#9cc9db');var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=160
	for i in 160:multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-9,41),rng.randf_range(-2,9),rng.randf_range(-10,34))))
	var n:=MultiMeshInstance3D.new();n.name='SuspendedIceDust';n.multimesh=multi;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;own(n)
