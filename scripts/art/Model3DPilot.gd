extends Node3D
## True weighted GLB animation, sampled from the battle's presentation clock.
const CATALOG=preload('res://scripts/art/Model3DCatalog.gd')
const TIMELINE=preload('res://scripts/art/HuntFrameTimeline.gd')
var source: AnimatedSprite2D
var entry: Dictionary={}
var timeline:=TIMELINE.new()
var _hero:=false
var _model: Node3D
var _player: AnimationPlayer
var _tracks: Dictionary={}
var _snapshot: Dictionary={}
var _last_point:=Vector2.ZERO
var _has_point:=false
var _distance:=0.0
var _materials: Array[StandardMaterial3D]=[]
var _colors: Array[Color]=[]
var _meshes: Array[MeshInstance3D]=[]
var _paint_materials: Array[ShaderMaterial]=[]
var fur_layers:=0 # Interface compatibility; actual fur is modeled geometry.
var effects_enabled:=true
var cast_shadow: int=GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
	set(value):
		cast_shadow=value
		for mesh in _meshes:mesh.cast_shadow=value
func bind(actor: AnimatedSprite2D,hero: bool,catalog: RefCounted=null) -> bool:
	var library=catalog if catalog!=null else CATALOG.new()
	entry=library.load_entry(CATALOG.identity(actor,hero));_hero=hero
	if entry.is_empty():return false
	var scene=load(str(entry.path)) as PackedScene
	if scene==null:return false
	source=actor;name='Model3DPilot';_model=scene.instantiate();add_child(_model)
	var players=_model.find_children('*','AnimationPlayer',true,false)
	if players.is_empty():return false
	_player=players[0];_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for action in entry.animations:
		for track in _player.get_animation_list():
			if str(track)==action or str(track).ends_with('/'+action) or str(track).ends_with('_'+action):_tracks[action]=track
	if _tracks.size()!=8:return false
	var original_entry=preload('res://scripts/art/HuntFrameCatalog.gd').new().load_entry(str(entry.id))
	var sheet: Dictionary=original_entry.get('motion',{})
	var texture: Texture2D=load(str(sheet.get('atlas',''))) if not sheet.is_empty() else null
	var region: Array=sheet.frames[0].region if texture!=null else []
	var anchor: Array=sheet.frames[0].anchor if texture!=null else []
	for mesh: MeshInstance3D in _model.find_children('*','MeshInstance3D',true,false):
		_meshes.append(mesh)
		var painted_mesh:=ArrayMesh.new()
		for index in mesh.mesh.get_surface_count():
			var original=mesh.get_active_material(index) as StandardMaterial3D
			if original==null:continue
			var material=original.duplicate() as StandardMaterial3D
			material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			_materials.append(material);_colors.append(material.albedo_color)
			var arrays: Array=mesh.mesh.surface_get_arrays(index)
			if texture!=null:
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var uv:=PackedVector2Array();var colors:=PackedColorArray()
				var pixels_per_unit: float=float(sheet.native_height)/float(entry.native_height)
				for vertex_index in vertices.size():
					var vertex: Vector3=vertices[vertex_index]
					uv.append(Vector2(region[0]+anchor[0]+vertex.x*pixels_per_unit,region[1]+anchor[1]-vertex.y*pixels_per_unit)/texture.get_size())
					colors.append(Color(1,1,1,clampf(normals[vertex_index].z/.55,0,1)))
				arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors
			painted_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			if texture!=null:
				var paint:=ShaderMaterial.new();paint.shader=preload('res://shaders/HandPaintedModel3D.gdshader')
				paint.set_shader_parameter('original_paint',texture);paint.set_shader_parameter('base_color',material.albedo_color)
				paint.set_shader_parameter('paint_rect',Vector4(region[0]/float(texture.get_width()),region[1]/float(texture.get_height()),(region[0]+region[2])/float(texture.get_width()),(region[1]+region[3])/float(texture.get_height())))
				painted_mesh.surface_set_material(index,paint);_paint_materials.append(paint)
			else:painted_mesh.surface_set_material(index,material)
		mesh.mesh=painted_mesh
	return true
func present(camera: Camera3D,height: float,tint: Color,delta: float,active: bool,point: Vector2,runtime: Dictionary,dead: bool) -> void:
	var running:=active and source.speed_scale>0
	var movement:=point-_last_point if _has_point else Vector2.ZERO
	if running and movement.length()<1.0:_distance+=movement.length()
	_last_point=point;_has_point=true
	var pose:=timeline.sample(runtime,source.state=='walk',dead,delta*source.speed_scale,running)
	var action:=str(pose.action)
	var phase:=clampf(float(pose.time)/float(pose.duration),0,1)
	var seconds:=float(pose.time)
	var animation: Animation=_player.get_animation(_tracks[action])
	if action=='walk':seconds=fposmod(_distance/1.4,1.0)*animation.length
	elif action=='idle':seconds=fposmod(seconds,animation.length)
	else:seconds=phase*animation.length
	if _player.current_animation!=_tracks[action]:_player.play(_tracks[action])
	_player.seek(seconds,true,true)
	# Orthographic projected height is consistent with the existing UI contract.
	var model_scale:=height/(float(entry.native_height)*maxf(.5,camera.global_basis.y.y))
	scale=Vector3.ONE*model_scale
	var facing: Vector2={'left':Vector2.LEFT,'right':Vector2.RIGHT,'up':Vector2.UP,'down':Vector2.DOWN}.get(source.direction,Vector2.DOWN)
	if source.state=='walk' and movement.length_squared()>.00001:facing=movement.normalized()
	var angle:=atan2(facing.x,facing.y)
	if running:rotation.y=lerp_angle(rotation.y,angle,clampf(delta*12.0,0,1))
	elif _snapshot.is_empty():rotation.y=angle
	var hit_age:=float(pose.get('hit_age',-1.0))
	var flash: float=.55*(1-clampf(hit_age/.06,0,1)) if effects_enabled and hit_age>=0 else 0.0
	for i in _materials.size():_materials[i].albedo_color=(_colors[i]*Color(tint.r,tint.g,tint.b,1)).lerp(Color.WHITE,flash)
	for paint in _paint_materials:paint.set_shader_parameter('actor_tint',tint);paint.set_shader_parameter('hit_flash',flash)
	_snapshot={'id':entry.id,'renderer':'real_skinned_3d','bones':entry.bones,'body_parts':_meshes.size(),'action':action,'phase':phase,'time':pose.time,'sequence':timeline.sequence,'distance':_distance,'paused':not running,'path':entry.path,'native_height':entry.native_height,'display_height':height,'world_height':float(entry.native_height)*model_scale,'animation':str(_tracks[action]),'angle':rotation.y}
func footprint(height: float) -> Rect2:
	# Reserve the locomotion body, not the deliberate weapon swing at contact.
	var width:=height*(.80 if _hero else float(entry.get('body_ratio',1.1)))
	return Rect2(Vector2(-width*.5,-height*1.12),Vector2(width,height*1.22))
func debug_snapshot() -> Dictionary:return _snapshot.duplicate(true)
