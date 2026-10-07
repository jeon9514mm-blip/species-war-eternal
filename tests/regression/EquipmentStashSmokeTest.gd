extends 'res://tests/support/V83UpgradeTestBase.gd'
const VIEW=preload('res://scripts/equipment/EquipmentStashView.gd')
class CountingStore extends SaveStore:
	var writes:=0
	var fail:=false
	func write_save(path: String, data: Dictionary) -> Dictionary:
		writes+=1
		return {'ok':false,'status':'stash_injected_failure'} if fail else super.write_save(path,data)
var main: Node
var counter: CountingStore
var timings: Array=[]
func _init() -> void:run.call_deferred()
func node(named: String) -> Node:return main.content_root.find_child(named,true,false)
func item(id: String, index:=0) -> Dictionary:
	var value: Dictionary=main.GEAR.normalize({'id':id,'name':'보관 검증 %04d'%index,'slot':['weapon','armor','accessory'][index%3],
		'rarity':['일반','희귀','전설'][index%3],'level':3,'origin':'raid','source_id':'gray_meadow',
		'locked':index%2==0,'bound':index%4==0,'set':'초보자','affixes':[{'stat':'attack_pct','value':5}]})
	if index%5==0:
		value=main.GEAR.normalize({'id':id,'item_type':'option_crystal','name':'선택 옵션 결정','rarity':'희귀','locked':true,
			'bound':false,'origin':'legacy','stored_option':{'stat':'attack_pct','value':5}})
	return value
func fixture(count: int) -> void:
	main.equipment_overflow=[];main.loot_inventory=[]
	for i: int in count:main.equipment_overflow.append(item('stash-%04d'%i,i))
	main.set_meta('stash_filters',{});main.set_meta('stash_selected',{});main.set_meta('stash_page',0)
func state() -> Dictionary:
	return {'bag':main.loot_inventory.duplicate(true),'stash':main.equipment_overflow.duplicate(true),
		'gold':main.wallet_gold,'gems':main.wallet_gems,'rng':main.loot_rng.state,'writes':counter.writes}
func batch_rules() -> void:
	fixture(4)
	for ids: Array in [[],['stash-0000','stash-0000'],['stash-0000','missing'],[3],['']]:
		var before:=state();check(not main._gear_claim_overflow_many(ids).ok and state()==before,'invalid or stale batch is atomic '+str(ids))
	for barrier: String in ['pending','practice','future']:
		if barrier=='pending':main.set_meta('game_save_pending',true)
		if barrier=='practice':main.set_meta('practice_active',true)
		if barrier=='future':main._save_blocked_for_newer_version=true
		var before:=state();check(not main._gear_claim_overflow_many(['stash-0000']).ok and state()==before,'save barrier blocks claim '+barrier)
		main.set_meta('game_save_pending',false);main.set_meta('practice_active',false);main._save_blocked_for_newer_version=false
	main.equipment_overflow.append(main.equipment_overflow[0].duplicate(true))
	var before:=state();check(not main._gear_claim_overflow_many(['stash-0000']).ok and state()==before,'duplicate stash IDs cannot clone items')
	main.equipment_overflow.pop_back();main.loot_inventory.append(main.equipment_overflow[0].duplicate(true))
	before=state();check(not main._gear_claim_overflow_many(['stash-0000']).ok and state()==before,'already owned ID rejected before any mutation')
	main.loot_inventory=[]
	var equipped: Dictionary=main._gear_item('','leonhardt','weapon')
	main.equipment_overflow.append(equipped.duplicate(true));before=state()
	check(not main._gear_claim_overflow_many([str(equipped.id)]).ok and state()==before,'equipped ID rejected before mutation')
	fixture(3)
	for i: int in 199:main.loot_inventory.append(item('bag-%03d'%i,i))
	before=state();check(not main._gear_claim_overflow_many(['stash-0000','stash-0001']).ok and state()==before,'batch exceeding free capacity rejects all selected items')
	check(main._gear_claim_overflow('stash-0000').ok and main.loot_inventory.size()==200,'single claim shares the capacity guard')
	before=state();check(not main._gear_claim_overflow('stash-0001').ok and state()==before,'full bag claim preserves recovery items')
	fixture(200)
	var original: Array=main.equipment_overflow.duplicate(true);var ids: Array=[]
	for i: int in range(199,-1,-1):ids.append(str(original[i].id))
	var writes: int=counter.writes;var gold: int=main.wallet_gold;var rng: int=main.loot_rng.state
	var result: Dictionary=main._gear_claim_overflow_many(ids)
	check(result.ok and result.count==200 and main.loot_inventory.size()==200 and main.equipment_overflow.is_empty(),'200 selected items fit exactly')
	check(counter.writes==writes+1,'one batch uses one save snapshot')
	check(main.wallet_gold==gold and main.loot_rng.state==rng,'claim does not consume currency or RNG')
	for i: int in 200:check(main.loot_inventory[i]==original[199-i],'metadata and requested order survive batch '+str(i))
	before=state();check(not main._gear_claim_overflow_many(ids).ok and state()==before,'replayed batch never grants items twice')
	main._load_idle_state();check(main.loot_inventory.size()==200 and main.equipment_overflow.is_empty(),'disk reload preserves claimed items once')
	for i: int in 200:check(main.loot_inventory[i]==original[199-i],'disk reload retains locked, bound and option metadata '+str(i))
