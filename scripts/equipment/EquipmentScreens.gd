class_name EquipmentScreens
extends RefCounted
## Equipment transactions live in Main/rules; these pages only display state and
## submit an explicit item ID so a stale button cannot modify a different item.
const P = preload('res://scripts/portrait/PortraitPages.gd')
const S = preload('res://scripts/portrait/PortraitSkin.gd')
const M = preload('res://scripts/portrait/PortraitMenus.gd')
const GEAR = preload('res://scripts/equipment/EquipmentRules.gd')
const ART = preload('res://scripts/equipment/EquipmentArtCatalog.gd')
const COMPARE=preload('res://scripts/equipment/EquipmentComparison.gd')

static func _result(main: Node, result: Dictionary) -> void:
	var message := str(result.get('reason',''))
	if not message.is_empty():main._show_toast(message)

static func _refresh_detail(main: Node, item_id: String, hero_id: String = '', slot: String = '', tab: String = '') -> void:
	var selected := tab if not tab.is_empty() else str(main.gear_workshop_context.get('tab','info'))
	main._build_equipment_detail(item_id,hero_id,slot,selected)

static func _work(main: Node, item_id: String, action: String, args: Dictionary, hero_id: String, slot: String) -> void:
	var result: Dictionary=main._gear_workshop_action(item_id,action,args,hero_id,slot)
	_refresh_detail(main,item_id,hero_id,slot)
	_result(main,result)

static func workshop(main: Node, item_id: String, hero_id: String = '', slot: String = '') -> void:
	detail(main,item_id,hero_id,slot,'options')

static func detail(main: Node, item_id: String, hero_id: String = '', slot: String = '', tab: String = 'info') -> void:
	var item: Dictionary=main._gear_item(item_id,hero_id,slot)
	var is_crystal := str(item.get('item_type','equipment'))=='option_crystal'
	if tab not in (['info','implant'] if is_crystal else ['info','enhance','options','implant']):tab='info'
	main.gear_workshop_context['tab']=tab
	var page := P.begin(main,'equipment_detail','옵션 결정' if is_crystal else '장비 공방','','bag')
	var header: Control=main.content_root.get_node('PortraitMenuHeader')
	header.offset_bottom=76
	var header_row: Control=header.get_child(0)
	header_row.offset_top=10;header_row.offset_bottom=64
	header.get_child(1).hide()
	var currency: Label=header_row.get_child(header_row.get_child_count()-1).get_child(0)
	currency.text='정수 %d'%main.raid_crystals;currency.name='EquipmentWorkshopBalance'
	var back: Button=header_row.get_child(0)
	for connection: Dictionary in back.pressed.get_connections():back.pressed.disconnect(connection['callable'])
	back.pressed.connect(Callable(main,'_back_from_equipment_detail'))
	back.name='EquipmentDetailBack';back.tooltip_text='이전 목록으로 돌아가기'
	if item.is_empty():
		P.text(P.card(page,'장비를 찾을 수 없습니다.'),'장착하거나 이동한 장비입니다. 목록에서 다시 선택해 주세요.',18,S.MUTED)
		return
	# The selected item stays on the left while each task uses the wide right pane.
	# Anchors keep both panes responsive without rebuilding transaction controls.
	var selected := PanelContainer.new();selected.name='EquipmentDetailHeader'
	var selected_style:=S.elevated(S.DARK_2,S.EDGE_SOFT,14);selected_style.set_content_margin_all(12)
	selected.add_theme_stylebox_override('panel',selected_style)
	main.content_root.add_child(selected)
	selected.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selected.anchor_right=0.32
	selected.offset_left=18;selected.offset_right=-8;selected.offset_top=92;selected.offset_bottom=-108
	var fixed := P.stack(selected,12)
	var identity := HBoxContainer.new()
	identity.name='EquipmentDetailIdentity';identity.custom_minimum_size=Vector2(0,82)
	identity.add_theme_constant_override('separation',14);fixed.add_child(identity)
	var art := P.picture(identity,ART.texture_for(item),Vector2(72,72))
	art.name='EquipmentArt';art.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	var label_box := P.stack(identity,2)
	var title := P.text(label_box,P.item_title(item),22,S.GOLD)
	title.max_lines_visible=1;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.tooltip_text=P.item_title(item)
	if is_crystal:
		P.text(label_box,'%s · 옵션 품질 %d%%'%[item.get('rarity','일반'),P.option_quality(item)],15,S.BLUE_SOFT)
	else:
		P.text(label_box,'%s · %s · 전투력 %d'%[item.get('rarity','일반'),main._equipment_slot_name(str(item.get('slot','weapon'))),main._item_power(item)],15,S.BLUE_SOFT)
	var state_text := '가방 보관'
	if not hero_id.is_empty():state_text='장착 중 · '+main._hero_short_name(hero_id)
	elif bool(item.get('locked',false)):state_text='가방 보관 · 잠금'
	elif bool(item.get('bound',false)):state_text='가방 보관 · 귀속'
	P.text(label_box,state_text,14,S.MUTED).name='EquipmentDetailState'
	var summary_scroll:=ScrollContainer.new();summary_scroll.name='EquipmentDetailSummaryScroll'
	S.make_scroll_responsive(summary_scroll);summary_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	fixed.add_child(summary_scroll)
	var summary:=P.stack(summary_scroll,10);summary.name='EquipmentInfoCard'
	_fit_scroll_content(summary_scroll,summary)
	P.text(summary,'보관된 옵션' if is_crystal else '장비 속성',21,S.INK)
	P.gear_summary(main,summary,item)
	if not hero_id.is_empty():P.text(summary,main._hero_short_name(hero_id)+'에게 장착 중',18,S.BLUE_SOFT)
	var task_header:=P.stack(main.content_root,7);task_header.name='EquipmentDetailTaskHeader'
	task_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	task_header.anchor_left=0.32
	task_header.offset_left=8;task_header.offset_right=-18;task_header.offset_top=92
	var tabs := P.grid(task_header,2 if is_crystal else 4)
	tabs.name='EquipmentDetailTabs';tabs.add_theme_constant_override('h_separation',8)
	for entry: Array in [['info','정보'],['enhance','강화'],['options','옵션'],['implant','이식']]:
		if is_crystal and str(entry[0]) not in ['info','implant']:continue
		var button := P.action(tabs,str(entry[1]),Callable(main,'_build_equipment_detail').bind(item_id,hero_id,slot,str(entry[0])),tab==str(entry[0]))
		button.name='DetailTab_'+str(entry[0]);button.toggle_mode=true;button.button_pressed=tab==str(entry[0])
	var hints: Dictionary={
		'info':'현재 상태·거래·장착 여부를 확인합니다.',
		'enhance':'강화 전후 전투력과 비용을 확인한 뒤 적용합니다.',
		'options':'옵션을 추가·교체·추출하고 후보를 비교합니다.',
		'implant':'옵션 결정을 다른 장비에 이식합니다.'
	}
	P.text(task_header,str(hints.get(tab,'')),16,S.MUTED).name='EquipmentDetailTabHint'
	var scroll: ScrollContainer=page.get_parent()
	scroll.anchor_left=0.32
	scroll.offset_left=8;scroll.offset_top=184;scroll.offset_right=-18;scroll.offset_bottom=-108
	_fit_scroll_content(scroll,page)
	match tab:
		'info':_detail_info(main,page,item,hero_id,slot,summary)
		'enhance':_detail_enhance(main,page,item,hero_id,slot)
		'options':_detail_options(main,page,item,hero_id,slot)
		'implant':
			if is_crystal:_crystal_targets(main,page,item)
			else:
				var crystals: Array=[]
				for owned: Dictionary in main.loot_inventory:
					if str(owned.get('item_type','equipment'))=='option_crystal':crystals.append(owned)
				_crystal_apply_panel(main,page,item,crystals,hero_id,slot)

