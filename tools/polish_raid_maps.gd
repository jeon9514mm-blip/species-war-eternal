extends SceneTree
## Save with a real renderer: the headless dummy renderer drops MultiMesh buffers.
func _init() -> void:run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=='headless':push_error('Raid authoring requires a display renderer.');quit(1);return
	for pair in [['Evergreen','forest'],['Crimson','canyon'],['Arcane','sanctuary'],['IceCavern','ice']]:
		var path: String='res://scenes/maps3d/'+pair[0]+'Raid.tscn'
		var scene: Node3D=load(path).instantiate()
		preload('res://tools/RaidArenaArt.gd').new().apply(scene,pair[1])
		var packed:=PackedScene.new();assert(packed.pack(scene)==OK);assert(ResourceSaver.save(packed,path)==OK)
		print('RAID_POLISHED ',path);scene.free()
	quit()
