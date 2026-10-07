extends "res://tests/support/V83UpgradeTestBase.gd"
## Actual ten-hero navigation, live search focus and read-only comparisons.
const RULES=preload('res://scripts/equipment/EquipmentRules.gd')
const COMPARE=preload('res://scripts/equipment/EquipmentComparison.gd')
var main: Node
func _init() -> void:run.call_deferred()
func node(named: String) -> Node:return main.content_root.find_child(named,true,false)
func press(named: String) -> void:
	var button: Button=node(named);check(button!=null,'exists '+named)
	if button==null:return
	var parent: Node=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(button)
		parent=parent.get_parent()
	await settle()
	check(root.get_visible_rect().encloses(button.get_global_rect()),'on-screen '+named)
	var motion:=InputEventMouseMotion.new();motion.position=button.get_global_rect().get_center();root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=motion.position;event.pressed=down;root.push_input(event,true)
	await settle()
func run() -> void:
	main=await make_main('aurelia',10);root.size=Vector2i(1280,720);await settle()
	main.loot_inventory=[]
	for i in 200:
		main.loot_inventory.append(RULES.normalize({'id':'ux-%03d'%i,'name':'월광 검' if i%2==0 else '강철 장비','slot':main.EQUIPMENT_SLOTS[i%3],'level':1+i%10,'rarity':'희귀','set':'월광' if i%2==0 else '강철'}))
	main._build_inventory_screen();await settle()
	var before:=economic(main);var party: Array=main._deployed_hero_ids().duplicate()
	check(node('GearInventoryGrid').columns==5 and node('GearBagCapacity').text=='200 / 200','five-column real 200-slot bag')
	for slot: String in main.EQUIPMENT_SLOTS:
		var control: Control=node('GearLoadout_'+slot)
		check(control.get_global_rect().end.y<=node('PortraitNavigation').get_global_rect().position.y,'every slot filter stays above navigation')
	for hero: Dictionary in main.deployed_heroes:
		await press('GearQuickHero_'+str(hero.id))
		check(str(main.get_meta('gear_equip_hero_id'))==str(hero.id),'quick switch selects correct hero')
		var selector: OptionButton=node('GearBagHero')
		check(str(selector.get_item_metadata(selector.selected))==str(hero.id),'quick switch synchronizes regular selector')
		check(economic(main)==before and main._deployed_hero_ids()==party,'browsing never equips, spends or changes party')
	main._build_inventory_screen();await settle()
	var last: String=str(main.deployed_heroes[9].id)
	check(node('EquipmentHeroScroll').get_global_rect().encloses(node('GearQuickHero_'+last).get_global_rect()),'reopening reveals remembered tenth hero without another swipe')
	await press('GearPageNext');await press('GearPageNext');await press('GearPageNext');await press('GearPageNext')
	var search: LineEdit=node('GearSearch');search.grab_focus();search.text='월광';search.caret_column=2;search.text_changed.emit(search.text)
	await create_timer(.3).timeout;await settle()
	check(node('GearSearch')==search and search.has_focus() and search.caret_column==2,'debounced search preserves field, keyboard focus and caret')
	check(node('GearPageLabel').text=='1 / 3','live search resets and clamps pages for 100 matches')
	check('100개' in node('GearInventoryCount').text,'live query displays exact match count')
	for tile: Node in node('GearInventoryGrid').get_children():check(int(str(tile.get_meta('equipment_id')).trim_prefix('ux-'))%2==0,'visible tiles match live query')
	search.text='없는 장비';search.text_changed.emit(search.text);await create_timer(.3).timeout;await settle()
	check(node('EquipmentEquip').disabled and node('GearOpenDetails').disabled,'no matches disables stale item actions')
	search.text='';search.text_changed.emit('');await create_timer(.3).timeout;await settle()
	check('200개' in node('GearInventoryCount').text,'clearing query restores every owned item')
	var sort: OptionButton=node('GearFilter_sort')
	for index in sort.item_count:
		if sort.get_item_metadata(index)=='set':sort.select(index);sort.item_selected.emit(index);break
	await settle()
	var rows: Array=preload('res://scripts/portrait/PortraitPages.gd')._inventory_rows(main,main.get_meta('gear_bag_filters',{}))
	for i in range(1,rows.size()):check(str(rows[i-1].item.set)<=str(rows[i].item.set),'set sort groups actual sets')
	check(COMPARE.delta_text(100,107)=='↑ +7 (+7.0%)','relative equipment power is accurate')
	check(COMPARE.delta_text(13,22,true)=='↑ +9%p','percentage affixes use percentage points')
	check(COMPARE.affix_totals([{'stat':'hp_pct','value':6},{'stat':'hp_pct','value':8}]).hp_pct==14,'repeated affixes compare their sum, not the final option')
	check(COMPARE.delta_text(0,8)=='신규 +8' and COMPARE.delta_text(100,90)=='↓ -10 (-10.0%)','zero baseline and loss stay honest')
	check(economic(main)==before,'all search, sort and comparisons remain read-only')
	main._build_combat_screen();await settle()
	for hero: Dictionary in main.deployed_heroes:
		check(node('Portrait_'+str(hero.id))!=null,'hunting uses the actual hero portrait')
	await dispose(main);done('equipment_v28_ux')
