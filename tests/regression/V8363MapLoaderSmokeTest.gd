extends SceneTree
const LOADER=preload('res://scripts/maps/MapLoader.gd')
var checks:=0
var failures: Array[String]=[]
func _init() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var parent:=Node3D.new();root.add_child(parent)
	var sentinel:=Node3D.new();sentinel.name='UnrelatedSibling';parent.add_child(sentinel)
	var loader:=LOADER.new();root.add_child(loader)
	var previous: Node3D
	for id in 4:
		var map: Node3D=loader.load_map(id,parent)
		check(map!=null,'map loads '+str(id))
		check(map.get_node('Arena/BattleCamera') is Camera3D,'map has actual 3D camera')
		check(map.get_node('SpawnPoints/PlayerSpawn').position==Vector3(16,0,10),'player marker matches gameplay world')
		check(map.get_node('SpawnPoints/EnemySpawn_E').position.x>30,'east marker matches invasion entry edge')
		var nav: NavigationMesh=map.get_node('NavigationRegion3D').navigation_mesh
		check(nav.get_polygon_count()==1 and nav.get_polygon(0).size()==4,'complete navigable quad instead of incomplete triangle fan')
		check(sentinel.get_parent()==parent,'unrelated sibling survives map switch')
		check(parent.get_child_count()==2,'only current map remains in parent')
		if is_instance_valid(previous):check(not previous.is_inside_tree(),'previous map removed before deferred deletion')
		previous=map
		await process_frame
	check(loader.load_map(99,parent)==null,'invalid map ID handled')
	check(previous.is_inside_tree(),'invalid request preserves current map')
	var other:=Node3D.new();root.add_child(other)
	var other_map: Node3D=loader.load_map(3,other,true)
	check(other_map!=null and previous.is_inside_tree(),'independent destination preserves first map')
	loader.unload_map(parent);check(parent.get_child_count()==1 and sentinel.get_parent()==parent,'unload preserves unrelated content')
	loader.unload_map(other);await process_frame;parent.free();other.free();loader.free();await process_frame
	print('v8363_map_loader checks=%d failures=%s'%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
