extends Node2D
## Full body 2D mesh rig. It deforms each hero's original painted action atlas;
## gameplay still owns movement, health, attack timing and target selection.
const GRID_X := 12
const GRID_Y := 12
const HIDE_SOURCE := "shader_type canvas_item; void fragment() { COLOR.a = 0.0; }"
static var transparent_material: ShaderMaterial
var actor: HeroSpriteController
var skeleton: Skeleton2D
var mesh: Polygon2D
var bones: Dictionary = {}
var pivot := Vector2.ZERO
var body_height := 64.0
var cached_animation := ''
var cached_frame := -1
var phase := 0.0
var action_time := 0.0
var prior_state := ''

func install(hero: HeroSpriteController) -> bool:
	if hero==null or not hero._frames_ready or hero.sprite_frames==null:return false
	var frame_texture: AtlasTexture=_source_frame(hero)
	if frame_texture==null or frame_texture.atlas==null:return false
	actor=hero
	name='PortraitHeroSkeletalRig'
	pivot=-hero.offset
	body_height=maxf(32.0,hero.native_visual_height)
	hero.add_child(self)
	_build_bones()
	_build_mesh(frame_texture)
	if transparent_material==null:
		var shader:=Shader.new();shader.code=HIDE_SOURCE
		transparent_material=ShaderMaterial.new();transparent_material.shader=shader
	# This material affects only the original AnimatedSprite2D. The skinned
	# Polygon2D retains the same atlas artwork and continues to receive tint.
	hero.material=transparent_material
	return true

func _source_frame(hero: HeroSpriteController) -> AtlasTexture:
	if hero.sprite_frames.has_animation(hero.animation) and hero.sprite_frames.get_frame_count(hero.animation)>0:
		return hero.sprite_frames.get_frame_texture(hero.animation,clampi(hero.frame,0,hero.sprite_frames.get_frame_count(hero.animation)-1)) as AtlasTexture
	if hero.sprite_frames.has_animation('idle_down'):
		return hero.sprite_frames.get_frame_texture('idle_down',0) as AtlasTexture
	return null

func _bone(parent: Node2D, name_key: String, local_position: Vector2, length: float) -> Bone2D:
	var node:=Bone2D.new()
	node.name=name_key
	node.position=local_position
	node.set_autocalculate_length_and_angle(false)
	node.length=length
	parent.add_child(node)
	node.rest=node.transform
	bones[name_key]=node
	return node

func _build_bones() -> void:
	skeleton=Skeleton2D.new();skeleton.name='Skeleton2D';add_child(skeleton)
	var h:=body_height
	var pelvis:=_bone(skeleton,'Pelvis',Vector2(0,-h*.21),h*.28)
	var torso:=_bone(pelvis,'Torso',Vector2(0,-h*.29),h*.30)
	_bone(torso,'Head',Vector2(0,-h*.28),h*.20)
	var larm:=_bone(torso,'LeftUpperArm',Vector2(-h*.23,-h*.02),h*.24)
	var rarm:=_bone(torso,'RightUpperArm',Vector2(h*.23,-h*.02),h*.24)
	var lfore:=_bone(larm,'LeftForearm',Vector2(-h*.17,h*.20),h*.22)
	var rfore:=_bone(rarm,'RightForearm',Vector2(h*.17,h*.20),h*.22)
	_bone(lfore,'LeftHand',Vector2(-h*.10,h*.15),h*.14)
	_bone(rfore,'RightHand',Vector2(h*.10,h*.15),h*.14)
	var lthigh:=_bone(pelvis,'LeftThigh',Vector2(-h*.15,h*.02),h*.23)
	var rthigh:=_bone(pelvis,'RightThigh',Vector2(h*.15,h*.02),h*.23)
	_bone(lthigh,'LeftShin',Vector2(0,h*.20),h*.20)
	_bone(rthigh,'RightShin',Vector2(0,h*.20),h*.20)

func _influence(point: Vector2) -> Dictionary:
	var x:=point.x/body_height
	var y:=point.y/body_height
	var raw: Dictionary={'Pelvis':.20,'Torso':.80}
	var head:=clampf((-y-.42)/.24,0.0,1.0)
	raw['Head']=head*5.0
	var arm_y:=clampf((-.08-y)/.42,0.0,1.0)
	for side in [-1,1]:
		var lateral:=clampf((x*float(side)-.15)/.34,0.0,1.0)
		var key: String='Left' if side<0 else 'Right'
		raw[key+'UpperArm']=lateral*arm_y*2.8
		raw[key+'Forearm']=lateral*clampf((y+.53)/.32,0.0,1.0)*2.0
		raw[key+'Hand']=lateral*clampf((x*float(side)-.46)/.24,0.0,1.0)*3.0
		var leg_y:=clampf((y+.28)/.22,0.0,1.0)
		var leg_x:=clampf(.5-x*float(-side)*2.8,0.0,1.0)
		raw[key+'Thigh']=leg_y*leg_x*3.0
		raw[key+'Shin']=clampf((y+.12)/.15,0.0,1.0)*leg_x*4.0
	var total:=0.0
	for weight in raw.values():total+=float(weight)
	for key in raw:raw[key]=float(raw[key])/maxf(total,.001)
	return raw

