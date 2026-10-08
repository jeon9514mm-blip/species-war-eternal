extends Node3D
## One fixed-cost boss ground seal; observes the raid, never changes its rules.
var field: Control
var seal: MeshInstance3D
var material: ShaderMaterial
var elapsed:=0.0
var phase:=1
var enraged:=false
func _ready() -> void:
	name='RaidDesign'
	seal=MeshInstance3D.new();seal.name='BossMossBronzeSeal'
	var plane:=PlaneMesh.new();plane.size=Vector2(5,7.071);seal.mesh=plane
	material=ShaderMaterial.new();material.shader=preload('res://shaders/MossBronzeCircle.gdshader')
	material.set_shader_parameter('artist_circle',load('res://assets/mobile25d/vfx/moss_bronze_circle.png'))
	material.set_shader_parameter('moss',Color('#a8b89e'));material.set_shader_parameter('bronze',Color('#e8c99a'))
	material.set_shader_parameter('glow',.7);material.set_shader_parameter('inner_glow',.55)
	material.set_shader_parameter('pulse_period',1.0);material.set_shader_parameter('rotation_speed',.12)
	material.set_shader_parameter('rune_count',12);material.set_shader_parameter('rune_brightness',.7)
	material.set_shader_parameter('leaf_count',20);material.set_shader_parameter('dust_count',20)
	seal.material_override=material;seal.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(seal)
	process_priority=101
func set_battle_mood(next_phase: int,next_enraged: bool) -> void:
	if phase==next_phase and enraged==next_enraged:return
	phase=next_phase;enraged=next_enraged
	# Phase changes alter pigment, without resizing attack footprints or feet.
	material.set_shader_parameter('moss',Color('#a8b89e').lerp(Color('#a85f52'),.22 if enraged else minf(.16,(phase-1)*.08)))
func _process(delta: float) -> void:
	if not is_instance_valid(field) or not is_instance_valid(field.game):return
	visible=field.presentation_visible and field.game.combat_effects_enabled
	if not visible or field.presentation_suspended or field.size.y<1 or not is_instance_valid(field.camera):return
	var point: Vector2=field.raid_to_world(field.game.raid_boss_position)
	if is_instance_valid(field.game.raid_boss_sprite):point=field.raid_display_world(field.game.raid_boss_sprite,field.game.raid_boss_position)
	seal.position=Vector3(point.x,.032,point.y)
	var radius: float=90.0*field.camera.size/field.size.y
	var plane: PlaneMesh=seal.mesh;plane.size=Vector2(radius*2.22,radius*2.22/maxf(.01,absf(field.camera.global_basis.z.y)))
	if field.battle_clock_running():
		elapsed+=maxf(0,delta)*field.visual_speed();material.set_shader_parameter('visual_time',elapsed)
