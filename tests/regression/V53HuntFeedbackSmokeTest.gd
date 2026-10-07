extends SceneTree
## Deliver real clicks to the visible hunting HUD and its information panel.
var main: Node
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error('V53 hunt feedback: '+message)
func settle() -> void:
	for frame in 8:await process_frame
func click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;root.push_input(event,true)
func escape() -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=down;root.push_input(event,true)
func button(caption: String, scope: Node = null) -> Button:
	for node in (main.content_root if scope==null else scope).find_children('*','Button',true,false):
		if node.text==caption:return node
	return null
func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate();main.save_state_path='user://v53-hunt-feedback.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main._offline_checked=true;main.combat_effects_enabled=false
	main.selected_faction='aurelia';main.idle_stage=25;main.party_slot_legacy_cap=10
	main.deployed_heroes=main._hero_roster_for_faction().slice(0,10)
	for dimensions: Vector2i in [Vector2i(720,1280),Vector2i(810,1440),Vector2i(720,1560)]:
		root.size=dimensions;await settle()
		main._build_combat_screen();await settle()
		var hud: Control=main.portrait_hud
		for option: Button in [hud.skill_button,hud.ultimate_button,hud.offline_button]:
			check(main.get_viewport_rect().encloses(option.get_global_rect()),option.name+' fits the viewport')
			var face: Font=option.get_theme_font('font')
			var measured:=face.get_string_size(option.text,HORIZONTAL_ALIGNMENT_LEFT,-1,option.get_theme_font_size('font_size')).x
			check(measured<option.size.x-18,option.name+' caption does not clip')
		check(not hud.reward_feed.get_global_rect().intersects(hud.skill_button.get_global_rect()),'reward feed cannot cover skill auto')
		check(not hud.ultimate_button.get_global_rect().intersects(hud.auto_button.get_global_rect()),'ultimate toggle cannot cover hunting controls')
		var details: Control=main.combat_labels['details_panel']
		check(not details.visible,'information starts closed')
		click(main.portrait_hud.details_button.get_global_rect().get_center());await settle()
		check(details.visible and main._hunt_details_layer.visible,'real information button opens input layer')
		check(main.portrait_hud.details_button.text=='정보 닫기','information toggle caption agrees with open state')
		var running: bool=main.combat_running
		var speed: float=main.battle_speed
		for target: Control in [main.portrait_hud.auto_button,main.portrait_hud.speed_button,main.portrait_hud.skill_button,main.portrait_hud.ultimate_button,main.portrait_hud.get_node('PortraitNavigation/PortraitNav_heroes')]:
			click(target.get_global_rect().get_center());await settle()
			check(main.active_screen=='combat' and main.combat_running==running and main.battle_speed==speed,'information panel blocks hidden commands '+target.name)
		check(main.get_viewport_rect().encloses(details.get_global_rect()),'information panel fits viewport')
		escape();await settle()
		check(not details.visible and not main._hunt_details_layer.visible,'back key closes panel and removes input blocker')
		click(main.portrait_hud.auto_button.get_global_rect().get_center());await settle()
		check(not main.combat_running and '재개' in main.portrait_hud.auto_button.text,'pause works again after panel closes')
		click(main.portrait_hud.details_button.get_global_rect().get_center());await settle()
		var close:=button('사냥터 정보 닫기',details)
		check(close!=null,'information panel has its own visible close button')
		click(close.get_global_rect().get_center());await settle()
		check(not details.visible and not main.combat_running,'real close button preserves paused state')
		click(main.portrait_hud.auto_button.get_global_rect().get_center());await settle()
		check(main.combat_running,'resume works after closing the information panel')
	# Keep the same live modal across a size change. No HP/cooldown reset.
	main._toggle_hunt_details();await settle()
	var before: Dictionary=main.hero_battle_state.duplicate(true)
	root.size=Vector2i(720,1280);await settle()
	var details: Control=main.combat_labels['details_panel']
	check(details.visible and main._hunt_details_layer.visible,'resize preserves the open information panel')
	check(before==main.hero_battle_state,'open-panel resize preserves combat HP/statuses')
	click(main.portrait_hud.get_node('PortraitNavigation/PortraitNav_heroes').get_global_rect().get_center());await settle()
	check(main.active_screen=='combat','resized backdrop continues to block navigation')
	# The actions at the bottom remain reachable through the real scroll container.
	var scroll: ScrollContainer=main.combat_labels['details_scroll']
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await settle()
	var next: Button=main.combat_labels['zone_button']
	check(scroll.get_global_rect().encloses(next.get_global_rect()),'next hunting zone is reachable after scrolling')
	var old_zone: String=main.current_zone_id
	click(next.get_global_rect().get_center());await settle()
	check(main.current_zone_id!=old_zone and main.active_screen=='combat','visible next-zone action changes hunting zone')
	check(main.combat_labels['terrain'].zone_id==main.current_zone_id,'new terrain matches selected zone')
	check(str(main._current_zone()['name']) in main.portrait_hud.stage_label.text,'field header reflects new zone')
	check(not main._hunt_details_layer.visible and not main.combat_labels['details_panel'].visible,'zone change leaves no stale modal or input blocker')
	# Claim offline rewards while the live encounter and pause state survive.
	main.unclaimed_gold=123;main.idle_chest_gold=77
	main.unclaimed_xp=13;main.idle_chest_xp=7
	main.offline_pending_gold=123;main.offline_pending_chest_gold=77
	main.offline_pending_xp=13;main.offline_pending_chest_xp=7
	main.portrait_hud.refresh()
	var gold_before: int=main.wallet_gold
	var xp_before: int=main.wallet_xp
	var state_before: Dictionary=main.hero_battle_state.duplicate(true)
	var wave_before: Array=main.enemy_wave.duplicate(true)
	check(not main.portrait_hud.offline_button.disabled and '오프라인' in main.portrait_hud.offline_button.text,'offline proceeds are visible without leaving battle')
	click(main.portrait_hud.offline_button.get_global_rect().get_center());await settle()
	var confirm: Button=main.content_root.find_child('DialogConfirm',true,false)
	check(confirm!=null and confirm.text=='오프라인 사냥 받기','offline panel has an explicit receipt action')
	if confirm!=null:click(confirm.get_global_rect().get_center());await settle()
	check(main.wallet_gold==gold_before+200 and main.wallet_xp==xp_before+20,'real claim button transfers earned rewards exactly once')
	check(main.unclaimed_gold==0 and main.unclaimed_xp==0 and main.idle_chest_gold==0 and main.idle_chest_xp==0,'claim clears every pending reward bucket')
	check(main.hero_battle_state==state_before and main.enemy_wave==wave_before and main.combat_running,'claim preserves the running encounter and HP')
	check(main.portrait_hud.gold_label.text==main._compact_hud_amount(main.wallet_gold),'claim immediately refreshes displayed wallet')
	check(main.portrait_hud.offline_button.disabled and main.portrait_hud.offline_button.text=='오프라인 보상 없음','empty offline receipt becomes disabled')
	click(main.portrait_hud.offline_button.get_global_rect().get_center());await settle()
	check(main.wallet_gold==gold_before+200 and main.wallet_xp==xp_before+20,'repeated real click cannot duplicate rewards')
	main.unclaimed_xp=9;main.offline_pending_xp=9;main.portrait_hud.refresh()
	main.portrait_hud._toggle_auto()
	check(not main.portrait_hud.offline_button.disabled,'XP-only offline reward remains claimable')
	click(main.portrait_hud.offline_button.get_global_rect().get_center());await settle()
	confirm=main.content_root.find_child('DialogConfirm',true,false)
	if confirm!=null:click(confirm.get_global_rect().get_center());await settle()
	check(main.wallet_xp==xp_before+29 and not main.combat_running,'claim works while paused and preserves pause')
	main.portrait_hud._toggle_auto()
	for rewards: Array in [[0,0,51,12],[9876543212345,87654321,112233,44],[0,0,0,19]]:
		main.unclaimed_gold=rewards[0];main.unclaimed_xp=rewards[1]
		main.idle_chest_gold=rewards[2];main.idle_chest_xp=rewards[3]
		main.offline_pending_gold=rewards[0];main.offline_pending_xp=rewards[1]
		main.offline_pending_chest_gold=rewards[2];main.offline_pending_chest_xp=rewards[3]
		main.portrait_hud.refresh();await settle()
		var claim: Button=main.portrait_hud.offline_button
		var font: Font=claim.get_theme_font('font')
		var style: StyleBox=claim.get_theme_stylebox('normal')
		var text_width:=font.get_string_size(claim.text,HORIZONTAL_ALIGNMENT_LEFT,-1,claim.get_theme_font_size('font_size')).x
		check(text_width+style.get_content_margin(SIDE_LEFT)+style.get_content_margin(SIDE_RIGHT)<=claim.size.x,'offline action caption fits the 720-pixel HUD')
		check(main.get_viewport_rect().encloses(claim.get_global_rect()),'reward button stays inside the small viewport')
		check(not claim.get_global_rect().intersects(main.portrait_hud.get_node('PortraitMoreButton').get_global_rect()),'reward and menu touch areas never overlap')
		var gold: int=main.wallet_gold;var xp: int=main.wallet_xp
		click(claim.get_global_rect().get_center());await settle()
		confirm=main.content_root.find_child('DialogConfirm',true,false)
		if confirm!=null:click(confirm.get_global_rect().get_center());await settle()
		check(main.wallet_gold==gold+int(rewards[0])+int(rewards[2]) and main.wallet_xp==xp+int(rewards[1])+int(rewards[3]),'chest/large/XP-only rewards transfer exactly once')
		check(main.portrait_hud.offline_button.disabled,'each offline reward state disables after collection')
	var id: String=str(main.deployed_heroes[0]['id'])
	main.hero_battle_state[id]['hp']=int(main.hero_battle_state[id]['max_hp']*.2)
	main.portrait_hud.refresh()
	check(main.portrait_hud.bars[id]['hp_band']==0,'low HP has the critical color')
	main.hero_battle_state[id]['hp']=main.hero_battle_state[id]['max_hp']
	main.portrait_hud.refresh()
	check(main.portrait_hud.bars[id]['hp_band']==2,'recovery restores normal HP color')
	# An empty expedition must offer a working way to deploy a hero.
	main.deployed_heroes=[];main.idle_stage=1;main.party_slot_legacy_cap=1
	main._build_combat_screen();await settle()
	check('영웅 편성' in main.portrait_hud.auto_button.text,'empty party offers formation instead of unusable resume')
	check('영웅을 편성' in main.portrait_hud.status_label.text,'empty-party status explains why hunting cannot begin')
	click(main.portrait_hud.auto_button.get_global_rect().get_center());await settle()
	check(main.active_screen=='hero_select','empty-party action opens the real roster')
	main._clear_screen();main.free();await settle()
	print('V53 HUNT FEEDBACK ',checks-failures.size(),'/',checks,' PASS')
	quit(0 if failures.is_empty() else 1)
