extends Node3D
## Genuine separate shell draws around painted fur/hair, not a UV stripe shader.
## All layers use the same complete pose, foot anchor and frozen battle clock.
const SHADER=preload('res://shaders/PaintedFurShell.gdshader')
const FUR_IDS=['wild_dog','bristle_boar','moon_wolf','iron_mole','frost_deer','bron','garm','fenris','ragna','ulric','rokan','bora']
var layers: Array[MeshInstance3D]=[]
var _key:=Vector4.ZERO
var _texture: Texture2D
var _pose_meshes: Dictionary={}
var _visible_count:=-1
var _visual_time:=-INF
func configure(hero: bool,id: String) -> void:
	visible=hero or id in FUR_IDS or FileAccess.file_exists('res://assets/mobile25d/'+id+'/frames.json')
	if not visible:return
	for i in 4:
		var layer:=MeshInstance3D.new();layer.name='FurShell'+str(i)
		layer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=SHADER
		material.set_shader_parameter('shell_layer',float(i+1)/4.0)
		material.set_shader_parameter('hair_only',hero and id not in FUR_IDS)
		layer.material_override=material;add_child(layer);layers.append(layer)
func present(sheet: Dictionary,frame: int,texture: Texture2D,time: float,count: int) -> void:
	if layers.is_empty():return
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
		var mesh: ArrayMesh=cache[key]
		for layer in layers:
			layer.mesh=mesh;layer.material_override.set_shader_parameter('source_texture',texture)
			layer.material_override.set_shader_parameter('atlas_texel',Vector2.ONE/atlas_size)
			layer.material_override.set_shader_parameter('atlas_rect',Vector4(r[0]/atlas_size.x,r[1]/atlas_size.y,r[2]/atlas_size.x,r[3]/atlas_size.y))
	if count!=_visible_count:
		_visible_count=count
		for i in layers.size():layers[i].visible=i<count
	if time!=_visual_time:
		_visual_time=time
		for layer in layers:layer.material_override.set_shader_parameter('visual_time',time)
