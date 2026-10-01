extends SceneTree
## Inspect the actual portrait HUD, including live state and resize behavior.
var main: Node
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error('V52 hunt UI: '+message)
func settle() -> void:
	for frame in 6:await process_frame
func text_layout(node: Node, frame: Rect2) -> void:
	if node is Control and not node.is_visible_in_tree():return
	if node is Label and not node.text.is_empty():
		check(frame.grow(1).encloses(node.get_global_rect()),node.name+' text stays on screen')
		check(node.get_line_count()*node.get_line_height()<=node.size.y+2,node.text+' has full line height')
		if node.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING:
			var font: Font=node.get_theme_font('font')
			var width:=font.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size('font_size')).x
			check(width<=node.size.x+1,node.text+' fits its width')
		for sibling in node.get_parent().get_children():
			if sibling is Label and sibling.get_index()>node.get_index() and sibling.is_visible_in_tree():
				var overlap: Rect2=node.get_global_rect().intersection(sibling.get_global_rect())
				check(overlap.size.x<=2 or overlap.size.y<=2,node.text+' does not cover '+sibling.text)
	for child in node.get_children():text_layout(child,frame)
func run() -> void:
	root.content_scale_size=Vector2i(720,1280)
	root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v52-hunt-ui.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main._offline_checked=true
	main.selected_faction='aurelia';main.combat_effects_enabled=false
	main.wallet_gold=987654321;main.wallet_gems=87654321
	var roster: Array=main._hero_roster_for_faction()
	main._setup_hero_progress(roster)
	for count in [1,3,5,10]:
		main.party_slot_legacy_cap=count;main.idle_stage=1
		main.deployed_heroes=roster.slice(0,count)
		main._build_combat_screen()
		if is_instance_valid(main.combat_timer):main.combat_timer.stop()
		await settle()
		for dims: Vector2i in [Vector2i(720,1280),Vector2i(720,1440),Vector2i(720,1560),Vector2i(810,1440)]:
			var hp_before: Dictionary=main.hero_battle_state.duplicate(true)
			root.size=dims;await settle()
			var hud: Control=main.portrait_hud
			check(hp_before==main.hero_battle_state,'resize preserves current HP and statuses')
			check(hud.bars.size()==count,'one live card per deployed hero')
			check(hud.slot_row.size.y==(176 if count>5 else 84),'compact one-row party when no second row is unlocked')
			check(main._combat_camera_anchor().y<hud.auto_button.position.y-150,'party camera remains clear of bottom controls')
			var map: Control=hud.get_node('PortraitMapButton')
			check(map.get_rect().end.y<main._combat_camera_anchor().y-150,'map stays above active encounter')
			check(hud.get_node('PortraitQuestButton').get_global_rect().end.y<main._combat_camera_anchor().y-150,'quest stays above active encounter')
			check(hud.auto_button.position.y-map.get_rect().end.y>=600,'at least 600 logical pixels of clear battle height')
			var controls: Array[Control]=[hud.details_button,hud.auto_button,hud.speed_button,hud.slot_row,map]
			for i in controls.size():
				check(main.get_viewport_rect().encloses(controls[i].get_global_rect()),controls[i].name+' stays in viewport')
				for j in range(i+1,controls.size()):
					check(not controls[i].get_global_rect().intersects(controls[j].get_global_rect()),'HUD touch targets do not overlap')
			for id: String in hud.bars:
				var card: Dictionary=hud.bars[id]
				check(Rect2(Vector2.ZERO,card.slot.size).encloses(card.hp.get_rect()),id+' HP fits card')
				check(Rect2(Vector2.ZERO,card.slot.size).encloses(card.ultimate.get_rect()),id+' ultimate fits card')
				check(not card.level.text.is_empty(),id+' has visible role and level')
			check(hud.enemy_label.text=='적 %d'%main._enemy_wave_alive_count(),'enemy count follows actual living enemies')
			check(hud.get_node('PortraitNavigation').get_child_count()==7,'all seven navigation actions preserved')
			text_layout(hud,main.get_viewport_rect())
	var id: String=str(main.deployed_heroes[0]['id'])
	main.hero_battle_state[id]['hp']=int(main.hero_battle_state[id]['max_hp']*.2)
	main.hero_battle_state[id]['ultimate']=34
	main.hero_skill_runtime[id]['remaining']=3.1
	main.hero_skill_runtime[id]['secondary_remaining']=5.2
	main.portrait_hud.refresh()
	check(main.portrait_hud.bars[id].skill.text=='기술 4초','skill clock rounds remaining cooldown up')
	check(main.portrait_hud.bars[id].hp_band==0,'low HP is visibly red')
	main.hero_battle_state[id]['ultimate']=100
	main.portrait_hud.refresh()
	check(main.portrait_hud.bars[id].skill.text=='궁극 준비','full charge has a readable ultimate-ready label')
	main.hero_battle_state[id]['hp']=0
	main.portrait_hud.refresh()
	check(main.portrait_hud.bars[id].skill.text=='전투불능','dead hero does not show a usable ultimate')
	main.portrait_hud._toggle_auto()
	check('재개' in main.portrait_hud.auto_button.text and '일시정지' in main.portrait_hud.status_label.text,'pause is visible and offers resume')
	main.portrait_hud._toggle_auto()
	check('자동사냥 중' in main.portrait_hud.auto_button.text,'resume label updates')
	main.enemy_wave[0]['hp']=0
	main.portrait_hud.refresh()
	check(main.portrait_hud.enemy_label.text=='적 %d'%main._enemy_wave_alive_count(),'enemy death immediately updates displayed population')
	main.deployed_heroes=roster.slice(0,3);main.party_slot_legacy_cap=3
	main.portrait_hud.refresh();await settle()
	check(main.portrait_hud.slot_row.size.y==84,'party row shrinks when second row is no longer needed')
	main.idle_stage=15
	main.portrait_hud.refresh();await settle()
	check(main.portrait_hud.slot_row.size.y==176,'newly unlocked party slots appear without resetting battle')
	main.portrait_hud.bars[id].slot.pressed.emit();await settle()
	check(main.active_screen=='hero_detail','party card opens the matching hero detail')
	main._clear_screen();main.free();await process_frame
	print('V52 HUNT UI ',checks-failures.size(),'/',checks,' PASS')
	quit(0 if failures.is_empty() else 1)
