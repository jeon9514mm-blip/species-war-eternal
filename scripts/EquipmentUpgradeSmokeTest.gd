extends SceneTree
## Real UI input and exact transaction results, not a mirrored UI implementation.
const RULES=preload('res://scripts/EquipmentRules.gd')
const C=preload('res://scripts/EquipmentComparison.gd')
const P=preload('res://scripts/portrait/PortraitPages.gd')
var main: Node
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error('Equipment upgrade: '+message)
func settle() -> void:
	for i in 8:await process_frame
func node(label: String) -> Node:return main.content_root.find_child(label,true,false)
func click(label: String) -> void:
	var button: Button=node(label)
	check(button!=null,'control exists '+label)
	if button==null:return
	var parent: Node=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(button)
		parent=parent.get_parent()
	await settle()
	check(not button.disabled,'enabled '+label)
	check(main.get_viewport_rect().encloses(button.get_global_rect()),'reachable '+label)
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=down;root.push_input(event,true)
	await settle()
func fixture(id: String, slot: String='weapon', level: int=8, set_name: String='초보자') -> Dictionary:
	return RULES.normalize({'id':id,'name':'비교 장검 '+id,'slot':slot,'level':level,'rarity':'전설','set':set_name,'affixes':[{'stat':'attack_pct','value':6}]})
