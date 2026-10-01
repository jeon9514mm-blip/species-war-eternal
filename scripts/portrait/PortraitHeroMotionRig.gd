extends Node2D
## A small, genuinely jointed 2D overlay for all deployed field heroes.
## Bone rotations are visual only: the owner keeps its world position, hitbox,
## skill timing, existing hero identity and original action frames.
var actor: HeroSpriteController
var shoulder: Node2D
var elbow: Node2D
var cape: Node2D
var offhand: Node2D
var role := 'dealer'
var phase := 0.0
var action_phase := 0.0
var previous_state := 'idle'
var tint := Color('#d5eaf5')

func install(sprite: HeroSpriteController, hero_role: String, color: Color) -> void:
	actor=sprite
	role=hero_role
	tint=color
	name='PortraitHeroMotionRig'
	# The bones use screen pixels; actor atlas scale differs for every skin.
	scale=Vector2(1.0/maxf(absf(sprite.scale.x),.001),1.0/maxf(absf(sprite.scale.y),.001))
	sprite.add_child(self)
	_build_bones()

func _patch(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
	var polygon:=Polygon2D.new()
	polygon.polygon=points
	polygon.color=color
	parent.add_child(polygon)

func _build_bones() -> void:
	cape=Node2D.new();cape.name='CapeJoint';cape.position=Vector2(-6,-28);cape.z_index=-1;add_child(cape)
	_patch(cape,PackedVector2Array([Vector2(-3,0),Vector2(3,0),Vector2(6,15),Vector2(0,17),Vector2(-8,13)]),Color(tint.darkened(.35),.70))
	shoulder=Node2D.new();shoulder.name='ShoulderJoint';shoulder.position=Vector2(8,-28);shoulder.z_index=1;add_child(shoulder)
	_patch(shoulder,PackedVector2Array([Vector2(-3,-2),Vector2(3,-2),Vector2(4,10),Vector2(-2,11)]),Color(tint.lightened(.2),.86))
	elbow=Node2D.new();elbow.name='ElbowJoint';elbow.position=Vector2(1,9);shoulder.add_child(elbow)
	_patch(elbow,PackedVector2Array([Vector2(-2,-1),Vector2(3,-1),Vector2(4,9),Vector2(-1,10)]),Color(tint,.9))
	var focus:=Polygon2D.new();focus.name='RoleFocus';focus.position=Vector2(2,9);elbow.add_child(focus)
	if role=='defender':
		focus.polygon=PackedVector2Array([Vector2(-6,-7),Vector2(6,-7),Vector2(7,3),Vector2(0,9),Vector2(-7,3)])
		focus.color=Color('#c7ddec')
	elif role in ['서포터','컨트롤러']:
		focus.polygon=PackedVector2Array([Vector2(-2,5),Vector2(-2,-10),Vector2(0,-15),Vector2(2,-10),Vector2(2,5)])
		focus.color=Color('#99efdd')
	else:
		focus.polygon=PackedVector2Array([Vector2(-4,3),Vector2(-2,-5),Vector2(0,-13),Vector2(2,-5),Vector2(4,3)])
		focus.color=Color('#f9d681')
	offhand=Node2D.new();offhand.name='OffhandJoint';offhand.position=Vector2(-9,-27);offhand.z_index=1;add_child(offhand)
	_patch(offhand,PackedVector2Array([Vector2(-3,-1),Vector2(2,-2),Vector2(4,9),Vector2(-1,10)]),Color(tint.darkened(.13),.80))

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.speed_scale<=0.0:return
	var next_state: String=actor.state
	if next_state!=previous_state:
		action_phase=0.0
		previous_state=next_state
	phase+=delta*float(actor.speed_scale)
	action_phase+=delta*float(actor.speed_scale)
	scale.x=(1.0 if not actor.flip_h else -1.0)/maxf(absf(actor.scale.x),.001)
	scale.y=1.0/maxf(absf(actor.scale.y),.001)
	var stride:=sin(phase*11.0)
	match next_state:
		'walk':
			shoulder.rotation=lerpf(shoulder.rotation,stride*.32,minf(1.0,delta*13.0))
			elbow.rotation=-stride*.23
			offhand.rotation=-stride*.33
			cape.rotation=-stride*.15
		'attack':
			var swing:=sin(minf(action_phase/.30,1.0)*PI)
			shoulder.rotation=-.66+swing*1.65
			elbow.rotation=-.52+swing*.92
			offhand.rotation=-.25-swing*.3
			cape.rotation=-swing*.2
		'hit':
			var recoil:=exp(-action_phase*12.0)
			shoulder.rotation=-.65*recoil
			elbow.rotation=.65*recoil
			offhand.rotation=.5*recoil
			cape.rotation=.28*recoil
		'death':
			shoulder.rotation=lerpf(shoulder.rotation,1.1,minf(1.0,delta*7.0))
			offhand.rotation=-shoulder.rotation
			cape.rotation=shoulder.rotation*.4
		_:
			shoulder.rotation=sin(phase*2.8)*.085
			elbow.rotation=sin(phase*2.8+.8)*.07
			offhand.rotation=-shoulder.rotation
			cape.rotation=sin(phase*2.0)*.08
