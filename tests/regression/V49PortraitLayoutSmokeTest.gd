extends SceneTree
## Inspect engine-shaped text and actual container geometry, including offscreen
## rows. Scrolling may hide content vertically; it must never hide content width.
var main: Node
var checks:=0
var failures: Array[String]=[]
var screens:=0
func _init() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error('V49 layout: '+message)
func settle() -> void:
	for i in 8:await process_frame
func controls(node: Node, result: Array) -> void:
	if node is Control and node.is_visible_in_tree():result.append(node)
	for child in node.get_children():controls(child,result)
func audit(label: String, scope: Node = null) -> void:
	screens+=1
	var nodes: Array=[]
	controls(main.content_root if scope==null else scope,nodes)
	var viewport: Rect2=main.get_viewport_rect()
	for node: Control in nodes:
		if not (node is Label or node is Button) or node.text.is_empty():continue
		var rectangle:=node.get_global_rect()
		var parent:=node.get_parent()
		var horizontal_scroll:=false
		var vertical_scroll:=false
		var clip:=viewport
		while parent is Control:
			if parent is ScrollContainer:
				horizontal_scroll=horizontal_scroll or parent.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED
				vertical_scroll=true
			if parent.clip_contents:clip=clip.intersection(parent.get_global_rect())
			parent=parent.get_parent()
		var name: String=label+' · '+node.text.left(32)
		if not horizontal_scroll:
			check(rectangle.position.x>=clip.position.x-1 and rectangle.end.x<=clip.end.x+1,name+' fits content width')
		if not vertical_scroll:
			check(viewport.grow(1).encloses(rectangle),name+' fits viewport')
		var font: Font=node.get_theme_font('font')
		var size: int=node.get_theme_font_size('font_size')
		if node is Label:
			check(node.get_line_count()*node.get_line_height()<=node.size.y+2 or (node.max_lines_visible>0 and node.tooltip_text==node.text),name+' full text height')
			if node.autowrap_mode==TextServer.AUTOWRAP_OFF and not node.clip_text and node.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING:
				check(font.get_multiline_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=node.size.x+1,name+' full text width')
		elif node is Button and not node is OptionButton:
			var style:=node.get_theme_stylebox('normal')
			var width:=font.get_multiline_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+style.get_content_margin(SIDE_LEFT)+style.get_content_margin(SIDE_RIGHT)
			check(width<=node.size.x+1,name+' button caption visible')
		# Compare sibling text rectangles, ignoring empty icon-only buttons and
		# intended parent/child overlays such as portrait badges.
		for other in node.get_parent().get_children():
			if other==node or not (other is Label or other is Button) or not other.is_visible_in_tree() or other.text.is_empty():continue
			if other.get_index()<=node.get_index():continue
			var overlap:=rectangle.intersection(other.get_global_rect())
			check(overlap.size.x<=3 or overlap.size.y<=3,name+' separated from '+other.text.left(24))
	var scroll: ScrollContainer=main.content_root.get_node_or_null('PortraitContentScroll')
	if scope==null and scroll!=null:
		check(is_equal_approx(scroll.get_child(0).scale.x,1.0),label+' no text scaling')
		check(scroll.get_child(0).size.x<=scroll.size.x+1,label+' one column fits scroll width')
func button(caption: String) -> Button:
	var nodes: Array=[];controls(main.content_root,nodes)
	for node in nodes:
		if node is Button and node.text==caption:return node
	return null
func press(caption: String) -> void:
	var target:=button(caption)
	check(target!=null,'action exists '+caption)
	if target!=null:
		check(not target.disabled,'action enabled '+caption)
		target.pressed.emit()
	await settle()
func fixture(faction: String) -> void:
	main.selected_faction=faction;main.idle_stage=35;main.current_zone_id='gray_meadow'
	main.wallet_gold=987654321;main.wallet_gems=87654321
	main.deployed_heroes=main._hero_roster_for_faction().slice(0,10)
	main._setup_hero_progress(main._hero_roster_for_faction())
	for hero in main._hero_roster_for_faction():main.hero_progress[str(hero['id'])]={'level':30,'xp':120}
