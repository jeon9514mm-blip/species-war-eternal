extends RefCounted
## Authored, fixed-cost raid stages. All raised geometry stays outside FLOOR.
## The simulation, feet, warnings and touch plane remain at world y = 0.
const FLOOR=preload('res://scripts/raid/RaidBattlefield.gd').FLOOR
const PIVOT=Vector2(519,383)
const UNITS=Vector2(13.0,26.0*.7071068)
const THEMES={
	'gray_meadow':{'id':'sky_court','title':'천공 수호 유적','stone':Color('#737f80'),'foundation':Color('#303d43'),'metal':Color('#b49b70'),'accent':Color('#86c7c9'),'interior':Color('#acb2a5')},
	'forgotten_mine':{'id':'amber_quarry','title':'호박빛 심층 광산','stone':Color('#595958'),'foundation':Color('#292b31'),'metal':Color('#a8875d'),'accent':Color('#edb766'),'interior':Color('#9e968a')},
	'moonrest_forest':{'id':'lunar_sanctum','title':'월광의 성소','stone':Color('#73798f'),'foundation':Color('#303041'),'metal':Color('#b5aac1'),'accent':Color('#c4adf0'),'interior':Color('#a2a6b7')},
}
static func profile(zone: String) -> Dictionary:return THEMES.get(zone,THEMES.gray_meadow)
static func to_world(point: Vector2) -> Vector2:return Vector2(16,10)+(point-PIVOT)/UNITS
static func combat_rect() -> Rect2:
	return Rect2(to_world(FLOOR.position),FLOOR.size/UNITS)

static func _material(color: Color,metallic:=.0,emission:=.0) -> StandardMaterial3D:
	var value:=StandardMaterial3D.new();value.albedo_color=color
	value.roughness=.72;value.metallic=metallic
	value.emission_enabled=emission>0;value.emission=color;value.emission_energy_multiplier=emission
	if emission<=0:
		# Reuse the resident stone atlas rather than loading a second environment
		# texture set. Local triplanar UVs weather column sides and carved caps.
		value.albedo_texture=load('res://assets/mobile25d/floor/stone_1024_albedo_ao.png')
		value.normal_enabled=true;value.normal_scale=.10 if metallic>.0 else .22
		value.normal_texture=load('res://assets/mobile25d/floor/stone_1024_normal.png')
		value.uv1_triplanar=true;value.uv1_scale=Vector3(.70,.70,.70)
		value.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return value
static func _mesh(parent: Node3D,label: String,mesh: Mesh,position: Vector3,material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;node.position=position
	node.material_override=material;node.gi_mode=GeometryInstance3D.GI_MODE_STATIC
	# Static architecture is shaded by the shared sun, without extra shadow passes.
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node);return node
static func _box(parent: Node3D,label: String,position: Vector3,dimensions: Vector3,material: Material) -> MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=dimensions
	return _mesh(parent,label,mesh,position,material)
static func _column(parent: Node3D,label: String,point: Vector2,height: float,radius: float,material: Material) -> MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius*.88;mesh.bottom_radius=radius
	mesh.height=height;mesh.radial_segments=8;mesh.rings=1
	return _mesh(parent,label,mesh,Vector3(point.x,height*.5,point.y),material)
static func _crystal(parent: Node3D,label: String,point: Vector2,height: float,radius: float,material: Material) -> MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=0;mesh.bottom_radius=radius
	mesh.height=height;mesh.radial_segments=5;mesh.rings=1
	var value:=_mesh(parent,label,mesh,Vector3(point.x,height*.5,point.y),material)
	value.rotation_degrees.z=9 if int(point.x)%2==0 else -12
	return value

