extends SceneTree
## Complete versions of the supplied scene skeletons, using available 3D art.
const MAPS={'ElvenRuins':'Arcane','CanyonMine':'Crimson','ForestMeadow':'Evergreen','IceCavern':'IceCavern'}
func _init() -> void: build.call_deferred()
func build() -> void:
	for map_name: String in MAPS:
		for raid in [false,true]:
			var scene:=Node3D.new();scene.name=map_name+'_Map';root.add_child(scene)
			var arena: Node3D=load('res://scenes/maps3d/'+str(MAPS[map_name])+('Raid' if raid else 'Field')+'.tscn').instantiate()
			arena.name='Arena';scene.add_child(arena);arena.owner=scene
			var region:=NavigationRegion3D.new();region.name='NavigationRegion3D'
			var nav:=NavigationMesh.new();nav.vertices=PackedVector3Array([Vector3(.35,0,.35),Vector3(31.65,0,.35),Vector3(31.65,0,19.65),Vector3(.35,0,19.65)])
			nav.add_polygon(PackedInt32Array([0,3,2,1]));nav.agent_radius=.25;nav.agent_height=2
			region.navigation_mesh=nav;scene.add_child(region);region.owner=scene
			var spawns:=Node3D.new();spawns.name='SpawnPoints';scene.add_child(spawns);spawns.owner=scene
			for key in {'PlayerSpawn':Vector3(16,0,10),'EnemySpawn_E':Vector3(31.2,0,10),'EnemySpawn_N':Vector3(16,0,.6),'EnemySpawn_S':Vector3(16,0,19.4)}:
				var marker:=Marker3D.new();marker.name=key
				marker.position={'PlayerSpawn':Vector3(16,0,10),'EnemySpawn_E':Vector3(31.2,0,10),'EnemySpawn_N':Vector3(16,0,.6),'EnemySpawn_S':Vector3(16,0,19.4)}[key]
				spawns.add_child(marker);marker.owner=scene
			var packed:=PackedScene.new();assert(packed.pack(scene)==OK)
			var path: String='res://scenes/maps/Map_'+map_name+('_Raid' if raid else '')+'.tscn'
			assert(ResourceSaver.save(packed,path)==OK);print('Built ',path);scene.free()
	quit()
