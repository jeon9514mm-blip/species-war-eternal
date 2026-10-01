extends SceneTree
## Uses real viewport mouse input and Godot-shaped text. Cross-parent text
## comparisons catch fixed regions colliding even when sibling checks pass.
## Physical small windows keep the supported 720-wide production canvas.
var main: Node
var checks := 0
var failures: Array[String] = []
var screens := 0
var exploratory_issues: Array[String] = []
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String, supported := true) -> void:
	if not supported:
		if not ok:exploratory_issues.append(message)
		return
	checks += 1
	if not ok:
		failures.append(message)
		push_error('V56 dungeon/roster UI: '+message)
func settle() -> void:
	for frame in 8:await process_frame
func node(named: String) -> Node:
	return main.content_root.find_child(named,true,false)
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point
		root.push_input(event,true)
func press_control(target: Button, label: String) -> void:
	check(target!=null,'action exists '+label)
	if target==null:return
	var ancestor: Node=target.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(target)
		ancestor=ancestor.get_parent()
	await settle()
	check(not target.disabled,'action enabled '+label)
	check(main.get_viewport_rect().grow(1).encloses(target.get_global_rect()),'action visible '+label)
	if target.disabled:return
	click(target.get_global_rect().get_center());await settle()
func press(named: String) -> void:
	await press_control(node(named),named)
func visible_rectangle(control: Control) -> Rect2:
	var rectangle: Rect2=control.get_global_rect().intersection(main.get_viewport_rect())
	var ancestor: Node=control.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents:rectangle=rectangle.intersection(ancestor.get_global_rect())
		ancestor=ancestor.get_parent()
	return rectangle
func separate(first: String, second: String, label: String, supported := true) -> void:
	var a: Control=node(first);var b: Control=node(second)
	check(a!=null and b!=null,label+' regions exist '+first+' / '+second,supported)
	if a==null or b==null:return
	var overlap: Rect2=a.get_global_rect().intersection(b.get_global_rect())
	check(overlap.size.x<=2 or overlap.size.y<=2,label+' regions do not collide '+first+' / '+second,supported)
func audit(label: String, supported := true) -> void:
	screens += 1
	var leaves: Array[Control]=[]
	var viewport: Rect2=main.get_viewport_rect()
	for control: Control in main.content_root.find_children('*','Control',true,false):
		if not control.is_visible_in_tree():continue
		if control is ScrollContainer:
			check(viewport.grow(1).encloses(control.get_global_rect()),label+' scroll fits viewport '+str(control.name),supported)
			if control.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED and control.get_child_count()>0:
				var body: Node=control.get_child(0)
				if body is Control:check(body.size.x<=control.size.x+1,label+' body fits width '+str(control.name),supported)
		if not (control is Label or control is Button) or control.text.is_empty():continue
		var rectangle: Rect2=control.get_global_rect()
		var clipped: Rect2=viewport
		var scrolls := false
		var ancestor: Node=control.get_parent()
		while ancestor is Control:
			if ancestor is ScrollContainer:scrolls=true
			if ancestor.clip_contents:clipped=clipped.intersection(ancestor.get_global_rect())
			ancestor=ancestor.get_parent()
		var caption: String=label+' '+str(control.name)+' '+control.text.left(24)
		check(rectangle.position.x>=clipped.position.x-1 and rectangle.end.x<=clipped.end.x+1,caption+' full width',supported)
		if not scrolls:check(viewport.grow(1).encloses(rectangle),caption+' fits viewport',supported)
		if control is Label:
			check(control.get_line_count()*control.get_line_height()<=control.size.y+2 or (control.max_lines_visible>0 and control.tooltip_text==control.text),caption+' readable height',supported)
			if control.autowrap_mode==TextServer.AUTOWRAP_OFF and not control.clip_text and control.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING:
				var width: float=control.get_theme_font('font').get_multiline_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size('font_size')).x
				check(width<=control.size.x+1,caption+' full text width',supported)
		else:
			check(control.size.y>=48 and control.size.x>=44,caption+' touch size',supported)
			if not control is OptionButton:
				var style: StyleBox=control.get_theme_stylebox('normal')
				var width: float=control.get_theme_font('font').get_multiline_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size('font_size')).x+style.get_content_margin(SIDE_LEFT)+style.get_content_margin(SIDE_RIGHT)
				check(width<=control.size.x+1 or (control.clip_text and control.tooltip_text==control.text),caption+' full button caption',supported)
		# Toasts are intentionally transient overlays, not page layout regions.
		if control.name!='ToastNotice':leaves.append(control)
	# Descendant text intentionally overlays its own button, but unrelated text
	# must not collide even when housed by different containers.
	var collisions: Array[String]=[]
	for index in leaves.size():
		var first: Control=leaves[index]
		var a: Rect2=visible_rectangle(first)
		if a.size.x<=2 or a.size.y<=2:continue
		for other_index in range(index+1,leaves.size()):
			var second: Control=leaves[other_index]
			if first.is_ancestor_of(second) or second.is_ancestor_of(first):continue
			var overlap: Rect2=a.intersection(visible_rectangle(second))
			if overlap.size.x>3 and overlap.size.y>3:
				collisions.append(str(first.name)+' ['+first.text.left(14)+'] / '+str(second.name)+' ['+second.text.left(14)+']')
	check(collisions.is_empty(),label+' cross-parent text collision '+str(collisions),supported)
	if node('PortraitRaidView')!=null:
		for names: Array in [['PortraitRaidStatus','PortraitRaidParty'],['PortraitRaidStatus','PortraitRaidActions'],['PortraitRaidArena','PortraitRaidActions'],['PortraitRaidActions','PortraitRaidParty'],['PortraitRaidParty','PortraitNavigation']]:
			separate(names[0],names[1],label,supported)
