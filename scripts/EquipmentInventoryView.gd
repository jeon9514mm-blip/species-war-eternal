extends Control
## Landscape workbench: two comparisons, direct actions and an icon inventory.
const P=preload('res://scripts/portrait/PortraitPages.gd')
const S=preload('res://scripts/portrait/PortraitSkin.gd')
const M=preload('res://scripts/portrait/PortraitMenus.gd')
const HUD=preload('res://scripts/portrait/PortraitHud.gd')
const C=preload('res://scripts/EquipmentComparison.gd')
const GEAR=preload('res://scripts/EquipmentRules.gd')
const ART=preload('res://scripts/EquipmentArtCatalog.gd')
const LIME=Color('#b8e86c')
const PAGE_SIZE=40
var game: Node
var selected_id:=''
var hero_id:=''
var comparison: HBoxContainer
var item_grid: GridContainer
var item_scroll: ScrollContainer
var action_column: VBoxContainer
var equip_button: Button
var upgrade_button: Button
var lock_button: Button
var source_button: Button
var detail_button: Button
var tiles: Dictionary={}
var settings_sheet: Control

static func refresh(main: Node) -> void:
	main.set_meta('gear_bag_page',0);main.set_meta('gear_bag_scroll',0)
	main.set_meta('gear_bag_reset_scroll',true);main._build_inventory_screen()

static func build(main: Node) -> void:
	if main.active_screen=='inventory' and not bool(main.get_meta('gear_bag_reset_scroll',false)):
		var previous: ScrollContainer=main.content_root.find_child('PortraitContentScroll',true,false)
		if previous!=null:main.set_meta('gear_bag_scroll',previous.scroll_vertical)
	main.set_meta('gear_bag_reset_scroll',false)
	main._clear_screen(true);main.active_screen='inventory'
	main.content_root.set_meta('portrait_ready',true);main.content_root.set_meta('portrait_tab','bag')
	var view: Control=load('res://scripts/EquipmentInventoryView.gd').new()
	view.name='EquipmentWorkbench';main.content_root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.install(main)

func _panel(parent: Node, rect: Rect2, edge: Color=S.EDGE_SOFT) -> PanelContainer:
	var panel:=PanelContainer.new();panel.position=rect.position;panel.size=rect.size
	var style:=S.box(S.SURFACE,edge,12,2);style.set_content_margin_all(12)
	panel.add_theme_stylebox_override('panel',style);parent.add_child(panel)
	return panel

func _button(parent: Node, caption: String, callback: Callable, primary: bool=false) -> Button:
	var button:=P.action(parent,caption,callback);button.custom_minimum_size.y=52
	button.add_theme_font_size_override('font_size',20)
	if primary:
		for state: String in ['normal','hover','pressed']:
			var style:=S.box(LIME if state=='normal' else LIME.lightened(.1),Color('#263023'),12,2)
			style.content_margin_left=10;style.content_margin_right=10
			button.add_theme_stylebox_override(state,style)
		for key: String in ['font_color','font_hover_color','font_pressed_color']:button.add_theme_color_override(key,Color('#182114'))
	return button

