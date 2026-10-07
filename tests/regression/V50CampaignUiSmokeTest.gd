extends SceneTree
var checks:=0
var failures: Array[String]=[]
var main: Node
var war: WorldWarScreen
var states:=0
func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error('V50 UI: '+label)
func settle() -> void:
	for i in 8:await process_frame
func audit(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree():return
	if node is Label or node is Button:
		var rect: Rect2=node.get_global_rect()
		var parent:=node.get_parent();var scroll:=false;var clip: Rect2=main.get_viewport_rect()
		while parent is Control:
			if parent is ScrollContainer:scroll=true
			if parent.clip_contents:clip=clip.intersection(parent.get_global_rect())
			parent=parent.get_parent()
		check(rect.position.x>=clip.position.x-1 and rect.end.x<=clip.end.x+1,'text fits panel width: '+node.text.left(30))
		if not scroll:check(main.get_viewport_rect().grow(1).encloses(rect),'text fits viewport: '+node.text.left(30))
		if node is Label:
			check(node.get_line_count()*node.get_line_height()<=node.size.y+2,'wrapped text fits height: '+node.text.left(30))
		elif node is Button:
			var style: StyleBox=node.get_theme_stylebox('normal')
			var width: float=node.get_theme_font('font').get_multiline_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size('font_size')).x+style.get_content_margin(SIDE_LEFT)+style.get_content_margin(SIDE_RIGHT)
			check(width<=node.size.x+1 and node.size.y>=44,'button readable and touchable: '+node.text)
		for other in node.get_parent().get_children():
			if other==node or not (other is Label or other is Button) or not other.is_visible_in_tree() or other.get_index()<=node.get_index():continue
			var overlap:=rect.intersection(other.get_global_rect())
			check(overlap.size.x<=3 or overlap.size.y<=3,'sibling text does not overlap '+node.text.left(20))
	for child in node.get_children():audit(child)
func close_modal() -> void:
	if is_instance_valid(war._active_modal):war._active_modal.find_child('WarModalClose',true,false).pressed.emit()
	await settle()
func touch(index: int, pressed: bool, point: Vector2) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.pressed=pressed;event.position=point
	war.map_view._gui_input(event)
