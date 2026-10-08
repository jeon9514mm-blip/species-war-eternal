extends 'res://tests/support/V83UpgradeTestBase.gd'
const MOBILE=preload('res://scripts/art/MobileReliefPilot.gd')
const SETTINGS=preload('res://scripts/presentation/PresentationSettings.gd')
func _init() -> void:run.call_deferred()
func triangles(mesh: Mesh) -> int:
	var count:=0
	for surface in mesh.get_surface_count():count+=int(mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3)
	return count
func run() -> void:
	check(SETTINGS.sanitize({'performance':'quality'}).performance=='quality','quality survives preference sanitization')
	check(SETTINGS.DEFAULTS.performance=='balanced','balanced remains the default')
	var main=await make_main('aurelia',10);main._build_combat_screen();await settle()
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	main.combat_running=false;main.combat_effects_enabled=true
	var field=main.combat_labels.terrain;field.set_process(false);field._process(0)
	var source=main.hero_map_sprites[0];var point: Vector2=main._hero_field_position(str(main.deployed_heroes[0].id))
	var original_simulation: Dictionary=economic(main);var rng_state: int=main.loot_rng.state
	for mode in ['balanced','quality','battery','balanced']:
		main.presentation_options.performance=mode;field.apply_render_profile();await settle();field._process(0)
		var battery: bool=mode=='battery';var quality: bool=mode=='quality'
		check(field.viewport_3d.msaa_3d==(Viewport.MSAA_DISABLED if battery else (Viewport.MSAA_4X if quality else Viewport.MSAA_2X)),'actual viewport antialiasing '+mode)
		check(is_equal_approx(field.viewport_3d.scaling_3d_scale,1.0 if battery or quality else .85),'actual 3D resolution '+mode)
		check(field._render_container.stretch_shrink==(2 if battery else 1),'battery viewport dimensions '+mode)
		var floor: MeshInstance3D=field.map_root.get_node('Arena/PBRStoneSlabs1024')
		var material: ShaderMaterial=floor.material_override
		var micro: Texture2D=material.get_shader_parameter('stone_micro_normal')
		check(micro.get_width()==(4096 if quality else 1024) and material.get_shader_parameter('parallax_steps')==(8 if quality else 4),'real micro texture and bounded height traversal '+mode)
		check(is_equal_approx(float(field._post_material.get_shader_parameter('chromatic')),0.0 if battery else (.005 if quality else .002)) and is_equal_approx(float(field._post_material.get_shader_parameter('film_grain')),0.0 if battery else (.02 if quality else .015)),'actual bounded post profile '+mode)
		check(absf(field._actor_height(source,true)*field.size.y/field.camera.size-86.4)<.001,'quality switch retains 86.4 pixel hero '+mode)
		var pixel: Vector2=field.project_world(point)
		check(field.local_to_world(pixel).distance_to(point)<.002,'render scaling preserves input projection '+mode)
		field.sync_actor(source,field.local_to_world(field.size*.5),true,{})
		var hero_pilot=field._actor_nodes[source.get_instance_id()].paint
		check(hero_pilot._hair.cast_shadow==(GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),'actual hair shadow obeys quality profile '+mode)
		check(main.loot_rng.state==rng_state and economic(main)==original_simulation,'profile cannot alter combat or rewards '+mode)
	check(field.secondary_lod_at(field.size*.5+Vector2(299.9,0))==0 and field.secondary_lod_at(field.size*.5+Vector2(300,0))==1,'300px half-detail threshold')
	check(field.secondary_lod_at(field.size*.5+Vector2(499.9,0))==1 and field.secondary_lod_at(field.size*.5+Vector2(500,0))==2,'500px secondary freeze threshold')
	check(field.secondary_lod_at(field.size*.5+Vector2(799.9,0))==2 and field.secondary_lod_at(field.size*.5+Vector2(800,0))==3,'800px auxiliary hide threshold')
	for fixture in [{'distance':0.0,'lod':0,'echoes':5,'hair':1200},{'distance':310.0,'lod':1,'echoes':3,'hair':600},{'distance':520.0,'lod':2,'echoes':1,'hair':600},{'distance':820.0,'lod':3,'echoes':0,'hair':600}]:
		var visual_point: Vector2=field.local_to_world(field.size*.5+Vector2(fixture.distance,0))
		field.sync_actor(source,visual_point,true,{})
		var nodes: Dictionary=field._actor_nodes[source.get_instance_id()];var pilot=nodes.paint
		check(pilot is MOBILE and pilot.secondary_lod==fixture.lod,'native battlefield assigns LOD '+str(fixture.lod))
		check(triangles(pilot._hair.mesh)==fixture.hair and pilot.echo_layers==fixture.echoes,'native field limits cards and afterimages '+str(fixture.lod))
		check(pilot._hair.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,'balanced hair avoids redundant shadow pass '+str(fixture.lod))
		check(nodes.shadow.visible and absf(nodes.shadow.position.z-16*field.camera.size/field.size.y/absf(field.camera.global_basis.z.y))<.00001,'contact footprint stays visible at16px '+str(fixture.lod))
	check(main.loot_rng.state==rng_state and economic(main)==original_simulation,'render LOD never moves simulation actors or consumes loot RNG')
	var decoration:=Label.new();source.add_child(decoration);field.sync_actor(source,point,true,{})
	check(not decoration.visible,'a new source decoration stays out of the 3D field')
	source.remove_child(decoration);decoration.free()
	var replacement:=Label.new();source.add_child(replacement);field.sync_actor(source,point,true,{})
	check(not replacement.visible,'same-count child replacement invalidates source node cache')
	source.remove_child(replacement);replacement.free()
	main.combat_running=true;field.ultra_post_impact()
	check(is_equal_approx(float(field._post_material.get_shader_parameter('chromatic')),.05) and field._post_impact_deadline_us-Time.get_ticks_usec()<=180000,'ultimate post accent has a180ms wall-time cap')
	main.combat_running=false;var post_clock: float=field._post_time;field._process(.4)
	check(field._post_time==post_clock and field._post_pause_started_us>0 and is_equal_approx(float(field._post_material.get_shader_parameter('chromatic')),.05),'pause freezes both post phase and ultimate deadline')
	main.combat_running=true;field._post_pause_started_us=0;field._post_impact_deadline_us=Time.get_ticks_usec()-1;field._update_ultra_post()
	check(is_equal_approx(float(field._post_material.get_shader_parameter('chromatic')),.002),'expired accent returns to balanced base')
	main.combat_effects_enabled=false;field._update_ultra_post()
	check(field._post_impact_deadline_us==0 and field._post_material.get_shader_parameter('chromatic')==0.0 and field._post_material.get_shader_parameter('film_grain')==0.0 and field._post_material.get_shader_parameter('lens_distortion')==0.0,'effects off resets all optional post distortion')
	main.combat_running=false;main.combat_effects_enabled=true
	var enemy: Dictionary=main.enemy_wave[0];var original_hp: int=enemy.hp
	enemy.hp=int(round(float(enemy.max_hp)*.25))
	check(absf(float(field._frame_runtime(main.enemy_wave_sprites[0],false).health_ratio)-float(enemy.hp)/float(enemy.max_hp))<.000001,'monster wounds use current game HP')
	enemy.hp=original_hp
	main._build_raid_screen();await settle();main._start_raid();await settle();main.raid_running=false
	field=main.content_root.get_node('PortraitRaidView').battlefield_3d;field.set_process(false);field._process(0)
	var boss_hp: int=main.raid_boss_hp;main.raid_boss_hp=int(round(float(main.raid_boss_max_hp)*.25))
	check(absf(float(field._frame_runtime(main.raid_boss_sprite,false).health_ratio)-float(main.raid_boss_hp)/float(main.raid_boss_max_hp))<.000001,'raid wounds use the actual boss HP')
	main.raid_boss_hp=boss_hp
	check(field.MAX_CAMERA_PUNCH==1.15 and absf(field._actor_height(main.raid_boss_sprite,false)*field.size.y/field.camera.size-179.2)<.001,'Ultra camera reserve retains179.2 pixel boss')
	await dispose(main);done('ULTRA_FIELD_RENDER_PROFILE')
