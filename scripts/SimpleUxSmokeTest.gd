extends 'res://scripts/V83UpgradeTestBase.gd'
var main: Node
func _init() -> void:run.call_deferred()
func node(named: String) -> Node:return main.content_root.find_child(named,true,false)
func touch(point: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=root.get_final_transform()*point;event.pressed=down;Input.parse_input_event(event)
func press(named: String) -> void:
	var target: Button=node(named);check(target!=null,'button exists '+named)
	if target==null:return
	var ancestor:=target.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(target)
		ancestor=ancestor.get_parent()
	await settle()
	check(target.is_visible_in_tree() and not target.disabled,'available '+named)
	touch(target.get_global_rect().get_center());await settle()
func battle() -> Dictionary:
	return {'hp':main.hero_battle_state.duplicate(true),'wave':main.enemy_wave.duplicate(true),'clock':main.invasion.clock,'gold':main.wallet_gold,'gems':main.wallet_gems,'running':main.combat_running}
func run() -> void:
	Input.set_use_accumulated_input(false);Input.emulate_mouse_from_touch=true
	main=await make_main('aurelia',10);main.tutorial_completed=true
	root.size=Vector2i(1280,720);await settle();main._build_combat_screen();await settle();main.combat_running=true
	var snapshot:=battle()
	check(main.portrait_hud.quest_label.get_parent()==main.portrait_hud and not main.portrait_hud.quest_label.text.is_empty(),'home goal stays visible after building collapsed options')
	check(node('HuntOptionsSheet')!=null and not node('HuntOptionsSheet').visible,'secondary hunt commands collapsed at start')
	check(not node('PortraitSkillAuto').is_visible_in_tree() and not node('HuntSettings').is_visible_in_tree(),'settings and skill switches do not crowd the hunting home')
	await press('PortraitDetailsButton')
	check(node('HuntOptionsSheet').visible,'touch opens hunt controls')
	for named: String in ['HuntOptionsClose','PortraitSkillAuto','PortraitUltimateAuto']:
		check(node('HuntOptionsPanel').get_global_rect().encloses(node(named).get_global_rect()),'hunt control fits its panel '+named)
	var automatic: bool=main.skill_auto
	await press('PortraitSkillAuto');check(main.skill_auto!=automatic,'skill switch acts once through a real touch')
	await press('PortraitSkillAuto');check(main.skill_auto==automatic,'skill switch restores independent setting')
	var close_position: Vector2=node('HuntOptionsClose').global_position
	node('HuntOptionsScroll').scroll_vertical=int(node('HuntOptionsScroll').get_v_scroll_bar().max_value);await settle()
	check(node('HuntOptionsClose').global_position==close_position,'hunt close stays visible while options scroll')
	await press('HuntOptionsClose');check(battle()==snapshot,'closing controls preserves battle and wallet')
	await press('LandscapeMenuButton')
	check(node('MenuFeaturedCards')!=null and node('MenuIconGrid')!=null,'menu restores illustrated cards and icon shortcuts')
	for entry: Dictionary in preload('res://scripts/NavigationCatalog.gd').menu_entries():check(node('PortraitMenu_'+str(entry.id))!=null,'destination retained '+str(entry.id))
	check(node('MenuGroup_battle')==null,'group tabs removed from restored menu')
	await press('PortraitMenu_party');check(main.active_screen=='hero_select','party route opens the actual formation editor')
	await press('PortraitNav_home');check(main.active_screen=='combat','hunting tab returns directly to hunt')
	await press('PortraitNav_battle');check(main.active_screen=='meta_hub' and node('ContentTab_raids').disabled,'challenge tab opens raid choices instead of restarting hunt')
	main.set_meta('content_meta_tab','quests');main._show_main_menu();await settle();await press('PortraitMenu_growth')
	check(str(main.get_meta('content_meta_tab'))=='daily','dungeon menu cannot restore an unrelated goal screen')
	main._build_boss_select_screen();await settle()
	await press('ContentTab_daily');check(node('DungeonDetailCard')!=null and not node('PracticeOpen').is_visible_in_tree(),'challenge starts with real content; practice tools collapsed')
	await press('Disclosure_연습 · 전투 설정');check(node('PracticeOpen').is_visible_in_tree(),'optional practice tools remain reachable')
	await press('PortraitNav_bag');check(main.active_screen=='inventory','bag route retained')
	await press('EquipmentBagBack');check(main.active_screen=='combat','bag back returns directly to hunting')
	await press('LandscapeMenuButton')
	await press('PresentationSettingsEntry');check(node('PresentationSettingsOverlay')!=null and node('PortraitActionSheet')==null,'settings opens with one modal')
	await press('PresentationClose')
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(640,360),Vector2i(1920,1080)]:
		root.size=dimensions;await settle();main._show_main_menu();await settle()
		var menu=node('PortraitActionSheet');check(main.get_viewport_rect().grow(1).encloses(menu.pane.get_global_rect()),'menu fits '+str(dimensions))
		var visible_rects: Array[Rect2]=[]
		for button: Button in menu.pane.find_children('*','Button',true,false):
			if not button.is_visible_in_tree():continue
			check(button.size.y>=44,'phone target at least 44px '+button.name)
			var rect:=button.get_global_rect()
			for other: Rect2 in visible_rects:check(not rect.intersects(other),'menu buttons do not overlap')
			visible_rects.append(rect)
		await press('PortraitMenuClose');check(node('PortraitActionSheet')==null,'close dismisses menu after resize')
	await dispose(main);done('simple_ux')
