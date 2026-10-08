extends "res://scripts/maps/MapTerrainRenderer.gd"
## Real 3D world embedded beneath the existing battle UI. Battle simulation owns
## the coordinates; both sprite billboards and 2D effects use this camera.
const HERO_SKIN=preload('res://scripts/maps3d/HeroSkeletalBillboard.gd')
const FRAME_PILOT=preload('res://scripts/art/HuntFramePilot.gd')
const MODEL_PILOT=preload('res://scripts/art/Model3DPilot.gd')
const MOBILE_PILOT=preload('res://scripts/art/MobileReliefPilot.gd')
const CAMERA_MOTION=preload('res://scripts/maps3d/MobileCameraMotion.gd')
const MAP_LOADER=preload('res://scripts/maps/MapLoader.gd')
const FRAMING=preload('res://scripts/maps3d/CombatCameraFraming.gd')
const HEALTH_LAYOUT=preload('res://scripts/maps3d/CombatHealthLayout.gd')
const BODY_LAYOUT=preload('res://scripts/maps3d/CombatBodyLayout.gd')
const HEALTH_OVERLAY=preload('res://scripts/maps3d/CombatHealthOverlay.gd')
const HUNT_OVERLAY=preload('res://scripts/maps3d/HuntCombatOverlay.gd')
const MOTION=preload('res://scripts/maps3d/HuntMotionPresentation.gd')
const CONTACT_SHADOW=preload('res://shaders/PaintedContactShadow.gdshader')
const FIELD_PALETTE=preload('res://scripts/maps/FieldArtCatalog.gd')
const STONE_GROUND=preload('res://scripts/maps/RuneStoneGround.gd')
const CAMERA_OFFSET=Vector3(0,40,28)
const HUNT_CAMERA_OFFSET=Vector3(0,.7071068,.7071068) # Requested 45 degree view.
const HERO_HEIGHT=2.05
const RAID_HERO_HEIGHT=4.20
const RAID_BOSS_HEIGHT=5.10
const ENEMY_HEIGHT=1.20
const HUNT_BODY_SCALE=.28
const RAID_BODY_SCALE=.46
var game: Node
var raid_view: Node
var raid_mode:=false
var viewport_3d: SubViewport
var camera: Camera3D
var map_root: Node3D
var map_loader: Node
var world: Node3D
var actors: Dictionary={}
var animate_environment:=true
var raid_factor:=1.0
var focus:=Vector2(16,10)
var _camera_initialized:=false
var _health_entries: Array[Dictionary]=[]
var _health_links: Array[PackedVector2Array]=[]
var _health_overlay: Control
var hunt_overlay: Control
var _presentation_clock:=0.0
var _last_footstep: Dictionary={}
var _last_death: Dictionary={}
var _impact_age:=1.0
var _impact_duration:=.16
var _impact_strength:=0.0
const RAID_PIVOT:=Vector2(519,383)
const RAID_UNITS:=26.0
const RAID_BOTTOM_CLEARANCE:=102.0
const RAID_BOSS_PIXELS:=179.2 # Original 128px body x requested final 1.4.
var presentation_visible := true
var presentation_suspended := false
var _render_profile := ""
var _render_container: SubViewportContainer
var _render_defaults: Dictionary = {}
var diorama: Node3D
var ultimate_details: Node3D
var rune_ground: Node3D
var frame_pilot_enabled := true
var real_models_enabled := false # Art review: original paintings are the default 2.5D cast.
var _actor_delta := 0.0
var _frame_events: Dictionary = {}
var _frame_catalog:=FRAME_PILOT.CATALOG.new()
var _body_scales: Dictionary={}
var _source_attacks: Dictionary={}
var _paint_rects: Dictionary={}
var mobile_camera:=CAMERA_MOTION.new()
var _camera_base_v:=0.0
var _rest_camera_size:=0.0
var _raid_boss_top_cache: Dictionary={}
var hunt_interpolation:=preload('res://scripts/maps3d/HuntRenderInterpolation.gd').new()
var _hunt_before: Dictionary={}
var _hunt_display: Dictionary={}
var _render_hero_points: Dictionary={}
var _render_enemy_indices: Dictionary={}
var skill_overlay: Control
var contact_flash: Control
var _contact_holds: Dictionary={}
var _contact_hold_cooldowns: Dictionary={}
var _crit_visual_until_us:=0
func _hunt_points() -> Dictionary:
	var points: Dictionary={}
	for i in mini(game.hero_map_sprites.size(),game.deployed_heroes.size()):
		var source=game.hero_map_sprites[i]
		if is_instance_valid(source):points[source.get_instance_id()]=game._hero_field_position(str(game.deployed_heroes[i].id))
	for i in mini(game.enemy_wave_sprites.size(),game.enemy_wave.size()):
		var source=game.enemy_wave_sprites[i]
		if is_instance_valid(source):points[source.get_instance_id()]=game.roaming_hunt.enemy_position(i)
	return points
func _hunt_states() -> Dictionary:
	var states: Dictionary={}
	for source in game.hero_map_sprites+game.enemy_wave_sprites:
		if is_instance_valid(source):states[source.get_instance_id()]=source.state=='death'
	return states
func begin_hunt_step() -> void:_hunt_before=_hunt_points()
func finish_hunt_step(seconds: float) -> void:
	hunt_interpolation.capture(_hunt_before,_hunt_points(),_hunt_states(),seconds)
func display_world(source: AnimatedSprite2D,fallback: Vector2) -> Vector2:
	return _hunt_display.get(source.get_instance_id(),fallback) if is_instance_valid(source) and not raid_mode else fallback
func _prepare_hunt_display() -> void:
	if raid_mode:return
	var remainder: float=game._ordinary_hunt_accumulator+Engine.get_physics_interpolation_fraction()*Engine.time_scale/maxi(1,Engine.physics_ticks_per_second)
	_hunt_display=hunt_interpolation.sample(_hunt_points(),_hunt_states(),remainder/hunt_interpolation.duration,battle_clock_running())
	_render_hero_points.clear();_render_enemy_indices.clear()
	for i in mini(game.hero_map_sprites.size(),game.deployed_heroes.size()):
		var id: String=str(game.deployed_heroes[i].id)
		if int(game.hero_battle_state.get(id,{}).get('hp',0))>0:_render_hero_points[id]=display_world(game.hero_map_sprites[i],game._hero_field_position(id))
	for i in game.enemy_wave_sprites.size():
		if is_instance_valid(game.enemy_wave_sprites[i]):_render_enemy_indices[game.enemy_wave_sprites[i].get_instance_id()]=i
