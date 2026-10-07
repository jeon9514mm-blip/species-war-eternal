extends Node3D
## Genuine separate shell draws around painted fur/hair, not a UV stripe shader.
## All layers use the same complete pose, foot anchor and frozen battle clock.
const SHADER=preload('res://shaders/PaintedFurShell.gdshader')
const FUR_IDS=['wild_dog','bristle_boar','moon_wolf','iron_mole','frost_deer','bron','garm','fenris','ragna','ulric','rokan','bora']
var layers: Array[MeshInstance3D]=[]
var _key:=''
func configure(hero: bool,id: String) -> void:
	visible=hero or id in FUR_IDS
	if not visible:return
	for i in 8:
		var layer:=MeshInstance3D.new();layer.name='FurShell'+str(i)
		layer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=SHADER
		material.set_shader_parameter('shell_layer',float(i+1)/8.0)
		material.set_shader_parameter('hair_only',hero and id not in FUR_IDS)
		layer.material_override=material;add_child(layer);layers.append(layer)
func present(sheet: Dictionary,frame: int,texture: Texture2D,time: float,count: int) -> void:
	if layers.is_empty():return
	var key:=str(sheet.atlas)+':'+str(frame)
	if key!=_key:
		_key=key;var pose: Dictionary=sheet.frames[frame];var r: Array=pose.region;var a: Array=pose.anchor
		var margin:=6.0;var vertices:=PackedVector3Array();var uvs:=PackedVector2Array()
		for pixel in [Vector2(-margin,-margin),Vector2(r[2]+margin,-margin),Vector2(r[2]+margin,r[3]+margin),Vector2(-margin,r[3]+margin)]:
			vertices.append(Vector3(pixel.x-a[0],a[1]-pixel.y,.02));uvs.append((Vector2(r[0],r[1])+pixel)/texture.get_size())
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		for layer in layers:
			layer.mesh=mesh;layer.material_override.set_shader_parameter('source_texture',texture)
			layer.material_override.set_shader_parameter('atlas_texel',Vector2.ONE/texture.get_size())
			layer.material_override.set_shader_parameter('atlas_rect',Vector4(r[0]/float(texture.get_width()),r[1]/float(texture.get_height()),r[2]/float(texture.get_width()),r[3]/float(texture.get_height())))
	for i in layers.size():
		layers[i].visible=i<count
		layers[i].material_override.set_shader_parameter('visual_time',time)
