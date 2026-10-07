extends "res://scripts/maps/MapTerrainRenderer.gd"
## Real 3D world embedded beneath the existing battle UI. Battle simulation owns
## the coordinates; both sprite billboards and 2D effects use this camera.
const HERO_SKIN=preload('res://scripts/maps3d/HeroSkeletalBillboard.gd')
const MAP_LOADER=preload('res://scripts/maps/MapLoader.gd')
const FRAMING=preload('res://scripts/maps3d/CombatCameraFraming.gd')
const HEALTH_LAYOUT=preload('res://scripts/maps3d/CombatHealthLayout.gd')
const HEALTH_OVERLAY=preload('res://scripts/maps3d/CombatHealthOverlay.gd')
const HUNT_OVERLAY=preload('res://scripts/maps3d/HuntCombatOverlay.gd')
const MOTION=preload('res://scripts/maps3d/HuntMotionPresentation.gd')
const CONTACT_SHADOW=preload('res://shaders/PaintedContactShadow.gdshader')
const FIELD_PALETTE=preload('res://scripts/maps/FieldArtCatalog.gd')
const STONE_GROUND=preload('res://scripts/maps/RuneStoneGround.gd')
const CAMERA_OFFSET=Vector3(0,40,28)
const HUNT_CAMERA_OFFSET=Vector3(0,.6691306,.7431448) # 42 degree hunting camera.
const HERO_HEIGHT=1.55
const ENEMY_HEIGHT=1.20
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
var _visual_hitstop_remaining:=0.0
var _last_footstep: Dictionary={}
var _last_death: Dictionary={}
var _impact_age:=1.0
var _impact_duration:=.16
var _impact_strength:=0.0
const RAID_PIVOT:=Vector2(519,383)
const RAID_UNITS:=26.0
const RAID_BOTTOM_CLEARANCE:=102.0
var presentation_visible := true
var presentation_suspended := false
var _render_profile := ""
var _render_container: SubViewportContainer
var _render_defaults: Dictionary = {}
var diorama: Node3D
var ultimate_details: Node3D
var rune_ground: Node3D
func apply_render_profile() -> void:
	if not is_instance_valid(viewport_3d) or not is_instance_valid(game):return
	var battery: bool=str(game.presentation_options.get('performance','balanced'))=='battery'
	var key: String='battery' if battery else 'balanced'
	if key!=_render_profile:
		_render_profile=key
		viewport_3d.msaa_3d=Viewport.MSAA_DISABLED if battery else (Viewport.MSAA_2X if raid_mode else Viewport.MSAA_4X)
		viewport_3d.positional_shadow_atlas_size=256 if battery else (1024 if raid_mode else 2048)
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
	_health_overlay=HEALTH_OVERLAY.new();_health_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_health_overlay);_health_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	_apply_battle_contrast()
	resized.connect(_resize_world);_resize_world()
	# Runs after the source AnimatedSprite2D controllers and HUD positions update.
	process_priority=100
	for environment_node in map_root.find_children("*","WorldEnvironment",true,false):
		if environment_node.environment!=null:environment_node.environment=environment_node.environment.duplicate(false)
	add_to_group("game_battlefields");apply_render_profile()
func _create_map_root() -> Node3D:
	if raid_mode:return map_loader.load_zone(zone_id,viewport_3d,true)
	return _create_generated_map_root()
