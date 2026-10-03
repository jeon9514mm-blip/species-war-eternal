extends RefCounted
## Portrait layouts. Visual composition changes only; all gameplay callbacks remain in Main.gd.
const SKIN := preload('res://scripts/portrait/PortraitSkin.gd')
const HUD := preload('res://scripts/portrait/PortraitHud.gd')
const ICON := preload('res://scripts/portrait/PortraitIcon.gd')
const HERO_VIEW := preload('res://scripts/HeroScreens.gd')
const ROSTER := preload('res://scripts/HeroRosterCatalog.gd')
const SKY := preload('res://scripts/portrait/PortraitSky.gd')

static func _faction_accent(main: Node) -> Color:
	return SKIN.faction_color(str(main.selected_faction))

static func _hero_portrait(main: Node, parent: Node, hero_id: String, rect: Rect2, dimmed: bool = false) -> TextureRect:
	var portrait:=TextureRect.new()
	portrait.name='RosterPortrait_'+hero_id
	portrait.texture=main._combat_portrait_texture(hero_id)
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait.modulate=Color(0.55,0.58,0.66,0.72) if dimmed else Color.WHITE
	SKIN.place(parent,portrait,rect)
	return portrait

static func header(main: Node, text: String, detail: String = '', return_action: Callable = Callable()) -> void:
	main.content_root.set_meta('portrait_ready',true)
	var bg:=SKIN.panel(main.content_root,Rect2(0,0,main.get_viewport_rect().size.x,112),SKIN.DARK,SKIN.EDGE_SOFT,1,0)
	bg.name='PortraitMenuHeader'
	bg.anchor_right=1.0;bg.offset_right=0
	var row:=HBoxContainer.new()
	bg.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_left=14;row.offset_right=-14;row.offset_top=12;row.offset_bottom=72
	row.add_theme_constant_override('separation',10)
	var back_action:=Callable(main,'_build_lobby_screen')
	var party_context: Variant=main.get('content_party_context')
	var return_to_party: bool=str(main.active_screen)=='hero_detail' and party_context is Dictionary and not party_context.is_empty()
	if return_to_party:back_action=Callable(main,'_build_hero_select_screen')
	if return_action.is_valid():back_action=return_action
	var back:=SKIN.button('‹',back_action,SKIN.SURFACE)
	back.name='PortraitMenuBack'
	back.tooltip_text='이전 화면으로 돌아가기' if return_action.is_valid() else ('출전 파티 편성으로 돌아가기' if return_to_party else '원정대 캠프로 돌아가기')
	back.custom_minimum_size=Vector2(54,54)
	back.add_theme_font_size_override('font_size',34)
	row.add_child(back)
	var title:=SKIN.label(text,27)
	title.name='PortraitPageTitle'
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible=2
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title.tooltip_text=text
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	for currency in [['G  '+main._compact_hud_amount(main.wallet_gold),SKIN.GOLD],['◆  '+main._compact_hud_amount(main.wallet_gems),SKIN.BLUE_SOFT]]:
		var chip:=PanelContainer.new()
		chip.custom_minimum_size=Vector2(111,44)
		chip.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		chip.add_theme_stylebox_override('panel',SKIN.box(SKIN.SURFACE,Color(currency[1],.65),13,1))
		row.add_child(chip)
		var amount:=SKIN.label(currency[0],17,currency[1])
		amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(amount)
	var sub:=SKIN.label(detail,16,SKIN.MUTED)
	sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	sub.max_lines_visible=1;sub.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.tooltip_text=detail
	bg.add_child(sub)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_left=20;sub.offset_right=-20;sub.offset_top=78;sub.offset_bottom=104
	var faction_bar:=ColorRect.new()
	faction_bar.color=SKIN.EDGE_SOFT
	faction_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bg.add_child(faction_bar)
	faction_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	faction_bar.offset_top=-1

