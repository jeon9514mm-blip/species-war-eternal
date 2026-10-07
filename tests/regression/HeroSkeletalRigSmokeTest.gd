extends SceneTree
const FACTORY=preload('res://scripts/heroes/HeroSpriteFactory.gd')
const RIG=preload('res://scripts/portrait/PortraitHeroSkeletalRig.gd')
const MOTIONS=preload('res://scripts/portrait/HeroRigMotionCatalog.gd')
const BILLBOARD=preload('res://scripts/maps3d/HeroSkeletalBillboard.gd')
var checks:=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera)
	for id in MOTIONS.PROFILES:
		var hero: HeroSpriteController=FACTORY.create_hero(id)
		hero.observe_game=false;hero.hold_demo=true;root.add_child(hero);hero.set_process(false)
		hero.position=Vector2(317,242)
		var rig:=RIG.new();check(rig.install(hero),id+' installs')
		rig.set_process(false)
		check(rig.bones.size()==21 and rig.mesh.get_bone_count()==21,id+' 21 weighted joints')
		check(hero.ACTIONS.size()==16,id+' controller has 16 tracks')
		var weight_ok:=true
		for weights: Dictionary in rig.weights:
			var total:=0.0
			for value in weights.values():total+=float(value)
			weight_ok=weight_ok and absf(total-1.0)<.0001 and weights.size()<=4
		check(weight_ok,id+' normalized four-influence weights')
		rig.apply_pose({})
		var neutral:=rig.deformed_points()
		var rest_error:=0.0
		for i in neutral.size():rest_error=maxf(rest_error,neutral[i].distance_to(rig.rest_points[i]))
		check(rest_error<.001,id+' inverse bind reconstructs rest painting')
		var billboard:=BILLBOARD.new();world.add_child(billboard);billboard.bind(rig)
		check(billboard.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES].size()==neutral.size()*4,id+' GPU skin has actual bone indices')
		var signatures: Dictionary={}
		for action in MOTIONS.ACTIONS:
			check(hero.play_visual(action),id+' accepts '+action)
			rig._process(0.0)
			var duration:=rig.action_duration(action)
			var time:=duration*.46 if action not in MOTIONS.LOOPS else .23
			rig._process(time)
			billboard.sync(camera,.03,Color.WHITE)
			var shape:=rig.deformed_points()
			var displacement:=0.0;var local_deformation:=0.0
			for i in shape.size():
				displacement=maxf(displacement,shape[i].distance_to(neutral[i]))
				if i>0:local_deformation=maxf(local_deformation,(shape[i]-shape[0]).distance_to(neutral[i]-neutral[0]))
			check(displacement>.01 and local_deformation>.01,id+' '+action+' deforms joints, not just image translation')
			check(hero.position==Vector2(317,242),id+' '+action+' preserves game position')
			var gpu_match:=true
			for i in rig.bone_names.size():
				var bone: Bone2D=rig.bones[rig.bone_names[i]]
				gpu_match=gpu_match and billboard.bones_3d.get_bone_pose_position(i).is_equal_approx(Vector3(bone.position.x,-bone.position.y,0))
			check(gpu_match,id+' '+action+' reaches visible 3D skeleton')
			signatures[str(rig.pose)]=true
		check(signatures.size()==16,id+' all sixteen tracks distinct')
		hero.play_visual('attack_1');rig._process(.21);hero.play_visual('attack_1');rig._process(.01)
		check(rig.action_time<.02,id+' repeated action restarts pose')
		var frozen: Dictionary=rig.pose.duplicate();hero.speed_scale=0;rig._process(.4)
		check(rig.pose==frozen,id+' pause freezes joints');hero.speed_scale=1
		hero.play_visual('death');rig._process(2);var fallen: Dictionary=rig.pose.duplicate();rig._process(2)
		check(fallen==rig.pose,id+' completed death has no residual breathing')
		# No breathing in a completed death pose.
		check(absf(rig.bones['Root'].rotation-.65)<.001,id+' death reaches and holds slump')
		hero.flip_h=true;rig.apply_pose({});billboard.sync(camera,.03,Color.WHITE)
		check(rig.scale.x==-1 and billboard.basis.determinant()<0,id+' mirror includes joints and artwork')
		billboard.free();hero.free()
	world.free()
	# Exercise the real hunt renderer, then the real raid creation path.
	var game:=preload('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://hero-rig-smoke.json';root.add_child(game)
	for i in 3:await process_frame
	game.selected_faction='aurelia';game.party_slot_legacy_cap=10;game._restore_deployed_heroes(['leonhardt','mira','elisia'])
	game._build_combat_screen()
	for i in 5:await process_frame
	var rendered:=0
	for hero: HeroSpriteController in game.hero_map_sprites:
		var rig: Node2D=hero.get_node_or_null('PortraitHeroSkeletalRig')
		if rig!=null and rig.rendered_in_3d:rendered+=1
	check(rendered==game.hero_map_sprites.size() and rendered>0,'actual hunt renderer skins every deployed hero')
	game.selected_raid_id='gray_meadow';game._build_raid_screen()
	for i in 6:await process_frame
	var raid=game.content_root.get_node('PortraitRaidView')
	var raid_rendered:=0
	for hero in raid.hero_actors.values():
		var rig: Node2D=hero.get_node_or_null('PortraitHeroSkeletalRig')
		if rig!=null and rig.rendered_in_3d:raid_rendered+=1
	check(raid_rendered==raid.hero_actors.size() and raid_rendered>0,'actual raid renderer skins every deployed hero')
	if game.presentation_runtime!=null:game.presentation_runtime.audio.shutdown()
	await create_timer(.35).timeout
	game.free()
	await create_timer(.1).timeout
	await process_frame
	print('hero_skeletal_rig ',checks-failures.size(),'/',checks,' pass')
	quit(0 if failures.is_empty() else 1)