func _create_generated_map_root() -> Node3D:
	# AutoMap Fix: start from a fresh arena; old hunting PackedScenes are not loaded.
	var root:=Node3D.new();root.name='AutoHuntMap';root.set_meta('auto_map_rebuilt',true)
	var arena_root:=Node3D.new();arena_root.name='Arena';root.add_child(arena_root)
	var next_camera:=Camera3D.new();next_camera.name='BattleCamera'
	next_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;next_camera.near=.05;next_camera.far=220;next_camera.current=true
	arena_root.add_child(next_camera)
	var environment_node:=WorldEnvironment.new();environment_node.name='Atmosphere'
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color('#29313a');environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	var palette: Dictionary=FIELD_PALETTE.lighting(zone_id)
	environment.ambient_light_color=palette.ambient
	environment.ambient_light_energy=.65;environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var reflection_sky:=Sky.new();var sky_paint:=ProceduralSkyMaterial.new()
	sky_paint.sky_top_color=Color('#7894ae');sky_paint.sky_horizon_color=Color('#d1dae1')
	sky_paint.ground_bottom_color=Color('#323c43');sky_paint.ground_horizon_color=Color('#a6b6bb')
	reflection_sky.sky_material=sky_paint;environment.sky=reflection_sky
	environment.tonemap_mode=Environment.TONE_MAPPER_ACES;environment.tonemap_exposure=1.12
	environment.glow_enabled=RenderingServer.get_current_rendering_method()=='forward_plus'
	environment.glow_intensity=.65;environment.glow_bloom=.10
	environment_node.environment=environment;arena_root.add_child(environment_node)
	var sun:=DirectionalLight3D.new();sun.name='AutoMapSun';sun.rotation_degrees=Vector3(-55,-28,0)
	sun.light_energy=1.10;sun.light_color=palette.sun
	sun.shadow_enabled=true;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	arena_root.add_child(sun);viewport_3d.add_child(root)
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
		raid_factor=minf(safe_size.x/674.0,safe_size.y/340.0)
		_set_focus(Vector2(16,10))
		camera.size=size.y/(RAID_UNITS*raid_factor)
		camera.v_offset=(-5.0+57.0*raid_factor)/(RAID_UNITS*raid_factor)
		# Measure the real floor projection; preserve actor/telegraph scale and
		# leave the enlarged dodge/follow strip below every reachable point.
		var floor_end: Vector2=preload("res://scripts/raid/RaidBattlefield.gd").FLOOR.end
		var excess:=project_world(raid_to_world(floor_end)).y-(size.y-RAID_BOTTOM_CLEARANCE)
		if excess>0.0:camera.v_offset-=excess/(RAID_UNITS*raid_factor)
	else:
		_update_hunt_camera(0.0,true)

func _set_focus(point: Vector2) -> void:
	focus=point
	var target:=Vector3(point.x,0,point.y)
	# Orthographic framing changes angle, not distance. Preserve enough camera
	# clearance so actor billboards cannot cross the near plane.
	var offset: Vector3=CAMERA_OFFSET if raid_mode else HUNT_CAMERA_OFFSET.normalized()*CAMERA_OFFSET.length()
	camera.position=target+offset
	camera.look_at(target)

func camera_points() -> Array[Vector3]:
	var points: Array[Vector3]=[]
	if not is_instance_valid(game):return points
	for hero in game.deployed_heroes:
		var id:=str(hero.id)
		if float(game.hero_battle_state.get(id,{}).get('hp',1))<=0:continue
		var point: Vector2=game._hero_field_position(id)
		points.append(Vector3(point.x,0,point.y))
		points.append(Vector3(point.x,HERO_HEIGHT+.6,point.y))
	for i in game.enemy_wave.size():
		if float(game.enemy_wave[i].get('hp',0))<=0:continue
		var point: Vector2=game.roaming_hunt.enemy_position(i)
		points.append(Vector3(point.x,0,point.y))
		points.append(Vector3(point.x,ENEMY_HEIGHT*1.35+.6,point.y))
	return points

func _update_hunt_camera(delta: float,snap:=false) -> void:
	if not is_instance_valid(camera) or size.x<1 or size.y<1:return
	var sine:=HUNT_CAMERA_OFFSET.normalized().y
	var frame: Dictionary=FRAMING.fit(camera_points(),size,sine)
	var next: Vector2=frame.center
	if not snap and _camera_initialized:
		# A small dead zone prevents idle/attack animation from steering the view.
		if focus.distance_to(next)<.18:next=focus
		else:next=focus.lerp(next,1.0-exp(-maxf(delta,0)*3.0))
	_set_focus(next)
	camera.v_offset=0
	var required: float=FRAMING.size_at_center(frame.bounds,focus,size,sine)
	if snap or not _camera_initialized or required>camera.size:
		camera.size=required
	else:
		camera.size=lerpf(camera.size,required,1.0-exp(-maxf(delta,0)*1.8))
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
func raid_origin() -> Vector2:
	return project_world(Vector2(16,10))-RAID_PIVOT*raid_factor
