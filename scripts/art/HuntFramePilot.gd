extends MeshInstance3D
## One undistorted full-body frame, switched on the actual battle's action clock.
## The mesh only clips adjacent atlas paint. It has no joints, weights or skin.
const CATALOG=preload('res://scripts/art/HuntFrameCatalog.gd')
const TIMELINE=preload('res://scripts/art/HuntFrameTimeline.gd')
const PAINT=preload('res://shaders/OriginalPainting.gdshader')
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
var _existing := false
var _hero := false
var _footprint := Rect2()
var _visual_time:=0.0
var _movement_heat:=0.0
var fur_layers:=4
var _fur: Node3D

func bind(actor: AnimatedSprite2D,hero: bool,catalog: RefCounted=null) -> bool:
	_catalog=catalog if catalog!=null else CATALOG.new()
	entry=_catalog.load_entry(CATALOG.identity(actor,hero))
	_hero=hero
	if entry.is_empty():
		entry=_existing_entry(actor,hero);_existing=true
	if entry.is_empty():return false
	if hero and not _existing and not bool(entry.get('authored_full_body',false)):
		entry=entry.duplicate(true)
		for kind in ['attack','motion']:entry[kind].native_height=float(entry[kind].frames[0].region[3])
	source=actor;name='HuntFramePilot';cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material=ShaderMaterial.new();_material.shader=PAINT
	_material.set_shader_parameter('outline_px',.35);_material.set_shader_parameter('rim_strength',.04)
	_material.set_shader_parameter('alpha_cutoff',.12);material_override=_material
	for kind in entry.sheets if _existing else ['attack','motion']:
		var sheet: Dictionary=entry[kind]
		_textures[kind]=sheet.texture if _existing else load(str(sheet.atlas))
		var meshes: Array[ArrayMesh]=[]
		for frame: Dictionary in sheet.frames:meshes.append(_make_frame(frame,_textures[kind].get_size()))
		_meshes[kind]=meshes
	_footprint=_measure_footprint(1.0)
	_fur=preload('res://scripts/art/PaintedFurLayers.gd').new();add_child(_fur);_fur.configure(hero,str(entry.id))
	return true

func present(camera: Camera3D,height: float,tint: Color,delta: float,active: bool,point: Vector2,runtime: Dictionary,dead: bool) -> void:
	var running:=active and source.speed_scale>0.0
	if running:
		_visual_time+=maxf(0,delta)*source.speed_scale
		_movement_heat=move_toward(_movement_heat,1.0 if _hero and source.state=='walk' and not dead else 0.0,maxf(0,delta)*.5)
	_material.set_shader_parameter('visual_time',_visual_time)
	_material.set_shader_parameter('movement_heat',_movement_heat)
	if _has_point and running and _was_active:
		var travelled:=point.distance_to(_last_point)
		if travelled<1.0:_distance+=travelled
	_last_point=point;_has_point=true;_was_active=running
	var pose:=timeline.sample(runtime,source.state=='walk',dead,delta*source.speed_scale,running)
	var action:=str(pose.action)
	var kind:='motion'
	var frame:=0
	if _existing:
		kind=action if entry.has(action) else 'idle'
		var count: int=entry[kind].frames.size()
		if action in ['walk','run']:
			frame=int(floor(_distance/float(entry.stride_distance)*count))%count
		elif action in ['attack_1','attack_2','skill','ultimate']:
			var phase:=clampf(float(pose.time)/float(pose.duration),0,1)
			# The central painted strike begins on the actual damage/release event.
			var middle:=int(count/2.0)
			frame=mini(middle-1,int(phase/.44*middle)) if phase<.44 and middle>0 else mini(count-1,middle+int((phase-.44)/.56*(count-middle)))
		elif action in ['hit','death']:
			frame=mini(count-1,int(float(pose.time)/float(pose.duration)*count))
		else:
			# Keep the packaged guard/buff/spawn/victory tracks where provided.
			var observed: String=str(source.get('visual_action')) if _hero and source.has_method('play_visual') else action
			if action=='idle' and entry.has(observed) and observed not in ['attack_1','attack_2','skill','ultimate','hit','death','walk','run']:
				kind=observed;count=entry[kind].frames.size()
			frame=int(floor(float(pose.time)*float(entry[kind].fps)))%count
	elif action in ['attack_1','attack_2','skill','ultimate']:
		kind='attack';frame=CATALOG.attack_frame(float(pose.time)/float(pose.duration))
	elif action in ['walk','run']:
		frame=2+int(floor(_distance/float(entry.get('stride_distance',1.4))*4.0))%4
	elif action=='hit':frame=6
	elif action=='death':frame=7
	elif action=='guard':frame=0
	else:frame=int(floor(float(pose.time)*1.8))%2
	_apply_frame(camera,height,tint,kind,frame)
	_fur.present(entry[kind],frame,_textures[kind],_visual_time,fur_layers if action!='death' else 0)
	position=Vector3.ZERO
	var hit_age:=float(pose.get('hit_age',-1.0))
	if action!='death' and hit_age>=0.0 and hit_age<.22:
		var amount:=(1.0-smoothstep(.025,.22,hit_age))*smoothstep(0.0,.025,hit_age+.012)
		var direction: Vector2=pose.get('recoil',Vector2.ZERO)
		# Tiny directional reaction of the complete drawing; never move the
		# simulation body, stretch a limb, or rotate an unattached head.
		position=camera.global_basis.x*direction.x*amount*.015
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