func apply_render_profile() -> void:
	if not is_instance_valid(viewport_3d) or not is_instance_valid(game):return
	var battery: bool=str(game.presentation_options.get('performance','balanced'))=='battery'
	var key: String='battery' if battery else 'balanced'
	if key!=_render_profile:
		_render_profile=key
		viewport_3d.msaa_3d=Viewport.MSAA_DISABLED if battery else Viewport.MSAA_2X
		viewport_3d.positional_shadow_atlas_size=256 if battery else (1024 if raid_mode else 2048)
		viewport_3d.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
		viewport_3d.scaling_3d_scale=1.0
		viewport_3d.anisotropic_filtering_level=Viewport.ANISOTROPY_4X if battery else Viewport.ANISOTROPY_16X
		if is_instance_valid(_render_container):_render_container.stretch_shrink=2 if battery else 1
		for node in map_root.find_children('*','DirectionalLight3D',true,false):
			if not _render_defaults.has(node):_render_defaults[node]=node.shadow_enabled
			node.shadow_enabled=false if battery else bool(_render_defaults[node])
		for node in map_root.find_children('*','WorldEnvironment',true,false):
			var environment: Environment=node.environment
			if environment==null:continue
			if not _render_defaults.has(environment):
				_render_defaults[environment]={'ssao_enabled':environment.ssao_enabled,'ssil_enabled':environment.ssil_enabled,'sdfgi_enabled':environment.sdfgi_enabled,'glow_enabled':environment.glow_enabled,'volumetric_fog_enabled':environment.volumetric_fog_enabled}
			for property in _render_defaults[environment]:environment.set(property,false if battery else _render_defaults[environment][property])
	viewport_3d.render_target_update_mode=SubViewport.UPDATE_ALWAYS if presentation_visible and not presentation_suspended else SubViewport.UPDATE_DISABLED
	if is_instance_valid(ultimate_details):ultimate_details.apply_profile()
func set_presentation_visible(value: bool) -> void:
	presentation_visible=value;apply_render_profile()
func set_presentation_suspended(value: bool) -> void:
	presentation_suspended=value;apply_render_profile()
func _projection_scale() -> Vector2:
	return size/Vector2(viewport_3d.size) if is_instance_valid(viewport_3d) else Vector2.ONE
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	var container:=SubViewportContainer.new();container.name='Live3DViewport';container.stretch=true
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(container)
	_render_container=container
	var post:=ShaderMaterial.new();post.shader=preload('res://shaders/MobileBattlePost.gdshader');container.material=post
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_3d=SubViewport.new();viewport_3d.name='World3D';viewport_3d.own_world_3d=true
	viewport_3d.msaa_3d=Viewport.MSAA_2X;viewport_3d.positional_shadow_atlas_size=1024
	viewport_3d.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport_3d)
	map_loader=MAP_LOADER.new();map_loader.name='MapLoader';add_child(map_loader)
	map_root=_create_map_root()
	if map_root==null:return
	world=map_root.get_node('Arena');camera=world.get_node('BattleCamera')
	if not raid_mode:
		rune_ground=STONE_GROUND.new();rune_ground.field=self;world.add_child(rune_ground)
	hunt_overlay=HUNT_OVERLAY.new();hunt_overlay.name='HuntCombatOverlay';hunt_overlay.terrain=self
	hunt_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(hunt_overlay)
	hunt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_overlay=preload('res://scripts/presentation/HeroSkillVfxPresenter.gd').new();skill_overlay.name='HeroSkillVfx';skill_overlay.field=self
	skill_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(skill_overlay);skill_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contact_flash=preload('res://scripts/maps3d/ContactScreenFlash.gd').new();contact_flash.field=self;add_child(contact_flash);contact_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ambient_dust:=preload('res://scripts/maps3d/MobileAmbientDust.gd').new();ambient_dust.field=self;ambient_dust.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(ambient_dust);ambient_dust.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health_overlay=HEALTH_OVERLAY.new();_health_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_health_overlay);_health_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	_apply_battle_contrast()
	resized.connect(_resize_world);_resize_world()
	# Runs after the source AnimatedSprite2D controllers and HUD positions update.
	process_priority=100
	for environment_node in map_root.find_children("*","WorldEnvironment",true,false):
		if environment_node.environment!=null:environment_node.environment=environment_node.environment.duplicate(false)
	preload('res://scripts/maps3d/MythicDetailProfile.gd').configure(map_root)
	add_to_group("game_battlefields");apply_render_profile()
func _create_map_root() -> Node3D:
	return _create_generated_map_root()
func _create_generated_map_root() -> Node3D:
	# AutoMap Fix: start from a fresh arena; old hunting PackedScenes are not loaded.
	var root:=Node3D.new();root.name='AutoRaidMap' if raid_mode else 'AutoHuntMap';root.set_meta('auto_map_rebuilt',true);root.set_meta('map_design_removed',false)
	var arena_root:=Node3D.new();arena_root.name='Arena';root.add_child(arena_root)
	var next_camera:=Camera3D.new();next_camera.name='BattleCamera'
	next_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;next_camera.near=.05;next_camera.far=220;next_camera.current=true
	arena_root.add_child(next_camera)
	var environment_node:=WorldEnvironment.new();environment_node.name='Atmosphere'
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color('#29313a');environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	var palette: Dictionary=FIELD_PALETTE.lighting(zone_id)
	environment.ambient_light_color=palette.ambient
	environment.ambient_light_energy=.48;environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var reflection_sky:=Sky.new();var sky_paint:=ProceduralSkyMaterial.new()
	sky_paint.sky_top_color=Color('#7894ae');sky_paint.sky_horizon_color=Color('#d1dae1')
	sky_paint.ground_bottom_color=Color('#323c43');sky_paint.ground_horizon_color=Color('#a6b6bb')
	reflection_sky.sky_material=sky_paint;environment.sky=reflection_sky
	environment.tonemap_mode=Environment.TONE_MAPPER_ACES;environment.tonemap_exposure=1.02
	environment.glow_enabled=RenderingServer.get_current_rendering_method()=='forward_plus'
	environment.glow_intensity=.45;environment.glow_strength=.9;environment.glow_bloom=.06
	if RenderingServer.get_current_rendering_method()=='forward_plus':
		environment.sdfgi_enabled=true;environment.sdfgi_cascades=4;environment.sdfgi_min_cell_size=.8;environment.sdfgi_bounce_feedback=0.0
	environment_node.environment=environment;arena_root.add_child(environment_node)
	var sun:=DirectionalLight3D.new();sun.name='AutoMapSun';sun.rotation_degrees=Vector3(-55,-28,0)
	sun.light_energy=.9;sun.light_color=palette.sun
	sun.shadow_enabled=true;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	arena_root.add_child(sun)
	var model_path: String='res://assets/models3d-v1/environments/'+zone_id+('_raid' if raid_mode else '_hunt')+'.glb'
	var model_scene=load(model_path) as PackedScene
	assert(model_scene!=null,'Missing real 3D environment: '+model_path)
	var environment_model=model_scene.instantiate();environment_model.name='EnvironmentModel';arena_root.add_child(environment_model)
	var floor_material: StandardMaterial3D
	for mesh: MeshInstance3D in environment_model.find_children('*','MeshInstance3D',true,false):
		mesh.gi_mode=GeometryInstance3D.GI_MODE_STATIC
		var floor_only:=true
		for index in mesh.mesh.get_surface_count():
			var original=mesh.get_active_material(index) as StandardMaterial3D
			if original==null or not original.resource_name.ends_with(' floor'):floor_only=false;continue
			var stone=original.duplicate() as StandardMaterial3D
			stone.albedo_color=Color.WHITE
			stone.albedo_texture=load('res://assets/mobile25d/floor/stone_1024_albedo_ao.png')
			stone.normal_enabled=true;stone.normal_scale=.28
			stone.normal_texture=load('res://assets/mobile25d/floor/stone_1024_normal.png')
			stone.roughness=.58;stone.metallic=.32;stone.roughness_texture=null
			stone.uv1_scale=Vector3(10,7,1)
			stone.ao_enabled=true;stone.ao_texture=stone.albedo_texture;stone.ao_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
			stone.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			floor_material=stone
			var hidden_floor:=StandardMaterial3D.new();hidden_floor.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;hidden_floor.albedo_color=Color(0,0,0,0)
			mesh.set_surface_override_material(index,hidden_floor)
		if floor_only:mesh.hide()
	if floor_material!=null:
		var slabs:=MeshInstance3D.new();slabs.name='PBRStoneSlabs1024'
		var plane:=PlaneMesh.new();plane.size=Vector2(80,60);slabs.mesh=plane;slabs.position=Vector3(16,0,10)
		floor_material.uv1_scale=Vector3(80.0/36.0*10,60.0/24.0*7,1)
		slabs.material_override=floor_material;slabs.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;arena_root.add_child(slabs)
	root.set_meta('environment_model',model_path)
	viewport_3d.add_child(root)
	return root