static func _fit_scroll_content(scroll: ScrollContainer, body: Control) -> void:
	body.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var fit:=func():body.custom_minimum_size.x=maxf(100,scroll.size.x-18)
	scroll.resized.connect(fit);fit.call_deferred()

static func _detail_info(main: Node, page: Node, item: Dictionary, hero_id: String, slot: String, info: Node) -> void:
	var item_id := str(item.get('id',''))
	var is_crystal := str(item.get('item_type','equipment'))=='option_crystal'
	if not is_crystal and hero_id.is_empty():_equip_comparison(main,page,item)
	var utility := P.grid(info,2)
	utility.name='EquipmentInfoUtilities'
	P.action(utility,'잠금 해제' if bool(item.get('locked',false)) else '잠금',Callable(EquipmentScreens,'_work').bind(main,item_id,'toggle_lock',{},hero_id,slot)).name='EquipmentToggleLock'
	var trade := P.action(utility,'거래소에 판매',func():main.set_meta('market_selected_item_id',item_id);main._build_equipment_market())
	trade.name='EquipmentSell';trade.disabled=not hero_id.is_empty() or not GEAR.tradable(item)
	if is_crystal:
		P.action(page,'이식할 장비 선택',Callable(main,'_build_equipment_detail').bind(item_id,'','','implant'),true).name='EquipmentCrystalImplant'
		return
	var task_shortcuts := P.card(page,'바로 작업')
	task_shortcuts.get_parent().name='EquipmentQuickTasks'
	var task_grid := P.grid(task_shortcuts,3)
	P.action(task_grid,'강화',Callable(main,'_build_equipment_detail').bind(item_id,hero_id,slot,'enhance'),true).name='EquipmentQuickEnhance'
	P.action(task_grid,'옵션',Callable(main,'_build_equipment_detail').bind(item_id,hero_id,slot,'options')).name='EquipmentQuickOptions'
	P.action(task_grid,'이식',Callable(main,'_build_equipment_detail').bind(item_id,hero_id,slot,'implant')).name='EquipmentQuickImplant'
	if not hero_id.is_empty():
		P.action(page,'같은 부위 장비 비교',func():
			main.set_meta('gear_equip_hero_id',hero_id)
			var filters: Dictionary=main.get_meta('gear_bag_filters',{}).duplicate()
			filters['slot']=slot;filters['type']='equipment'
			main.set_meta('gear_bag_filters',filters)
			main.set_meta('gear_bag_page',0);main.set_meta('gear_bag_reset_scroll',true)
			main._build_inventory_screen(),true).name='EquipmentFindReplacement'
		return
	var salvage := P.action(page,'분해 · %dG 받기'%main._inventory_salvage_value(item),Callable(EquipmentScreens,'_confirm_decompose').bind(main,item_id))
	salvage.name='EquipmentDecompose';salvage.disabled=bool(item.get('locked',false)) or not (item.get('proposal',{}) as Dictionary).is_empty()

