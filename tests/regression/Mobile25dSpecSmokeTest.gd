extends 'res://tests/support/V83UpgradeTestBase.gd'
const MOBILE=preload('res://scripts/art/MobileReliefPilot.gd')
const ACTOR=preload('res://scripts/art/MobilePaintActor.gd')
const MONSTER=preload('res://scripts/art/MobileMonsterActor.gd')
const CIRCLE=preload('res://scripts/maps3d/HeroCircleFormation.gd')
const CAMERA=preload('res://scripts/maps3d/MobileCameraMotion.gd')
func _init() -> void:run.call_deferred()
func triangles(mesh: Mesh) -> int:
	var result:=0
	for i in mesh.get_surface_count():result+=int(mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()/3)
	return result
func run() -> void:
	var camera:=Camera3D.new();root.add_child(camera)
	for id in ROSTER.HEROES:
		var source:=ACTOR.new();source.configure_mobile(id);root.add_child(source);source.set_process(false);source.speed_scale=1
		var paint:=MOBILE.new();root.add_child(paint);check(paint.bind(source,true),id+' binds Blender relief')
		paint.present(camera,1,Color.WHITE,.1,true,Vector2.ZERO,{},false)
		check(triangles(paint.mesh)==6000 and triangles(paint._hair.mesh)==1200,id+' actual imported geometry is 7200 triangles with 600 hair cards')
		check(paint.material_override.get_shader_parameter('outline_px')==3.0 and paint._cape.points.size()==5,id+' final outline and five cloth controls are bound')
		check(paint._textures.attack==paint._textures.motion and source.sprite_sheet==paint._textures.motion and source.sprite_sheet.get_size()==Vector2(1024,1024),id+' source and both pose tracks reuse one 1024 texture')
		var mesh: Mesh=paint.mesh
		paint.timeline.release('attack_1',.15);paint.present(camera,1,Color.WHITE,0,true,Vector2.ZERO,{},false)
		check(paint.mesh==mesh and paint._echoes.multimesh.instance_count==5 and paint._echoes.visible_count()==5,id+' action reuses body geometry and five native contact instances')
		check(bool(paint._echoes.material.get_shader_parameter('unit_mesh')) and paint._echoes.multimesh.mesh==paint.mesh,id+' afterimage uses the imported mesh transform')
		var clock: float=paint._visual_time;var drift=paint._cape.points.duplicate()
		paint.present(camera,1,Color.WHITE,.5,false,Vector2.ZERO,{},false)
		check(clock==paint._visual_time and drift==paint._cape.points,id+' pause freezes cloth and pose clock')
		paint.effects_enabled=false;paint.present(camera,1,Color.WHITE,.1,true,Vector2.ZERO,{},false)
		check(not paint._hair.visible and paint._echoes.visible_count()==0 and not paint._echoes.instance.visible and paint.material_override.get_shader_parameter('cape_2')==Vector2.ZERO,id+' effects-off stops secondary geometry and contact echo')
		paint.free();source.free()
	var entries: Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/mobile25d/catalog.json'))
	for item in entries.entries:
		if item.hero:continue
		var monster_name: String=''
		for key in preload('res://scripts/art/HuntFrameCatalog.gd').MONSTERS:
			if preload('res://scripts/art/HuntFrameCatalog.gd').MONSTERS[key]==item.id:monster_name=key;break
		var source:=MONSTER.new();source.configure_mobile(monster_name,Vector2.ONE);root.add_child(source);source.set_process(false);source.speed_scale=1
		var paint:=MOBILE.new();root.add_child(paint);check(paint.bind(source,false),item.id+' binds shared monster atlas')
		paint.present(camera,1,Color.WHITE,0,true,Vector2.ZERO,{},false)
		check(triangles(paint.mesh)==3000 and paint._fur.multimesh.instance_count==6 and paint._fur.visible_count()==6,item.id+' body triangles and six actual native fur shell instances')
		check(paint._textures.attack==paint._textures.motion and source.sprite_sheet==paint._textures.motion,item.id+' monster source and relief share one texture')
		var idle_rect=paint._fur.material.get_shader_parameter('atlas_rect');var idle_mesh=paint._fur.multimesh.mesh
		paint.timeline.release('attack_1',.15);paint.present(camera,1,Color.WHITE,0,true,Vector2.ZERO,{},false)
		check(paint._fur.material.get_shader_parameter('atlas_rect')!=idle_rect,item.id+' attack fur uses a different cell of the shared atlas')
		paint._fur.present(paint.entry.motion,0,paint._textures.motion,0,6)
		check(paint._fur.multimesh.mesh==idle_mesh,item.id+' repeated idle pose reuses its cached shell mesh')
		paint.free();source.free()
	camera.free()
	var motion:=CAMERA.new();var offset:=motion.advance(2.5,true,true)
	check(is_equal_approx(offset.y,-17.0),'camera 10 second breathe reaches 3 pixel amplitude')
	var held:=motion.advance(1,false,true);check(offset==held,'paused camera breath remains fixed')
	motion.impact(false);check(motion.shake_strength==5,'ordinary contact uses bounded 5px shake')
	motion.impact(true);check(motion.shake_strength==10,'critical contact overrides ordinary shake with 10px emphasis')
	motion.advance(.05,true,true);check(is_equal_approx(motion.zoom_punch(true),1.15),'zoom punch peaks at 1.15 and preserves fixed actor height')
	var main=await make_main('aurelia',10);main._build_combat_screen();await settle()
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	var field=main.combat_labels.terrain;field.set_process(false);main.combat_running=false
	CIRCLE.hunt(main,field,true);field._process(0)
	var center: Vector2=field.project_world(main.expedition_position);var ids: Array=main._deployed_hero_ids()
	# The later formation request supersedes the uniform 120px hunting ring.
	# Keep the fixed painting size while validating the actual selected diagram.
	var formation: Dictionary=preload('res://scripts/combat/BattleFormation.gd').projected_offsets(main.deployed_heroes,main.formation_id)
	for i in ids.size():
		var point: Vector2=field.project_world(main.party_movement.positions[ids[i]])-center
		check(point.distance_to(formation[ids[i]])<.1,ids[i]+' starts in the selected formation shown by the menu')
		var gap:=INF
		for j in ids.size():
			if i!=j:gap=minf(gap,point.distance_to(field.project_world(main.party_movement.positions[ids[j]])-center))
		check(gap>=71.9,ids[i]+' reserves native body clearance in the selected formation')
		var actor=main.hero_map_sprites[i];check(absf(field._actor_height(actor,true)*field.size.y/field.camera.size-86.4)<.001,ids[i]+' remains 86.4 pixels after camera zoom')
	check(is_equal_approx(absf(field.camera.global_basis.z.y),sqrt(.5)),'camera is 45 degrees')
	var size: float=field.camera.size;main.combat_running=true
	for i in 10:field._process(.1)
	check(size==field.camera.size,'camera breathe cannot alter hero scale or zoom')
	main.combat_running=false;field._process(.1)
	check(not field.visual_running(),'pause freezes presentation without a global hitstop')
	main.combat_effects_enabled=false;field.hunt_overlay.loot(Vector2.ZERO);field.hunt_overlay._process(.1)
	check(field.hunt_overlay.loot_beams.is_empty(),'effects-off clears loot beams')
	main.combat_effects_enabled=true;main.combat_running=true
	var dilation=main.presentation_runtime.contact_time;dilation.request(false)
	check(dilation.enabled and is_equal_approx(Engine.time_scale,1),'ordinary contacts keep normal game time')
	dilation.request(true)
	check(is_equal_approx(Engine.time_scale,.15),'ordinary critical feedback retains short .15 slow motion')
	main.combat_running=false;dilation._process(0);check(is_equal_approx(Engine.time_scale,1),'pause restores global time scale')
	main.combat_running=true;dilation.cooldown_us=0;dilation.request();dilation.deadline_us=Time.get_ticks_usec()-1;dilation._process(0)
	check(is_equal_approx(Engine.time_scale,1),'wall-time deadline restores global scale')
	var loot=main.presentation_runtime.get_node('LootRewardFeedback');loot.bind(main);var rng: int=main.loot_rng.state
	main.wallet_gold+=5;main.wallet_gems+=2;loot._process(0)
	check(get_nodes_in_group('loot_reward_popup').size()>=2 and not field.hunt_overlay.loot_beams.is_empty(),'confirmed gold and gem additions produce bounded popups and beam')
	check(main.loot_rng.state==rng,'reward presentation consumes no loot RNG')
	main.combat_running=false;main._build_raid_screen();await settle();main._start_raid();await settle()
	var view=main.content_root.get_node('PortraitRaidView');field=view.battlefield_3d;field.set_process(false)
	field.mobile_camera.impact(true);field._process(.05)
	var boss: Vector2=field.project_world(field.raid_to_world(main.raid_boss_sprite.position))
	check(boss.y-(field.RAID_BOSS_PIXELS+2)>=11.9,'enlarged raid boss head clears the stage')
	var floor_end: Vector2=field.project_world(field.raid_to_world(preload('res://scripts/raid/RaidBattlefield.gd').FLOOR.end))
	check(floor_end.y<=field.size.y-field.RAID_BOTTOM_CLEARANCE+.1,'camera keeps reachable raid floor above context controls')
	var destination:=Vector2(420,460);var pixel: Vector2=field.project_world(field.raid_to_world(destination))
	check(field.world_to_raid(field.local_to_world(pixel)).distance_to(destination)<.02,'camera punch and shake preserve inverse raid projection')
	view._on_move_input(pixel);check(main.raid_rally_position.distance_to(destination)<.05,'real raid movement callback uses the displayed point')
	main.raid_running=false;await dispose(main);done('MOBILE25D_SPEC')