func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate();main.save_state_path='user://v50-campaign-ui.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main._offline_checked=true;main.combat_effects_enabled=false
	for faction_id in ['aurelia','noxfera']:
		main.selected_faction=faction_id;main.idle_stage=35
		main.deployed_heroes=main._hero_roster_for_faction().slice(0,10)
		main._setup_hero_progress(main._hero_roster_for_faction())
		main._build_faction_war_screen();await settle()
		for child in main.content_root.get_children():
			if child is WorldWarScreen:war=child
		war.set_process(false)
		for dims in [Vector2i(720,1280),Vector2i(720,1560),Vector2i(810,1440)]:
			root.size=dims;await settle();war.set_command_expanded(false);await settle()
			states+=1;audit(war)
			var big_height: float=war.get_node('WarMapPanel').size.y
			check(big_height>=590,'default map is taller than previous 390–510 panel')
			check(not war.find_child('WarCommandDetails',true,false).visible,'default command dock leaves room for map')
			war.expand_button.pressed.emit();await settle();states+=1;audit(war)
			check(war.get_node('WarMapPanel').size.y<big_height and war.support_button.is_visible_in_tree(),'expanded command dock exposes support and garrison')
			check(war.find_child('WarCommandDetails',true,false).size.y>=100,'expanded troop details keep readable scroll area')
			var snapshot: Dictionary=war.world_state.export_state();var command_count: int=war.client_session.command_sequence
			war.scout_button.pressed.emit();await settle();states+=1;audit(war._active_modal)
			check(snapshot==war.world_state.export_state() and command_count==war.client_session.command_sequence,'scout does not charge resources or issue commands')
			check(main.get_viewport_rect().encloses(war._active_modal.get_global_rect()),'preparation modal fits portrait')
			check(war._active_modal.find_child('WarModalClose',true,false).is_visible_in_tree(),'preparation always has accessible exit')
			await close_modal()
	# Map projection, touch gestures and minimap camera navigation.
	var view:=war.map_view
	for zoom_value in [1.0,2.0,4.0,8.0]:
		view.set_zoom(zoom_value)
		for cell in [Vector2i(0,0),Vector2i(39,39),Vector2i(39,0),Vector2i(0,39),Vector2i(19,19),Vector2i(20,20)]:
			view.focus_cell(cell);view._map_metrics()
			check(view.cell_at_point(view._cell_center(cell))==cell,'isometric selection roundtrip '+str(cell)+' zoom '+str(zoom_value))
	view.set_zoom(3);view.focus_army();var chosen:=war.selected_cell
	var center:=view.size*.5
	touch(0,true,center-Vector2(30,0));touch(1,true,center+Vector2(30,0))
	var drag:=InputEventScreenDrag.new();drag.index=1;drag.position=center+Vector2(60,0);drag.relative=Vector2(30,0)
	view._gui_input(drag);touch(1,false,drag.position);touch(0,false,center-Vector2(30,0))
	check(view.zoom>3 and war.selected_cell==chosen,'pinch zoom never selects territory or submits orders')
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=war.minimap.size*Vector2(.85,.85)
	war.minimap._gui_input(event)
	check(view.camera_center.x>30 and view.camera_center.y>30 and war.selected_cell==chosen,'minimap navigates added provinces without changing orders')
	war._map_command(5);check(view.map_filter=='resources','resource filter enables')
	war._map_command(6);check(view.map_filter=='forts','fort filter enables')
	war._map_command(0);check(view.map_filter=='all' and view.zoom==1,'world overview clears filter')
	# Real button flow: first tap previews; only explicit confirmation dispatches.
	war.set_command_expanded(false);war._recommend_target();await settle()
	var funds:=war.world_state.rations;var commands:=war.client_session.command_sequence
	war.action_button.pressed.emit();await settle();states+=1;audit(war._active_modal)
	check(not war.march_state.active and war.world_state.rations==funds and commands==war.client_session.command_sequence,'primary action opens preview without departure')
	war._active_modal.find_child('WarStance_assault',true,false).pressed.emit();await settle()
	check(war.world_state.battle_stance=='assault' and not war.march_state.active and war.world_state.rations==funds,'tactic selector updates command without starting march')
	# Changing the route while confirmation is open requires a fresh quote.
	war.world_state.rations=0
	war._active_modal.find_child('WarConfirmMarch',true,false).pressed.emit();await settle()
	check(not war.march_state.active and war._active_modal.find_child('WarConfirmMarch',true,false).disabled,'confirmation revalidates resources')
	war.world_state.rations=funds;war._show_campaign_preparation();await settle()
	var plan:=war.march_state.plan(war.world_state,war.selected_cell)
	war._active_modal.find_child('WarConfirmMarch',true,false).pressed.emit();await settle()
	check(war.march_state.active and war.world_state.rations==funds-int(plan['ration_cost']),'confirmed departure spends exact quoted cost')
	war._show_campaign_preparation();await settle();states+=1;audit(war._active_modal)
	check(war._active_modal.find_child('WarConfirmMarch',true,false).disabled and war._active_modal.find_child('WarStance_assault',true,false).disabled,'march locks duplicate departure and tactic editing')
	await close_modal()
	war._cancel_march();await settle()
	var report:=WorldBattleResolver.new().resolve(war.attacker_squad,WorldBattleResolver.new().make_garrison('neutral',Vector2i(24,25),'fort',1600),0,1.18,88,'assault')
	report['tile_name']='황혼 고원의 요새';war._show_battle_report(report);await settle();states+=1;audit(war._active_modal)
	check(report['timeline'].size()>0 and war._active_modal.find_child('WarBattleReportScroll',true,false).get_child_count()==1,'battle report renders real turn history in a single scroll')
	await close_modal()
	print('V50CampaignUiSmokeTest: ',checks,' checks, ',states,' states, ',failures.size(),' failures')
	# Audio shutdown is asynchronous even under the Dummy/headless driver.
	main.set_process(false);main.set_physics_process(false)
	if is_instance_valid(main.presentation_runtime): main.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	main.queue_free();await settle();await create_timer(0.35).timeout
	quit(0 if failures.is_empty() else 1)