static func _equip_comparison(main: Node, page: Node, item: Dictionary) -> void:
	var equip := P.card(page,'장착 전 비교',S.GOLD)
	equip.get_parent().name='EquipmentEquipPanel'
	var eligible: Array=[]
	for hero: Dictionary in main._hero_roster_for_faction():
		if main._gear_role_matches(item,str(hero.get('id',''))):eligible.append(hero)
	if eligible.is_empty():
		P.text(equip,'장착 가능한 영웅이 없습니다. 진영과 전용 역할을 확인해 주세요.',18,S.MUTED)
		return
	var selection:=_selection(equip,'EquipmentHeroSelection')
	selection.custom_minimum_size.y=64;selection.add_theme_font_size_override('font_size',20)
	var selected_hero:=COMPARE.selected_hero(main)
	for hero: Dictionary in eligible:
		selection.add_item(str(hero.get('name','영웅')));selection.set_item_metadata(selection.item_count-1,str(hero.id))
		if str(hero.id)==selected_hero:selection.select(selection.item_count-1)
	var comparison_body:=P.stack(equip,10);comparison_body.name='EquipmentComparisonBody'
	var footer:=P.stack(main.content_root,0);footer.name='EquipmentEquipFooter'
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.anchor_left=0.32
	footer.offset_left=8;footer.offset_right=-18;footer.offset_top=-184;footer.offset_bottom=-108
	var wear:=P.action(footer,'장착',func():
		var candidate_id:=str(selection.get_item_metadata(selection.selected))
		var result: Dictionary=main._gear_equip_item(str(item.id),candidate_id)
		if bool(result.get('ok',false)):_refresh_detail(main,str(item.id),str(result.get('hero_id','')),str(result.get('slot',item.get('slot','weapon'))),'info')
		else:_refresh_detail(main,str(item.id),'','','info')
		_result(main,result),true)
	wear.name='EquipmentEquip';wear.custom_minimum_size.y=76;wear.add_theme_font_size_override('font_size',22)
	wear.disabled=not (item.get('proposal',{}) as Dictionary).is_empty()
	var scroll: ScrollContainer=page.get_parent();scroll.offset_bottom=-200
	var refresh:=func():
		for child in comparison_body.get_children():comparison_body.remove_child(child);child.queue_free()
		var candidate_id:=str(selection.get_item_metadata(selection.selected));main.set_meta('gear_equip_hero_id',candidate_id)
		var snapshot:=COMPARE.preview(main,item,candidate_id)
		var cards:=P.grid(comparison_body,2)
		for entry: Array in [['현재 장비',snapshot.old],['교체 장비',item]]:
			var current: Dictionary=entry[1]
			var box:=P.card(cards,str(entry[0]))
			box.get_parent().name='EquipmentCompareCurrent' if str(entry[0])=='현재 장비' else 'EquipmentCompareCandidate'
			P.picture(box,ART.texture_for(current),Vector2(0,54))
			var title:=P.text(box,P.item_title(current),18,S.INK)
			title.max_lines_visible=2;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.tooltip_text=title.text
			P.text(box,'장비력 %d'%main._item_power(current),20,S.GOLD)
		var delta: int=snapshot.delta
		P.text(comparison_body,'장비력 %d → %d  (%s%d)'%[int(snapshot.before),int(snapshot.after),'+' if delta>=0 else '',delta],22,S.SUCCESS if delta>0 else S.MUTED).name='EquipComparison'
		if bool(snapshot.set_loss):P.text(comparison_body,'세트 효과 감소 · 장비력이 높아도 능력치가 줄 수 있어요.',18,Color('#f29484')).name='EquipmentSetLossWarning'
		if str(snapshot.before_set)!=str(snapshot.after_set):
			P.text(comparison_body,'현재: '+str(snapshot.before_set)+'\n교체 후: '+str(snapshot.after_set),16,S.MUTED).name='EquipmentSetComparison'
		for change: Dictionary in snapshot.changes:
			P.text(comparison_body,COMPARE.change_text(change),18,S.SUCCESS if int(change.after)>int(change.before) else Color('#f29484'))
		if (snapshot.changes as Array).is_empty():P.text(comparison_body,'세트·추가 옵션 능력치 변화 없음',16,S.MUTED)
		P.text(comparison_body,'장착 시 귀속 · 현재 장비는 가방에 보관됩니다.',16,S.MUTED)
		wear.text=main._hero_short_name(candidate_id)+'에게 장착';wear.tooltip_text=wear.text
		if wear.disabled:P.text(comparison_body,'옵션 탭에서 조율 후보를 먼저 선택해 주세요.',18,S.GOLD)
	selection.item_selected.connect(func(_index: int):refresh.call());refresh.call()