func _existing_entry(actor: AnimatedSprite2D,hero: bool) -> Dictionary:
	if actor.sprite_frames==null:return {}
	var identity: String=CATALOG.identity(actor,hero)
	var result: Dictionary={'id':identity if not identity.is_empty() else (str(actor.atlas_key) if hero else str(actor.pixel_monster_name)),'sheets':[],'stride_distance':1.4,'asset_scope':'existing_complete_frames'}
	var images: Dictionary={}
	for action in ['idle','walk','run','attack_1','attack_2','skill','ultimate','hit','death','guard','buff','debuff','victory','spawn','dodge','knockback']:
		var legacy: String='attack' if action in ['attack_1','attack_2','skill','ultimate'] else ('walk' if action=='run' else action)
		var track: String=action if actor.sprite_frames.has_animation(action) else legacy+'_down'
		if not actor.sprite_frames.has_animation(track):continue
		var sheet: Dictionary={'frames':[],'native_height':maxf(1,actor.native_visual_height),'fps':actor.sprite_frames.get_animation_speed(track)}
		for index in actor.sprite_frames.get_frame_count(track):
			var texture:=actor.sprite_frames.get_frame_texture(track,index)
			var atlas:=texture as AtlasTexture
			var region:=atlas.region if atlas!=null else Rect2(Vector2.ZERO,texture.get_size())
			var base: Texture2D=atlas.atlas if atlas!=null else texture
			var anchor: Vector2=-actor.offset-(atlas.margin.position if atlas!=null else Vector2.ZERO)
			if actor.centered:anchor+=texture.get_size()*.5
			# Legacy cells include large transparent canvases (especially Valeria).
			# Read alpha bounds without modifying any source pixels. Keep the foot
			# pivot in the same canvas position after trimming the UV rectangle.
			var key:=base.get_instance_id()
			if not images.has(key):
				var image:=base.get_image()
				if image!=null and image.is_compressed():image.decompress()
				images[key]=image
			var image: Image=images[key]
			if image!=null:
				var outer:=Rect2i(Vector2i(region.position.floor()),Vector2i(region.end.ceil()-region.position.floor()))
				outer=outer.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
				var used:=image.get_region(outer).get_used_rect()
				if used.has_area():
					var trimmed:=Rect2(Vector2(outer.position+used.position),Vector2(used.size))
					anchor-=trimmed.position-region.position;region=trimmed
			sheet.texture=base;sheet.atlas=base.resource_path;sheet.atlas_size=[base.get_width(),base.get_height()]
			sheet.frames.append({'region':[region.position.x,region.position.y,region.size.x,region.size.y],'anchor':[anchor.x,anchor.y],'silhouette_uv':[[0,0],[1,0],[1,1],[0,1]]})
		result[action]=sheet;result.sheets.append(action)
	if not result.has('idle'):return {}
	if hero:
		# Packaged atlases were exported at different nominal heights (64/128px).
		# Normalize the complete standing painting, not its export canvas/margins.
		var standing_height: float=result.idle.frames[0].region[3]
		for action in result.sheets:result[action].native_height=maxf(1,standing_height)
	return result

func footprint(height: float) -> Rect2:
	return Rect2(_footprint.position*height,_footprint.size*height)

func _measure_footprint(height: float) -> Rect2:
	# Reserve locomotion bodies. Attack weapons deliberately enter the target's
	# space at contact; their maximum swing must not shrink the entire party.
	var bounds:=Rect2()
	for kind in entry.sheets if _existing else ['attack','motion']:
		if kind not in ['idle','walk','run','motion']:continue
		var sheet: Dictionary=entry[kind]
		for index in sheet.frames.size():
			if not _existing and kind=='motion' and index>=6:continue
			var item: Dictionary=sheet.frames[index]
			var region: Array=item.region;var anchor: Array=item.anchor
			var scale:=height/float(sheet.native_height)
			var rect:=Rect2(Vector2(-anchor[0],-anchor[1])*scale,Vector2(region[2],region[3])*scale)
			bounds=rect if not bounds.has_area() else bounds.merge(rect)
	return bounds
