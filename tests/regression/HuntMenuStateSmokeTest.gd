extends "res://tests/support/V83UpgradeTestBase.gd"
class FailedStore extends SaveStore:
	func write_save(_path: String, _data: Dictionary) -> Dictionary: return {"ok":false,"status":"injected_live_menu_failure"}

func _init() -> void: run.call_deferred()

func phone(main: Node, named: String) -> void:
	var control: Control=main.content_root.find_child(named,true,false)
	check(control!=null,"touch control exists "+named)
	if control==null:return
	var point:=root.get_final_transform()*control.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.position=point;event.pressed=down
		Input.parse_input_event(event)
	await settle()

func inspect(main: Node, id: String, tab: String) -> void:
	main.set_meta("hero_showcase_tab",tab);main._build_hero_detail_screen(id);await settle()

func check_party_memory(main: Node, faction: String) -> void:
	var ids: Array=main._deployed_hero_ids().duplicate()
	var id: String=ids[0]
	main._toggle_combat(main.combat_labels.toggle)
	for hit in 20:
		if int(main.hero_battle_state[id].hp)<=0:break
		main._incoming_damage_to_hero(id,int(main.hero_battle_state[id].max_hp)*1000)
	check(int(main.hero_battle_state[id].hp)==0,faction+" casualty uses the production damage path")
	main.hero_skill_runtime[id].remaining=float(main.hero_skill_runtime[id].profile.cooldown)
	main.hero_skill_runtime[id].secondary_remaining=2.8
	main.pet_runtime.remaining=5.2
	var cooldown: float=main.hero_skill_runtime[id].remaining
	await inspect(main,id,"growth")
	await phone(main,"HeroDeployAction");main._advance_auto_hunt(0.0)
	check(not main.hero_battle_state.has(id),faction+" removed hunter cannot act or be targeted")
	main._open_home();await settle() # The ledger must survive a Home visit.
	await inspect(main,id,"growth")
	await phone(main,"HeroDeployAction");main._advance_auto_hunt(0.0)
	check(int(main.hero_battle_state[id].hp)==0 and not main.hero_battle_state[id].alive,faction+" re-entry cannot revive a casualty")
	check(main.hero_skill_runtime[id].remaining==cooldown and main.hero_skill_runtime[id].secondary_remaining==2.8,faction+" both cooldowns survive re-entry")
	check(main.pet_runtime.remaining==5.2,faction+" formation edits do not recharge the guardian")
	main._open_home();await settle()
	main._toggle_combat(main.combat_labels.toggle);main._advance_auto_hunt(.05)
	check(main.hero_battle_state[id].hp<int(main.hero_battle_state[id].max_hp)/10 and main.hero_skill_runtime[id].remaining>=cooldown-.06,faction+" active hunt permits only normal recovery and cooldown passage after re-entry")
	main._toggle_combat(main.combat_labels.toggle)
	var healthy: String=ids[1]
	main.hero_battle_state[healthy].hp=int(main.hero_battle_state[healthy].max_hp)/2
	main.hero_battle_state[healthy].shield=47;main.hero_battle_state[healthy].ultimate=64.0
	var ratio: float=float(main.hero_battle_state[healthy].hp)/float(main.hero_battle_state[healthy].max_hp)
	for attempt in 3:
		await inspect(main,healthy,"growth")
		await phone(main,"HeroDeployAction");main._advance_auto_hunt(0.0)
		# Growth while benched changes stats, but must not refill HP.
		main.hero_progress[healthy].level+=1;main._refresh_growth_runtime()
		await phone(main,"HeroDeployAction");main._advance_auto_hunt(0.0)
		var state: Dictionary=main.hero_battle_state[healthy]
		check(absf(float(state.hp)/float(state.max_hp)-ratio)<.002,faction+" repeated swap/growth retains injured HP ratio")
		check(state.shield==47 and state.ultimate==64.0,faction+" swap retains shield and ultimate energy")
		main._open_home();await settle()
	main._build_world_map_screen();await settle()
	main._select_zone_for_hunt("forgotten_mine");await settle()
	check(main.hero_battle_state[id].hp==main.hero_battle_state[id].max_hp and main.hero_battle_state[id].alive and main.background_hunt.benched.is_empty(),faction+" entering a different region clears the previous encounter ledger")
	main._select_zone_for_hunt("gray_meadow");await settle()

