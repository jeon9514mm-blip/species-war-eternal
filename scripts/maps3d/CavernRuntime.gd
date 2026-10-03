extends Node3D
## Preserve editable source nodes; combine identical static meshes only in play.
func _ready() -> void:
	var groups: Dictionary={}
	for child in get_children():
		if not child is MeshInstance3D or not child.visible or child.mesh==null or child.get_child_count()>0:continue
		var key:=str(child.mesh.get_rid())+':'+str(child.material_override.get_rid() if child.material_override!=null else RID())
		if not groups.has(key):groups[key]=[]
		groups[key].append(child)
	for nodes: Array in groups.values():
		if nodes.size()<4:continue
		var source: MeshInstance3D=nodes[0]
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=source.mesh;multi.instance_count=nodes.size()
		for i in nodes.size():multi.set_instance_transform(i,nodes[i].transform);nodes[i].hide()
		var batch:=MultiMeshInstance3D.new();batch.name='StaticBatch';batch.multimesh=multi;batch.material_override=source.material_override;add_child(batch)