func fixture(faction := 'aurelia', count := 10, stage := 35) -> void:
	main.selected_faction=faction;main.idle_stage=stage;main.party_slot_legacy_cap=10 if stage>=25 else 0
	main.current_zone_id='gray_meadow';main.selected_raid_id='';main.hero_roster_filter='전체';main.hero_roster_sort='등급'
	main.deployed_heroes=main._hero_roster_for_faction().slice(0,count).duplicate(true)
	main._setup_hero_progress(main._hero_roster_for_faction())
	for hero: Dictionary in main._hero_roster_for_faction():main.hero_progress[str(hero['id'])]={'level':30 if stage>=25 else 1,'xp':0}
	main.wallet_gold=987654321;main.wallet_gems=87654321;main.wallet_xp=0
	main.daily_dungeon_day=main._today_key();main.daily_dungeon_runs=0;main.tower_floor=1;main.tower_best_floor=0
	main._reset_weekly_if_needed();main.weekly_trial_runs=0;main.weekly_trial_best=0
	main.raid_last_result='';main.set_meta('content_meta_tab','daily');main.set_meta('content_region_id','gray_meadow')
	main.loot_inventory.clear();main.equipment_overflow.clear()
func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280);root.gui_embed_subwindows=true
	main=preload('res://scenes/PortraitMain.tscn').instantiate();main.save_state_path='user://v56-dungeon-roster-ui.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main.set_process(false);main._offline_checked=true;main.tutorial_completed=true;main.combat_effects_enabled=false
	await verify_roster()
	await verify_dungeons()
	await verify_raid()
	await verify_sizes()
	main._clear_screen();main.free();await settle()
	print('V56 DUNGEON ROSTER UI ',checks-failures.size(),'/',checks,' PASS · ',screens,' screen states')
	print('600 logical width exploratory findings: ',exploratory_issues.size())
	for issue: String in exploratory_issues.slice(0,8):print('EXPLORATORY ',issue)
	quit(0 if failures.is_empty() else 1)
