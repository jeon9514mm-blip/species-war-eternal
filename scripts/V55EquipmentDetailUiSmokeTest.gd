extends SceneTree
## Real viewport input covers the compact inventory and one-item detail flow.
## Existing V54 tests retain workshop, crystal and escrow transaction coverage.
const RULES=preload('res://scripts/EquipmentRules.gd')
var main: Node
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error('V55 equipment detail: '+message)
func settle() -> void:
	for frame in 8:await process_frame
func node(named: String) -> Node:
	return main.content_root.find_child(named,true,false)
func click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;root.push_input(event,true)
func press(named: String) -> void:
	var target: Button=node(named)
	check(target!=null,'button exists '+named)
	if target==null:return
	var ancestor: Node=target.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(target)
		ancestor=ancestor.get_parent()
	await settle()
	check(not target.disabled,'action enabled '+named)
	check(main.get_viewport_rect().encloses(target.get_global_rect()),'action fits viewport '+named)
	click(target.get_global_rect().get_center());await settle()
func select_filter(key: String, value: String) -> void:
	var selection: OptionButton=node('GearFilter_'+key)
	check(selection!=null,'filter exists '+key)
	if selection==null:return
	for index in selection.item_count:
		if str(selection.get_item_metadata(index))==value:
			selection.select(index);selection.item_selected.emit(index);await settle();return
	check(false,'filter value exists '+value)
func tiles() -> Array[Button]:
	var result: Array[Button]=[]
	for candidate: Node in main.content_root.find_children('GearTile_*','Button',true,false):result.append(candidate)
	return result
func geometry(label: String, require_tiles_visible := false) -> void:
	var viewport: Rect2=main.get_viewport_rect()
	var scroll: ScrollContainer=node('PortraitContentScroll')
	check(scroll!=null,label+' has body scroll')
	if scroll==null:return
	check(viewport.grow(1).encloses(scroll.get_global_rect()),label+' body fits viewport')
	check(scroll.get_child(0).size.x<=scroll.size.x+1,label+' no horizontal body overflow')
	for control: Control in main.content_root.find_children('*','Control',true,false):
		if not control.is_visible_in_tree() or not (control is Label or control is Button):continue
		var rect:=control.get_global_rect()
		check(rect.position.x>=viewport.position.x-1 and rect.end.x<=viewport.end.x+1,label+' width '+str(control.name))
		if control is Label:
			check(control.get_line_count()*control.get_line_height()<=control.size.y+2 or (control.max_lines_visible>0 and control.tooltip_text==control.text),label+' readable text '+str(control.name))
		if control is Button:
			check(control.size.y>=48,label+' touch target '+str(control.name))
			if not control is OptionButton and not control.text.is_empty():
				var font: Font=control.get_theme_font('font')
				var style: StyleBox=control.get_theme_stylebox('normal')
				var caption_width: float=font.get_multiline_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size('font_size')).x+style.get_content_margin(SIDE_LEFT)+style.get_content_margin(SIDE_RIGHT)
				check(caption_width<=control.size.x+1,label+' button caption visible '+str(control.name))
			if str(control.name).begins_with('DetailTab_') or str(control.name).begins_with('GearPage'):
				check(viewport.grow(1).encloses(rect),label+' persistent action visible '+str(control.name))
				check(not rect.intersects(scroll.get_global_rect()) or str(control.name).begins_with('GearPage'),label+' tabs outside body '+str(control.name))
		for sibling in control.get_parent().get_children():
			if sibling==control or not (sibling is Label or sibling is Button) or not sibling.is_visible_in_tree() or sibling.get_index()<=control.get_index():continue
			if control.text.is_empty() or sibling.text.is_empty():continue
			var overlap:=rect.intersection(sibling.get_global_rect())
			check(overlap.size.x<=3 or overlap.size.y<=3,label+' sibling text separated '+str(control.name))
	if require_tiles_visible:
		check(tiles().size()<=12,label+' at most twelve equipment tiles')
		for tile: Button in tiles():
			check(scroll.get_global_rect().grow(1).encloses(tile.get_global_rect()),label+' tile visible without scrolling '+str(tile.name))
		check(scroll.scroll_vertical==0,label+' bag starts at top')
func fixture(id: String, slot := 'weapon', level := 3) -> Dictionary:
	return RULES.normalize({'id':id,'name':'아주 오래된 달잠 숲의 별빛을 모아 만든 전설의 수호 장비','slot':slot,'level':level,'rarity':'전설','origin':'raid','source_id':'moonrest_forest','set':'월식의 추격','affixes':[{'stat':'attack_pct','value':6}],'focus':2})