static func landing(main: Node) -> void:
	main._clear_screen()
	main.active_screen='title'
	main.content_root.set_meta('portrait_ready',true)
	var size: Vector2=main.get_viewport_rect().size
	var tex:=TextureRect.new()
	tex.texture=preload('res://assets/terrain-v70/evergreen-overview.png')
	tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter=Control.MOUSE_FILTER_IGNORE
	SKIN.place(main.content_root,tex,Rect2(Vector2.ZERO,size))
	var shade:=ColorRect.new();shade.color=Color('#14312c83');shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	SKIN.place(main.content_root,shade,Rect2(Vector2.ZERO,size))
	var sky:=SKY.new()
	SKIN.place(main.content_root,sky,Rect2(0,0,size.x,310))
	var brand_y: float = 100.0 if size.x > size.y else 315.0
	var brand:=SKIN.panel(main.content_root,Rect2(42,brand_y,size.x-84,235),Color('#17323ee9'),SKIN.GOLD,2,22)
	var title:=SKIN.label('종의전쟁: 이터널',46,Color('#ffe49b'))
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(brand,title,Rect2(20,32,brand.size.x-40,76))
	var sub:=SKIN.label('나의 영웅들과, 하나의 진영으로',23)
	sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(brand,sub,Rect2(20,112,brand.size.x-40,44))
	var note:=SKIN.label('최대 10인 자동사냥 · 성장 · 종의전쟁',17,SKIN.MUTED)
	note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(brand,note,Rect2(20,163,brand.size.x-40,38))
	var start:=SKIN.button('모험 시작',Callable(main,'_build_lobby_screen'),SKIN.GOLD)
	start.name='PortraitStartButton'
	start.disabled=main._save_blocked_for_newer_version
	start.add_theme_font_size_override('font_size',27)
	SKIN.place(main.content_root,start,Rect2(68,size.y-242,size.x-136,68))
	var save_notice: String=str(preload('res://scripts/LandingScreens.gd')._save_notice(main))
	var guide:=SKIN.label(save_notice if not save_notice.is_empty() else '작은 영웅들과 떠나는 끝없는 모험',16,Color('#f1f4ff'))
	guide.name='PortraitSaveNotice'
	guide.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	SKIN.place(main.content_root,guide,Rect2(20,size.y-163,size.x-40,62))

static func faction(main: Node) -> void:
	main._clear_screen()
	main.active_screen='faction'
	main.faction_cards.clear()
	var w: float=main.get_viewport_rect().size.x
	var h: float=main.get_viewport_rect().size.y
	header(main,'진영 선택','한 번의 편성에는 선택한 진영 영웅만 사용할 수 있습니다.')
	var hint:=SKIN.label('함께할 진영을 선택하세요.',18,SKIN.MUTED)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(main.content_root,hint,Rect2(20,143,w-40,38))
	main.selection_hint=hint
	_faction_card(main,Rect2(18,190,w-36,314),'aurelia','아우렐리아 연합','휴먼 · 엘프','수호 · 회복 · 정교한 협공',Color('#4c9cff'),'shield')
	_faction_card(main,Rect2(18,516,w-36,314),'noxfera','녹스페라 연맹','뱀파이어 · 늑대인간','흡혈 · 기습 · 근접 압박',Color('#d55f91'),'moon')
	main.confirm_button=SKIN.button('진영을 선택하세요',Callable(main,'_confirm_faction'),Color('#2b72c4'))
	main.confirm_button.disabled=true
	SKIN.place(main.content_root,main.confirm_button,Rect2(46,h-190,w-92,58))
	var note:=SKIN.label('진영을 변경하면 현재 편성은 해제되며, 각 진영 편성 프리셋은 따로 보관됩니다.',14,SKIN.MUTED)
	note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	SKIN.place(main.content_root,note,Rect2(28,h-126,w-56,44))
	if str(main.selected_faction) in ['aurelia','noxfera']:
		_choose_faction(main,str(main.selected_faction))