func verify_roster() -> void:
	fixture('aurelia',0,1);main._build_hero_select_screen();await settle()
	check(node('RosterConfirm').disabled,'empty first-run party cannot be saved')
	check(node('RosterPartyGrid').columns==5 and node('RosterPartyGrid').get_child_count()==10,'all ten party slots use five columns')
	check(not node('PartySlotScroll') is ScrollContainer,'party slots need no horizontal scrolling')
	var first_id: String=str(main._hero_roster_for_faction()[0]['id'])
	var locked := 0
	for hero: Dictionary in main._hero_roster_for_faction():
		if int(hero.get('unlock_stage',1))>1:
			locked+=1;check(node('RosterDeploy_'+str(hero['id'])).disabled,'unreleased hero disabled '+str(hero['id']))
	check(locked>0,'first-run fixture covers locked heroes')
	audit('empty first-run formation')
	await press('RosterDeploy_'+first_id)
	check(main.deployed_heroes.size()==1 and not node('RosterConfirm').disabled,'one real tap fills the first slot and enables save')
	audit('one hero with locked slots')
	await press('RosterSlotRemove_'+first_id)
	check(main.deployed_heroes.is_empty() and node('RosterConfirm').disabled,'slot removal disables save when party becomes empty')
	for faction: String in ['aurelia','noxfera']:
		fixture(faction);main._build_hero_select_screen();await settle()
		audit(faction+' ten hero roster')
		for slot in 10:
			check(main.get_viewport_rect().encloses(node('RosterPartySlot_%d'%slot).get_global_rect()),faction+' party slot visible '+str(slot))
		separate('RosterPartyPanel','RosterFilter',faction+' party/filter')
		separate('RosterListTitle','RosterSort',faction+' list/sort')
		var removed_id: String=str(main.deployed_heroes[0]['id'])
		await press('RosterSlotRemove_'+removed_id)
		check(main.deployed_heroes.size()==9 and not main._is_hero_deployed(removed_id),faction+' selected slot removes exact hero')
		await press('RosterDeploy_'+removed_id)
		check(main.deployed_heroes.size()==10 and main._is_hero_deployed(removed_id),faction+' card can redeploy exact hero')
		for role: String in ['딜러','탱커','서포터','컨트롤러']:
			await press('RosterFilter_'+role)
			check(main.hero_roster_filter==role,faction+' role filter selects '+role)
			var cards: Array[Node]=main.content_root.find_children('RosterCard_*','PanelContainer',true,false)
			check(not cards.is_empty(),faction+' filter has matching cards '+role)
			for card: Node in cards:check(main._hero_role_group(str(card.name).trim_prefix('RosterCard_'))==role,faction+' filtered cards match role')
			audit(faction+' '+role+' filter')
		await press('RosterFilter')
		for expected: String in ['레벨','전투력','등급']:
			await press('RosterSort');check(main.hero_roster_sort==expected,faction+' sort cycles to '+expected)
		await press('RosterClear');check(main.deployed_heroes.is_empty(),faction+' clear acts on selected faction only')
		var sorted_heroes: Array=main._filtered_sorted_roster(main._hero_roster_for_faction())
		var last_id: String=str(sorted_heroes[-1]['id'])
		var scroll: ScrollContainer=node('HeroRosterScroll')
		scroll.ensure_control_visible(node('RosterDeploy_'+last_id));await settle()
		var old_scroll: int=scroll.scroll_vertical
		check(old_scroll>0,faction+' lower hero fixture requires list scrolling')
		await press('RosterDeploy_'+last_id)
		check(main._is_hero_deployed(last_id) and node('HeroRosterScroll').scroll_vertical==old_scroll,faction+' lower-card deployment retains list position')
		await press('RosterAutoParty');check(main.deployed_heroes.size()==10,faction+' automatic selection fills unlocked ten slots')
		for hero: Dictionary in main.deployed_heroes:check(main._hero_belongs_to_selected_faction(str(hero['id'])),faction+' auto party remains within faction')