func run() -> void:
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
	main=load('res://scenes/PortraitMain.tscn').instantiate();main.save_state_path='user://equipment-upgrade-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(main);await settle();main.set_process(false);main.set_physics_process(false);main._offline_checked=true;main.combat_effects_enabled=false
	main.selected_faction='aurelia';main.idle_stage=30;main.deployed_heroes=main._hero_roster_for_faction().slice(0,3);main.wallet_gold=30000
	var hero_id: String=main.deployed_heroes[0].id;main.set_meta('gear_equip_hero_id',hero_id)
	for slot: String in main.EQUIPMENT_SLOTS:
		var item:=fixture('current-'+slot,slot,3,'강철');item.rarity='희귀'
		main.hero_equipment_items.get_or_add(hero_id,{})[slot]=item
		main._get_hero_equipment(hero_id)[slot]=3;main._get_hero_equipment_rarity(hero_id)[slot]='희귀'
		main._get_hero_equipment_names(hero_id)[slot]=item.name;main._get_hero_equipment_sets(hero_id)[slot]='강철'
	main.loot_inventory=[fixture('candidate'),fixture('locked','armor'),fixture('restricted'),fixture('pending'),fixture('weak','accessory',1)]
	main.loot_inventory[1].locked=true;main.loot_inventory[2].hunt_role='support';main.loot_inventory[2].origin='hunt'
	main.loot_inventory[3].proposal={'family':'guard','options':[{'stat':'hp_pct','value':6}],'cost':12}
	var candidate: Dictionary=main._gear_item('candidate');var before: Dictionary=main._gear_item('',hero_id,'weapon').duplicate(true)
	var gold: int=main.wallet_gold;var inventory_before: Array=main.loot_inventory.duplicate(true)
	var preview:=C.preview(main,candidate,hero_id)
	check(int(preview.delta)==main._item_power(candidate)-main._item_power(before),'preview uses actual slot power')
	check(bool(preview.set_loss),'replacing three-piece set warns about lost defense')
	check('방어력' in C.change_text(preview.changes[0]),'lost set stat is explicitly identified')
	check(main.wallet_gold==gold and main.loot_inventory==inventory_before,'comparison spends no currency and moves no inventory')
	check(P._inventory_rows(main,{'query':'CANDIDATE'}).size()==1,'search is case insensitive')
	check(P._inventory_rows(main,{'query':'no-match'}).is_empty(),'unmatched search has no stale rows')
	check(P._inventory_rows(main,{'state':'locked'}).size()==1,'locked filter is exact')
	var usable:=P._inventory_rows(main,{'state':'usable'})
	for row: Dictionary in usable:check(str(row.item.id) not in ['restricted','pending'],'usable excludes wrong role and pending options')
	var power_rows:=P._inventory_rows(main,{'sort':'power'})
	for i in range(1,power_rows.size()):check(main._item_power(power_rows[i-1].item)>=main._item_power(power_rows[i].item),'power sort is descending')
	main.set_meta('gear_bag_selected_id','candidate');main._build_inventory_screen();await settle()
	check(node('GearBagHero')!=null and node('EquipmentCompareCurrent')!=null,'hero and current equipment are visible in bag')
	check(main.active_screen=='inventory' and node('EquipmentSetLossWarning')!=null,'set loss is displayed in inventory comparison')
	var scroll: ScrollContainer=node('PortraitContentScroll')
	check(not node('GearInventoryPager').get_global_rect().intersects(scroll.get_global_rect()),'pager never covers equipment')
	check(scroll.get_child(0).size.x<=scroll.size.x-12,'equipment leaves room for the scrollbar')
	await click('GearLoadout_weapon')
	check(main.get_meta('gear_bag_filters').slot=='weapon','current slot opens same-slot candidates')
	var search: LineEdit=node('GearSearch');search.text='candidate';search.text_submitted.emit(search.text);await settle()
	check(node('GearTile_candidate')!=null and node('GearTile_pending')==null,'submitted search updates actual visible tiles')
	await click('GearTile_candidate')
	check(main.active_screen=='inventory','selection keeps the inventory open')
	check(node('EquipmentCompareCurrent')!=null and node('EquipmentCompareCandidate')!=null,'current and replacement remain side by side')
	await click('GearQuickLock')
	check(bool(main._gear_item('candidate').locked) and node('GearTile_candidate').get_node('GearTileLock').visible,'lock immediately updates item and badge')
	await click('GearQuickLock')
	check(not bool(main._gear_item('candidate').locked) and not node('GearTile_candidate').get_node('GearTileLock').visible,'unlock immediately updates item and badge')
	await click('GearSource')
	check(node('EquipmentOverlay')!=null and node('GearSourceWorld')!=null,'source opens a usable overlay')
	await click('EquipmentOverlayClose')
	check(node('EquipmentOverlay')==null,'source overlay closes without leaving inventory')
	await click('GearSettingsToggle')
	var overlay_scroll: ScrollContainer=node('EquipmentOverlayScroll')
	check(overlay_scroll.get_child(0).size.x<=overlay_scroll.size.x-12,'management filters fit beside scrollbar')
	for control: Control in overlay_scroll.get_child(0).find_children('*','Button',true,false):
		check(control.get_global_rect().end.x<=overlay_scroll.get_global_rect().end.x-10,'management control does not clip '+str(control.name))
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true);await settle()
	check(node('EquipmentOverlay')==null and main.active_screen=='inventory','back closes management before leaving inventory')
	await click('EquipmentEquip')
	check(str(main._gear_item('',hero_id,'weapon').id)=='candidate','real equip changes exactly selected hero and slot')
	check(main._gear_item('current-weapon')==before,'displaced equipment and options are preserved')
	check(main.wallet_gold==gold,'equip spends no gold')
	check(bool(main._gear_item('',hero_id,'weapon').bound),'equipped candidate becomes bound')
	# A stale callback must never equip the item that shifted into its array index.
	main.loot_inventory=[fixture('stale'),fixture('remaining')];main.set_meta('gear_bag_filters',{});main.set_meta('gear_bag_selected_id','stale');main._build_inventory_screen();await settle()
	main.loot_inventory.remove_at(0);await click('EquipmentEquip')
	check(str(main._gear_item('',hero_id,'weapon').id)=='candidate' and not main._gear_item('remaining').is_empty(),'stale bag cannot equip a replacement array entry')
	await click('GearOpenDetails')
	check(main.active_screen=='equipment_detail' and str(main.gear_workshop_context.item_id)=='remaining','explicit detail action retains selected ID')
	await click('EquipmentDetailBack')
	check(main.active_screen=='inventory','detail returns to comparison bag')
	# Fill the bag to its real capacity and ensure all pages can be reached.
	main.loot_inventory=[]
	for i in 200:main.loot_inventory.append(fixture('full-%03d'%i,main.EQUIPMENT_SLOTS[i%3]))
	main.set_meta('gear_bag_filters',{'sort':'recent'});main._build_inventory_screen();await settle()
	check(node('GearBagCapacity').text=='200 / 200','real 200 capacity displayed')
	var visited: Dictionary={}
	for page in 5:
		for tile: Node in node('GearInventoryGrid').get_children():visited[str(tile.get_meta('equipment_id',''))]=true
		if page<4:await click('GearPageNext')
	check(visited.size()==200 and not visited.has(''),'every one of 200 IDs reachable across five pages')
	check(node('GearPageNext').disabled and node('GearPageLabel').text=='5 / 5','last page boundary is explicit')
	var draft: LineEdit=node('GearSearch');draft.text='아직 적용하지 않은 검색';draft.grab_focus();draft.caret_column=4
	root.size=Vector2i(1600,720);await settle()
	check(node('GearSearch').text=='아직 적용하지 않은 검색' and node('GearSearch').caret_column==4,'landscape resize preserves draft and caret')
	check(str(main.get_meta('gear_equip_hero_id'))==hero_id and node('GearPageLabel').text=='5 / 5','resize preserves hero and page')
	check(main.get_viewport_rect().encloses(node('EquipmentBagPanel').get_global_rect()),'wide layout keeps bag visible')
	# Crystals use the existing implantation transaction screen.
	main.loot_inventory=[fixture('target'),RULES.normalize({'id':'crystal','item_type':'option_crystal','stored_option':{'stat':'attack_pct','value':6}})]
	main.set_meta('gear_bag_filters',{'slot':'weapon','type':'equipment'});main.set_meta('gear_settings_open',true);main._build_inventory_screen();await settle()
	var kind: OptionButton=node('GearFilter_type')
	for index in kind.item_count:
		if str(kind.get_item_metadata(index))=='option_crystal':kind.select(index);kind.item_selected.emit(index);break
	await settle()
	check(main.get_meta('gear_bag_filters').slot=='all' and node('GearTile_crystal')!=null,'crystal type clears incompatible equipment slot filter')
	await click('EquipmentOverlayClose')
	check(node('EquipmentEquip').text=='이식' and node('GearWorkshop').disabled,'crystal uses implantation instead of equipment upgrade')
	await click('EquipmentEquip')
	check(main.active_screen=='equipment_detail' and str(main.gear_workshop_context.tab)=='implant','crystal opens implantation with exact ID')
	main.set_meta('gear_bag_filters',{'query':'missing'});main._build_inventory_screen();await settle()
	check(node('EquipmentEquip').disabled and node('GearOpenDetails').disabled,'empty search disables stale actions')
	main.loot_inventory[0].locked=true;main.set_meta('gear_bag_filters',{'state':'locked'});main._build_inventory_screen();await settle()
	await click('GearQuickLock')
	check(not bool(main._gear_item('target').locked) and node('GearTile_target')==null,'unlock immediately removes item from locked-only filter')
	check('0개' in node('GearInventoryCount').text,'locked filter count stays consistent with actual state')
	main.idle_stage=1
	var remembered: String=main._hero_roster_for_faction().back().id;main.set_meta('gear_equip_hero_id',remembered)
	main._build_inventory_screen();await settle()
	var hero_selection: OptionButton=node('GearBagHero')
	check(str(hero_selection.get_item_metadata(hero_selection.selected))==C.selected_hero(main),'visible selector and comparison retain same remembered hero')
	main.presentation_runtime.audio.shutdown();await create_timer(.3).timeout;main.free();await settle()
	print('equipment_upgrade checks=',checks,' failures=',failures)
	quit(0 if failures.is_empty() else 1)