func configure(next_zone_id: String,next_zone_color: Color) -> void:
	zone_id=next_zone_id;zone_color=next_zone_color
func configure_world_view(ppu: float,anchor: Vector2) -> void:
	pixels_per_unit=ppu;local_anchor=anchor
func set_camera_position(_world_position: Vector2) -> void: pass
func _resize_world() -> void:
	if not is_instance_valid(camera) or size.x<1 or size.y<1:return
	if raid_mode:
		# Keep every reachable floor point and the boss's head inside the stage.
		# The original combat-coordinate transform remains shared with warnings.
		var safe_size:=Vector2(maxf(1,size.x-36),maxf(1,size.y-RAID_BOTTOM_CLEARANCE))
		raid_factor=minf(safe_size.x/674.0,safe_size.y/340.0)*CAMERA_MOTION.ZOOM
		_set_focus(Vector2(16,10))
		camera.size=size.y/(RAID_UNITS*raid_factor)
		camera.v_offset=(-5.0+57.0*raid_factor)/(RAID_UNITS*raid_factor)
		# Measure the real floor projection; preserve actor/telegraph scale and
		# leave the enlarged dodge/follow strip below every reachable point.
		var floor_end: Vector2=preload("res://scripts/raid/RaidBattlefield.gd").FLOOR.end
		var excess:=project_world(raid_to_world(floor_end)).y-(size.y-RAID_BOTTOM_CLEARANCE)
		if excess>0.0:camera.v_offset-=excess/(RAID_UNITS*raid_factor)
		var boss: Vector2=raid_to_world(game.raid_boss_position) if is_instance_valid(game) else raid_to_world(Vector2(650,383))
		camera.v_offset+=maxf(0,_raid_boss_top_pixels()-project_world(boss).y)*camera.size/size.y
		_camera_base_v=camera.v_offset
	else:
		_update_hunt_camera(0.0,true)
		_camera_base_v=0.0
	_rest_camera_size=camera.size

func _raid_boss_top_pixels() -> float:
	# A fixed 179.2px native height does not bound the raised weapon/wing in
	# every attack pose. Reserve the whole atlas above its foot pivot, without
	# changing the original's scale. The existing catalog and this three-boss
	# identity cache avoid reading/parsing frame JSON in the render loop.
	if not is_instance_valid(game) or not is_instance_valid(game.raid_boss_sprite):return RAID_BOSS_PIXELS+2.0
	var identity: String=FRAME_PILOT.CATALOG.identity(game.raid_boss_sprite,false)
	if _raid_boss_top_cache.has(identity):return float(_raid_boss_top_cache[identity])
	var top:=RAID_BOSS_PIXELS
	var entry: Dictionary=_frame_catalog.load_entry(identity)
	for kind in ['attack','motion']:
		var sheet: Dictionary=entry.get(kind,{})
		var native_height:=float(sheet.get('native_height',0))
		if native_height<=0:continue
		for frame: Dictionary in sheet.get('frames',[]):
			var anchor: Array=frame.get('anchor',[])
			if anchor.size()==2:top=maxf(top,float(anchor[1])/native_height*RAID_BOSS_PIXELS)
	top+=2.0 # The boss's maximum breathing displacement.
	if not identity.is_empty():_raid_boss_top_cache[identity]=top
	return top

func _set_focus(point: Vector2) -> void:
	focus=point
	var target:=Vector3(point.x,0,point.y)
	# Orthographic framing changes angle, not distance. Preserve enough camera
	# clearance so actor billboards cannot cross the near plane.
	var offset: Vector3=HUNT_CAMERA_OFFSET.normalized()*CAMERA_OFFSET.length()
	camera.position=target+offset
	camera.look_at(target)

func camera_points() -> Array[Vector3]:
	var points: Array[Vector3]=[]
	if not is_instance_valid(game):return points
	for hero_index in game.deployed_heroes.size():
		var hero=game.deployed_heroes[hero_index]
		var id:=str(hero.id)
		if float(game.hero_battle_state.get(id,{}).get('hp',1))<=0:continue
		var point: Vector2=game._hero_field_position(id)
		if hero_index<game.hero_map_sprites.size():point=display_world(game.hero_map_sprites[hero_index],point)
		points.append(Vector3(point.x,0,point.y))
		var height:=HERO_HEIGHT
		if hero_index<game.hero_map_sprites.size():height=_actor_height(game.hero_map_sprites[hero_index],true)
		points.append(Vector3(point.x,height*1.35+.25,point.y))
	# Follow the party and its target. Distant arriving waves must not zoom
	# every hero out; their simulation keeps running beyond the camera.
	for i in game.enemy_wave.size():
		if not game.roaming_hunt.aggro_active:continue
		if i!=game.roaming_hunt.current_target:continue
		if float(game.enemy_wave[i].get('hp',0))<=0:continue
		var point: Vector2=game.roaming_hunt.enemy_position(i)
		if i<game.enemy_wave_sprites.size():point=display_world(game.enemy_wave_sprites[i],point)
		var height:=ENEMY_HEIGHT
		if i<game.enemy_wave_sprites.size():height=_actor_height(game.enemy_wave_sprites[i],false)
		var candidate: Array[Vector3]=points.duplicate()
		candidate.append(Vector3(point.x,0,point.y));candidate.append(Vector3(point.x,height*1.35+.25,point.y))
		if float(FRAMING.fit(candidate,size,HUNT_CAMERA_OFFSET.normalized().y).size)<=_hunt_zoom():points=candidate
	return points