func install(main: Node) -> void:
	game=main;hero_id=C.selected_hero(game);game.set_meta('gear_equip_hero_id',hero_id)
	var viewport: Vector2=game.get_viewport_rect().size
	var w:=viewport.x;var h:=viewport.y
	var top:=HBoxContainer.new();top.add_theme_constant_override('separation',16)
	add_child(top);top.position=Vector2(20,12);top.size=Vector2(w-40,60)
	var back:=_button(top,'‹',Callable(game,'_build_lobby_screen'));back.name='EquipmentBagBack';back.custom_minimum_size.x=52;back.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var title:=P.text(top,'장비 관리',27);title.custom_minimum_size.x=152;title.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var selector:=OptionButton.new();selector.name='GearBagHero';selector.custom_minimum_size=Vector2(250,56)
	selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selector.clip_text=true;selector.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	selector.add_theme_font_size_override('font_size',21);top.add_child(selector);M.retint(selector)
	for hero: Dictionary in game._hero_roster_for_faction():
		selector.add_item(str(hero.get('name','영웅')));selector.set_item_metadata(selector.item_count-1,str(hero.id))
		if str(hero.id)==hero_id:selector.select(selector.item_count-1)
	selector.disabled=selector.item_count==0
	selector.item_selected.connect(func(index: int):
		hero_id=str(selector.get_item_metadata(index));game.set_meta('gear_equip_hero_id',hero_id)
		refresh(game))
	var money:=P.text(top,'G  '+game._compact_hud_amount(game.wallet_gold),21,S.GOLD)
	money.custom_minimum_size.x=135;money.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;money.size_flags_horizontal=Control.SIZE_SHRINK_END
	var close:=_button(top,'×',Callable(game,'_build_lobby_screen'));close.name='EquipmentBagClose';close.custom_minimum_size.x=56;close.size_flags_horizontal=Control.SIZE_SHRINK_END
	var body_y:=86.0;var body_h:=h-190.0
	var bag_w:=clampf(w*.35,430.0,530.0);var action_w:=120.0
	var compare_w:=w-64-bag_w-action_w
	comparison=HBoxContainer.new();comparison.name='EquipmentComparisons';comparison.add_theme_constant_override('separation',12)
	add_child(comparison);comparison.position=Vector2(16,body_y);comparison.size=Vector2(compare_w,body_h)
	action_column=P.stack(self,10);action_column.name='EquipmentActions'
	action_column.position=Vector2(28+compare_w,body_y);action_column.size=Vector2(action_w,body_h)
	equip_button=_button(action_column,'교체',_equip,true);equip_button.name='EquipmentEquip'
	upgrade_button=_button(action_column,'강화',func():_open_detail('enhance'));upgrade_button.name='GearWorkshop'
	source_button=_button(action_column,'획득처',_show_source);source_button.name='GearSource'
	detail_button=_button(action_column,'상세 정보',func():_open_detail('info'));detail_button.name='GearOpenDetails'
	lock_button=_button(action_column,'잠금',_toggle_lock);lock_button.name='GearQuickLock'
	P.text(action_column,'장착 부위',17,S.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for slot: String in game.EQUIPMENT_SLOTS:
		var button:=_button(action_column,game._equipment_slot_name(slot),func():_category(slot))
		button.name='GearLoadout_'+slot;button.custom_minimum_size.y=46;button.add_theme_font_size_override('font_size',18)
	var bag:=_panel(self,Rect2(w-16-bag_w,body_y,bag_w,body_h));bag.name='EquipmentBagPanel'
	var contents:=P.stack(bag,8)
	var bag_heading:=HBoxContainer.new();contents.add_child(bag_heading)
	P.text(bag_heading,'장비 가방',23).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var capacity:=P.text(bag_heading,'%d / %d'%[game.loot_inventory.size(),game.INVENTORY_CAP],21,S.GOLD)
	capacity.name='GearBagCapacity';capacity.autowrap_mode=TextServer.AUTOWRAP_OFF;capacity.size_flags_horizontal=Control.SIZE_SHRINK_END
	var categories:=P.grid(contents,5);categories.name='GearCategories';categories.add_theme_constant_override('h_separation',5)
	var filters: Dictionary=game.get_meta('gear_bag_filters',{})
	for entry: Array in [['all','전체'],['weapon','무기'],['armor','갑옷'],['accessory','장신구'],['crystal','결정']]:
		var key:=str(entry[0]);var active: bool=(str(filters.get('type','all'))=='option_crystal') if key=='crystal' else (str(filters.get('slot','all'))==key and str(filters.get('type','all'))!='option_crystal')
		var button:=_button(categories,str(entry[1]),func():_category(key),active)
		button.name='GearCategory_'+key;button.custom_minimum_size.y=48;button.add_theme_font_size_override('font_size',16)
	var tools_row:=HBoxContainer.new();tools_row.add_theme_constant_override('separation',6);contents.add_child(tools_row)
	var search:=LineEdit.new();search.name='GearSearch';search.placeholder_text='이름 · 세트 검색';search.text=str(filters.get('query',''))
	search.custom_minimum_size=Vector2(0,46);search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	search.add_theme_font_override('font',S.font());search.add_theme_font_size_override('font_size',17);tools_row.add_child(search)
	var submit:=func():
		var updated: Dictionary=game.get_meta('gear_bag_filters',{}).duplicate();updated['query']=search.text.strip_edges()
		game.set_meta('gear_bag_filters',updated);refresh(game)
	search.text_submitted.connect(func(_value: String):submit.call())
	var find:=_button(tools_row,'검색',submit);find.name='GearSearchApply';find.custom_minimum_size=Vector2(64,46);find.add_theme_font_size_override('font_size',16);find.size_flags_horizontal=Control.SIZE_SHRINK_END
	var sort:=OptionButton.new();sort.name='GearFilter_sort';sort.custom_minimum_size=Vector2(130,46);sort.clip_text=true;sort.size_flags_horizontal=Control.SIZE_SHRINK_END
	for entry: Array in [['rarity','등급순'],['power','장비력순'],['quality','옵션순'],['recent','최근순']]:
		sort.add_item(entry[1]);sort.set_item_metadata(sort.item_count-1,entry[0])
		if str(filters.get('sort','rarity'))==entry[0]:sort.select(sort.item_count-1)
	tools_row.add_child(sort);M.retint(sort)
	sort.item_selected.connect(func(index: int):var updated: Dictionary=game.get_meta('gear_bag_filters',{}).duplicate();updated['sort']=sort.get_item_metadata(index);game.set_meta('gear_bag_filters',updated);refresh(game))
	var rows:=P._inventory_rows(game,filters)
	var page_count:=maxi(1,ceili(float(rows.size())/PAGE_SIZE))
	var page_index:=clampi(int(game.get_meta('gear_bag_page',0)),0,page_count-1);game.set_meta('gear_bag_page',page_index)
	var status:=P.text(contents,'선택해서 비교 · %d개 표시'%rows.size(),15,S.MUTED);status.name='GearInventoryCount'
	item_scroll=ScrollContainer.new();item_scroll.name='PortraitContentScroll';S.make_scroll_responsive(item_scroll)
	item_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;item_scroll.custom_minimum_size.y=100;contents.add_child(item_scroll)
	item_grid=P.grid(item_scroll,4);item_grid.name='GearInventoryGrid';item_grid.add_theme_constant_override('h_separation',8);item_grid.add_theme_constant_override('v_separation',8)
	item_grid.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;item_grid.custom_minimum_size.x=bag_w-44
	selected_id=str(game.get_meta('gear_bag_selected_id',''))
	var ids: Array=[]
	for offset in mini(PAGE_SIZE,rows.size()-page_index*PAGE_SIZE):
		var item: Dictionary=rows[page_index*PAGE_SIZE+offset].item;ids.append(str(item.id));_tile(item)
	if selected_id not in ids:selected_id=str(ids[0]) if not ids.is_empty() else ''
	if rows.is_empty():
		P.text(item_grid,'조건에 맞는 장비가 없습니다.\n아래 필터에서 검색 조건을 지워 보세요.',18,S.MUTED)
	item_scroll.set_deferred('scroll_vertical',int(game.get_meta('gear_bag_scroll',0)))
	item_scroll.get_v_scroll_bar().value_changed.connect(func(value: float):game.set_meta('gear_bag_scroll',int(value)))
	var footer:=HBoxContainer.new();footer.name='GearInventoryPager';footer.add_theme_constant_override('separation',6);contents.add_child(footer)
	var previous:=_button(footer,'‹',func():_page(page_index-1));previous.name='GearPagePrevious';previous.disabled=page_index==0;previous.custom_minimum_size=Vector2(52,46);previous.size_flags_horizontal=Control.SIZE_SHRINK_END
	var counter:=P.text(footer,'%d / %d'%[page_index+1,page_count],18);counter.name='GearPageLabel';counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var next:=_button(footer,'›',func():_page(page_index+1));next.name='GearPageNext';next.disabled=page_index==page_count-1;next.custom_minimum_size=Vector2(52,46);next.size_flags_horizontal=Control.SIZE_SHRINK_END
	var settings:=_button(footer,'필터 · 관리',_show_settings);settings.name='GearSettingsToggle';settings.custom_minimum_size=Vector2(130,46);settings.add_theme_font_size_override('font_size',16);settings.size_flags_horizontal=Control.SIZE_SHRINK_END
	HUD.navigation(game,game.content_root,'bag',h-90,90)
	_render_details()
	if bool(game.get_meta('gear_settings_open',false)):_show_settings()

func _category(slot: String) -> void:
	var filters: Dictionary=game.get_meta('gear_bag_filters',{}).duplicate()
	filters['slot']='all' if slot in ['all','crystal'] else slot
	filters['type']='option_crystal' if slot=='crystal' else ('all' if slot=='all' else 'equipment')
	game.set_meta('gear_bag_filters',filters);refresh(game)

func _page(index: int) -> void:
	game.set_meta('gear_bag_page',index);game.set_meta('gear_bag_scroll',0);game.set_meta('gear_bag_reset_scroll',true);game._build_inventory_screen()

func _accent(item: Dictionary) -> Color:
	return {'일반':S.MUTED,'희귀':Color('#74c7ed'),'전설':Color('#d99ae7')}.get(str(item.get('rarity','일반')),S.MUTED)

func _tile(item: Dictionary) -> void:
	var item_id:=str(item.id);var button:=S.button('',func():_select_item(item_id))
	button.name='GearTile_'+item_id;button.set_meta('equipment_id',item_id);button.mouse_filter=Control.MOUSE_FILTER_PASS
	button.custom_minimum_size=Vector2(0,88);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.tooltip_text=P.item_title(item)+'\n'+GEAR.affix_text(item);item_grid.add_child(button);tiles[item_id]=button
	var crystal:=str(item.get('item_type','equipment'))=='option_crystal'
	if crystal:
		var symbol:=S.label('◆',40,Color('#9decdf'));S.place(button,symbol,Rect2(8,5,60,58));symbol.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	else:
		var art:=TextureRect.new();art.texture=ART.texture_for(item);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);art.offset_left=12;art.offset_top=8;art.offset_right=-12;art.offset_bottom=-19
	var level:=S.label('결정' if crystal else '+%d'%int(item.get('level',1)),15,S.INK);level.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	button.add_child(level);level.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);level.offset_left=4;level.offset_right=-7;level.offset_top=-24;level.offset_bottom=-3
	var locked:=S.label('잠금',12,LIME);locked.name='GearTileLock';locked.visible=bool(item.get('locked',false));S.place(button,locked,Rect2(5,3,42,20))