static func build(map_root: Node3D,zone: String) -> void:
	var arena: Node3D=map_root.get_node('Arena')
	# The old raid mesh used hunt-sized column placement: several columns lay
	# inside the stretched raid movement rectangle. Replace that visible mesh.
	var previous: Node3D=arena.get_node('EnvironmentModel');previous.hide()
	previous.set_meta('replaced_by','RaidEncounterArena')
	var root:=Node3D.new();root.name='RaidEncounterArena';arena.add_child(root)
	var theme: Dictionary=profile(zone);var rect:=combat_rect();var center:=rect.get_center()
	var platform:=rect.grow(1.25)
	var stone:=_material(theme.stone)
	var dark:=_material(theme.foundation)
	var metal:=_material(theme.metal,.35)
	var light:=_material(theme.accent,.15,.28)
	_box(root,'Foundation',Vector3(center.x,-.56,center.y),Vector3(platform.size.x,.95,platform.size.y),dark)
	# The shallow perimeter is outside every reachable combat coordinate.
	for z in [platform.position.y,platform.end.y]:
		_box(root,'OuterLip',Vector3(center.x,-.045,z),Vector3(platform.size.x,.14,.40),stone)
		_box(root,'BronzeInlay',Vector3(center.x,.006,z+.03),Vector3(platform.size.x-.6,.016,.08),metal)
	for x in [platform.position.x,platform.end.x]:
		_box(root,'OuterLip',Vector3(x,-.045,center.y),Vector3(.40,.14,platform.size.y),stone)
		_box(root,'BronzeInlay',Vector3(x+.03,.006,center.y),Vector3(.08,.016,platform.size.y-.6),metal)
	var rear:=rect.position.y-3.0
	var corners: Array[Vector2]=[
		Vector2(rect.position.x-1.3,rear),Vector2(rect.end.x+1.3,rear),
		Vector2(rect.position.x-1.3,rect.end.y+1.35),Vector2(rect.end.x+1.3,rect.end.y+1.35)]
	for i in corners.size():
		var p:=corners[i]
		_box(root,'CornerPlinth'+str(i),Vector3(p.x,.12,p.y),Vector3(1.6,.24,1.25),stone)
		_column(root,'CornerSigil'+str(i),p,.19,.55,metal)
		if i<2:_crystal(root,'CornerBeacon'+str(i),p,.9,.26,light)
	match str(theme.id):
		'sky_court':_sky(root,rect,rear,stone,metal,light)
		'amber_quarry':_mine(root,rect,rear,stone,dark,metal,light)
		'lunar_sanctum':_moon(root,rect,rear,stone,metal,light)
	root.set_meta('encounter_design',{'id':theme.id,'title':theme.title,'combat_rect':rect,'platform_rect':platform,'raised_geometry_outside_floor':true,'dynamic_lights':0,'static_mesh_count':root.find_children('*','MeshInstance3D',true,false).size(),'texture_reuse':'existing four packed stone maps'})
	map_root.set_meta('dedicated_raid_arena',str(theme.id))

static func _sky(root: Node3D,rect: Rect2,rear: float,stone: Material,metal: Material,light: Material) -> void:
	# Weathered colonnade and a small sanctuary beyond the attackable floor.
	for x in [rect.position.x+3.0,rect.position.x+10.0,rect.end.x-10.0,rect.end.x-3.0]:
		var p:=Vector2(x,rear)
		_box(root,'TempleFoot',Vector3(x,.13,rear),Vector3(2.1,.26,1.7),stone)
		_column(root,'TempleColumn',p,3.6,.44,stone)
		_box(root,'TempleCapital',Vector3(x,3.62,rear),Vector3(1.45,.27,1.05),metal)
		_column(root,'TempleCollar',p,.35,.63,metal)
	for x in [rect.position.x+6.5,rect.end.x-6.5]:
		_box(root,'BrokenLintel',Vector3(x,3.86,rear),Vector3(8.5,.30,.84),stone)
	var c:=rect.get_center().x
	_box(root,'SanctuarySteps',Vector3(c,.18,rear-1),Vector3(7,.36,2.0),stone)
	_box(root,'SanctuaryTablet',Vector3(c,1.04,rear-1),Vector3(4,.92,.65),stone)
	_box(root,'SanctuaryLight',Vector3(c,1.54,rear-.65),Vector3(3.25,.08,.04),light)

