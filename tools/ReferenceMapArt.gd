extends RefCounted
## Geometry direction from the user's three map reference images (2026-10-02).
## All tall scenery stays outside the 32 x 20 simulation rectangle.
var scene: Node3D
var group: Node3D
var biome: String
var rng:=RandomNumberGenerator.new()
var author=preload('res://tools/ForestMeshAuthor.gd').new()
var batches: Dictionary={}
var cache: Dictionary={}
var stone: Material
var moss: Material
var bark: Material
var metal: Material
var leaf: Material
var cyan: Material
var violet: Material
var roots: SurfaceTool
var root_segments:=0
func apply(target: Node3D,parent: Node3D,theme: String) -> void:
	scene=target;biome=theme;rng.seed=836600+['sanctuary','canyon','forest'].find(theme)
	group=Node3D.new();group.name='ReferenceScenery';parent.add_child(group);group.owner=scene
	materials();retire_old_scenery();lighting()
	roots=SurfaceTool.new();roots.begin(Mesh.PRIMITIVE_TRIANGLES)
	if theme=='sanctuary':sanctuary()
	elif theme=='canyon':canyon()
	else:forest()
	flush()
func own(n: Node) -> void:
	group.add_child(n);n.owner=scene
func plain(color: String,rough:=.85,emission:=0.) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=rough
	if emission>0:m.emission_enabled=true;m.emission=m.albedo_color;m.emission_energy_multiplier=emission
	return m
func materials() -> void:
	stone=load_rock('#b8c6c5' if biome=='sanctuary' else ('#dc9a76' if biome=='canyon' else '#999b71'))
	moss=load_rock('#697b42');moss.set_shader_parameter('moss_amount',.8)
	bark=StandardMaterial3D.new();bark.albedo_texture=load('res://assets/maps3d/pbr/bark_brown_01_diff.jpg');bark.albedo_color=Color('#9c8061');bark.roughness=.87
	metal=plain('#433b34',.45)
	leaf=ShaderMaterial.new();leaf.shader=load('res://assets/maps3d/materials/foliage.gdshader');leaf.set_shader_parameter('foliage_tint',Color('#94b897'))
	cyan=plain('#69dfe5',.26,1.25);violet=plain('#9874c5',.7)
func load_rock(tint: String) -> ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=load('res://assets/maps3d/materials/detail_rock.gdshader');m.set_shader_parameter('rock_texture',load('res://assets/maps3d/pbr/'+('rock_face_03' if biome=='canyon' else 'mossy_rock')+'_diff.jpg'));m.set_shader_parameter('tint',Color(tint));m.set_shader_parameter('texture_scale',.4)
	if biome=='canyon':m.set_shader_parameter('strata_amount',.22)
	return m
func retire_old_scenery() -> void:
	for n in scene.get_children():
		if n is MultiMeshInstance3D:n.visible=false;continue
		if not n is MeshInstance3D or n.get_child_count()>0:continue
		if biome!='forest':n.visible=false;continue
		if n.material_override is ShaderMaterial:
			var path: String=n.material_override.shader.resource_path
			if path.ends_with('water.gdshader'):n.visible=false
			if path.ends_with('detail_rock.gdshader'):
				# Retain the existing broken watchtower on the northwest bank.
				n.visible=n.position.x>0 and n.position.x<6 and n.position.z<0 and n.position.z> -8
	var floor_node: MeshInstance3D=scene.get_node('SculptedTerrain')
	if biome=='sanctuary':
		var m:=ShaderMaterial.new();m.shader=load('res://assets/maps3d/materials/sanctuary_paving.gdshader')
		m.set_shader_parameter('carving',load('res://assets/maps3d/ornament/arena-carving.png'))
		m.set_shader_parameter('stone_color',load('res://assets/maps3d/pbr/cobblestone_floor_01_diff.jpg'))
		m.set_shader_parameter('stone_normal',load('res://assets/maps3d/pbr/cobblestone_floor_01_nor_gl.jpg'));floor_node.material_override=m
