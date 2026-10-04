extends Control
## UI state is device-local metadata. Only the command service moves equipment.
const P=preload('res://scripts/portrait/PortraitPages.gd')
const S=preload('res://scripts/portrait/PortraitSkin.gd')
const M=preload('res://scripts/portrait/PortraitMenus.gd')
const SAFETY=preload('res://scripts/SaveSafety.gd')
const PAGE_SIZE=40
var game: Node
var rows: Array[Dictionary]=[]
var visible_ids: Array[String]=[]
var selected: Dictionary={}
var checks: Dictionary={}
var claims: Array[Button]=[]
var selection_label: Label
var receive: Button
var select_page: Button
var select_free: Button
var clear_selection: Button
var elapsed:=0.0

static func build(main: Node) -> void:
	if main.active_screen!='equipment_stash':main.set_meta('stash_selected',{})
	var detail: String='가방 초과 장비 배송 · 최대 3,000통 · 만료 없음 · 수령 시 우편 삭제'
	var pending: int=preload('res://scripts/EquipmentMailService.gd').pending_count(main)
	if pending>0:detail+=' · 장비 탐색 %d회 배송 대기'%pending
	if main.equipment_overflow.size()>main.GEAR_OVERFLOW_CAP:detail+=' · 기존 초과분 보존'
	var page:=P.begin(main,'equipment_stash','장비 우편함',detail,'bag')
	var view: Control=load('res://scripts/EquipmentStashView.gd').new()
	view.name='EquipmentStashView';main.content_root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	view.install(main,page)

func _button(parent: Node, caption: String, callback: Callable, named: String, primary:=false) -> Button:
	var button:=P.action(parent,caption,callback,primary)
	button.name=named;button.custom_minimum_size.y=52
	button.add_theme_font_size_override('font_size',18)
	var text_width: float=button.get_theme_font('font').get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	button.custom_minimum_size.x=maxf(108,text_width+button.get_theme_stylebox('normal').get_minimum_size().x+8)
	return button

func _choice(parent: Node, key: String, choices: Array) -> void:
	var choice:=OptionButton.new();choice.name='StashFilter_'+key
	choice.custom_minimum_size=Vector2(160,52);choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	choice.clip_text=true;choice.mouse_filter=Control.MOUSE_FILTER_PASS
	choice.add_theme_font_size_override('font_size',17);parent.add_child(choice);M.retint(choice)
	var filters: Dictionary=game.get_meta('stash_filters',{})
	for entry: Array in choices:
		choice.add_item(str(entry[1]));choice.set_item_metadata(choice.item_count-1,entry[0])
		if str(filters.get(key,'all'))==str(entry[0]):choice.select(choice.item_count-1)
	choice.item_selected.connect(func(index: int):_filter(key,str(choice.get_item_metadata(index))))

