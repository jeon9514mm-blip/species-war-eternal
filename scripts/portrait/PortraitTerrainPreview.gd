extends "res://scripts/maps3d/Battlefield3DView.gd"
## Region cards use the same editable 3D environment as the playable field.
func _ready() -> void:
	super._ready()
	viewport_3d.render_target_update_mode=SubViewport.UPDATE_ONCE
func _resize_world() -> void:
	super._resize_world()
	if is_instance_valid(viewport_3d):viewport_3d.render_target_update_mode=SubViewport.UPDATE_ONCE
