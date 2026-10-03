extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _init() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	# Authored hidden landmarks must remain hidden when static meshes are batched.
	var holder:=Node3D.new();holder.set_script(load('res://scripts/maps3d/CavernRuntime.gd'))
	var cube:=BoxMesh.new()
	for i in 8:
		var n:=MeshInstance3D.new();n.mesh=cube;n.visible=i<4;n.position=Vector3(i*2,0,0);holder.add_child(n)
	root.add_child(holder);await process_frame
	var visible_instances:=0
	for child in holder.get_children():
		if child is MeshInstance3D and child.visible:visible_instances+=1
		if child is MultiMeshInstance3D and child.visible:visible_instances+=child.multimesh.instance_count
	check(visible_instances==4,'static batching preserves authored visibility')
	holder.free()
	for theme in ['Arcane','Crimson','Evergreen']:
		for suffix in ['Field','Raid']:
			var key: String=theme+suffix
			var source: String=FileAccess.get_file_as_string('res://scenes/maps3d/'+key+'.tscn')
			var buffers: Dictionary={}
			for block in source.split('\n\n'):
				if block.begins_with('[sub_resource type="MultiMesh"'):
					buffers[block.get_slice('id="',1).get_slice('"',0)]=block.contains('buffer = PackedFloat32Array(') and not block.contains('buffer = PackedFloat32Array()')
			for block in source.split('\n\n'):
				if block.begins_with('[node') and block.contains('parent="ArtPolish') and block.contains('multimesh = SubResource("'):
					var id: String=block.get_slice('multimesh = SubResource("',1).get_slice('"',0)
					check(buffers.get(id,false),key+' scenery instances survive scene save '+id)
			var world: Node3D=load('res://scenes/maps3d/'+key+'.tscn').instantiate();root.add_child(world)
			await physics_frame;await physics_frame
			var art:=world.get_node_or_null('ArtPolish/ReferenceScenery')
			check(art!=null,key+' includes reference geometry')
			check(art.find_children('*','CollisionObject3D',true,false).is_empty(),key+' scenery adds no collision obstacles')
			var space:=world.get_world_3d().direct_space_state
			for p in [Vector2(.2,.2),Vector2(31.8,.2),Vector2(.2,19.8),Vector2(31.8,19.8),Vector2(16,10),Vector2(31.8,10)]:
				var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,8,p.y),Vector3(p.x,-2,p.y))
				var hit:=space.intersect_ray(query)
				check(not hit.is_empty(),key+' playable floor exists '+str(p))
				if not hit.is_empty():check(absf(hit.position.y)<.001,key+' floor height preserved '+str(p))
			check(world.get_node('BattleCamera') is Camera3D,key+' battle camera remains connected')
			if theme=='Crimson':
				var normals: PackedVector3Array=world.get_node('SculptedTerrain').mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
				check(not normals.is_empty() and normals[0].y>.99,key+' visual floor faces upward')
			if theme=='Arcane':
				var paving: String='raid_ground.gdshader' if suffix=='Raid' else 'sanctuary_paving.gdshader'
				check(world.get_node('SculptedTerrain').material_override.shader.resource_path.ends_with(paving),'sanctuary uses the appropriate field/raid paving')
			world.free();await physics_frame
	print('v8366_map_art checks=%d failures=%s'%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