func install(main: Node, page: VBoxContainer) -> void:
	game=main
	var existing: Dictionary={}
	for item: Dictionary in game.equipment_overflow:existing[str(item.get('id',''))]=true
	var saved: Variant=game.get_meta('stash_selected',{})
	if saved is Dictionary:
		for id in saved:
			if id is String and existing.has(id) and saved[id]==true:selected[id]=true
	game.set_meta('stash_selected',selected.duplicate())
	var filters: Dictionary=game.get_meta('stash_filters',{})
	for item: Dictionary in game.equipment_overflow:
		if _matches(item,filters):rows.append(item)
	var page_count:=maxi(1,ceili(float(rows.size())/PAGE_SIZE))
	var page_index:=clampi(int(game.get_meta('stash_page',0)),0,page_count-1)
	game.set_meta('stash_page',page_index)
	var toolbar:=VBoxContainer.new();toolbar.name='StashToolbar';toolbar.add_theme_constant_override('separation',8)
	add_child(toolbar);toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_left=20;toolbar.offset_right=-20;toolbar.offset_top=132
	var filter_row:=HBoxContainer.new();filter_row.add_theme_constant_override('separation',8);toolbar.add_child(filter_row)
	_choice(filter_row,'type',[['all','전체 종류'],['weapon','무기'],['armor','갑옷'],['accessory','장신구'],['crystal','옵션 결정']])
	_choice(filter_row,'rarity',[['all','전체 등급'],['일반','일반'],['희귀','희귀'],['전설','전설']])
	_choice(filter_row,'lock',[['all','전체 잠금'],['locked','잠금 장비'],['unlocked','잠금 없음']])
	var search:=LineEdit.new();search.name='StashSearch';search.text=str(filters.get('query',''))
	search.placeholder_text='이름 · 세트 검색';search.custom_minimum_size=Vector2(180,52)
	search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.add_theme_font_override('font',S.font())
	search.add_theme_font_size_override('font_size',17);filter_row.add_child(search)
	search.text_submitted.connect(func(value: String):_filter('query',value.strip_edges()))
	_button(filter_row,'검색',func():_filter('query',search.text.strip_edges()),'StashSearchApply').size_flags_horizontal=Control.SIZE_SHRINK_END
	_button(filter_row,'초기화',func():game.set_meta('stash_filters',{});_reset(),'StashFilterReset').size_flags_horizontal=Control.SIZE_SHRINK_END
	var actions:=HBoxContainer.new();actions.add_theme_constant_override('separation',8);toolbar.add_child(actions)
	select_page=_button(actions,'페이지 선택',_select_page,'StashSelectPage')
	select_free=_button(actions,'빈칸만큼 선택',_select_free,'StashSelectFree')
	clear_selection=_button(actions,'선택 해제',func():selected.clear();_remember();_refresh_selection(),'StashClearSelection')
	selection_label=P.text(actions,'',17,S.GOLD);selection_label.name='StashSelectionStatus'
	selection_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	selection_label.autowrap_mode=TextServer.AUTOWRAP_OFF;selection_label.custom_minimum_size=Vector2(320,52)
	selection_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	receive=_button(actions,'선택 받기',func():_claim(selected.keys()),'StashClaimSelected',true)
	for button: Button in [select_page,select_free,clear_selection,receive]:button.size_flags_horizontal=Control.SIZE_SHRINK_END
	var scroll: ScrollContainer=game.content_root.get_node('PortraitContentScroll')
	scroll.offset_top=256;scroll.offset_bottom=-176
	var back: Button=game.content_root.find_child('PortraitMenuBack',true,false)
	for connection: Dictionary in back.pressed.get_connections():back.pressed.disconnect(connection['callable'])
	back.pressed.connect(Callable(game,'_build_inventory_screen'));back.tooltip_text='가방으로 돌아가기'
	for offset: int in mini(PAGE_SIZE,rows.size()-page_index*PAGE_SIZE):
		var item: Dictionary=rows[page_index*PAGE_SIZE+offset]
		var id:=str(item.get('id',''));visible_ids.append(id)
		var box:=P.card(page);box.name='StashItem_'+id
		var row:=HBoxContainer.new();row.add_theme_constant_override('separation',12);box.add_child(row)
		var tick:=S.button('선택',func():_toggle(id));tick.name='StashSelect_'+id
		tick.toggle_mode=true;tick.custom_minimum_size=Vector2(112,52);tick.set_pressed_no_signal(selected.has(id))
		row.add_child(tick);checks[id]=tick
		var description:=P.stack(row,4);description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		P.text(description,P.item_title(item),20,S.GOLD)
		var kind: String='옵션 결정' if str(item.get('item_type','equipment'))=='option_crystal' else game._equipment_slot_name(str(item.get('slot','weapon')))
		var state: String=' · 잠금' if bool(item.get('locked',false)) else ''
		if bool(item.get('bound',false)):state+=' · 귀속'
		if str(item.get('set','초보자'))!='초보자':state+=' · '+str(item.set)
		if str(item.get('item_type','equipment'))=='equipment':state+=' · 장비력 %d'%int(item.get('power',0))
		P.text(description,'%s · %s%s'%[item.get('rarity','일반'),kind,state],16,S.MUTED)
		P.text(description,game.GEAR.affix_text(item),16,S.BLUE_SOFT)
		var mail: Dictionary=preload('res://scripts/EquipmentMailService.gd').header(item,game.equipment_mail_headers.get(id))
		var sent: String=Time.get_datetime_string_from_unix_time(int(mail.sent_at)).replace('T',' ') if int(mail.sent_at)>0 else '기존 장비 이관 · 날짜 미상'
		P.text(description,'%s · %s · %s'%[mail.sender,mail.title,sent],15,S.MUTED)
		var claim:=_button(row,'가방으로 받기',func():_claim([id]),'StashClaim_'+id,true)
		claim.custom_minimum_size.x=156;claim.size_flags_horizontal=Control.SIZE_SHRINK_END;claims.append(claim)
	if rows.is_empty():
		P.text(P.card(page),'도착한 장비 우편이 없습니다.' if game.equipment_overflow.is_empty() else '조건에 맞는 장비가 없습니다. 검색·필터를 초기화해 보세요.',18,S.MUTED)
	var footer:=HBoxContainer.new();footer.name='StashPager';footer.add_theme_constant_override('separation',10)
	add_child(footer);footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left=20;footer.offset_right=-20;footer.offset_top=-164;footer.offset_bottom=-112
	var previous:=_button(footer,'‹ 이전',func():_page(page_index-1),'StashPagePrevious');previous.size_flags_horizontal=Control.SIZE_SHRINK_END;previous.disabled=page_index==0
	var status:=P.text(footer,'%d / %d페이지 · 검색 %d개 / 우편 %d / 3,000통'%[page_index+1,page_count,rows.size(),game.equipment_overflow.size()],17)
	status.tooltip_text='장비 1개당 우편 1통. 가방에서 장비를 정리하면 대기 중인 장비 배송과 사냥이 재개됩니다.'
	status.name='StashPageStatus';status.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var next:=_button(footer,'다음 ›',func():_page(page_index+1),'StashPageNext');next.size_flags_horizontal=Control.SIZE_SHRINK_END;next.disabled=page_index==page_count-1
	_button(footer,'새로고침',func():game._build_equipment_stash(),'StashRefresh').size_flags_horizontal=Control.SIZE_SHRINK_END
	_refresh_selection()

