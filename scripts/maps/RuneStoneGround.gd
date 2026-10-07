extends Node3D
## Asset-based stone surface; all geometry, light and clock changes are visual only.
const ART=preload('res://scripts/maps/FieldArtCatalog.gd')
const SURFACE_SHADER=preload('res://shaders/MossBronzeCircle.gdshader')
var zone_id:='gray_meadow'
var field: Control
var surface: MeshInstance3D
var stone_material: ShaderMaterial
var elapsed:=0.0
var arrow: MeshInstance3D
func _ready() -> void:
	name='RuneStoneGround'
	surface=MeshInstance3D.new();surface.name='ArtistStoneSurface'
	var plane:=PlaneMesh.new();plane.size=Vector2(3,4.243);surface.mesh=plane
	surface.position=Vector3(16,.016,10)
	stone_material=ShaderMaterial.new();stone_material.shader=SURFACE_SHADER
	stone_material.set_shader_parameter('moss',Color('#a8b89e'));stone_material.set_shader_parameter('bronze',Color('#c4a484'))
	stone_material.set_shader_parameter('artist_circle',load('res://assets/mobile25d/vfx/moss_bronze_circle.png'))
	surface.material_override=stone_material;add_child(surface)
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow=MeshInstance3D.new();arrow.name='BronzeDirectionArrow3D'
	var polygon:=PackedVector2Array([Vector2(-.4,-.12),Vector2(.05,-.12),Vector2(.05,-.25),Vector2(.4,0),Vector2(.05,.25),Vector2(.05,.12),Vector2(-.4,.12)])
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	for level in [.0,.035]:
		for point in polygon:vertices.append(Vector3(point.x,level,point.y));normals.append(Vector3.UP)
	var indices:=Geometry2D.triangulate_polygon(polygon);var triangles:=PackedInt32Array()
	for index in indices:triangles.append(index+polygon.size())
	for i in polygon.size():
		var j: int=(i+1)%polygon.size();triangles.append_array(PackedInt32Array([i,j,j+7,i,j+7,i+7]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=triangles
	var arrow_mesh:=ArrayMesh.new();arrow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);arrow.mesh=arrow_mesh
	var bronze:=StandardMaterial3D.new();bronze.albedo_color=Color('#c4a484');bronze.metallic=.32;bronze.roughness=.58;bronze.emission_enabled=true;bronze.emission=Color('#c4a484')*.35;bronze.cull_mode=BaseMaterial3D.CULL_DISABLED
	bronze.emission=Color('#c4a484')*.04
	arrow.scale=Vector3.ONE*.45
	arrow.material_override=bronze;arrow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(arrow)
	process_priority=101
func _process(delta: float) -> void:
	if not is_instance_valid(field):
		elapsed+=maxf(0,delta);stone_material.set_shader_parameter('visual_time',elapsed);return
	if not field.presentation_visible or field.presentation_suspended:return
	if not is_instance_valid(field.game) or field.size.y<1 or not is_instance_valid(field.camera):return
	visible=field.game.combat_effects_enabled
	var radius: float=120.0*field.camera.size/field.size.y
	var plane: PlaneMesh=surface.mesh;plane.size=Vector2(radius*2.22,radius*2.22/absf(field.camera.global_basis.z.y))
	var center: Vector2=Vector2.ZERO;var alive: Array=field.game._alive_hero_ids()
	for id in alive:
		var point: Vector2=field.game._hero_field_position(id)
		var index: int=field.game._deployed_hero_ids().find(id)
		if index>=0 and index<field.game.hero_map_sprites.size():point=field.display_world(field.game.hero_map_sprites[index],point)
		center+=point
	center=center/maxi(1,alive.size()) if not alive.is_empty() else field.game.expedition_position
	surface.position=Vector3(center.x,.026,center.y)
	var direction: Vector2=(field.game.expedition_target-center).normalized()
	arrow.position=Vector3(center.x+direction.x*radius,.06+sin(elapsed*TAU/2)*.025,center.y+direction.y*radius)
	arrow.rotation.y=-direction.angle()
	if field.visual_running():
		elapsed+=maxf(0,delta)*field.visual_speed()
		stone_material.set_shader_parameter('visual_time',elapsed)
