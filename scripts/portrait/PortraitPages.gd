extends RefCounted
## Portrait pages use one scrolling column with natural text height. All actions
## call the existing game rules; no fixed landscape canvas or scaled typography.
const S = preload('res://scripts/portrait/PortraitSkin.gd')
const M = preload('res://scripts/portrait/PortraitMenus.gd')
const H = preload('res://scripts/portrait/PortraitHud.gd')
const R = preload('res://scripts/HeroRosterCatalog.gd')
const ART = preload('res://scripts/EquipmentArtCatalog.gd')
const GEAR = preload('res://scripts/EquipmentRules.gd')
const VISUALS = preload('res://scripts/HeroVisualCatalog.gd')
const SCENERY = preload('res://scripts/portrait/PortraitScenery.gd')
const RAID_DESIGN = preload('res://scripts/RaidBossDesign.gd')
const GUARDIANS = preload('res://scripts/GuardianCatalog.gd')
const DAILY_RULES = preload('res://scripts/DailyDungeonBattleRules.gd')
const TOWER_RULES = preload('res://scripts/TowerBattleRules.gd')
const ABYSS_RULES = preload('res://scripts/WeeklyAbyssBattleRules.gd')
const ZONES = ['gray_meadow','forgotten_mine','moonrest_forest']
const RAID_ART = {
	'gray_meadow': 'res://assets/backgrounds/raid-v59/stone-circle.png',
	'forgotten_mine': 'res://assets/backgrounds/raid-v59/crystal-forge.png',
	'moonrest_forest': 'res://assets/backgrounds/raid-v59/eclipse-grove.png',
}