static func _mine(root: Node3D,rect: Rect2,rear: float,stone: Material,dark: Material,metal: Material,light: Material) -> void:
	# Ore seams, heavy gantries and cart rails are outside the clear central court.
	for x in [rect.position.x+3,rect.end.x-3]:
		_box(root,'MineButtress',Vector3(x,2.1,rear),Vector3(1.15,4.2,.95),dark)
		_box(root,'MineClamp',Vector3(x,3.70,rear+.01),Vector3(1.4,.27,1.12),metal)
		for j in 3:
			_crystal(root,'AmberOre',Vector2(x+float(j-1)*.63,rear+.55),1.3+float(j)*.45,.4,light)
	_box(root,'MineGantries',Vector3(rect.get_center().x,4.35,rear),Vector3(rect.size.x-5,.44,.65),metal)
	_box(root,'MineGantryPatina',Vector3(rect.get_center().x,4.51,rear+.36),Vector3(rect.size.x-5,.06,.08),dark)
	var c:=rect.get_center().x
	_box(root,'OreAltar',Vector3(c,.3,rear-.55),Vector3(7,.6,2.25),stone)
	for j in 5:_crystal(root,'CoreOre',Vector2(c+float(j-2)*.65,rear-.35),1.45+float((j+1)%3)*.42,.38,light)
	for x in [rect.position.x-.65,rect.end.x+.65]:
		_box(root,'CartRail',Vector3(x,.035,rect.get_center().y),Vector3(.07,.05,rect.size.y),metal)

static func _moon(root: Node3D,rect: Rect2,rear: float,stone: Material,metal: Material,light: Material) -> void:
	for x in [rect.position.x+3.5,rect.end.x-3.5]:
		var p:=Vector2(x,rear)
		_column(root,'MoonColumn',p,3.0,.50,stone)
		_box(root,'MoonCapital',Vector3(x,3.06,rear),Vector3(1.6,.20,1.15),metal)
		_crystal(root,'MoonCrown',Vector2(x,rear),1.02,.34,light).position.y+=3.25
	var c:=rect.get_center().x
	_box(root,'LunarAltar',Vector3(c,.2,rear-.35),Vector3(7,.40,2.3),stone)
	# An open crescent silhouette uses one tiny static mesh, with no light node.
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
	for i in 25:
		var angle:=lerpf(-2.35,2.35,float(i)/24.0)
		for radius in [1.35,1.12]:
			vertices.append(Vector3(sin(angle)*radius,cos(angle)*radius,0));normals.append(Vector3(0,0,1))
	for i in 24:
		var a:=i*2
		indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var crescent:=_mesh(root,'CrescentShrine',mesh,Vector3(c,2.1,rear-.20),light)
	var material:=light.duplicate() as StandardMaterial3D;material.cull_mode=BaseMaterial3D.CULL_DISABLED;crescent.material_override=material
	for offset in [-3.4,3.4]:_crystal(root,'LunarShard',Vector2(c+offset,rear),1.6,.35,light)

static func finish_floor(map_root: Node3D,zone: String) -> void:
	var floor: MeshInstance3D=map_root.get_node('Arena/PBRStoneSlabs1024')
	var original: ShaderMaterial=floor.material_override
	var material:=ShaderMaterial.new();material.shader=preload('res://shaders/RaidArenaPBR.gdshader')
	for parameter in ['stone_art','stone_normal','stone_micro_normal','stone_surface','tile_scale','parallax_steps','moss_glow']:
		material.set_shader_parameter(parameter,original.get_shader_parameter(parameter))
	var theme: Dictionary=profile(zone);var rect:=combat_rect()
	material.set_shader_parameter('arena_min',rect.position)
	material.set_shader_parameter('arena_max',rect.end)
	material.set_shader_parameter('court_tint',theme.interior)
	material.set_shader_parameter('outer_tint',theme.foundation)
	material.set_shader_parameter('inlay_color',theme.metal)
	material.set_shader_parameter('sigil_color',theme.accent)
	floor.material_override=material;floor.set_meta('dedicated_combat_surface',str(theme.id))
