extends SceneTree
## Real landscape controls and mouse input, using the same Main transactions as
## play. This exercises persistence-safe proposals and escrow delivery actions.
const RULES=preload('res://scripts/EquipmentRules.gd')
var main: Node
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error('V54 crystal UI: '+message)
func settle() -> void:
	for frame in 8:await process_frame
func click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;root.push_input(event,true)
func respond(dialog: ConfirmationDialog, accept: bool) -> void:
	var target: Button=dialog.get_ok_button() if accept else dialog.get_cancel_button()
	check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),'confirmation fits viewport')
	click(Vector2(dialog.position)+target.get_global_rect().get_center());await settle()
func node(named: String) -> Node:
	return main.content_root.find_child(named,true,false)
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
func layout(label: String) -> void:
	var scroll: ScrollContainer=main.content_root.find_child('EquipmentDetailScroll',true,false)
	if scroll==null:scroll=main.content_root.find_child('PortraitContentScroll',true,false)
	if scroll==null:return
	check(main.get_viewport_rect().encloses(scroll.get_global_rect()),label+' scroll fits screen')
	var page: Control=scroll.get_child(0)
	check(page.size.x<=scroll.size.x+1,label+' has no horizontal overflow')
	for control: Control in page.find_children('*','Control',true,false):
		if not control.is_visible_in_tree():continue
		check(control.size.x<=scroll.size.x+1,label+' control width '+control.name)
		if control is Label:
			check(control.size.y+1>=control.get_minimum_size().y,label+' label natural height '+control.name)
		if control is Button:
			check(control.size.y>=44,label+' touch target '+control.name)
func fixture(id: String, source: String = 'hunt') -> Dictionary:
	return RULES.normalize({'id':id,'name':'별빛 옵션 실험 장비','slot':'weapon','level':3,'rarity':'전설','origin':source,'source_id':'moonrest_forest','set':'월식의 추격' if source=='raid' else '월광'})
func set_filter(key: String, value: String) -> void:
	var choice: OptionButton=node('GearFilter_'+key)
	check(choice!=null,'filter exists '+key)
	if choice==null:return
	for index in choice.item_count:
		if str(choice.get_item_metadata(index))==value:
			choice.select(index);choice.item_selected.emit(index);await settle();return
	check(false,'filter value exists '+key+' '+value)
