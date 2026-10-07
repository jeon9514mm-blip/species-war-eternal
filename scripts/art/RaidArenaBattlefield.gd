extends 'res://scripts/maps3d/Battlefield3DView.gd'
## Painted 2.5D environment beneath GPU-skinned actors and coordinate-exact warnings.
const SCENERY = preload('res://scripts/art/RaidSceneryCatalog.gd')
const ATMOSPHERE = preload('res://shaders/RaidPaintedAtmosphere.gdshader')
var painted_backdrop: TextureRect
var atmosphere_material: ShaderMaterial
var atmosphere_clock := 0.0
func _create_map_root() -> Node3D:
	var root := _create_generated_map_root(); root.name = 'PaintedRaidWorld'
	root.set_meta('map_design_removed', false)
	root.set_meta('painted_raid_asset', SCENERY.profile(zone_id).texture)
	return root
func _ready() -> void:
	super._ready()
	viewport_3d.transparent_bg = true
	for environment in map_root.find_children('*', 'WorldEnvironment', true, false):
		environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	painted_backdrop = TextureRect.new(); painted_backdrop.name = 'PaintedRaidBackdrop'
	painted_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painted_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painted_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	painted_backdrop.texture = load(str(SCENERY.profile(zone_id).texture))
	painted_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	atmosphere_material = ShaderMaterial.new(); atmosphere_material.shader = ATMOSPHERE
	atmosphere_material.set_shader_parameter('mist_color', SCENERY.profile(zone_id).accent)
	painted_backdrop.material = atmosphere_material
	add_child(painted_backdrop); move_child(painted_backdrop, 0)
	painted_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(delta: float) -> void:
	super._process(delta)
	if atmosphere_material == null or not is_instance_valid(game): return
	if game.raid_running and presentation_visible and not presentation_suspended and not game._application_suspended:
		if str(game.presentation_options.get('performance','balanced')) != 'battery':
			atmosphere_clock += maxf(0,delta) * visual_speed()
			atmosphere_material.set_shader_parameter('visual_time', atmosphere_clock)
