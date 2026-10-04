extends "res://scripts/maps3d/Battlefield3DView.gd"
## Painted 2.5D arena with production camera/actor projection.
## A lightweight actor world replaces unused old geometry, lights and collision.
## Camera, billboards and ground rings retain the RaidBattlefield coordinates.
const SCENERY=preload("res://scripts/art/RaidSceneryCatalog.gd")
var environment_plate: TextureRect
var atmosphere: Control
func _create_map_root() -> Node3D:
	var root:=Node3D.new();root.name="PaintedRaidMap"
	var arena_world:=Node3D.new();arena_world.name="Arena";root.add_child(arena_world)
	var view_camera:=Camera3D.new();view_camera.name="BattleCamera"
	view_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	view_camera.current=true;view_camera.size=30.0;view_camera.far=180.0
	arena_world.add_child(view_camera)
	var atmosphere_world:=WorldEnvironment.new();atmosphere_world.name="Atmosphere"
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	atmosphere_world.environment=environment;arena_world.add_child(atmosphere_world)
	viewport_3d.add_child(root)
	return root
func _ready() -> void:
	super._ready()
	viewport_3d.transparent_bg=true
	viewport_3d.positional_shadow_atlas_size=0
	environment_plate=TextureRect.new()
	environment_plate.name="RaidEnvironmentPlate"
	environment_plate.texture=load(SCENERY.texture_path(zone_id))
	environment_plate.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	environment_plate.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	environment_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(environment_plate);move_child(environment_plate,0)
	environment_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere=preload("res://scripts/art/RaidAtmosphere.gd").new()
	atmosphere.name="RaidPeripheralAtmosphere";atmosphere.field=self
	atmosphere.accent=SCENERY.profile(zone_id).mote
	add_child(atmosphere);atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
