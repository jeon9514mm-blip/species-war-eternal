extends RefCounted
## Raid-only authored scenery. Central floor/collision and simulation are preserved.
var scene: Node3D
var decor: Node3D
var theme: String
var rng:=RandomNumberGenerator.new()
var ref=preload('res://tools/ReferenceMapArt.gd').new()
var author=preload('res://tools/ForestMeshAuthor.gd').new()
var stone: Material
var moss: Material
var wood: Material
var leaf: Material
var crystal: Material
var steel: Material
func apply(target: Node3D,biome: String) -> void:
	scene=target;theme=biome;rng.seed=8410+['forest','canyon','sanctuary','ice'].find(theme)
	var old:=scene.get_node_or_null('RaidDesign')
	if old!=null:old.free()
	decor=Node3D.new();decor.set_script(load('res://scripts/maps3d/RaidArenaMood.gd'));decor.name='RaidDesign';scene.add_child(decor);decor.owner=scene
	decor.set_meta('theme',theme);decor.set_meta('art_version',1)
	ref.scene=scene;ref.group=decor;ref.biome=theme;ref.rng=rng;ref.materials()
	ref.roots=SurfaceTool.new();ref.roots.begin(Mesh.PRIMITIVE_TRIANGLES)
	stone=ref.stone;moss=ref.moss;wood=ref.bark;leaf=ref.leaf;steel=ref.metal
	if theme=='canyon':stone.set_shader_parameter('strata_amount',.80)
	if theme=='ice':
		stone.set_shader_parameter('frost_amount',.75);stone.set_shader_parameter('tint',Color('#b5ccdb'))
	crystal=ShaderMaterial.new();crystal.shader=load('res://assets/maps3d/materials/raid_crystal.gdshader')
	crystal.set_shader_parameter('tint',Color('#ffba5e' if theme=='canyon' else '#83b8f2' if theme=='sanctuary' else '#7db89c' if theme=='forest' else '#60cfee'))
	floor_material();lighting()
	if theme=='canyon':canyon()
	elif theme=='sanctuary':sanctuary()
	elif theme=='forest':forest()
	else:ice()
	border_rubble();ref.flush()
func own(node: Node) -> void:decor.add_child(node);node.owner=scene
func floor_material() -> void:
	var floor_node: MeshInstance3D=scene.get_node('CarvedStoneArena' if theme=='ice' else 'SculptedTerrain')
	var m:=ShaderMaterial.new();m.shader=load('res://assets/maps3d/materials/raid_ground.gdshader')
	m.set_shader_parameter('theme',['forest','canyon','sanctuary','ice'].find(theme))
	var texture: String='sandstone_cracks' if theme=='canyon' else 'aerial_grass_rock' if theme=='forest' else 'cobblestone_floor_01'
	m.set_shader_parameter('detail_color',load('res://assets/maps3d/pbr/'+texture+'_diff.jpg'))
	# The normal map is already packaged and does not affect geometry or collisions.
	m.set_shader_parameter('detail_normal',load('res://assets/maps3d/pbr/'+('forest_ground_04' if theme=='forest' else 'sandstone_cracks' if theme=='canyon' else 'cobblestone_floor_01')+'_nor_gl.jpg'))
	m.set_shader_parameter('carving',load('res://assets/maps3d/ornament/arena-carving.png'))
	floor_node.material_override=m
func lighting() -> void:
	var e: Environment=scene.get_node('CavernAtmosphere' if theme=='ice' else 'Atmosphere').environment
	e.background_mode=Environment.BG_COLOR;e.tonemap_exposure=.98;e.glow_intensity=.30
	e.fog_density=.0012;e.fog_sky_affect=0.;e.volumetric_fog_density=.0006
	e.ssao_radius=.8;e.ssao_intensity=1.35
	var sun: DirectionalLight3D=scene.get_node('MoonlightThroughIce' if theme=='ice' else 'Sunlight')
	sun.light_angular_distance=1.5
	if theme=='canyon':
		e.background_color=Color('#383a48');e.fog_light_color=Color('#667380');e.ambient_light_color=Color('#95a7bf');e.ambient_light_energy=.42
		sun.light_color=Color('#ffd6a9');sun.light_energy=1.20;sun.rotation_degrees=Vector3(-48,-36,0)
	elif theme=='sanctuary':
		e.background_color=Color('#101b2b');e.fog_light_color=Color('#253957');e.ambient_light_color=Color('#8a9abb');e.ambient_light_energy=.32
		sun.light_color=Color('#b8d3ef');sun.light_energy=1.08;sun.rotation_degrees=Vector3(-54,-30,0)
	elif theme=='forest':
		e.background_color=Color('#142b20');e.fog_light_color=Color('#526c51');e.ambient_light_color=Color('#9db8a3');e.ambient_light_energy=.37
		sun.light_color=Color('#ffe8b3');sun.light_energy=1.24;sun.rotation_degrees=Vector3(-54,-40,0)
	else:
		e.ambient_light_energy=.30;sun.light_energy=1.40
