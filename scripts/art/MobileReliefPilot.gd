extends 'res://scripts/art/HuntFramePilot.gd'
## Real Blender geometry; one shared body surface for all sixteen source poses.
const MOBILE_PAINT=preload('res://shaders/MobileReliefPaint.gdshader')
const FORWARD_PAINT=preload('res://shaders/MobileReliefForward.gdshader')
const HAIR=preload('res://shaders/MobileHairCards.gdshader')
const FORWARD_HAIR=preload('res://shaders/MobileHairCardsForward.gdshader')
const CAPE=preload('res://scripts/art/CapeThreePointMotion.gd')
const CAPE_UNIFORMS: Array[StringName]=[&'cape_0',&'cape_1',&'cape_2',&'cape_3',&'cape_4']
const BREATH_PERIODS={'bristle_boar':2.2,'wild_dog':1.2,'wind_crow':1.5,'night_raven':1.5}
const BREATH_AMPLITUDES={'bristle_boar':.04,'wild_dog':.08,'wind_crow':.06,'night_raven':.06}
var _body_mesh: Mesh
var _hair_mesh: Mesh
var _body_lod_mesh: Mesh
var _hair_lod_mesh: Mesh
var _hair: MeshInstance3D
var secondary_lod:=0
var hair_shadow_enabled:=true
var _hair_uniforms: Dictionary={}
var _cape:=CAPE.new()
var _cape_seed:=0.0
var _breath_phase:=0.0
var _breath_period:=2.0
var _breath_amplitude:=.04
var _boss:=false
var _cape_enabled:=false
func bind(actor: AnimatedSprite2D,hero: bool,catalog: RefCounted=null) -> bool:
	var data: Dictionary=(catalog if catalog!=null else CATALOG.new()).load_entry(CATALOG.identity(actor,hero))
	if data.is_empty() or not data.has('mesh'):return false
	var scene: PackedScene=load(str(data.mesh));var temporary:=scene.instantiate()
	for node in temporary.find_children('*','MeshInstance3D',true,false):
		if 'HairCards300LOD' in node.name:_hair_lod_mesh=node.mesh
		elif 'HairCards600' in node.name or 'HairCards300' in node.name:_hair_mesh=node.mesh
		elif 'PaintedReliefLOD' in node.name:_body_lod_mesh=node.mesh
		elif 'PaintedRelief' in node.name:_body_mesh=node.mesh
	if temporary is MeshInstance3D and _body_mesh==null:_body_mesh=temporary.mesh
	temporary.free()
	if _body_mesh==null:return false
	if not super.bind(actor,hero,catalog):return false
	var identity: String=str(entry.id)
	_cape_seed=float(posmod(identity.hash(),6283))*.001
	_breath_phase=float(posmod(identity.hash(),1000))*.006283
	_boss=identity in ['grun','morgul','selene_boss']
	_breath_period=float(BREATH_PERIODS.get(identity,1.8 if _boss else 2.0))
	_breath_amplitude=float(BREATH_AMPLITUDES.get(identity,.04))
	_material.shader=FORWARD_PAINT if RenderingServer.get_current_rendering_method()=='forward_plus' else MOBILE_PAINT
	_reset_uniform_cache()
	_set_uniform(&'outline_px',3.0 if hero else 0.0)
	_set_uniform(&'rim_strength',.25)
	_material.set_shader_parameter('outline_opacity',.6)
	_material.set_shader_parameter('display_height',86.4 if hero else (179.2 if _boss else 40.0))
	_cape_enabled=hero
	echo_layers=5
	_material.set_shader_parameter('cape_enabled',_cape_enabled)
	if hero:
		_fur.disable()
		_hair=MeshInstance3D.new();_hair.name='HairCards600';_hair.mesh=_hair_mesh;_hair.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var hair_material:=ShaderMaterial.new();hair_material.shader=FORWARD_HAIR if RenderingServer.get_current_rendering_method()=='forward_plus' else HAIR;_hair.material_override=hair_material;add_child(_hair)
		_snapshot.merge({'triangles':7200,'hair_cards':600,'cape_points':5,'display_pixels':86.4,'atlas_size':1024,'cloth_collision':'analytic five-point strip; torso capsule and nonadjacent points'},true)
	else:
		fur_layers=6
		_snapshot.merge({'triangles':3000,'fur_layers':fur_layers,'atlas_size':1024},true)
	return true