func _hunt_zoom() -> float:return maxf(4.8,6.0/maxf(.1,size.x/maxf(1,size.y)))/CAMERA_MOTION.ZOOM

func _update_hunt_camera(delta: float,snap:=false) -> void:
	if not is_instance_valid(camera) or size.x<1 or size.y<1:return
	var sine:=HUNT_CAMERA_OFFSET.normalized().y
	var frame: Dictionary=FRAMING.fit(camera_points(),size,sine)
	var next: Vector2=frame.center
	if not snap and _camera_initialized:
		# A small dead zone prevents idle/attack animation from steering the view.
		if focus.distance_to(next)<.18:next=focus
		else:next=focus.lerp(next,1.0-exp(-maxf(delta,0)*3.0))
	# Pan enough to keep party heads/feet inside the fixed zoom. A remote target
	# cannot drag the party off screen or force the old breathing zoom behavior.
	var half:=Vector2(_hunt_zoom()*size.x/size.y,_hunt_zoom())*.5
	var bounds: Rect2=frame.bounds
	var low:=bounds.end-half;var high:=bounds.position+half
	var plane:=Vector2(next.x,next.y*sine)
	if low.x<=high.x:plane.x=clampf(plane.x,low.x,high.x)
	if low.y<=high.y:plane.y=clampf(plane.y,low.y,high.y)
	next=Vector2(plane.x,plane.y/sine)
	_set_focus(next)
	camera.v_offset=0
	# Follow combat without changing the pixel height whenever a target arrives,
	# dies or crosses the party. Only a viewport resize changes this zoom.
	camera.size=_hunt_zoom()
	_camera_initialized=true

func _apply_battle_contrast() -> void:pass

func _draw() -> void:pass
func project_world(point: Vector2,height: float=0.0) -> Vector2:
	if not is_instance_valid(camera):return size*.5
	return camera.unproject_position(Vector3(point.x,height,point.y))*_projection_scale()
func local_to_world(point: Vector2) -> Vector2:
	if not is_instance_valid(camera):return Vector2(16,10)
	var render_point:=point/_projection_scale()
	var origin:=camera.project_ray_origin(render_point);var ray:=camera.project_ray_normal(render_point)
	if absf(ray.y)<.0001:return focus
	var hit:=origin-ray*(origin.y/ray.y)
	return Vector2(hit.x,hit.z)
func visible_world_rect() -> Rect2:
	var a:=local_to_world(Vector2.ZERO);var b:=local_to_world(size)
	return Rect2(a,b-a).abs()
func raid_to_world(point: Vector2) -> Vector2:
	var sin_pitch: float=absf(camera.global_basis.z.y)
	return Vector2(16,10)+(point-RAID_PIVOT)/Vector2(RAID_UNITS,RAID_UNITS*sin_pitch)
func world_to_raid(point: Vector2) -> Vector2:
	return RAID_PIVOT+(point-Vector2(16,10))*Vector2(RAID_UNITS,RAID_UNITS*absf(camera.global_basis.z.y))
func raid_projection_factor() -> float:return size.y/maxf(.001,camera.size*RAID_UNITS)
func raid_origin() -> Vector2:
	return project_world(Vector2(16,10))-RAID_PIVOT*raid_projection_factor()