func _select_item(item_id: String) -> void:
	if not is_instance_valid(game) or game.active_screen!='inventory':return
	selected_id=item_id;game.set_meta('gear_bag_selected_id',selected_id);_render_details()

func _render_details() -> void:
	game.set_meta('gear_bag_selected_id',selected_id)
	for child in comparison.get_children():comparison.remove_child(child);child.queue_free()
	var item: Dictionary=game._gear_item(selected_id)
	var preview:=C.preview(game,item,hero_id) if not item.is_empty() else {}
	var current: Dictionary=preview.get('old',{})
	_item_card('현재 장비',current,false,preview)
	_item_card('선택 장비',item,true,preview)
	var crystal:=str(item.get('item_type','equipment'))=='option_crystal'
	equip_button.text='이식' if crystal else '교체'
	equip_button.disabled=item.is_empty() or (not crystal and (preview.is_empty() or not bool(preview.get('compatible',false)) or not (item.get('proposal',{}) as Dictionary).is_empty()))
	upgrade_button.disabled=item.is_empty() or crystal;detail_button.disabled=item.is_empty();source_button.disabled=item.is_empty();lock_button.disabled=item.is_empty()
	lock_button.text='잠금 해제' if bool(item.get('locked',false)) else '잠금'
	for id: String in tiles:
		var owned: Dictionary=game._gear_item(id);var accent:=_accent(owned)
		var style:=S.box(S.SURFACE_2,LIME if id==selected_id else accent,10,2)
		style.bg_color=Color('#344139') if id==selected_id else Color(accent.darkened(.76),1)
		tiles[id].add_theme_stylebox_override('normal',style)
		tiles[id].get_node('GearTileLock').visible=bool(owned.get('locked',false))