func lighting() -> void:
	var env: Environment=scene.get_node('Atmosphere').environment
	env.fog_sky_affect=0.;env.fog_density=.0007;env.volumetric_fog_density=.00065;env.tonemap_exposure=1.0
	var sun: DirectionalLight3D=scene.get_node('Sunlight')
	if biome=='sanctuary':
		env.background_color=Color('#091a23');env.ambient_light_color=Color('#77a2b2');env.ambient_light_energy=.31
		sun.light_color=Color('#c7e2ed');sun.light_energy=1.12;sun.rotation_degrees=Vector3(-49,-32,0)
	elif biome=='forest':
		env.background_color=Color('#263c32');env.ambient_light_color=Color('#9cbca8');env.ambient_light_energy=.35
		sun.light_color=Color('#fff1bd');sun.light_energy=1.3
	else:
		env.background_color=Color('#9b6e60');env.ambient_light_color=Color('#8e9db6');env.ambient_light_energy=.31
		sun.light_color=Color('#ffd1a1');sun.light_energy=1.45
func mesh(key: String) -> Mesh:
	if cache.has(key):return cache[key]
	var m: Mesh
	match key:
		'box':m=BoxMesh.new()
		'column':
			var c:=CylinderMesh.new();c.height=1;c.top_radius=.44;c.bottom_radius=.5;c.radial_segments=24;m=c
		'cord':
			var c:=CylinderMesh.new();c.height=1;c.top_radius=.5;c.bottom_radius=.5;c.radial_segments=8;m=c
		'gem':
			var c:=CylinderMesh.new();c.height=1;c.top_radius=0.;c.bottom_radius=.32;c.radial_segments=6;m=c
		'strata':m=stratum_mesh()
		'petal':
			var s:=SphereMesh.new();s.radius=.10;s.height=.17;s.radial_segments=6;s.rings=3;m=s
		_:m=load('res://assets/maps3d/baked/'+key+'.res')
	cache[key]=m;return m
func put(label: String,m: Mesh,mat: Material,p: Vector3,size: Vector3,angle:=0.0) -> void:
	put_transform(label,m,mat,Transform3D(Basis(Vector3.UP,angle).scaled(size),p))
func put_transform(label: String,m: Mesh,mat: Material,t: Transform3D) -> void:
	var key:=str(m.get_rid())+':'+str(mat.get_rid())
	if not batches.has(key):batches[key]={'label':label,'mesh':m,'material':mat,'transforms':[]}
	batches[key].transforms.append(t)
func beam(label: String,a: Vector3,b: Vector3,width: float,depth: float,mat: Material,round_shape:=false) -> void:
	var up: Vector3=(b-a).normalized();var side:=up.cross(Vector3.FORWARD).normalized()
	if side.length()<.1:side=Vector3.RIGHT
	var basis:=Basis(side,up,side.cross(up)).scaled(Vector3(width,a.distance_to(b),depth))
	put_transform(label,mesh('cord' if round_shape else 'box'),mat,Transform3D(basis,(a+b)*.5))
func ellipse(a: float,rx: float,rz: float,y:=0.) -> Vector3:
	var p:=Vector3(16+cos(a)*rx,y,10+sin(a)*rz)
	if biome=='sanctuary':p.y+=ground_y(p)
	return p
func corridor(p: Vector3,margin:=0.) -> bool:return p.x>30 and p.z>5-margin and p.z<14+margin
func root_path(points: Array[Vector3],radius: float) -> void:
	root_segments+=1
	var curve:=Curve3D.new();curve.bake_interval=.24
	for i in points.size():
		var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)])*.22
		curve.add_point(points[i],-tangent,tangent)
	var path:=curve.get_baked_points();var rings: Array=[];var last_side:=Vector3.RIGHT
	for i in path.size():
		var dir: Vector3=(path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]).normalized()
		var side: Vector3=last_side-dir*last_side.dot(dir)
		if side.length()<.05:side=dir.cross(Vector3.FORWARD)
		side=side.normalized();last_side=side
		var up:=dir.cross(side).normalized();var ring: Array[Vector3]=[]
		var r:=lerpf(radius,.022,float(i)/(path.size()-1))
		for j in 10:ring.append(path[i]+(side*cos(j*TAU/10.)+up*sin(j*TAU/10.))*r)
		rings.append(ring)
	for i in rings.size()-1:
		for j in 10:
			var k: int=(j+1)%10
			author.triangle(roots,rings[i][j],rings[i+1][j],rings[i][k],Vector2(j/10.,i*.2),Vector2(j/10.,(i+1)*.2),Vector2((j+1)/10.,i*.2))
			author.triangle(roots,rings[i][k],rings[i+1][j],rings[i+1][k],Vector2((j+1)/10.,i*.2),Vector2(j/10.,(i+1)*.2),Vector2((j+1)/10.,(i+1)*.2))