func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v49-layout.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main._offline_checked=true
	main.combat_effects_enabled=false;main.tutorial_completed=true
	for faction in ['aurelia','noxfera']:
		fixture(faction)
		main.loot_inventory=[{'id':'layout-item','name':'오래된 왕국의 전설적인 수호자의 검','slot':'weapon','rarity':'전설','level':10,'set':'월광'}]
		for dims in [Vector2i(720,1280),Vector2i(720,1560),Vector2i(810,1440)]:
			root.size=dims;await settle()
			for method in ['_build_title_screen','_build_login_screen','_build_faction_screen','_build_intro_screen','_build_lobby_screen','_build_hero_select_screen','_build_growth_screen','_build_inventory_screen','_build_meta_hub_screen','_build_summon_screen','_build_world_map_screen','_build_boss_select_screen','_build_codex_screen','_build_bm_screen','_build_combat_screen','_build_raid_screen','_build_faction_war_screen']:
				main.call(method);await settle();audit(faction+' '+str(dims)+' '+method)
			main._build_hero_detail_screen(str(main.deployed_heroes[0]['id']))
			await settle();audit('hero detail '+str(dims))
			var names: Array[String]=[]
			for hero in main.deployed_heroes:names.append(str(hero['name']))
			main._build_party_ready_screen(names);await settle();audit('ready '+str(dims))
			main._build_combat_screen();await settle();main._show_main_menu();await settle()
			audit('menu '+str(dims),main.content_root.get_node('PortraitActionSheet'))
			main._show_main_menu();await settle()
			check(main.content_root.find_children('PortraitActionSheet','',false,false).size()==1,'one action sheet')
			main._build_raid_screen();await settle()
			main.raid_last_result='토벌 완료 · '+('긴 전투 결과를 확인하세요. '.repeat(16))
			main.content_root.get_node('PortraitRaidView').refresh();await settle();audit('raid long result '+str(dims))
			main._show_battle_result_popup('RAID CLEAR','오래된 광산의 거대한 수호자 처치 완료','골드 +123456789\n'+('전투 보상 상세 내용 '.repeat(45)),Color.GOLD)
			await settle();audit('battle popup '+str(dims),main.content_root.get_node('BattleResultPopup'))
			main._build_lobby_screen();await settle()
			main.offline_reward_seconds=28800;main.offline_reward_gold=123456789
			main._show_offline_reward_popup();await settle();audit('offline popup '+str(dims),main.content_root.get_node('OfflineRewardPopup'))
			main._build_summon_screen();await settle()
			main._show_summon_reveal({'hero_id':str(main.deployed_heroes[0]['id']),'name':str(main.deployed_heroes[0]['name']),'shards':30})
			await settle();audit('summon popup '+str(dims),main.content_root.get_node('SummonRevealPanel'))
	# First-run/empty states and transient effects use the same readable shell.
	fixture('aurelia');main.deployed_heroes.clear();main.loot_inventory.clear();main.idle_stage=1
	root.size=Vector2i(720,1280);await settle()
	for method in ['_build_lobby_screen','_build_hero_select_screen','_build_inventory_screen','_build_codex_screen','_build_growth_screen']:
		main.call(method);await settle();audit('empty/locked '+method)
	fixture('aurelia');main._build_combat_screen();await settle()
	main.combat_effects_enabled=true
	main._emit_boss_telegraph('오래된 광산 수호자의 광역 붕괴 공격',3.0)
	await settle();audit('boss warning',main.content_root.get_node('BossTelegraphWarning'))
	main._show_battle_result_popup('STAGE CLEAR','스테이지 35 돌파','골드 +9999 · 경험치 +8888',Color.GOLD)
	await settle();audit('field result',main.content_root.get_node('BattleResultPopup'))
	main._build_raid_screen();await settle();main._start_raid()
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	main._advance_raid_encounter(.3)
	var raid_hp: float=main.raid_boss_hp;var raid_elapsed: float=main.raid_elapsed
	main._emit_ultimate_cutin('leonhardt','원정대 10명 보호막 · 공격력과 방어력을 강화합니다.')
	await settle();audit('raid ultimate',main.content_root.get_node('PortraitUltimateNotice'))
	for dims in [Vector2i(720,1560),Vector2i(720,1280)]:
		root.size=dims;await settle();audit('live raid resize '+str(dims))
		check(main.raid_boss_hp==raid_hp and main.raid_elapsed==raid_elapsed and main.raid_running,'raid resize preserves encounter')
	main.combat_effects_enabled=false
	main._build_lobby_screen();await settle();main._show_main_menu();await settle()
	for dims in [Vector2i(900,1600),Vector2i(720,1280)]:
		root.size=dims;await settle();audit('open sheet resize '+str(dims),main.content_root.get_node('PortraitActionSheet'))
	for method in ['_build_title_screen','_build_faction_screen']:
		main.call(method);await settle();root.size=Vector2i(810,1440);await settle()
		audit('resized '+method)
		check(main.content_root.get_node_or_null('PortraitNavigation')==null,'entry screen does not gain navigation on resize')
	# Exercise real callbacks after previous views have been freed.
	fixture('aurelia');root.size=Vector2i(720,1280);await settle()
	main._build_hero_select_screen();await settle()
	main._build_hero_detail_screen('leonhardt');await settle()
	await press('배치 해제')
	check(not main._is_hero_deployed('leonhardt'),'detail removes hero after leaving roster without stale labels')
	await press('원정대에 배치')
	check(main._is_hero_deployed('leonhardt'),'detail deploys the same hero')
	main.hero_skill_tree['leonhardt']={'offense':0,'survival':0,'utility':0}
	main._build_growth_screen();await settle()
	var upgrade: Button=main.content_root.find_child('GrowthBranch_offense',true,false)
	check(upgrade!=null and not upgrade.disabled,'offense research action enabled')
	if upgrade!=null:upgrade.pressed.emit()
	await settle()
	check(main._get_skill_tree('leonhardt')['offense']==1,'training button spends one point on intended hero')
	main._build_summon_screen();await settle()
	var gems: int=main.wallet_gems
	await press('소환하기 · 100 젬')
	check(main.wallet_gems==gems-100,'summon invokes existing price exactly once')
	check(main.content_root.get_node_or_null('SummonRevealPanel')!=null,'summon opens visible result')
	main.loot_inventory=[{'id':'action-item','name':'장착 검','slot':'weapon','rarity':'전설','level':10,'set':'월광'}]
	main._build_inventory_screen();await settle()
	var item_id: String=main.loot_inventory[0]['id']
	var tile: Button=main.content_root.find_child('GearTile_'+item_id,true,false)
	check(tile!=null,'equipment tile uses displayed ID')
	if tile!=null:tile.pressed.emit()
	await settle();audit('selected equipment details')
	var equip: Button=main.content_root.find_child('EquipmentEquip',true,false)
	check(equip!=null and not equip.disabled,'selected equipment can be equipped')
	if equip!=null:equip.pressed.emit()
	await settle()
	var kept:=false
	for item in main.loot_inventory:kept=kept or item.get('id','')==item_id
	check(not kept,'equipment selector and equip action use the displayed item ID')
	main._build_lobby_screen();await settle()
	main.unclaimed_gold=100;main.unclaimed_xp=10
	main.offline_pending_gold=100;main.offline_pending_xp=10
	main._build_lobby_screen();await settle()
	var before: int=main.wallet_gold
	await press('오프라인 사냥 받기')
	var confirm: Button=main.content_root.find_child('DialogConfirm',true,false)
	check(confirm!=null and confirm.text=='오프라인 사냥 받기','lobby opens offline receipt')
	if confirm!=null:confirm.pressed.emit()
	check(main.wallet_gold==before+100 and main.unclaimed_gold==0,'lobby offline receipt remains one-time')
	main.presentation_runtime.audio.shutdown();await create_timer(.5).timeout
	main._clear_screen();main.free();await create_timer(.35).timeout
	print('V49 LAYOUT ',checks-failures.size(),'/',checks,' PASS · ',screens,' screen states')
	quit(0 if failures.is_empty() else 1)