func _matches(item: Dictionary, filters: Dictionary) -> bool:
	var type:=str(filters.get('type','all'))
	var crystal: bool=str(item.get('item_type','equipment'))=='option_crystal'
	if type=='crystal' and not crystal:return false
	if type in ['weapon','armor','accessory'] and (crystal or str(item.get('slot',''))!=type):return false
	var rarity:=str(filters.get('rarity','all'))
	if rarity in ['일반','희귀','전설'] and str(item.get('rarity','일반'))!=rarity:return false
	var lock:=str(filters.get('lock','all'))
	if lock=='locked' and not bool(item.get('locked',false)):return false
	if lock=='unlocked' and bool(item.get('locked',false)):return false
	var query:=str(filters.get('query','')).strip_edges().to_lower()
	return query.is_empty() or (str(item.get('name',''))+' '+str(item.get('set',''))).to_lower().contains(query)

func _filter(key: String, value: String) -> void:
	var filters: Dictionary=game.get_meta('stash_filters',{}).duplicate()
	filters[key]=value;game.set_meta('stash_filters',filters);_reset()

func _reset() -> void:
	game.set_meta('stash_selected',{});game.set_meta('stash_page',0)
	game.content_root.get_node('PortraitContentScroll').scroll_vertical=0
	game._build_equipment_stash()

func _page(index: int) -> void:
	game.set_meta('stash_page',index)
	game.content_root.get_node('PortraitContentScroll').scroll_vertical=0
	game._build_equipment_stash()

func _remember() -> void:game.set_meta('stash_selected',selected.duplicate())

func _toggle(id: String) -> void:
	if selected.has(id):selected.erase(id)
	elif selected.size()<game.INVENTORY_CAP:selected[id]=true
	_remember();_refresh_selection()

func _select_page() -> void:
	var all_selected: bool=not visible_ids.is_empty()
	for id: String in visible_ids:all_selected=all_selected and selected.has(id)
	for id: String in visible_ids:
		if all_selected:selected.erase(id)
		elif selected.size()<game.INVENTORY_CAP:selected[id]=true
	_remember();_refresh_selection()

func _select_free() -> void:
	selected.clear()
	for i: int in mini(maxi(0,game.INVENTORY_CAP-game.loot_inventory.size()),rows.size()):selected[str(rows[i].id)]=true
	_remember();_refresh_selection()

func _refresh_selection() -> void:
	var free: int=maxi(0,game.INVENTORY_CAP-game.loot_inventory.size())
	var error: String=SAFETY.mutation_error(game)
	selection_label.text='선택 %d개 · 빈칸 %d개%s'%[selected.size(),free,' · 빈칸 부족' if selected.size()>free else '']
	selection_label.tooltip_text=error if not error.is_empty() else selection_label.text
	receive.disabled=selected.is_empty() or selected.size()>free or not error.is_empty()
	select_free.disabled=free==0 or rows.is_empty()
	select_page.disabled=visible_ids.is_empty();clear_selection.disabled=selected.is_empty()
	for id in checks:
		checks[id].set_pressed_no_signal(selected.has(id))
		checks[id].text='✓ 선택됨' if selected.has(id) else '선택'
	for button: Button in claims:button.disabled=free==0 or not error.is_empty()

func _claim(ids: Array) -> void:
	var host:=game
	var result: Dictionary=host._gear_claim_overflow_many(ids)
	if bool(result.get('ok',false)):
		for id in ids:selected.erase(id)
		_remember()
	host._build_equipment_stash()
	host._show_toast(str(result.get('reason','')))

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed<.2 or not is_instance_valid(game):return
	elapsed=0.0;_refresh_selection()
