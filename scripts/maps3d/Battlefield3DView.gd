extends "res://scripts/MapTerrainRenderer.gd"
## Real 3D world embedded beneath the existing battle UI. Battle simulation owns
## the coordinates; both sprite billboards and 2D effects use this camera.
const HERO_SKIN=preload('res://scripts/maps3d/HeroSkeletalBillboard.gd')
const MAP_LOADER=preload('res://scripts/maps/MapLoader.gd')
const FRAMING=preload('res://scripts/maps3d/CombatCameraFraming.gd')
const HEALTH_LAYOUT=preload('res://scripts/maps3d/CombatHealthLayout.gd')
const HEALTH_OVERLAY=preload('res://scripts/maps3d/CombatHealthOverlay.gd')
const CAMERA_OFFSET=Vector3(0,40,28)
const HERO_HEIGHT=2.25
const ENEMY_HEIGHT=1.75
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
var overview_mode:=false
var view_button: Button
const RAID_PIVOT:=Vector2(519,383)
const RAID_UNITS:=26.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	var container:=SubViewportContainer.new();container.name='Live3DViewport';container.stretch=true
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_3d=SubViewport.new();viewport_3d.name='World3D';viewport_3d.own_world_3d=true
	viewport_3d.msaa_3d=Viewport.MSAA_2X;viewport_3d.positional_shadow_atlas_size=1024
	viewport_3d.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport_3d)
	map_loader=MAP_LOADER.new();map_loader.name='MapLoader';add_child(map_loader)
	map_root=map_loader.load_zone(zone_id,viewport_3d,raid_mode)
	if map_root==null:return
	world=map_root.get_node('Arena');camera=world.get_node('BattleCamera')
	_health_overlay=HEALTH_OVERLAY.new();_health_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_health_overlay);_health_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	_apply_battle_contrast()
	if not raid_mode:
		view_button=preload('res://scripts/portrait/PortraitSkin.gd').button('전장 보기',Callable())
		view_button.name='CombatViewToggle';view_button.tooltip_text='전투 중심 확대와 전장 전체 보기 전환'
		view_button.add_theme_font_size_override('font_size',16)
		view_button.pressed.connect(_toggle_overview)
		add_child(view_button);view_button.z_index=80
		view_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		view_button.offset_left=-118;view_button.offset_right=-10;view_button.offset_top=10;view_button.offset_bottom=48
	resized.connect(_resize_world);_resize_world()
	# Runs after the source AnimatedSprite2D controllers and HUD positions update.
	process_priority=100
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
		var safe_size:=Vector2(maxf(1,size.x-36),maxf(1,size.y-102))
		raid_factor=minf(safe_size.x/674.0,safe_size.y/340.0)
		_set_focus(Vector2(16,10))
		camera.size=size.y/(RAID_UNITS*raid_factor)
		camera.v_offset=(-5.0+57.0*raid_factor)/(RAID_UNITS*raid_factor)
	else:
		_update_hunt_camera(0.0,true)

func _set_focus(point: Vector2) -> void:
	focus=point
	var target:=Vector3(point.x,0,point.y)
	camera.position=target+CAMERA_OFFSET
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
	if overview_mode:
		_set_focus(Vector2(16,10));camera.v_offset=0
		camera.size=maxf(34,46.0/maxf(.1,size.x/size.y))
		return
	var sine:=CAMERA_OFFSET.normalized().y
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

func _toggle_overview() -> void:
	overview_mode=not overview_mode
	view_button.text='전투 보기' if overview_mode else '전장 보기'
	_resize_world()

func _apply_battle_contrast() -> void:
	# Make the play surface quieter, without changing the standalone map gallery.
	for node_name in ['CarvedStoneArena','SculptedTerrain']:
		var floor_mesh:=world.get_node_or_null(node_name) as MeshInstance3D
		if floor_mesh==null or not floor_mesh.material_override is ShaderMaterial:continue
		var material:=floor_mesh.material_override.duplicate() as ShaderMaterial
		material.set_shader_parameter('combat_readability',1.0)
		floor_mesh.material_override=material

func _draw() -> void:pass
func project_world(point: Vector2,height: float=0.0) -> Vector2:
	if not is_instance_valid(camera):return size*.5
	return camera.unproject_position(Vector3(point.x,height,point.y))
func local_to_world(point: Vector2) -> Vector2:
	if not is_instance_valid(camera):return Vector2(16,10)
	var origin:=camera.project_ray_origin(point);var ray:=camera.project_ray_normal(point)
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
	if not raid_mode:_update_hunt_camera(delta)
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
			actors[key].free();actors.erase(key)
	_health_overlay.links=_health_links
	_health_overlay.queue_redraw()

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
	return ENEMY_HEIGHT*clampf(absf(source.scale.y)/maxf(.001,source.presentation_scale.y),.15,1.35)

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
		sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.shaded=false
		sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.12
		sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(sprite);actors[id]=sprite
		var shadow:=MeshInstance3D.new();shadow.name='ContactShadow'
		var disk:=CylinderMesh.new();disk.top_radius=.43;disk.bottom_radius=.43;disk.height=.009;disk.radial_segments=24;shadow.mesh=disk
		var m:=StandardMaterial3D.new();m.albedo_color=Color(.055,.075,.06,.28);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
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
	sprite.position=Vector3(point.x,.10,point.y);sprite.flip_h=source.flip_h
	sprite.modulate=source.modulate*Color(source.self_modulate.r,source.self_modulate.g,source.self_modulate.b,1)
	sprite.visible=source.visible
	if hero:
		var rig: Node2D=source.get_node_or_null('PortraitHeroSkeletalRig')
		if rig!=null:
			var skinned=sprite.get_node_or_null('HeroSkeletalBillboard')
			if skinned==null:
				skinned=HERO_SKIN.new();sprite.add_child(skinned);skinned.bind(rig)
			skinned.sync(camera,sprite.pixel_size,sprite.modulate)
			# The Sprite3D remains the positioning/shadow API, but only the skin draws.
			sprite.texture=null
	# Keep source animation active; hide only its 2D rendering in the main canvas.
	source.self_modulate.a=0
	for child in source.get_children():
		if child is CanvasItem:child.visible=false
	var shadow: MeshInstance3D=sprite.get_node('ContactShadow');shadow.position=Vector3(0,-.02,0)
	shadow.visible=source.modulate.a>.15
	sprite.get_node('TeamFootRing').visible=source.modulate.a>.5 and source.state!='death'