static func _selection(parent: Node, node_name: String) -> OptionButton:
	var control := OptionButton.new()
	control.name=node_name;control.custom_minimum_size=Vector2(0,52);control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	control.clip_text=true;control.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(control);M.retint(control)
	return control

static func _detail_enhance(main: Node, page: Node, item: Dictionary, hero_id: String, slot: String) -> void:
	var level := int(item.get('level',1))
	var cost: int=main._inventory_upgrade_cost(item)
	var box := P.card(page,'강화 미리보기',S.GOLD)
	box.get_parent().name='EquipmentEnhancePanel'
	var next := item.duplicate(true);next['level']=mini(10,level+1)
	var metrics := P.grid(box,2)
	P._metric_tile(metrics,'강화 단계','+%d'%level,S.GOLD,'최대 +10')
	P._metric_tile(metrics,'전투력',str(main._item_power(item)),S.BLUE_SOFT,'강화 후 %d'%main._item_power(next))
	P.text(box,'+%d → +%d'%[level,int(next['level'])] if level<10 else '최대 강화 +10',28,S.GOLD).name='EquipmentEnhanceLevels'
	P.text(box,'장비 전투력 %d → %d'%[main._item_power(item),main._item_power(next)],20,S.BLUE_SOFT).name='EquipmentEnhancePower'
	P.text(box,'비용 %sG · 보유 %sG'%[main._compact_hud_amount(cost),main._compact_hud_amount(main.wallet_gold)] if level<10 else '모든 강화 단계를 완료했습니다.',17,S.MUTED)
	var enhance := P.action(box,'강화 적용 · %sG'%main._compact_hud_amount(cost) if level<10 else '최대 강화 완료',func():
		var result: Dictionary=main._gear_enhance_item(str(item.get('id','')),hero_id,slot)
		_refresh_detail(main,str(item.get('id','')),hero_id,slot,'enhance');_result(main,result),true)
	enhance.name='EquipmentEnhance';enhance.disabled=level>=10 or main.wallet_gold<cost
	if level<10 and main.wallet_gold<cost:P.text(box,'강화에 필요한 골드가 부족합니다.',17,S.GOLD)
	P.text(box,'강화 성공률 100% · 현재 옵션과 세트 효과는 그대로 유지됩니다.',16,S.SUCCESS)

static func _detail_options(main: Node, page: Node, item: Dictionary, hero_id: String, slot: String) -> void:
	var item_id := str(item.get('id',''))
	var affixes: Array=item.get('affixes',[])
	var capacity: int=GEAR.option_capacity(item)
	var proposal: Dictionary=item.get('proposal',{})
	var focus := clampi(int(item.get('focus',0)),0,3)
	var current := P.card(page,'현재 옵션 %d / %d'%( [affixes.size(),capacity] ))
	if affixes.is_empty():P.text(current,'빈 옵션 칸에 원하는 계열을 조율해 보세요.',18,S.MUTED)
	for index in affixes.size():
		var option := P.stack(current,6)
		P.text(option,GEAR.stat_text(affixes[index])+' · '+GEAR.option_quality_text(affixes[index]),18,S.GOLD)
		var actions := P.grid(option)
		var remove := P.action(actions,'삭제 · 6 정수',Callable(EquipmentScreens,'_confirm_remove').bind(main,item_id,index,hero_id,slot))
		remove.name='WorkshopRemove%d'%index;remove.disabled=main.raid_crystals<6 or not proposal.is_empty()
		var extract := P.action(actions,'추출 · 18 정수',Callable(EquipmentScreens,'_confirm_extract').bind(main,item_id,index,hero_id,slot))
		extract.name='WorkshopExtract%d'%index;extract.disabled=main.raid_crystals<18 or not proposal.is_empty() or bool(item.get('locked',false))
	if not proposal.is_empty():
		var pending := P.card(page,'저장된 후보 · 하나 선택',S.BLUE)
		P.text(pending,'정수 %d개 사용 완료 · 나가도 후보는 유지됩니다.'%int(proposal.get('cost',0)),16,S.MUTED)
		var options: Array=proposal.get('options',[])
		for index in options.size():
			P.action(pending,GEAR.stat_text(options[index])+' 선택',Callable(EquipmentScreens,'_work').bind(main,item_id,'choose',{'index':index},hero_id,slot),true).name='WorkshopChoose%d'%index
		P.action(pending,'후보 포기 · 환불 없음',Callable(EquipmentScreens,'_work').bind(main,item_id,'discard',{},hero_id,slot)).name='WorkshopDiscard'
		return
	var add := P.card(page,'옵션 조율 · 집중 %d / 3'%focus)
	P.text(add,'삭제할 때 집중 +1 · 집중 3이면 다음 조율은 최대 수치',16,S.MUTED)
	if affixes.size()>=capacity:
		P.text(add,'옵션 칸이 가득 찼습니다. 바꿀 옵션을 삭제하거나 추출해 주세요.',18,S.BLUE_SOFT)
		return
	var families: Array=[['assault','공격 · 공격력 / 궁극기 충전'],['guard','수호 · 체력 / 방어력'],['flow','순환 · 공격 속도 / 궁극기 충전']]
	var selection := _selection(add,'WorkshopFamilySelection')
	for family: Array in families:
		selection.add_item(str(family[1]));selection.set_item_metadata(selection.item_count-1,str(family[0]))
		if str(main.get_meta('gear_workshop_family','assault'))==str(family[0]):selection.select(selection.item_count-1)
	var cost := 12+8*affixes.size()
	var roll := P.action(add,'후보 확인 · %d 정수'%cost,func():_work(main,item_id,'preview',{'family':str(selection.get_item_metadata(selection.selected))},hero_id,slot),true)
	roll.name='WorkshopPreview'
	var hint := P.text(add,'',16,S.MUTED)
	var refresh := func():
		var family := str(selection.get_item_metadata(selection.selected))
		main.set_meta('gear_workshop_family',family)
		var available: Array=GEAR.FAMILIES[family].duplicate()
		for affix: Dictionary in affixes:available.erase(str(affix.get('stat','')))
		roll.disabled=main.raid_crystals<cost or available.is_empty()
		hint.text='이 계열의 옵션은 모두 보유 중입니다.' if available.is_empty() else ('레이드 정수가 부족합니다.' if main.raid_crystals<cost else '확인 즉시 정수 차감 · 무작위 후보 중 1개 선택')
	selection.item_selected.connect(func(_index: int):refresh.call());refresh.call()
	P.text(add,'공격 속도·궁극기 충전은 사냥·레이드에 적용됩니다.',16,S.BLUE_SOFT)

