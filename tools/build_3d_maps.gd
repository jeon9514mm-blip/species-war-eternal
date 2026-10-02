extends SceneTree
## Deterministic authoring tool. Output scenes contain editable real geometry.
## Run: godot --headless --path . --script tools/build_3d_maps.gd
const TERRAIN = preload('res://scripts/FieldTerrainCatalog.gd')
var root_node: Node3D
var rng:=RandomNumberGenerator.new()
var theme:=0
var raid:=false
var mesh_cache: Dictionary={}
var author=preload("res://tools/ForestMeshAuthor.gd").new()
var bark_material: StandardMaterial3D
var leaf_material: ShaderMaterial
var fern_material: ShaderMaterial
var rock_mat: Material
var stone_mat: StandardMaterial3D
var gold_mat: StandardMaterial3D
var glow_mat: StandardMaterial3D
func _init() -> void: build.call_deferred()
func build() -> void:
	for t in 3:
		for boss in [false,true]:
			theme=t;raid=boss;rng.seed=83630+t*11+int(boss)
			root_node=Node3D.new();root_node.set_script(load('res://scripts/maps3d/CavernRuntime.gd'));root_node.name=['Evergreen','Crimson','Arcane'][t]+('Raid' if raid else 'Field')
			root.add_child(root_node)
			materials();ground();lighting();detailed_scenery();detailed_landmark();grass();reference_details()
			var packed:=PackedScene.new();var result:=packed.pack(root_node)
			assert(result==OK)
			var path: String='res://scenes/maps3d/'+root_node.name+'.tscn'
			assert(ResourceSaver.save(packed,path)==OK)
			print('Built ',path,' nodes=',root_node.get_child_count())
			root_node.free()
	quit()
func own(node: Node, parent: Node=null) -> void:
	(parent if parent!=null else root_node).add_child(node);node.owner=root_node
func mat(color: String, rough: float=.88) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=rough;return m
func materials() -> void:
	var shader_mat:=ShaderMaterial.new();shader_mat.shader=load('res://assets/maps3d/materials/detail_rock.gdshader')
	shader_mat.set_shader_parameter('rock_texture',load('res://assets/maps3d/pbr/'+('rock_face_03' if theme==1 else 'mossy_rock')+'_diff.jpg'))
	shader_mat.set_shader_parameter('tint',Color(['#d9d4b9','#bd8565','#a5bbc2'][theme]));rock_mat=shader_mat
	bark_material=StandardMaterial3D.new();bark_material.albedo_texture=load('res://assets/maps3d/pbr/bark_brown_01_diff.jpg');bark_material.normal_enabled=true;bark_material.normal_texture=load('res://assets/maps3d/pbr/bark_brown_01_nor_gl.jpg');bark_material.roughness=.9;bark_material.albedo_color=Color('#a9a18b')
	leaf_material=ShaderMaterial.new();leaf_material.shader=load('res://assets/maps3d/materials/foliage.gdshader');leaf_material.set_shader_parameter('foliage_tint',Color('#75bbc5') if theme==2 else Color.WHITE)
	fern_material=leaf_material
	stone_mat=mat(['#9c9b85','#b58c62','#7b91a0'][theme])
	gold_mat=mat('#b99456',.45);gold_mat.metallic=.5
	glow_mat=mat(['#e7ce83','#ff8b43','#67e4e4'][theme],.22)
	glow_mat.emission_enabled=true;glow_mat.emission=glow_mat.albedo_color;glow_mat.emission_energy_multiplier=.55
func height_at(x: float,z: float) -> float:
	# Flat playable floor; raised border slopes cannot interfere with gameplay.
	var edge:=maxf(maxf(-x,x-32.0),maxf(-z,z-20.0))
	if theme==1:return -smoothstep(0,5,edge)*12.0
	return smoothstep(0,7,edge)*(1.4+sin(x*.31)*.8+cos(z*.38)*.65)