func _item_card(caption: String, item: Dictionary, candidate: bool, preview: Dictionary) -> void:
	var panel:=PanelContainer.new();panel.name='EquipmentCompareCandidate' if candidate else 'EquipmentCompareCurrent'
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var style:=S.box(S.SURFACE,_accent(item) if candidate else S.EDGE_SOFT,12,2);style.set_content_margin_all(12)
	panel.add_theme_stylebox_override('panel',style);comparison.add_child(panel)
	var scroll:=ScrollContainer.new();scroll.name='CandidateComparisonScroll' if candidate else 'CurrentComparisonScroll';S.make_scroll_responsive(scroll);panel.add_child(scroll)
	var body:=P.stack(scroll,9);body.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;body.custom_minimum_size.x=(comparison.size.x-12)*.5-42
	P.text(body,caption,18,LIME if candidate else S.MUTED)
	if item.is_empty():
		P.text(body,'장비를 선택하세요' if candidate else '장비 비교',24,S.INK)
		P.text(body,'오른쪽 가방에서 장비를 누르면 현재 장비와 바로 비교할 수 있어요.' if candidate else '영웅과 장비를 선택하면 같은 부위의 장착 상태를 표시합니다.',18,S.MUTED)
		return
	var identity:=HBoxContainer.new();identity.add_theme_constant_override('separation',10);body.add_child(identity)
	P.picture(identity,ART.texture_for(item),Vector2(56,60)).size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var identity_text:=P.stack(identity,3)
	var name_label:=P.text(identity_text,P.item_title(item),21,_accent(item));name_label.max_lines_visible=2;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name_label.tooltip_text=name_label.text
	var crystal:=str(item.get('item_type','equipment'))=='option_crystal'
	P.text(identity_text,str(item.get('rarity','일반'))+' · '+('옵션 결정' if crystal else game._equipment_slot_name(str(item.slot))),16,S.MUTED)
	if candidate and not preview.is_empty():
		if not bool(preview.compatible):P.text(body,'역할 전용 · 장착 불가',17,S.UI.RED).name='EquipmentRoleWarning'
		elif bool(preview.set_loss):P.text(body,'교체 시 기존 세트 효과 감소',17,S.UI.RED).name='EquipmentSetLossWarning'
	var attributes:=P.card(body,'장비 속성');attributes.get_parent().name='CandidateAttributes' if candidate else 'CurrentAttributes'
	if not crystal:_stat_row(attributes,'장비력',int(game._item_power(item)),false,int(preview.get('before',0)) if candidate else int(game._item_power(item)),candidate)
	var affixes: Array=[item.get('stored_option',{})] if crystal else item.get('affixes',[])
	if affixes.is_empty():P.text(attributes,'추가 옵션 없음',17,S.MUTED)
	for option: Dictionary in affixes:
		var previous:=0
		if candidate:
			for old_option: Dictionary in (preview.get('old',{}) as Dictionary).get('affixes',[]):
				if old_option.get('stat')==option.get('stat'):previous=int(old_option.get('value',0))
		else:previous=int(option.get('value',0))
		_stat_row(attributes,str(GEAR.STAT_NAMES.get(str(option.get('stat','')),'옵션')),int(option.get('value',0)),str(option.get('stat',''))!='defense',previous,candidate)
	if crystal:
		P.text(body,'결정의 옵션을 다른 장비에 이식할 수 있습니다.',18,S.MUTED)
		return
	var set_name:=str(item.get('set','초보자'));var sets: Dictionary=game._get_hero_equipment_sets(hero_id).duplicate() if not hero_id.is_empty() else {}
	if candidate:sets[str(item.slot)]=set_name
	var count:=0
	for value in sets.values():
		if str(value)==set_name:count+=1
	var set_box:=P.card(body,'세트 효과')
	P.text(set_box,set_name+'  %d / 3'%count,20,_accent(item))
	for threshold in [2,3]:
		var sample: Dictionary={'weapon':set_name,'armor':set_name,'accessory':set_name if threshold==3 else '초보자'}
		var summary: String=GEAR.set_profile(sample).summary
		var prior: String=GEAR.set_profile({'weapon':set_name,'armor':set_name,'accessory':'초보자'}).summary
		if threshold==3 and summary.begins_with(prior+' · '):summary=summary.trim_prefix(prior+' · ')
		elif threshold==3 and summary==prior:summary='추가 효과 없음'
		var active: bool=count>=int(threshold) and set_name!='초보자'
		P.text(set_box,('● ' if active else '○ ')+'%d세트'%threshold,18,LIME if active else S.MUTED)
		P.text(set_box,summary,16,S.INK if active else S.MUTED)
	if candidate and not preview.is_empty():
		for change: Dictionary in preview.changes:
			P.text(body,C.change_text(change),16,S.SUCCESS if int(change.after)>int(change.before) else S.UI.RED)
		if not (item.get('proposal',{}) as Dictionary).is_empty():P.text(body,'공방에서 옵션 후보를 먼저 선택하세요.',17,S.GOLD)
	P.text(body,'잠금 중' if bool(item.get('locked',false)) else ('귀속 장비' if bool(item.get('bound',false)) else '장착 시 귀속 · 기존 장비는 가방 보관'),15,S.MUTED)

