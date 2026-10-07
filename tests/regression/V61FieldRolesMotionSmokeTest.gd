extends SceneTree
const GEAR:=preload('res://scripts/equipment/EquipmentRules.gd')
var checks:=0
var errors: Array[String]=[]

func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error('V61 field roles motion: '+message)
func settle() -> void:
	for _frame in 4:await process_frame

func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	var main:=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v61-roles-motion.json'
	root.add_child(main);await settle()
	main.selected_faction='aurelia';main.idle_stage=8
	main._restore_deployed_heroes(['leonhardt','mira','elisia','orwin'])
	main.gear_auto_equip=false
	main.loot_rng.seed=6126
	for zone_id in GEAR.ZONES:
		main.current_zone_id=zone_id
		main._build_combat_screen();await settle()
		var terrain=main.combat_labels.terrain
		check(terrain.zone_id==zone_id and is_instance_valid(terrain.map_root),zone_id+' has its own loaded 3D field')
		check(is_instance_valid(terrain.camera),zone_id+' has the live battle camera')
		for sprite: HeroSpriteController in main.hero_map_sprites:
			var rig: Node2D=sprite.get_node_or_null('PortraitHeroSkeletalRig')
			check(rig!=null and rig.bones.size()==21 and rig.mesh.get_bone_count()==21,zone_id+' heroes have weighted full body skeleton')
			check(rig.mesh.texture==rig._source_frame(sprite).atlas,zone_id+' weighted mesh keeps original hero atlas')
			check(sprite.get_node_or_null('PortraitGroundShadow')!=null,zone_id+' heroes have contact shadow')
		for sprite: MonsterSpriteController in main.enemy_wave_sprites:
			check(sprite.get_node_or_null('PortraitGroundShadow')!=null,zone_id+' monsters have contact shadow')
		var hero: HeroSpriteController=main.hero_map_sprites[0]
		var rig: Node2D=hero.get_node('PortraitHeroSkeletalRig')
		hero.play_attack();rig._process(rig.action_duration(str(hero.get('visual_action')))*.48)
		check(absf(rig.bones['LeftUpperArm'].rotation)+absf(rig.bones['RightUpperArm'].rotation)>.05 and absf(rig.bones['LeftForearm'].rotation)+absf(rig.bones['RightForearm'].rotation)>.05,zone_id+' attack articulates shoulder and elbow')
		hero.play_hit();rig._process(.09)
		check(absf(rig.bones['LeftUpperArm'].rotation)>0.1,zone_id+' received hit recoils the arm')
		var seen: Dictionary={}
		var zone: Dictionary=main._zone_data()[zone_id]
		for _roll in 210:
			var item: Dictionary=main._roll_equipment_drop(zone)
			if not item.is_empty():
				check(item.get('source_id')==zone_id and item.get('set')==zone['equipment_set'],zone_id+' keeps source and regional set')
				seen[item.get('hunt_role','')]=true
		check(seen.size()==3 and seen.has('dealer') and seen.has('defender') and seen.has('support'),zone_id+' production drop includes all role families')
		main._build_world_map_screen();await settle()
	for role in GEAR.HUNT_ROLES:
		for zone_id in GEAR.ZONES:
			var item: Dictionary=GEAR.hunt_item(zone_id,'weapon','희귀',main.loot_rng,role)
			check(item['hunt_role']==role and item['affixes'][0]['stat']==GEAR.HUNT_ROLE_STATS[role],zone_id+' '+role+' gets its role-specific stat')
			check(main._normalize_inventory_item(item)['hunt_role']==role,zone_id+' '+role+' survives persistence normalization')
			var matching:=0
			for hero_id in ['leonhardt','mira','elisia','orwin']:
				if main._gear_role_matches(item,hero_id):matching+=1
			check(matching>0 and matching<4,zone_id+' '+role+' cannot equip to an incompatible class')
	if main.presentation_runtime!=null:main.presentation_runtime.audio.shutdown()
	await create_timer(.35).timeout
	main.free()
	await create_timer(.1).timeout
	print('v61_field_roles_motion ',checks-errors.size(),'/',checks,' pass')
	quit(0 if errors.is_empty() else 1)