func flush() -> void:
	for data: Dictionary in batches.values():
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=data.mesh;multi.instance_count=data.transforms.size()
		for i in data.transforms.size():multi.set_instance_transform(i,data.transforms[i])
		var n:=MultiMeshInstance3D.new();n.name=data.label;n.multimesh=multi;n.material_override=data.material;own(n)
	if root_segments==0:return
	roots.generate_normals();var root_mesh:=roots.commit()
	if root_mesh!=null and root_mesh.get_surface_count()>0:
		var n:=MeshInstance3D.new();n.name='TwistingRootsAndVines';n.mesh=root_mesh;n.material_override=bark;own(n)
func sanctuary() -> void:
	# Full oval colonnade, broken low at the foreground to keep combat readable.
	var count:=20
	for i in count:
		var a:=TAU*i/count;var p:=ellipse(a,23,18)
		if corridor(p,1):continue
		var front: bool=sin(a)>.55;var h:=1.4 if front else 5.7
		put('CarvedColumnPlinths',mesh('rock0'),stone,p+Vector3(0,.18,0),Vector3(1.55,.36,1.55),-a)
		put('FlutedColumns',mesh('column'),stone,p+Vector3(0,h*.5+.3,0),Vector3(.94,h,.94))
		put('ColumnCapitals',mesh('rock0'),stone,p+Vector3(0,h+.4,0),Vector3(1.45,.35,1.45),-a)
		for flute in 12:
			var f:=flute*TAU/12.
			put('ColumnFlutes',mesh('cord'),stone,p+Vector3(cos(f)*.47,h*.5+.3,sin(f)*.47),Vector3(.075,h-.15,.075))
		for k in 3:
			var dir:=Vector3(cos(a+k*.28),0,sin(a+k*.28))
			root_path([p+Vector3(.4,h*.83,.1),p+Vector3(-.65,h*.47,.3),p+Vector3(.6,.6,.35),p+dir*1.2+Vector3(0,.17,0),p+dir*3.4],.20)
		var q:=ellipse((i+1)*TAU/count,23,18)
		if corridor(q,1):continue
		var midpoint: Vector3=(p+q)*.5;var axis: Vector3=(q-p).normalized();var radius:=p.distance_to(q)*.5
		var rotation:=atan2(-axis.z,axis.x)
		for j in 16:
			var t:=PI*j/15.;var height:=h+.45+sin(t)*radius*.68
			if front and j>3 and j<12:continue
			var at:=midpoint+axis*(cos(t)*radius)+Vector3(0,height,0)
			var basis:=Basis(Vector3.UP,rotation)*Basis(Vector3.FORWARD,t-PI*.5)
			put_transform('ArchVoussoirs',mesh('rock1'),stone,Transform3D(basis.scaled(Vector3(.94,.75,1.0)),at))
			if j%2==0:put('ArchMoss',mesh('rock2'),moss,at+Vector3(0,.32,0),Vector3(.74,.16,.72),rotation)
		if not front:
			for strand in 5:
				var at:=midpoint+axis*(strand-2)*.34+Vector3(0,h+radius*.55,0)
				for bloom in 12:
					var t:=bloom/12.;var offset:=Vector3(sin(bloom*2.4+strand)*.13,-t*(1.2+strand*.16),cos(bloom*2.4)*.13)
					put('HangingWisteria',mesh('petal'),violet,at+offset,Vector3.ONE*(1.-t*.50))
	for i in 12:
		var a:=TAU*i/12.;var p:=ellipse(a,20.7,15.8)
		if corridor(p,1):continue
		for tier in 3:put('CrystalPedestals',mesh('rock0'),stone,p+Vector3(0,.12+tier*.22,0),Vector3(1.75-tier*.26,.24,1.75-tier*.26),a)
		for gem in 5:
			var g:=gem*2.4;var h:=1.25 if gem==0 else rng.randf_range(.5,.85)
			put('SanctuaryCrystals',mesh('gem'),cyan,p+Vector3(cos(g)*.25,.7+h*.5,sin(g)*.25),Vector3(.65,h,.65),g)
		if i%3==0:
			var light:=OmniLight3D.new();light.name='CrystalPool';light.position=p+Vector3(0,1.6,0);light.light_color=Color('#4bcbd9');light.light_energy=1.7;light.omni_range=5.;own(light)
	plant_border(27.,22.,true)
