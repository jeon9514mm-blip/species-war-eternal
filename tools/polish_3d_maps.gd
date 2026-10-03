extends SceneTree
## Reapply just the polish layer while preserving manually edited source geometry.
func _init() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=='headless':
		push_error('Map authoring needs a display renderer to preserve MultiMesh instance buffers. Run without --headless.');quit(1);return
	for pair in [['IceCavern','ice'],['Crimson','canyon'],['Evergreen','forest'],['Arcane','sanctuary']]:
		for suffix in ['Field','Raid']:
			var path: String='res://scenes/maps3d/'+pair[0]+suffix+'.tscn'
			# No scene-tree insertion: runtime batching must not be baked into the source.
			var scene: Node3D=load(path).instantiate()
			preload('res://tools/MapArtPolish.gd').new().apply(scene,pair[1])
			var packed:=PackedScene.new();assert(packed.pack(scene)==OK)
			assert(ResourceSaver.save(packed,path)==OK);print('POLISHED ',path);scene.free()
	quit()