func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280);root.gui_embed_subwindows=true
	main=preload('res://scenes/PortraitMain.tscn').instantiate();main.save_state_path='user://v55-equipment-detail-ui.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main.set_process(false);main._offline_checked=true;main.combat_effects_enabled=false
	main.selected_faction='aurelia';main.idle_stage=25;main.party_slot_legacy_cap=10
	main.deployed_heroes=main._hero_roster_for_faction().slice(0,3)
	main.wallet_gold=50000;main.raid_crystals=300;main.gear_market_state={};main._gear_market_loaded=false;main.equipment_overflow=[]
	main.loot_inventory=[]
	for index in 30:main.loot_inventory.append(fixture('tile_%02d'%index,['weapon','armor','accessory'][index%3]))
	main.set_meta('gear_bag_filters',{});main.set_meta('gear_bag_page',0)
	main._build_inventory_screen();await settle()
	check(tiles().size()==12,'thirty items render only the first twelve tiles')
	check(node('GearInventoryGrid').columns==3,'inventory has three compact columns')
	check(node('GearPagePrevious').disabled and not node('GearPageNext').disabled,'first page boundaries are accurate')
	geometry('first inventory page',true)
	await press('GearPageNext');check(tiles().size()==12,'second inventory page has twelve items')
	await press('GearPageNext');check(tiles().size()==6,'last inventory page has the remaining six items')
	check(node('GearPageNext').disabled,'last inventory page cannot advance')
	var remembered_page: int=int(main.get_meta('gear_bag_page',0))
	var target_id: String=str(tiles()[0].name).trim_prefix('GearTile_')
	await press('GearTile_'+target_id)
	check(main.active_screen=='equipment_detail','one equipment tap opens dedicated item details')
	check(str(main.gear_workshop_context.get('item_id',''))==target_id,'detail retains selected stable item ID')
	for tab in ['info','enhance','options','implant']:check(node('DetailTab_'+tab)!=null,'detail exposes '+tab+' task')
	check(node('EquipmentEnhance')==null and node('WorkshopPreview')==null,'information tab contains no enhancement or workshop form')
	geometry('selected equipment information')
	await press('EquipmentDetailBack')
	check(int(main.get_meta('gear_bag_page',0))==remembered_page and node('GearTile_'+target_id)!=null,'viewing details returns to the same unchanged tile page')
	await press('GearTile_'+target_id)
	await press('DetailTab_enhance')
	check(node('EquipmentEquip')==null and node('WorkshopPreview')==null,'enhancement tab displays only the selected task')
	var identity: Control=node('EquipmentDetailIdentity')
	var identity_position: Vector2=identity.get_global_rect().position
	var before: Dictionary=main._gear_item(target_id).duplicate(true)
	var gold: int=main.wallet_gold
	var first_cost: int=main._inventory_upgrade_cost(before)
	await press('EquipmentEnhance')
	check(main.active_screen=='equipment_detail' and main.gear_workshop_context.get('tab')=='enhance','enhancement keeps selected equipment and tab open')
	check(main.wallet_gold==gold-first_cost and main._gear_item(target_id)['level']==int(before['level'])+1,'first enhancement debits exact visible-level cost')
	var second_cost: int=main._inventory_upgrade_cost(main._gear_item(target_id))
	await press('EquipmentEnhance')
	var enhanced: Dictionary=main._gear_item(target_id)
	check(main.wallet_gold==gold-first_cost-second_cost and enhanced['level']==int(before['level'])+2,'second enhancement uses updated level and cost')
	for field in ['id','affixes','origin','source_id','set','focus','rarity','bound','trade_count']:
		check(enhanced.get(field)==before.get(field),'consecutive enhancement preserves '+field)
	var body: ScrollContainer=node('PortraitContentScroll');body.scroll_vertical=1000;await settle()
	check(node('EquipmentDetailIdentity').get_global_rect().position==identity_position,'selected item identity stays fixed while task body scrolls')
	check(main.get_viewport_rect().encloses(node('DetailTab_info').get_global_rect()),'information tab remains accessible after body scroll')
	await press('EquipmentDetailBack')
	check(main.active_screen=='inventory' and int(main.get_meta('gear_bag_page',0))==remembered_page,'returning restores the previous inventory page')
	check(not main._gear_item(target_id).is_empty(),'enhanced equipment remains owned when its new power changes sorted position')
	await select_filter('slot','weapon')
	check(tiles().size()==10 and node('GearPageNext').disabled,'slot filter shows ten weapons on one valid page')
	check(int(main.get_meta('gear_bag_page',0))==0,'filter clamps an out-of-range previous page')
	await select_filter('slot','all')
	# Exercise the same worn equipment item across consecutive upgrades.
	main._build_equipment_detail(target_id);await settle();await press('EquipmentEquip')
	check(main._gear_item(target_id).is_empty(),'equipment leaves the bag after equipping')
	var hero_id: String=str(main.gear_workshop_context.get('hero_id',''))
	var target_slot: String=str(before['slot'])
	check(not hero_id.is_empty(),'equipping transfers detail context to its owner')
	var worn: Dictionary=main._gear_item(target_id,hero_id,target_slot)
	check(not worn.is_empty(),'worn details retain exact equipped item ID')
	await press('DetailTab_enhance')
	gold=main.wallet_gold;first_cost=main._inventory_upgrade_cost(worn)
	await press('EquipmentEnhance')
	check(main.wallet_gold==gold-first_cost and main._gear_item(target_id,hero_id,target_slot)['level']==int(worn['level'])+1,'worn enhancement uses selected hero and slot')
	check(main._gear_item(target_id,hero_id,target_slot)['affixes']==before['affixes'],'worn enhancement retains exact extracted-option source metadata')
	check(main.active_screen=='equipment_detail','worn enhancement does not reopen hero list')
	await press('EquipmentDetailBack')
	check(main.active_screen=='inventory','equipping from the bag retains its original return location')
	main._build_hero_detail_screen(hero_id);await settle()
	var hero_scroll: ScrollContainer=node('PortraitContentScroll')
	hero_scroll.ensure_control_visible(node('GearTile_'+target_id));await settle()
	var remembered_hero_scroll: int=hero_scroll.scroll_vertical
	check(remembered_hero_scroll>0,'hero equipment tile is reached below the initial hero summary')
	await press('GearTile_'+target_id)
	await press('EquipmentDetailBack')
	check(main.active_screen=='hero_detail','item opened from a hero returns to its owning hero')
	check(node('PortraitContentScroll').scroll_vertical==remembered_hero_scroll,'return restores the hero equipment scroll position')
	# Exhaustion and cap state have clear disabled actions; no resource mutation.
	main._build_equipment_detail(target_id,hero_id,target_slot,'enhance');await settle()
	main.wallet_gold=0;main._build_equipment_detail(target_id,hero_id,target_slot,'enhance');await settle()
	check(node('EquipmentEnhance').disabled,'insufficient gold disables enhancement')
	main.wallet_gold=50000
	var capped: Dictionary=main._gear_item(target_id,hero_id,target_slot);capped['level']=10;main.hero_equipment[hero_id][target_slot]=10;main._gear_update_item(capped,hero_id,target_slot)
	main._build_equipment_detail(target_id,hero_id,target_slot,'enhance');await settle()
	check(node('EquipmentEnhance').disabled,'maximum enhancement has no active spend button')
	# Physical small windows still use the production 720-wide canvas scaling.
	for dimensions: Vector2i in [Vector2i(320,568),Vector2i(360,640),Vector2i(720,1280),Vector2i(810,1440),Vector2i(720,1560)]:
		root.size=dimensions;await settle()
		main.set_meta('gear_bag_filters',{});main.set_meta('gear_bag_page',0)
		main._build_inventory_screen();await settle();geometry('inventory '+str(dimensions),true)
		var visible_id: String=str(tiles()[0].name).trim_prefix('GearTile_')
		await press('GearTile_'+visible_id)
		for tab: String in ['info','enhance','options','implant']:
			if tab!='info':await press('DetailTab_'+tab)
			geometry('detail '+tab+' '+str(dimensions))
			check(main.gear_workshop_context.get('item_id')==visible_id,'viewport resize/task switch retains selected item')
		await press('EquipmentDetailBack')
		check(main.active_screen=='inventory','detail back works at physical window '+str(dimensions))
	# Filter empty state remains navigable and does not retain stale tiles.
	await select_filter('type','option_crystal')
	check(tiles().is_empty(),'crystal filter does not show equipment')
	check(node('GearPagePrevious').disabled and node('GearPageNext').disabled,'empty filter has no invalid pagination')
	geometry('empty crystal category')
	main._clear_screen();main.free();await settle()
	print('V55 EQUIPMENT DETAIL UI ',checks-failures.size(),'/',checks,' PASS')
	quit(0 if failures.is_empty() else 1)
