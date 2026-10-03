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
	if not ok:failures.append(message);push_error('V54 equipment UI: '+message)
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
func fixture(id: String, origin: String = 'hunt') -> Dictionary:
	return RULES.normalize({'id':id,'name':'달잠 숲의 별빛을 담은 전설 사냥검','slot':'weapon','level':3,'rarity':'전설','origin':origin,'source_id':'moonrest_forest','set':'월식의 추격' if origin=='raid' else '월광'})
func run() -> void:
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
	main=preload('res://scenes/PortraitMain.tscn').instantiate();main.save_state_path='user://v54-equipment-ui.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main.set_process(false);main._offline_checked=true;main.combat_effects_enabled=false
	main.selected_faction='aurelia';main.idle_stage=25;main.party_slot_legacy_cap=10
	main.deployed_heroes=main._hero_roster_for_faction().slice(0,3)
	main.wallet_gold=10000;main.raid_crystals=200
	main.gear_market_state={};main._gear_market_loaded=false
	main.loot_inventory=[fixture('ui_gear')];main.equipment_overflow=[fixture('ui_overflow','raid')]
	main._build_inventory_screen();await settle();layout('inventory')
	await press('GearTile_ui_gear')
	check(main.active_screen=='inventory','item selection keeps comparison workbench open')
	await press('GearOpenDetails')
	check(node('GearOrigin')!=null and str(RULES.ZONES['moonrest_forest']['name']) in node('GearOrigin').text,'bag shows item source and source zone')
	check(node('GearSetEffect')!=null and '2세트' in node('GearSetEffect').text and '3세트' in node('GearSetEffect').text,'bag explains both set thresholds')
	await press('EquipmentToggleLock')
	check(bool(main._gear_item('ui_gear').get('locked',false)),'real lock action updates original item')
	check(node('EquipmentSell').disabled,'locked item cannot be listed')
	check(node('EquipmentDecompose').disabled,'locked item cannot be dismantled')
	await press('EquipmentToggleLock')
	await press('DetailTab_options')
	check(main.active_screen=='equipment_detail','bag opens item-specific workshop')
	layout('workshop')
	var before: int=main.raid_crystals
	await press('WorkshopPreview')
	check(main.raid_crystals==before-12,'preview consumes displayed currency once')
	check(main._gear_item('ui_gear')['proposal']['options'].size()==2,'first assault proposal offers two options')
	var proposal: Dictionary=main._gear_item('ui_gear')['proposal'].duplicate(true)
	main._build_inventory_screen();await settle()
	await press('GearTile_ui_gear')
	check(main.active_screen=='inventory','item selection keeps comparison workbench open')
	await press('GearOpenDetails')
	check(node('EquipmentDecompose').disabled,'pending proposal prevents accidental dismantling')
	main._build_equipment_workshop('ui_gear');await settle()
	check(main._gear_item('ui_gear')['proposal']==proposal,'leaving/reopening retains paid proposal')
	await press('WorkshopChoose0')
	check(main.raid_crystals==before-12 and main._gear_item('ui_gear')['affixes'].size()==1,'choice adds option without charging twice')
	before=main.raid_crystals
	await press('WorkshopRemove0')
	var confirmation: ConfirmationDialog=main.get_node_or_null('EquipmentRemoveConfirmation')
	check(confirmation!=null and confirmation.visible,'removal presents explicit currency confirmation')
	check(main.raid_crystals==before,'opening confirmation does not spend')
	if confirmation!=null:
		await respond(confirmation,false)
	check(main.raid_crystals==before and main._gear_item('ui_gear')['affixes'].size()==1,'cancel preserves option and currency')
	await press('WorkshopRemove0')
	confirmation=main.get_node_or_null('EquipmentRemoveConfirmation')
	if confirmation!=null:await respond(confirmation,true)
	check(main.raid_crystals==before-6 and main._gear_item('ui_gear')['affixes'].is_empty(),'confirmed delete spends six and removes only selected option')
	check(main._gear_item('ui_gear')['focus']==1,'deletion visibly earns focus')
	main.raid_crystals=0;main._build_equipment_workshop('ui_gear');await settle()
	check(node('WorkshopPreview').disabled,'zero currency disables preview actions')
	main.raid_crystals=200
	main._build_inventory_screen();await settle()
	await press('GearSettingsToggle')
	await press('OpenEquipmentStash')
	layout('stash')
	await press('StashClaim_ui_overflow')
	check(main.equipment_overflow.is_empty() and not main._gear_item('ui_overflow').is_empty(),'stash action returns exact protected item to bag')
	main._build_inventory_screen();await settle()
	check(node('EquipmentOverlay')==null,'return from stash closes the bag management overlay')
	await press('GearTile_ui_overflow')
	await press('GearOpenDetails')
	await press('EquipmentDecompose')
	confirmation=main.get_node_or_null('EquipmentDecomposeConfirmation')
	check(confirmation!=null and '복구' in confirmation.dialog_text,'raid dismantle asks for explicit destructive confirmation')
	if confirmation!=null:await respond(confirmation,false)
	check(not main._gear_item('ui_overflow').is_empty(),'cancel dismantle retains exact raid equipment')
	main._build_equipment_detail('ui_gear');await settle()
	await press('EquipmentSell')
	check(main.active_screen=='equipment_market','item trade action opens market')
	check(node('EquipmentMarketConnection')!=null and '온라인 서버 연결 후' in node('EquipmentMarketConnection').text,'market explicitly explains local connection limit')
	layout('market')
	var price: SpinBox=node('MarketSalePrice');price.value=240
	root.size=Vector2i(1440,810);await settle()
	check(node('MarketSalePrice')==price and price.value==240,'live resize preserves entered sale price')
	await press('MarketList')
	confirmation=main.get_node_or_null('EquipmentTradeConfirmation')
	check(confirmation!=null and '228' in confirmation.dialog_text,'sale confirmation displays 5% fee and exact expected proceeds')
	check(not main._gear_item('ui_gear').is_empty(),'opening sale confirmation keeps item in bag')
	if confirmation!=null:await respond(confirmation,true)
	var snapshot: Dictionary=main._market_snapshot()
	var active: Array=[]
	for listing: Dictionary in snapshot.get('own_listings',[]):
		if listing.get('status')=='active':active.append(listing)
	check(active.size()==1 and main._gear_item('ui_gear').is_empty(),'real registration escrows one item')
	if not active.is_empty():
		var listing_id: String=str(active[0]['id'])
		check(int(active[0]['price'])==240,'registration uses entered price')
		await press('MarketCancel_'+listing_id)
		snapshot=main._market_snapshot()
		check(snapshot['account']['deliveries'].size()==1,'cancel returns exact item to delivery')
		check(node('MarketCancel_'+listing_id)==null,'closed listing cannot be cancelled again')
		await press('MarketClaim_ui_gear')
		check(not main._gear_item('ui_gear').is_empty() and main._market_snapshot()['account']['deliveries'].is_empty(),'delivery action claims equipment exactly once')
	# The test alone adds a second isolated account to verify the buyer UI. The
	# production market never seeds NPCs, sellers, money or fabricated offers.
	var remote: Dictionary=main.gear_market_service.bootstrap_account('ui_seller',1000,[fixture('ui_offer')],'UI 검증 판매자','player')
	check(bool(remote.get('ok',false)),'isolated seller fixture accepted')
	var offer: Dictionary=main.gear_market_service.submit('ui_seller',{'action':'list','item_id':'ui_offer','price':200,'request_id':'ui_offer_register'},int(Time.get_unix_time_from_system()))
	check(bool(offer.get('ok',false)),'isolated offer registered through transaction service')
	var offer_id: String=str(offer.get('listing_id',''))
	main._build_equipment_market();await settle()
	var old_gold: int=main.wallet_gold
	await press('MarketBuy_'+offer_id)
	confirmation=main.get_node_or_null('EquipmentTradeConfirmation')
	check(confirmation!=null and '귀속' in confirmation.dialog_text,'purchase confirmation explains irreversible binding')
	if confirmation!=null:await respond(confirmation,false)
	check(main.wallet_gold==old_gold,'cancel purchase spends no gold')
	await press('MarketBuy_'+offer_id)
	confirmation=main.get_node_or_null('EquipmentTradeConfirmation')
	if confirmation!=null:await respond(confirmation,true)
	check(main.wallet_gold==old_gold-200,'confirmed purchase consumes exact stated price')
	await press('MarketClaim_ui_offer')
	var bought: Dictionary=main._gear_item('ui_offer')
	check(not bought.is_empty() and bool(bought.get('bound',false)) and int(bought.get('trade_count',0))==1,'bought equipment arrives bound with its one allowed trade recorded')
	main._build_inventory_screen();await settle()
	await press('GearTile_ui_offer')
	await press('GearOpenDetails')
	check(node('EquipmentSell')!=null and node('EquipmentSell').disabled,'received traded gear cannot be relisted through bag')
	var hero_id: String=str(main.deployed_heroes[0]['id'])
	main._build_hero_detail_screen(hero_id);await settle();layout('equipped detail')
	var worn: Dictionary=main._gear_item('',hero_id,'weapon')
	await press('GearTile_'+str(worn['id']))
	await press('DetailTab_options')
	check(main.active_screen=='equipment_detail','worn equipment opens workshop with hero/slot context')
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,810),Vector2i(1560,720)]:
		root.size=dimensions;await settle()
		for screen: String in ['inventory','workshop','market','stash']:
			match screen:
				'inventory':main._build_inventory_screen()
				'workshop':main._build_equipment_workshop('ui_gear')
				'market':main._build_equipment_market()
				'stash':main._build_equipment_stash()
			await settle();layout(screen+' '+str(dimensions))
		main._build_raid_screen();await settle()
		var reward: Label=node('PortraitRaidEquipmentRewards')
		var start: Button=node('PortraitRaidStart')
		check(reward!=null and '세트 1개 확정' in reward.text,'raid preview advertises actual equipment reward')
		var raid_options: Button=node('RaidOptionsButton')
		if raid_options!=null:
			click(raid_options.get_global_rect().get_center());await settle()
		var reward_scroll: Node=reward.get_parent()
		while reward_scroll!=null and not reward_scroll is ScrollContainer:reward_scroll=reward_scroll.get_parent()
		if reward_scroll!=null:reward_scroll.ensure_control_visible(reward);await settle()
		check(reward.is_visible_in_tree() and main.get_viewport_rect().encloses(reward.get_global_rect()),'raid reward is reachable inside current information sheet')
		check(not reward.get_global_rect().intersects(start.get_global_rect()),'raid reward and start button do not overlap')
		check(not start.get_global_rect().intersects(node('PortraitRaidParty').get_global_rect()),'raid start and party do not overlap')
	main.presentation_runtime.audio.shutdown();await create_timer(.3).timeout
	main._clear_screen();main.free();await settle()
	print('V54 EQUIPMENT UI ',checks-failures.size(),'/',checks,' PASS')
	quit(0 if failures.is_empty() else 1)
