extends MeshInstance3D
## One undistorted full-body frame, switched on the actual battle's action clock.
## The mesh only clips adjacent atlas paint. It has no joints, weights or skin.
const CATALOG=preload('res://scripts/art/HuntFrameCatalog.gd')
const TIMELINE=preload('res://scripts/art/HuntFrameTimeline.gd')
const PAINT=preload('res://assets/art-direction/pilot-01/shaders/hero-contour.gdshader')
var source: AnimatedSprite2D
var timeline:=TIMELINE.new()
var entry: Dictionary={}
var _meshes: Dictionary={}
var _textures: Dictionary={}
var _material: ShaderMaterial
var _last_point:=Vector2.ZERO
var _has_point:=false
var _distance:=0.0
var _was_active:=false
var _kind:=''
var _frame:=-1
var _snapshot: Dictionary={}
var _catalog: RefCounted

func bind(actor: AnimatedSprite2D,hero: bool,catalog: RefCounted=null) -> bool:
	_catalog=catalog if catalog!=null else CATALOG.new()
	entry=_catalog.load_entry(CATALOG.identity(actor,hero))
	if entry.is_empty():return false
	source=actor;name='HuntFramePilot';cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material=ShaderMaterial.new();_material.shader=PAINT
	_material.set_shader_parameter('outline_px',.35);_material.set_shader_parameter('rim_strength',.04)
	_material.set_shader_parameter('alpha_cutoff',.12);material_override=_material
	for kind in ['attack','motion']:
		var sheet: Dictionary=entry[kind]
		_textures[kind]=load(str(sheet.atlas))
		var meshes: Array[ArrayMesh]=[]
		for frame: Dictionary in sheet.frames:meshes.append(_make_frame(frame,_textures[kind].get_size()))
		_meshes[kind]=meshes
	return true

func present(camera: Camera3D,height: float,tint: Color,delta: float,active: bool,point: Vector2,runtime: Dictionary,dead: bool) -> void:
	var running:=active and source.speed_scale>0.0
	if _has_point and running and _was_active:
		var travelled:=point.distance_to(_last_point)
		if travelled<1.0:_distance+=travelled
	_last_point=point;_has_point=true;_was_active=running
	var pose:=timeline.sample(runtime,source.state=='walk',dead,delta*source.speed_scale,running)
	var action:=str(pose.action)
	var kind:='motion'
	var frame:=0
	if action in ['attack_1','attack_2']:
		kind='attack';frame=CATALOG.attack_frame(float(pose.time)/float(pose.duration))
	elif action in ['walk','run']:
		frame=2+int(floor(_distance/float(entry.get('stride_distance',1.4))*4.0))%4
	elif action=='hit':frame=6
	elif action=='death':frame=7
	elif action in ['skill','ultimate','guard']:frame=0
	else:frame=int(floor(float(pose.time)*1.8))%2
	_apply_frame(camera,height,tint,kind,frame)
	position=Vector3.ZERO
	var hit_age:=float(pose.get('hit_age',-1.0))
	if action!='death' and hit_age>=0.0 and hit_age<.22:
		var amount:=(1.0-smoothstep(.025,.22,hit_age))*smoothstep(0.0,.025,hit_age+.012)
		var direction: Vector2=pose.get('recoil',Vector2.ZERO)
		# Tiny directional reaction of the complete drawing; never move the
		# simulation body, stretch a limb, or rotate an unattached head.
		position=camera.global_basis.x*direction.x*amount*.045
	_snapshot={'id':str(entry.id),'action':action,'phase':float(pose.time)/float(pose.duration),'time':float(pose.time),'duration':float(pose.duration),'frame':frame,'sheet':kind,'sequence':timeline.sequence,'distance':_distance,'paused':not running,'renderer':'one_complete_painted_pose','bones':0,'body_parts':1,'native_height':float(entry[kind].native_height),'anchor':entry[kind].frames[frame].anchor,'atlas':entry[kind].atlas,'flip':source.flip_h}

func _apply_frame(camera: Camera3D,height: float,tint: Color,kind: String,frame: int) -> void:
	var sheet: Dictionary=entry[kind]
	var mirror:=-1.0 if source.flip_h else 1.0
	var pixel_size:=height/float(sheet.native_height)
	basis=camera.global_basis.scaled_local(Vector3(pixel_size*mirror,pixel_size,pixel_size))
	if kind!=_kind or frame!=_frame:
		mesh=_meshes[kind][frame];_kind=kind;_frame=frame
		var texture: Texture2D=_textures[kind]
		var region: Array=sheet.frames[frame].region
		var atlas_size:=texture.get_size()
		_material.set_shader_parameter('source_texture',texture)
		_material.set_shader_parameter('atlas_rect',Vector4(region[0]/atlas_size.x,region[1]/atlas_size.y,region[2]/atlas_size.x,region[3]/atlas_size.y))
		_material.set_shader_parameter('atlas_texel',Vector2.ONE/atlas_size)
	_material.set_shader_parameter('actor_tint',tint)
	_material.set_shader_parameter('facing_sign',mirror)

func _make_frame(frame: Dictionary,atlas_size: Vector2) -> ArrayMesh:
	var region: Array=frame.region
	var size:=Vector2(region[2],region[3]);var anchor:=Vector2(frame.anchor[0],frame.anchor[1])
	var polygon:=PackedVector2Array();var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array()
	for point: Array in frame.silhouette_uv:
		var pixel:=Vector2(point[0],point[1])*size
		polygon.append(pixel);vertices.append(Vector3(pixel.x-anchor.x,anchor.y-pixel.y,0.0));normals.append(Vector3.BACK)
		uvs.append((Vector2(region[0],region[1])+pixel)/atlas_size)
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=Geometry2D.triangulate_polygon(polygon)
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return result

func debug_snapshot() -> Dictionary:return _snapshot.duplicate(true)