func stratum_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2]=[Vector2(.43,-.5),Vector2(.50,-.32),Vector2(.49,.30),Vector2(.40,.5)]
	for j in profile.size()-1:
		for i in 16:
			var a:=i*TAU/16.;var b: float=(i+1)*TAU/16.
			var ra: float=1.+sin(i*2.4)*.075;var rb: float=1.+sin((i+1)*2.4)*.075
			var pa:=Vector3(cos(a)*profile[j].x*ra,profile[j].y,sin(a)*profile[j].x*ra)
			var pb:=Vector3(cos(b)*profile[j].x*rb,profile[j].y,sin(b)*profile[j].x*rb)
			var pc:=Vector3(cos(a)*profile[j+1].x*ra,profile[j+1].y,sin(a)*profile[j+1].x*ra)
			var pd:=Vector3(cos(b)*profile[j+1].x*rb,profile[j+1].y,sin(b)*profile[j+1].x*rb)
			author.triangle(st,pa,pb,pc);author.triangle(st,pb,pd,pc)
	for i in 16:
		var a:=i*TAU/16.;var b: float=(i+1)*TAU/16.
		author.triangle(st,Vector3(0,.5,0),Vector3(cos(a)*.4,.5,sin(a)*.4),Vector3(cos(b)*.4,.5,sin(b)*.4))
	st.generate_normals();return st.commit()