static func _faction_card(main: Node, rect: Rect2, id: String, title: String, species: String, doctrine: String, accent: Color, icon_kind: String) -> void:
	var card:=PanelContainer.new()
	card.name='FactionCard_'+id
	card.position=rect.position;card.size=rect.size
	card.add_theme_stylebox_override('panel',SKIN.box(Color('#1c2a48ed'),Color(accent,.62),18,2))
	main.content_root.add_child(card)
	main.faction_cards[id]=card
	var canvas:=Control.new();canvas.custom_minimum_size=rect.size-Vector2(8,8);card.add_child(canvas)
	var icon:=ICON.new();icon.kind=icon_kind
	SKIN.place(canvas,icon,Rect2(22,20,54,54))
	var title_label:=SKIN.label(title,27,SKIN.INK)
	SKIN.place(canvas,title_label,Rect2(90,14,340,44))
	SKIN.badge(canvas,Rect2(90,62,184,30),species,accent)
	var doctrine_label:=SKIN.label(doctrine,17,accent.lightened(.20))
	SKIN.place(canvas,doctrine_label,Rect2(292,61,rect.size.x-310,32))
	var roster: Array=ROSTER.roster(id)
	var card_w:=104.0
	for i in mini(5,roster.size()):
		var hero: Dictionary=roster[i]
		var p:=Panel.new();p.add_theme_stylebox_override('panel',SKIN.box(Color('#101a30c9'),Color(accent,.42),10,1))
		SKIN.place(canvas,p,Rect2(20+i*(card_w+7),112,card_w,124))
		_hero_portrait(main,p,str(hero['id']),Rect2(5,5,card_w-10,82))
		var n:=SKIN.label(str(hero['name']).split(' ')[0],13,SKIN.INK);n.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		SKIN.place(p,n,Rect2(4,88,card_w-8,28))
	var select:=SKIN.button('이 진영 선택',func(): _choose_faction(main,id),accent.darkened(.28))
	select.name='SelectFaction_'+id
	SKIN.place(canvas,select,Rect2(rect.size.x-168,252,148,46))
	var separation:=SKIN.label('상대 진영 영웅은 편성·성장·소환 목록에 섞이지 않습니다.',13,SKIN.MUTED)
	SKIN.place(canvas,separation,Rect2(20,253,rect.size.x-205,42))

static func _choose_faction(main: Node,id: String) -> void:
	main._select_faction(id)
	for faction_id in main.faction_cards.keys():
		var card: PanelContainer=main.faction_cards[faction_id]
		var accent:=SKIN.faction_color(str(faction_id))
		var chosen:=str(faction_id)==id
		card.add_theme_stylebox_override('panel',SKIN.box(Color('#223351f4') if chosen else Color('#1c2a48ed'),SKIN.GOLD if chosen else Color(accent,.55),18,4 if chosen else 2))

