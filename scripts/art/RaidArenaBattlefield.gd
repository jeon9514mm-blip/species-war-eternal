extends 'res://scripts/maps3d/Battlefield3DView.gd'
## No raid scenery. Keep camera, actors and inherited raid controls only.
func _create_map_root() -> Node3D:
 var root:=_create_generated_map_root();root.name='EmptyRaidWorld'
 root.set_meta('map_design_removed',true)
 return root
