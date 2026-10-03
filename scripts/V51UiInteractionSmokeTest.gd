extends SceneTree
## Exercise viewport input delivery, not only direct signal calls. z_index does
## not prevent a later sibling's buttons from receiving clicks behind a modal.
var main: Node
var war: WorldWarScreen
var checks:=0
var failures: Array[String]=[]
var selections:=0

func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error('V51 UI: '+label)
func settle() -> void:
	for i in 8:await process_frame
func click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point
	root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point
		root.push_input(event,true)
func escape() -> void:
	var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true
	root.push_input(event,true)
	event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=false
	root.push_input(event,true)
func touch(index: int, pressed: bool, point: Vector2, canceled: bool=false) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=index;event.pressed=pressed;event.position=point;event.canceled=canceled
	war.map_view._gui_input(event)
func button(caption: String) -> Button:
	for node in main.content_root.find_children('*','Button',true,false):
		if node.text==caption:return node
	return null
func all_text(node: Node) -> String:
	var result: String=node.text if node is Label else ''
	for child in node.get_children():result+='\n'+all_text(child)
	return result
func fixture(faction: String) -> void:
	main.selected_faction=faction;main.idle_stage=35
	main.deployed_heroes=main._hero_roster_for_faction().slice(0,10)
	main._setup_hero_progress(main._hero_roster_for_faction())
func find_war() -> void:
	for node in main.content_root.get_children():
		if node is WorldWarScreen:war=node
	war.set_process(false)

func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v51-ui-interaction.json'
	root.add_child(main);await settle()
	main._offline_checked=true;main.set_physics_process(false);main.combat_effects_enabled=false
	for faction in ['aurelia','noxfera']:
		fixture(faction)
		for dimensions in [Vector2i(720,1280),Vector2i(810,1440)]:
			root.size=dimensions;await settle()
			main._build_faction_war_screen();await settle();find_war()
			var chosen:=war.selected_cell
			var sequence: int=war.client_session.command_sequence
			for kind in ['preparation','season','report']:
				if kind=='preparation':war._show_campaign_preparation()
				elif kind=='season':war._show_season_info()
				else:war._show_battle_report({'victory':true,'tile_name':'전선 기록','logs':['승리']})
				await settle()
				check(main.get_viewport_rect().encloses(war._active_modal.get_global_rect()),kind+' modal fits '+str(dimensions))
				var nav: Control=main.content_root.find_child('PortraitNav_heroes',true,false)
				click(nav.get_global_rect().get_center());await settle()
				check(main.active_screen=='faction_war',kind+' blocks real navigation click '+faction)
				if main.active_screen!='faction_war':quit(1);return
				click(war.map_view.get_global_rect().position+Vector2(4,4));await settle()
				check(war.selected_cell==chosen and war.client_session.command_sequence==sequence,kind+' blocks map and orders')
				escape();await settle()
				check(not is_instance_valid(war._active_modal),kind+' closes on cancel key')
				check(war._modal_layer.get_child_count()==0,kind+' leaves no invisible input blocker')
			war._show_campaign_preparation();await settle()
			war._show_season_info();await settle()
			check(war._modal_layer.get_child_count()==2,'replacing dialog leaves one panel and one dimmer')
			var close: Control=war._active_modal.find_child('WarModalClose',true,false)
			click(close.get_global_rect().get_center());await settle()
			check(not is_instance_valid(war._active_modal),'real close button receives input above dimmer')
			var nav: Control=main.content_root.find_child('PortraitNav_heroes',true,false)
			click(nav.get_global_rect().get_center());await settle()
			check(main.active_screen=='hero_detail','navigation resumes at the current hero showcase after closing modal')
	fixture('aurelia');main._build_faction_war_screen();await settle();find_war()
	var view:=war.map_view
	view.tile_selected.connect(func(_cell): selections+=1)
	view.set_zoom(3);view.focus_army()
	var center:=view.size*.5
	touch(0,true,center);touch(0,false,center,true)
	check(selections==0,'OS-canceled touch never selects a territory')
	check(view._pointer==-1 and view._touches.is_empty(),'OS cancellation clears active pointers')
	touch(0,true,center-Vector2(30,0));touch(1,true,center+Vector2(30,0));touch(2,true,center+Vector2(100,0))
	touch(0,false,center-Vector2(30,0))
	var zoom_before:=view.zoom
	var drag:=InputEventScreenDrag.new();drag.index=2;drag.position=center+Vector2(100,0);drag.relative=Vector2.ZERO
	view._gui_input(drag)
	check(is_equal_approx(view.zoom,zoom_before),'changing the active finger pair never jumps zoom')
	touch(1,false,center+Vector2(30,0));touch(2,false,center+Vector2(100,0))
	check(selections==0,'three-finger gesture never sends a tap')
	touch(0,true,center)
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(0,false,center)
	check(selections==0 and view._touches.is_empty(),'app focus loss cancels pending touch')
	touch(0,true,center);touch(0,false,center)
	check(selections==1,'fresh tap works after interruption')
	var logs: Array[String]=[]
	for i in WorldBattleResolver.REPORT_LOG_LIMIT:logs.append('기록 %02d · 전투 결과 확인'%i)
	war._show_battle_report({'victory':true,'tile_name':'전체 교전 기록','logs':logs});await settle()
	var text:=all_text(war._active_modal.find_child('WarBattleReportScroll',true,false))
	for entry in logs:check(text.contains(entry),'battle report retains '+entry)
	escape();await settle()
	main._build_lobby_screen();await settle();main._show_main_menu();await settle()
	escape();await settle()
	check(main.content_root.get_node_or_null('PortraitActionSheet')==null,'portrait action sheet closes on cancel key')
	# UI availability must match the monotonic reward-day guard in the game.
	main.daily_reward_claimed_day='9999-12-31';main.rewarded_ad_day='9999-12-31';main.rewarded_ad_claimed_count=3
	main._build_bm_screen();await settle()
	check(button('오늘의 선물 수령 완료')!=null and button('오늘의 선물 수령 완료').disabled,'clock rollback cannot re-enable claimed gift')
	check(button('오늘의 지원 수령 완료')!=null and button('오늘의 지원 수령 완료').disabled,'clock rollback retains exhausted support count')
	main.daily_reward_claimed_day='2000-01-01';main.rewarded_ad_day='2000-01-01'
	main._build_bm_screen();await settle()
	check(button('오늘의 선물 받기')!=null and not button('오늘의 선물 받기').disabled,'new day enables gift')
	check(button('지원 보상 받기')!=null and not button('지원 보상 받기').disabled,'new day displays fresh support quota')
	main._clear_screen();main.free();await settle()
	print('V51UiInteractionSmokeTest: ',checks,' checks, ',failures.size(),' failures')
	quit(0 if failures.is_empty() else 1)
