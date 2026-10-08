extends Node3D
## Six reusable GPU bursts, each40 primary+20 secondary, share one floor box.
## The50-capacity visual cast pool owns admissions; GPU cost has a tighter cap.
const LIMIT=6
var field: Control
var bursts: Array[Dictionary]=[]
var accepted:=0
var _cursor:=0
func _ready() -> void:
	var floor_collision:=GPUParticlesCollisionBox3D.new();floor_collision.name='UltraSkillFloorCollision'
	floor_collision.size=Vector3(100,.12,80);floor_collision.position=Vector3(16,-.08,10);add_child(floor_collision)
	for i in LIMIT:
		var main:=_emitter(40);main.name='SkillBurst40_'+str(i);add_child(main)
		var secondary:=_emitter(20);secondary.name='SkillSubBurst20_'+str(i);add_child(secondary)
		bursts.append({'main':main,'secondary':secondary,'age':1.0,'busy':false})
func _emitter(amount: int) -> GPUParticles3D:
	var emitter:=GPUParticles3D.new();emitter.amount=amount;emitter.one_shot=true
	emitter.lifetime=.65;emitter.explosiveness=1;emitter.emitting=false;emitter.local_coords=false
	emitter.visibility_aabb=AABB(Vector3(-4,-1,-4),Vector3(8,7,8));emitter.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh:=QuadMesh.new();mesh.size=Vector2(.055,.12)
	var surface:=StandardMaterial3D.new();surface.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;surface.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	surface.vertex_color_use_as_albedo=true;surface.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	surface.emission_enabled=true;surface.emission=Color(.5,.5,.5);mesh.material=surface;emitter.draw_pass_1=mesh
	var material:=ParticleProcessMaterial.new();material.direction=Vector3(0,1,0);material.spread=125
	material.initial_velocity_min=.6;material.initial_velocity_max=1.8;material.gravity=Vector3(0,-3,0)
	material.scale_min=.6;material.scale_max=1.3;material.damping_min=.2;material.damping_max=.5
	material.collision_mode=ParticleProcessMaterial.COLLISION_RIGID;material.collision_bounce=.25;material.collision_friction=.5
	material.turbulence_enabled=true;material.turbulence_noise_scale=2;material.turbulence_noise_strength=.15
	material.turbulence_influence_min=.1;material.turbulence_influence_max=.2
	material.turbulence_noise_speed=Vector3(.12,.2,.08)
	var ramp:=Gradient.new();ramp.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.65),Color(1,1,1,0)]);ramp.offsets=PackedFloat32Array([0,.45,1])
	var gradient:=GradientTexture1D.new();gradient.gradient=ramp;material.color_ramp=gradient
	var curve:=Curve.new();curve.add_point(Vector2(0,.2));curve.add_point(Vector2(.18,1));curve.add_point(Vector2(1,0))
	var life:=CurveTexture.new();life.curve=curve;material.scale_curve=life
	emitter.process_material=material
	return emitter
func burst(point: Vector2,height: float,profile: Dictionary) -> bool:
	if not is_instance_valid(field) or not field.battle_clock_running() or not field.game.combat_effects_enabled:return false
	if str(field.game.presentation_options.get('performance','balanced'))=='battery':return false
	var selected: int=-1
	for step in LIMIT:
		var index: int=(_cursor+step)%LIMIT
		if not bursts[index].busy:selected=index;break
	if selected<0:return false
	_cursor=(selected+1)%LIMIT;var item: Dictionary=bursts[selected]
	for emitter: GPUParticles3D in [item.main,item.secondary]:
		emitter.position=Vector3(point.x,height,point.y)
		var material: ParticleProcessMaterial=emitter.process_material
		material.color=profile.color if emitter==item.main else profile.core
		material.initial_velocity_max=1.8*float(profile.power)
		material.angle_min=float(profile.seed)*7;material.angle_max=material.angle_min+70
		emitter.restart();emitter.emitting=true;emitter.visible=true
	item.age=0.0;item.busy=true;accepted+=1
	return true
func _process(delta: float) -> void:
	if not is_instance_valid(field):return
	var visible_now: bool=field.presentation_visible and field.game.combat_effects_enabled
	var running: bool=visible_now and field.battle_clock_running()
	for item in bursts:
		for emitter: GPUParticles3D in [item.main,item.secondary]:
			emitter.visible=visible_now and item.busy
			emitter.speed_scale=field.visual_speed() if running else 0.0
			if not visible_now:emitter.emitting=false
		if running:item.age+=maxf(0,delta)*field.visual_speed()
		if not visible_now or item.age>=.75:item.busy=false
