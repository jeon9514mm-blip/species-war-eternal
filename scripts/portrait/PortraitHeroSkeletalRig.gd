extends Node2D
## One rest painting, articulated with the same weighted skeleton in 2D and 3D.
## Animation controllers retain their timing/events; this node never changes combat state.
const MOTIONS=preload('res://scripts/portrait/HeroRigMotionCatalog.gd')
const ORIGINAL_ART=preload('res://scripts/sd/SDHeroVisuals.gd')
const GRID_X:=24
const GRID_Y:=28
const BONE_COUNT:=21
const HIDE_SOURCE:="shader_type canvas_item; void fragment() { COLOR.a = 0.0; }"
static var transparent_material: ShaderMaterial
var actor: HeroSpriteController
var skeleton: Skeleton2D
var mesh: Polygon2D
var bones: Dictionary={}
var bone_names: Array[String]=[]
var rest_globals: Array[Transform2D]=[]
var parents: PackedInt32Array=[]
var weights: Array[Dictionary]=[]
var pivot:=Vector2.ZERO
var body_height:=64.0
var art_scale:=1.0
var phase:=0.0
var action_time:=0.0
var prior_state:=''
var profile: Dictionary
var rest_frame: AtlasTexture
var rest_points:=PackedVector2Array()
var pose: Dictionary={}
var previous_pose: Dictionary={}
var sequence:=-1
var transition_time:=0.0
var rendered_in_3d:=false
var skin_mesh: ArrayMesh

func install(hero: HeroSpriteController) -> bool:
	if hero==null or not hero._frames_ready or hero.sprite_frames==null:return false
	if hero.get_node_or_null('PortraitHeroSkeletalRig')!=null:return false
	rest_frame=_source_frame(hero)
	if rest_frame==null or rest_frame.atlas==null:return false
	actor=hero;name='PortraitHeroSkeletalRig';process_priority=50
	pivot=-hero.offset;body_height=maxf(32.0,hero.native_visual_height)
	if _has_original_art(hero):
		pivot=Vector2(128,248)
		art_scale=body_height/ORIGINAL_ART.native_height(hero.atlas_key)
	profile=MOTIONS.profile(hero.atlas_key)
	hero.add_child(self)
	_build_bones();_build_mesh(rest_frame)
	if transparent_material==null:
		var shader:=Shader.new();shader.code=HIDE_SOURCE
		transparent_material=ShaderMaterial.new();transparent_material.shader=shader
	hero.material=transparent_material
	apply_pose(MOTIONS.sample(profile,'idle',0,1))
	return true

func _has_original_art(hero: HeroSpriteController) -> bool:
	return hero.atlas_key not in ['leonhardt','valeria'] and ResourceLoader.exists('res://assets/heroes/sd-v36/sheets/'+hero.atlas_key+'-pose.png')

func _source_frame(hero: HeroSpriteController) -> AtlasTexture:
	# Use the full-resolution source painting instead of its 64px baked action copy.
	if _has_original_art(hero):
		var source:=AtlasTexture.new()
		source.atlas=load('res://assets/heroes/sd-v36/sheets/'+hero.atlas_key+'-pose.png')
		source.region=Rect2(Vector2.ZERO,source.atlas.get_size());source.filter_clip=true
		return source
	# Fixed bind artwork prevents frame-margin jumps and double animation.
	for track in ['idle','idle_down']:
		if hero.sprite_frames.has_animation(track):return hero.sprite_frames.get_frame_texture(track,0) as AtlasTexture
	return null

func _bone(parent: Node2D, key: String, point: Vector2, length: float) -> Bone2D:
	var node:=Bone2D.new();node.name=key
	node.position=point;node.set_autocalculate_length_and_angle(false);node.length=length
	parent.add_child(node);node.rest=node.transform
	var parent_index:=bone_names.find(str(parent.name))
	parents.append(parent_index);bone_names.append(key);bones[key]=node
	rest_globals.append((rest_globals[parent_index] if parent_index>=0 else Transform2D.IDENTITY)*node.rest)
	return node

func _build_bones() -> void:
	skeleton=Skeleton2D.new();skeleton.name='Skeleton2D';add_child(skeleton)
	var h:=body_height
	var root_bone:=_bone(skeleton,'Root',Vector2.ZERO,h*.1)
	var pelvis:=_bone(root_bone,'Pelvis',Vector2(0,-h*.22),h*.18)
	var torso:=_bone(pelvis,'Torso',Vector2(0,-h*.15),h*.13)
	var chest:=_bone(torso,'Chest',Vector2(0,-h*.13),h*.12)
	# Pivot at the collar rather than inside the painted face. Keep the same 21-joint skin.
	var head:=_bone(chest,'Head',Vector2(0,h*(profile.head+.11+.50)),h*.23)
	_bone(head,'Hair',Vector2(0,-h*.19),h*.12)
	_bone(chest,'Cape',Vector2(-h*.07,h*.05),h*.36)
	for side in [-1,1]:
		var key: String='Left' if side<0 else 'Right'
		var arm:=_bone(chest,key+'UpperArm',Vector2(side*h*profile.shoulder,0),h*.15)
		var fore:=_bone(arm,key+'Forearm',Vector2(side*h*.065,h*.115),h*.13)
		_bone(fore,key+'Hand',Vector2(side*h*.05,h*.10),h*.06)
		var thigh:=_bone(pelvis,key+'Thigh',Vector2(side*h*.105,0),h*.12)
		var shin:=_bone(thigh,key+'Shin',Vector2(side*h*.025,h*.10),h*.11)
		_bone(shin,key+'Foot',Vector2(side*h*.02,h*.10),h*.07)
	var lead: String='Right' if profile.side>0 else 'Left'
	var off: String='Left' if profile.side>0 else 'Right'
	_bone(bones[lead+'Hand'],'Weapon',Vector2.ZERO,h*.33)
	_bone(bones[off+'Hand'],'Offhand',Vector2.ZERO,h*.18)