func verify_dungeons() -> void:
	fixture();main._build_meta_hub_screen();await settle();audit('daily dungeon')
	check(node('DungeonDetailCard')!=null and not node('DungeonEnterButton').disabled,'daily tab offers one ready dungeon')
	var gold: int=main.wallet_gold;var xp: int=main.wallet_xp
	await press('DungeonEnterButton')
	check(main.active_screen=='combat' and main.daily_dungeon_runs==0,'daily entry starts real combat without instant completion')
	var daily_ticks: int=0
	while main.challenge_session!=null and daily_ticks<2000:
		main._advance_auto_hunt(1.0/30.0)
		daily_ticks+=1
	await settle()
	check(main.daily_dungeon_runs==1 and main.wallet_gold==gold+950 and main.wallet_xp==xp+350,'daily combat victory grants exact next-run rewards once')
	await press('ContentTab_tower');audit('tower dungeon')
	gold=main.wallet_gold;var gems: int=main.wallet_gems
	await press('DungeonEnterButton')
	check(main.active_screen=='combat' and main.tower_floor==1 and main.wallet_gold==gold,'tower entry starts combat without immediate payout')
	var tower_ticks: int=0
	while main.challenge_session!=null and tower_ticks<3000:
		main._advance_auto_hunt(1.0/30.0)
		tower_ticks+=1
	await settle()
	check(main.tower_floor==2 and main.tower_best_floor==1 and main.wallet_gold==gold+340 and main.wallet_gems==gems+2,'tower victory uses selected floor reward once')
	await press('ContentTab_weekly');audit('weekly dungeon')
	gold=main.wallet_gold;gems=main.wallet_gems
	await press('DungeonEnterButton')
	check(main.weekly_trial_runs==0 and main.wallet_gold==gold and main.active_screen=='combat','weekly entry opens battle without reward')
	var weekly_ticks: int=0
	while main.challenge_session!=null and weekly_ticks<2800:
		main._advance_auto_hunt(1.0/30.0)
		weekly_ticks+=1
		if weekly_ticks%30==0:await process_frame
	await settle()
	check(main.weekly_trial_runs==1 and main.wallet_gold==gold+1600 and main.wallet_gems==gems+18,'weekly actual completion uses next-run reward once')
	await press('ContentPartyButton')
	check(main.active_screen=='hero_select' and main.content_party_context.get('kind')=='meta','dungeon formation records correct return route')
	var inspected_id: String=str(main.deployed_heroes[0]['id'])
	await press('RosterDetail_'+inspected_id)
	check(main.active_screen=='hero_detail' and main.content_party_context.get('kind')=='meta','hero inspection preserves dungeon formation route')
	var worn: Dictionary=main._gear_item('',inspected_id,'weapon')
	await press('GearTile_'+str(worn['id']))
	check(main.active_screen=='equipment_detail' and main.content_party_context.get('kind')=='meta','equipment inspection preserves dungeon formation route')
	await press('EquipmentDetailBack');await press('PortraitMenuBack')
	check(main.active_screen=='hero_select' and main.content_party_context.get('kind')=='meta','gear and hero back actions return to content formation')
	gold=main.wallet_gold;gems=main.wallet_gems
	await press('RosterConfirm')
	check(main.active_screen=='meta_hub' and main.get_meta('content_meta_tab')=='weekly','saving formation returns to selected dungeon tab')
	check(main.wallet_gold==gold and main.wallet_gems==gems and main.weekly_trial_runs==1,'formation return starts no entry and spends nothing')
	check(main.content_party_context.is_empty(),'successful formation return consumes route')
	await press('ContentPartyButton');await press('RosterClear')
	check(node('RosterConfirm').disabled,'empty content party cannot confirm')
	main._confirm_party();await settle()
	check(main.active_screen=='hero_select' and main.content_party_context.get('kind')=='meta','empty-party guard preserves content route')
	await press('PortraitMenuBack')
	check(main.active_screen=='meta_hub' and node('DungeonEnterButton').disabled,'empty party can return but cannot enter dungeon')
	audit('empty dungeon formation')
	# Leaving formation for the camp must not redirect an unrelated later save.
	await press('ContentPartyButton');main._build_lobby_screen();await settle()
	check(main.content_party_context.is_empty(),'camp navigation discards abandoned dungeon route')
	main._build_hero_select_screen();await settle();await press('RosterAutoParty');await press('RosterConfirm')
	check(main.active_screen=='party_ready','unrelated formation save uses normal ready screen')
	await press('ReadyEditParty');await press('RosterConfirm')
	check(main.active_screen=='party_ready','ready-screen formation returns to readiness without starting hunting')
	main.daily_dungeon_runs=3;main.set_meta('content_meta_tab','daily');main._build_meta_hub_screen();await settle()
	check(node('DungeonEnterButton').disabled,'daily exhaustion disables entry');audit('daily exhausted')
	main.weekly_trial_runs=5;main.set_meta('content_meta_tab','weekly');main._build_meta_hub_screen();await settle()
	check(node('DungeonEnterButton').disabled,'weekly exhaustion disables entry');audit('weekly exhausted')
	main.tower_floor=999999;main.tower_best_floor=999998;main.set_meta('content_meta_tab','tower');main._build_meta_hub_screen();await settle()
	check(node('DungeonEnterButton').disabled and '지원' in node('DungeonEntryStatus').text,'unsupported floor has explicit save-boundary reason');audit('large tower values')
	await press('ContentTab_quests');audit('quest rewards')
	check(node('DungeonDetailCard')==null and node('ContentQuest_stage5')!=null,'quest tab replaces dungeon form')
	fixture('aurelia',1,1);main._build_boss_select_screen();await settle()
	check(node('RaidCatalogEnter_moonrest_forest').disabled,'locked raid cannot enter');audit('locked raid')
	var original_screen: String=main.active_screen
	main._open_content_party('raid','moonrest_forest');await settle()
	check(main.active_screen==original_screen and main.content_party_context.is_empty(),'direct locked-raid formation request is rejected')
	main._open_content_party('raid','invalid_zone');await settle()
	check(main.active_screen==original_screen,'invalid raid destination cannot create route')
