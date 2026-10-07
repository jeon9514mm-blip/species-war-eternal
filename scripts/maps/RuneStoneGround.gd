extends Node3D
## Asset-based stone surface; all geometry, light and clock changes are visual only.
const ART=preload('res://scripts/maps/FieldArtCatalog.gd')
const SURFACE_SHADER=preload('res://shaders/RuneStoneGround.gdshader')
var zone_id:='gray_meadow'
var field: Control
var surface: MeshInstance3D
var stone_material: ShaderMaterial
var elapsed:=0.0
func _ready() -> void:
	name='RuneStoneGround'
	surface=MeshInstance3D.new();surface.name='ArtistStoneSurface'
	var plane:=PlaneMesh.new();plane.size=Vector2(70,60)
	plane.subdivide_width=48;plane.subdivide_depth=40;surface.mesh=plane
	surface.position=Vector3(16,0,10)
	stone_material=ShaderMaterial.new();stone_material.shader=SURFACE_SHADER
	var selected_zone: String=str(field.zone_id) if is_instance_valid(field) else zone_id
	stone_material.set_shader_parameter('stone_art',ART.texture_for(selected_zone))
	stone_material.set_shader_parameter('stone_detail',preload('res://assets/maps/detail-v33/stone-detail.png'))
	var palette: Dictionary=ART.stone_palette(selected_zone)
	stone_material.set_shader_parameter('stone_tint',palette.stone)
	stone_material.set_shader_parameter('rune_color',palette.rune)
	# Color parameters perform the sRGB-to-linear conversion for lit 3D ink.
	stone_material.set_shader_parameter('moss_rune',Color('#a8b89e'))
	stone_material.set_shader_parameter('bronze_rune',Color('#c4a484'))
	surface.material_override=stone_material;add_child(surface)
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_priority=101
func _process(delta: float) -> void:
	if not is_instance_valid(field):
		elapsed+=maxf(0,delta);stone_material.set_shader_parameter('visual_time',elapsed);return
	if not field.presentation_visible or field.presentation_suspended:return
	if field.visual_running():
		elapsed+=maxf(0,delta)*field.visual_speed()
		stone_material.set_shader_parameter('visual_time',elapsed)