func run() -> void:
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
	main=preload('res://scenes/PortraitMain.tscn').instantiate();main.save_state_path='user://v54-equipment-crystal-ui.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main.set_process(false);main._offline_checked=true;main.combat_effects_enabled=false
	main.selected_faction='aurelia';main.idle_stage=25;main.party_slot_legacy_cap=10
	main.deployed_heroes=main._hero_roster_for_faction().slice(0,2)
	main.wallet_gold=10000;main.raid_crystals=100
	main.gear_market_state={};main._gear_market_loaded=false;main.equipment_overflow=[]
	var source := fixture('crystal_source','raid');source['affixes']=[{'stat':'attack_pct','value':6},{'stat':'hp_pct','value':4}]
	var target := fixture('crystal_target');target['affixes']=[{'stat':'haste_pct','value':3}]
	var low := fixture('crystal_lower_quality');low['affixes']=[{'stat':'hp_pct','value':3}]
	main.loot_inventory=[source,target,low]
	main._build_inventory_screen();await settle();layout('compact bag')
	check(node('GearSettingsToggle')!=null and node('GearAutoEquip')==null,'automatic settings remain outside the initial comparison workbench')
	await press('GearSettingsToggle')
	check(node('EquipmentOverlay')!=null and node('GearAutoEquip').is_visible_in_tree(),'advanced management settings open in their own overlay')
	await set_filter('origin','hunt')
	check(node('GearTile_crystal_source')==null and node('GearTile_crystal_target')!=null,'source filter displays hunting items only')
	await set_filter('origin','all')
	await press('EquipmentOverlayClose')
	check(node('EquipmentOverlay')==null,'closing management returns unobstructed access to the bag')
	await set_filter('sort','quality')
	check(str(node('GearInventoryGrid').get_child(2).name)=='GearTile_crystal_lower_quality','quality sort places lower rolls after maximum rolls')
	await press('GearTile_crystal_source')
	check(main.active_screen=='inventory','source selection stays on the comparison workbench')
	await press('GearOpenDetails')
	check(node('GearOptionQuality')!=null and '100%' in node('GearOptionQuality').text,'max option quality is visible in selected equipment details')
	await press('DetailTab_options')
	layout('extraction workshop')
	await press('WorkshopExtract0')
	var dialog: ConfirmationDialog=main.get_node_or_null('EquipmentExtractConfirmation')
	check(dialog!=null and '원본 장비' in dialog.dialog_text and '18' in dialog.dialog_text,'extraction confirmation names the source mutation and cost')
	if dialog!=null:await respond(dialog,false)
	check(main.raid_crystals==100 and main._gear_item('crystal_source')['affixes'].size()==2,'cancel extraction changes no resource or option')
	await press('WorkshopExtract0')
	dialog=main.get_node_or_null('EquipmentExtractConfirmation')
	if dialog!=null:await respond(dialog,true)
	check(main.raid_crystals==82,'confirmed extraction spends exactly 18 essence')
	check(main._gear_item('crystal_source')['affixes']==[{'stat':'hp_pct','value':4}],'extraction removes only the selected source option')
	var crystal_id: String=''
	for item: Dictionary in main.loot_inventory:
		if str(item.get('item_type','equipment'))=='option_crystal':crystal_id=str(item['id'])
	check(not crystal_id.is_empty(),'extracted option is delivered as a distinct inventory item')
	if crystal_id.is_empty():main.free();quit(1);return
	var crystal: Dictionary=main._gear_item(crystal_id)
	check(crystal['stored_option']['stat']=='attack_pct' and int(crystal['stored_option']['value'])==6,'crystal preserves exact max-roll stat')
	main._build_inventory_screen();await settle()
	await press('GearCategory_crystal')
	check(node('GearTile_'+crystal_id)!=null and node('GearTile_crystal_target')==null,'crystal filter displays crystals without equipment controls')
	layout('crystal bag')
	await press('GearTile_'+crystal_id)
	check(node('EquipmentEquip').text=='이식','crystal comparison offers transplant as its primary action')
	check(node('GearWorkshop').disabled,'crystals cannot use normal equipment enhancement')
	await press('GearOpenDetails')
	check(node('DetailTab_enhance')==null and node('EquipmentDecompose')==null,'crystal detail offers neither normal enhancement nor dismantle actions')
	check('100%' in node('GearOptionQuality').text,'crystal quality is stated as maximum-roll percentage')
	await press('EquipmentSell')
	var price: SpinBox=node('MarketSalePrice');price.value=400
	await press('MarketList')
	dialog=main.get_node_or_null('EquipmentTradeConfirmation')
	if dialog!=null:await respond(dialog,true)
	var snapshot: Dictionary=main._market_snapshot()
	var listing_id: String=''
	for listing: Dictionary in snapshot['own_listings']:
		if str(listing['item'].get('id',''))==crystal_id:listing_id=str(listing['id'])
	check(not listing_id.is_empty() and main._gear_item(crystal_id).is_empty(),'crystal sale registration moves crystal into escrow')
	check(node('MarketTypeFilter')!=null,'market exposes equipment/crystal categories')
	await press('MarketCancel_'+listing_id)
	await press('MarketClaim_'+crystal_id)
	check(main._gear_item(crystal_id)['stored_option']['value']==6,'market cancellation and delivery preserve original option value')
	main.set_meta('crystal_target_item_id','crystal_target')
	main._build_option_crystal(crystal_id);await settle();await press('DetailTab_implant');layout('crystal detail')
	check('공격력 +6%' in node('CrystalApplyPreview').text and '공격 속도 +3%' in node('CrystalApplyPreview').text,'transplant preview shows retained and added options')
	var previous: Dictionary=main._gear_item('crystal_target').duplicate(true)
	await press('WorkshopApplyCrystal')
	dialog=main.get_node_or_null('EquipmentApplyConfirmation')
	if dialog!=null:await respond(dialog,false)
	check(main.raid_crystals==82 and main._gear_item('crystal_target')==previous,'cancel transplant preserves target and currency')
	await press('WorkshopApplyCrystal')
	dialog=main.get_node_or_null('EquipmentApplyConfirmation')
	if dialog!=null:await respond(dialog,true)
	check(main.raid_crystals==74 and main._gear_item(crystal_id).is_empty(),'transplant consumes exactly 8 essence and one crystal')
	var applied: Dictionary=main._gear_item('crystal_target')
	check(applied['affixes'].size()==2 and applied['affixes'][0]['stat']=='haste_pct' and applied['affixes'][1]['stat']=='attack_pct' and applied['affixes'][1]['value']==6,'transplant keeps existing effect and adds exact extracted roll')
	check(main.active_screen=='equipment_detail','successful transplant opens updated target workshop')
	# Reproduce a stale popup: the requested source option changes while open.
	main._build_equipment_workshop('crystal_target');await settle()
	await press('WorkshopExtract1')
	dialog=main.get_node_or_null('EquipmentExtractConfirmation')
	var changed: Dictionary=main._gear_item('crystal_target');changed['affixes'][1]['value']=5
	main._gear_update_item(changed)
	var before: int=main.raid_crystals
	if dialog!=null:await respond(dialog,true)
	check(main.raid_crystals==before and main._gear_item('crystal_target')['affixes'][1]['value']==5,'stale extraction confirmation cannot consume a changed option')
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,810),Vector2i(1560,720)]:
		root.size=dimensions;await settle()
		main.set_meta('gear_bag_filters',{});main._build_inventory_screen();await settle();layout('filtered bag '+str(dimensions))
		main._build_equipment_workshop('crystal_target');await settle();layout('extraction '+str(dimensions))
		main._build_equipment_market();await settle();layout('crystal market '+str(dimensions))
	main.presentation_runtime.audio.shutdown();await create_timer(.3).timeout
	main._clear_screen();main.free();await settle()
	print('V54 CRYSTAL UI ',checks-failures.size(),'/',checks,' PASS')
	quit(0 if failures.is_empty() else 1)