func center(a: float,rx: float,rz: float,y:=0.) -> Vector3:return Vector3(16+cos(a)*rx,y,10+sin(a)*rz)
func put(key: String,shape: String,mat: Material,p: Vector3,size: Vector3,angle:=0.) -> void:ref.put(key,ref.mesh(shape),mat,p,size,angle)
func ring_blocks(label: String,rx: float,rz: float,material: Material,height: float,count: int) -> void:
	for i in count:
		var a:=i*TAU/count;var p:=center(a,rx,rz,height*.5)
		put(label,'rock'+str(i%3),material,p,Vector3(1.10,height,.78),-a+PI*.5)
func pedestal(p: Vector3,color: Material,height:=1.1) -> void:
	for i in 3:put('SculptedPedestal','rock0',stone,p+Vector3(0,.10+i*.18,0),Vector3(1.25-i*.18,.20,1.25-i*.18))
	for i in 5:
		var a:=i*2.4;var h: float=height if i==0 else height*.45
		put('FacetedRaidCrystals','gem',color,p+Vector3(cos(a)*.22,.6+h*.5,sin(a)*.22),Vector3(.65,h,.65),a)
func rune_light(p: Vector3,color: Color,energy:=1.0) -> void:
	var light:=OmniLight3D.new();light.name='LocalizedRuneLight';light.position=p+Vector3(0,1.2,0)
	light.light_color=color;light.light_energy=energy;light.omni_range=4.;own(light)
func sanctuary() -> void:
	# A closer ring reads in the actual raid camera; tall arches occupy the back rim.
	var original:=scene.get_node_or_null('ArtPolish/ReferenceScenery')
	if original!=null:original.visible=false
	ring_blocks('MoonCourtyardRim',16.6,10.7,moss,.40,90)
	for i in 18:
		var a:=TAU*i/18.;var p:=center(a,16.6,10.7)
		var front: bool=sin(a)>.20
		var h:=.8 if front else 4.7
		put('LunarColumnBases','rock0',stone,p+Vector3(0,.18,0),Vector3(1.4,.36,1.4),-a)
		put('LunarColumnShafts','column',stone,p+Vector3(0,h*.5+.32,0),Vector3(.88,h,.88))
		put('LunarColumnCapitals','rock1',stone,p+Vector3(0,h+.45,0),Vector3(1.30,.30,1.30),-a)
		for flute in 10:
			var f:=flute*TAU/10.
			put('CarvedColumnFlutes','cord',stone,p+Vector3(cos(f)*.43,h*.5+.32,sin(f)*.43),Vector3(.065,h-.1,.065))
		ref.root_path([p+Vector3(.32,h*.8,.0),p+Vector3(-.45,h*.48,.30),p+Vector3(.45,.65,.20),p+Vector3(.75,.12,.5),p+Vector3(2.0,.03,.4)],.16)
		var b:=TAU*(i+1)/18.;var q:=center(b,16.6,10.7)
		if front or sin(b)>.20:continue
		arch(p,q,h)
	for i in 10:
		var a:=TAU*i/10.;var p:=center(a,14.9,9.2)
		pedestal(p,crystal,.95 if sin(a)>.3 else 1.35)
		if i%3==0:rune_light(p,Color('#7d99dd'),1.0)
	# Monument behind the boss: nested stone doorway with a crescent at its lintel.
	monument(Vector3(16,0,-2.0),stone,Color('#7d9cdd'))
	plants(17.8,12.4,125)