static func roster(main: Node) -> void:
	main._clear_screen();main.active_screen='hero_select'
	main.hero_slot_labels.clear();main.hero_select_buttons.clear();main.equipment_labels.clear()
	main.party_composition_label=null;main.hero_hint=null
	var heroes: Array=main._hero_roster_for_faction()
	main._setup_hero_progress(heroes)
	var w: float=main.get_viewport_rect().size.x
	var h: float=main.get_viewport_rect().size.y
	var accent:=_faction_accent(main)
	var cap: int=main._party_slot_cap()
	header(main,'영웅 편성','%s · 출전 파티를 만들고 프리셋으로 빠르게 전환하세요.'%main._faction_name())
	var return_context: Variant=main.get('content_party_context')
	if return_context is Dictionary and not return_context.is_empty():
		var back: Button=main.content_root.find_child('PortraitMenuBack',true,false)
		if back!=null:
			back.pressed.disconnect(Callable(main,'_build_lobby_screen'))
			back.pressed.connect(Callable(main,'_back_from_content_party'))
			back.tooltip_text='편성 변경을 유지하고 이전 화면으로 돌아가기'
	var party:=SKIN.panel(main.content_root,Rect2(14,142,w-28,294),Color('#172541ef'),Color(accent,.72),2,16)
	party.name='RosterPartyPanel'
	var party_title:=SKIN.label('출전 파티',21,SKIN.INK)
	SKIN.place(party,party_title,Rect2(14,9,116,34))
	var count:=SKIN.badge(party,Rect2(132,10,94,32),'%d / %d명'%[main.deployed_heroes.size(),cap],accent)
	count.name='RosterPartyCount'
	var pwr:=SKIN.label('전투력 %s'%main._compact_hud_amount(main._calculate_party_power()),17,SKIN.GOLD)
	pwr.name='RosterPartyPower';pwr.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	SKIN.place(party,pwr,Rect2(240,9,party.size.x-254,34))
	# All ten slots remain visible, including the next stage unlocks.
	var slot_area:=Control.new();slot_area.name='PartySlotScroll'
	SKIN.place(party,slot_area,Rect2(12,54,party.size.x-24,228))
	var party_grid:=GridContainer.new();party_grid.name='RosterPartyGrid';party_grid.columns=5
	party_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	party_grid.add_theme_constant_override('h_separation',8);party_grid.add_theme_constant_override('v_separation',8)
	slot_area.add_child(party_grid)
	party_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var slot_width:=floorf((slot_area.size.x-32.0)/5.0)
	for slot_index in range(10):
		party_grid.add_child(_party_slot(main,slot_index,accent,slot_width))
	main._load_active_faction_presets()
	var preset_bar:=SKIN.panel(main.content_root,Rect2(14,448,w-28,48),Color('#14243aef'),Color(accent,.48),1,12)
	preset_bar.name='RosterPresetBar'
	var preset_title:=SKIN.label('프리셋',15,SKIN.MUTED)
	SKIN.place(preset_bar,preset_title,Rect2(12,4,68,40))
	var preset_x:=84.0
	for preset_index in range(3):
		var saved: Array=main.party_presets[preset_index] if preset_index<main.party_presets.size() and typeof(main.party_presets[preset_index])==TYPE_ARRAY else []
		var caption: String='P%d · %d명'%[preset_index+1,saved.size()]
		var active: bool=main.active_preset_index==preset_index
		var preset_value: int=preset_index
		var preset:=SKIN.button(caption,func():
			main._preview_party_preset(preset_value)
		,Color(accent,.36) if active else Color('#243653'))
		preset.name='RosterPreset%d'%(preset_index+1)
		preset.tooltip_text='P%d 편성 적용'%[preset_index+1]
		preset.add_theme_font_size_override('font_size',14)
		SKIN.place(preset_bar,preset,Rect2(preset_x,4,104,40))
		preset_x+=110.0
	var save_preset:=SKIN.button('현재 편성 저장',func():
		main._save_party_preset(main.active_preset_index if main.active_preset_index>=0 else 0)
		_refresh_roster(main)
	,Color('#2f6f91'))
	save_preset.name='RosterPresetSave'
	save_preset.tooltip_text='현재 편성을 선택된 프리셋에 저장합니다. 선택된 프리셋이 없으면 P1에 저장합니다.'
	save_preset.add_theme_font_size_override('font_size',14)
	SKIN.place(preset_bar,save_preset,Rect2(preset_bar.size.x-174,4,162,40))
	var roles: Array[String]=['전체','딜러','탱커','서포터','컨트롤러']
	var filter_width: float=(w-32.0-4.0*6.0)/5.0
	for i in roles.size():
		var role: String=roles[i]
		var role_btn:=SKIN.button(role,func():
			main.hero_roster_filter=role
			main._build_hero_select_screen()
		,Color(accent,.46) if main.hero_roster_filter==role else Color('#1d3048'))
		role_btn.name='RosterFilter' if i==0 else 'RosterFilter_'+role
		role_btn.add_theme_font_size_override('font_size',15)
		SKIN.place(main.content_root,role_btn,Rect2(16+i*(filter_width+6),506,filter_width,48))
	var filtered: Array=main._filtered_sorted_roster(heroes)
	var roster_title:=SKIN.label('%s 영웅 · %d명'%[main.hero_roster_filter,filtered.size()],18,SKIN.INK)
	roster_title.name='RosterListTitle'
	SKIN.place(main.content_root,roster_title,Rect2(18,560,w-244,44))
	var sort_btn:=SKIN.button('정렬 · '+str(main.hero_roster_sort),Callable(main,'_cycle_hero_sort'),Color('#253653'))
	sort_btn.name='RosterSort';sort_btn.add_theme_font_size_override('font_size',17)
	SKIN.place(main.content_root,sort_btn,Rect2(w-210,560,194,48))
	var scroll:=ScrollContainer.new();scroll.name='HeroRosterScroll';SKIN.make_scroll_responsive(scroll)
	SKIN.place(main.content_root,scroll,Rect2(14,614,w-28,maxf(120,h-830)))
	var grid:=GridContainer.new();grid.name='RosterHeroGrid';grid.columns=4;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override('h_separation',8);grid.add_theme_constant_override('v_separation',8)
	scroll.add_child(grid)
	# Reserve the scrollbar width so the last column stays inside the list.
	var card_width:=floorf((w-80.0)/4.0)
	for hero: Dictionary in filtered:
		grid.add_child(_roster_card(main,hero,accent,card_width))
	var action_dock:=SKIN.panel(main.content_root,Rect2(10,h-220,w-20,118),Color('#102238f4'),Color(accent,.42),1,14)
	action_dock.name='RosterActionDock'
	var swapping: int=int(main.get_meta('roster_swap_slot',-1))
	var hint_text: String='자리 교체 중 · 다른 출전 영웅을 누르세요.' if swapping>=0 else ('조합 · '+main._party_composition_hint())
	main.hero_hint=SKIN.label(hint_text,15,SKIN.MUTED)
	main.hero_hint.name='RosterCompositionHint'
	main.hero_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	main.hero_hint.max_lines_visible=2
	main.hero_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	main.hero_hint.tooltip_text=hint_text
	SKIN.place(main.content_root,main.hero_hint,Rect2(18,h-210,w-36,48))
	var action_width: float=(w-32.0-16.0)/3.0
	var auto:=SKIN.button('자동 편성',func(): _auto_party(main),Color('#2f7bd1'))
	auto.name='RosterAutoParty';auto.tooltip_text='현재 역할 필터와 정렬 순서로 해금된 영웅을 편성합니다.'
	auto.add_theme_font_size_override('font_size',18)
	SKIN.place(main.content_root,auto,Rect2(16,h-156,action_width,52))
	var clear:=SKIN.button('일괄 해제',func():
		main.deployed_heroes.clear()
		main._save_idle_state()
		_refresh_roster(main)
	,Color('#3b465c'))
	clear.name='RosterClear';clear.add_theme_font_size_override('font_size',18)
	SKIN.place(main.content_root,clear,Rect2(24+action_width,h-156,action_width,52))
	var confirm_text:='편성 완료' if return_context is Dictionary and not return_context.is_empty() else '편성 저장'
	var confirm:=SKIN.button(confirm_text,func():
		if not main.deployed_heroes.is_empty():
			main._save_party_preset(maxi(0,main.active_preset_index))
		main._confirm_party()
	,SKIN.GOLD)
	confirm.name='RosterConfirm'
	confirm.disabled=main.deployed_heroes.is_empty()
	confirm.tooltip_text='최소 한 명을 편성하면 저장할 수 있습니다.' if confirm.disabled else '현재 출전 파티를 저장합니다.'
	confirm.add_theme_color_override('font_color',Color('#231b0f'))
	confirm.add_theme_font_size_override('font_size',19)
	SKIN.place(main.content_root,confirm,Rect2(32+action_width*2,h-156,action_width,52))
	HUD.navigation(main,main.content_root,'heroes',h-90,90)