func ground() -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-14,35):
		for x in range(-18,50):
			for p: Vector2 in [Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]:
				st.set_uv(p*.1);st.add_vertex(Vector3(p.x,height_at(p.x,p.y),p.y))
	st.generate_normals();st.generate_tangents()
	var mesh:=st.commit();var material:=ShaderMaterial.new();material.shader=load('res://assets/maps3d/materials/terrain.gdshader')
	material.set_shader_parameter('theme',theme)
	material.set_shader_parameter('meadow_texture',load('res://assets/maps3d/pbr/aerial_grass_rock_diff.jpg'))
	var ground_name: String=['forest_ground_04','sandstone_cracks','cobblestone_floor_01'][theme]
	material.set_shader_parameter('dirt_texture',load('res://assets/maps3d/pbr/'+ground_name+'_diff.jpg'))
	material.set_shader_parameter('dirt_normal',load('res://assets/maps3d/pbr/'+ground_name+'_nor_gl.jpg'))
	if theme==2:
		material.shader=load('res://assets/maps3d/materials/arena_carving.gdshader');material.set_shader_parameter('carving',load('res://assets/maps3d/ornament/arena-carving.png'));material.set_shader_parameter('border_stone',load('res://assets/maps3d/pbr/rock_boulder_cracked_diff.jpg'))
	var node:=MeshInstance3D.new();node.name='SculptedTerrain';node.mesh=mesh;node.material_override=material;own(node)
	var body:=StaticBody3D.new();body.name='GroundCollision';own(body,node)
	var collision:=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();own(collision,body)
func lighting() -> void:
	var env:=WorldEnvironment.new();env.name='Atmosphere';env.environment=Environment.new()
	var e:=env.environment;e.background_mode=Environment.BG_COLOR;e.background_color=Color(['#a1b3a1','#bba086','#728c9b'][theme])
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(['#c4d5cd','#d7b6a0','#a6c9e2'][theme]);e.ambient_light_energy=.22 if theme==2 else .32
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	e.fog_enabled=true;e.fog_light_color=e.background_color;e.fog_density=.0025
	own(env)
	var sun:=DirectionalLight3D.new();sun.name='Sunlight';sun.rotation_degrees=Vector3(-53,-32,0)
	sun.light_color=Color(['#fff0cf','#ffddb0','#cce9ff'][theme]);sun.light_energy=.85 if theme==2 else 1.10;sun.shadow_enabled=true
	sun.directional_shadow_max_distance=95;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias=.025;sun.shadow_normal_bias=.35;own(sun)
	var cam:=Camera3D.new();cam.name='BattleCamera';cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=30
	cam.position=Vector3(16,29,38);own(cam);cam.look_at(Vector3(16,0,8) if not raid else Vector3(16,0,10));cam.current=true;cam.far=180
func primitive(name_key: String, mesh: Mesh, pos: Vector3, material: Material, dimensions:=Vector3.ONE) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=name_key;node.mesh=mesh;node.material_override=material;node.position=pos;node.scale=dimensions;own(node);return node
func box(name_key: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var m:=BoxMesh.new();m.size=size;return primitive(name_key,m,pos,material)
func cylinder(name_key: String,pos: Vector3,radius: float,h: float,material: Material,top: float=-1) -> MeshInstance3D:
	var m:=CylinderMesh.new();m.bottom_radius=radius;m.top_radius=radius if top<0 else top;m.height=h;m.radial_segments=12
	return primitive(name_key,m,pos,material)
func crystal(p: Vector3,s: float) -> void:
	for i in 3:
		var crystal_mesh:=CylinderMesh.new();crystal_mesh.top_radius=0;crystal_mesh.bottom_radius=.22*s;crystal_mesh.height=(1.0+i*.34)*s;crystal_mesh.radial_segments=5
		var node:=primitive('LuminousCrystal',crystal_mesh,p+Vector3((i-1)*.3*s,crystal_mesh.height*.5,0),glow_mat);node.rotation.z=(i-1)*.18
func ring(pos: Vector3,radius: float,width: float,material: Material) -> void:
	var mesh:=TorusMesh.new();mesh.inner_radius=radius-width;mesh.outer_radius=radius+width;mesh.rings=64;mesh.ring_segments=6
	primitive('RunicInlay',mesh,pos,material)
func pillar(p: Vector3,h: float) -> void:
	box('PillarPlinth',p+Vector3(0,.2,0),Vector3(1.5,.4,1.5),rock_mat)
	cylinder('CarvedPillar',p+Vector3(0,h*.5+.4,0),.46,h,stone_mat)
	box('PillarCapital',p+Vector3(0,h+.5,0),Vector3(1.2,.3,1.2),stone_mat)
	box('GoldBand',p+Vector3(0,h*.75,0),Vector3(.98,.12,.98),gold_mat)
func grass() -> void:
	# A single MultiMesh per zone keeps the ground cover inexpensive on mobile.
	var blades:=SurfaceTool.new();blades.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0,1.1,2.2]:
		var dir:=Vector3(cos(angle)*.13,0,sin(angle)*.13)
		for point in [-dir,dir,Vector3(.035,.34,0)]:blades.add_vertex(point)
	blades.generate_normals();var mesh:=blades.commit()
	var grass_mat:=mat(['#728b4d','#947648','#447678'][theme]);grass_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,grass_mat)
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=900
	var index:=0
	for i in 2000:
		if index>=900:break
		var x:=rng.randf_range(-4,36);var z:=rng.randf_range(-4,25)
		if raid and Vector2(x-16,z-10).length()<11:continue
		if Vector2((x-16)*.7,z-10).length()<6:continue
		if absf(z-(14.8-x*.17))<1.6:continue
		var s:=rng.randf_range(.65,1.9)
		multi.set_instance_transform(index,Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*s),Vector3(x,height_at(x,z),z)));index+=1
	multi.visible_instance_count=index
	var node:=MultiMeshInstance3D.new();node.name='GroundCover';node.multimesh=multi;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;own(node)

