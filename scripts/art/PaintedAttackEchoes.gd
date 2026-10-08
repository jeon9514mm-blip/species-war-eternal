extends Node3D
## Five native instances of one captured contact mesh, submitted as one draw.
const SHADER=preload('res://shaders/PaintedAttackEcho.gdshader')
const DURATION:=.40
const MAX_LAYERS:=5
var instance: MultiMeshInstance3D
var multimesh: MultiMesh
var material: ShaderMaterial
var sequence:=-1
var started:=-1.0
var layer_limit:=5
var _visible_count:=0
var _age:=-INF
func configure() -> void:
	if is_instance_valid(instance):return
	multimesh=MultiMesh.new();multimesh.mesh=QuadMesh.new()
	# The renderer validates AABBs during allocation, before a contact is captured.
	# A valid hidden surface prevents a null-mesh pool; it never appears on screen.
	multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_custom_data=true;multimesh.instance_count=MAX_LAYERS;multimesh.visible_instance_count=0
	for i in MAX_LAYERS:
		multimesh.set_instance_transform(i,Transform3D.IDENTITY);multimesh.set_instance_custom_data(i,Color(0,0,0,1))
	material=ShaderMaterial.new();material.shader=SHADER
	instance=MultiMeshInstance3D.new();instance.name='PaintedEchoBatch';instance.multimesh=multimesh;instance.material_override=material;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;instance.visible=false;add_child(instance)
func visible_count() -> int:return multimesh.visible_instance_count if multimesh!=null else 0
func instance_opacity(index: int) -> float:return multimesh.get_instance_custom_data(index).r if multimesh!=null and index>=0 and index<MAX_LAYERS else 0.0
func present(paint: MeshInstance3D,action: String,phase: float,serial: int,clock: float,enabled: bool) -> void:
	if not is_instance_valid(instance):return
	if enabled and action in ['attack_1','attack_2','skill','ultimate'] and phase>=.44 and serial!=sequence:
		sequence=serial;started=clock
		_age=-INF;multimesh.mesh=paint.mesh
		var bounds:=paint.custom_aabb
		if bounds.size.x<=0 or bounds.size.y<=0:bounds=paint.mesh.get_aabb()
		instance.custom_aabb=AABB(bounds.position+Vector3(-100,0,-.20),bounds.size+Vector3(100,0,.40))
		# Only the Blender unit surface needs vertex/UV reconstruction. A legacy
		# frame pilot can read the mobile atlas while already storing native pixels.
		var mobile: bool=bool(paint.get('entry').get('optimized_mobile25d',false)) and paint.material_override.get_shader_parameter('paint_anchor') is Vector2
		material.set_shader_parameter('unit_mesh',mobile)
		if mobile:
			for key in ['paint_size','paint_anchor']:material.set_shader_parameter(key,paint.material_override.get_shader_parameter(key))
		for key in ['source_texture','atlas_rect','atlas_texel']:material.set_shader_parameter(key,paint.material_override.get_shader_parameter(key))
	var age:=clock-started
	var count:=mini(MAX_LAYERS,maxi(0,layer_limit)) if enabled and started>=0 and age>=0 and age<DURATION else 0
	if count!=_visible_count:
		_visible_count=count;multimesh.visible_instance_count=count;instance.visible=count>0
	if count>0 and age!=_age:
		_age=age
		for i in MAX_LAYERS:
			multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(-float(i+1)*(8+age*30),0,-.03*float(i+1))))
			multimesh.set_instance_custom_data(i,Color(.5*(1-age/DURATION)*(1.0-float(i)*.12),0,0,1))
