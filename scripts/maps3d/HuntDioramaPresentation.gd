extends Node3D
## Presentation only: foreground depth, mobile fog and actor-safe occlusion.
## No collision nodes, gameplay positions, timers or random-number calls.
const FADE = preload('res://shaders/FadeNearCamera.gdshader')
const FERN = preload('res://assets/maps3d/baked/fern.res')
const ROCK = preload('res://assets/maps3d/baked/rock0.res')
const ANCHORS = [Vector2(.025,.99),Vector2(.13,1.025),Vector2(.87,1.025),Vector2(.975,.99)]
var field: Control
var clusters: Array[Node3D] = []
var materials: Array[ShaderMaterial] = []
var actor_areas: Array[Rect2] = []

func setup(battlefield: Control) -> void:
	field=battlefield
	name='HuntDioramaPresentation'
	_configure_atmosphere()
	for i in ANCHORS.size():
		var cluster:=Node3D.new();cluster.name='Foreground'+str(i);add_child(cluster)
		var material:=ShaderMaterial.new();material.shader=FADE
		var forest: bool=field.zone_id=='moonrest_forest'
		material.set_shader_parameter('vertex_tint',forest)
		material.set_shader_parameter('tint',Color('#b5c99f') if forest else (Color('#814938') if field.zone_id=='forgotten_mine' else Color('#496a87')))
		for j in 3:
			var prop:=MeshInstance3D.new();prop.mesh=FERN if forest else ROCK
			prop.material_override=material;prop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			prop.position=Vector3((j-1)*.65,-.25,absf(j-1)*.35)
			prop.rotation.y=(i*1.17+j*.83)
			prop.scale=Vector3.ONE*(2.7 if forest else 1.4)*(1.0-j*.14)
			cluster.add_child(prop)
		clusters.append(cluster);materials.append(material)

func _configure_atmosphere() -> void:
	# Depth fog works on Mobile; do not force unsupported volumetric rendering.
	for node in field.map_root.find_children('*','WorldEnvironment',true,false):
		if node.environment==null:continue
		node.environment=node.environment.duplicate(false)
		var environment: Environment=node.environment
		environment.volumetric_fog_enabled=false
		if RenderingServer.get_current_rendering_method()!='gl_compatibility':
			environment.fog_enabled=true
			environment.fog_density=.0014 if field.zone_id=='forgotten_mine' else .0018
			environment.fog_light_color=Color('#bd9b82') if field.zone_id=='forgotten_mine' else (Color('#667e87') if field.zone_id=='moonrest_forest' else Color('#7292ae'))
			environment.fog_sky_affect=0.0
			environment.background_color=Color('#644338') if field.zone_id=='forgotten_mine' else (Color('#1a343a') if field.zone_id=='moonrest_forest' else Color('#132f49'))
		if RenderingServer.get_current_rendering_method()!='forward_plus':
			environment.ssao_enabled=false;environment.ssil_enabled=false

func update_foreground() -> void:
	if field.size.x<1 or field.size.y<1:return
	actor_areas.clear()
	for actor in field.actors.values():
		if not actor.visible:continue
		var point:=Vector2(actor.position.x,actor.position.z)
		var foot: Vector2=field.project_world(point)
		var head: Vector2=field.project_world(point,field.HERO_HEIGHT+.7)
		var half_width:=maxf(28,field.HERO_HEIGHT*field.size.y/field.camera.size*.85)
		actor_areas.append(Rect2(Vector2(foot.x-half_width,head.y-12),Vector2(half_width*2,maxf(32,foot.y-head.y+24))))
	var unit: float=field.camera.size/20.0
	for i in clusters.size():
		# Outer frame follows camera in world space, with slower lateral motion.
		var screen: Vector2=ANCHORS[i]*field.size
		screen.x+=(field.focus.x-16)*2.0
		var point: Vector2=field.local_to_world(screen)
		clusters[i].position=Vector3(point.x,0,point.y)
		clusters[i].scale=Vector3.ONE*unit
		var area:=_screen_bounds(clusters[i]).grow(12)
		var opacity:=1.0
		for actor_area in actor_areas:
			if area.intersects(actor_area):opacity=.12;break
		materials[i].set_shader_parameter('visibility',opacity)

func _screen_bounds(cluster: Node3D) -> Rect2:
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
	for prop: MeshInstance3D in cluster.get_children():
		var box:=prop.get_aabb()
		for i in 8:
			var point: Vector2=field.camera.unproject_position(prop.global_transform*box.get_endpoint(i))*field._projection_scale()
			low=low.min(point);high=high.max(point)
	return Rect2(low,high-low)