func arch(p: Vector3,q: Vector3,h: float) -> void:
	var axis: Vector3=(q-p).normalized();var mid: Vector3=(p+q)*.5;var radius:=p.distance_to(q)*.5
	var angle:=atan2(-axis.z,axis.x)
	for j in 13:
		var t:=PI*j/12.;var at:=mid+axis*(cos(t)*radius)+Vector3(0,h+.46+sin(t)*radius*.82,0)
		var basis:=Basis(Vector3.UP,angle)*Basis(Vector3.FORWARD,t-PI*.5)
		ref.put_transform('LunarArchStones',ref.mesh('rock1'),stone,Transform3D(basis.scaled(Vector3(.72,.63,.90)),at))
		if j%2==0:put('LunarArchMoss','rock2',moss,at+Vector3(0,.28,0),Vector3(.78,.12,.55),angle)
	var purple:=ref.plain('#796aa6')
	for strand in 7:
		var at:=mid+axis*(strand-3)*.24+Vector3(0,h+radius*.63,0)
		for flower in 10:
			var f:=flower/10.0
			put('LunarWisteria','petal',purple,at+Vector3(sin(f*14)*.09,-f*(1.1+strand*.04),cos(f*13)*.10),Vector3.ONE*(1.-f*.4))
func monument(p: Vector3,mat: Material,tint: Color) -> void:
	var marker:=Marker3D.new();marker.name='BossGateMonument';marker.position=p;own(marker)
	for side in [-1,1]:
		var base:=p+Vector3(side*2.1,0,0)
		put('BossGatePlinth','rock0',mat,base+Vector3(0,.24,0),Vector3(1.7,.48,1.55))
		put('BossGatePillar','box',mat,base+Vector3(0,2.2,0),Vector3(1.10,4.0,1.0))
		put('BossGateCrown','rock1',mat,base+Vector3(0,4.5,0),Vector3(1.65,.45,1.65))
	put('BossGateLintel','box',mat,p+Vector3(0,4.7,0),Vector3(5.8,.75,1.3))
	var crescent:=SurfaceTool.new();crescent.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 32:
		var a:=j*TAU/32.;var b:=float(j+1)*TAU/32.
		var pa:=Vector3(cos(a)*.78,5.9+sin(a)*.78,0)
		var pb:=Vector3(cos(b)*.78,5.9+sin(b)*.78,0)
		var pc:=Vector3(.26+cos(a)*.59,6.0+sin(a)*.59,0)
		var pd:=Vector3(.26+cos(b)*.59,6.0+sin(b)*.59,0)
		author.triangle(crescent,pa,pb,pc);author.triangle(crescent,pb,pd,pc)
	crescent.generate_normals()
	var n:=MeshInstance3D.new();n.name='MoonGateEmblem';n.mesh=crescent.commit();n.material_override=ref.plain(tint.to_html(false),.5,.25);n.position=p;own(n)