func _process(delta: float) -> void:
	# A deferred resize can briefly leave the replacement viewport at zero size.
	# Wait for layout before projection/crowd fitting can produce 0/0 transforms.
	if not is_instance_valid(game) or not is_instance_valid(camera) or size.x<1 or size.y<1:return
	_actor_delta=maxf(0.0,delta)
	apply_render_profile()
	_prepare_hunt_display()
	if visual_running():_presentation_clock+=maxf(0,delta)*visual_speed()
	if not raid_mode:_update_hunt_camera(delta)
	var speed:=visual_speed() if visual_running() else 0.0
	var animated: Array=(raid_view.hero_actors.values()+[game.raid_boss_sprite]) if raid_mode and is_instance_valid(raid_view) else game.hero_map_sprites+game.enemy_wave_sprites
	for actor in animated:
		if is_instance_valid(actor):
			actor.speed_scale=speed
			if actor is MonsterSpriteController:actor.set_process(speed>0)
	if not raid_mode:
		if speed>0:_impact_age+=maxf(0,delta)*speed
	var camera_active: bool=battle_clock_running()
	var offsets:=mobile_camera.advance(delta/maxf(.001,Engine.time_scale),camera_active,game.combat_effects_enabled)
	var punch: float=mobile_camera.zoom_punch(game.combat_effects_enabled)
	if _rest_camera_size<=0:_rest_camera_size=camera.size
	if not raid_mode:_rest_camera_size=camera.size
	elif is_instance_valid(game.raid_boss_sprite):
		camera.size=_rest_camera_size
		var boss_point: Vector2=raid_to_world(game.raid_boss_sprite.position)
		var desired:=Vector2(16,10).lerp(boss_point,.22)
		if battle_clock_running():_set_focus(focus.lerp(desired,1-exp(-maxf(0,delta)*2.0)))
		var floor_point: Vector2=raid_to_world(preload('res://scripts/raid/RaidBattlefield.gd').FLOOR.end)
		var below_boss: float=project_world(floor_point).y-project_world(boss_point).y
		var available: float=maxf(1,size.y-RAID_BOTTOM_CLEARANCE-12-_raid_boss_top_pixels())
		if below_boss*punch>available:
			var fit: float=below_boss*punch/available
			_rest_camera_size*=fit;raid_factor/=fit
	camera.size=_rest_camera_size/punch
	var units: float=camera.size/size.y
	camera.h_offset=offsets.x*units;camera.v_offset=_camera_base_v-offsets.y*units
	if raid_mode and is_instance_valid(game.raid_boss_sprite):
		# The boss is positioned after initial layout; guard its actual head too.
		var head: float=project_world(raid_to_world(game.raid_boss_sprite.position)).y-_raid_boss_top_pixels()
		var padding: float=maxf(0,12.0-head)*units
		_camera_base_v+=padding;camera.v_offset+=padding
		var end: float=project_world(raid_to_world(preload('res://scripts/raid/RaidBattlefield.gd').FLOOR.end)).y
		var lift: float=minf(maxf(0,end-(size.y-RAID_BOTTOM_CLEARANCE)),maxf(0,head+padding/units-12))
		_camera_base_v-=lift*units;camera.v_offset-=lift*units
	if raid_mode and is_instance_valid(raid_view) and is_instance_valid(raid_view.arena):
		raid_view.arena.scale=Vector2.ONE*raid_projection_factor()
		raid_view.arena.position=raid_origin()
	var live: Dictionary={}
	_health_entries.clear()
	_health_links.clear()
	_update_body_layout(delta)
	if not raid_mode:
		var top:=INF;var bottom:=-INF
		for source in game.hero_map_sprites:
			if not is_instance_valid(source) or source.state=='death':continue
			var rect: Rect2=_paint_rects.get(source.get_instance_id(),Rect2())
			if not rect.has_area():continue
			top=minf(top,rect.position.y-position.y);bottom=maxf(bottom,rect.end.y-position.y)
		if top<INF:
			var correction: float=maxf(0,8-top)-maxf(0,bottom-(size.y-8))
			camera.v_offset+=correction*units
			for id in _paint_rects:_paint_rects[id].position.y+=correction
	if raid_mode:
		if not is_instance_valid(raid_view):return
		var mood:=world.get_node_or_null('RaidDesign')
		if mood!=null and mood.has_method('set_battle_mood'):
			mood.set_battle_mood(int(game.raid_phase),bool(game.raid_enraged))
		for id in raid_view.hero_actors:
			var actor: AnimatedSprite2D=raid_view.hero_actors[id]
			if is_instance_valid(actor):sync_actor(actor,raid_to_world(actor.position),true,live)
		if is_instance_valid(game.raid_boss_sprite):sync_actor(game.raid_boss_sprite,raid_to_world(game.raid_boss_sprite.position),false,live)
	else:
		for i in game.hero_map_sprites.size():
			if i<game.deployed_heroes.size():
				var id: String=str(game.deployed_heroes[i]['id'])
				var point:=display_world(game.hero_map_sprites[i],game._hero_field_position(id))
				sync_actor(game.hero_map_sprites[i],point,true,live)
				var source: Node2D=game.hero_map_sprites[i]
				source.position=position+project_world(point)
				if game.hero_hp_bars.has(id):
					var paint: Rect2=_paint_rects.get(source.get_instance_id(),Rect2(source.position,Vector2.ZERO))
					_queue_health(game.hero_hp_bars[id],Vector2(source.position.x,paint.end.y+7),source.visible,
						float(game.hero_battle_state.get(id,{}).get('hp',0)),true,false)
		for i in game.enemy_wave_sprites.size():
			if i<game.enemy_wave.size():
				var point:=display_world(game.enemy_wave_sprites[i],game.roaming_hunt.enemy_position(i))
				sync_actor(game.enemy_wave_sprites[i],point,false,live)
				game.enemy_wave_sprites[i].position=position+project_world(point)
				if i<game.enemy_hp_bars.size():
					var source: AnimatedSprite2D=game.enemy_wave_sprites[i]
					var selected: bool=game.roaming_hunt.aggro_active and game.roaming_hunt.current_target==i
					var anchor: Vector2=source.position-Vector2(0,_actor_height(source,false)*size.y/camera.size+9)
					if _paint_rects.has(source.get_instance_id()):anchor.y=_paint_rects[source.get_instance_id()].position.y-9
					if selected:anchor=anchor.clamp(position+Vector2(24,18),position+size-Vector2(24,18))
					_queue_health(game.enemy_hp_bars[i],anchor,source.visible or selected,float(game.enemy_wave[i].get('hp',0)),false,selected)
		game._update_combat_target_marker()
		_layout_health()
		var marker: Label=game.combat_labels.get('target_marker')
		var target: int=game.roaming_hunt.current_target
		if is_instance_valid(marker) and marker.visible and target>=0 and target<game.enemy_wave_sprites.size():
			var source: AnimatedSprite2D=game.enemy_wave_sprites[target]
			marker.position=source.position-Vector2(39,_actor_height(source,false)*size.y/camera.size+32)
	for key in actors.keys():
		if not live.has(key):
			actors[key].free();actors.erase(key);_last_footstep.erase(key);_last_death.erase(key);_frame_events.erase(key)
			_contact_holds.erase(key)
			_contact_hold_cooldowns.erase(key)
	_health_overlay.links=_health_links
	_health_overlay.queue_redraw()
	if is_instance_valid(diorama):diorama.update_foreground()
	if is_instance_valid(ultimate_details):ultimate_details.update_occlusion()

func hunt_hit(point: Vector2,source: Vector2,tint: Color,critical: bool) -> void:
	if is_instance_valid(hunt_overlay):
		var height:=ENEMY_HEIGHT
		var victim: AnimatedSprite2D
		var nearest:=.36
		for index in mini(game.enemy_wave.size(),game.enemy_wave_sprites.size()):
			var distance: float=game.roaming_hunt.enemy_position(index).distance_squared_to(point)
			if distance<nearest:
				nearest=distance;height=_actor_height(game.enemy_wave_sprites[index],false);victim=game.enemy_wave_sprites[index]
				if distance<.00001:break
		hunt_overlay.hit(point,source,tint,critical,height)
		contact_feedback(critical,point,victim)
		if critical and game.combat_effects_enabled:
			for actor in game.hero_map_sprites:
				if is_instance_valid(actor) and actor.position.distance_to(position+project_world(source))<30:
					if not _uses_frame_pilot(actor,true):hunt_overlay.afterimage(actor,source,(point-source).normalized())
					break

func contact_feedback(critical: bool,point: Vector2,victim: AnimatedSprite2D=null) -> void:
	if not battle_clock_running():return
	if is_instance_valid(game.presentation_runtime):
		game.presentation_runtime.audio.play_positional('critical' if critical else 'hit',self,point)
		game.presentation_runtime.haptics.pulse('critical' if critical else 'hit')
	if not game.combat_effects_enabled:return
	mobile_camera.impact(critical)
	if is_instance_valid(victim) and victim.state!='death':
		var id:=victim.get_instance_id();var now:=Time.get_ticks_usec()
		if now>=int(_contact_hold_cooldowns.get(id,0)):
			_contact_holds[id]=now+80000
			_contact_hold_cooldowns[id]=now+200000
	if critical and Time.get_ticks_usec()>=_crit_visual_until_us:
		_crit_visual_until_us=Time.get_ticks_usec()+1500000
		contact_flash.flash()
		if is_instance_valid(game.presentation_runtime):game.presentation_runtime.contact_time.request(true)