func _stat_row(parent: Node, label: String, value: int, percent: bool, previous: int, compare: bool) -> void:
	var row:=HBoxContainer.new();row.add_theme_constant_override('separation',4);parent.add_child(row)
	P.text(row,label,18).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var suffix:='%' if percent else ''
	var direction:=' ↑' if value>previous else (' ↓' if value<previous else '')
	var amount:=P.text(row,'+%d%s%s'%[value,suffix,direction if compare else ''],19,S.SUCCESS if compare and value>previous else (S.UI.RED if compare and value<previous else S.INK))
	amount.autowrap_mode=TextServer.AUTOWRAP_OFF;amount.size_flags_horizontal=Control.SIZE_SHRINK_END

func _equip() -> void:
	var item: Dictionary=game._gear_item(selected_id)
	if str(item.get('item_type','equipment'))=='option_crystal':_open_detail('implant');return
	var before:=C.preview(game,item,hero_id)
	var result: Dictionary=game._gear_equip_item(selected_id,hero_id)
	if bool(result.get('ok',false)):game.set_meta('gear_bag_selected_id',str((before.get('old',{}) as Dictionary).get('id','')))
	game._build_inventory_screen();game._show_toast(str(result.get('reason','')))

func _open_detail(tab: String) -> void:
	game._build_equipment_detail(selected_id,'','',tab)

