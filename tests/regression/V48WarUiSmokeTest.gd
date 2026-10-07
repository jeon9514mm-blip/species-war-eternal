extends SceneTree
class CountingGateway extends WorldServerGateway:
	var advances := 0
	func advance(authority: WorldAuthorityService, world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, player_id: String, delta: float) -> Dictionary:
		advances+=1
		return super.advance(authority,world,march,conflict,supply,resolver,player_id,delta)
var checks:=0
var failures: Array[String]=[]
var main: Node
var war: WorldWarScreen
func _init() -> void: run.call_deferred()
func check(condition: bool, label: String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		push_error('V48 UI: '+label)
func settle() -> void:
	for i in 6: await process_frame
func close_modal() -> void:
	if is_instance_valid(war._active_modal):
		war._active_modal.find_child('WarModalClose',true,false).pressed.emit()
	await settle()
func run() -> void:
	root.content_scale_size=Vector2i(720,1280)
	root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v48-war-ui.json'
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction='aurelia'
	main.idle_stage=25
	main._offline_checked=true
	main._restore_deployed_heroes(['leonhardt','mira','elisia'])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._build_faction_war_screen()
	for child in main.content_root.get_children():
		if child is WorldWarScreen: war=child
	war.set_process(false)
	war.set_command_expanded(true)
	await settle()
	var snapshot: Dictionary=main.faction_war_state.export_state()
	for dims: Vector2i in [Vector2i(720,1280),Vector2i(720,1440),Vector2i(720,1560),Vector2i(810,1440)]:
		root.size=dims
		await settle()
		var view:=Rect2(Vector2.ZERO,main.get_viewport_rect().size)
		for name in ['WarToolbar','WarMetrics','WarMapPanel','WarCommandPanel']:
			var panel: Control=war.get_node(name)
			check(view.encloses(panel.get_global_rect()),'panel fits portrait '+name+' '+str(dims))
		var map: Control=war.get_node('WarMapPanel')
		var commands: Control=war.get_node('WarCommandPanel')
		check(not map.get_global_rect().intersects(commands.get_global_rect()),'map and commands never overlap '+str(dims))
		var nav: Control=main.content_root.get_node('PortraitNavigation')
		check(commands.get_global_rect().end.y<nav.get_global_rect().position.y,'commands clear the navigation '+str(dims))
		check(war.find_child('WarCommandDetails',true,false).size.y>=100,'territory details retain readable scroll area '+str(dims))
		for button in [war.season_button,war.sync_button,war.action_button,war.support_button,war.rally_button,war.cancel_button,war.return_button,war.report_button]:
			check(button.is_visible_in_tree() and view.encloses(button.get_global_rect()),'command visible and within screen '+button.text)
			check(button.size.y>=44,'command keeps touch height '+button.text)
		war.season_button.pressed.emit()
		await settle()
		check(view.encloses(war._active_modal.get_global_rect()),'season popup fully fits '+str(dims))
		var close: Control=war._active_modal.find_child('WarModalClose',true,false)
		check(close.is_visible_in_tree() and view.encloses(close.get_global_rect()),'popup close stays reachable '+str(dims))
		await close_modal()
	check(snapshot==main.faction_war_state.export_state(),'screen resize and season reading preserve army and economy')
	# Reports remain selectable and use a single modal/backdrop.
	war.world_state.record_battle_report({'victory':false,'tile_name':'오래된 전투','defeated_forces':1,'remaining_defenders':1,'attacker_survivors':0,'logs':['후퇴']})
	war.world_state.record_battle_report({'victory':true,'tile_name':'최근 전투','defeated_forces':2,'remaining_defenders':0,'attacker_survivors':3,'logs':['점령']})
	war._show_latest_battle_report()
	await settle()
	check(war._active_modal.find_child('WarReportPage',true,false).text=='1 / 2','latest report is first in history')
	war._active_modal.find_child('WarOlderReport',true,false).pressed.emit()
	await settle()
	check(war._active_modal.find_child('WarReportPage',true,false).text=='2 / 2','older report can be opened')
	war._active_modal.find_child('WarNewerReport',true,false).pressed.emit()
	await settle()
	var backdrops:=0
	for child in war._modal_layer.get_children():
		if child is ColorRect and child.mouse_filter==Control.MOUSE_FILTER_STOP: backdrops+=1
	check(backdrops==1,'browsing reports leaves exactly one input-blocking backdrop')
	check(war._modal_layer.layer>0,'modal input is above portrait navigation canvas')
	check(Rect2(Vector2.ZERO,main.get_viewport_rect().size).encloses(war._active_modal.get_global_rect()),'battle report fits narrow portrait')
	await close_modal()
	# Select by actual mouse/touch events; dragging must not change the selected tile.
	var map_view: WorldWarMapView=war.map_view
	map_view.set_zoom(3.0)
	map_view.focus_cell(Vector2i(10,10))
	map_view._map_metrics()
	var point:=map_view._cell_center(Vector2i(10,10))
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=pressed
		map_view._gui_input(event)
	check(war.selected_cell==Vector2i(10,10),'mouse tap selects the displayed territory')
	map_view.set_zoom(4.5)
	map_view.focus_cell(Vector2i(10,10))
	point=map_view._cell_center(Vector2i(11,10))
	for pressed in [true,false]:
		var touch:=InputEventScreenTouch.new()
		touch.index=0;touch.position=point;touch.pressed=pressed
		map_view._gui_input(touch)
	check(war.selected_cell==Vector2i(11,10),'touch selection maps correctly after zoom')
	var center_before:=map_view.camera_center
	var selection_before:=war.selected_cell
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=map_view.size*.5
	map_view._gui_input(press)
	var drag:=InputEventMouseMotion.new();drag.relative=Vector2(30,60);drag.position=press.position+drag.relative
	map_view._gui_input(drag)
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=drag.position
	map_view._gui_input(release)
	check(map_view.camera_center!=center_before and war.selected_cell==selection_before,'drag pans without issuing a tile selection')
	map_view.pan_by(Vector2(100000,-100000))
	check(map_view.camera_center.x>=0 and map_view.camera_center.y<=WorldWarState.HEIGHT,'panning remains within the world')
	map_view.set_zoom(1.0)
	check(map_view.cell_at_point(Vector2(-1,-1))==Vector2i(-1,-1),'outside-map clicks are rejected')
	var funds:=war.world_state.rations
	var sequence:=war.client_session.command_sequence
	war._recommend_target()
	check(war.world_state.tile_owner(war.selected_cell)==WorldWarState.FACTION_NEUTRAL,'recommendation prefers a reachable neutral frontier')
	check(not map_view.preview_path.is_empty() and not war.action_button.disabled,'selected target displays a valid route and enabled march')
	check(not war.march_state.active and funds==war.world_state.rations and sequence==war.client_session.command_sequence,'recommendation never spends resources or submits a command')
	war.world_state.rations=0
	war._refresh()
	check(war.action_button.disabled and '군량' in war.order_hint.text,'insufficient rations explain why departure is blocked')
	check(not war.return_button.disabled and war.return_button.text=='긴급 귀환','free emergency return remains visible')
	war.world_state.rations=funds
	for hero in war.attacker_squad: war.world_state.army_wounds[str(hero['id'])]=0.0
	war._refresh()
	check(war.action_button.disabled and war.rally_button.disabled and '부상' in war.order_hint.text,'wiped army gets recovery guidance')
	war._on_tile_selected(war.world_state.army_position)
	check(war.support_button.disabled,'wiped army cannot press garrison registration')
	war.world_state.army_wounds.clear()
	war._recommend_target()
	# Authority progression is polled at bounded cadence, but clock catch-up still resolves once.
	var counting:=CountingGateway.new()
	war.client_session.gateway=counting
	war._perform_selected_action()
	check(war.march_state.active,'actual primary action starts an authoritative march')
	check('행군 경로' in war.detail_label.text and '경로 없음' not in war.detail_label.text,'active destination keeps its route description')
	for i in 60: war._process(1.0/60.0)
	check(counting.advances>=5 and counting.advances<=7,'60 render updates produce only 5–7 march snapshots')
	var origin: Vector2i=war.world_state.army_position
	var destination: Vector2i=war.march_state.target
	war._refresh_march_only()
	check(war.march_progress.visible and war.cancel_button.text.contains('환급'),'active march shows progress and cancellation refund')
	war.client_session.authority.server_time_offset_seconds+=war.march_state.remaining_seconds()+1
	war._process(.2)
	check(not war.march_state.active and war.world_state.army_position==destination and destination!=origin,'authoritative clock completes the displayed march')
	check(not war.march_progress.visible,'arrival clears the progress indicator')
	var captured:=war.world_state.captured_count
	war._process(.2)
	check(war.world_state.captured_count==captured,'UI polling cannot award the same capture twice')
	main._clear_screen();main.free()
	print('V48WarUiSmokeTest: ',checks,' checks, ',failures.size(),' failures; march polls per 60 updates=',counting.advances-1)
	quit(0 if failures.is_empty() else 1)