func _uses_frame_pilot(source: AnimatedSprite2D,hero: bool) -> bool:
	if not frame_pilot_enabled:return false
	return not _frame_catalog.load_entry(FRAME_PILOT.CATALOG.identity(source,hero)).is_empty()

func frame_release(actor: AnimatedSprite2D,hero: bool,action: String,windup: float) -> void:
	if not is_instance_valid(actor) or not _uses_frame_pilot(actor,hero):return
	var id:=actor.get_instance_id();var pending: Dictionary=_frame_events.get(id,{})
	pending.release={'action':action,'windup':windup};_frame_events[id]=pending

func frame_hit(actor: AnimatedSprite2D,hero: bool,incoming: Vector2) -> void:
	if not is_instance_valid(actor) or not _uses_frame_pilot(actor,hero):return
	var id:=actor.get_instance_id();var pending: Dictionary=_frame_events.get(id,{})
	pending.hit=project_world(incoming)-project_world(Vector2.ZERO);_frame_events[id]=pending

func _frame_runtime(source: AnimatedSprite2D,hero: bool) -> Dictionary:
	if hero:
		var runtime: Dictionary=game.hero_skill_runtime.get(str(source.atlas_key),{}).duplicate()
		if raid_mode:return {}
		var prepared:=str(runtime.get('prepared_action','basic'))
		runtime.visual_action='ultimate' if prepared=='ultimate' else ('skill' if prepared in ['a1','a2'] else 'attack_1')
		return runtime
	if raid_mode:return {}
	var index: int=_render_enemy_indices.get(source.get_instance_id(),-1)
	if index<0 or index>=game.enemy_wave.size():return {}
	var enemy: Dictionary=game.enemy_wave[index]
	return {'windup':float(enemy.get('attack_remaining',0.0)) if enemy.has('attack_intent') else -1.0,'attack_windup_duration':.22,'visual_action':'attack_1'}

func _frame_dead(source: AnimatedSprite2D,hero: bool) -> bool:
	if hero:return int(game.hero_battle_state.get(str(source.atlas_key),{}).get('hp',0))<=0
	if raid_mode:return game.raid_boss_hp<=0
	var index: int=_render_enemy_indices.get(source.get_instance_id(),-1)
	return int(game.enemy_wave[index].get('hp',0))<=0 if index>=0 and index<game.enemy_wave.size() else source.state=='death'

func visual_running() -> bool:
	return battle_clock_running()
func battle_clock_running() -> bool:
	return presentation_visible and not presentation_suspended and is_instance_valid(game) and ((game.active_screen=='raid' and game.raid_running) if raid_mode else (game.active_screen=='combat' and game.combat_running)) and not game._application_suspended and not bool(game.get_meta('equipment_mail_paused',false)) and not preload('res://scripts/persistence/SaveSafety.gd').pending(game)

func visual_speed() -> float:
	return clampf(game.battle_speed,1,2) if is_finite(game.battle_speed) else 1.0

func camera_impact(intensity: float,duration: float,_zoom: float) -> void:
	# Only the world moves. Menus, touch coordinates and the party dock stay fixed.
	if not is_instance_valid(camera) or _impact_age<.18:return
	mobile_camera.impact(intensity>3.0)
	_impact_age=0;_impact_duration=clampf(duration,.10,.20)
	_impact_strength=minf(.085,maxf(0,intensity)*.015)

func _queue_health(bar: ProgressBar,anchor: Vector2,shown: bool,hp: float,hero: bool,selected: bool) -> void:
	if not is_instance_valid(bar):return
	# Healthy party members remain visible in the persistent party dock.
	bar.visible=shown and hp>0 and (bar.value<99.9 or selected)
	if not bar.visible:return
	bar.show_percentage=false
	bar.custom_minimum_size=Vector2.ZERO
	bar.size=Vector2(32 if selected else 26,5)
	_health_entries.append({'bar':bar,'anchor':anchor,'priority':(4 if selected else 0)+(2 if bar.value<30 else 0)+(1 if hero else 0)})

func _layout_health() -> void:
	_health_entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return a.priority>b.priority)
	var occupied: Array[Rect2]=[]
	for rect: Rect2 in _paint_rects.values():occupied.append(rect.grow(2))
	var bounds:=Rect2(position+Vector2(8,8),size-Vector2(16,16))
	for entry in _health_entries:
		var bar: ProgressBar=entry.bar
		var rect: Rect2=HEALTH_LAYOUT.place(entry.anchor,bar.size,occupied,bounds)
		if not rect.has_area():
			bar.hide()
			continue
		bar.position=rect.position
		occupied.append(rect)
		var tip:=rect.get_center()
		if absf(tip.y-entry.anchor.y)>8:
			_health_links.append(PackedVector2Array([entry.anchor-position,tip-position]))

func _base_actor_height(source: AnimatedSprite2D,hero: bool) -> float:
	if is_instance_valid(camera) and size.y>1:
		if hero:return 86.4*camera.size/size.y/(RAID_BODY_SCALE if raid_mode else HUNT_BODY_SCALE)
		if not raid_mode:return 40.0*camera.size/size.y/HUNT_BODY_SCALE
		return RAID_BOSS_PIXELS*camera.size/size.y/RAID_BODY_SCALE
	if raid_mode:
		# All hero originals share one height, independent of old sprite margins.
		return RAID_HERO_HEIGHT if hero else RAID_BOSS_HEIGHT
	if hero:return HERO_HEIGHT
	# Legacy spawn/hit tweens change the 2D source scale. The painted 3D actor
	# uses its rest height; fades and fallen poses express these states.
	return ENEMY_HEIGHT

func _actor_height(source: AnimatedSprite2D,hero: bool) -> float:
	return _base_actor_height(source,hero)*float(_body_scales.get(source.get_instance_id(),RAID_BODY_SCALE if raid_mode else HUNT_BODY_SCALE))

func actor_world_height(source: AnimatedSprite2D,hero: bool) -> float:
	return _actor_height(source,hero)/maxf(.5,camera.global_basis.y.y)