func _make_frame(_frame: Dictionary,_atlas_size: Vector2) -> ArrayMesh:return _body_mesh as ArrayMesh
func _apply_frame(camera: Camera3D,height: float,tint: Color,kind: String,frame: int) -> void:
	var changed: bool=kind!=_kind or frame!=_frame
	super._apply_frame(camera,height,tint,kind,frame)
	# Select before the base presenter captures a new contact echo, so LOD
	# ghosts reuse the same selected surface instead of restoring full geometry.
	if _hero and _body_lod_mesh!=null:mesh=_body_lod_mesh if secondary_lod>=1 else _body_mesh
	if _hair!=null and _hair_lod_mesh!=null:_hair.mesh=_hair_lod_mesh if secondary_lod>=1 else _hair_mesh
	if changed:
		var pose: Dictionary=entry[kind].frames[frame]
		_material.set_shader_parameter('paint_anchor',Vector2(pose.anchor[0],pose.anchor[1]))
		var region: Array=pose.region
		custom_aabb=AABB(Vector3(-pose.anchor[0]-4,pose.anchor[1]-region[3]-4,-4),Vector3(region[2]+8,region[3]+8,8))
		if _hair!=null:
			_hair.custom_aabb=custom_aabb
			for key in ['source_texture','atlas_rect','atlas_texel','paint_size','paint_anchor']:
				_hair.material_override.set_shader_parameter(key,_material.get_shader_parameter(key))
			var rect: Array=pose.hair_rect;_hair.material_override.set_shader_parameter('hair_rect',Vector4(rect[0],rect[1],rect[2],rect[3]))
	if _hair!=null:
		if _hair_uniforms.get('actor_tint')!=tint:_hair.material_override.set_shader_parameter('actor_tint',tint);_hair_uniforms.actor_tint=tint
		if secondary_lod<2 and _hair_uniforms.get('visual_time')!=_visual_time:_hair.material_override.set_shader_parameter('visual_time',_visual_time);_hair_uniforms.visual_time=_visual_time
func present(camera: Camera3D,height: float,tint: Color,delta: float,active: bool,point: Vector2,runtime: Dictionary,dead: bool) -> void:
	if _fur!=null:_fur.detail_lod=secondary_lod;_fur.effects_enabled=effects_enabled
	super.present(camera,height,tint,delta,active,point,runtime,dead)
	var cape_enabled_now:=_hero and effects_enabled and secondary_lod<3
	if cape_enabled_now!=_cape_enabled:
		_cape_enabled=cape_enabled_now
		_material.set_shader_parameter('cape_enabled',_cape_enabled)
	if _hero:
		var hair_shadow:=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if hair_shadow_enabled and effects_enabled and secondary_lod==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _hair.cast_shadow!=hair_shadow:_hair.cast_shadow=hair_shadow
		if active and source.speed_scale>0 and effects_enabled and secondary_lod<2:
			var drift:=_cape.advance(delta*source.speed_scale,_visual_time,_locomotion_weight,_cape_seed)
			var pixel: float=height/86.4
			for i in CAPE_UNIFORMS.size():_set_uniform(CAPE_UNIFORMS[i],drift[i]/maxf(.00001,basis.y.length())*pixel)
		if not effects_enabled:
			for i in CAPE_UNIFORMS.size():_set_uniform(CAPE_UNIFORMS[i],Vector2.ZERO)
		if str(_snapshot.get('action',''))=='idle' and effects_enabled:position=camera.global_basis.y*sin(_visual_time*TAU/2.0+_breath_phase)*height/86.4*2.5
		_hair.visible=not dead and effects_enabled and secondary_lod<3
		_snapshot.triangles=3600 if secondary_lod>=1 and _body_lod_mesh!=null else 7200
		_snapshot.hair_cards=0 if secondary_lod>=3 else (300 if secondary_lod>=1 else 600)
	else:
		var hp_ratio:=clampf(float(runtime.get('health_ratio',1.0)),0.0,1.0)
		_set_uniform(&'wound_strength',clampf((.75-hp_ratio)/.75,0.0,1.0) if effects_enabled and not dead else 0.0)
		if str(_snapshot.get('action',''))=='idle' and effects_enabled:
			position=camera.global_basis.y*sin(_visual_time*TAU/_breath_period+_breath_phase)*(height/179.2*2.0 if _boss else _breath_amplitude)
		_snapshot.fur_layers=fur_layers
	_snapshot.secondary_lod=secondary_lod
