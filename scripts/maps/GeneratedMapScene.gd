extends RefCounted
## Gallery/legacy loader adapter. Default game fields use the same builders.
static func build(zone: String,parent: Node,raid: bool) -> Node3D:
	var root:=Node3D.new();root.name='EmptyRaidWorld' if raid else 'RuneStoneHuntWorld'
	root.set_meta('map_design_removed',true);root.set_meta('auto_map_rebuilt',true);root.set_meta('zone',zone);root.set_meta('raid',raid)
	var world:=Node3D.new();world.name='Arena';root.add_child(world)
	var camera:=Camera3D.new();camera.name='BattleCamera';camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=34;camera.near=.05;camera.far=220;camera.current=true;world.add_child(camera)
	camera.position=Vector3(16,40,54)
	var atmosphere:=WorldEnvironment.new();atmosphere.name='Atmosphere'
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color('#29313a')
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=.38
	env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	atmosphere.environment=env;world.add_child(atmosphere)
	var sun:=DirectionalLight3D.new();sun.name='AutoMapSun';sun.rotation_degrees=Vector3(-55,-28,0)
	sun.light_energy=.90;sun.light_color=Color.WHITE;sun.shadow_enabled=true;world.add_child(sun)
	parent.add_child(root)
	camera.look_at(Vector3(16,0,10))
	if not raid:
		var ground:=preload('res://scripts/maps/RuneStoneGround.gd').new();ground.zone_id=zone;world.add_child(ground)
		root.set_meta('map_design_removed',false)
	var region:=NavigationRegion3D.new();region.name='NavigationRegion3D'
	var nav:=NavigationMesh.new();nav.vertices=PackedVector3Array([Vector3(.35,0,.35),Vector3(31.65,0,.35),Vector3(31.65,0,19.65),Vector3(.35,0,19.65)])
	nav.add_polygon(PackedInt32Array([0,3,2,1]));nav.agent_radius=.25;nav.agent_height=2;region.navigation_mesh=nav;root.add_child(region)
	var spawns:=Node3D.new();spawns.name='SpawnPoints';root.add_child(spawns)
	var entries: Dictionary={'PlayerSpawn':Vector3(16,0,10),'EnemySpawn_E':Vector3(31.2,0,10),'EnemySpawn_W':Vector3(.6,0,10),'EnemySpawn_N':Vector3(16,0,.6),'EnemySpawn_S':Vector3(16,0,19.4)}
	for label: String in entries:
		var marker:=Marker3D.new();marker.name=label;marker.position=entries[label];spawns.add_child(marker)
	return root
