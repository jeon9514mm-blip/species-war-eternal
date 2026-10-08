extends Node3D
## Six native shell instances share one surface, material and draw per creature.
## INSTANCE_CUSTOM.r selects shell depth; UV, foot anchor and clock stay shared.
const SHADER=preload('res://shaders/PaintedFurShell.gdshader')
const FUR_IDS=['wild_dog','bristle_boar','moon_wolf','iron_mole','frost_deer','bron','garm','fenris','ragna','ulric','rokan','bora']
const MAX_LAYERS:=6
var instance: MultiMeshInstance3D
var multimesh: MultiMesh
var material: ShaderMaterial
var _key:=Vector4.ZERO
var _texture: Texture2D
var _pose_meshes: Dictionary={}
var _visible_count:=-1
var _visual_time:=-INF
var detail_lod:=0
var effects_enabled:=true
func configure(hero: bool,id: String) -> void:
	visible=not hero and (id in FUR_IDS or FileAccess.file_exists('res://assets/mobile25d/'+id+'/frames.json'))
	if not visible:return
	if is_instance_valid(instance):return
	multimesh=MultiMesh.new();multimesh.mesh=QuadMesh.new()
	# Native MultiMesh AABB updates require a valid mesh even for a hidden pool.
	# Replace this allocation surface with the first real pose before showing it.
	multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_custom_data=true;multimesh.instance_count=MAX_LAYERS;multimesh.visible_instance_count=0
	for i in MAX_LAYERS:
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,0,float(i)*.001)))
		multimesh.set_instance_custom_data(i,Color(float(i+1)/float(MAX_LAYERS),0,0,1))
	material=ShaderMaterial.new();material.shader=SHADER;material.set_shader_parameter('hair_only',false)
	instance=MultiMeshInstance3D.new();instance.name='FurShellBatch';instance.multimesh=multimesh;instance.material_override=material;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;instance.visible=false;add_child(instance)
	_visible_count=0
func disable() -> void:
	if is_instance_valid(instance):
		instance.hide();instance.multimesh=null;instance.free()
	instance=null;multimesh=null;material=null;_visible_count=0;_pose_meshes.clear();hide()
func visible_count() -> int:return multimesh.visible_instance_count if multimesh!=null else 0
func instance_shell(index: int) -> float:return multimesh.get_instance_custom_data(index).r if multimesh!=null and index>=0 and index<MAX_LAYERS else 0.0
func present(sheet: Dictionary,frame: int,texture: Texture2D,time: float,count: int) -> void:
	if not is_instance_valid(instance):return
	count=0 if not effects_enabled or detail_lod>=3 else (mini(count,3) if detail_lod>=1 else mini(count,MAX_LAYERS))
	count=maxi(0,count)
	var pose: Dictionary=sheet.frames[frame]
	# Mobile attack and locomotion share a texture, but occupy different cells.
	var r: Array=pose.region
	var key:=Vector4(r[0],r[1],r[2],r[3])
	if key!=_key or texture!=_texture:
		_key=key;_texture=texture
		var texture_id:=texture.get_instance_id()
		if not _pose_meshes.has(texture_id):_pose_meshes[texture_id]={}
		var cache: Dictionary=_pose_meshes[texture_id]
		var atlas_size:=texture.get_size()
		# Construct UV/vertex buffers only once, including after a pose repeats.
		if not cache.has(key):
			var a: Array=pose.anchor
			var margin:=6.0;var vertices:=PackedVector3Array();var uvs:=PackedVector2Array()
			for pixel in [Vector2(-margin,-margin),Vector2(r[2]+margin,-margin),Vector2(r[2]+margin,r[3]+margin),Vector2(-margin,r[3]+margin)]:
				vertices.append(Vector3(pixel.x-a[0],a[1]-pixel.y,.02));uvs.append((Vector2(r[0],r[1])+pixel)/atlas_size)
			var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
			var pose_mesh:=ArrayMesh.new();pose_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);cache[key]=pose_mesh
		multimesh.mesh=cache[key]
		var anchor: Array=pose.anchor
		instance.custom_aabb=AABB(Vector3(-anchor[0]-6,anchor[1]-r[3]-6,-.10),Vector3(r[2]+12,r[3]+12,.30))
		material.set_shader_parameter('source_texture',texture)
		material.set_shader_parameter('atlas_texel',Vector2.ONE/atlas_size)
		material.set_shader_parameter('atlas_rect',Vector4(r[0]/atlas_size.x,r[1]/atlas_size.y,r[2]/atlas_size.x,r[3]/atlas_size.y))
	if count!=_visible_count:
		_visible_count=count
		multimesh.visible_instance_count=count;instance.visible=count>0
	if detail_lod<2 and time!=_visual_time:
		_visual_time=time
		material.set_shader_parameter('visual_time',time)
