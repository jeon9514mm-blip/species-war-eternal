extends SceneTree
const LOADER=preload('res://scripts/maps/MapLoader.gd')
const FLOOR=preload('res://scripts/RaidBattlefield.gd')
var checks:=0
var failures: Array[String]=[]
func _init() -> void:run.call_deferred()
func check(ok: bool,description: String) -> void:
	checks+=1
	if not ok:failures.append(description);push_error(description)
func run() -> void:
	var parent:=Node3D.new();root.add_child(parent)
	var loader:=LOADER.new();root.add_child(loader)
	for pair in [['gray_meadow','Evergreen','forest'],['forgotten_mine','Crimson','canyon'],['moonrest_forest','Arcane','sanctuary']]:
		var map:=loader.load_zone(pair[0],parent,true)
		await physics_frame;await physics_frame
		var world: Node3D=map.get_node('Arena')
		check(world.scene_file_path.ends_with(pair[1]+'Raid.tscn'),pair[0]+' selects the themed raid scene')
		var art:=world.get_node_or_null('RaidDesign')
		check(art!=null and art.get_meta('theme')==pair[2],pair[0]+' authored raid design is connected')
		check(art.find_children('*','CollisionObject3D',true,false).is_empty(),pair[0]+' artwork adds no movement obstacles')
		var originals: Array[float]=[]
		for lamp in art.lamps:originals.append(lamp.light_energy)
		art.set_battle_mood(3,true)
		check(art.current_phase==3 and art.current_enraged,pair[0]+' responds to boss phase visually')
		art.set_battle_mood(1,false)
		var restored:=true
		for i in art.lamps.size():restored=restored and is_equal_approx(art.lamps[i].light_energy,originals[i])
		check(restored,pair[0]+' phase light response is reversible')
		var source:=FileAccess.get_file_as_string('res://scenes/maps3d/'+pair[1]+'Raid.tscn')
		var buffers: Dictionary={}
		for block in source.split('\n\n'):
			if block.begins_with('[sub_resource type="MultiMesh"'):
				buffers[block.get_slice('id="',1).get_slice('"',0)]=block.contains('buffer = PackedFloat32Array(') and not block.contains('buffer = PackedFloat32Array()')
		for block in source.split('\n\n'):
			if block.begins_with('[node') and block.contains('parent="RaidDesign') and block.contains('multimesh = SubResource("'):
				check(buffers.get(block.get_slice('multimesh = SubResource("',1).get_slice('"',0),false),pair[0]+' packed scenery instance data survives saving')
		var material: ShaderMaterial=world.get_node('SculptedTerrain').material_override
		check(material.shader.resource_path.ends_with('raid_ground.gdshader'),pair[0]+' has the raid ground shader')
		check(material.get_shader_parameter('theme')==['forest','canyon','sanctuary'].find(pair[2]),pair[0]+' has its own ground palette')
		var space:=world.get_world_3d().direct_space_state
		# These points include all four corners of the real raid movement rectangle.
		var sine:=Vector3(0,40,28).normalized().y
		for point in [FLOOR.FLOOR.position,FLOOR.FLOOR.end,Vector2(FLOOR.FLOOR.end.x,FLOOR.FLOOR.position.y),Vector2(FLOOR.FLOOR.position.x,FLOOR.FLOOR.end.y),FLOOR.ENTRY]:
			var p: Vector2=Vector2(16,10)+(point-Vector2(519,383))/Vector2(26,26*sine)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,5,p.y),Vector3(p.x,-2,p.y)))
			check(not hit.is_empty() and absf(hit.position.y)<.001,pair[0]+' flat collision supports reachable raid point')
		check(world.has_node('RaidDesign/BossGateMonument') if pair[2]!='canyon' else world.has_node('RaidDesign/SculptedCanyonEscarpment'),pair[0]+' readable landmark exists')
	var field:=loader.load_zone('gray_meadow',parent,false)
	check(field.name=='IceCavern_Map','hunting still uses its existing ice map')
	loader.unload_map(parent);await process_frame;parent.free();loader.free();await process_frame
	print('raid_arena_quality checks=%d failures=%s' %[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
