extends "res://scripts/V83UpgradeTestBase.gd"
const GUIDE=preload("res://scripts/FirstSessionGuide.gd")
const RULES=preload("res://scripts/GrowthEconomyRules.gd")
const RECOVERY=preload("res://scripts/RaidRecoveryGuide.gd")
const SAVE=preload("res://scripts/GameSaveCoordinator.gd")
const VALIDATION=preload("res://scripts/SaveValidation.gd")
const FIELD=preload("res://scripts/HuntFieldService.gd")
func _init() -> void: run.call_deferred()
func tap(button: Button) -> void:
	var point: Vector2=root.get_final_transform()*button.get_global_rect().get_center()
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.position=point;event.pressed=down;Input.parse_input_event(event)
	await settle()
func run() -> void:
	Input.set_use_accumulated_input(false);Input.emulate_mouse_from_touch=true
	_test_curves()
	for faction: String in ["aurelia","noxfera"]:
		root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
		var main=HOST.new();main.save_state_path="user://first-session-"+faction+"-"+str(Time.get_ticks_usec())+".json"
		root.add_child(main);await settle();main.set_process(false);main.set_physics_process(false)
		main._offline_checked=true;main.combat_effects_enabled=false;main.sound_effects_enabled=false
		main.selected_faction=faction;main.current_zone_id="gray_meadow";main.idle_stage=1;main.party_slot_legacy_cap=0
		var roster: Array=main._hero_roster_for_faction();var id: String=str(roster[0].id)
		main._restore_deployed_heroes([id]);main.tutorial_completed=false;main.tutorial_actions={};main.tutorial_step=0
		main._refresh_tutorial_state();check(main.tutorial_step==2,"fresh account starts first hunt guide "+faction)
		main._open_home();await settle()
		root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280);main._build_combat_screen();await settle()
		var phone_cta: Button=main.content_root.find_child("FirstSessionGuideAction",true,false)
		check(phone_cta!=null and phone_cta.is_visible_in_tree() and phone_cta.get_global_rect().end.y<=1280,"portrait home shows guide without opening settings")
		root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);main._build_combat_screen();await settle()
		var hud: Node=main.content_root.find_child("PortraitHud",true,false)
		var cta: Button=hud.find_child("FirstSessionGuideAction",true,false) if hud!=null else null
		check(cta!=null and cta.visible and cta.size.y>=44,"hunting home exposes touch-sized guide action "+faction)
		if cta!=null:
			await tap(cta)
			check(main.content_root.find_child("FirstSessionGuideContinue",true,false)!=null,"hunt guide has an actionable continuation")
			await tap(main.content_root.find_child("FirstSessionGuideContinue",true,false));await settle()
		main.combat_kills=10;main.idle_stage=2;main.hero_progress[id]={"level":10,"xp":0}
		main._roll_equipment_drop(main._current_zone());main._refresh_tutorial_state()
		check(main.tutorial_step==4 and not main.tutorial_actions.has("growth"),"passive XP and drops never skip deliberate growth")
		check(not GUIDE.restore(main,{}).has("growth"),"legacy level and passive loot cannot infer manual growth")
		main._follow_first_session_guide();await settle()
		check(main.active_screen=="hero_detail" and main.get_meta("hero_showcase_tab","")=="growth","research CTA opens points screen")
		main.wallet_gold=0
		check(not main._gear_enhance_item("",id,"weapon").ok and not main.tutorial_actions.has("growth"),"failed enhancement never completes guide")
		main._upgrade_skill_tree(id,"offense");main._refresh_tutorial_state()
		check(main.tutorial_step==5 and bool(main.tutorial_actions.get("growth",false)),"actual point spending advances guide")
		check(GUIDE.status(main).route=="hunt","stage two directs back to unlock three slots")
		main.idle_stage=3
		check(GUIDE.status(main).route=="party","solo party is asked to fill unlocked slots")
		if faction=="noxfera":
			check("스테이지 5" in GUIDE.status(main).text,"early noxfera formation explains the healer unlock")
			main._restore_deployed_heroes([str(roster[0].id),str(roster[1].id),str(roster[3].id)])
			main.raid_outcome="defeat"
			check(RECOVERY.advice(main).route=="hunt" and "스테이지 5" in RECOVERY.advice(main).text,"locked support directs to attainable hunting goal")
		main._restore_deployed_heroes([str(roster[0].id),str(roster[1].id),str(roster[2].id)])
		check(GUIDE.status(main).route=="raid" and "권장" in GUIDE.status(main).text,"three-person party sees honest raid readiness")
		main._follow_first_session_guide();await settle();var gold_before: int=main.wallet_gold
		main._start_raid();main._start_raid()
		if is_instance_valid(main.combat_timer):main.combat_timer.stop()
		main._refresh_tutorial_state()
		check(main.raid_running and main.tutorial_completed and main.wallet_gold==gold_before,"one free raid entry completes instruction without paying clear rewards")
		main.raid_pattern_count=2;main.raid_evaded_hits=0;main._finish_raid("defeat");await create_timer(.15).timeout;await settle()
		check("다음 행동" in main.raid_last_result and "회피 기록" in main.raid_last_result,"failure explains next action and missed dodges")
		var recovery: Button=main.content_root.find_child("RaidRecoveryAction",true,false)
		check(recovery!=null and recovery.visible and recovery.size.y>=44,"failure offers a touch-sized improvement button")
		if recovery!=null:
			var view: Node=main.content_root.get_node("PortraitRaidView")
			check(view.landscape_info.get_global_rect().encloses(view.state_scroll.get_global_rect()) and view.landscape_info.get_global_rect().encloses(recovery.get_global_rect()),"failure explanation and action both stay visible on phone")
			var expected: String="growth" if RECOVERY.advice(main).route=="growth" else "hero_select"
			await tap(recovery);check(main.active_screen==expected,"phone tap on failure advice reaches recommended screen "+faction+" "+main.active_screen)
		var saved: Dictionary=SAVE.snapshot(main)
		var clean: Dictionary=VALIDATION.sanitize(saved,main._zone_data().keys())
		check(clean.tutorial_actions==main.tutorial_actions and clean.tutorial_completed,"guide milestones survive validated save snapshot")
		main._save_idle_state();main.tutorial_actions={};main.tutorial_completed=false;main._load_idle_state()
		check(main.tutorial_completed and main.tutorial_actions==clean.tutorial_actions,"disk save reload retains completed milestones")
		main.tutorial_completed=false;main.tutorial_actions={};main.idle_stage=2
		main.hero_progress[id]={"level":1,"xp":0};main.wallet_gold=0;main._refresh_tutorial_state()
		check(GUIDE.status(main).route=="hunt" and "더 모으면" in GUIDE.status(main).text,"cash shortage explains how to reach first enhancement")
		main.wallet_gold=main._inventory_upgrade_cost(main._gear_item("",id,"weapon"))
		check(GUIDE.status(main).route=="enhance","affordable weapon has a direct enhancement route")
		main._follow_first_session_guide();await settle()
		check(main.content_root.find_child("EquipmentDetailHeader",true,false)!=null and main.content_root.find_child("DetailTab_enhance",true,false)!=null,"enhancement route opens item details")
		check(main._gear_enhance_item("",id,"weapon").ok and bool(main.tutorial_actions.get("growth",false)),"successful paid enhancement records growth")
		check(bool(GUIDE.restore(main,{}).get("growth",false)),"legacy real investment restores the milestone")
		check(GUIDE.restore(main,{"tutorial_actions":{}}).is_empty(),"new saves never infer an action from passive state")
		main.tutorial_completed=false;main.tutorial_actions={};main.set_meta("practice_active",true)
		main._record_first_session_action("growth");check(main.tutorial_actions.is_empty(),"practice cannot mark actual growth")
		main.set_meta("practice_active",false);main.set_meta("game_save_pending",true)
		main._record_first_session_action("growth");check(main.tutorial_actions.is_empty(),"pending save blocks new milestones")
		main.set_meta("game_save_pending",false);main._save_blocked_for_newer_version=true
		main._record_first_session_action("growth");check(main.tutorial_actions.is_empty(),"future save remains untouched")
		main._save_blocked_for_newer_version=false
		main._restore_deployed_heroes([str(roster[1].id)])
		check(RECOVERY.advice(main).route=="party","missing tank/support receives formation advice")
		main.raid_outcome="timeout";check(RECOVERY.advice(main).route=="growth","timeout receives offense growth advice")
		main.idle_stage=1;var weak: Array=FIELD.generate_corps(main,main._current_zone())
		main.idle_stage=3;var normal: Array=FIELD.generate_corps(main,main._current_zone())
		check(int(weak[0].max_hp)<int(normal[0].max_hp) and weak.size()>=15 and normal.size()>=15,"starter relief preserves population and ends at stage three")
		main.hunt_productivity={};main._offline_checked=false;main.last_idle_timestamp=int(Time.get_unix_time_from_system())-28800
		main._calculate_offline_reward()
		check("보수적" in main.offline_reward_basis and main.offline_reward_xp<=10000,"unmeasured solo receipt uses conservative starter allowance")
		check(main.offline_stage_clears<=5 and main.offline_gear_rolls<=32,"receipt keeps stage and mobile loot work caps")
		var once: Dictionary=economic(main);main._calculate_offline_reward();check(economic(main)==once,"one offline period is never awarded twice")
		main._claim_offline_rewards();var claimed: int=main.wallet_gold;main._claim_offline_rewards();check(main.wallet_gold==claimed,"receipt claim remains idempotent")
		await dispose(main)
	done("first_session_economy")
func _test_curves() -> void:
	check(GUIDE.sanitize({"growth":true,"raid_started":false,"junk":true})=={"growth":true},"only real booleans and known milestones accepted")
	for bad: Variant in [[],"done",12,null]:check(GUIDE.sanitize(bad).is_empty(),"malformed guide flags rejected")
	for level in range(1,21):check(RULES.xp_cost(level,100)==100+(level-1)*75,"early XP cost unchanged")
	for level in range(2,101):check(RULES.xp_cost(level,100)>RULES.xp_cost(level-1,100),"XP costs rise monotonically")
	for level in range(1,5):
		for slot: String in ["weapon","armor","accessory"]:
			check(RULES.equipment_cost(slot,level)==(100+level*75)*int({"weapon":1,"armor":2,"accessory":3}[slot]),"first four enhancement costs unchanged")
	for level in range(2,10):check(RULES.equipment_cost("weapon",level)>RULES.equipment_cost("weapon",level-1),"late enhancement costs rise")
	for size in range(1,11):check(RULES.unmeasured_pack_interval(size)>=18.9,"unmeasured receipts never use fast theoretical pace")
