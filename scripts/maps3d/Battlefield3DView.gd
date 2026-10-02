extends "res://scripts/MapTerrainRenderer.gd"
## Real 3D world embedded beneath the existing battle UI. Battle simulation owns
## the coordinates; both sprite billboards and 2D effects use this camera.
const MAP_LOADER=preload('res://scripts/maps/MapLoader.gd')
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
	world=map_root.get_node('Arena');camera=world.get_node('BattleCamera')
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
		raid_factor=minf(maxf(.20,(size.x-24)/720.0),maxf(.20,(size.y-96)/340.0))
		camera.look_at(Vector3(16,0,10))
		camera.size=size.y/(RAID_UNITS*raid_factor)
		# Leave the boss bars a clear strip above the floor.
		camera.v_offset=38.0/(RAID_UNITS*raid_factor)
	else:camera.size=maxf(34.0,58.0/(size.x/size.y)) if zone_id=='gray_meadow' else maxf(26.0,42.0/(size.x/size.y))
func _draw() -> void: pass
func project_world(point: Vector2,height: float=0.0) -> Vector2:
	if not is_instance_valid(camera):return size*.5
	return camera.unproject_position(Vector3(point.x,height,point.y))
func local_to_world(point: Vector2) -> Vector2:
	if not is_instance_valid(camera):return Vector2(16,10)
	var origin:=camera.project_ray_origin(point);var ray:=camera.project_ray_normal(point)
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
func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(camera):return
	var live: Dictionary={}
	if raid_mode:
		if not is_instance_valid(raid_view):return
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
				if game.hero_hp_bars.has(id):game.hero_hp_bars[id].position=source.position+Vector2(-16,3)
		for i in game.enemy_wave_sprites.size():
			if i<game.enemy_wave.size():
				sync_actor(game.enemy_wave_sprites[i],game.roaming_hunt.enemy_position(i),false,live)
				game.enemy_wave_sprites[i].position=position+project_world(game.roaming_hunt.enemy_position(i))
				if i<game.enemy_hp_bars.size():game.enemy_hp_bars[i].position=position+project_world(game.roaming_hunt.enemy_position(i),1.7)+Vector2(-17,-7)
		game._update_combat_target_marker()
	for key in actors.keys():
		if not live.has(key):
			actors[key].free();actors.erase(key)
func sync_actor(source: AnimatedSprite2D,point: Vector2,hero: bool,live: Dictionary) -> void:
	if not is_instance_valid(source) or source.sprite_frames==null:return
	if not source.sprite_frames.has_animation(source.animation):return
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
	var texture: Texture2D=source.sprite_frames.get_frame_texture(source.animation,source.frame)
	sprite.texture=texture
	var native: float=maxf(1,source.native_visual_height)
	var height: float=1.95 if hero else 1.65
	if raid_mode:height=native*absf(source.scale.y)/RAID_UNITS
	elif not hero:height*=clampf(absf(source.scale.y)/maxf(.001,source.presentation_scale.y),.15,1.35)
	sprite.pixel_size=height/native
	var canvas_offset: Vector2=source.offset if not source.centered else source.offset-texture.get_size()*.5
	sprite.offset=Vector2(canvas_offset.x+texture.get_width()*.5,-canvas_offset.y-texture.get_height()*.5)
	sprite.position=Vector3(point.x,.035,point.y);sprite.flip_h=source.flip_h;sprite.modulate=source.modulate;sprite.visible=source.visible
	# Keep source animation active; hide only its 2D rendering in the main canvas.
	source.self_modulate.a=0
	for child in source.get_children():
		if child is CanvasItem:child.visible=false
	var shadow: MeshInstance3D=sprite.get_node('ContactShadow');shadow.position=Vector3(0,-.02,0)
	shadow.visible=source.modulate.a>.15
