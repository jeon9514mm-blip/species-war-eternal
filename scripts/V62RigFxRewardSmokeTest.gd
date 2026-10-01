extends SceneTree
const RIG:=preload('res://scripts/portrait/PortraitHeroSkeletalRig.gd')
const ROSTER:=preload('res://scripts/HeroRosterCatalog.gd')
const FACTORY:=preload('res://scripts/HeroSpriteFactory.gd')
var checks:=0
var failures: Array[String]=[]

func check(value: bool, description: String) -> void:
	checks+=1
	if not value:failures.append(description);push_error('V62 '+description)

func _initialize() -> void:run.call_deferred()

func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	for hero_id in ROSTER.HEROES:
		var hero: HeroSpriteController=FACTORY.create_hero(str(hero_id))
		root.add_child(hero)
		var rig:=RIG.new()
		check(rig.install(hero),str(hero_id)+' atlas is accepted')
		if rig.actor!=null:
			check(rig.bones.size()==13 and rig.mesh.get_bone_count()==13,str(hero_id)+' full skeleton is weighted')
			check(rig.mesh.uv.size()==169 and rig.mesh.polygons.size()==144,str(hero_id)+' atlas mesh has continuous cells')
			hero.play_walk(Vector2.RIGHT);rig._process(.11)
			check(absf(rig.bones['LeftThigh'].rotation)+absf(rig.bones['RightThigh'].rotation)>.01,str(hero_id)+' legs stride independently')
			hero.play_attack();rig._process(.12)
			check(absf(rig.bones['RightUpperArm'].rotation)>.1,str(hero_id)+' attack drives right arm')
		hero.free()
	var main:=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v62-rig-reward.json'
	root.add_child(main)
	for i in 4:await process_frame
	main.selected_faction='aurelia';main._restore_deployed_heroes(['leonhardt','mira','elisia'])
	main._build_combat_screen()
	for i in 4:await process_frame
	check(main.portrait_hud.reward_feed!=null and main.portrait_hud.reward_feed.position.y<main.portrait_hud.auto_button.position.y,'reward feed sits above combat buttons')
	var wallet: int=main.wallet_gold
	var drops: Array[Dictionary]=[{'item':{'name':'테스트 갑옷','rarity':'희귀'},'handling':'보관함에 저장'}]
	main._on_hunt_reward(145,42,drops,false)
	var feed: Node=main.portrait_hud.reward_feed
	check(feed.gold_line.visible and feed.item_line.visible and '145' in feed.gold_text.text and '테스트 갑옷' in feed.item_text.text,'actual reward receipt drives bottom feed')
	check(main.wallet_gold==wallet,'visual feedback cannot claim pending gold')
	main._spawn_floating_combat_text('-128',Color.RED,Vector2(360,580))
	check(get_nodes_in_group('floating_combat_text').size()>0,'combat numbers animate in dedicated layer')
	main._emit_skill_cast_fx('mira',-1,false,{'slot':'a1','fx_targets':[]},false)
	check(main.skill_fx_layer.find_child('PortraitSkillBurst',true,false)!=null,'skill cast drives dedicated role flare inside the combat clip')
	main.free()
	print('v62_rig_fx_reward ',checks-failures.size(),'/',checks,' pass')
	quit(0 if failures.is_empty() else 1)