func verify_raid() -> void:
	fixture();main._build_boss_select_screen();await settle()
	await press('RaidCatalogEnter_moonrest_forest')
	check(main.active_screen=='raid' and main.selected_raid_id=='moonrest_forest' and main.current_zone_id=='gray_meadow' and not main.raid_running,'content raid opens selected boss without moving hunting region')
	audit('moon forest raid preparation')
	await press('PortraitRaidFormation')
	check(main.active_screen=='hero_select' and main.content_party_context.get('zone_id')=='moonrest_forest','raid formation retains selected boss')
	var gold: int=main.wallet_gold;var crystals: int=main.raid_crystals;var clears: Dictionary=main.raid_clears.duplicate(true)
	await press('RosterConfirm')
	check(main.active_screen=='raid' and main.selected_raid_id=='moonrest_forest' and main.current_zone_id=='gray_meadow' and not main.raid_running,'saving raid party returns to same boss without automatic battle')
	check(main.wallet_gold==gold and main.raid_crystals==crystals and main.raid_clears==clears,'raid preparation return grants no rewards and spends nothing')
	await press('PortraitRaidStart')
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	check(main.raid_running and node('PortraitRaidStart').disabled and node('PortraitRaidFormation').disabled,'actual start begins encounter and locks repeated start/formation')
	var serial: int=main.raid_encounter_serial
	main._open_content_party('raid','moonrest_forest');await settle()
	check(main.active_screen=='raid' and main.raid_encounter_serial==serial and main.raid_running,'direct formation request cannot interrupt running raid')
	main._advance_raid_encounter(.3)
	main.boss_telegraph_pending=true;main.boss_telegraph_skill='달잠 숲의 고대 수호자가 모든 원정대원에게 예고하는 아주 긴 광역 공격';main.boss_telegraph_remaining=2.25
	main.raid_event_text='원정대의 피해량과 보호막 수치를 함께 표시하는 전투 기록 '.repeat(8)
	node('PortraitRaidView').refresh();await settle();audit('raid long telegraph')
	var health: int=main.raid_boss_hp;var elapsed: float=main.raid_elapsed
	for dimensions: Vector2i in [Vector2i(720,1560),Vector2i(810,1440),Vector2i(720,1280)]:
		root.size=dimensions;await settle();audit('live raid resize '+str(dimensions))
		check(main.raid_boss_hp==health and main.raid_elapsed==elapsed and main.raid_encounter_serial==serial and main.raid_running,'resize preserves ongoing raid state '+str(dimensions))
		check(node('PortraitRaidStart').disabled and node('PortraitRaidFormation').disabled,'resize keeps encounter actions locked')
	main.boss_telegraph_pending=false;main.raid_running=false
	for outcome: String in ['토벌 성공','토벌 실패']:
		main.raid_last_result=outcome+' · '+('전투 결과와 획득한 보상에 대한 긴 안내를 확인하세요. '.repeat(24))
		node('PortraitRaidView').refresh();await settle();audit('raid '+outcome+' long result')
		check(node('PortraitRaidStatus').get_child(0).size.y>node('PortraitRaidStatus').size.y,'long result scrolls inside dedicated status region')
		check(not node('PortraitRaidStart').disabled and not node('PortraitRaidFormation').disabled,'finished raid restores actions')
func verify_sizes() -> void:
	fixture()
	for index in main.deployed_heroes.size():main.deployed_heroes[index]['name']='별빛과 달빛이 함께 수호하는 아주 긴 이름의 원정대 영웅 %d'%index
	for dimensions: Vector2i in [Vector2i(320,568),Vector2i(360,640),Vector2i(720,1280),Vector2i(810,1440),Vector2i(720,1560)]:
		root.size=dimensions;await settle()
		check(main.get_viewport_rect().size.x>=720,'small physical window retains production canvas width '+str(dimensions))
		for method: String in ['_build_hero_select_screen','_build_meta_hub_screen','_build_boss_select_screen','_build_world_map_screen','_build_raid_screen']:
			main.call(method);await settle();audit(str(dimensions)+' '+method)
		main._build_party_ready_screen(main._deployed_names());await settle();audit(str(dimensions)+' long-name readiness')
		check(main.content_root.find_children('ReadyHero_*','PanelContainer',true,false).size()==10,'readiness retains ten individual hero cards')
	# Short logical canvas exercises fixed-region allocation without reducing
	# production text sizes. Width 600 is exploratory and outside its contract.
	for logical: Vector2i in [Vector2i(720,960),Vector2i(600,1066)]:
		root.content_scale_size=logical;root.size=logical;await settle()
		for method: String in ['_build_hero_select_screen','_build_meta_hub_screen','_build_boss_select_screen','_build_raid_screen']:
			main.call(method);await settle();audit('logical '+str(logical)+' '+method,logical.x>=720)
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280);await settle()