func _influence(point: Vector2) -> Dictionary:
	var p:=point/body_height
	var raw: Dictionary={}
	var key: String='Left' if p.x<0 else 'Right'
	var lateral:=absf(p.x)
	var weapon_side: bool=p.x*float(profile.side)>0
	var outer:=smoothstep(.28,.43,lateral)
	# Head/face stays almost rigid. Only the hair tips receive secondary sway.
	var head:=smoothstep(.52,.66,-p.y)
	var hair:=smoothstep(.82,1.0,-p.y)*.42
	var leg:=smoothstep(-.31,-.20,p.y)
	var arm:=smoothstep(.12,.27,lateral)*(1.0-head)*(1.0-leg)
	var weapon: float=outer if weapon_side else outer*.60
	# Staff/bow upper tips attach to the hand, never to the hair.
	if p.y<-.62 and lateral<.33:weapon=0.0
	if weapon_side and str(profile.family) in ['staff','heal']:
		# A diagonal staff is rigid from the grip through the ornament. A horizontal
		# head/arm split would kink its shaft where it passes beside the face.
		var shaft_x:=.085+(-p.y-.245)*.53
		var shaft:=smoothstep(shaft_x-.035,shaft_x+.025,p.x*float(profile.side))*smoothstep(.25,.42,-p.y)
		weapon=maxf(weapon,shaft)
		var tip: Vector3=profile.weapon_tip
		if tip.z>0:
			var ornament: float=p.distance_to(Vector2(tip.x*float(profile.side),tip.y))/tip.z
			weapon=maxf(weapon,1.0-smoothstep(.90,1.22,ornament))
	if p.y>-.15:weapon*=.55
	var remain:=1.0-weapon
	raw['Weapon' if weapon_side else 'Offhand']=weapon
	raw['Head']=remain*head*(1.0-hair)
	raw['Hair']=remain*head*hair
	var body: float=remain*(1.0-head)
	var knee:=smoothstep(-.19,-.075,p.y)
	var foot:=smoothstep(-.06,.025,p.y)
	var cloth: float=body*leg*(1.0-knee)*smoothstep(.18,.32,lateral)*.28*profile.cloth
	raw['Cape']=cloth
	raw[key+'Thigh']=body*leg*(1.0-knee)-cloth
	raw[key+'Shin']=body*leg*knee*(1.0-foot)
	raw[key+'Foot']=body*leg*knee*foot
	var elbow:=smoothstep(-.46,-.30,p.y)
	raw[key+'UpperArm']=remain*arm*(1.0-elbow)
	raw[key+'Forearm']=remain*arm*elbow*.82
	raw[key+'Hand']=remain*arm*elbow*.18
	var center: float=body*(1.0-leg)*(1.0-smoothstep(.12,.27,lateral))
	var chest:=smoothstep(.30,.50,-p.y)
	raw['Chest']=center*chest
	raw['Torso']=center*(1.0-chest)*.75
	raw['Pelvis']=center*(1.0-chest)*.25
	# Four normalized influences, identical to the GPU skinning limit in both renderers.
	var sorted: Array=raw.keys();sorted.sort_custom(func(a,b):return raw[a]>raw[b])
	var result: Dictionary={};var total:=0.0
	for i in mini(4,sorted.size()):
		if float(raw[sorted[i]])>.00001:result[sorted[i]]=raw[sorted[i]];total+=float(raw[sorted[i]])
	if total<=.00001:return {'Pelvis':1.0}
	for name_key in result:result[name_key]/=total
	return result

func _build_mesh(source: AtlasTexture) -> void:
	mesh=Polygon2D.new();mesh.name='SkinnedHeroMesh';mesh.z_index=1;add_child(mesh)
	mesh.skeleton=mesh.get_path_to(skeleton);mesh.texture=source.atlas
	var faces: Array[PackedInt32Array]=[]
	var uv:=PackedVector2Array()
	var local_start: Vector2=(source.margin.position-pivot)*art_scale
	var per_bone: Dictionary={}
	for key in bones:per_bone[key]=PackedFloat32Array()
	for row in GRID_Y+1:
		for column in GRID_X+1:
			var fraction:=Vector2(float(column)/GRID_X,float(row)/GRID_Y)
			var point:=local_start+fraction*source.region.size*art_scale
			rest_points.append(point);uv.append(source.region.position+fraction*source.region.size)
			var influence:=_influence(point);weights.append(influence)
			for key in bones:per_bone[key].append(float(influence.get(key,0)))
	for row in GRID_Y:
		for column in GRID_X:
			var a:=row*(GRID_X+1)+column
			faces.append(PackedInt32Array([a,a+1,a+GRID_X+2,a+GRID_X+1]))
	mesh.polygon=rest_points;mesh.polygons=faces;mesh.uv=uv
	for key in bones:mesh.add_bone(mesh.get_path_to(bones[key]),per_bone[key])