static func _party_slot(main: Node, slot_index: int, accent: Color, width: float=120.0) -> Control:
	var wrap:=PanelContainer.new();wrap.name='RosterPartySlot_%d'%slot_index
	wrap.custom_minimum_size=Vector2(width,110);wrap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var cap:int=main._party_slot_cap()
	var filled: bool = slot_index < int(main.deployed_heroes.size())
	var unlocked:=slot_index<cap
	wrap.add_theme_stylebox_override('panel',SKIN.box(Color('#172941') if unlocked else Color('#121e31'),SKIN.GOLD if filled else Color(accent,.36),10,2 if filled else 1))
	var c:=Control.new();c.custom_minimum_size=Vector2(width-4,106);wrap.add_child(c)
	var inner_width:=width-4.0
	if filled:
		var hero: Dictionary=main.deployed_heroes[slot_index]
		var hero_id:=str(hero['id'])
		var chosen: bool=int(main.get_meta('roster_swap_slot',-1))==slot_index
		var choose:=SKIN.button('',func():
			var previous: int=int(main.get_meta('roster_swap_slot',-1))
			if previous<0:
				main.set_meta('roster_swap_slot',slot_index)
			elif previous==slot_index:
				main.set_meta('roster_swap_slot',-1)
			else:
				main._swap_deployed_heroes(previous,slot_index)
				main.set_meta('roster_swap_slot',-1)
			_refresh_roster(main)
		,Color('#324a6a'))
		choose.name='RosterSlotSwap_%d'%slot_index
		choose.tooltip_text=('%s 선택 해제'%hero['name'] if chosen else '%s · %s · 누르고 다른 영웅을 눌러 교체'%[hero['name'],main._party_slot_name(slot_index)])
		choose.add_theme_stylebox_override('normal',SKIN.box(Color('#344866'),SKIN.GOLD if chosen else Color('#526b94'),8,2))
		SKIN.place(c,choose,Rect2(4,3,inner_width-54,48))
		_hero_portrait(main,choose,hero_id,Rect2(2,2,inner_width-58,44))
		var remove:=SKIN.button('×',func():
			main._deploy_hero(hero)
			_refresh_roster(main)
		,Color('#243653'))
		remove.name='RosterSlotRemove_'+hero_id
		remove.tooltip_text=str(hero['name'])+' 편성 해제'
		remove.add_theme_font_size_override('font_size',22)
		for state in ['normal','hover','pressed','disabled']:
			var compact:=remove.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			compact.content_margin_left=4;compact.content_margin_right=4
			remove.add_theme_stylebox_override(state,compact)
		SKIN.place(c,remove,Rect2(inner_width-46,4,44,48))
		var progress: Dictionary=main._get_hero_progress(hero_id)
		var hero_name:=SKIN.label(str(hero['name']).split(' ')[0],14,SKIN.INK)
		hero_name.name='RosterSlotName_%d'%slot_index;hero_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		hero_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;hero_name.tooltip_text=str(hero['name'])
		SKIN.place(c,hero_name,Rect2(3,54,inner_width-6,24))
		var row:=SKIN.label('%s · Lv.%d'%[main._party_slot_name(slot_index),int(progress.get('level',1))],13,accent.lightened(.22))
		row.name='RosterSlotRow_%d'%slot_index
		row.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		row.tooltip_text='%s · Lv.%d'%[main._party_slot_name(slot_index),int(progress.get('level',1))]
		row.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		SKIN.place(c,row,Rect2(3,78,inner_width-6,24))
		main.hero_slot_labels.append(hero_name)
	elif unlocked:
		var plus:=SKIN.button('+',Callable(main,'_open_hero_menu'),Color('#243653'))
		plus.add_theme_font_size_override('font_size',30);plus.tooltip_text='아래 영웅 목록에서 출전 영웅을 선택하세요.'
		SKIN.place(c,plus,Rect2(7,8,inner_width-14,48))
		var empty:=SKIN.label('빈 슬롯',14,SKIN.MUTED);empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		SKIN.place(c,empty,Rect2(3,64,inner_width-6,30));main.hero_slot_labels.append(empty)
	else:
		var icon:=ICON.new();icon.kind='lock';SKIN.place(c,icon,Rect2((inner_width-30)/2,8,30,32))
		var locked_title:=SKIN.label('미해금',14,SKIN.MUTED);locked_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		SKIN.place(c,locked_title,Rect2(3,45,inner_width-6,24))
		var locked:=SKIN.label('스테이지 %d'%main._party_slot_unlock_stage(slot_index),14,SKIN.MUTED_DARK)
		locked.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		SKIN.place(c,locked,Rect2(3,72,inner_width-6,26));main.hero_slot_labels.append(locked)
	return wrap