func _toggle_lock() -> void:
	var result: Dictionary=game._gear_workshop_action(selected_id,'toggle_lock')
	if str(game.get_meta('gear_bag_filters',{}).get('state','all'))=='locked':game._build_inventory_screen()
	else:_render_details()
	game._show_toast(str(result.get('reason','')))

func _sheet(title: String) -> VBoxContainer:
	# GUI hit testing follows sibling order, independently of draw z_index.
	# Keep the modal after the navigation so its shade consumes background taps.
	var shade:=ColorRect.new();shade.name='EquipmentOverlay';shade.color=Color(0,0,0,.72);shade.z_index=100
	shade.mouse_filter=Control.MOUSE_FILTER_STOP;game.content_root.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_sheet=shade
	var viewport: Vector2=game.get_viewport_rect().size
	var panel:=_panel(shade,Rect2(viewport.x*.2,42,viewport.x*.6,viewport.y-84),S.BLUE_SOFT)
	var column:=P.stack(panel,10)
	var row:=HBoxContainer.new();column.add_child(row);P.text(row,title,24)
	var close:=_button(row,'닫기',func():game.set_meta('gear_settings_open',false);shade.queue_free());close.name='EquipmentOverlayClose';close.custom_minimum_size.x=100;close.size_flags_horizontal=Control.SIZE_SHRINK_END
	var scroll:=ScrollContainer.new();scroll.name='EquipmentOverlayScroll';S.make_scroll_responsive(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	var body:=P.stack(scroll,10);body.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;body.custom_minimum_size.x=viewport.x*.6-42
	return body

func _input(event: InputEvent) -> void:
	if event.is_action_pressed('ui_cancel') and is_instance_valid(settings_sheet) and not settings_sheet.is_queued_for_deletion():
		game.set_meta('gear_settings_open',false);settings_sheet.queue_free();get_viewport().set_input_as_handled()

func _show_source() -> void:
	if is_instance_valid(settings_sheet) and not settings_sheet.is_queued_for_deletion():return
	var item: Dictionary=game._gear_item(selected_id)
	var body:=_sheet('획득처')
	P.text(body,P.item_title(item),23,S.GOLD)
	var zone: Dictionary=GEAR.ZONES.get(str(item.get('source_id','')),{})
	P.text(body,str(zone.get('name','기존 보유 장비')),23)
	P.text(body,GEAR.origin_text(item),20,S.BLUE_SOFT)
	P.text(body,'레이드에서 지역 전용 세트 장비를 얻을 수 있습니다.' if item.get('origin')=='raid' else ('해당 지역 사냥에서 얻을 수 있는 장비입니다.' if item.get('origin')=='hunt' else '이 장비의 획득 지역 기록이 없습니다. 사냥터와 레이드에서 새 장비를 확인하세요.'),20,S.MUTED)
	_button(body,'사냥터 보기',Callable(game,'_open_world_menu'),true).name='GearSourceWorld'

func _show_settings() -> void:
	if is_instance_valid(settings_sheet) and not settings_sheet.is_queued_for_deletion():return
	game.set_meta('gear_settings_open',true)
	var body:=_sheet('가방 필터 · 관리')
	var filters: Dictionary=game.get_meta('gear_bag_filters',{})
	var controls:=P.grid(body,3)
	P._gear_filter(game,controls,'type',[['all','전체 종류'],['equipment','장비'],['option_crystal','옵션 결정']],filters)
	P._gear_filter(game,controls,'rarity',[['all','전체 등급'],['전설','전설'],['희귀','희귀'],['일반','일반']],filters)
	P._gear_filter(game,controls,'state',[['all','전체 상태'],['usable','장착 가능'],['improved','장비력 상승'],['locked','잠금']],filters)
	_button(body,'필터 · 검색 초기화',func():game.set_meta('gear_bag_filters',{});refresh(game)).name='GearResetFilters'
	var tools_row:=P.grid(body,2)
	_button(tools_row,'파티 추천 장착',Callable(game,'_recommend_equip_all'),true).name='GearRecommendEquip'
	_button(tools_row,'보호 보관함 · %d'%game.equipment_overflow.size(),Callable(game,'_build_equipment_stash')).name='OpenEquipmentStash'
	P._inventory_settings(game,body,filters)
	for node_name: String in ['GearRecommendEquip','OpenEquipmentStash','OpenEquipmentMarket','GearBulkEnhance']:
		var navigation: Button=body.find_child(node_name,true,false)
		if navigation==null:continue
		for connection: Dictionary in navigation.pressed.get_connections():
			var callback: Callable=connection['callable'];navigation.pressed.disconnect(callback)
			navigation.pressed.connect(func():game.set_meta('gear_settings_open',false);callback.call())