static func _confirm_decompose(main: Node, item_id: String) -> void:
	var item: Dictionary=main._gear_item(item_id)
	if item.is_empty():return
	var confirm := ConfirmationDialog.new()
	confirm.name='EquipmentDecomposeConfirmation';confirm.title='장비 분해'
	confirm.dialog_text='%s\n분해하면 %dG를 얻습니다.\n장비와 모든 옵션이 사라지며 복구되지 않습니다.'%[P.item_title(item),main._inventory_salvage_value(item)]
	confirm.ok_button_text='장비 분해';confirm.cancel_button_text='유지하기';confirm.min_size=Vector2i(480,180)
	main.add_child(confirm)
	confirm.confirmed.connect(func():
		var result: Dictionary=main._gear_decompose_item(item_id,true)
		if bool(result.get('ok',false)):main._back_from_equipment_detail()
		else:_refresh_detail(main,item_id)
		_result(main,result);confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free);confirm.popup_centered()

static func _confirm_remove(main: Node, item_id: String, index: int, hero_id: String, slot: String) -> void:
	var item: Dictionary=main._gear_item(item_id,hero_id,slot)
	var options: Array=item.get('affixes',[])
	if index<0 or index>=options.size():return
	var expected_option: Dictionary=options[index].duplicate(true)
	var confirm := ConfirmationDialog.new()
	confirm.name='EquipmentRemoveConfirmation';confirm.title='옵션 삭제'
	confirm.dialog_text='선택한 옵션을 삭제하고 레이드 정수 6개를 사용합니다.\n삭제한 옵션은 복구되지 않으며 공명 집중이 1 증가합니다.'
	confirm.ok_button_text='6 정수로 삭제';confirm.cancel_button_text='유지하기'
	confirm.min_size=Vector2i(480,180)
	main.add_child(confirm)
	confirm.confirmed.connect(func():
		_work(main,item_id,'remove',{'index':index,'expected_option':expected_option},hero_id,slot);confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

static func _trade(main: Node, action: String, params: Dictionary) -> void:
	var result: Dictionary=main._market_submit(action,params)
	main._build_equipment_market()
	_result(main,result)

static func _confirm_trade(main: Node, action: String, params: Dictionary, description: String) -> void:
	var confirm := ConfirmationDialog.new()
	confirm.name='EquipmentTradeConfirmation';confirm.title='판매 등록 확인' if action=='list' else '장비 구매 확인'
	confirm.dialog_text=description
	confirm.ok_button_text='판매 등록' if action=='list' else '골드로 구매';confirm.cancel_button_text='다시 확인'
	confirm.min_size=Vector2i(480,210)
	main.add_child(confirm)
	confirm.confirmed.connect(func():_trade(main,action,params);confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

static func _item_card(main: Node, parent: Node, item: Dictionary) -> VBoxContainer:
	var box := P.card(parent,P.item_title(item))
	P.gear_summary(main,box,item)
	return box

static func market(main: Node) -> void:
	var snapshot: Dictionary=main._market_snapshot()
	var account: Dictionary=snapshot.get('account',{})
	var page := P.begin(main,'equipment_market','장비·옵션 거래소','골드 %s · 레이드 정수 %d'%[main._compact_hud_amount(main.wallet_gold),main.raid_crystals],'bag')
	var notice := P.card(page,'로컬 거래소 · 온라인 서버 미연결',S.GOLD)
	P.text(notice,'현재 이 기기에서 판매 등록·취소·정산을 관리할 수 있습니다. 다른 플레이어의 매물은 온라인 서버 연결 후 이용할 수 있습니다.',18,S.MUTED).name='EquipmentMarketConnection'
	P.text(notice,'판매 수수료 5% · 등록·취소 무료 · 48시간 뒤 만료\n미귀속 장비·옵션 결정 거래 가능 · 구매 즉시 귀속\n구매한 옵션은 다시 추출해도 거래할 수 없습니다.',16,S.BLUE_SOFT)
	P.action(page,'가방으로 돌아가기',Callable(main,'_build_inventory_screen'))
	var wallet := P.card(page,'거래 정산')
	var pending_gold := int(account.get('pending_gold',0))
	P.text(wallet,'받을 판매 대금 %sG'%main._compact_hud_amount(pending_gold),21,S.GOLD)
	var settle := P.action(wallet,'판매 대금 받기',Callable(EquipmentScreens,'_trade').bind(main,'claim',{'gold_only':true}),true)
	settle.name='MarketClaimGold';settle.disabled=pending_gold<=0
	var deliveries: Array=account.get('deliveries',[])
	for entry: Dictionary in deliveries:
		var delivered: Dictionary=entry.get('item',entry)
		var delivery := _item_card(main,wallet,delivered)
		P.action(delivery,'물품 받기',Callable(EquipmentScreens,'_trade').bind(main,'claim',{'item_id':str(delivered.get('id',''))}),true).name='MarketClaim_'+str(delivered.get('id',''))
	var sale := P.card(page,'판매 등록')
	var eligible: Array=[]
	for raw: Dictionary in main.loot_inventory:
		var item: Dictionary=main._normalize_inventory_item(raw)
		if GEAR.tradable(item):eligible.append(item)
	if eligible.is_empty():
		P.text(sale,'판매 가능한 장비가 없습니다. 자동 장착을 끄고, 미귀속 장비를 가방에 모아 보세요.',18,S.MUTED)
	else:
		var selection := OptionButton.new()
		selection.name='MarketSaleItem';selection.custom_minimum_size=Vector2(0,52);selection.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		selection.clip_text=true;selection.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		for item: Dictionary in eligible:
			selection.add_item(P.item_title(item)+' · '+(GEAR.affix_text(item) if str(item.get('item_type','equipment'))=='option_crystal' else str(item.get('rarity','일반'))))
			selection.set_item_metadata(selection.item_count-1,str(item.get('id','')))
			if str(main.get_meta('market_selected_item_id',''))==str(item.get('id','')):selection.select(selection.item_count-1)
		sale.add_child(selection);M.retint(selection)
		P.text(sale,'판매 가격 · 골드',18)
		var price := SpinBox.new()
		price.name='MarketSalePrice';price.min_value=10;price.max_value=1000000000;price.step=1;price.value=1000
		price.custom_minimum_size=Vector2(0,52);price.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		price.get_line_edit().add_theme_font_size_override('font_size',20)
		sale.add_child(price)
		P.text(sale,'등록하면 선택한 물품이 거래소에 보관됩니다. 취소·만료 시 배송함에서 다시 받을 수 있습니다.',16,S.MUTED)
		P.action(sale,'선택 물품 판매 등록',func():
			price.apply()
			var amount := int(price.value)
			var fee := maxi(1,int(ceil(float(amount)*0.05)))
			_confirm_trade(main,'list',{'item_id':str(selection.get_item_metadata(selection.selected)),'price':amount},'%s\n판매가 %sG · 수수료 %sG (5%%)\n판매 완료 후 받을 금액 %sG\n등록한 장비는 거래소에 보관됩니다.'%[selection.get_item_text(selection.selected),main._compact_hud_amount(amount),main._compact_hud_amount(fee),main._compact_hud_amount(amount-fee)]),true).name='MarketList'
	var own: Array=snapshot.get('own_listings',[])
	P.text(page,'내 판매 목록 · %d개'%own.size(),24)
	if own.is_empty():P.text(P.card(page),'등록한 장비가 없습니다.',18,S.MUTED)
	for listing: Dictionary in own:
		var box := _item_card(main,page,listing.get('item',{}))
		P.text(box,'판매가 %sG'%main._compact_hud_amount(int(listing.get('price',0))),21,S.GOLD)
		var status := str(listing.get('status','active'))
		if status=='active':
			var remaining := maxi(0,int(listing.get('expires_at',0))-int(Time.get_unix_time_from_system()))
			P.text(box,'판매 중 · 남은 시간 %d시간 %d분'%[remaining/3600,(remaining%3600)/60],16,S.BLUE_SOFT)
			P.action(box,'판매 취소 · 장비 돌려받기',Callable(EquipmentScreens,'_trade').bind(main,'cancel',{'listing_id':str(listing.get('id',''))})).name='MarketCancel_'+str(listing.get('id',''))
		else:
			P.text(box,str({'sold':'판매 완료 · 판매 대금을 확인하세요.','cancelled':'등록 취소 · 배송함에서 장비를 받으세요.','expired':'기간 만료 · 배송함에서 장비를 받으세요.'}.get(status,'거래 종료')),17,S.MUTED)
	var listings: Array=snapshot.get('listings',[])
	var own_ids: Dictionary={}
	for entry: Dictionary in own:own_ids[str(entry.get('id',''))]=true
	var browse := P.card(page,'매물 둘러보기')
	var browse_type := str(main.get_meta('gear_market_type','all'))
	var category := OptionButton.new()
	category.name='MarketTypeFilter';category.custom_minimum_size=Vector2(0,52);category.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for entry: Array in [['all','장비·옵션 결정 전체'],['equipment','장비'],['option_crystal','옵션 결정']]:
		category.add_item(str(entry[1]));category.set_item_metadata(category.item_count-1,str(entry[0]))
		if browse_type==str(entry[0]):category.select(category.item_count-1)
	category.item_selected.connect(func(index: int):main.set_meta('gear_market_type',str(category.get_item_metadata(index)));main._build_equipment_market())
	browse.add_child(category);M.retint(category)
	var count:=0
	for listing: Dictionary in listings:
		if own_ids.has(str(listing.get('id',''))):continue
		if browse_type!='all' and str((listing.get('item',{}) as Dictionary).get('item_type','equipment'))!=browse_type:continue
		count+=1
		var box := _item_card(main,browse,listing.get('item',{}))
		P.text(box,'판매자 '+str(listing.get('seller_name','원정대')),16,S.MUTED)
		var buy := P.action(box,'%sG로 구매'%main._compact_hud_amount(int(listing.get('price',0))),Callable(EquipmentScreens,'_confirm_trade').bind(main,'buy',{'listing_id':str(listing.get('id',''))},'%s\n구매 가격 %sG를 사용합니다.\n구매 즉시 귀속되며 다시 판매할 수 없습니다.\n구매 장비는 거래 배송함에서 받을 수 있습니다.'%[str((listing.get('item',{}) as Dictionary).get('name','장비')),main._compact_hud_amount(int(listing.get('price',0)))]),true)
		buy.name='MarketBuy_'+str(listing.get('id',''));buy.disabled=main.wallet_gold<int(listing.get('price',0))
	if count==0:P.text(browse,'다른 원정대의 매물이 아직 없습니다.',18,S.MUTED)
	P.action(page,'거래소 새로고침',Callable(main,'_build_equipment_market')).name='MarketRefresh'

static func stash(main: Node) -> void:
	preload('res://scripts/equipment/EquipmentStashView.gd').build(main)

static func _confirm_extract(main: Node, item_id: String, index: int, hero_id: String, slot: String) -> void:
	var item: Dictionary=main._gear_item(item_id,hero_id,slot)
	var affixes: Array=item.get('affixes',[])
	if index<0 or index>=affixes.size():return
	var expected_option: Dictionary=affixes[index].duplicate(true)
	var confirm := ConfirmationDialog.new()
	confirm.name='EquipmentExtractConfirmation';confirm.title='옵션 결정 추출'
	confirm.dialog_text='%s\n레이드 정수 18개를 사용합니다.\n원본 장비에서 이 옵션이 제거되고 수치가 같은 결정이 생깁니다.\n결정은 가방에 보관되며, 가득 차면 우편함으로 이동합니다.\n구매한 옵션은 추출해도 귀속이 유지됩니다.'%GEAR.stat_text(affixes[index])
	confirm.ok_button_text='18 정수로 추출';confirm.cancel_button_text='옵션 유지'
	confirm.min_size=Vector2i(480,230)
	main.add_child(confirm)
	confirm.confirmed.connect(func():
		var result: Dictionary=main._gear_extract_option(item_id,index,hero_id,slot,expected_option)
		_refresh_detail(main,item_id,hero_id,slot,'options');_result(main,result);confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

static func _apply_reason(main: Node, item: Dictionary, crystal_item: Dictionary) -> String:
	if bool(crystal_item.get('locked',false)):return '결정의 잠금을 먼저 해제해 주세요.'
	if bool(item.get('locked',false)):return '대상 장비의 잠금을 먼저 해제해 주세요.'
	if not (item.get('proposal',{}) as Dictionary).is_empty():return '조율 후보를 선택하거나 포기한 뒤 이식할 수 있습니다.'
	var affixes: Array=item.get('affixes',[])
	if affixes.size()>=GEAR.option_capacity(item):return '대상 장비에 빈 옵션 칸이 필요합니다.'
	for affix: Dictionary in affixes:
		if str(affix.get('stat',''))==str((crystal_item.get('stored_option',{}) as Dictionary).get('stat','')):return '이미 같은 종류의 옵션을 보유하고 있습니다.'
	if main.raid_crystals<8:return '이식에 필요한 레이드 정수 8개가 부족합니다.'
	return ''

static func _crystal_apply_panel(main: Node, parent: Node, item: Dictionary, crystals: Array, hero_id: String, slot: String) -> void:
	var box := P.card(parent,'옵션 결정 이식 · 8 정수')
	P.text(box,'결정의 수치를 그대로 빈 옵션 칸에 옮깁니다. 결정 1개가 소모되며 같은 종류의 옵션은 중복할 수 없습니다.',17,S.MUTED)
	if crystals.is_empty():
		P.text(box,'가방에 보유한 옵션 결정이 없습니다. 좋은 옵션을 추출하거나 거래소에서 얻을 수 있습니다.',17,S.BLUE_SOFT)
		return
	var selection := OptionButton.new()
	selection.name='WorkshopCrystalSelection';selection.custom_minimum_size=Vector2(0,52);selection.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	selection.clip_text=true;selection.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for candidate: Dictionary in crystals:
		selection.add_item('%s · 최대치 대비 %d%%'%[GEAR.affix_text(candidate),P.option_quality(candidate)])
	box.add_child(selection);M.retint(selection)
	var preview := P.text(box,'',18,S.SUCCESS);preview.name='CrystalApplyPreview'
	var hint := P.text(box,'',16,S.MUTED);hint.name='CrystalApplyState'
	var apply := P.action(box,'선택 결정 이식 · 8 정수',func():_confirm_apply(main,str(crystals[selection.selected].get('id','')),str(item.get('id','')),hero_id,slot),true)
	apply.name='WorkshopApplyCrystal'
	var refresh := func():
		var candidate: Dictionary=crystals[selection.selected]
		var after := item.duplicate(true)
		var options: Array=after.get('affixes',[]).duplicate(true)
		options.append((candidate.get('stored_option',{}) as Dictionary).duplicate(true));after['affixes']=options
		preview.text='현재 · '+GEAR.affix_text(item)+'\n이식 후 · '+GEAR.affix_text(after)
		var reason := _apply_reason(main,item,candidate)
		apply.disabled=not reason.is_empty()
		hint.text=reason if not reason.is_empty() else ('구매한 결정의 옵션은 이식·재추출 후에도 귀속됩니다.' if bool(candidate.get('bound',false)) or int(candidate.get('trade_count',0))>0 else '수치가 다시 무작위로 바뀌지 않습니다.')
	selection.item_selected.connect(func(_index: int):refresh.call())
	refresh.call()

static func _confirm_apply(main: Node, crystal_id: String, item_id: String, hero_id: String, slot: String) -> void:
	var item: Dictionary=main._gear_item(item_id,hero_id,slot)
	var crystal_item: Dictionary=main._gear_item(crystal_id)
	if item.is_empty() or crystal_item.is_empty():return
	var confirm := ConfirmationDialog.new()
	confirm.name='EquipmentApplyConfirmation';confirm.title='옵션 이식 확인'
	confirm.dialog_text='%s\n대상: %s\n정수 8개와 결정 1개를 사용해 옵션을 추가합니다.\n결정에 저장된 수치는 바뀌지 않습니다.\n구매한 옵션은 재추출해도 다시 판매할 수 없습니다.'%[GEAR.affix_text(crystal_item),P.item_title(item)]
	confirm.ok_button_text='8 정수로 이식';confirm.cancel_button_text='결정 보관'
	confirm.min_size=Vector2i(480,230)
	main.add_child(confirm)
	confirm.confirmed.connect(func():
		var result: Dictionary=main._gear_apply_crystal(crystal_id,item_id,hero_id,slot)
		if bool(result.get('ok',false)):_refresh_detail(main,item_id,hero_id,slot,'implant')
		_result(main,result);confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

static func crystal(main: Node, crystal_id: String) -> void:
	main._build_equipment_detail(crystal_id,'','','implant')

static func _crystal_targets(main: Node, page: Node, item: Dictionary) -> void:
	var crystal_id := str(item.get('id',''))
	var targets: Array=[]
	for candidate: Dictionary in main.loot_inventory:
		if str(candidate.get('item_type','equipment'))=='equipment':targets.append({'item':candidate,'hero_id':'','slot':'','label':'가방 · '+P.item_title(candidate)})
	for hero: Dictionary in main._hero_roster_for_faction():
		var hero_id := str(hero.get('id',''))
		for slot: String in ['weapon','armor','accessory']:
			var target: Dictionary=main._gear_item('',hero_id,slot)
			if not target.is_empty():targets.append({'item':target,'hero_id':hero_id,'slot':slot,'label':main._hero_short_name(hero_id)+' · '+main._equipment_slot_name(slot)+' · '+P.item_title(target)})
	var choose := P.card(page,'이식할 장비 선택')
	if targets.is_empty():
		P.text(choose,'가방에 장비를 보관하거나 영웅의 장비를 확인해 주세요.',18,S.MUTED)
		return
	var selection := _selection(choose,'CrystalTargetSelection')
	var selected_id := str(main.get_meta('crystal_target_item_id',''))
	for target: Dictionary in targets:
		selection.add_item(str(target['label']))
		if str(target['item'].get('id',''))==selected_id:selection.select(selection.item_count-1)
	selection.item_selected.connect(func(index: int):
		main.set_meta('crystal_target_item_id',str(targets[index]['item'].get('id','')))
		main._build_equipment_detail(crystal_id,'','','implant'))
	var target: Dictionary=targets[selection.selected]
	P.text(choose,'옵션 %d / %d칸 · %s'%[(target['item'].get('affixes',[]) as Array).size(),GEAR.option_capacity(target['item']),str(target['item'].get('set','초보자'))],17,S.MUTED)
	_crystal_apply_panel(main,page,target['item'],[item],str(target['hero_id']),str(target['slot']))