func check_live_menu(main: Node, faction: String) -> void:
	var id: String=main._deployed_hero_ids()[0]
	main.wallet_gold=1199
	await inspect(main,id,"ascension")
	var panel: Control=main.content_root.find_child("HeroShowcaseView",true,false)
	var ascend: Button=main.content_root.find_child("HeroAscendAction",true,false)
	var money: Label=panel.find_child("HeroGoldValue",true,false)
	check(ascend.disabled,faction+" unaffordable ascension starts disabled")
	var scroll: ScrollContainer=main.content_root.get_node("PortraitContentScroll")
	scroll.scroll_vertical=28;await settle()
	var offset: int=scroll.scroll_vertical
	var roster: ScrollContainer=panel.find_child("HeroRosterScroll",true,false)
	roster.scroll_vertical=80;await settle()
	var roster_offset: int=roster.scroll_vertical
	main.content_root.find_child("HeroTab_ascension",true,false).grab_focus()
	var focus: Control=root.gui_get_focus_owner()
	for step in 400:
		main._advance_auto_hunt(.1)
		if step%40==0:await process_frame
	await settle()
	check(main.wallet_gold>=1200 and main.combat_hunt_cycle>0,faction+" real hidden hunting crosses ascension affordability")
	check(money.text==main._compact_hud_amount(main.wallet_gold) and money.tooltip_text==str(main.wallet_gold),faction+" hero wallet updates after hunting income")
	check(not ascend.disabled,faction+" newly affordable ascension enables without navigation")
	check(main.content_root.find_child("HeroShowcaseView",true,false)==panel and scroll.scroll_vertical==offset and roster.scroll_vertical==roster_offset and root.gui_get_focus_owner()==focus,faction+" live update preserves presenter, both scrolls and focus")
	main.wallet_gold=0;await settle()
	check(ascend.disabled,faction+" spending gold disables ascension again")
	main.wallet_gold=10000;await settle()
	main.save_store=FailedStore.new();main._save_idle_state();await settle()
	check(ascend.disabled,faction+" live affordability cannot bypass save safety")
	main.save_store=SaveStore.new();main._save_idle_state();await settle()
	check(not ascend.disabled,faction+" recovered save enables affordable action in place")
	main.hero_progress[id]={"level":3,"xp":main._hero_xp_to_next(3)-1};main.hero_skill_tree[id]={"offense":0,"survival":0,"utility":0}
	main._refresh_growth_runtime();await inspect(main,id,"growth")
	var level: Label=main.content_root.find_child("HeroLevelValue",true,false)
	var research: Button=main.content_root.find_child("HeroResearch_offense",true,false)
	check(research.disabled,faction+" level three has no research points")
	var old_attack: int=main.content_root.find_child("HeroStat_attack",true,false).get_meta("combat_value")
	main._grant_hero_xp(3);await settle()
	check(int(main._get_hero_progress(id).level)==4 and level.text=="LEVEL  4 / 100",faction+" XP grant updates the level in place")
	check(not research.disabled and main.content_root.find_child("HeroResearchPoints",true,false).text.contains("1 P"),faction+" newly earned research point enables the action")
	check(main.content_root.find_child("HeroStat_attack",true,false).get_meta("combat_value")>old_attack,faction+" displayed combat stats track actual growth")
	var xp: int=main._get_hero_progress(id).xp
	check(main.content_root.find_child("HeroExperienceBar",true,false).value==xp and main.content_root.find_child("HeroExperienceValue",true,false).text.contains(str(xp)),faction+" XP bar and amount update together")
	await inspect(main,id,"ascension")
	var cost: int=main._breakthrough_cost(main._hero_breakthrough_rank(id))
	main.hero_shards[id]=cost;await settle()
	check(not main.content_root.find_child("HeroBreakthroughAction",true,false).disabled and main.content_root.find_child("HeroShardBalance",true,false).text.contains("조각 %d개"%cost),faction+" shard balance and breakthrough availability update together")
	main._build_inventory_screen();await settle()
	var inventory: Control=main.content_root.find_child("EquipmentWorkbench",true,false)
	main.wallet_gold+=123;await settle()
	check(main.content_root.find_child("GearGoldValue",true,false).tooltip_text==str(main.wallet_gold) and main.content_root.find_child("EquipmentWorkbench",true,false)==inventory,faction+" inventory wallet refresh preserves the open workbench")
	main._open_home();await settle()

func check_offline_notice(main: Node, faction: String) -> void:
	var id: String=main._deployed_hero_ids()[0]
	await inspect(main,id,"growth")
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED);main.last_idle_timestamp-=120
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED);await settle()
	check(main.offline_reward_seconds==120 and main._offline_notice_pending and not main.content_root.has_node("OfflineRewardPopup"),faction+" menu resume retains a deferred offline notice")
	var pending: int=main.offline_pending_gold+main.offline_pending_chest_gold
	check(pending>0,faction+" suspension created claimable offline earnings")
	main._open_home();await settle()
	var popup: Control=main.content_root.get_node_or_null("OfflineRewardPopup")
	check(popup!=null and not main._offline_notice_pending,faction+" returning Home displays the deferred receipt once")
	main._open_home();await settle()
	check(main.content_root.get_node_or_null("OfflineRewardPopup")==popup and main.offline_pending_gold+main.offline_pending_chest_gold==pending,faction+" repeated Home neither duplicates the notice nor credits rewards")
	var before: int=main.wallet_gold
	await phone(main,"DialogConfirm")
	check(main.wallet_gold==before+pending and main.offline_pending_gold+main.offline_pending_chest_gold==0,faction+" popup touch claims the exact pending gold")
	main._claim_offline_rewards();main._open_home();await settle()
	check(main.wallet_gold==before+pending and not main.content_root.has_node("OfflineRewardPopup"),faction+" repeated claim and Home cannot pay or notify twice")
	# A paused hunt also receives its notice, and a claim from camp cancels it.
	main._toggle_combat(main.combat_labels.toggle)
	main._build_lobby_screen();await settle()
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED);main.last_idle_timestamp-=120
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED);await settle()
	main._open_home();await settle()
	check(not main.combat_running and main.content_root.has_node("OfflineRewardPopup"),faction+" Home notice preserves a manually paused hunt")
	await phone(main,"DialogConfirm")
	main._build_lobby_screen();await settle()
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED);main.last_idle_timestamp-=120
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED);await settle()
	main._claim_offline_rewards();main._open_home();await settle()
	check(not main._offline_notice_pending and not main.content_root.has_node("OfflineRewardPopup"),faction+" claiming in camp cancels the deferred notice")
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED);await settle()
	check(not main.content_root.has_node("OfflineRewardPopup"),faction+" brief suspension with no earnings produces no popup")

func run() -> void:
	Input.set_use_accumulated_input(false);Input.emulate_mouse_from_touch=true
	for faction in ["aurelia","noxfera"]:
		var main=await make_main(faction,3)
		root.size=Vector2i(1280,720);await settle();main._open_home();await settle()
		await check_party_memory(main,faction)
		await check_live_menu(main,faction)
		await check_offline_notice(main,faction)
		await dispose(main)
	done("HUNT_MENU_STATE")