func action_duration(action: String) -> float:
	if action in ['attack_1','attack_2','skill','ultimate']:return actor.visual_attack_duration
	if not actor.sprite_frames.has_animation(action):return .6
	var duration:=0.0
	for i in actor.sprite_frames.get_frame_count(action):duration+=actor.sprite_frames.get_frame_duration(action,i)
	return duration/maxf(.001,actor.sprite_frames.get_animation_speed(action))

func apply_pose(value: Dictionary) -> void:
	pose=value.duplicate()
	# Connected artwork cannot tolerate extreme independent neck/wrist twists.
	pose['Head']=clampf(float(pose.get('Head',0)),-.075,.075)
	for key in ['LeftHand','RightHand']:
		pose[key]=clampf(float(pose.get(key,0)),-.065,.065)
	for key in ['Weapon','Offhand']:
		pose[key]=clampf(float(pose.get(key,0)),-.028,.028)
	for key in bones:
		var bone: Bone2D=bones[key]
		bone.transform=bone.rest
		bone.rotation=float(pose.get(key,0.0))
	bones['Root'].position+=Vector2(float(pose.get('root_x',0)),float(pose.get('root_y',0)))*body_height
	# Mirror skeleton AND painted mesh together around the foot pivot.
	scale.x=-1.0 if actor.flip_h else 1.0
	mesh.modulate=Color(actor.self_modulate.r,actor.self_modulate.g,actor.self_modulate.b,1.0)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.speed_scale<=0:return
	var action: String=str(actor.get('visual_action')) if actor.has_method('play_visual') else actor.state
	if action=='attack':action='attack_1'
	var current_sequence: int=actor.visual_sequence
	var dt:=maxf(0,delta)*actor.speed_scale
	if action!=prior_state or current_sequence!=sequence:
		previous_pose=pose.duplicate();transition_time=0;action_time=0
		prior_state=action;sequence=current_sequence
	action_time+=dt;phase+=dt;transition_time+=dt
	var next:=MOTIONS.sample(profile,action,action_time,action_duration(action))
	# Quick reactions, longer recovery: limbs settle without snapping to idle.
	var blend_seconds:=.04 if action in ['hit','knockback','dodge'] else (.14 if action=='idle' else .075)
	var blend:=smoothstep(0,blend_seconds,transition_time)
	if blend<1:
		for key in previous_pose:
			if not next.has(key):next[key]=0.0
		for key in next:next[key]=lerpf(float(previous_pose.get(key,0)),float(next[key]),blend)
	apply_pose(next)

func deformed_points() -> PackedVector2Array:
	# Diagnostic CPU reference for the exact GPU bind weights, also used by tests.
	var transforms: Array[Transform2D]=[]
	for i in bone_names.size():
		var local: Transform2D=bones[bone_names[i]].transform
		transforms.append((transforms[parents[i]] if parents[i]>=0 else Transform2D.IDENTITY)*local)
	var result:=PackedVector2Array()
	for i in rest_points.size():
		var point:=Vector2.ZERO
		for key in weights[i]:
			var index:=bone_names.find(key)
			point+=(transforms[index]*rest_globals[index].affine_inverse()*rest_points[i])*float(weights[i][key])
		result.append(point)
	return result

static func transform_3d(value: Transform2D) -> Transform3D:
	return Transform3D(Basis(Vector3.BACK,-value.get_rotation()),Vector3(value.origin.x,-value.origin.y,0))

func make_3d_mesh() -> ArrayMesh:
	if skin_mesh!=null:return skin_mesh
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array()
	var bone_indices:=PackedInt32Array();var bone_weights:=PackedFloat32Array();var indices:=PackedInt32Array()
	for i in rest_points.size():
		vertices.append(Vector3(rest_points[i].x,-rest_points[i].y,0));normals.append(Vector3.BACK)
		uv.append(mesh.uv[i]/rest_frame.atlas.get_size())
		var keys: Array=weights[i].keys()
		for j in 4:
			bone_indices.append(bone_names.find(keys[j]) if j<keys.size() else 0)
			bone_weights.append(float(weights[i][keys[j]]) if j<keys.size() else 0.0)
	for row in GRID_Y:
		for column in GRID_X:
			var a:=row*(GRID_X+1)+column;var b:=a+GRID_X+1
			indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_BONES]=bone_indices;arrays[Mesh.ARRAY_WEIGHTS]=bone_weights;arrays[Mesh.ARRAY_INDEX]=indices
	skin_mesh=ArrayMesh.new();skin_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return skin_mesh