func _update_body_layout(_delta: float) -> void:
	if size.x<1 or size.y<1 or not is_instance_valid(camera) or camera.size<=0:return
	var items: Array[Dictionary]=[]
	# Existing renderers supply bounds on subsequent frames; bootstrap bounds
	# below are replaced by actual atlas margins/paint extents after binding.
	var sources: Array=[];var points: Array[Vector2]=[];var heroes: Array[bool]=[]
	if raid_mode and is_instance_valid(raid_view):
		for actor in raid_view.hero_actors.values():sources.append(actor);points.append(raid_to_world(actor.position));heroes.append(true)
		if is_instance_valid(game.raid_boss_sprite):sources.append(game.raid_boss_sprite);points.append(raid_to_world(game.raid_boss_sprite.position));heroes.append(false)
	elif not raid_mode:
		for i in mini(game.hero_map_sprites.size(),game.deployed_heroes.size()):sources.append(game.hero_map_sprites[i]);points.append(display_world(game.hero_map_sprites[i],game._hero_field_position(str(game.deployed_heroes[i].id))));heroes.append(true)
		for i in mini(game.enemy_wave_sprites.size(),game.enemy_wave.size()):sources.append(game.enemy_wave_sprites[i]);points.append(display_world(game.enemy_wave_sprites[i],game.roaming_hunt.enemy_position(i)));heroes.append(false)
	for i in sources.size():
		var source: AnimatedSprite2D=sources[i]
		if not is_instance_valid(source) or _frame_dead(source,heroes[i]) or source.state=='death' or source.modulate.a<.15:continue
		var id:=source.get_instance_id();var height:=_base_actor_height(source,heroes[i])
		var bounds:=Rect2(-height*.55,-height,height*1.1,height)
		var sprite: Sprite3D=actors.get(id)
		var left:=source.flip_h
		if sprite!=null:
			var pilot=sprite.get_node_or_null('Model3DPilot' if real_models_enabled else 'HuntFramePilot')
			if pilot!=null:
				bounds=pilot.footprint(height)
				if not real_models_enabled and pilot._facing_override:left=pilot._facing_left
		if left:bounds.position.x=-bounds.end.x
		var projection:=project_world(points[i])
		# Camera-aligned drawings have identical x/y scale in orthographic view.
		items.append({'id':id,'hero':heroes[i],'point':projection*camera.size/size.y,'bounds':bounds})
	var next: Dictionary={}
	var hero_scale:=RAID_BODY_SCALE if raid_mode else HUNT_BODY_SCALE
	for i in sources.size():
		var source: AnimatedSprite2D=sources[i]
		if not is_instance_valid(source):continue
		var id:=source.get_instance_id()
		next[id]=hero_scale
	_body_scales=next
	_paint_rects.clear()
	for item in items:
		var paint: Rect2=item.bounds
		var scale: float=next[item.id]*size.y/camera.size
		_paint_rects[item.id]=Rect2(position+item.point*size.y/camera.size+paint.position*scale,paint.size*scale)

func actor_head_offset(source: AnimatedSprite2D) -> Vector2:
	if not is_instance_valid(camera):return Vector2.ZERO
	return Vector2(0,-_actor_height(source,source is HeroSpriteController)*size.y/camera.size)

func _paint_facing_target(source: AnimatedSprite2D,point: Vector2,hero: bool) -> Dictionary:
	if raid_mode:
		if hero and is_instance_valid(game.raid_boss_sprite):return {'facing_target':raid_to_world(game.raid_boss_position)}
		var nearest:=INF;var result: Dictionary={}
		if is_instance_valid(raid_view):
			for id in raid_view.hero_actors:
				if float(game.hero_battle_state.get(id,{}).get('hp',0))<=0:continue
				var candidate:=raid_to_world(game.raid_positions.get(id,raid_view.hero_actors[id].position))
				if point.distance_squared_to(candidate)<nearest:
					nearest=point.distance_squared_to(candidate);result={'facing_target':candidate}
		return result
	if hero:
		var id:=str(source.atlas_key)
		var runtime: Dictionary=game.hero_skill_runtime.get(id,{})
		var index:=int(runtime.get('target_index',game.party_movement.targets.get(id,-1)))
		if index>=0 and index<game.enemy_wave.size() and float(game.enemy_wave[index].get('hp',0))>0:
			var target: Vector2=game.roaming_hunt.enemy_position(index)
			if index<game.enemy_wave_sprites.size():target=display_world(game.enemy_wave_sprites[index],target)
			return {'facing_target':target}
	else:
		var index: int=_render_enemy_indices.get(source.get_instance_id(),-1)
		if index>=0 and index<game.enemy_wave.size():
			var target:=str(game.enemy_wave[index].get('attack_intent',''))
			if target.is_empty():target=str(game.enemy_wave[index].get('target_id',''))
			if _render_hero_points.has(target):return {'facing_target':_render_hero_points[target]}
			var nearest:=INF;var result: Dictionary={}
			for candidate: Vector2 in _render_hero_points.values():
				if point.distance_squared_to(candidate)<nearest:
					nearest=point.distance_squared_to(candidate);result={'facing_target':candidate}
			return result
	return {}