func cached_mesh(key: String) -> ArrayMesh:
	if mesh_cache.has(key):return mesh_cache[key]
	var mesh: ArrayMesh
	if key.begins_with('rock'):mesh=author.rock(8363+int(key.right(1)))
	elif key=='fern':mesh=author.fern()
	else:
		var number:=int(key.right(1));var pair: Array=author.tree(363+number)
		mesh_cache['bark'+str(number)]=pair[0];mesh_cache['leaves'+str(number)]=pair[1]
		for n in ['bark','leaves']:
			ResourceSaver.save(mesh_cache[n+str(number)],'res://assets/maps3d/baked/'+n+str(number)+'.res',ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
		return mesh_cache[key]
	mesh_cache[key]=mesh
	ResourceSaver.save(mesh,'res://assets/maps3d/baked/'+key+'.res',ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
	return mesh
func detailed_rock(pos: Vector3,dimensions: Vector3) -> void:
	var node:=primitive('ErodedMossRock',cached_mesh('rock'+str(rng.randi_range(0,3))),pos,rock_mat,dimensions)
	node.rotation.y=rng.randf_range(-.7,.7);node.rotation.z=rng.randf_range(-.12,.12)
func detailed_tree(pos: Vector3,scale_value: float,index: int) -> void:
	var key:=str(index%3);var angle:=rng.randf_range(0,TAU)
	for part in ['bark','leaves']:
		var node:=primitive('AncientOak_'+part,cached_mesh(part+key),pos,bark_material if part=='bark' else leaf_material,Vector3.ONE*scale_value)
		node.rotation.y=angle
func detailed_scenery() -> void:
	# A continuous perimeter creates the open central clearing shown in the concept.
	# All tall pieces lie beyond the 32 x 20 gameplay area.
	for i in 30:
		var x: float=-5+i*1.45;var z: float=-2.5+sin(i*.57)*1.6
		var h:=rng.randf_range(2.0,4.3) if theme!=1 else rng.randf_range(3.3,7.0)
		for layer in 3:
			detailed_rock(Vector3(x,float(layer)*h*.32-.3,z-float(layer)*.6),Vector3(rng.randf_range(2.0,3.5),h*.52,2.4))
	for side in [-1,1]:
		for i in 13:
			var x: float=-2.0 if side<0 else 34.1;var z: float=i*1.9-1
			# Right-center gap is the visible monster entry corridor.
			if side>0 and z>6 and z<13:continue
			if side<0 and z<8:continue
			var h:=rng.randf_range(1.5,3.7)
			detailed_rock(Vector3(x+sin(i)*.6,h*.22-.2,z),Vector3(3,h,2.7))
	for i in 19:
		var x: float=-3+i*2.2;var z:=22.8+sin(i*.55)*1.7
		if i%4==0:continue
		detailed_rock(Vector3(x,.25,z),Vector3(2.7,rng.randf_range(1.1,2.4),2.5))
	if theme!=1:
		for i in 8:
			var x: float=-7+i*6.8;var z: float=-5.5-float(i%3)*1.8
			detailed_tree(Vector3(x,1.0,z),rng.randf_range(1.0,1.35),i)
		for side in [-1,1]:
			for i in 3:
				var x: float=-7.8 if side<0 else 39.0
				detailed_tree(Vector3(x,.5,i*10.0+1),rng.randf_range(.65,.98),i)
		# Deliberately low foreground canopies frame the field without hiding units.
		for x in [-4.0,37.0]:detailed_tree(Vector3(x,-2.4,27),1.0,int(x+4))
		stream()
	else:
		for i in 22:
			var p:=Vector3(rng.randf_range(-5,38),rng.randf_range(-.2,.5),-3-rng.randf()*4)
			crystal(p,rng.randf_range(.4,1.0))
	# Rubble, grasses and ferns use shared meshes but retain editable placement.
	for i in 145:
		var p:=Vector3(rng.randf_range(-3,35),0,rng.randf_range(-3,24))
		if p.x>2.0 and p.x<30 and p.z>1.0 and p.z<19:continue
		detailed_rock(p+Vector3(0,.06,0),Vector3.ONE*rng.randf_range(.16,.65))
		if theme!=1:
			var fern:=primitive('WoodlandFern',cached_mesh('fern'),p,fern_material,Vector3.ONE*rng.randf_range(.65,1.4));fern.rotation.y=rng.randf_range(0,TAU)
	if raid and theme!=2:
		# Separate weathered paving stones rather than a smooth flat disk.
		for z in range(1,20):
			for x in range(1,32):
				if Vector2((x-16)*.7,z-10).length()>10:continue
				var tile:=primitive('WeatheredPaving',cached_mesh('rock'+str((x+z)%4)),Vector3(x,.006,z),rock_mat,Vector3(.96,.06,.96));tile.rotation.y=rng.randf_range(-.025,.025)
		ring(Vector3(16,.075,10),7.2,.022,gold_mat);ring(Vector3(16,.076,10),6.9,.015,gold_mat)
func stone_block(pos: Vector3,dimensions: Vector3,angle: float=0.0) -> void:
	var block:=primitive('RuinedMasonry',cached_mesh('rock'+str(rng.randi_range(0,3))),pos,rock_mat,dimensions);block.rotation.y=angle
func detailed_landmark() -> void:
	if theme==0:
		# Broken watchtower on the northwest stream bank.
		for row in 7:
			for i in 17:
				var a: float=(i+float(row%2)*.5)*TAU/20.0
				if row>4 and (i<3 or i>11):continue
				if row>2 and i>6 and i<9:continue
				stone_block(Vector3(3+cos(a)*2.4,row*.64+.25,-4+sin(a)*2.4),Vector3(.77,.61,.7),-a+PI*.5)
		for i in 8:stone_block(Vector3(8+i*.9,.3+float(i%3)*.5,-1.9),Vector3(.85,.9,.9))
		for i in 4:stone_block(Vector3(25+i*.85,1.0+float(i%2)*.4,-1.9),Vector3(.8,2,.9))
	elif theme==1:
		var timber:=bark_material
		for x in [2.0,8.0]:box('MineTimber',Vector3(x,2.3,-2.6),Vector3(.75,4.6,.8),timber)
		box('MineLintel',Vector3(5,4.75,-2.6),Vector3(7.4,.8,1.0),timber)
		box('MineDarkInterior',Vector3(5,2.0,-4.3),Vector3(5.4,4,.3),mat('#121819'))
		for z in 14:box('RailSleeper',Vector3(5,.06,-8+z*.65),Vector3(2.7,.12,.20),timber)
		for x in [4.1,5.9]:box('SteelRail',Vector3(x,.17,-3.8),Vector3(.12,.14,8.4),gold_mat)
		for i in 10:stone_block(Vector3(16+i*1.6,2.6,-5),Vector3(1.5,.35,1.6))
	else:
		for x in [3.0,9.0,24.0,30.0]:
			pillar(Vector3(x,0,-2.4),4.8)
			for i in 12:
				var a: float=i*TAU/12
				cylinder('ColumnFlute',Vector3(x+cos(a)*.47,2.7,-2.4+sin(a)*.47),.045,4.4,stone_mat)
		for center in [6.0,27.0]:
			for i in 12:
				var a: float=i*PI/11.0
				var block:=primitive('PortalArch',cached_mesh('rock'+str(i%4)),Vector3(center+cos(a)*2.8,4.0+sin(a)*2.1,-2.4),rock_mat,Vector3(.8,.75,1.0));block.rotation.z=a-PI*.5
			crystal(Vector3(center,0,-2.5),2.2)
		for i in 6:pillar(Vector3(-2,0,2+i*3.2),rng.randf_range(1.3,3.8))
	for x in [1.0,9.0]:
		var light:=OmniLight3D.new();light.name='WarmRuinsLight';light.position=Vector3(x,2,-1);light.light_color=Color('#ffd49c');light.light_energy=.7;light.omni_range=4;own(light)
func stream() -> void:
	var water:=ShaderMaterial.new();water.shader=load('res://assets/maps3d/materials/water.gdshader');water.set_shader_parameter('water_color',Color('#23646d'))
	var channel:=PlaneMesh.new();channel.size=Vector2(3.0,23)
	primitive('WesternStream',channel,Vector3(-2.4,.08,5),water)
	# Water drops between two real terrain ledges at the northwest corner.
	var fall:=PlaneMesh.new();fall.size=Vector2(2.1,2.6)
	var node:=primitive('Waterfall',fall,Vector3(-2.4,1.3,-2.2),water);node.rotation.x=PI*.5
	for i in 12:
		var ripple:=TorusMesh.new();ripple.inner_radius=.15+i*.035;ripple.outer_radius=ripple.inner_radius+.024;ripple.rings=24;ripple.ring_segments=4
		primitive('WaterfallFoam',ripple,Vector3(-2.4+sin(i)*.4,.085,-1+cos(i)*.5),mat('#a4ccc6'))

func reference_details() -> void:
	# Additional direction from the user's Meta reference documents.
	if theme==1:
		for i in 14:detailed_rock(Vector3(-6+i*3.2,1.5,-10.5+sin(i)*1.7),Vector3(4,rng.randf_range(8,13),4.5))
		for p in [Vector3(1.8,2,-2),Vector3(8.2,2,-2),Vector3(30,2,1)]:
			var casing:=StandardMaterial3D.new();casing.albedo_color=Color('#231c16');casing.metallic=.55
			box('LanternFrame',p,Vector3(.32,.55,.32),casing)
			box('AmberLanternGlass',p+Vector3(0,0,.19),Vector3(.22,.35,.05),glow_mat)
			var light:=OmniLight3D.new();light.name='WarmMiningLantern';light.position=p+Vector3(0,0,.5);light.light_color=Color('#ff9a47');light.light_energy=2.2;light.omni_range=6;own(light)
		for i in 14:
			var x: float=-3+i*3.0
			detailed_rock(Vector3(x,-4,23.8+sin(i)*1.3),Vector3(2.8,rng.randf_range(6,11),3.2))
		for i in 8:
			box('MineScaffoldPost',Vector3(20+i*1.5,1.6,-4.1),Vector3(.16,3.2,.16),bark_material)
		box('ScaffoldRail',Vector3(25.2,2.8,-4.1),Vector3(11,.12,.12),bark_material)
	else:
		var flower:=SphereMesh.new();flower.radius=.055;flower.height=.07;flower.radial_segments=6;flower.rings=3
		var flower_mat:=StandardMaterial3D.new();flower_mat.vertex_color_use_as_albedo=true;flower_mat.albedo_color=Color.WHITE;flower.material=flower_mat
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=flower;multi.instance_count=600
		for i in 600:
			var side: int=i%4
			var p:=Vector3(rng.randf_range(0,32),.18,rng.randf_range(0,20))
			if side==0:p.z=rng.randf_range(-.4,1.2)
			elif side==1:p.z=rng.randf_range(18.5,21)
			elif side==2:p.x=rng.randf_range(-.4,1.2)
			else:p.x=rng.randf_range(30.8,32.6)
			if theme==2:p.y=rng.randf_range(.5,4.5);p.z=-2.5+sin(i*.4)*.6
			multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,p))
			multi.set_instance_color(i,Color('#b7a5e9') if theme==2 else (Color('#edf0d0') if i%3 else Color('#829cd9')))
		var node:=MultiMeshInstance3D.new();node.name='HangingWisteria' if theme==2 else 'WhiteAndBlueWildflowers';node.multimesh=multi;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;own(node)