func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(camera):return
	apply_render_profile()
	_visual_hitstop_remaining=maxf(0,_visual_hitstop_remaining-maxf(0,delta))
	if visual_running():_presentation_clock+=maxf(0,delta)*visual_speed()
	if not raid_mode:_update_hunt_camera(delta)
	if not raid_mode:
		var speed:=visual_speed() if visual_running() else 0.0
		for actor in game.hero_map_sprites+game.enemy_wave_sprites:
			if is_instance_valid(actor):
				actor.speed_scale=speed
				if actor is MonsterSpriteController:actor.set_process(speed>0)
		if speed>0:_impact_age+=maxf(0,delta)*speed
	if not raid_mode and _impact_age<_impact_duration:
		var beat:=sin(_impact_age/_impact_duration*TAU*1.5)*(1-clampf(_impact_age/_impact_duration,0,1))
		camera.h_offset=beat*_impact_strength;camera.v_offset=beat*_impact_strength*.35
	elif not raid_mode:camera.h_offset=0
	var live: Dictionary={}
	_health_entries.clear()
	_health_links.clear()
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
				sync_actor(game.hero_map_sprites[i],game._hero_field_position(id),true,live)
				var source: Node2D=game.hero_map_sprites[i]
				source.position=position+project_world(game._hero_field_position(id))
				if game.hero_hp_bars.has(id):
					_queue_health(game.hero_hp_bars[id],source.position+Vector2(0,7),source.visible,
						float(game.hero_battle_state.get(id,{}).get('hp',0)),true,false)
		for i in game.enemy_wave_sprites.size():
			if i<game.enemy_wave.size():
				sync_actor(game.enemy_wave_sprites[i],game.roaming_hunt.enemy_position(i),false,live)
				game.enemy_wave_sprites[i].position=position+project_world(game.roaming_hunt.enemy_position(i))
				if i<game.enemy_hp_bars.size():
					var source: AnimatedSprite2D=game.enemy_wave_sprites[i]
					var selected: bool=game.roaming_hunt.aggro_active and game.roaming_hunt.current_target==i
					var anchor: Vector2=source.position-Vector2(0,_actor_height(source,false)*size.y/camera.size+9)
					_queue_health(game.enemy_hp_bars[i],anchor,source.visible,float(game.enemy_wave[i].get('hp',0)),false,selected)
		game._update_combat_target_marker()
		_layout_health()
		var marker: Label=game.combat_labels.get('target_marker')
		var target: int=game.roaming_hunt.current_target
		if is_instance_valid(marker) and marker.visible and target>=0 and target<game.enemy_wave_sprites.size():
			var source: AnimatedSprite2D=game.enemy_wave_sprites[target]
			marker.position=source.position-Vector2(39,_actor_height(source,false)*size.y/camera.size+32)
	for key in actors.keys():
		if not live.has(key):
			actors[key].free();actors.erase(key);_last_footstep.erase(key);_last_death.erase(key)
	_health_overlay.links=_health_links
	_health_overlay.queue_redraw()
	if is_instance_valid(diorama):diorama.update_foreground()
	if is_instance_valid(ultimate_details):ultimate_details.update_occlusion()

func hunt_hit(point: Vector2,source: Vector2,tint: Color,critical: bool) -> void:
	if is_instance_valid(hunt_overlay):
		hunt_overlay.hit(point,source,tint,critical)
		if critical and game.combat_effects_enabled:
			_visual_hitstop_remaining=.045
			for actor in game.hero_map_sprites:
				if is_instance_valid(actor) and actor.position.distance_to(position+project_world(source))<30:
					hunt_overlay.afterimage(actor,source,(point-source).normalized());break

func skill_trail(hero_id: String) -> void:
	if raid_mode or not is_instance_valid(hunt_overlay) or not game.combat_effects_enabled:return
	for i in mini(game.hero_map_sprites.size(),game.deployed_heroes.size()):
		if str(game.deployed_heroes[i].id)!=hero_id:continue
		var source: AnimatedSprite2D=game.hero_map_sprites[i]
		var point: Vector2=game._hero_field_position(hero_id)
		var facing: Vector2={'left':Vector2.LEFT,'right':Vector2.RIGHT,'up':Vector2.UP,'down':Vector2.DOWN}.get(source.direction,Vector2.RIGHT)
		source.set_meta('v16_skill_motion',true);source.set_meta('v16_skill_until',_presentation_clock+.45)
		hunt_overlay.afterimage(source,point,facing);break

func visual_running() -> bool:
	return is_instance_valid(game) and game.active_screen=='combat' and game.combat_running and not game._application_suspended and _visual_hitstop_remaining<=0 and not bool(game.get_meta('equipment_mail_paused',false)) and not preload('res://scripts/persistence/SaveSafety.gd').pending(game)

