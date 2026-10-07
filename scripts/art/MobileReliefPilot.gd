extends 'res://scripts/art/HuntFramePilot.gd'
## Real Blender geometry; one shared body surface for all sixteen source poses.
const MOBILE_PAINT=preload('res://shaders/MobileReliefPaint.gdshader')
const FORWARD_PAINT=preload('res://shaders/MobileReliefForward.gdshader')
const HAIR=preload('res://shaders/MobileHairCards.gdshader')
const CAPE=preload('res://scripts/art/CapeThreePointMotion.gd')
const CAPE_UNIFORMS: Array[StringName]=[&'cape_0',&'cape_1',&'cape_2']
const BREATH_PERIODS={'bristle_boar':2.2,'wild_dog':1.2,'wind_crow':1.5,'night_raven':1.5}
const BREATH_AMPLITUDES={'bristle_boar':.04,'wild_dog':.08,'wind_crow':.06,'night_raven':.06}
var _body_mesh: Mesh
var _hair_mesh: Mesh
var _hair: MeshInstance3D
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
		if 'HairCards300' in node.name:_hair_mesh=node.mesh
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
	_cape_enabled=hero
	_material.set_shader_parameter('cape_enabled',_cape_enabled)
	if hero:
		for layer in _fur.layers:layer.free()
		_fur.layers.clear()
		_hair=MeshInstance3D.new();_hair.name='HairCards300';_hair.mesh=_hair_mesh;_hair.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hair_material:=ShaderMaterial.new();hair_material.shader=HAIR;_hair.material_override=hair_material;add_child(_hair)
		_snapshot.merge({'triangles':6600,'hair_cards':300,'cape_points':3,'display_pixels':86.4,'atlas_size':1024},true)
	else:_snapshot.merge({'triangles':3000,'fur_layers':fur_layers,'atlas_size':1024},true)
	return true
func _make_frame(_frame: Dictionary,_atlas_size: Vector2) -> ArrayMesh:return _body_mesh as ArrayMesh
func _apply_frame(camera: Camera3D,height: float,tint: Color,kind: String,frame: int) -> void:
	var changed: bool=kind!=_kind or frame!=_frame
	super._apply_frame(camera,height,tint,kind,frame)
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
		_hair.material_override.set_shader_parameter('actor_tint',tint)
		_hair.material_override.set_shader_parameter('visual_time',_visual_time)
func present(camera: Camera3D,height: float,tint: Color,delta: float,active: bool,point: Vector2,runtime: Dictionary,dead: bool) -> void:
	super.present(camera,height,tint,delta,active,point,runtime,dead)
	var cape_enabled_now:=_hero and effects_enabled
	if cape_enabled_now!=_cape_enabled:
		_cape_enabled=cape_enabled_now
		_material.set_shader_parameter('cape_enabled',_cape_enabled)
	if _hero:
		if active and source.speed_scale>0 and effects_enabled:
			var drift:=_cape.advance(delta*source.speed_scale,_visual_time,_locomotion_weight,_cape_seed)
			var pixel: float=height/86.4
			for i in 3:_material.set_shader_parameter(CAPE_UNIFORMS[i],drift[i]/maxf(.00001,basis.y.length())*pixel)
		if not effects_enabled:
			for i in 3:_material.set_shader_parameter(CAPE_UNIFORMS[i],Vector2.ZERO)
		if str(_snapshot.get('action',''))=='idle' and effects_enabled:position=camera.global_basis.y*sin(_visual_time*TAU/2.0+_breath_phase)*height/86.4*1.5
		_hair.visible=not dead and effects_enabled
	else:
		if str(_snapshot.get('action',''))=='idle' and effects_enabled:
			position=camera.global_basis.y*sin(_visual_time*TAU/_breath_period+_breath_phase)*(height/166.4*2.0 if _boss else _breath_amplitude)
		_snapshot.fur_layers=fur_layers