static func stack(parent: Node, gap: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override('separation',gap)
	parent.add_child(box)
	return box

static func grid(parent: Node, columns: int = 2) -> GridContainer:
	var box := GridContainer.new()
	box.columns=columns
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override('h_separation',12)
	box.add_theme_constant_override('v_separation',12)
	parent.add_child(box)
	return box

static func text(parent: Node, value: String, points: int = 18, color: Color = S.INK) -> Label:
	var label := S.label(value,points,color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

static func action(parent: Node, caption: String, callback: Callable, primary: bool = false) -> Button:
	var button := S.button(caption,callback,S.GOLD if primary else S.SURFACE_2)
	var ancestor: Node=parent
	while ancestor!=null:
		if ancestor is ScrollContainer:
			button.mouse_filter=Control.MOUSE_FILTER_PASS
			break
		ancestor=ancestor.get_parent()
	button.custom_minimum_size=Vector2(0,52)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.clip_text=true
	button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text=caption
	parent.add_child(button)
	return button

static func card(parent: Node, title: String = '', accent: Color = S.EDGE_SOFT) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style := S.elevated(S.DARK_2,S.EDGE_SOFT,12)
	style.content_margin_left=18;style.content_margin_right=18
	style.content_margin_top=17;style.content_margin_bottom=17
	panel.add_theme_stylebox_override('panel',style)
	parent.add_child(panel)
	var box := stack(panel,10)
	if not title.is_empty():
		var heading:=text(box,title,23)
		heading.add_theme_color_override('font_color',S.INK)
		heading.tooltip_text=title
	return box

static func disclosure(parent: Node, title: String, expanded: bool = false) -> VBoxContainer:
	var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override('panel',S.elevated(S.SURFACE))
	parent.add_child(panel)
	var column:=stack(panel,8)
	var toggle:=S.button(('−  ' if expanded else '+  ')+title,Callable())
	toggle.name='Disclosure_'+title.validate_node_name();toggle.custom_minimum_size=Vector2(0,52)
	toggle.alignment=HORIZONTAL_ALIGNMENT_LEFT;toggle.mouse_filter=Control.MOUSE_FILTER_PASS
	column.add_child(toggle)
	var body:=stack(column,10);body.visible=expanded
	toggle.pressed.connect(func():
		body.visible=not body.visible
		toggle.text=('−  ' if body.visible else '+  ')+title)
	return body

static func picture(parent: Node, texture: Texture2D, extent: Vector2) -> TextureRect:
	var art := TextureRect.new()
	art.texture=texture
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size=extent
	art.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

static func portrait(main: Node, parent: Node, id: String, height: float = 140) -> void:
	picture(parent,main._combat_portrait_texture(id),Vector2(0,height))

static func progress(parent: Node, value: float, maximum: float) -> void:
	var bar := S.gauge(parent,Rect2(0,0,0,10),S.SUCCESS)
	bar.custom_minimum_size=Vector2(0,10)
	bar.max_value=maxf(1,maximum);bar.value=value

static func begin(main: Node, screen: String, title: String, detail: String, tab: String = '') -> VBoxContainer:
	var previous: ScrollContainer=main.content_root.get_node_or_null('PortraitContentScroll')
	var restore_position: int=previous.scroll_vertical if main.active_screen==screen and previous!=null else 0
	main._clear_screen(screen not in ['login', 'intro'])
	main.active_screen=screen
	main.content_root.set_meta('portrait_tab',tab)
	M.header(main,title,detail)
	var scroll := ScrollContainer.new()
	scroll.name='PortraitContentScroll'
	S.make_scroll_responsive(scroll)
	main.content_root.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left=20;scroll.offset_top=132;scroll.offset_right=-20;scroll.offset_bottom=-108
	var box := stack(scroll,14)
	box.name='PageContent'
	if restore_position>0:scroll.set_deferred('scroll_vertical',restore_position)
	H.navigation(main,main.content_root,tab,main.get_viewport_rect().size.y-90,90)
	return box

static func lobby(main: Node) -> void:
	var page := begin(main,'lobby','원정대 현황',main._faction_name(),'more')
	var zone: Dictionary=main._current_zone()
	var lead := card(page,str(zone['name']),S.BLUE)
	text(lead,'지금 떠날 곳  ·  STAGE %02d'%main.idle_stage,16,S.BLUE_SOFT)
	text(lead,'권장 전투력 %s'%main._compact_hud_amount(int(zone['power'])),16,S.GOLD)
	text(lead,str(zone.get('description','새로운 모험이 기다립니다.')),18,S.MUTED)
	action(lead,'사냥 이어하기' if not main.deployed_heroes.is_empty() else '첫 원정대 만들기',Callable(main,'_lobby_start_hunt'),true).name='LobbyHuntButton'
	if not main.tutorial_completed:
		var goal := card(page,'다음 목표',S.GOLD)
		goal.get_parent().name='LobbyGuideCard'
		text(goal,main._tutorial_text(),18,S.MUTED)
		action(goal,str(preload("res://scripts/FirstSessionGuide.gd").status(main).caption),Callable(main,'_follow_first_session_guide'),true).name='LobbyGuideAction'
	var metrics := grid(page)
	var power := card(metrics,'원정대 전투력')
	text(power,main._compact_hud_amount(main._calculate_party_power()),28,S.GOLD)
	var stage := card(metrics,'사냥 진행')
	text(stage,'%d / %d 무리'%[main.idle_stage_kills,maxi(1,main.idle_stage_target)],23,S.BLUE_SOFT)
	progress(stage,main.idle_stage_kills,main.idle_stage_target)
	var party := card(page,'나의 원정대 · %d / %d명'%[main.deployed_heroes.size(),main._party_slot_cap()])
	party.get_parent().name='LobbyPartyCard'
	if main.deployed_heroes.is_empty():text(party,'진영을 선택하고 함께할 첫 동료를 만나세요.',18,S.MUTED)
	else:
		var heroes := grid(party,5)
		for hero: Dictionary in main.deployed_heroes:
			var tile := stack(heroes,4)
			portrait(main,tile,str(hero['id']),72)
			text(tile,str(hero['name']),14).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			text(tile,'Lv.%d'%main._get_hero_progress(str(hero['id']))['level'],14,S.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	action(party,'원정대 편성',Callable(main,'_lobby_deploy'))
	var goal_summary := card(page,'장기 목표')
	goal_summary.name='LobbyLongTermGoals'
	text(goal_summary,main.GOALS.tracked_text(main),18)
	action(goal_summary,'목표·업적 보상 확인',Callable(main,'_open_goal_screen')).name='LobbyLongTermGoalAction'
	var rewards := card(page,'사냥 보상')
	var gold: int=main.offline_pending_gold+main.offline_pending_chest_gold
	var xp: int=main.offline_pending_xp+main.offline_pending_chest_xp
	text(rewards,'온라인은 즉시 지급 · 오프라인 골드 %s / 경험치 %s'%[main._compact_hud_amount(gold),main._compact_hud_amount(xp)],17,S.GOLD)
	var claim := action(rewards,'오프라인 사냥 받기',Callable(main,'_show_offline_reward_popup'),true)
	claim.name='LobbyOfflineRewards';claim.disabled=gold+xp<=0
	text(page,'바로가기',23,S.INK)
	var shortcuts := grid(page)
	for entry in [['영웅 훈련','_build_growth_screen'],['장비 가방','_build_inventory_screen'],['사냥터','_open_world_menu'],['모험 메뉴','_show_main_menu']]:
		action(shortcuts,entry[0],Callable(main,entry[1]))
	action(shortcuts,'수호신 소환',func():main.set_meta('summon_mode','guardian');main._build_summon_screen())

static func _metric_tile(parent: Node, caption: String, value: String, accent: Color = S.BLUE_SOFT, note: String = '') -> VBoxContainer:
	var box:=stack(parent,4)
	text(box,caption,16,S.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var amount:=text(box,value,24,accent);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if not note.is_empty():text(box,note,14,S.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	return box

static func _recommended_growth_branch(main: Node, hero_id: String) -> String:
	match main._hero_role_group(hero_id):
		'탱커':return 'survival'
		'서포터','컨트롤러':return 'utility'
	return 'offense'

static func _growth_branch_label(branch: String) -> String:
	return {'offense':'공격','survival':'생존','utility':'기능'}.get(branch,'성장')

static func _choose_growth_hero(main: Node, parent: Node, key: String, screen_method: String) -> String:
	var roster: Array=main._hero_roster_for_faction()
	if roster.is_empty():return ''
	var selected: String=str(main.get_meta(key,''))
	var ids: Array[String]=[]
	for hero: Dictionary in roster:ids.append(str(hero['id']))
	if selected not in ids:
		selected=str(main.deployed_heroes[0]['id']) if not main.deployed_heroes.is_empty() else ids[0]
		main.set_meta(key,selected)
	var selector_title := '성장할 영웅' if key=='growth_hero_id' else '돌파할 영웅'
	var selector := card(parent,selector_title,S.BLUE)
	selector.get_parent().name='GrowthHeroPicker' if key=='growth_hero_id' else 'SummonHeroPicker'
	var nav := grid(selector,3)
	nav.name='GrowthHeroPickerRow' if key=='growth_hero_id' else 'SummonHeroPickerRow'
	var current_index: int=maxi(0,ids.find(selected))
	var previous_id: String=ids[posmod(current_index-1,ids.size())]
	var next_id: String=ids[posmod(current_index+1,ids.size())]
	var previous := action(nav,'‹ 이전',func():main.set_meta(key,previous_id);main.call(screen_method))
	previous.name='GrowthHeroPrevious' if key=='growth_hero_id' else 'SummonHeroPrevious'
	var chooser:=OptionButton.new()
	chooser.mouse_filter=Control.MOUSE_FILTER_PASS
	chooser.name='GrowthHeroChoice' if key=='growth_hero_id' else 'SummonHeroChoice'
	chooser.custom_minimum_size=Vector2(0,54)
	chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	chooser.clip_text=true;chooser.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for hero: Dictionary in roster:
		var hero_id: String=str(hero['id'])
		var status: String='%d P'%main._skill_tree_available_points(hero_id) if key=='growth_hero_id' else '%d조각'%main._hero_shard_count(hero_id)
		chooser.add_item('%s · Lv.%d · %s'%[hero['name'],main._get_hero_progress(hero_id)['level'],status])
		chooser.set_item_metadata(chooser.item_count-1,hero_id)
		if hero_id==selected:chooser.select(chooser.item_count-1)
	chooser.item_selected.connect(func(index: int):
		main.set_meta(key,str(chooser.get_item_metadata(index)))
		main.call(screen_method))
	nav.add_child(chooser);M.retint(chooser)
	var following := action(nav,'다음 ›',func():main.set_meta(key,next_id);main.call(screen_method))
	following.name='GrowthHeroNext' if key=='growth_hero_id' else 'SummonHeroNext'
	var selected_hero: Dictionary=R.hero(selected)
	var deployed_text: String = main._party_slot_name(main._deployed_hero_ids().find(selected)) if main._is_hero_deployed(selected) else '미편성'
	var status_text := '%d P 사용 가능'%main._skill_tree_available_points(selected) if key=='growth_hero_id' else '조각 %d개 · 돌파 %d/5'%[main._hero_shard_count(selected),main._hero_breakthrough_rank(selected)]
	text(selector,'%s · %s · Lv.%d · %s · %s'%[selected_hero['name'],main._hero_role_group(selected),main._get_hero_progress(selected)['level'],deployed_text,status_text],15,S.MUTED).name='FocusedHeroSummary'
	return selected

static func growth(main: Node) -> void:
	var page := begin(main,'growth','영웅 성장','선택한 영웅의 상태를 먼저 확인하고 필요한 연구만 올리세요.','growth')
	var hero_id: String=_choose_growth_hero(main,page,'growth_hero_id','_build_growth_screen')
	if hero_id.is_empty():return
	var hero: Dictionary=R.hero(hero_id)
	var progress_data: Dictionary=main._get_hero_progress(hero_id)
	var points: int=main._skill_tree_available_points(hero_id)
	var tree: Dictionary=main._get_skill_tree(hero_id)
	var spent: int=main._skill_tree_spent(hero_id)
	var total: int=main._skill_tree_total_points(hero_id)
	var recommended: String=_recommended_growth_branch(main,hero_id)
	var box := card(page,'%s · Lv.%d'%[hero['name'],progress_data['level']],S.GOLD)
	box.get_parent().name='GrowthSelectedHero'
	portrait(main,box,hero_id,118)
	var metrics := grid(box,2)
	metrics.name='GrowthMetrics'
	_metric_tile(metrics,'사용 가능','%d P'%points,S.GOLD,'바로 투자 가능')
	_metric_tile(metrics,'누적 연구','%d / %d P'%[spent,total],S.BLUE_SOFT,'레벨로 획득')
	text(box,'현재 배치 · '+main._party_slot_name(main._deployed_hero_ids().find(hero_id)) if main._is_hero_deployed(hero_id) else '현재 출전하지 않은 영웅',16,S.MUTED)
	text(box,'추천 연구 · %s · %s 역할의 전투 기여를 먼저 높이는 방향'%[_growth_branch_label(recommended),main._hero_role_group(hero_id)],16,S.BLUE_SOFT).name='GrowthRecommendation'
	action(page,'연구 포인트 재배분 · 미리보기',Callable(main,'_open_research_allocation').bind(hero_id)).name='OpenResearchAllocation'
	text(page,'연구 분야',23,S.INK)
	var branches := grid(page,1)
	branches.name='GrowthBranchList'
	for branch: String in ['offense','survival','utility']:
		var rank: int=int(tree.get(branch,0))
		var accent: Color=S.GOLD if branch==recommended else S.EDGE_SOFT
		var branch_box := card(branches,'%s 연구 · %d / 10'%[_growth_branch_label(branch),rank],accent)
		branch_box.get_parent().name='GrowthBranchCard_'+branch
		text(branch_box,main._skill_tree_branch_text(branch,rank),17,S.INK)
		progress(branch_box,rank,10)
		var upgrade := action(branch_box,'포인트 1 사용 · %s 강화'%_growth_branch_label(branch),Callable(main,'_upgrade_skill_tree').bind(hero_id,branch),branch==recommended)
		upgrade.name='GrowthBranch_'+branch;upgrade.add_theme_font_size_override('font_size',18)
		upgrade.disabled=points<=0 or rank>=10
		if rank>=10:text(branch_box,'이 분야는 최대 단계입니다.',15,S.SUCCESS)
		elif points<=0:text(branch_box,'다음 훈련 포인트는 영웅 레벨을 올리면 획득합니다.',15,S.MUTED)
	var pet: Dictionary=main._get_pet_progress()
	var profile: Dictionary=main._pet_profile()
	var companion := card(page,'장착 수호신 · '+str(profile.get('name','없음')),GUARDIANS.tier_color(str(profile.get('tier','고급'))))
	text(companion,'%s · Lv.%d · %s'%[profile.get('tier','고급'),pet['level'],main._pet_evolution_name(int(pet['evolution']))],20,S.SUCCESS)
	progress(companion,pet['xp'],main._pet_xp_to_next(int(pet['level'])))
	text(companion,'수호신 경험치 %d / %d · Lv.5 각성 · Lv.10 초월'%[pet['xp'],main._pet_xp_to_next(int(pet['level']))],16,S.MUTED)
	text(companion,GUARDIANS.bonus_text(profile,int(main.guardian_collection.get(main.guardian_equipped,{}).get('copies',1))),16,S.GOLD)
	text(companion,str(profile.get('description','전투를 함께하며 성장해요.')),18)
	action(companion,'수호신 관리',func():main.set_meta('summon_mode','guardian');main._build_summon_screen())

static func item_title(item: Dictionary) -> String:
	return str(item.get('name','옵션 결정')) if str(item.get('item_type','equipment'))=='option_crystal' else '%s +%d'%[item.get('name','장비'),item.get('level',1)]

static func option_quality(item: Dictionary) -> int:
	var options: Array=[item.get('stored_option',{})] if str(item.get('item_type','equipment'))=='option_crystal' else item.get('affixes',[])
	var quality:=0
	for affix: Dictionary in options:
		var limits: Vector2i=GEAR.STAT_RANGES.get(str(affix.get('stat','')),Vector2i(0,1))
		quality=maxi(quality,roundi(100.0*int(affix.get('value',0))/maxi(1,limits.y)))
	return quality

static func gear_summary(main: Node, parent: Node, item: Dictionary, compact: bool = false) -> void:
	var crystal := str(item.get('item_type','equipment'))=='option_crystal'
	text(parent,'%s · 옵션 결정'%item.get('rarity','일반') if crystal else '%s · %s · 전투력 %d'%[item.get('rarity','일반'),main._equipment_slot_name(str(item.get('slot','weapon'))),int(item.get('power',0))],18,S.GOLD)
	var source: Dictionary=GEAR.ZONES.get(str(item.get('source_id','')),{})
	var role_name: String=str(GEAR.HUNT_ROLE_NAMES.get(str(item.get('hunt_role','')),''))
	text(parent,GEAR.origin_text(item)+(' · '+str(source.get('name','')) if not source.is_empty() else '')+(' · '+role_name+' 전용' if not role_name.is_empty() else ''),16,S.BLUE_SOFT).name='GearOrigin'
	var set_name := str(item.get('set','초보자'))
	if not crystal and set_name!='초보자':
		var profile: Dictionary=GEAR.set_profile({'weapon':set_name,'armor':set_name,'accessory':set_name})
		text(parent,set_name+' · 2세트·3세트 보너스' if compact else set_name+' 세트 · '+str(profile.get('summary','')),16,S.MUTED).name='GearSetEffect'
	text(parent,GEAR.affix_text(item),18,S.GOLD if option_quality(item)>=100 else S.INK).name='GearAffixes'
	if option_quality(item)>0:text(parent,('옵션 품질 · 최대치 대비 %d%%' if crystal else '최고 옵션 · 최대치 대비 %d%%')%option_quality(item),16,S.SUCCESS).name='GearOptionQuality'
	var trade_reason: String=GEAR.trade_block_reason(item)
	text(parent,('거래 가능 · 수치 그대로 이식' if crystal else '거래 가능 · 장착 시 귀속') if trade_reason.is_empty() else '거래 제한 · '+trade_reason,16,S.SUCCESS if trade_reason.is_empty() else S.MUTED).name='GearTradeState'
	if GEAR.protected(item):
		text(parent,'잠금 중 · 분해 및 거래 보호' if bool(item.get('locked',false)) else ('자동 분해 보호' if crystal else '자동 분해·추천 교체 보호'),16,S.GOLD).name='GearProtected'

static func _gear_filter(main: Node, parent: Node, key: String, entries: Array, filters: Dictionary) -> void:
	var selection := OptionButton.new()
	selection.mouse_filter=Control.MOUSE_FILTER_PASS
	selection.name='GearFilter_'+key;selection.custom_minimum_size=Vector2(0,64);selection.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	selection.clip_text=true;selection.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for entry: Array in entries:
		selection.add_item(str(entry[1]));selection.set_item_metadata(selection.item_count-1,str(entry[0]))
		if str(filters.get(key,''))==str(entry[0]):selection.select(selection.item_count-1)
	selection.item_selected.connect(func(index: int):
		var updated: Dictionary=main.get_meta('gear_bag_filters',{}).duplicate()
		updated[key]=str(selection.get_item_metadata(index))
		if key=='type' and updated[key]=='option_crystal':updated['slot']='all'
		main.set_meta('gear_bag_filters',updated);main.set_meta('gear_bag_page',0);main.set_meta('gear_bag_reset_scroll',true);main._build_inventory_screen())
	parent.add_child(selection);M.retint(selection)

static func _inventory_rows(main: Node, filters: Dictionary) -> Array:
	var rows: Array=[]
	for index in main.loot_inventory.size():
		if not main._inventory_action_valid(index):continue
		var item: Dictionary=main._normalize_inventory_item(main.loot_inventory[index])
		if str(filters.get('type','all'))!='all' and str(item.get('item_type','equipment'))!=str(filters['type']):continue
		if str(filters.get('slot','all'))!='all' and (str(item.get('item_type','equipment'))=='option_crystal' or str(item.get('slot',''))!=str(filters['slot'])):continue
		if str(filters.get('origin','all'))!='all' and str(item.get('origin','legacy'))!=str(filters['origin']):continue
		if str(filters.get('rarity','all'))!='all' and str(item.get('rarity','일반'))!=str(filters['rarity']):continue
		var query:=str(filters.get('query','')).strip_edges().to_lower()
		var searchable:=('%s %s %s'%[item.get('name',''),item.get('set',''),GEAR.affix_text(item)]).to_lower()
		if not query.is_empty() and not query in searchable:continue
		var state:=str(filters.get('state','all'))
		if state=='locked' and not bool(item.get('locked',false)):continue
		if state in ['usable','improved']:
			var preview: Dictionary=preload('res://scripts/EquipmentComparison.gd').preview(main,item,preload('res://scripts/EquipmentComparison.gd').selected_hero(main))
			if preview.is_empty() or not bool(preview.compatible) or not (item.get('proposal',{}) as Dictionary).is_empty():continue
			if state=='improved' and int(preview.delta)<=0:continue
		rows.append({'index':index,'item':item})
	var mode := str(filters.get('sort','rarity'))
	rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if mode=='recent':return int(a['index'])>int(b['index'])
		var first: Dictionary=a['item'];var second: Dictionary=b['item']
		if mode=='power' and int(first.get('power',0))!=int(second.get('power',0)):return int(first.get('power',0))>int(second.get('power',0))
		if mode=='quality' and option_quality(first)!=option_quality(second):return option_quality(first)>option_quality(second)
		var grades: Dictionary={'일반':0,'희귀':1,'전설':2}
		var first_grade: int=grades.get(str(first.get('rarity','일반')),0)
		var second_grade: int=grades.get(str(second.get('rarity','일반')),0)
		if first_grade!=second_grade:return first_grade>second_grade
		if int(first.get('power',0))!=int(second.get('power',0)):return int(first.get('power',0))>int(second.get('power',0))
		return int(a['index'])>int(b['index']))
	return rows

static func confirm_decompose(main: Node, index: int, item_id: String) -> void:
	if not main._inventory_action_valid(index,item_id):return
	var item: Dictionary=main._normalize_inventory_item(main.loot_inventory[index])
	if not GEAR.protected(item):
		main._decompose_inventory_item(index,item_id)
		return
	var confirm := ConfirmationDialog.new()
	confirm.name='EquipmentDecomposeConfirmation';confirm.title='보호 장비 분해'
	confirm.dialog_text='레이드 또는 옵션 장비를 분해합니다.\n장비와 추가 옵션은 복구할 수 없습니다. 계속할까요?'
	confirm.ok_button_text='장비 분해';confirm.cancel_button_text='보관하기'
	confirm.min_size=Vector2i(480,180)
	main.add_child(confirm)
	confirm.confirmed.connect(func():main._decompose_inventory_item(index,item_id,true);confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

static func _gear_tile_label(parent: Node, value: String, points: int, color: Color) -> Label:
	var label := S.label(value,points,color)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text=true
	label.tooltip_text=value
	parent.add_child(label)
	return label

static func _gear_tile(main: Node, parent: Node, item: Dictionary, hero_id: String = '', slot: String = '') -> Button:
	var item_id := str(item.get('id',''))
	var crystal := str(item.get('item_type','equipment'))=='option_crystal'
	var rarity := str(item.get('rarity','일반'))
	var accent: Color={'일반':S.EDGE_SOFT,'희귀':S.BLUE_SOFT,'전설':S.GOLD}.get(rarity,S.EDGE_SOFT)
	var button := S.button('',Callable(main,'_build_equipment_detail').bind(item_id,hero_id,slot),S.SURFACE)
	button.mouse_filter=Control.MOUSE_FILTER_PASS
	button.name='GearTile_'+item_id
	button.set_meta('equipment_id',item_id)
	button.set_meta('equipment_hero_id',hero_id)
	button.set_meta('equipment_slot',slot)
	button.custom_minimum_size=Vector2(0,164)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.tooltip_text='%s\n%s\n%s'%[item_title(item),GEAR.affix_text(item),'눌러서 상세 · 강화 · 옵션 관리']
	button.add_theme_stylebox_override('normal',S.box(S.SURFACE,accent,12,2))
	parent.add_child(button)
	var inset := MarginContainer.new()
	inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ['left','right','top','bottom']:inset.add_theme_constant_override('margin_'+side,8)
	var contents := stack(inset,3)
	contents.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if crystal:
		var symbol := _gear_tile_label(contents,'◆',42,S.BLUE_SOFT)
		symbol.name='OptionCrystalArt';symbol.custom_minimum_size=Vector2(0,54)
	else:
		var art := picture(contents,ART.texture_for(item),Vector2(0,54))
		art.name='EquipmentArt'
	var caption := str(item.get('name','장비'))
	if crystal:caption=caption.trim_suffix(' 옵션 결정')+' 결정'
	_gear_tile_label(contents,caption,18,S.INK).name='GearTileName'
	_gear_tile_label(contents,rarity+' · '+GEAR.stat_text(item.get('stored_option',{})) if crystal else '%s · +%d'%[rarity,int(item.get('level',1))],16,accent).name='GearTileGrade'
	var option_count: int=(item.get('affixes',[]) as Array).size()
	var note := '이식용' if crystal else '옵션 %d/%d'%[option_count,GEAR.option_capacity(item)]
	if bool(item.get('locked',false)):note+=' · 잠금'
	elif bool(item.get('bound',false)):note+=' · 귀속'
	elif not GEAR.trade_block_reason(item).is_empty():note+=' · 거래 불가'
	else:note+=' · 거래 가능'
	_gear_tile_label(contents,note,15,S.MUTED).name='GearTileState'
	return button

static func _inventory_settings(main: Node, parent: Node, filters: Dictionary) -> void:
	var settings := card(parent,'관리 도구')
	settings.get_parent().name='GearSettingsPanel'
	settings.get_parent().visible=bool(main.get_meta('gear_settings_open',false))
	text(settings,'자주 쓰지 않는 기능은 이곳에 모았습니다. 가방 목록은 아래에서 그대로 유지됩니다.',15,S.MUTED)
	var tools := grid(settings)
	action(tools,'거래소',Callable(main,'_build_equipment_market')).name='OpenEquipmentMarket'
	action(tools,'장착 장비 일괄 강화',Callable(main,'_bulk_enhance_equipped')).name='GearBulkEnhance'
	_gear_filter(main,settings,'origin',[['all','출처 · 전체'],['hunt','출처 · 사냥터'],['raid','출처 · 레이드'],['legacy','출처 · 기존 장비']],filters)
	var auto := CheckButton.new()
	auto.name='GearAutoEquip';auto.text='획득한 장비 자동 장착';auto.button_pressed=main.gear_auto_equip
	auto.custom_minimum_size=Vector2(0,52)
	auto.add_theme_font_size_override('font_size',18)
	auto.toggled.connect(Callable(main,'_set_gear_auto_equip'))
	settings.add_child(auto)
	text(settings,'자동 장착은 편하지만 장착 즉시 귀속됩니다. 거래용 장비를 모을 때는 꺼 주세요.',15,S.MUTED)
	var salvage := OptionButton.new()
	salvage.name='GearAutoSalvage';salvage.custom_minimum_size=Vector2(0,48)
	salvage.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for i in 3:
		salvage.add_item(['자동 분해 · 사용 안 함','자동 분해 · 희귀 미만','자동 분해 · 전설 미만'][i])
		salvage.set_item_metadata(i,['일반','희귀','전설'][i])
		if salvage.get_item_metadata(i)==main.auto_salvage_min_rarity:salvage.select(i)
	salvage.item_selected.connect(func(index):main._set_auto_salvage(str(salvage.get_item_metadata(index))))
	settings.add_child(salvage);M.retint(salvage)
	text(settings,'레이드·옵션·잠금 장비는 자동 분해하지 않습니다. 가방을 넘는 장비는 우편함으로 배송됩니다. 직접 설정한 자동 분해만 적용합니다.',15,S.MUTED)

static func _inventory_summary(main: Node, parent: Node) -> void:
	var equipment_count := 0
	var crystal_count := 0
	var legendary_count := 0
	var protected_count := 0
	for raw: Dictionary in main.loot_inventory:
		var item: Dictionary=main._normalize_inventory_item(raw)
		if str(item.get('item_type','equipment'))=='option_crystal':crystal_count+=1
		else:equipment_count+=1
		if str(item.get('rarity','일반'))=='전설':legendary_count+=1
		if GEAR.protected(item):protected_count+=1
	var box := card(parent,'가방 현황',S.BLUE)
	box.get_parent().name='GearBagSummary'
	var usage := float(main.loot_inventory.size())/maxf(1.0,float(main.INVENTORY_CAP))
	text(box,'%d / %d칸 사용 · 여유 %d칸'%[main.loot_inventory.size(),main.INVENTORY_CAP,maxi(0,main.INVENTORY_CAP-main.loot_inventory.size())],21,S.INK)
	progress(box,usage*100.0,100.0)
	if usage>=0.85:
		text(box,'가방이 거의 가득 찼어요 · 우편 수령 전에 필요 없는 장비를 정리해 주세요.',15,S.GOLD if usage<0.95 else Color('#ff8b86'))
	var stats := grid(box,4)
	for entry: Array in [['장비',equipment_count,S.BLUE_SOFT],['결정',crystal_count,S.BLUE_SOFT],['전설',legendary_count,S.GOLD],['보호',protected_count,S.SUCCESS]]:
		var metric_accent: Color=entry[2]
		_metric_tile(stats,str(entry[0]),str(entry[1]),metric_accent)

static func inventory(main: Node) -> void:
	load('res://scripts/EquipmentInventoryView.gd').build(main)

static func detail(main: Node, hero_id: String, scroll_position: int = 0) -> void:
	var hero: Dictionary=R.hero(hero_id)
	hero['color']=Color(str(hero['color']))
	var page := begin(main,'hero_detail',str(hero['name']),'영웅 상세 · 핵심 상태와 성장 동선을 한 화면에서 확인하세요.','heroes')
	var progress_data: Dictionary=main._get_hero_progress(hero_id)
	var locked: bool=main.idle_stage<int(hero.get('unlock_stage',1))
	var party_slot: int=-1
	for index in main.deployed_heroes.size():
		if str(main.deployed_heroes[index]['id'])==hero_id:
			party_slot=index
			break
	var hp_multiplier: float=float(main._calculate_party_synergy().get('hp_multiplier',1.0)) if party_slot>=0 else 1.0
	var combat_stats: Dictionary=main._hero_combat_stats(hero_id,maxi(0,party_slot),hp_multiplier)
	var identity := card(page,'%s · %s · Lv.%d'%[main._hero_grade(hero_id),main._hero_role_group(hero_id),progress_data['level']],main._hero_grade_color(hero_id))
	identity.get_parent().name='HeroIdentityPanel'
	portrait(main,identity,hero_id,164)
	text(identity,str(hero.get('identity',hero['role'])),22)
	var state_text: String = '출전 · '+main._party_slot_name(party_slot) if party_slot>=0 else '미편성'
	text(identity,'%s · %s · %s'%[hero['race'],hero['class'],state_text],16,S.BLUE_SOFT).name='HeroDeploymentState'
	var stats := grid(identity,3)
	stats.name='HeroStatGrid'
	_metric_tile(stats,'HP',main._compact_hud_amount(int(combat_stats['max_hp'])),S.SUCCESS)
	_metric_tile(stats,'공격',main._compact_hud_amount(int(combat_stats['attack'])),S.GOLD)
	_metric_tile(stats,'방어',main._compact_hud_amount(int(combat_stats['defense'])),S.BLUE_SOFT)
	var stats_description:=text(identity,'현재 전투 능력치 · HP %s · 공격 %s · 방어 %s'%[
		main._compact_hud_amount(int(combat_stats['max_hp'])),
		main._compact_hud_amount(int(combat_stats['attack'])),
		main._compact_hud_amount(int(combat_stats['defense']))],15,S.MUTED)
	stats_description.name='HeroCombatStats';stats_description.visible=false
	progress(identity,progress_data['xp'],main._hero_xp_to_next(int(progress_data['level'])))
	text(identity,'경험치 %d / %d'%[progress_data['xp'],main._hero_xp_to_next(int(progress_data['level']))],15,S.MUTED)
	var select := action(identity,'스테이지 %d에서 합류'%hero.get('unlock_stage',1) if locked else ('배치 해제' if main._is_hero_deployed(hero_id) else '원정대에 배치'),func():
		main._deploy_hero(hero);main._build_hero_detail_screen(hero_id),true)
	select.name='HeroDeployAction'
	select.disabled=locked or (not main._is_hero_deployed(hero_id) and main.deployed_heroes.size()>=main._party_slot_cap())

	var quick := card(page,'빠른 작업')
	quick.get_parent().name='HeroQuickActions'
	text(quick,'이 영웅을 유지한 채 성장·장비·돌파 화면으로 바로 이동합니다.',15,S.MUTED)
	var quick_grid := grid(quick,3)
	var growth_button := action(quick_grid,'성장 연구',func():main.set_meta('growth_hero_id',hero_id);main._build_growth_screen(),true)
	growth_button.name='HeroQuickGrowth'
	var bag_button := action(quick_grid,'장비 가방',Callable(main,'_build_inventory_screen'))
	bag_button.name='HeroQuickBag'
	var shard_button := action(quick_grid,'조각 · 돌파',func():main.set_meta('summon_mode','hero');main.set_meta('summon_hero_id',hero_id);main._build_summon_screen())
	shard_button.name='HeroQuickBreakthrough'

	text(page,'전투 기술',24)
	var skill_grid := grid(page,2)
	skill_grid.name='HeroSkillGrid'
	for kit: Dictionary in R.HEROES[hero_id]['skills']:
		var box := card(skill_grid,str(kit['skill']),S.GOLD if kit['slot']=='ultimate' else S.EDGE_SOFT)
		box.get_parent().name='HeroSkill_'+str(kit['slot'])
		picture(box,VISUALS.skill_texture(hero_id,str(kit['slot'])),Vector2(0,68))
		var slot_name: String={'a1':'액티브 1','a2':'액티브 2','passive':'패시브','ultimate':'궁극기'}[kit['slot']]
		text(box,slot_name+' · '+('게이지 100' if kit['slot']=='ultimate' else '재사용 %.1f초'%float(kit.get('cooldown',0))),15,S.GOLD)
		text(box,str(kit['effect']),16,S.INK)
	var profile: Dictionary=main.hero_identity_catalog.profile(hero_id)
	var behavior := disclosure(page,'전투 성향')
	text(behavior,'%s · %s'%[main.hero_identity_catalog.ai_style_name(str(profile.get('ai_style','balanced'))),profile.get('trait','상황에 맞춘 균형 행동')],17,S.MUTED)

	var equipment := card(page,'장비',S.BLUE)
	main.equipment_labels[hero_id]=text(equipment,main._equipment_summary(hero_id),17)
	var equipped_tiles := grid(equipment,3)
	equipped_tiles.name='EquippedGearGrid'
	for slot: String in ['weapon','armor','accessory']:
		var worn: Dictionary=main._gear_item('',hero_id,slot)
		if not worn.is_empty():
			var tile := _gear_tile(main,equipped_tiles,worn,hero_id,slot)
			tile.tooltip_text=main._equipment_slot_name(slot)+' · '+tile.tooltip_text
	main.hero_hint=text(equipment,'장비를 누르면 정보·강화·옵션·이식을 같은 상세 화면에서 관리합니다.',15,S.MUTED)
	var equipment_actions := grid(equipment,2)
	action(equipment_actions,'가방에서 교체',Callable(main,'_build_inventory_screen'),true).name='HeroEquipmentBag'
	action(equipment_actions,'성장 연구',func():main.set_meta('growth_hero_id',hero_id);main._build_growth_screen()).name='HeroEquipmentGrowth'

	var tree: Dictionary=main._get_skill_tree(hero_id)
	var progression := card(page,'승급 · 돌파 · 연구',S.GOLD)
	var progression_metrics := grid(progression,3)
	_metric_tile(progression_metrics,'연구','%d P'%main._skill_tree_spent(hero_id),S.BLUE_SOFT,'남은 %d P'%main._skill_tree_available_points(hero_id))
	_metric_tile(progression_metrics,'조각','%d개'%main._hero_shard_count(hero_id),S.GOLD,'돌파 %d / 5'%main._hero_breakthrough_rank(hero_id))
	_metric_tile(progression_metrics,'등급',main._hero_grade(hero_id),main._hero_grade_color(hero_id),'Lv.%d'%int(progress_data['level']))
	text(progression,'연구 · 공격 %d / 생존 %d / 기능 %d'%[tree.get('offense',0),tree.get('survival',0),tree.get('utility',0)],16,S.MUTED)
	var requirement: Dictionary=main._ascension_requirement(hero_id)
	text(progression,'다음 승급 조건 · Lv.%d · %dG'%[requirement['level'],requirement['gold']] if main._hero_grade(hero_id)!='UR' else '모든 승급 단계를 완료했습니다.',16,S.MUTED)
	var progression_actions := grid(progression,2)
	var ascend := action(progression_actions,'승급 · %dG'%requirement['gold'] if main._hero_grade(hero_id)!='UR' else '최고 등급 UR',func():
		if main._try_ascend_hero(hero_id):main._build_hero_detail_screen(hero_id),true)
	ascend.name='HeroAscendAction';ascend.disabled=locked or main._hero_grade(hero_id)=='UR'
	action(progression_actions,'조각 · 돌파 관리',func():main.set_meta('summon_mode','hero');main.set_meta('summon_hero_id',hero_id);main._build_summon_screen()).name='HeroBreakthroughAction'
	main.content_root.get_node('PortraitContentScroll').set_deferred('scroll_vertical',scroll_position)

static func _content_tab(parent: Node, caption: String, callback: Callable, selected: bool) -> Button:
	var button := action(parent,caption,callback,selected)
	button.add_theme_font_size_override('font_size',18)
	button.disabled=selected
	if selected:
		button.add_theme_stylebox_override('disabled',S.box(S.BLUE.darkened(.28),S.BLUE_SOFT,10,2))
		button.add_theme_color_override('font_disabled_color',S.INK)
		button.tooltip_text=caption+' · 선택됨'
	return button

static func _content_stat(main: Node, parent: Node, caption: String, amount: int, accent: Color = S.GOLD) -> void:
	var box := stack(parent,4)
	text(box,caption,16,S.MUTED)
	var value := text(box,main._compact_hud_amount(amount),24,accent)
	value.tooltip_text='%s · %d'%[caption,amount]

static func _content_party(main: Node, parent: Node, context: String, zone_id: String = '') -> VBoxContainer:
	var box := card(parent,'출전 원정대',S.BLUE)
	box.get_parent().name='ContentPartyCard'
	var metrics := grid(box)
	_content_stat(main,metrics,'편성 인원 · 최대 %d명'%main._party_slot_cap(),main.deployed_heroes.size(),S.BLUE_SOFT)
	_content_stat(main,metrics,'현재 전투력',main._calculate_party_power())
	if main.deployed_heroes.is_empty():text(box,'영웅을 한 명 이상 편성하면 도전할 수 있어요.',17,S.MUTED)
	else:text(box,'시너지 · '+str(main._calculate_party_synergy().get('summary','')),17,S.BLUE_SOFT)
	if context=='meta':
		var role_info: Dictionary=preload('res://scripts/ChallengeCombatLedger.gd').capabilities(main.deployed_heroes)
		text(box,'역할 · 탱커 %d / 딜러 %d / 보조 %d / 제어 %d · 아군 회복 보유 %d(조건부 포함)'%[role_info.tank,role_info.damage,role_info.support,role_info.control,role_info.heal],16,S.MUTED).name='ChallengePartyRoles'
		text(box,'자동 스킬 %s · 자동 궁극기 %s'%['켜짐' if main.skill_auto else '꺼짐','켜짐' if main.ultimate_auto else '꺼짐'],16,S.BLUE_SOFT).name='ChallengePartyAutoStatus'
	action(box,'편성하기' if main.deployed_heroes.is_empty() else '편성 수정',Callable(main,'_open_content_party').bind(context,zone_id),main.deployed_heroes.is_empty()).name='ContentPartyButton'
	return box

static func _content_requirement(main: Node, parent: Node, required: int) -> bool:
	var power: int=main._calculate_party_power()
	var can_enter: bool=not main.deployed_heroes.is_empty() and power>=required
	text(parent,'필요 전투력 %s'%main._compact_hud_amount(required),18,S.MUTED).tooltip_text='필요 전투력 %d'%required
	var status := '출전 가능' if can_enter else ('영웅 편성이 필요해요' if main.deployed_heroes.is_empty() else '전투력 %s 부족'%main._compact_hud_amount(required-power))
	text(parent,status,18,S.SUCCESS if can_enter else S.GOLD).name='DungeonEntryStatus'
	return can_enter

static func meta(main: Node) -> void:
	main._reset_daily_dungeon_if_needed();main._reset_weekly_if_needed();main._auto_track_quest()
	var page := begin(main,'meta_hub','도전','레이드·던전을 선택하고 출전하세요.','content')
	var tools := disclosure(page,'연습 · 전투 설정')
	tools.get_parent().name='ChallengeTools'
	var lab_actions := grid(tools,2)
	action(lab_actions,'무보상 연습전',Callable(main,'_open_practice_screen')).name='PracticeOpen'
	action(lab_actions,'통합 전투 프리셋',Callable(main,'_open_combat_presets')).name='CombatPresetsOpen'
	var selected: String=str(main.get_meta('content_meta_tab','daily'))
	if selected not in ['daily','tower','weekly','raids','quests']:selected='daily'
	var tabs := grid(page,5)
	tabs.add_theme_constant_override('h_separation',7)
	for entry in [['raids','레이드'],['daily','일일 던전'],['tower','무한탑'],['weekly','주간 원정'],['quests','목표 · 업적']]:
		var tab_id: String=entry[0]
		var button := _content_tab(tabs,entry[1],func():main.set_meta('content_meta_tab',tab_id);main._build_meta_hub_screen(),selected==tab_id)
		button.name='ContentTab_'+tab_id
	if selected=='raids':
		tools.get_parent().get_parent().queue_free()
		load('res://scripts/RaidCatalogView.gd').build(main,page,load('res://scripts/portrait/PortraitPages.gd'))
		return
	var last_result: Dictionary=main.get_meta('last_dungeon_result',{})
	if selected==str(last_result.get('mode','')):
		var report := card(page,str(last_result.get('title','원정 결과')),S.SUCCESS)
		report.get_parent().name='DungeonLastResult'
		text(report,str(last_result.get('detail','')),18,S.INK)
	var combat_report: Dictionary=main.get_meta('last_challenge_report',{})
	if selected==str(combat_report.get('mode','')) and str(combat_report.get('entry',{}).get('faction',''))==str(main.selected_faction):
		var report_serial: int=int(combat_report.get('serial',-1))
		action(page,('최근 연습 분석 · ' if combat_report.get('practice',false) else '최근 실전 분석 · ')+str(combat_report.get('title','')),Callable(main,'_open_challenge_report').bind(report_serial)).name='ChallengeReportOpen'
	if selected=='quests':
		preload("res://scripts/LongTermGoalScreens.gd").build(main, page, load("res://scripts/portrait/PortraitPages.gd"))
		return
	var daily: bool=selected=='daily'
	var tower: bool=selected=='tower'
	var title: String='일일 던전' if daily else ('무한탑' if tower else '주간 심연 원정')
	var box := card(page,title,S.BLUE if daily else S.GOLD)
	box.get_parent().name='DungeonDetailCard'
	var daily_variant: String=str(main.get_meta('daily_dungeon_variant','gold_rush'))
	if daily_variant not in DAILY_RULES.VARIANTS:daily_variant='gold_rush'
	var daily_plan: Dictionary=DAILY_RULES.plan(daily_variant)
	if daily:
		var mode_tabs := grid(box,3)
		mode_tabs.name='DailyDungeonModeTabs'
		for variant in DAILY_RULES.VARIANTS:
			var variant_plan: Dictionary=DAILY_RULES.plan(variant)
			var mode_button := action(mode_tabs,str(variant_plan['title']),func():
				main.set_meta('daily_dungeon_variant',variant);main._build_meta_hub_screen(),variant==daily_variant)
			mode_button.name='DailyMode_'+variant;mode_button.disabled=variant==daily_variant
		text(box,'전투·소탕·세 유형은 하루 3회 한도를 함께 사용해요.',16,S.MUTED)
	var runs: int=main.daily_dungeon_runs if daily else main.weekly_trial_runs
	var limit: int=3 if daily else 5
	var exhausted: bool=not tower and runs>=limit
	if tower:
		text(box,'%s층 도전 · 최고 %s층'%[main._compact_hud_amount(main.tower_floor),main._compact_hud_amount(main.tower_best_floor)],20,S.BLUE_SOFT).name='DungeonProgress'
	else:
		text(box,('오늘' if daily else '이번 주')+' 남은 도전 %d / %d회'%[maxi(0,limit-runs),limit],20,S.BLUE_SOFT).name='DungeonProgress'
		progress(box,runs,limit)
		if not daily:
			text(box,'최고 실제 피해 %s'%main._compact_hud_amount(main.weekly_trial_best),16,S.MUTED)
			var weekly_mutator: Dictionary=ABYSS_RULES.mutator(str(main.weekly_content_key))
			text(box,str(weekly_mutator.get('label',''))+' · '+str(weekly_mutator.get('description','')),16,S.MUTED).name='WeeklyMutatorInfo'
			if main.weekly_trial_legacy_best>0:
				text(box,'이전 전투력 점수 %s는 별도 보관 중이에요.'%main._compact_hud_amount(main.weekly_trial_legacy_best),15,S.MUTED)
	if exhausted:
		text(box,'오늘의 원정을 모두 완료했어요.' if daily else '이번 주 심연 원정을 모두 완료했어요.',20,S.SUCCESS)
		text(box,'다음 초기화 후 다시 보상을 받을 수 있어요.',17,S.MUTED)
	else:
		var next_run: int=runs+1
		if daily:
			var reward: Dictionary=DAILY_RULES.reward(runs)
			text(box,'완료 보상 · 골드 %s · 경험치 %s · 수호신 경험치 %d'%[main._compact_hud_amount(int(reward.gold)),main._compact_hud_amount(int(reward.xp)),int(reward.pet_xp)],17,S.GOLD)
		elif tower:
			var reward: Dictionary=TOWER_RULES.reward(int(main.tower_floor))
			text(box,'완료 보상 · 골드 %s · 젬 %d'%[main._compact_hud_amount(int(reward.get('gold',0))),int(reward.get('gems',0))],17,S.GOLD)
		else:
			text(box,'완료 보상 · 골드 %s · 젬 %d · 경험치 %s'%[main._compact_hud_amount(1200+next_run*400),15+next_run*3,main._compact_hud_amount(350+next_run*100)],17,S.GOLD)
	var required: int=650+runs*250 if daily else (500+main.tower_floor*180 if tower else 900+runs*550)
	var tower_error: String=main._tower_entry_error() if tower else ''
	var weekly_error: String=main._weekly_entry_error() if not daily and not tower else ''
	var can_enter: bool=false
	if not exhausted:
		if daily:
			can_enter=not main.deployed_heroes.is_empty()
			text(box,'권장 전투력 %s · 승패는 실제 전투로 결정'%main._compact_hud_amount(required),18,S.MUTED)
			text(box,'출전 가능' if can_enter else '영웅 편성이 필요해요',18,S.SUCCESS if can_enter else S.GOLD).name='DungeonEntryStatus'
		elif tower:
			can_enter=tower_error.is_empty()
			text(box,'권장 전투력 %s · 미달이어도 도전 가능'%main._compact_hud_amount(required),18,S.MUTED)
			text(box,'출전 가능 · 실제 전투' if can_enter else tower_error,18,S.SUCCESS if can_enter else S.GOLD).name='DungeonEntryStatus'
		else:
			can_enter=weekly_error.is_empty()
			text(box,'90초 생존 · 전투력 입장 제한 없음',18,S.MUTED)
			text(box,'출전 가능 · 실제 피해량 집계' if can_enter else weekly_error,18,S.SUCCESS if can_enter else S.GOLD).name='DungeonEntryStatus'
	if tower:
		var tower_plan: Dictionary=TOWER_RULES.plan(int(main.tower_floor))
		text(box,str(tower_plan.get('description',tower_error))+' · 실패·취소는 층 기록과 보상을 변경하지 않아요.',16,S.MUTED).name='TowerBattleObjective'
	elif daily:
		text(box,str(daily_plan['description'])+' 실패·취소는 보상과 완료 횟수를 늘리지 않아요.',16,S.MUTED)
	else:
		var weekly_plan: Dictionary=ABYSS_RULES.plan(str(main._week_key()))
		text(box,str(weekly_plan.get('description',''))+'\n전멸·취소·피해 0은 기록·횟수·보상을 변경하지 않아요.',16,S.MUTED).name='WeeklyPatternObjective'
	var tower_context: Dictionary=main._tower_entry_context() if tower else {}
	var weekly_context: Dictionary=main._weekly_entry_context() if not daily and not tower else {}
	var enter := action(box,'도전 횟수 소진' if exhausted else ('도전 시작' if can_enter else '출전 조건 미달'),func():
		if daily:main._run_daily_dungeon(daily_variant)
		elif tower:main._challenge_tower(tower_context)
		else:main._run_weekly_trial(weekly_context),true)
	enter.name='DungeonEnterButton';enter.disabled=exhausted or not can_enter
	if daily:
		var sweep_context: Dictionary=main._daily_dungeon_entry_context()
		var sweep_reason: String=main._daily_sweep_error(daily_variant)
		var sweep_button := action(box,'소탕 1회 · 전투와 동일 보상',func():
			main._sweep_daily_dungeon(daily_variant,sweep_context))
		sweep_button.name='DungeonSweepButton';sweep_button.disabled=not sweep_reason.is_empty()
		text(box,sweep_reason if not sweep_reason.is_empty() else '직접 클리어 기록 확인 · 이 진영·유형·단계 소탕 가능',16,S.MUTED).name='DungeonSweepStatus'
	_content_party(main,page,'meta')
	action(page,'장비 관리',Callable(main,'_build_inventory_screen'))
	page.move_child(tools.get_parent().get_parent(),-1)

static func summon(main: Node) -> void:
	var page := begin(main,'summon','소환 · 돌파','보유 재화와 보장 상태를 먼저 확인하고 필요한 성장만 진행하세요.','summon')
	var mode: String=str(main.get_meta('summon_mode','hero'))
	var tabs := grid(page,2)
	tabs.name='SummonModeTabs'
	var guardian_tab := action(tabs,'수호신',func():main.set_meta('summon_mode','guardian');main._build_summon_screen(),mode=='guardian')
	guardian_tab.name='SummonModeGuardian';guardian_tab.disabled=mode=='guardian'
	var hero_tab := action(tabs,'영웅 조각',func():main.set_meta('summon_mode','hero');main._build_summon_screen(),mode!='guardian')
	hero_tab.name='SummonModeHero';hero_tab.disabled=mode!='guardian'
	var wallet := card(page,'소환 현황',S.BLUE)
	wallet.get_parent().name='SummonResourceSummary'
	var wallet_metrics := grid(wallet,2)
	_metric_tile(wallet_metrics,'보유 젬',main._compact_hud_amount(main.wallet_gems),S.BLUE_SOFT,'소환 재화')
	_metric_tile(wallet_metrics,'레이드 정수','%d개'%main.raid_crystals,S.GOLD,'장비 옵션 재화')
	if mode=='guardian':
		_guardian_summon(main,page)
		return
	var banner := card(page,'영웅 조각 소환',S.GOLD)
	banner.get_parent().name='HeroSummonBanner'
	text(banner,'1회 소환 · 영웅 조각 12개 · 10번째 소환은 조각 30개 보장',18,S.INK)
	progress(banner,main.summon_pity,10)
	var remaining: int=maxi(1,10-main.summon_pity)
	text(banner,'보장까지 %d회 · 현재 %d / 10'%[remaining,main.summon_pity],17,S.GOLD).name='HeroSummonPity'
	var summon_button := action(banner,'소환하기 · 100 젬',func():
		var result: Dictionary=main._summon_once()
		if not result.is_empty():main._build_summon_screen();main._show_summon_reveal(result),true)
	summon_button.name='HeroSummonButton';summon_button.disabled=main.wallet_gems<100
	if summon_button.disabled:text(banner,'젬이 부족합니다. 보상 센터와 콘텐츠 보상을 먼저 확인하세요.',15,S.MUTED)
	var shortcuts := grid(banner,2)
	action(shortcuts,'영웅 도감',Callable(main,'_build_codex_screen')).name='SummonOpenCodex'
	action(shortcuts,'보상 센터',Callable(main,'_build_bm_screen')).name='SummonOpenRewards'
	text(page,'조각으로 돌파할 영웅',23,S.INK)
	var hero_id: String=_choose_growth_hero(main,page,'summon_hero_id','_build_summon_screen')
	if hero_id.is_empty():return
	var hero: Dictionary=R.hero(hero_id)
	var rank: int=main._hero_breakthrough_rank(hero_id)
	var count: int=main._hero_shard_count(hero_id)
	var cost: int=main._breakthrough_cost(rank)
	var box := card(page,str(hero['name'])+' · 돌파',S.GOLD)
	box.get_parent().name='SummonSelectedHero'
	portrait(main,box,hero_id,116)
	var breakthrough_metrics := grid(box,3)
	breakthrough_metrics.name='BreakthroughMetrics'
	_metric_tile(breakthrough_metrics,'현재','%d / 5'%rank,S.BLUE_SOFT,'돌파 단계')
	_metric_tile(breakthrough_metrics,'보유','%d'%count,S.GOLD,'영웅 조각')
	_metric_tile(breakthrough_metrics,'필요','완료' if rank>=5 else '%d'%cost,S.SUCCESS if count>=cost or rank>=5 else S.MUTED,'다음 돌파')
	progress(box,rank,5)
	text(box,'돌파는 같은 영웅 조각을 사용하며 최대 5단계까지 성장합니다.',15,S.MUTED)
	var advance := action(box,'돌파 완료' if rank>=5 else ('돌파 가능 · %d조각'%cost if count>=cost else '조각 부족 · %d / %d'%[count,cost]),func():
		if main._try_breakthrough(hero_id):main._build_summon_screen(),count>=cost and rank<5)
	advance.name='SummonBreakthrough';advance.disabled=rank>=5 or count<cost

static func _guardian_summon(main: Node, page: Node) -> void:
	main._guardian_ensure_starter()
	var active_id: String=str(main.guardian_equipped)
	var active: Dictionary=GUARDIANS.profile(active_id)
	var owned: Dictionary=main.guardian_collection.get(active_id,{})
	var accent: Color=GUARDIANS.tier_color(str(active.get('tier','고급')))
	var active_card := card(page,'현재 장착 · '+str(active.get('name','수호신 없음')),accent)
	var sigil:=preload('res://scripts/portrait/PortraitGuardianSigil.gd').new()
	sigil.accent=accent;sigil.tier=str(active.get('tier','고급'))
	active_card.add_child(sigil)
	text(active_card,'%s  ·  공명 %d단계'%[active.get('tier','고급'),GUARDIANS.resonance(int(owned.get('copies',1)))],18,accent)
	text(active_card,str(active.get('description','')),17,S.MUTED)
	text(active_card,'장착 효과  ·  '+GUARDIANS.bonus_text(active,int(owned.get('copies',1))),17,S.GOLD)
	var summon_card:=card(page,'수호신의 계약',S.GOLD)
	summon_card.get_parent().name='GuardianSummonSummary'
	text(summon_card,'고급 55% · 희귀 27% · 에픽 12% · 전설 5% · 신화 1%',17)
	var pity_metrics := grid(summon_card,2)
	_metric_tile(pity_metrics,'전설 이상','%d / %d'%[main.guardian_legendary_pity,GUARDIANS.LEGENDARY_PITY],S.GOLD,'보장 누적')
	_metric_tile(pity_metrics,'신화','%d / %d'%[main.guardian_mythic_pity,GUARDIANS.MYTHIC_PITY],S.BLUE_SOFT,'보장 누적')
	progress(summon_card,main.guardian_legendary_pity,GUARDIANS.LEGENDARY_PITY)
	progress(summon_card,main.guardian_mythic_pity,GUARDIANS.MYTHIC_PITY)
	text(summon_card,'같은 수호신을 다시 만나면 공명이 오릅니다. 1·4·7장에 공명 1·2·3단계.',16,S.MUTED)
	var free: bool=not main.guardian_free_claimed
	var summon_button:=action(summon_card,'첫 수호신 무료 소환' if free else '수호신 소환 · %d젬'%GUARDIANS.SUMMON_COST,func():
		var result: Dictionary=main._summon_guardian()
		if not result.is_empty():main._build_summon_screen();main._show_guardian_reveal(result),true)
	summon_button.name='GuardianSummonButton'
	summon_button.disabled=not free and main.wallet_gems<GUARDIANS.SUMMON_COST
	text(page,'수호신 도감',23,S.GOLD)
	text(page,'보유한 수호신을 선택해 장착 효과를 바꿀 수 있습니다.',16,S.MUTED)
	var filter := OptionButton.new()
	filter.name='GuardianCollectionFilter'
	filter.custom_minimum_size=Vector2(0,52)
	filter.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var choices: Array[String]=['전체','보유','미보유']
	choices.append_array(GUARDIANS.TIERS)
	for choice: String in choices:filter.add_item(choice)
	var chosen: String=str(main.get_meta('guardian_collection_filter','전체'))
	filter.select(maxi(0,choices.find(chosen)))
	filter.item_selected.connect(func(index: int):
		main.set_meta('guardian_collection_filter',choices[index])
		main._build_summon_screen())
	page.add_child(filter);M.retint(filter)
	var collection_grid:=grid(page,2)
	for tier: String in GUARDIANS.TIERS:
		for id in GUARDIANS.DEFINITIONS:
			var profile: Dictionary=GUARDIANS.profile(str(id))
			if str(profile['tier'])!=tier:continue
			var copies: int=int(main.guardian_collection.get(id,{}).get('copies',0))
			if chosen=='보유' and copies==0:continue
			if chosen=='미보유' and copies>0:continue
			if chosen in GUARDIANS.TIERS and chosen!=tier:continue
			var tile:=card(collection_grid,'%s  %s'%[profile['symbol'],profile['name']] if copies>0 else '%s  미발견'%profile['symbol'],GUARDIANS.tier_color(tier))
			text(tile,'%s · %s'%[tier,'공명 %d단계'%GUARDIANS.resonance(copies) if copies>0 else '미보유'],16,GUARDIANS.tier_color(tier))
			text(tile,GUARDIANS.bonus_text(profile,maxi(1,copies)) if copies>0 else '소환으로 발견하세요.',15,S.MUTED)
			var equip:=action(tile,'장착 중' if str(id)==active_id else '장착하기',Callable(_equip_guardian_and_refresh).bind(main,str(id)))
			equip.name='GuardianEquip_'+str(id);equip.disabled=copies<=0 or str(id)==active_id

static func _equip_guardian_and_refresh(main: Node, id: String) -> void:
	if main._guardian_equip(id):main._build_summon_screen()

static func rewards(main: Node) -> void:
	var page := begin(main,'rewards','보상 센터','오늘의 선물을 챙기고 모험을 이어가세요.')
	var daily := card(page,'매일의 선물',S.GOLD)
	text(daily,'젬 30 · 골드 100',26,S.GOLD)
	var claimed: bool=main._today_key()<=main.daily_reward_claimed_day
	var status := text(daily,'내일 새로운 선물이 기다려요.' if claimed else '하루 한 번 받을 수 있어요.',18,S.MUTED)
	var claim := action(daily,'오늘의 선물 수령 완료' if claimed else '오늘의 선물 받기',Callable(),true)
	claim.disabled=claimed
	claim.pressed.connect(func():main._claim_daily_reward(claim,status);main._build_bm_screen())
	var support := card(page,'원정 지원 보상')
	text(support,'젬 5 · 골드 50',26,S.BLUE_SOFT)
	var count: int=main.rewarded_ad_claimed_count if main._today_key()<=main.rewarded_ad_day else 0
	var support_status := text(support,'오늘 %d / 3회 · 무료로 받을 수 있어요.'%count,18,S.MUTED)
	var button := action(support,'오늘의 지원 수령 완료' if count>=3 else '지원 보상 받기',Callable(),true)
	button.disabled=count>=3
	button.pressed.connect(func():main._claim_rewarded_ad(button,support_status);main._build_bm_screen())
	var shop := card(page,'원정대 상점 · 준비 중')
	text(shop,'외형 스킨과 원정대 패스를 준비하고 있어요.',18,S.MUTED)
	action(shop,'상점 오픈 예정',Callable()).disabled=true
	text(page,'보상 골드는 사냥 누적 보상에 합산됩니다.',16,S.MUTED)

static func world(main: Node, bosses: bool = false) -> void:
	if bosses:
		main.set_meta('content_meta_tab','raids')
		meta(main)
		return
	var page := begin(main,'world_map','사냥터','지역을 선택해 보상과 출전 조건을 확인하세요.','content')
	var selected: String=str(main.get_meta('content_region_id',main.current_zone_id))
	if selected not in ZONES:selected=ZONES[0]
	var regions := grid(page,3)
	for index in ZONES.size():
		var zone_id: String=ZONES[index]
		var caption: String=['빙하','협곡','성역'][index]
		var select := _content_tab(regions,caption,func():
			main.set_meta('content_region_id',zone_id)
			world(main,bosses),selected==zone_id)
		select.name='RegionTab_'+zone_id
	var index: int=ZONES.find(selected)
	var zone: Dictionary=main._zone_data()[selected]
	var unlocked: bool=main._is_zone_unlocked(selected)
	var box := card(page,str(zone['name']),S.BLUE)
	box.get_parent().name='RegionDetailCard'
	var art := preload('res://scripts/portrait/PortraitTerrainPreview.gd').new()
	art.name='RegionTerrainPreview'
	art.zone_id=selected
	art.custom_minimum_size=Vector2(0,190)
	art.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_child(art)
	text(box,'현재 사냥터' if main.current_zone_id==selected else ('해금 완료' if unlocked else '잠긴 지역'),16,S.BLUE_SOFT)
	text(box,str(zone['description']),18)
	text(box,'사냥 장비 · %s 세트'%zone['equipment_set'],20,S.GOLD)
	text(box,str(zone.get('battle_trait','')),17,S.MUTED)
	text(box,'권장 전투력 %s'%main._compact_hud_amount(int(zone['power'])),18,S.MUTED)
	if not unlocked:text(box,'사냥 스테이지 %d에 도달하면 해금돼요.'%int(zone['unlock_stage']),18,S.GOLD)
	var empty_party: bool=main.deployed_heroes.is_empty()
	var launch := action(box,'사냥 시작' if unlocked else '지역 해금 필요',Callable(main,'_select_zone_for_hunt').bind(selected),true)
	launch.name='RegionEnterButton';launch.disabled=not unlocked or empty_party
	_content_party(main,page,'world',selected)

static func codex(main: Node) -> void:
	var page := begin(main,'codex','영웅 도감','함께할 영웅의 종족과 고유한 능력을 살펴보세요.','heroes')
	main.GOALS.refresh(main)
	var bank: Dictionary=main.long_term_goals['factions'].get(str(main.selected_faction),{})
	text(page,'도감 등록 %d / 15 · 도감 업적 최대 HP +%.1f%%'%[bank.get('discovered',{}).size(),LongTermGoalState.collection_tier(main.long_term_goals,str(main.selected_faction))*.5],18,S.GOLD).name='CodexCollectionProgress'
	text(page,'영웅 5·10·15명 발견 후 업적을 수령하면 단계마다 HP +0.5% (현재 진영만 적용)',16,S.MUTED)
	action(page,'도감 업적·칭호 확인',func():main.set_meta('goal_scope','achievement');main._open_goal_screen()).name='CodexOpenGoals'
	var cards := grid(page)
	for hero: Dictionary in main._hero_roster_for_faction():
		var id := str(hero['id'])
		var found: bool=bool(main.codex_seen.get(id,false)) or main.idle_stage>=int(hero.get('unlock_stage',1))
		var box := card(cards,str(hero['name']) if found else '미발견 영웅')
		if found:portrait(main,box,id,110)
		text(box,str(hero['race']) if found else '발견을 기다리는 중',16,S.MUTED)
		text(box,'%s · Lv.%d · %d돌파'%[main._hero_grade(id),main._get_hero_progress(id)['level'],main._hero_breakthrough_rank(id)] if found else '스테이지 %d에서 합류'%hero.get('unlock_stage',1),16,S.GOLD)
		action(box,'영웅 이야기' if found else '아직 만나지 못했어요',Callable(main,'_build_hero_detail_screen').bind(id)).disabled=not found

static func onboarding(main: Node, screen: String, names: Array[String] = []) -> void:
	var title := {'login':'모험 시작','intro':'첫 동료와의 만남','party_ready':'출전 준비'}
	var page := begin(main,screen,title[screen],main._faction_name(),'heroes')
	var box := card(page,'함께할 동료를 만날 시간이에요' if screen=='intro' else (('원정대 준비 완료' if not main.deployed_heroes.is_empty() else '출전 영웅을 골라주세요') if screen=='party_ready' else '다시 만나 반가워요'))
	if screen=='login':
		text(box,'이 기기에 남겨 둔 영웅과 모험의 기록으로 시작할 수 있어요.',20)
		action(box,'이 기기에서 계속하기',Callable(main,'_open_home'),true).disabled=main._save_blocked_for_newer_version
		var notice: String=LandingScreens._save_notice(main)
		text(box,notice if not notice.is_empty() else '다른 기기에서 이어하기는 아직 지원하지 않아요.',18,S.MUTED)
	elif screen=='intro':
		text(box,'첫 영웅과 에버그린 초원숲으로 출발하세요. 모험을 거듭할수록 더 많은 동료가 합류하고, 최대 10명이 함께하는 원정대로 성장합니다.',20)
		action(box,'첫 영웅 만나기',Callable(main,'_build_hero_select_screen'),true)
		action(box,'진영 다시 선택',Callable(main,'_build_faction_screen'))
	else:
		var zone: Dictionary=main._current_zone()
		text(box,str(zone['name']),24,S.BLUE_SOFT).name='ReadyZoneName'
		var metrics := grid(box)
		_content_stat(main,metrics,'출전 인원 · 최대 %d명'%main._party_slot_cap(),main.deployed_heroes.size(),S.BLUE_SOFT)
		_content_stat(main,metrics,'원정대 전투력',main._calculate_party_power())
		text(box,'권장 전투력 %s'%main._compact_hud_amount(int(zone['power'])),17,S.MUTED)
		text(box,'시너지 · '+str(main._calculate_party_synergy().get('summary','')),18,S.BLUE_SOFT)
		var buttons := grid(box)
		var start := action(buttons,'사냥 시작',Callable(main,'_build_combat_screen'),true)
		start.name='ReadyStartHunt';start.disabled=main.deployed_heroes.is_empty()
		action(buttons,'편성 수정',Callable(main,'_open_content_party').bind('party_ready')).name='ReadyEditParty'
		text(page,'출전 영웅',24)
		var heroes := grid(page,2)
		for index in main.deployed_heroes.size():
			var hero: Dictionary=main.deployed_heroes[index]
			var id: String=str(hero['id'])
			var tile := card(heroes,'',S.EDGE_SOFT)
			tile.get_parent().name='ReadyHero_'+id
			var row := HBoxContainer.new()
			row.add_theme_constant_override('separation',12);tile.add_child(row)
			var art := picture(row,main._combat_portrait_texture(id),Vector2(68,76))
			art.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
			var labels := stack(row,5)
			text(labels,str(hero.get('name',names[index] if index<names.size() else id)),18)
			text(labels,'Lv.%d'%int(main._get_hero_progress(id)['level']),16,S.GOLD)
			text(labels,main._party_slot_name(index),15,S.MUTED)