static func _roster_card(main: Node, hero: Dictionary, accent: Color, width: float=200.0) -> PanelContainer:
	var hero_id:=str(hero['id'])
	var locked:bool=main.idle_stage<int(hero.get('unlock_stage',1))
	var selected:bool=main._is_hero_deployed(hero_id)
	var grade:=str(main._hero_grade(hero_id))
	var grade_color:Color=main._hero_grade_color(hero_id)
	var result:=PanelContainer.new();result.name='RosterCard_'+hero_id
	result.custom_minimum_size=Vector2(width,206);result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.add_theme_stylebox_override('panel',SKIN.elevated(Color('#182a43f4'),SKIN.GOLD if selected else Color(grade_color,.62),14))
	var c:=Control.new();c.custom_minimum_size=Vector2(width-6,200);result.add_child(c)
	var inner_width:=width-6.0
	var detail:=SKIN.button('',Callable(main,'_build_hero_detail_screen').bind(hero_id),Color.TRANSPARENT)
	detail.mouse_filter=Control.MOUSE_FILTER_PASS
	detail.name='RosterDetail_'+hero_id
	detail.tooltip_text=str(hero['name'])+' · 상세 보기'
	detail.add_theme_stylebox_override('normal',SKIN.box(Color.TRANSPARENT,Color.TRANSPARENT,6,0))
	SKIN.place(c,detail,Rect2(5,5,inner_width-10,126))
	_hero_portrait(main,detail,hero_id,Rect2(4,27,inner_width-18,72),locked)
	SKIN.badge(c,Rect2(8,8,43,23),grade,grade_color)
	var progress: Dictionary=main._get_hero_progress(hero_id)
	var level:=SKIN.label('Lv.%d'%int(progress.get('level',1)),13,SKIN.INK);level.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	SKIN.place(c,level,Rect2(inner_width-60,8,52,23))
	if selected:
		var deployed_badge:=SKIN.badge(c,Rect2(inner_width-57,78,49,23),'출전',SKIN.GOLD)
		deployed_badge.name='RosterSelected_'+hero_id
	var hero_name:=SKIN.label(str(hero['name']).split(' ')[0],16,SKIN.INK)
	hero_name.name='RosterHeroName_'+hero_id;hero_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hero_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;hero_name.tooltip_text=str(hero['name'])
	SKIN.place(c,hero_name,Rect2(5,108,inner_width-10,24))
	var role:=SKIN.label(main._hero_role_group(hero_id),13,accent.lightened(.20));role.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(c,role,Rect2(5,132,inner_width-10,22))
	var full: bool=not selected and main.deployed_heroes.size()>=main._party_slot_cap()
	var button_text:='스테이지 %d'%int(hero.get('unlock_stage',1)) if locked else ('해제' if selected else ('인원 가득' if full else '편성'))
	var button:=SKIN.button(button_text,func():
		main._deploy_hero(hero)
		_refresh_roster(main)
	,Color('#39455c') if locked else (Color('#8f6830') if selected else Color('#2f7bd1')))
	button.mouse_filter=Control.MOUSE_FILTER_PASS
	button.name='RosterDeploy_'+hero_id;button.add_theme_font_size_override('font_size',14)
	button.disabled=locked or full
	SKIN.place(c,button,Rect2(7,160,inner_width-14,38))
	main.hero_select_buttons[hero_id]=button
	return result