func canyon() -> void:
	var original:=scene.get_node_or_null('ArtPolish/ReferenceScenery')
	if original!=null:original.visible=false
	# One connected, irregular cliff instead of repeated cylindrical towers.
	var wall:=SurfaceTool.new();wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top:=SurfaceTool.new();top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments:=144
	for i in segments:
		var a:=i*TAU/segments;var b:=float(i+1)*TAU/segments
		for layer in 14:
			var pa:=cliff_point(a,layer/14.0);var pb:=cliff_point(b,layer/14.0)
			var pc:=cliff_point(a,(layer+1)/14.0);var pd:=cliff_point(b,(layer+1)/14.0)
			author.triangle(wall,pa,pb,pc,Vector2(a*6,pa.y*.13),Vector2(b*6,pb.y*.13),Vector2(a*6,pc.y*.13))
			author.triangle(wall,pb,pd,pc,Vector2(b*6,pb.y*.13),Vector2(b*6,pd.y*.13),Vector2(a*6,pc.y*.13))
			var ia:=inner_cliff_point(a,layer/14.0);var ib:=inner_cliff_point(b,layer/14.0)
			var ic:=inner_cliff_point(a,(layer+1)/14.0);var id:=inner_cliff_point(b,(layer+1)/14.0)
			author.triangle(wall,ia,ic,ib);author.triangle(wall,ib,ic,id)
		if i%6==0 and sin(a)<.2:
			var p:=cliff_point(a,1)
			put('CanyonRimBoulders','rock'+str(i%3),stone,p+Vector3(0,.36,0),Vector3(1.8,.85,1.55),a)
		var pa:=cliff_point(a,1);var pb:=cliff_point(b,1)
		var qa:=center(a,16.9,11.8,pa.y);var qb:=center(b,16.9,11.8,pb.y)
		author.triangle(top,pa,pb,qa);author.triangle(top,pb,qb,qa)
	wall.generate_normals();top.generate_normals()
	for pair in [['SculptedCanyonEscarpment',wall],['SandstoneRimShelves',top]]:
		var n:=MeshInstance3D.new();n.name=pair[0];n.mesh=pair[1].commit();n.material_override=stone;own(n)
	# Fit the visible mesa to the cliffs, while retaining the existing collision body.
	var floor_surface:=SurfaceTool.new();floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a:=i*TAU/segments;var b:=float(i+1)*TAU/segments
		var pa:=center(a,18.8,13.5);var pb:=center(b,18.8,13.5)
		author.triangle(floor_surface,Vector3(16,0,10),pa,pb,Vector2(.5,.5),Vector2(pa.x,pa.z)*.05,Vector2(pb.x,pb.z)*.05)
	floor_surface.generate_normals();floor_surface.generate_tangents();scene.get_node('SculptedTerrain').mesh=floor_surface.commit()
	var portal:=Vector3(5,0,-.5)
	var darkness:=ref.plain('#191513')
	put('MineMouth','box',darkness,portal+Vector3(0,1.45,-.5),Vector3(4.4,2.9,.22))
	for side in [-1,1]:
		put('MinePortalPosts','box',wood,portal+Vector3(side*2.4,1.85,0),Vector3(.43,3.7,.50))
	put('MinePortalLintel','box',wood,portal+Vector3(0,3.60,0),Vector3(5.7,.55,.60))
	for i in 16:put('MineLoadingDeck','box',wood,portal+Vector3(-2.8+i*.38,2.9,1.4),Vector3(.33,.16,2.5))
	for x in [-2.5,2.5]:
		ref.beam('MineCrossBraces',portal+Vector3(x,.15,2.1),portal+Vector3(-x,2.8,2.1),.18,.18,wood)
	for i in 3:
		var p:=portal+Vector3(-2+i*.75,.45,1.2)
		put('SupplyCrates','box',wood,p,Vector3(.68,.75,.70),i*.2)
		for side in [-1,1]:put('CrateBands','box',steel,p+Vector3(side*.28,0,.36),Vector3(.08,.77,.03),i*.2)
	# Rail along the western rim; every sleeper is outside the actual raid floor.
	for i in 34:
		var a:=PI*.85+i*.042;var b:=a+.042
		var p:=center(a,14.5,9.5,.07);var q:=center(b,14.5,9.5,.07)
		var across:=Vector3(cos(a),0,sin(a))*.52
		ref.beam('RailSleepers',p-across,p+across,.13,.16,wood)
		for sign in [-1,1]:ref.beam('ForgedRail',p+across*sign+Vector3(0,.12,0),q+across*sign+Vector3(0,.12,0),.065,.065,steel)
	for i in 7:
		var a:=TAU*i/7.;var p:=center(a,15.5,10.1)
		if p.z>15:continue
		pedestal(p,crystal,.80);rune_light(p,Color('#eaa56a'),.85)
	for i in 9:
		var a:=TAU*i/9.;var p:=center(a,16.1,11.0)
		if p.z<3:continue
		put('MineRimFence','box',wood,p+Vector3(0,.45,0),Vector3(.12,.9,.12))
		ref.lantern(p+Vector3(0,.85,0))
func inner_cliff_point(a: float,t: float) -> Vector3:
	var edge:=cliff_point(a,1.0)
	var ledge:=sin(t*PI*13)*.22+sin(a*13+t*3)*.12
	return center(a,16.9+ledge,11.8+ledge*.6,lerpf(-.12,edge.y,t))
func cliff_point(a: float,t: float) -> Vector3:
	var front:=smoothstep(-.10,.40,sin(a))
	var height:=lerpf(4.6+sin(a*5)*.45+sin(a*11)*.22,.32,front)
	var ledge:=sin(t*PI*13)*.30+sin(a*13+t*3)*.24
	var bulge:=sin(a*17)*.28+sin(a*7)*.28+ledge
	return center(a,18.7+bulge,13.1+bulge*.7,lerpf(-7.0,height,t))
