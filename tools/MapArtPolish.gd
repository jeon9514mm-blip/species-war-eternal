extends RefCounted
## Deterministic, editable scenery pass. No changes to gameplay floor or collision.
var scene: Node3D
var decor: Node3D
var rng:=RandomNumberGenerator.new()
var theme: String
func apply(target: Node3D, biome: String) -> void:
	scene=target;theme=biome;rng.seed=8365+['ice','canyon','forest','sanctuary'].find(theme)
	var previous:=scene.get_node_or_null('ArtPolish')
	if previous!=null:previous.free()
	decor=Node3D.new();decor.name='ArtPolish';scene.add_child(decor);decor.owner=scene
	materials();lighting()
	if theme=='ice':ice_details()
	motes()
	if theme!='ice':preload('res://tools/ReferenceMapArt.gd').new().apply(scene,decor,theme)
	if str(scene.name).ends_with('Raid'):preload('res://tools/RaidArenaArt.gd').new().apply(scene,theme)
func own(node: Node) -> void:
	decor.add_child(node);node.owner=scene
func material(color: String,glow:=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=.82
	if glow>0:m.emission_enabled=true;m.emission=m.albedo_color;m.emission_energy_multiplier=glow
	return m
func batch(label: String,mesh: Mesh,mat: Material,placements: Array[Transform3D],shadows:=true) -> void:
	if placements.is_empty():return
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=placements.size()
	for i in placements.size():multi.set_instance_transform(i,placements[i])
	var n:=MultiMeshInstance3D.new();n.name=label;n.multimesh=multi;n.material_override=mat
	if not shadows:n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	own(n)
func placement(p: Vector3,s: Vector3,angle:=0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,angle).scaled(s),p)
func materials() -> void:
	var seen: Dictionary={}
	for n in scene.get_children():
		if not n is MeshInstance3D or not n.material_override is ShaderMaterial:continue
		var m: ShaderMaterial=n.material_override
		if seen.has(m.get_instance_id()):continue
		seen[m.get_instance_id()]=true
		var path:=m.shader.resource_path
		if path.ends_with('detail_rock.gdshader'):
			m.set_shader_parameter('frost_amount',.78 if theme=='ice' else 0.)
			m.set_shader_parameter('moss_amount',.80 if theme in ['forest','sanctuary'] else 0.)
			m.set_shader_parameter('strata_amount',.88 if theme=='canyon' else 0.)
			if theme=='canyon':m.set_shader_parameter('tint',Color('#c88f76'));m.set_shader_parameter('texture_scale',.40)
		if path.ends_with('/ice.gdshader'):
			m.set_shader_parameter('ice_roughness',load('res://assets/maps3d/pbr/ice2k/Ice003_2K-JPG_Roughness.jpg'))
		if path.ends_with('foliage.gdshader'):
			m.set_shader_parameter('foliage_tint',Color('#b2c895') if theme=='sanctuary' else Color('#baca98'))
func lighting() -> void:
	var env: WorldEnvironment=scene.get_node('CavernAtmosphere' if theme=='ice' else 'Atmosphere')
	var e:=env.environment
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;e.tonemap_exposure=1.08
	e.ssao_enabled=true;e.ssao_radius=1.1;e.ssao_intensity=1.65;e.ssao_power=1.2
	e.glow_enabled=true;e.glow_intensity=.48;e.glow_bloom=0.;e.glow_hdr_threshold=1.45
	e.volumetric_fog_enabled=true;e.volumetric_fog_density=.0025;e.volumetric_fog_length=110
	e.volumetric_fog_albedo=Color('#7d9fb0') if theme=='ice' else Color('#b6be9d')
	var sun: DirectionalLight3D=scene.get_node('MoonlightThroughIce' if theme=='ice' else 'Sunlight')
	sun.light_angular_distance=1.1
	if theme=='ice':
		e.background_color=Color('#09182e');e.ambient_light_energy=.25
		e.fog_light_color=Color('#102c48');e.fog_density=.003
		sun.light_energy=1.85
	elif theme=='canyon':
		e.background_color=Color('#72505a');e.fog_light_color=Color('#a97561');e.fog_density=.003
		e.ambient_light_color=Color('#859fc0');e.ambient_light_energy=.42
		sun.light_color=Color('#ffd0a0');sun.light_energy=1.65;sun.rotation_degrees=Vector3(-36,-48,0)
	else:
		e.background_color=Color('#243c43');e.fog_light_color=Color('#587b72');e.fog_density=.004
		e.ambient_light_color=Color('#8dbdb2');e.ambient_light_energy=.40
		sun.light_color=Color('#fff0c9');sun.light_energy=1.65;sun.rotation_degrees=Vector3(-48,-38,0)
		var fill:=DirectionalLight3D.new();fill.name='CanopyBounce';fill.rotation_degrees=Vector3(-30,125,0);fill.light_color=Color('#7daea9');fill.light_energy=.24;own(fill)