func _build_mesh(source: AtlasTexture) -> void:
	mesh=Polygon2D.new();mesh.name='SkinnedHeroMesh';mesh.z_index=1;add_child(mesh)
	mesh.skeleton=mesh.get_path_to(skeleton)
	mesh.texture=source.atlas
	var points:=PackedVector2Array()
	var faces: Array[PackedInt32Array]=[]
	var local_start: Vector2=source.margin.position-pivot
	var frame_size: Vector2=source.region.size
	var weights: Dictionary={}
	for key in bones:weights[key]=PackedFloat32Array()
	for row in GRID_Y+1:
		for column in GRID_X+1:
			var fraction:=Vector2(float(column)/GRID_X,float(row)/GRID_Y)
			var point:=local_start+fraction*frame_size
			points.append(point)
			var influence:=_influence(point)
			for key in bones:weights[key].append(float(influence.get(key,0.0)))
	for row in GRID_Y:
		for column in GRID_X:
			var a:=row*(GRID_X+1)+column
			faces.append(PackedInt32Array([a,a+1,a+GRID_X+2,a+GRID_X+1]))
	mesh.polygon=points
	mesh.polygons=faces
	for key in bones:mesh.add_bone(mesh.get_path_to(bones[key]),weights[key])
	_apply_frame(source)

func _apply_frame(source: AtlasTexture) -> void:
	if source.atlas!=mesh.texture:mesh.texture=source.atlas
	var coords:=PackedVector2Array()
	for row in GRID_Y+1:
		for column in GRID_X+1:
			coords.append(source.region.position+Vector2(float(column)/GRID_X,float(row)/GRID_Y)*source.region.size)
	mesh.uv=coords

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.speed_scale<=0.0:return
	var action: String=actor.state
	var special: String=str(actor.get('visual_action')) if actor.has_method('play_visual') else ''
	if special in ['skill','ultimate']:action=special
	if action!=prior_state:action_time=0.0;prior_state=action
	phase+=delta*actor.speed_scale
	action_time+=delta*actor.speed_scale
	for key in bones:bones[key].rotation=0.0
	var pace:=sin(phase*11.0)
	match action:
		'walk':
			bones['Pelvis'].rotation=pace*.045
			bones['Torso'].rotation=-pace*.075
			bones['Head'].rotation=pace*.09
			bones['LeftUpperArm'].rotation=pace*.22
			bones['RightUpperArm'].rotation=-pace*.22
			bones['LeftThigh'].rotation=-pace*.23
			bones['RightThigh'].rotation=pace*.23
			bones['LeftShin'].rotation=maxf(0.0,pace)*.26
			bones['RightShin'].rotation=maxf(0.0,-pace)*-.26
		'attack','skill','ultimate':
			var strike:=sin(minf(action_time/.34,1.0)*PI)
			var power:=1.25 if action=='ultimate' else 1.0
			bones['Torso'].rotation=-strike*.16*power
			bones['Head'].rotation=strike*.08
			bones['RightUpperArm'].rotation=-.15+strike*.82*power
			bones['RightForearm'].rotation=-.3+strike*.55
			bones['LeftUpperArm'].rotation=-strike*.26
			bones['LeftForearm'].rotation=strike*.22
			bones['LeftThigh'].rotation=-strike*.13
			bones['RightThigh'].rotation=strike*.12
		'hit':
			var recoil:=exp(-action_time*12.0)
			bones['Torso'].rotation=.23*recoil
			bones['Head'].rotation=-.18*recoil
			bones['RightUpperArm'].rotation=-.41*recoil
			bones['LeftUpperArm'].rotation=.38*recoil
			bones['LeftThigh'].rotation=-.12*recoil
		'death':
			bones['Torso'].rotation=lerpf(bones['Torso'].rotation,.44,minf(1.0,delta*8.0))
			bones['Head'].rotation=-.24
			bones['LeftThigh'].rotation=-.31
			bones['RightThigh'].rotation=.31
		_:
			bones['Torso'].rotation=sin(phase*2.8)*.025
			bones['Head'].rotation=-bones['Torso'].rotation*.6
			bones['LeftUpperArm'].rotation=sin(phase*2.8)*.06
			bones['RightUpperArm'].rotation=-bones['LeftUpperArm'].rotation
	mesh.modulate=actor.self_modulate
	mesh.scale.x=-1.0 if actor.flip_h else 1.0
	if cached_animation!=actor.animation or cached_frame!=actor.frame:
		var frame_texture: AtlasTexture=_source_frame(actor)
		if frame_texture!=null:_apply_frame(frame_texture)
		cached_animation=actor.animation;cached_frame=actor.frame