static func _refresh_roster(main: Node) -> void:
	# Choosing another hero should not send the player back to the first row.
	var previous: ScrollContainer=main.content_root.get_node_or_null('HeroRosterScroll')
	var scroll_position: int=previous.scroll_vertical if previous!=null else 0
	main._build_hero_select_screen()
	var current: ScrollContainer=main.content_root.get_node_or_null('HeroRosterScroll')
	if current!=null:current.set_deferred('scroll_vertical',scroll_position)

static func _auto_party(main: Node) -> void:
	var candidates: Array=[]
	for hero in main._filtered_sorted_roster(main._hero_roster_for_faction()):
		if main.idle_stage>=int(hero.get('unlock_stage',1)):
			candidates.append(hero)
	if candidates.is_empty():
		if is_instance_valid(main.hero_hint):
			main.hero_hint.text='현재 필터에서 편성할 수 있는 영웅이 없습니다.'
		return
	main.deployed_heroes.clear()
	for hero in candidates.slice(0,main._party_slot_cap()):
		main.deployed_heroes.append(hero)
	main._save_idle_state()
	_refresh_roster(main)

static func retint(node: Node) -> void:
	if node is Panel or node is PanelContainer:
		node.add_theme_stylebox_override('panel',SKIN.box(Color('#233e42eb'),Color('#7c9e95'),14,1))
	elif node is Button:
		if node.find_parent('PortraitContentScroll')!=null:node.mouse_filter=Control.MOUSE_FILTER_PASS
		for state in ['font_color','font_hover_color','font_pressed_color','font_focus_color']:
			node.add_theme_color_override(state,SKIN.INK)
		node.add_theme_color_override('font_disabled_color',Color('#a2abc0'))
		node.add_theme_stylebox_override('normal',SKIN.box(SKIN.SURFACE_2,SKIN.EDGE_SOFT,12,1))
		node.add_theme_stylebox_override('hover',SKIN.box(SKIN.SURFACE_2.lightened(.12),SKIN.GOLD,12,1))
		node.add_theme_stylebox_override('pressed',SKIN.box(SKIN.SURFACE_2.darkened(.12),SKIN.GOLD,12,2))
		node.add_theme_stylebox_override('focus',SKIN.box(Color.TRANSPARENT,SKIN.GOLD,10,2))
		node.add_theme_stylebox_override('disabled',SKIN.box(Color('#30394c'),Color('#536078'),10,1))
	elif node is Label:
		node.add_theme_color_override('font_color',SKIN.UI.text_color(node.get_theme_color('font_color')))
		node.add_theme_font_size_override('font_size',maxi(14,node.get_theme_font_size('font_size')))
		node.add_theme_color_override('font_outline_color',SKIN.EDGE)
		node.add_theme_constant_override('outline_size',0)
	elif node is GameUiIcon:
		node.ink=SKIN.GOLD
	for child: Node in node.get_children():retint(child)