func touch(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.position=root.get_final_transform()*point;event.pressed=down;Input.parse_input_event(event)
func press(named: String) -> void:
	var button: Button=node(named);check(button!=null,'control exists '+named)
	if button==null:return
	var ancestor:=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await settle();check(button.is_visible_in_tree() and not button.disabled,'touch control enabled '+named)
	check(main.get_viewport_rect().encloses(button.get_global_rect()),'touch control fits viewport '+named)
	touch(button.get_global_rect().get_center());await settle()
func ui_rules() -> void:
	fixture(3200);main._build_equipment_stash();await settle()
	for index: int in [0,37,79]:
		main.set_meta('stash_page',index);var start:=Time.get_ticks_usec();main._build_equipment_stash()
		timings.append({'items':3200,'page':index,'build_ms':(Time.get_ticks_usec()-start)/1000.0});await settle()
		check(node('EquipmentStashView').visible_ids.size()==40,'large stash shows one bounded page '+str(index))
		check(node('StashItem_stash-%04d'%(index*40))!=null and node('StashItem_stash-%04d'%(index*40+39))!=null,'requested page IDs are reachable '+str(index))
	main.set_meta('stash_page',0);main._build_equipment_stash();await settle();await press('StashSelect_stash-0000')
	check(main.get_meta('stash_selected').has('stash-0000'),'touch selects one item once')
	check(node('StashSelect_stash-0000').text=='✓ 선택됨','selected item has a visible text marker')
	await press('StashPageNext');check(node('StashItem_stash-0040')!=null and main.get_meta('stash_selected').has('stash-0000'),'selection survives page changes')
	await press('StashSelect_stash-0040');await press('StashClaimSelected')
	check(main.loot_inventory.size()==2 and main.equipment_overflow.size()==3198,'cross-page touch selection receives exactly two items')
	fixture(41);main.set_meta('stash_page',1);main._build_equipment_stash();await settle();await press('StashClaim_stash-0040')
	check(main.get_meta('stash_page')==0 and node('EquipmentStashView').visible_ids.size()==40,'last-page claim clamps page safely')
	fixture(105);main._build_equipment_stash();await settle();var view=node('EquipmentStashView')
	view._filter('type','crystal');await settle()
	check(node('EquipmentStashView').rows.size()==21,'crystal filter includes every matching item across pages')
	view=node('EquipmentStashView');view._filter('lock','locked');await settle()
	check(node('EquipmentStashView').rows.size()==21,'lock filter preserves protected crystals')
	view=node('EquipmentStashView');view._filter('query','NO MATCH');await settle()
	check(node('EquipmentStashView').rows.is_empty() and node('StashClaimSelected').disabled,'empty search has no accidental claim')
	await press('StashFilterReset');await press('StashSelect_stash-0001')
	view=node('EquipmentStashView');view._filter('rarity','전설');await settle()
	check(main.get_meta('stash_selected').is_empty(),'changing filters clears hidden selections')
	for entry: Dictionary in node('EquipmentStashView').rows:check(str(entry.rarity)=='전설','rarity filter matches all rows')
	fixture(80)
	for i: int in 198:main.loot_inventory.append(item('bag-%03d'%i,i))
	main._build_equipment_stash();await settle();await press('StashSelectFree')
	check(main.get_meta('stash_selected').size()==2,'free-slot selection uses actual capacity')
	await press('StashClaimSelected');check(main.loot_inventory.size()==200 and node('StashClaimSelected').disabled,'batch touch fills only the free slots')
	check(node('StashClaim_stash-0002').disabled and node('StashSelectFree').disabled,'full bag disables direct and free-slot claims')
	fixture(80);main._build_equipment_stash();await settle()
	var scroll: ScrollContainer=node('PortraitContentScroll')
	var point: Vector2=node('StashClaim_stash-0000').get_global_rect().get_center()
	var before_drag:=state()
	var start:=InputEventScreenTouch.new();start.position=root.get_final_transform()*point;start.pressed=true;Input.parse_input_event(start)
	var drag:=InputEventScreenDrag.new();drag.position=root.get_final_transform()*(point+Vector2(0,-72));drag.relative=root.get_final_transform().basis_xform(Vector2(0,-72));Input.parse_input_event(drag)
	var release:=InputEventScreenTouch.new();release.position=drag.position;release.pressed=false;Input.parse_input_event(release);await settle()
	check(scroll.scroll_vertical>0 and state()==before_drag,'drag starting on a claim scrolls without receiving or saving')
	scroll.scroll_vertical=0;await settle()
	start.position=root.get_final_transform()*point;Input.parse_input_event(start)
	release.position=start.position;release.canceled=true;Input.parse_input_event(release);await settle()
	check(state()==before_drag,'OS-canceled claim touch cannot move equipment')
	await press('StashClaim_stash-0000');check(main.loot_inventory.size()==1 and main.equipment_overflow.size()==79,'next touch works once after scrolling and cancellation')
	fixture(4);main._build_equipment_stash();await settle();await press('StashSelectPage');await press('StashSelectPage')
	check(main.get_meta('stash_selected').is_empty(),'page selection toggles without moving items')
	await press('StashSelectPage');counter.fail=true;await press('StashClaimSelected')
	check(SAFETY.pending(main) and main.loot_inventory.size()==4 and main.equipment_overflow.is_empty(),'failed batch save retains awarded items in memory')
	var before:=state();check(not main._gear_claim_overflow_many(['stash-0000']).ok and state()==before,'pending save prevents repeated awards')
	counter.fail=false;check(SAFETY.retry(main),'retry saves current snapshot without claiming again')
	check(main.loot_inventory.size()==4 and main.equipment_overflow.is_empty(),'retry retains one copy of all selected items')
	fixture(50);main._build_equipment_stash();await settle()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(640,360),Vector2i(1920,1080)]:
		root.size=dimensions;await settle();main._build_equipment_stash();await settle()
		var list: Control=node('PortraitContentScroll');var toolbar: Control=node('StashToolbar');var pager: Control=node('StashPager')
		check(main.get_viewport_rect().encloses(toolbar.get_global_rect()) and main.get_viewport_rect().encloses(pager.get_global_rect()),'fixed actions fit screen '+str(dimensions))
		check(not toolbar.get_global_rect().intersects(list.get_global_rect()) and not pager.get_global_rect().intersects(list.get_global_rect()),'fixed actions do not overlap scrolling list '+str(dimensions))
		for named: String in ['StashSelectPage','StashSelectFree','StashClearSelection','StashClaimSelected','StashPageNext']:
			check(node(named).size.y>=44,'touch target size '+named)
		for named: String in ['StashSearchApply','StashFilterReset','StashSelectPage','StashSelectFree','StashClearSelection','StashClaimSelected']:
			var button: Button=node(named)
			var text_width: float=button.get_theme_font('font').get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size('font_size')).x
			var padding: float=button.get_theme_stylebox('normal').get_minimum_size().x
			check(button.size.x>=text_width+padding,'action label stays readable '+named+' '+str(dimensions))
		check(node('StashSelectionStatus').size.x>=320 and not node('StashSelectionStatus').text.is_empty(),'selected count and free capacity stay visible '+str(dimensions))
	root.size=Vector2i(1280,720);await settle();fixture(80);main._build_combat_screen();await settle();main.combat_running=true
	var battle: Dictionary={'hp':main.hero_battle_state.duplicate(true),'wave':main.enemy_wave.duplicate(true),'clock':main.invasion.clock}
	main._build_equipment_stash();await settle();await press('StashClaim_stash-0000')
	check(main.hero_battle_state==battle.hp and main.enemy_wave==battle.wave and main.invasion.clock==battle.clock,'opening and claiming stash preserve the active hunt')
	await press('PortraitMenuBack');check(main.active_screen=='inventory','stash back returns to bag management')
	check(node('GearStashShortcut').is_visible_in_tree(),'nonempty stash has a contextual shortcut in the bag')
	await press('GearStashShortcut');check(main.active_screen=='equipment_stash','bag shortcut opens stash in one touch')
	main.equipment_overflow=[];main._build_inventory_screen();await settle()
	check(not node('GearStashShortcut').visible,'empty stash does not add an unnecessary bag action')
	main.equipment_overflow.append(item('late-reward',1));node('EquipmentWorkbench')._process(0)
	check(node('GearStashShortcut').visible,'new background delivery reveals the shortcut without reopening the bag')
func run() -> void:
	Input.set_use_accumulated_input(false);Input.emulate_mouse_from_touch=true
	main=await make_main('aurelia',3);root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await settle()
	counter=CountingStore.new();main.save_store=counter
	batch_rules();await ui_rules()
	print('STASH_TIMINGS '+JSON.stringify(timings))
	await dispose(main);done('equipment_stash')