func canyon() -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 128:
		var a:=i*TAU/128.;var b: float=(i+1)*TAU/128.
		var pa:=ellipse(a,23.2,17.2);var pb:=ellipse(b,23.2,17.2)
		author.triangle(surface,Vector3(16,0,10),pa,pb,Vector2(1.6,1.),Vector2(pa.x,pa.z)*.1,Vector2(pb.x,pb.z)*.1)
	surface.generate_normals();surface.generate_tangents()
	scene.get_node('SculptedTerrain').mesh=surface.commit()
	# Large, visibly stratified sandstone towers surround an open mesa.
	for i in 44:
		var a:=TAU*i/44.;var p:=ellipse(a,23.4,17.4)
		if corridor(p,1.2):continue
		var front: bool=sin(a)>.35;var top:=.3 if front else rng.randf_range(4.0,6.8)
		if p.x<7 and p.z<1:top=2.2 # mine entrance landmark stays visible
		var layers:=int((top+9)/.88)
		for j in layers:
			var y: float=-9+j*.88;var bulge:=sin(j*.91+i)*.20
			put('LayeredSandstone',mesh('strata'),stone,Vector3(p.x,y,p.z),Vector3(4.65+bulge,1.02,4.2+bulge),-a)
		put('SandstoneCaps',mesh('strata'),stone,Vector3(p.x,top+.08,p.z),Vector3(4.75,.6,4.4),-a)
		if i%3==0:
			var post:=p+Vector3(0,maxf(.3,top),0)
			put('RimSafetyPosts',mesh('box'),bark,post+Vector3(0,.7,0),Vector3(.16,1.4,.16))
			if front:lantern(post+Vector3(0,1.2,.2))
	# Mine portal and timber scaffold, all north of the playable floor.
	var dark:=plain('#191b22');put('MineRecess',mesh('box'),dark,Vector3(3,2,-4.4),Vector3(5.8,4.2,.18))
	for x in [-.4,6.4]:
		beam('MineUprights',Vector3(x,0,-2.8),Vector3(x,5.5,-2.8),.55,.65,bark)
		beam('MineBraces',Vector3(x,1,-2.6),Vector3(x+(-1.7 if x>0 else 1.7),4.7,-2.6),.24,.27,bark)
	put('MineLintel',mesh('box'),bark,Vector3(3,4.9,-2.8),Vector3(8,.65,.8))
	for i in 26:
		put('ScaffoldDeck',mesh('box'),bark,Vector3(-1+i*.35,5.2,-4.4),Vector3(.31,.16,3.2))
	for x in [-1.,1.5,4.,7.7]:
		beam('ScaffoldPosts',Vector3(x,.2,-5.8),Vector3(x,6.6,-5.8),.23,.23,bark)
		beam('ScaffoldPosts',Vector3(x,.2,-2.9),Vector3(x,6.6,-2.9),.23,.23,bark)
	beam('ScaffoldHandrail',Vector3(-1,6.3,-2.9),Vector3(7.7,6.3,-2.9),.13,.13,bark)
	for p in [Vector3(.0,2.7,-2.2),Vector3(6.1,2.7,-2.2)]:lantern(p)
	# Curving track follows the west rim; it never enters the battle rectangle.
	var previous:=Vector3.ZERO
	for i in 60:
		var t:=i/59.;var a: float=PI*1.28-t*PI*.73;var p:=ellipse(a,19.6,15.4,.18)
		var tangent:=Vector3(-sin(a)*19.6,0,cos(a)*15.4).normalized();var side:=Vector3(-tangent.z,0,tangent.x)
		put('TrackSleepers',mesh('box'),bark,p,Vector3(2.0,.15,.23),atan2(-side.z,side.x))
		if i>0:
			var last_a: float=PI*1.28-(i-1)/59.*PI*.73;var last_t:=Vector3(-sin(last_a)*19.6,0,cos(last_a)*15.4).normalized();var last_s:=Vector3(-last_t.z,0,last_t.x)
			for s in [-1,1]:beam('CurvedSteelRails',previous+last_s*.70*s+Vector3(0,.13,0),p+side*.70*s+Vector3(0,.13,0),.10,.11,metal)
		previous=p
	for i in 10:
		var p:=Vector3(-1.8+rng.randf()*2.4,.4,-.5-rng.randf()*2)
		put('MineCrates',mesh('box'),bark,p,Vector3(.65,.8,.7),rng.randf_range(-.2,.2))
	# A static low mist layer beneath the mesa suggests the depth of the chasm.
	var mist:=ShaderMaterial.new();mist.shader=load('res://assets/maps3d/materials/cavern_mist.gdshader');mist.set_shader_parameter('mist_color',Color(.18,.22,.27,.4))
	var plane:=PlaneMesh.new();plane.size=Vector2(72,60);put('LowerChasmHaze',plane,mist,Vector3(16,-10,10),Vector3.ONE)
func lantern(p: Vector3) -> void:
	put('LanternCages',mesh('box'),metal,p,Vector3(.32,.48,.32))
	if not cache.has('amber'):cache['amber']=plain('#ffba5f',.3,2.)
	put('AmberLanterns',mesh('box'),cache.amber,p+Vector3(0,0,.18),Vector3(.20,.29,.08))
func ground_y(p: Vector3) -> float:
	var edge:=maxf(maxf(-p.x,p.x-32.),maxf(-p.z,p.z-20.))
	return smoothstep(0,7,edge)*(1.4+sin(p.x*.31)*.8+cos(p.z*.38)*.65)