func visual_speed() -> float:
	return clampf(game.battle_speed,1,2) if is_finite(game.battle_speed) else 1.0

func camera_impact(intensity: float,duration: float,_zoom: float) -> void:
	# Only the world moves. Menus, touch coordinates and the party dock stay fixed.
	if not is_instance_valid(camera) or _impact_age<.18:return
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

func _actor_height(source: AnimatedSprite2D,hero: bool) -> float:
	var native: float=maxf(1,source.native_visual_height)
	if raid_mode:return native*absf(source.scale.y)/RAID_UNITS
	if hero:return HERO_HEIGHT
	# Atlas normalization is not a gameplay size bonus. Compare against the
	# normalized rest scale, then apply only spawn/hit/death presentation changes.
	return ENEMY_HEIGHT*clampf(absf(source.scale.y)/maxf(.001,source._base_scale.y),.15,1.35)

func actor_head_offset(source: AnimatedSprite2D) -> Vector2:
	if not is_instance_valid(camera):return Vector2.ZERO
	return Vector2(0,-_actor_height(source,source is HeroSpriteController)*size.y/camera.size)

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
		shadow.material_override=m;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;sprite.add_child(shadow)
		var ring:=MeshInstance3D.new();ring.name='TeamFootRing'
		var torus:=TorusMesh.new();torus.inner_radius=.40;torus.outer_radius=.46;torus.rings=20;torus.ring_segments=6
		ring.mesh=torus
		var ring_material:=StandardMaterial3D.new();ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.albedo_color=Color('#79d8d0') if hero else Color('#dd967e')
		ring.material_override=ring_material;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y=.04;sprite.add_child(ring)
	var texture: Texture2D=source.sprite_frames.get_frame_texture(source.animation,source.frame)
	sprite.texture=texture
	var native: float=maxf(1,source.native_visual_height)
	var height: float=_actor_height(source,hero)
	sprite.pixel_size=height/native
	var canvas_offset: Vector2=source.offset if not source.centered else source.offset-texture.get_size()*.5
	sprite.offset=Vector2(canvas_offset.x+texture.get_width()*.5,-canvas_offset.y-texture.get_height()*.5)
	var motion:=Vector3.ZERO;var presentation_shape:=Vector2.ONE;var presentation_roll:=0.0
	if not raid_mode:
		var facing: Vector2={'left':Vector2.LEFT,'right':Vector2.RIGHT,'up':Vector2.UP,'down':Vector2.DOWN}.get(source.direction,Vector2.RIGHT)
		if source.get_meta('v16_skill_until',-1.)<_presentation_clock:source.set_meta('v16_skill_motion',false)
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
	sprite.modulate=source.modulate*Color(source.self_modulate.r,source.self_modulate.g,source.self_modulate.b,1)
	sprite.visible=source.visible
	sprite.scale=Vector3(presentation_shape.x,presentation_shape.y,1)
	if hero:
		var rig: Node2D=source.get_node_or_null('PortraitHeroSkeletalRig')
		if rig!=null:
			var skinned=sprite.get_node_or_null('HeroSkeletalBillboard')
			if skinned==null:
				skinned=HERO_SKIN.new();sprite.add_child(skinned);skinned.bind(rig)
				skinned.set_environment_lighting(not raid_mode)
			skinned.sync(camera,sprite.pixel_size,sprite.modulate)
			if not raid_mode:skinned.basis=skinned.basis.rotated(camera.global_basis.z,presentation_roll)
			# The Sprite3D remains the positioning/shadow API, but only the skin draws.
			sprite.texture=null
	# Keep source animation active; hide only its 2D rendering in the main canvas.
	source.self_modulate.a=0
	for child in source.get_children():
		if child is CanvasItem:child.visible=false
	var shadow: MeshInstance3D=sprite.get_node('ContactShadow');shadow.position=Vector3(0,-.02,0)-motion
	shadow.visible=source.modulate.a>.15
	if not raid_mode:
		var lift_scale:=1.0-clampf(motion.y*3.0,0,.6)
		shadow.scale=Vector3(lift_scale/presentation_shape.x,1/presentation_shape.y,lift_scale)
	sprite.get_node('TeamFootRing').scale=Vector3(1/presentation_shape.x,1/presentation_shape.y,1)
	sprite.get_node('TeamFootRing').position=Vector3(0,.04,0)-motion
	sprite.get_node('TeamFootRing').visible=source.modulate.a>.5 and source.state!='death'
