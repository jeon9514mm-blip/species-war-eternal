extends 'res://scripts/maps3d/Battlefield3DView.gd'
## Modeled architecture and real skinned actors share the warning camera.
func _create_map_root() -> Node3D:
	var root:=_create_generated_map_root();root.name='Real3DRaidWorld'
	root.set_meta('map_design_removed',false)
	return root