func ice_details() -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=.015;mesh.bottom_radius=.38;mesh.height=1;mesh.radial_segments=6
	var m:=ShaderMaterial.new();m.shader=load('res://assets/maps3d/materials/ice.gdshader')
	for pair in [['ice_color','Color'],['ice_normal','NormalGL'],['ice_roughness','Roughness']]:
		m.set_shader_parameter(pair[0],load('res://assets/maps3d/pbr/ice2k/Ice003_2K-JPG_'+pair[1]+'.jpg'))
	var crystals: Array[Transform3D]=[]
	var snow: Array[Transform3D]=[]
	for i in 72:
		var a:=TAU*i/72.;var r:=rng.randf_range(20.0,21.6)
		var p:=Vector3(16+cos(a)*r,-.35,10+sin(a)*r)
		# The eastern spawn corridor stays clear, including its decorative silhouette.
		if p.x>30 and p.z>5 and p.z<14:continue
		var h:=rng.randf_range(.45,1.55)
		crystals.append(placement(p+Vector3(0,h*.5,0),Vector3(.55,h,.55),a))
		snow.append(placement(p-Vector3(0,.2,0),Vector3(rng.randf_range(.6,1.25),.12,.65),a))
	batch('RimIceSplinters',mesh,m,crystals)
	batch('WindPackedFrost',load('res://assets/maps3d/baked/rock0.res'),material('#819ba9'),snow)
	# A blue pool of light marks the gate without illuminating the entire floor.
	var gate:=OmniLight3D.new();gate.name='GateRunicBounce';gate.position=Vector3(16,5,-10);gate.light_color=Color('#50c7f0');gate.light_energy=3.5;gate.omni_range=8;own(gate)
func canyon_details() -> void:
	var ledges: Array[Transform3D]=[]
	var stone:=ShaderMaterial.new();stone.shader=load('res://assets/maps3d/materials/detail_rock.gdshader')
	stone.set_shader_parameter('rock_texture',load('res://assets/maps3d/pbr/rock_face_03_diff.jpg'));stone.set_shader_parameter('tint',Color('#ad7761'));stone.set_shader_parameter('strata_amount',1.)
	for i in 24:
		var x: float=-8+i*2.1
		for layer in 3:
			ledges.append(placement(Vector3(x,1.6+layer*1.65,-6.8-layer*.45),Vector3(2.2,.25,.9),rng.randf_range(-.09,.09)))
	batch('SedimentaryLedges',load('res://assets/maps3d/baked/rock1.res'),stone,ledges)
	var pebbles: Array[Transform3D]=[]
	for i in 160:
		var p:=Vector3(rng.randf_range(-1,33),.025,rng.randf_range(-1.4,21.4))
		if p.x>1 and p.x<31 and p.z>0 and p.z<20:continue
		if p.x>30 and p.z>5 and p.z<14:continue
		pebbles.append(placement(p,Vector3.ONE*rng.randf_range(.08,.20),rng.randf_range(0,TAU)))
	batch('SandstoneScree',load('res://assets/maps3d/baked/rock2.res'),stone,pebbles,false)
func forest_details() -> void:
	var roots: Array[Transform3D]=[]
	var moss: Array[Transform3D]=[]
	for side in [-1,1]:
		for i in 20:
			var x: float=-1.8 if side<0 else 34.2;var z: float=-3+i*1.4
			if side>0 and z>5 and z<14:continue
			var p:=Vector3(x,.16,z)
			moss.append(placement(p,Vector3(1.3,.20,.8),rng.randf_range(0,TAU)))
			var b:=Basis(Vector3.FORWARD,1.3).rotated(Vector3.UP,.5+sin(i))
			roots.append(Transform3D(b.scaled(Vector3(.17,2.8,.17)),p+Vector3(0,.1,0)))
	var root_mesh:=CylinderMesh.new();root_mesh.top_radius=.25;root_mesh.bottom_radius=.65;root_mesh.height=1;root_mesh.radial_segments=8
	batch('ExposedAncientRoots',root_mesh,material('#514b30'),roots)
	batch('MossBanks',load('res://assets/maps3d/baked/rock2.res'),material('#435b32'),moss)
	# Cyan firelight distinguishes the sanctuary from the warmer woodland.
	if theme=='sanctuary':
		for x in [6.,27.]:
			var light:=OmniLight3D.new();light.name='SanctuaryRuneBounce';light.position=Vector3(x,2,-1.5);light.light_color=Color('#60d9dd');light.light_energy=2.;light.omni_range=6.;own(light)
func motes() -> void:
	var mesh:=SphereMesh.new();mesh.radius=.027 if theme=='ice' else .035;mesh.height=mesh.radius*2;mesh.radial_segments=6;mesh.rings=3
	var m:=ShaderMaterial.new();m.shader=load('res://assets/maps3d/materials/ambient_motes.gdshader')
	m.set_shader_parameter('tint',Color({'ice':'#94d6ef','canyon':'#dca779','forest':'#c3dca2','sanctuary':'#5fdce0'}[theme]))
	m.set_shader_parameter('drift',.14 if theme=='ice' else .07)
	var positions: Array[Transform3D]=[]
	for i in 96:
		var a:=rng.randf_range(0,TAU);var r:=rng.randf_range(1.,1.18)
		positions.append(placement(Vector3(16+cos(a)*22*r,rng.randf_range(.5,5),10+sin(a)*16*r),Vector3.ONE))
	batch('PeripheralMotes',mesh,m,positions,false)
