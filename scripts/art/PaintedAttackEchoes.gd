extends Node3D
## Two short silhouettes of the actual painted contact pose, never old SD art.
const SHADER=preload('res://shaders/PaintedAttackEcho.gdshader')
const DURATION:=.15
var layers: Array[MeshInstance3D]=[]
var sequence:=-1
var started:=-1.0
var layer_limit:=2
func configure() -> void:
	for i in 2:
		var layer:=MeshInstance3D.new();layer.name='PaintedEcho'+str(i)
		layer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=SHADER
		layer.material_override=material;layer.visible=false;add_child(layer);layers.append(layer)
func present(paint: MeshInstance3D,action: String,phase: float,serial: int,clock: float,enabled: bool) -> void:
	if enabled and action in ['attack_1','attack_2','skill','ultimate'] and phase>=.44 and serial!=sequence:
		sequence=serial;started=clock
		for layer in layers:
			layer.mesh=paint.mesh
			for key in ['source_texture','atlas_rect','atlas_texel']:
				layer.material_override.set_shader_parameter(key,paint.material_override.get_shader_parameter(key))
	var age:=clock-started
	for i in layers.size():
		var visible_now:=i<layer_limit and enabled and started>=0 and age>=0 and age<DURATION
		layers[i].visible=visible_now
		if not visible_now:continue
		layers[i].position=Vector3(-float(i+1)*(8+age*30),0,-.03*float(i+1))
		layers[i].material_override.set_shader_parameter('opacity',(.16 if i==0 else .09)*(1-age/DURATION))