func forest() -> void:
	for node in scene.get_children():
		if node is MeshInstance3D and node.mesh is TorusMesh and node.position.distance_to(Vector3(16,0,10))<.2:node.visible=false
	var original:=scene.get_node_or_null('ArtPolish/ReferenceScenery')
	if original!=null:original.visible=false
	ring_blocks('AncientForestStoneCircle',16.4,10.4,moss,.44,86)
	# Broken gate and mature roots identify the giant-tree boss's home.
	monument(Vector3(16,0,-.7),moss,Color('#a7b78a'))
	for x in [1.6,30.4]:
		var p:=Vector3(x,0,.8)
		for part in ['bark','leaves']:
			put('AncientGuardianTrees_'+part,part+'1',wood if part=='bark' else leaf,p,Vector3.ONE*.85,.1 if x<16 else -.4)
		for i in 4:
			var direction:=Vector3(1 if x<16 else -1,0,1).normalized()
			ref.root_path([p+Vector3(0,2.4,0),p+direction*.8+Vector3(0,1.0,0),p+direction*2+Vector3(0,.23,0),p+direction*3.1+Vector3(i*.2,.06,0)],.30)
	var stream:=SurfaceTool.new();stream.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3]=[Vector3(-3,.05,-1.4),Vector3(5,.05,-1.8),Vector3(13,.05,-1.1),Vector3(24,.05,-.1),Vector3(32,.05,1.2),Vector3(34,.05,4.0),Vector3(34,.05,10.0)]
	for i in points.size()-1:
		var p: Vector3=points[i];var q: Vector3=points[i+1]
		var across: Vector3=(q-p).normalized().cross(Vector3.UP)*.72
		author.triangle(stream,p-across,q-across,p+across,Vector2(p.x,p.z)*.2,Vector2(q.x,q.z)*.2,Vector2(p.x,p.z)*.2+Vector2(.3,0))
		author.triangle(stream,p+across,q-across,q+across)
		for j in 4:
			var at: Vector3=p.lerp(q,j/4.0)
			for sign in [-1,1]:put('ForestStreamBank','rock'+str(j%3),moss,at+across*sign*1.2+Vector3(0,.15,0),Vector3(.7,.35,.6),j)
	stream.generate_normals();var water:=ShaderMaterial.new();water.shader=load('res://assets/maps3d/materials/water.gdshader');water.set_shader_parameter('water_color',Color('#25616a'))
	var n:=MeshInstance3D.new();n.name='GuardianStream';n.mesh=stream.commit();n.material_override=water;own(n)
	for i in 3:
		var p:=Vector3(24,1.1+i*.6,-1.4-i*.55)
		put('ForestCascadeRocks','rock1',moss,p-Vector3(0,.2,0),Vector3(2.9,.6,1.0))
		var fall:=PlaneMesh.new();fall.size=Vector2(1.4,.68)
		ref.put_transform('ForestCascade',fall,water,Transform3D(Basis(Vector3.RIGHT,PI*.5),p+Vector3(0,.1,.5)))
	plants(16.5,10.6,165)
	for i in 180:
		var p:=Vector3(rng.randf_range(3,29),.025,rng.randf_range(3,17))
		if Vector2((p.x-16)/14.,(p.z-10)/8.).length()>1.:continue
		put('ClearingGrassTufts','fern',leaf,p,Vector3.ONE*rng.randf_range(.07,.15),rng.randf_range(0,TAU))
	for i in 9:
		var a:=TAU*i/9.;var p:=center(a,17.7,12.5)
		if sin(a)>.25:continue
		for part in ['bark','leaves']:put('RaidCanopy_'+part,part+str(i%3),wood if part=='bark' else leaf,p,Vector3.ONE*.72,a)
func ice() -> void:
	monument(Vector3(16,0,-.9),stone,Color('#67c9e9'))
	for p in [Vector3(3,0,3),Vector3(29,0,3),Vector3(3,0,17),Vector3(29,0,17)]:
		pedestal(p,crystal,1.4)
		rune_light(p,Color('#62bfd9'),1.15)
	ring_blocks('FrozenCourtyardRim',16.4,10.7,stone,.32,78)
func plants(rx: float,rz: float,count: int) -> void:
	var flowers:=ref.plain('#e2d9b7');var purple:=ref.plain('#9284b4')
	for i in count:
		var a:=i*TAU/count;var p:=center(a,rx+rng.randf_range(-.5,.5),rz+rng.randf_range(-.4,.4),.05)
		put('RaidBorderFerns','fern',leaf,p,Vector3.ONE*rng.randf_range(.55,.95),a)
		for j in 3:
			var q:=p+Vector3(rng.randf_range(-.3,.3),.18,rng.randf_range(-.3,.3))
			put('RaidWildflowers','petal',purple if theme=='sanctuary' else flowers,q,Vector3(.70,.60,.70))
func border_rubble() -> void:
	for i in 110:
		var a:=rng.randf_range(0,TAU);var p:=center(a,16.8+rng.randf_range(0,1.5),10.7+rng.randf_range(0,1.4),.06)
		put('RaidRimRubble','rock'+str(i%3),stone,p,Vector3(rng.randf_range(.12,.40),rng.randf_range(.08,.24),rng.randf_range(.15,.40)),a)