static func adapt(main: Node, title: String, active: String = '') -> void:
	# Keep original controls and callbacks; only present them inside the unified navy/blue mobile shell.
	var w: float=main.get_viewport_rect().size.x
	var h: float=main.get_viewport_rect().size.y
	var candidates: Array[Control]=[]
	for child: Node in main.content_root.get_children():
		if not child is Control:continue
		if child==main.skill_fx_layer:continue
		if child.name in ['PortraitMenuBackground','PortraitMenuShade']:
			continue
		if child.name in ['BottomNav','ScreenHeader','PortraitMenuHeader','PortraitNavigation']:
			child.visible=false
			continue
		if not child.visible:continue
		if child.position.y<174 and not child is Panel and not child is PanelContainer:
			child.visible=false;continue
		candidates.append(child)
	var scroll:=ScrollContainer.new();scroll.name='PortraitContentScroll';SKIN.make_scroll_responsive(scroll)
	SKIN.place(main.content_root,scroll,Rect2(14,145,w-28,h-255))
	var stack:=VBoxContainer.new();stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stack.add_theme_constant_override('separation',13);scroll.add_child(stack)
	candidates.sort_custom(func(a: Control,b: Control):
		if absf(a.position.y-b.position.y)<20:return a.position.x<b.position.x
		return a.position.y<b.position.y)
	for item in candidates:
		if item is Label:
			item.reparent(stack,false);item.custom_minimum_size=Vector2(w-50,38);item.size=Vector2(w-50,54)
			item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;item.add_theme_font_size_override('font_size',19);retint(item);continue
		var old:=item.size.max(item.get_combined_minimum_size()).max(Vector2(160,48))
		var factor:=clampf((w-44)/old.x,.48,1.45)
		var wrap:=PanelContainer.new();wrap.custom_minimum_size=Vector2(w-36,old.y*factor+12)
		wrap.add_theme_stylebox_override('panel',SKIN.box(Color('#172541dd'),Color('#485f86'),12,1));stack.add_child(wrap)
		var inner:=Control.new();inner.custom_minimum_size=Vector2(w-48,old.y*factor);wrap.add_child(inner)
		item.reparent(inner,false);item.position=Vector2(6,6);item.size=old;item.scale=Vector2.ONE*factor;retint(item)
	header(main,title,'%s · 골드 %s · 보석 %s'%[main._faction_name(),main._compact_hud_amount(main.wallet_gold),main._compact_hud_amount(main.wallet_gems)])
	HUD.navigation(main,main.content_root,active,h-90,90)

static func viewport_sheet(main: Node, title: String, active: String) -> void:
	var w: float=main.get_viewport_rect().size.x
	var h: float=main.get_viewport_rect().size.y
	var old_root: Control=main.content_root
	old_root.size=Vector2(1280,720);old_root.scale=Vector2.ONE*((w-20)/1280.0);old_root.position=Vector2(10,245);retint(old_root)
	var chrome:=Control.new();chrome.name='PortraitBoardChrome';chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE;main.add_child(chrome)
	var temp: Control=main.content_root;main.content_root=chrome
	header(main,title,'전투 규칙과 계산식은 기존 소스를 그대로 사용합니다.')
	HUD.navigation(main,chrome,active,h-90,90)
	main.content_root=temp

static func war(main: Node) -> void:
	var w: float=main.get_viewport_rect().size.x
	var h: float=main.get_viewport_rect().size.y
	var screen: WorldWarScreen
	for item in main.content_root.get_children():
		if item is WorldWarScreen:screen=item
		elif item is CanvasItem and item.name!='PortraitMenuBackground':item.visible=false
	if screen==null:return
	main.content_root.set_meta('portrait_tab','war')
	screen.configure_portrait()
	retint(screen)
	for btn in [screen.action_button,screen.support_button,screen.rally_button,screen.return_button,screen.cancel_button,screen.report_button]:
		btn.add_theme_font_size_override('font_size',18)
	header(main,'종의전쟁','%s · 천하 전도 · 영토 경영과 공성전'%main._faction_name())
	HUD.navigation(main,main.content_root,'war',h-90,90)
