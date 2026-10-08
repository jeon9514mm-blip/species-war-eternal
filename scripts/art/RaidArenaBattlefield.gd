extends 'res://scripts/maps3d/Battlefield3DView.gd'
## Encounter architecture and painted actors share the coordinate-exact camera.
const ARENA_DESIGN=preload('res://scripts/maps3d/RaidEncounterArena.gd')
func _ready() -> void:
	super._ready()
	ARENA_DESIGN.finish_floor(map_root,zone_id)

func _create_map_root() -> Node3D:
	var root:=_create_generated_map_root();root.name='Real3DRaidWorld'
	root.set_meta('map_design_removed',false)
	ARENA_DESIGN.build(root,zone_id)
	return root
