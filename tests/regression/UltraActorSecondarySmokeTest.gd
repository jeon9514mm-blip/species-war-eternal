extends SceneTree
const PAINT=preload('res://scripts/art/MobileReliefPilot.gd')
const ACTOR=preload('res://scripts/art/MobilePaintActor.gd')
const MONSTER=preload('res://scripts/art/MobileMonsterActor.gd')
const CATALOG=preload('res://scripts/art/HuntFrameCatalog.gd')
const ROSTER=preload('res://scripts/heroes/HeroRosterCatalog.gd')
const CAPE=preload('res://scripts/art/CapeThreePointMotion.gd')
const FLOCK=preload('res://scripts/hunting/MonsterFlocking.gd')
var checks:=0
var failures: Array[String]=[]
func _init() -> void:run.call_deferred()
func check(value: bool,note: String) -> void:
	checks+=1
	if not value:failures.append(note);push_error(note)
func triangles(value: Mesh) -> int:
	var count:=0
	for surface in value.get_surface_count():count+=int(value.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3)
	return count
func run() -> void:
	var camera:=Camera3D.new();root.add_child(camera)
	for id in ROSTER.HEROES:
		var source:=ACTOR.new();source.configure_mobile(id);root.add_child(source);source.set_process(false);source.speed_scale=1
		var paint:=PAINT.new();root.add_child(paint)
		if not paint.bind(source,true):check(false,id+' native painted relief binds');paint.free();source.free();continue
		check(paint._echoes.multimesh.mesh!=null and paint._echoes.visible_count()==0 and not paint._echoes.instance.visible,id+' hidden native pool has a valid allocation surface before any contact')
		paint.present(camera,1,Color.WHITE,.1,true,Vector2.ZERO,{},false)
		check(triangles(paint.mesh)==6000 and triangles(paint._hair.mesh)==1200,id+' actual full mesh uses 600 hair cards')
		check(paint._fur.multimesh==null and paint._fur.get_child_count()==0,id+' hero hair has no redundant creature fur geometry')
		check(paint._cape.points.size()==5 and paint._cape.points[0]==Vector2.ZERO,id+' cape root pinned with five controls')
		check(paint.material_override.get_shader_parameter('outline_px')==3.0 and paint.material_override.get_shader_parameter('rim_strength')==.25,id+' readable three pixel outline and 25 percent rim')
		check(paint.position.length()<=2.5/86.4+.00001,id+' breathing never exceeds 2.5 pixels')
		var atlas: Texture2D=paint._textures.motion;var body_basis:=paint.basis
		paint.secondary_lod=1;paint.present(camera,1,Color.WHITE,.1,true,Vector2.ZERO,{},false)
		check(triangles(paint.mesh)==3000 and triangles(paint._hair.mesh)==600 and paint.basis==body_basis,id+' actual half geometry preserves fixed actor size')
		check(paint._textures.motion==atlas and paint._textures.attack==atlas,id+' LOD reuses one original 1024 pose atlas')
		paint.timeline.release('attack_1',.15);paint.present(camera,1,Color.WHITE,0,true,Vector2.ZERO,{},false)
		check(paint._echoes.multimesh.instance_count==5 and paint._echoes.visible_count()==5 and triangles(paint._echoes.multimesh.mesh)==3000,id+' five native echo instances capture the selected lower body mesh')
		check(paint._echoes.multimesh.get_instance_transform(0).origin.x==-8 and paint._echoes.multimesh.get_instance_transform(4).origin.x==-40,id+' five echo instances retain independent native offsets')
		check(is_equal_approx(paint._echoes.instance_opacity(0),.5) and is_equal_approx(paint._echoes.instance_opacity(4),.26),id+' first and last native echoes carry their own opacity')
		var frozen=paint._cape.points.duplicate();var hair_time: float=paint._hair.material_override.get_shader_parameter('visual_time')
		paint.secondary_lod=2;paint.present(camera,1,Color.WHITE,.5,true,Vector2.ZERO,{},false)
		check(paint._cape.points==frozen and paint._hair.material_override.get_shader_parameter('visual_time')==hair_time,id+' distant secondary motion freezes without freezing whole pose')
		paint.secondary_lod=0;var clock: float=paint._visual_time
		paint.present(camera,1,Color.WHITE,.5,false,Vector2.ZERO,{},false)
		check(paint._visual_time==clock and paint._cape.points==frozen,id+' paused secondary simulation stays fixed')
		paint.secondary_lod=3;paint.present(camera,1,Color.WHITE,0,true,Vector2.ZERO,{},false)
		check(not paint._hair.visible,id+' far hair hidden')
		paint.effects_enabled=false;paint.present(camera,1,Color.WHITE,0,true,Vector2.ZERO,{},false)
		var reset:=true
		for key in paint.CAPE_UNIFORMS:reset=reset and paint.material_override.get_shader_parameter(key)==Vector2.ZERO
		check(reset and not paint._hair.visible,id+' effects off clears all five cloth uniforms')
		paint.free();source.free()
	var cloth:=CAPE.new();var bounded:=true
	for i in 1200:
		cloth.advance(1.0/60.0,float(i)/60.0,1.0,.32)
		for point in cloth.points:bounded=bounded and point.is_finite() and point.length()<=2.60001
	check(bounded and cloth.points[0]==Vector2.ZERO,'twenty seconds cloth cannot diverge or move its root')
	var source:=MONSTER.new();source.configure_mobile('들개 무리',Vector2.ONE);root.add_child(source);source.set_process(false);source.speed_scale=1
	var paint:=PAINT.new();root.add_child(paint);check(paint.bind(source,false),'actual monster binds')
	check(paint._fur.multimesh.mesh!=null and paint._fur.visible_count()==0 and not paint._fur.instance.visible,'hidden creature pool has a valid allocation surface before its first pose')
	paint.present(camera,1,Color.WHITE,.1,true,Vector2.ZERO,{'health_ratio':.25},false)
	check(paint._fur.multimesh.instance_count==6 and paint._fur.visible_count()==6 and paint._fur.get_child_count()==1 and paint._fur.instance is MultiMeshInstance3D,'six native fur shells share one actual geometry node')
	check(is_equal_approx(paint._fur.instance_shell(0),1.0/6.0) and is_equal_approx(paint._fur.instance_shell(5),1.0),'first and last fur shell depths are independent INSTANCE_CUSTOM values')
	check(paint.material_override.get_shader_parameter('wound_strength')>.6,'confirmed HP ratio reveals bounded wound mark')
	paint.secondary_lod=1;paint.present(camera,1,Color.WHITE,.1,true,Vector2.ZERO,{},false)
	check(paint._fur.visible_count()==3 and paint._fur.multimesh.instance_count==6,'monster LOD selects three of six preallocated native shells')
	paint.effects_enabled=false;paint.present(camera,1,Color.WHITE,.1,true,Vector2.ZERO,{},true)
	check(paint.material_override.get_shader_parameter('wound_strength')==0.0 and paint._fur.visible_count()==0 and not paint._fur.instance.visible,'dead monster hides wound and fur')
	check(FLOCK.SEPARATION_PX==25 and FLOCK.ALIGNMENT==.15 and FLOCK.COHESION==.08 and FLOCK.AVOID_PX==40,'flock distances and weights match final request')
	check(FLOCK.BEHAVIOR_MIN==1 and FLOCK.BEHAVIOR_MAX==8 and FLOCK.SOUND_CHANCE==.5,'behavior interval and bounded positional sound chance')
	paint.free();source.free();camera.free()
	print('ULTRA_ACTOR_SECONDARY checks=%d failures=%s'%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