func forest() -> void:
	# Broken low masonry frames the grass without hiding front-line units.
	for i in 100:
		var a:=TAU*i/100.;var p:=ellipse(a,22.7,16.5)
		if corridor(p,1.) or (p.x<6 and p.z<0):continue
		var h:=rng.randf_range(.35,.8)
		for row in 2:
			put('OvergrownLowWall',mesh('rock'+str(i%3)),stone,p+Vector3(0,ground_y(p)+h*row+.22,0),Vector3(1.25,h,.82),-a+PI*.5)
		put('WallMoss',mesh('rock2'),moss,p+Vector3(0,ground_y(p)+h+.4,0),Vector3(1.3,.16,.9),-a)
	var points: Array[Vector3]=[Vector3(-4,0,-5),Vector3(2,0,-7),Vector3(9,0,-5),Vector3(17,0,-5.6),Vector3(25,0,-4),Vector3(32,0,-3),Vector3(36,0,1),Vector3(38,0,7),Vector3(38,0,16),Vector3(35,0,23)]
	var curve:=Curve3D.new()
	for i in points.size():
		var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()*2.0
		curve.add_point(points[i],-tangent,tangent)
	var path:=curve.get_baked_points();var water:=SurfaceTool.new();water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in path.size()-1:
		var a: Vector3=path[i];var b: Vector3=path[i+1];a.y=ground_y(a)+.075;b.y=ground_y(b)+.075
		var side: Vector3=(b-a).normalized().cross(Vector3.UP).normalized()*1.15
		for p in [a-side,b-side,a+side,a+side,b-side,b+side]:water.set_uv(Vector2(p.x,p.z)*.2);water.add_vertex(p)
		if i%5==0:
			for s in [-1,1]:
				var bank: Vector3=a+side*s*1.13;bank.y=ground_y(bank)+.22
				put('StreamBankStones',mesh('rock'+str(i%3)),moss,bank,Vector3(.7,.45,.6),i*.4)
	water.generate_normals();var wm:=ShaderMaterial.new();wm.shader=load('res://assets/maps3d/materials/water.gdshader');wm.set_shader_parameter('water_color',Color('#2b6875'))
	put('WindingWoodlandStream',water.commit(),wm,Vector3.ZERO,Vector3.ONE)
	# Stepped waterfall at the north bank, backed by rock shelves.
	for step in 3:
		var p:=Vector3(14,1.0+step*.85,-6.5-step*.8)
		put('WaterfallLedges',mesh('rock1'),moss,p-Vector3(0,.25,0),Vector3(4,.65,1.4))
		var fall:=PlaneMesh.new();fall.size=Vector2(1.6,.95)
		put_transform('CascadingWater',fall,wm,Transform3D(Basis(Vector3.RIGHT,PI*.5),p+Vector3(0,.12,.73)))
		var pool:=PlaneMesh.new();pool.size=Vector2(1.7,.85);put('WaterfallPools',pool,wm,p+Vector3(0,.13,0),Vector3.ONE)
	plant_border(21.8,15.8,false)
	for i in 7:
		var a: float=TAU*i/7.;var p:=ellipse(a,24,18)
		if corridor(p,1):continue
		for k in 4:
			var d:=Vector3(cos(a+k*.4),0,sin(a+k*.4))
			root_path([p+Vector3(0,2,0),p+d*.8+Vector3(0,.7,0),p+d*2+Vector3(0,.2,0),p+d*3.5],.32)
func plant_border(rx: float,rz: float,trees: bool) -> void:
	var flower_material:=plain('#dddaba')
	for i in 130:
		var a:=i*TAU/130.;var p:=ellipse(a,rx+rng.randf_range(-1,1),rz+rng.randf_range(-.5,.5))
		if corridor(p,1.):continue
		p.y=ground_y(p) if biome=='forest' else .08
		put('LushBorderFerns',mesh('fern'),leaf,p,Vector3.ONE*rng.randf_range(.75,1.35),a)
		for j in 3:
			var flower:=p+Vector3(rng.randf_range(-.5,.5),.24,rng.randf_range(-.5,.5))
			put('Wildflowers',mesh('petal'),cyan if biome=='sanctuary' else flower_material,flower,Vector3(.50,.40,.50))
	if trees:
		for i in 13:
			var a:=TAU*i/13.;var p:=ellipse(a,rx+3,rz+3)
			if sin(a)>.55 or corridor(p,2.):continue
			for part in ['bark','leaves']:put('OuterCanopy_'+part,mesh(part+str(i%3)),bark if part=='bark' else leaf,p,Vector3.ONE*1.05,a)