func sync_actor(source: AnimatedSprite2D,point: Vector2,hero: bool,live: Dictionary) -> void:
	if not is_instance_valid(source) or source.sprite_frames==null:return
	if not source.sprite_frames.has_animation(source.animation):return
	if not raid_mode:
		# Re-evaluate visibility after a camera change, including while paused.
		source.visible=Rect2(Vector2.ZERO,size).grow(4).has_point(project_world(point))
	var id:=source.get_instance_id();live[id]=true
	var sprite: Sprite3D=actors.get(id)
	if sprite==null:
		sprite=Sprite3D.new();sprite.name='HeroBillboard' if hero else 'EnemyBillboard'
		sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.shaded=not raid_mode
		sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.12
		sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(sprite);actors[id]=sprite
		var shadow:=MeshInstance3D.new();shadow.name='ContactShadow'
		var footprint:=PlaneMesh.new();footprint.size=Vector2(1.08,.84);shadow.mesh=footprint
		var m:=ShaderMaterial.new();m.shader=CONTACT_SHADOW
		m.set_shader_parameter('baked_mask',load('res://assets/mobile25d/floor/contact_shadow_128.png'))
		shadow.material_override=m;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;sprite.add_child(shadow)
		var ring:=MeshInstance3D.new();ring.name='TeamFootRing'
		var torus:=TorusMesh.new();torus.inner_radius=.40;torus.outer_radius=.46;torus.rings=20;torus.ring_segments=6
		ring.mesh=torus
		var ring_material:=StandardMaterial3D.new();ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.albedo_color=Color('#79d8d0') if hero else Color('#dd967e')
		ring.material_override=ring_material;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y=.04;sprite.add_child(ring)
	var texture: Texture2D=source.sprite_frames.get_frame_texture(source.animation,source.frame)
	var frame_active: bool=_uses_frame_pilot(source,hero)
	# The container never draws an atlas when a whole-paint/model pilot owns it.
	# Avoid queuing a Sprite3D material update only to remove it in the same frame.
	sprite.texture=null if frame_active else texture
	var native: float=maxf(1,source.native_visual_height)
	var height: float=_actor_height(source,hero)
	sprite.pixel_size=height/native
	var canvas_offset: Vector2=source.offset if not source.centered else source.offset-texture.get_size()*.5
	sprite.offset=Vector2(canvas_offset.x+texture.get_width()*.5,-canvas_offset.y-texture.get_height()*.5)
	var motion:=Vector3.ZERO;var presentation_shape:=Vector2.ONE;var presentation_roll:=0.0
	if not raid_mode:
		var facing: Vector2={'left':Vector2.LEFT,'right':Vector2.RIGHT,'up':Vector2.UP,'down':Vector2.DOWN}.get(source.direction,Vector2.RIGHT)
		if source.get_meta('v16_skill_until',-1.)<_presentation_clock:source.set_meta('v16_skill_motion',false)
		if not frame_active:
			var pose: Dictionary=MOTION.pose(source,hero,facing,_presentation_clock)
			motion=pose.offset;presentation_shape=pose.shape;presentation_roll=pose.roll
		if is_instance_valid(hunt_overlay) and game.combat_effects_enabled and visual_running():
			var step:=int(source.visual_state_time/.22)
			if source.state=='walk' and _last_footstep.get(id,-1)!=step:
				_last_footstep[id]=step;hunt_overlay.footstep(point)
			if source.state!='death':_last_death.erase(id)
			if source.state=='death' and not _last_death.has(id):
				_last_death[id]=true;hunt_overlay.soul(point,hero)
	sprite.position=Vector3(point.x,.10,point.y)+motion;sprite.flip_h=source.flip_h
	# The 3D paint owns its 40ms flash. The source controller's legacy red
	# blink would otherwise tint the painting a second time for 180ms.
	sprite.modulate=source.modulate if frame_active else source.modulate*Color(source.self_modulate.r,source.self_modulate.g,source.self_modulate.b,1)
	sprite.visible=source.visible
	sprite.scale=Vector3(presentation_shape.x,presentation_shape.y,1)
	var inactive=sprite.get_node_or_null('HuntFramePilot' if real_models_enabled else 'Model3DPilot')
	if inactive!=null:inactive.hide()
	var pilot=sprite.get_node_or_null('Model3DPilot' if real_models_enabled else 'HuntFramePilot')
	if frame_active:
		var expected: String=FRAME_PILOT.CATALOG.identity(source,hero)
		if expected.is_empty():expected=str(source.atlas_key) if hero else str(source.pixel_monster_name)
		if pilot!=null and str(pilot.entry.id)!=expected:
			sprite.remove_child(pilot);pilot.free();pilot=null;_source_attacks.erase(id)
		if pilot==null:
			var optimized: bool=_frame_catalog.load_entry(expected).get('optimized_mobile25d',false)
			pilot=(MODEL_PILOT.new() if real_models_enabled else (MOBILE_PILOT.new() if optimized else FRAME_PILOT.new()));sprite.add_child(pilot)
			if not pilot.bind(source,hero,MODEL_PILOT.CATALOG.new() if real_models_enabled else _frame_catalog):sprite.remove_child(pilot);pilot.free();pilot=null
		if pilot!=null:
			var source_rig=source.get_node_or_null('PortraitHeroSkeletalRig')
			if source_rig!=null:source_rig.set_process(false)
			# Raids release instantly in the existing simulation; observe the real
			# source attack restart instead of inventing a second gameplay timer.
			if raid_mode:
				var mark: float=float(source.visual_sequence) if hero else float(source.visual_state_time)
				var previous: Dictionary=_source_attacks.get(id,{})
				if source.state=='attack' and (str(previous.get('state',''))!='attack' or (hero and mark!=float(previous.get('mark',-1))) or (not hero and mark<float(previous.get('mark',0)))):
					var action: String=str(source.get('visual_action')) if hero and source.has_method('play_visual') else 'attack_1'
					pilot.timeline.release(action,.15 if hero else .22)
				_source_attacks[id]={'state':source.state,'mark':mark}
				if source.state=='hit' and str(previous.get('state',''))!='hit':pilot.timeline.hit(Vector2.LEFT if source.flip_h else Vector2.RIGHT)
			var pending: Dictionary=_frame_events.get(id,{})
			if pending.has('release'):pilot.timeline.release(str(pending.release.action),float(pending.release.windup))
			if pending.has('hit'):pilot.timeline.hit(pending.hit)
			_frame_events.erase(id);pilot.show()
			pilot.fur_layers=0 if str(game.presentation_options.get('performance','balanced'))=='battery' else 4
			if not real_models_enabled:pilot.echo_layers=2
			pilot.effects_enabled=game.combat_effects_enabled and str(game.presentation_options.get('performance','balanced'))!='battery'
			# The complete original painting casts into the modeled battle floor.
			pilot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # Baked contact footprint; avoid a second dense billboard shadow pass.
			var runtime:=_frame_runtime(source,hero)
			runtime.merge(_paint_facing_target(source,point,hero))
			var active:=visual_running() and Time.get_ticks_usec()>=int(_contact_holds.get(id,0))
			pilot.present(camera,height,sprite.modulate,_actor_delta,active,point,runtime,_frame_dead(source,hero))
			var old_skin=sprite.get_node_or_null('HeroSkeletalBillboard')
			if old_skin!=null:old_skin.hide()
			sprite.texture=null
		else:frame_active=false
	elif pilot!=null:pilot.hide()
	if hero and not frame_active:
		var rig: Node2D=source.get_node_or_null('PortraitHeroSkeletalRig')
		if rig!=null:
			rig.set_process(true)
			var skinned=sprite.get_node_or_null('HeroSkeletalBillboard')
			if skinned==null:
				skinned=HERO_SKIN.new();sprite.add_child(skinned);skinned.bind(rig)
				skinned.set_environment_lighting(not raid_mode)
			skinned.show()
			skinned.sync(camera,sprite.pixel_size,sprite.modulate)
			if not raid_mode:skinned.basis=skinned.basis.rotated(camera.global_basis.z,presentation_roll)
			# The Sprite3D remains the positioning/shadow API, but only the skin draws.
			sprite.texture=null
	# Keep source animation active; hide only its 2D rendering in the main canvas.
	source.visibility_layer=0
	source.self_modulate.a=0
	for child in source.get_children():
		if child is CanvasItem:child.visible=false
	var shadow: MeshInstance3D=sprite.get_node('ContactShadow');shadow.position=Vector3(0,-.02,14*camera.size/size.y/absf(camera.global_basis.z.y))-motion
	shadow.visible=source.modulate.a>.15
	var breathing_lift: float=pilot.position.length() if frame_active and pilot!=null else motion.y
	var lift_scale:=1.0-clampf(breathing_lift*3.0,0,.6)
	shadow.scale=Vector3(lift_scale/presentation_shape.x,1/presentation_shape.y,lift_scale)
	var crowd: float=_body_scales.get(id,1.0)
	sprite.get_node('TeamFootRing').scale=Vector3(crowd/presentation_shape.x,crowd/presentation_shape.y,crowd)
	sprite.get_node('TeamFootRing').position=Vector3(0,.04,0)-motion
	sprite.get_node('TeamFootRing').visible=source.modulate.a>.5 and source.state!='death'
