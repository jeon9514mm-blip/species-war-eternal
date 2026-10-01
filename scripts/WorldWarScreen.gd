extends Control
class_name WorldWarScreen

signal back_requested
signal state_changed

const PORTRAIT_SKIN = preload("res://scripts/portrait/PortraitSkin.gd")
const MARCH_POLL_SECONDS := 0.15
const UI = preload("res://scripts/GameUiTheme.gd")
const PANEL := UI.SURFACE
const TEXT := UI.INK
const MUTED := UI.MUTED
const GOLD := UI.GOLD
const GREEN := UI.GREEN
const RED := UI.RED

var world_state: WorldWarState
var march_state: WorldMarchState
var conflict_state: WorldConflictState
var season_state: WorldSeasonState
var client_session: WorldWarClientSession
var supply_network := WorldSupplyNetwork.new()
var faction := ""
var party_power := 0
var attacker_squad: Array = []
var selected_cell := Vector2i(-1, -1)
var map_view: WorldWarMapView
var detail_label: Label
var action_button: Button
var support_button: Button
var rally_button: Button
var cancel_button: Button
var return_button: Button
var report_button: Button
var sync_button: Button
var season_button: Button
var stats_label: Label
var status_label: Label
var march_label: Label
var war_metric_labels: Dictionary = {}
var order_hint: Label
var march_progress: ProgressBar
var map_zoom_label: Label
var _command_expanded := false
var command_title: Label
var expand_button: Button
var scout_button: Button
var minimap: WorldWarMinimap
var province_label: Label
var _portrait_mode := false
var _active_modal: PanelContainer
var _modal_layer: CanvasLayer
var _ui_elapsed := 0.0
var _heartbeat_elapsed := 0.0
var _march_retry_elapsed := 0.0
var _preparation_serial: int = 0
var _preparation_snapshot: Dictionary = {}

func setup(state: WorldWarState, march: WorldMarchState, conflict: WorldConflictState, season: WorldSeasonState, session: WorldWarClientSession, faction_id: String, power: int, squad: Array) -> void:
	world_state = state
	march_state = march
	conflict_state = conflict
	season_state = season
	client_session = session
	faction = faction_id
	party_power = power
	attacker_squad = squad.duplicate(true)
	if world_state != null:
		selected_cell = world_state.army_position
	if is_inside_tree():
		_build()

func _ready() -> void:
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	get_viewport().size_changed.connect(_layout_changed)
	if world_state != null:
		_build()
		_handle_catch_up()

func _process(delta: float) -> void:
	if world_state == null or march_state == null or client_session == null or not is_finite(delta) or delta < 0.0:
		return
	_heartbeat_elapsed += maxf(0.0, delta)
	if _heartbeat_elapsed >= WorldSyncGuard.HEARTBEAT_INTERVAL_SECONDS:
		_heartbeat_elapsed = 0.0
		var old_revision := client_session.revision
		if not march_state.active:
			client_session.advance_server(0.0, attacker_squad, party_power)
		if client_session.revision != old_revision:
			state_changed.emit()
		var heartbeat := client_session.heartbeat_server()
		if not bool(heartbeat.get("ok", false)) and is_instance_valid(status_label):
			status_label.text = "전선 통신 · %s · 재시도 %.0f초" % [client_session.connection_health_text(), client_session.retry_delay_seconds()]
		_refresh()
	if march_state.active:
		_march_retry_elapsed = maxf(0.0, _march_retry_elapsed - maxf(0.0, delta))
		if _march_retry_elapsed > 0.0:
			return
		_ui_elapsed += delta
		if _ui_elapsed < MARCH_POLL_SECONDS:
			return
		var result := client_session.advance_server(_ui_elapsed, attacker_squad, party_power)
		_ui_elapsed = 0.0
		if not bool(result.get("ok", false)):
			_march_retry_elapsed = client_session.retry_delay_seconds()
		var event := str(result.get("event", ""))
		if event not in ["idle", "march_progress"]:
			_handle_authority_result(result)
			_ui_elapsed = 0.0
		else:
			_ui_elapsed = 0.0
			_refresh_march_only()

func _handle_catch_up() -> void:
	if client_session == null or march_state == null:
		return
	var sync := client_session.resync_from_server()
	if not bool(sync.get("ok", false)):
		if is_instance_valid(status_label):
			status_label.text = "전선 재동기화 실패"
		return
	var old_revision := client_session.revision
	var result := client_session.catch_up_server(attacker_squad, party_power)
	var event := str(result.get("event", ""))
	if event not in ["idle", "march_progress"]:
		_handle_authority_result(result)
	elif client_session.revision != old_revision:
		state_changed.emit()
	_refresh()

func _style(fill: Color, border := Color.TRANSPARENT, radius := 14, width := 1) -> StyleBoxFlat:
	var box := UI.panel(fill, border, radius, width)
	if _portrait_mode:
		box.bg_color=PORTRAIT_SKIN.SURFACE
		box.border_color=PORTRAIT_SKIN.EDGE_SOFT
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box

func _label(text_value: String, font_size := 15, color := TEXT) -> Label:
	var label := UI.label(text_value, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _portrait_mode:
		label.add_theme_color_override('font_color',PORTRAIT_SKIN.MUTED if color==MUTED else (PORTRAIT_SKIN.GOLD if color==GOLD else (Color('#8bdfaa') if color==GREEN else (Color('#f5a3a3') if color==RED else PORTRAIT_SKIN.INK))))
	return label

func _button(text_value: String, min_size: Vector2, color: Color) -> Button:
	var button := PORTRAIT_SKIN.button(text_value,Callable(),Color('#8a6030') if color==UI.PRIMARY else Color('#304768')) if _portrait_mode else UI.button(text_value, Vector2(min_size.x, maxf(44.0, min_size.y)), color)
	button.custom_minimum_size=Vector2(min_size.x,maxf(44.0,min_size.y))
	button.tooltip_text = text_value
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button

func _frame_left() -> float:
	return maxf(52.0, (get_viewport_rect().size.x - 1176.0) * 0.5)

func _war_metric_card(title_text: String, accent: Color, key: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 68)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _style(PANEL, UI.BORDER)
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label(title_text, 12, accent))
	var value := _label("-", 15, TEXT)
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(value)
	war_metric_labels[key] = value
	return panel

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var left := _frame_left()
	var header := HBoxContainer.new()
	header.name = "WarHeader"
	header.position = Vector2(left, 24)
	header.size = Vector2(1176, 46)
	header.add_theme_constant_override("separation", 16)
	add_child(header)
	var back := _button("‹  로비", Vector2(110, 44), UI.SOFT)
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	var heading := _label("종의 전쟁", 28, TEXT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var faction_name := "아우렐리아 연합" if faction == WorldWarState.FACTION_AURELIA else "녹스페라 연맹"
	header.add_child(_label(faction_name, 15, MUTED))
	season_button = _button("시즌 · 보상", Vector2(112, 44), UI.SOFT)
	season_button.name="WarSeasonButton"
	season_button.pressed.connect(_show_season_info)
	header.add_child(season_button)
	sync_button = _button("전선 새로고침", Vector2(140, 44), UI.SOFT)
	sync_button.name="WarSyncButton"
	sync_button.pressed.connect(_resync_world)
	header.add_child(sync_button)
	var subtitle := _label("영토를 잇고, 동료와 함께 대륙을 넓혀 가세요.", 15, MUTED)
	subtitle.position = Vector2(left, 83)
	subtitle.size = Vector2(1176, 24)
	add_child(subtitle)

	war_metric_labels.clear()
	var metric_grid := HBoxContainer.new()
	metric_grid.name = "WarMetrics"
	metric_grid.position = Vector2(left, 116)
	metric_grid.size = Vector2(1176, 64)
	metric_grid.add_theme_constant_override("separation", 12)
	add_child(metric_grid)
	metric_grid.add_child(_war_metric_card("시즌 점수", GOLD, "score"))
	metric_grid.add_child(_war_metric_card("우리의 영토", UI.BLUE, "territory"))
	metric_grid.add_child(_war_metric_card("원정 물자", GREEN, "logistics"))
	metric_grid.add_child(_war_metric_card("전선 상태", UI.LAVENDER, "server"))

	var map_panel := PanelContainer.new()
	map_panel.name = "WarMapPanel"
	map_panel.position = Vector2(left, 196)
	map_panel.size = Vector2(724, 428)
	map_panel.add_theme_stylebox_override("panel", _style(PANEL, UI.BORDER))
	add_child(map_panel)
	var map_box := VBoxContainer.new()
	map_box.add_theme_constant_override("separation", 8)
	map_panel.add_child(map_box)
	var map_header := HBoxContainer.new()
	map_box.add_child(map_header)
	var map_heading:=VBoxContainer.new()
	map_heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	map_header.add_child(map_heading)
	var map_title := _label("천하 전도 · 40 × 40", 19, TEXT)
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_heading.add_child(map_title)
	province_label=_label('서부 왕국 · 드래그 이동 / 두 손가락 확대',14,MUTED)
	province_label.clip_text=true
	map_heading.add_child(province_label)
	var map_tools:=HBoxContainer.new()
	map_tools.name="WarMapTools"
	map_tools.add_theme_constant_override("separation",6)
	map_box.add_child(map_tools)
	map_view = WorldWarMapView.new()
	map_view.name = "WarTerritoryMap"
	map_view.custom_minimum_size = Vector2(0, 150)
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	map_view.set_world_state(world_state)
	map_view.set_march_state(march_state)
	map_view.set_supply_network(supply_network)
	map_view.tile_selected.connect(_on_tile_selected)
	map_box.add_child(map_view)
	minimap=WorldWarMinimap.new()
	minimap.name='WarMinimap'
	minimap.map_view=map_view
	map_view.camera_changed.connect(minimap.queue_redraw)
	minimap.clip_contents=true
	map_header.add_child(minimap)
	for entry in [['−',-1],['+',1],['전체',0],['내 부대',2],['추천',3],['보급',4],['자원',5],['성곽',6]]:
		var button:=_button(str(entry[0]),Vector2(44,44),UI.SOFT)
		button.name='WarMapTool'+str(entry[1])
		button.add_theme_font_size_override('font_size',14)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.pressed.connect(_map_command.bind(int(entry[1])))
		map_tools.add_child(button)
	map_zoom_label=_label('×3.5',12,MUTED)
	map_tools.add_child(map_zoom_label)
	map_view.zoom_changed.connect(func(value: float): map_zoom_label.text='×%.1f'%value)
	map_view.focus_army.call_deferred()
	var legend := _label("파랑·아우렐리아  붉음·녹스페라  금테·보호  빗금·고립", 12, MUTED)
	legend.name = "WarMapLegend"
	map_box.add_child(legend)
	stats_label = _label("", 12, MUTED)
	stats_label.name = "WarSeasonSummary"
	stats_label.clip_text = true
	stats_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	map_box.add_child(stats_label)

	var side := PanelContainer.new()
	side.name = "WarCommandPanel"
	side.position = Vector2(left + 744, 196)
	side.size = Vector2(432, 428)
	side.add_theme_stylebox_override("panel", _style(PANEL, UI.BORDER))
	add_child(side)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	side.add_child(box)
	var heading_row := HBoxContainer.new()
	box.add_child(heading_row)
	heading_row.add_child(UI.icon("war", Vector2(24, 24), UI.PRIMARY))
	command_title=_label("원정대 지휘",19,TEXT)
	command_title.clip_text=true
	command_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading_row.add_child(command_title)
	var scroll := ScrollContainer.new()
	scroll.name = "WarCommandDetails"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var information := VBoxContainer.new()
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information.add_theme_constant_override("separation", 8)
	scroll.add_child(information)
	march_label = _label("", 14, GREEN)
	march_label.name = "WarMarchStatus"
	march_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.add_child(march_label)
	march_progress=PORTRAIT_SKIN.gauge(information,Rect2(0,0,1,10),Color('#61bfe4'))
	march_progress.name='WarMarchProgress'
	march_progress.custom_minimum_size=Vector2(0,10)
	information.add_child(_label("선택한 영토", 13, GOLD))
	detail_label = _label("", 14, TEXT)
	detail_label.name = "WarSelectedTerritory"
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.add_child(detail_label)
	status_label = _label("영토를 선택하면 가능한 명령이 표시됩니다.", 13, MUTED)
	status_label.name = "WarCommandStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible=2
	box.add_child(status_label)

	order_hint=_label('',14,GOLD)
	order_hint.name='WarOrderHint'
	order_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	order_hint.max_lines_visible=2
	box.add_child(order_hint)
	# Commands remain visible while detailed territory/season descriptions scroll.
	action_button = _button("", Vector2(0, 46), UI.PRIMARY)
	action_button.name = "WarPrimaryAction"
	action_button.add_theme_font_size_override("font_size", 14)
	action_button.pressed.connect(_show_campaign_preparation)
	box.add_child(action_button)
	var war_action_row := HBoxContainer.new()
	war_action_row.name="WarAdvancedActions"
	war_action_row.add_theme_constant_override("separation", 8)
	box.add_child(war_action_row)
	support_button = _button("지원 주둔", Vector2(0, 44), UI.SOFT)
	support_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	support_button.add_theme_font_size_override("font_size", 14)
	support_button.pressed.connect(_start_support_march)
	war_action_row.add_child(support_button)
	rally_button = _button("집결 공격", Vector2(0, 44), UI.SOFT)
	rally_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rally_button.add_theme_font_size_override("font_size", 14)
	rally_button.pressed.connect(_start_rally_attack)
	war_action_row.add_child(rally_button)
	var command_row := HBoxContainer.new()
	command_row.name="WarAdvancedCommands"
	command_row.add_theme_constant_override("separation", 8)
	box.add_child(command_row)
	return_button = _button("수도 귀환", Vector2(0, 44), UI.SOFT)
	return_button.pressed.connect(_return_to_capital)
	command_row.add_child(return_button)
	cancel_button = _button("행군 취소", Vector2(0, 44), UI.SOFT)
	cancel_button.pressed.connect(_cancel_march)
	command_row.add_child(cancel_button)
	report_button = _button("전투 기록", Vector2(0, 44), UI.SOFT)
	report_button.pressed.connect(_show_latest_battle_report)
	command_row.add_child(report_button)
	for button in [return_button, cancel_button, report_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
	var quick:=HBoxContainer.new()
	quick.add_theme_constant_override('separation',8)
	box.add_child(quick)
	scout_button=_button('영토 정찰',Vector2(0,44),UI.SOFT)
	scout_button.name='WarScoutButton'
	scout_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scout_button.pressed.connect(_show_campaign_preparation)
	quick.add_child(scout_button)
	expand_button=_button('부대 지휘 ▴',Vector2(0,44),UI.SOFT)
	expand_button.name='WarExpandCommands'
	expand_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	expand_button.pressed.connect(func(): set_command_expanded(not _command_expanded))
	quick.add_child(expand_button)
	set_command_expanded(false)
	_refresh()

func set_command_expanded(expanded: bool) -> void:
	_command_expanded=expanded
	for node_name in ['WarCommandDetails','WarAdvancedActions','WarAdvancedCommands']:
		var node: Control=find_child(node_name,true,false)
		if node!=null:node.visible=expanded
	if is_instance_valid(expand_button):expand_button.text='지도 넓게 ▾' if expanded else '부대 지휘 ▴'
	_layout_changed()

func _on_tile_selected(cell: Vector2i) -> void:
	selected_cell = cell
	_refresh()

func _buff_text(buff: Dictionary) -> String:
	var tier := int(buff.get("tier", 0))
	if tier <= 0:
		return "진영 균형"
	return "%s · 행군 +%d%% · 군량 -%d%% · 방어 +%d%%" % [
		str(buff.get("name", "저항")),
		int(round((float(buff.get("march_speed_multiplier", 1.0)) - 1.0) * 100.0)),
		int(round((1.0 - float(buff.get("ration_cost_multiplier", 1.0))) * 100.0)),
		int(round((float(buff.get("defense_multiplier", 1.0)) - 1.0) * 100.0))
	]

func _owner_name(owner: String) -> String:
	if owner == WorldWarState.FACTION_AURELIA:
		return "아우렐리아"
	if owner == WorldWarState.FACTION_NOXFERA:
		return "녹스페라"
	return "중립"





func _refresh() -> void:
	if world_state == null or conflict_state == null or detail_label == null:
		return
	var ours := world_state.owned_count(faction)
	var enemy_faction := world_state.enemy_faction()
	var enemy := world_state.owned_count(enemy_faction)
	var buff := world_state.faction_balance_buff(faction)
	var isolated_ours := supply_network.isolated_count(world_state, faction)
	var isolated_enemy := supply_network.isolated_count(world_state, enemy_faction)
	var server_revision := client_session.revision if client_session != null else 0
	var sync_count := client_session.sync_count if client_session != null else 0
	var season_text := "시즌 미시작"
	var our_season_score := 0
	var enemy_season_score := 0
	var season_contribution := 0
	if season_state != null:
		var now := int(client_session.server_now_estimate()) if client_session != null else int(Time.get_unix_time_from_system())
		season_text = season_state.status_text(now)
		our_season_score = season_state.score_for(faction)
		enemy_season_score = season_state.score_for(enemy_faction)
		season_contribution = season_state.contribution_for("local_player")
	var health := client_session.connection_health_text() if client_session != null else "세션 없음"
	var score_metric: Label = war_metric_labels.get("score")
	if is_instance_valid(score_metric):
		score_metric.text = "%d : %d · 공헌 %d" % [our_season_score,enemy_season_score,season_contribution]
	var territory_metric: Label = war_metric_labels.get("territory")
	if is_instance_valid(territory_metric):
		territory_metric.text = "우리 %d · 적 %d" % [ours,enemy]
	var logistics_metric: Label = war_metric_labels.get("logistics")
	if is_instance_valid(logistics_metric):
		logistics_metric.text = "군량 %d · 명예 %d" % [world_state.rations, world_state.campaign_honor]
		logistics_metric.tooltip_text = "군량 %d · 명예 %d · 피로 %d%%" % [world_state.rations, world_state.campaign_honor, world_state.army_fatigue]
	var server_metric: Label = war_metric_labels.get("server")
	if is_instance_valid(server_metric):
		var local_front := client_session != null and client_session.gateway != null and not client_session.gateway.is_online_authoritative()
		server_metric.text = "기기 내 전선" if local_front else health
		server_metric.tooltip_text = ("이 기기에 저장된 전선입니다.\n" if local_front else "") + "전선 기록 %d · 갱신 %d회" % [server_revision, sync_count]
	stats_label.text = "%s · 고립 우리 %d / 적 %d · %s" % [season_text,isolated_ours,isolated_enemy,_buff_text(buff)]
	stats_label.tooltip_text = stats_label.text

	var tile := world_state.tile_at(selected_cell)
	if is_instance_valid(command_title):
		command_title.text='%s · (%d,%d)'%[world_state.tile_display_name(selected_cell),selected_cell.x,selected_cell.y]
	if is_instance_valid(province_label):province_label.text=world_state.province_name(selected_cell)+' · 영토 선택 → 정찰 → 출정'
	if is_instance_valid(scout_button):scout_button.disabled=tile.is_empty()
	if tile.is_empty():
		detail_label.text = "타일을 선택하세요."
		for button in [action_button,support_button,rally_button]: button.disabled=true
		order_hint.text='지도에서 영토를 선택하세요.'
		map_view.set_preview([])
		_refresh_march_only()
		return

	var owner := str(tile.get("owner", WorldWarState.FACTION_NEUTRAL))
	var selected_plan: Dictionary=march_state.plan(world_state,selected_cell) if march_state!=null else {}
	var route_text: String='현재 위치' if selected_cell==world_state.army_position else ('경로 %d칸'%int(selected_plan['distance']) if not selected_plan.is_empty() else '경로 없음')
	if march_state!=null and march_state.active:
		route_text='행군 경로 %d칸'%maxi(1,march_state.path.size()-1) if selected_cell==march_state.target else '행군 완료 후 경로 확인'
	map_view.set_preview(selected_plan.get('path',[]))
	var protection := world_state.protection_text(selected_cell)
	var protection_line := "\n보호: %s" % protection if not protection.is_empty() else ""
	var garrison_count := conflict_state.garrison_count(selected_cell)
	var capacity := conflict_state.capacity_at(world_state, selected_cell)
	var attack_queue_count := conflict_state.attack_queue_count(selected_cell)
	var supply_text := "중립"
	if owner != WorldWarState.FACTION_NEUTRAL:
		supply_text = supply_network.supply_status_text(world_state, selected_cell, owner)
	detail_label.text = "좌표 %d,%d · %s\n%s · %s%s\n주둔 %d/%d · %s\n%s" % [
		selected_cell.x, selected_cell.y, world_state.tile_display_name(selected_cell),
		_owner_name(owner), route_text, protection_line,
		garrison_count, capacity, supply_text + (" · 공격대기 %d" % attack_queue_count if attack_queue_count > 0 else ""),
		world_state.tile_resource_text(selected_cell)
	]

	action_button.disabled = true
	support_button.disabled = true
	rally_button.disabled = true
	support_button.text = "지원 주둔"
	rally_button.text = "집결 공격"

	if march_state != null and march_state.active:
		action_button.text = "다른 명령 수행 중"
	else:
		if selected_cell == world_state.army_position:
			action_button.text = "현재 주둔 위치"
		else:
			var plan := march_state.plan(world_state, selected_cell) if march_state != null else {}
			if not plan.is_empty():
				var action := str(plan.get("action", "move"))
				if action == "attack_enemy":
					action_button.text = "공성 출정 준비 · 군량 %d" % int(plan["ration_cost"])
				elif action == "capture_neutral":
					action_button.text = ("토벌 출정 준비" if world_state.neutral_guard_level(selected_cell)>0 else "영토 개척 준비") + " · 군량 %d" % int(plan["ration_cost"])
				else:
					action_button.text = "이동 준비 · 군량 %d" % int(plan["ration_cost"])
				action_button.disabled = world_state.rations < int(plan["ration_cost"]) or attacker_squad.is_empty()
			elif owner == world_state.enemy_faction():
				action_button.text = "보호지역 또는 보급선 미연결"
			else:
				action_button.text = "연결된 영토만 이동 가능"

		if owner == faction and selected_cell != world_state.army_position:
			var support_plan := march_state.plan(world_state, selected_cell, "support")
			var has_capacity := garrison_count < capacity
			var supply_ok := supply_network.can_reinforce(world_state, selected_cell, faction)
			support_button.text = "지원 주둔 · %d/%d" % [garrison_count, capacity]
			support_button.disabled = support_plan.is_empty() or not has_capacity or not supply_ok or world_state.rations < int(support_plan.get("ration_cost", 999999))
		elif owner == faction and selected_cell == world_state.army_position:
			support_button.text = "현재 타일 수비 등록"
			support_button.disabled = garrison_count >= capacity or not supply_network.can_reinforce(world_state, selected_cell, faction)

		if (owner == world_state.enemy_faction() or world_state.neutral_guard_level(selected_cell)>0) and not world_state.can_launch_combat():
			action_button.text = "피로 과다 · 수도에서 회복 필요"
			action_button.disabled = true
			rally_button.text = "피로 과다"
			rally_button.disabled = true
		elif owner == world_state.enemy_faction() and world_state.can_attack_enemy_tile(faction, selected_cell):
			var attack_plan := march_state.plan(world_state, selected_cell)
			var rally := conflict_state.rally_at_target(selected_cell, faction)
			var participant_count := 0
			if not rally.is_empty():
				var participants = rally.get("participants", [])
				if typeof(participants) == TYPE_ARRAY:
					participant_count = participants.size()
			rally_button.text = "집결 공격" if participant_count == 0 else "집결 출정 · %d/%d" % [participant_count, WorldConflictState.MAX_RALLY_FORCES]
			rally_button.disabled = attack_plan.is_empty() or attacker_squad.is_empty() or world_state.rations < int(attack_plan.get("ration_cost", 999999))

	if season_state != null and season_state.phase != "active":
		if owner != faction:
			action_button.disabled = true
			action_button.text = "시즌 정산 · 점령 잠김"
		support_button.disabled = true
		rally_button.disabled = true
	_refresh_order_guidance(selected_plan,owner)
	var admission: Dictionary = WorldCampaignRules.march_check(world_state, march_state, supply_network, selected_cell, attacker_squad, season_state == null or season_state.phase == "active")
	action_button.disabled = not bool(admission["ok"])

	for button in [action_button, support_button, rally_button]:
		button.tooltip_text = button.text
	_refresh_march_only()
	report_button.disabled = world_state.battle_reports.is_empty() and conflict_state.campaign_reports.is_empty()
	map_view.set_selected(selected_cell)
	map_view.queue_redraw()

func _refresh_march_only() -> void:
	if march_label == null or march_state == null or world_state == null:
		return
	if is_instance_valid(march_progress):
		march_progress.visible=march_state.active
		march_progress.value=100.0*march_state.progress_ratio()
	if march_state.active:
		var pct := int(round(march_state.progress_ratio() * 100.0))
		if is_instance_valid(order_hint):order_hint.text='행군 (%d,%d) · %.1f초 남음 · %d%%\n부대 지휘에서 취소 가능 · 군량 50%% 환급'%[march_state.target.x,march_state.target.y,march_state.remaining_seconds(),pct]
		var mission := "공격"
		if march_state.action == "capture_neutral":
			mission = "점령"
		elif march_state.action == "move":
			mission = "이동"
		elif march_state.action == "support":
			mission = "지원"
		elif march_state.action == "forced_retreat":
			mission = "긴급 후퇴"
		elif not march_state.context_id.is_empty():
			mission = "집결"
		march_label.text = "%s → (%d,%d) · %d%% · %.1f초\n군량 %d" % [
			mission, march_state.target.x, march_state.target.y, pct, march_state.remaining_seconds(), march_state.ration_cost
		]
	else:
		var local_garrison := conflict_state.find_force("player_local") if conflict_state != null else {}
		var duty := "주둔 등록" if not local_garrison.is_empty() else "기동 대기"
		var surviving := 0
		for unit in attacker_squad:
			if float(world_state.army_wounds.get(str(unit.get("id", "")), 1.0)) > 0.0:
				surviving += 1
		march_label.text = "현재 (%d,%d) · %s\n병력 %d/%d · 피로 %d" % [world_state.army_position.x, world_state.army_position.y, duty, surviving, attacker_squad.size(), world_state.army_fatigue]
	if cancel_button != null:
		cancel_button.disabled = not march_state.active
		cancel_button.text="취소 · %d 환급"%int(round(march_state.ration_cost*.5)) if march_state.active else "행군 취소"
	if return_button != null:
		return_button.disabled = march_state.active or world_state.army_position == world_state.capital_for(faction)
		var return_plan:=march_state.plan(world_state,world_state.capital_for(faction))
		var emergency:=return_plan.is_empty() or world_state.rations<int(return_plan.get('ration_cost',0))
		return_button.text='긴급 귀환' if emergency and not return_button.disabled else '수도 귀환'
		return_button.tooltip_text='군량 없이 천천히 귀환해 부상을 회복합니다.' if emergency else '수도 도착 시 부상 회복 · 피로 -35'
	if map_view != null:
		map_view.queue_redraw()
	if is_instance_valid(minimap):minimap.queue_redraw()

func _perform_selected_action() -> void:
	if client_session == null or march_state == null or march_state.active:
		return
	var result := client_session.send(
		"begin_march",
		{"target": [selected_cell.x, selected_cell.y]},
		attacker_squad,
		party_power
	)
	_handle_authority_result(result)

func _start_support_march() -> void:
	if client_session == null or march_state == null or march_state.active:
		return
	var result := client_session.send(
		"support",
		{"target": [selected_cell.x, selected_cell.y]},
		attacker_squad,
		party_power
	)
	_handle_authority_result(result)

func _start_rally_attack() -> void:
	if client_session == null or march_state == null or march_state.active:
		return
	var result := client_session.send(
		"rally",
		{"target": [selected_cell.x, selected_cell.y]},
		attacker_squad,
		party_power
	)
	_handle_authority_result(result)

func _return_to_capital() -> void:
	if client_session == null or march_state == null or march_state.active:
		return
	var result := client_session.send("return_capital", {}, attacker_squad, party_power)
	_handle_authority_result(result)

func _cancel_march() -> void:
	if client_session == null or march_state == null or not march_state.active:
		return
	var result := client_session.send("cancel_march", {}, attacker_squad, party_power)
	_handle_authority_result(result)

func _resync_world() -> void:
	if client_session == null:
		return
	var result := client_session.reconnect_and_resync()
	if bool(result.get("ok", false)):
		status_label.text = "전선 정보를 새로 불러왔습니다."
	else:
		status_label.text = _authority_error_text(str(result.get("error", "sync_failed")))
	state_changed.emit()
	_refresh()

func _authority_error_text(error: String) -> String:
	var messages := {
		"authority_not_bound": "전쟁 서버 상태가 준비되지 않았습니다.",
		"missing_player": "플레이어 인증 정보가 없습니다.",
		"unauthorized_player": "서버에 등록되지 않은 플레이어입니다.",
		"faction_mismatch": "진영 정보가 서버 상태와 일치하지 않습니다.",
		"stale_revision": "전선 상태가 변경되어 다시 동기화했습니다.",
		"march_already_active": "이미 다른 행군 명령을 수행 중입니다.",
		"empty_squad": "출정 가능한 영웅 부대가 없습니다.",
		"invalid_target": "잘못된 목표 타일입니다.",
		"invalid_stance": "전술을 다시 선택하세요.",
		"illegal_route": "수도 보급망에 연결된 경로가 없습니다.",
		"fatigue_limit": "피로가 너무 높습니다. 수도에서 회복하세요.",
		"insufficient_rations": "군량이 부족합니다.",
		"invalid_support_target": "아군 영토에만 지원할 수 있습니다.",
		"supply_disconnected": "보급이 끊긴 영토에는 새 지원 부대를 보낼 수 없습니다.",
		"garrison_full": "이 타일의 주둔 한도가 가득 찼습니다.",
		"invalid_attack_target": "현재 공격할 수 없는 적 영토입니다.",
		"rally_create_failed": "집결을 만들 수 없습니다.",
		"rally_full": "집결 참여 한도가 가득 찼습니다.",
		"already_at_capital": "이미 수도에 있습니다.",
		"return_failed": "수도 귀환을 시작하지 못했습니다.",
		"no_active_march": "취소할 행군이 없습니다.",
		"attack_queue_full": "적 타일의 공격 대기열이 가득 찼습니다.",
		"attack_condition_changed": "도착 전에 전선 상황이 바뀌어 공격이 취소되었습니다.",
		"rally_expired": "집결 정보가 만료되었습니다.",
		"battle_failed": "전투 계산을 완료하지 못했습니다.",
		"rally_battle_failed": "집결 전투 계산을 완료하지 못했습니다.",
		"arrival_failed": "행군 도착 처리를 완료하지 못했습니다.",
		"sync_failed": "서버 전선 상태를 다시 불러오지 못했습니다.",
		"invalid_snapshot": "서버 전선 스냅샷이 올바르지 않습니다.",
		"server_disconnected": "전쟁 서버 연결이 끊겼습니다. 재동기화를 눌러주세요.",
		"season_locked": "시즌 정산 중입니다. 귀환과 보상 수령이 가능합니다.",
		"command_id_conflict": "중복 명령 내용이 다릅니다. 재동기화해 주세요.",
		"wounded_army": "출정 가능한 부대가 없습니다. 수도로 귀환해 부상을 회복하세요.",
		"support_conditions_changed": "지원 도착 전 보급 또는 주둔 한도가 바뀌어 원위치로 복귀했습니다.",
		"season_reward_unavailable": "참여한 시즌 정산 중에 보상을 한 번 수령할 수 있습니다.",
		"season_still_active": "아직 시즌 정산이 끝나지 않았습니다.",
		"season_reward_pending": "새 시즌 시작 전 시즌 보상을 수령하세요.",
		"insufficient_honor": "전쟁 명예가 50 이상 필요합니다.",
		"support_failed": "지원 경로와 군량을 확인해 주세요.",
		"rally_march_failed": "집결 경로와 군량을 확인해 주세요.",
		"expired_command": "명령 시간이 지났습니다. 전선을 갱신해 주세요.",
		"snapshot_integrity_failed": "전선 정보를 확인하지 못했습니다. 다시 갱신해 주세요.",
		"stale_snapshot": "이전 전선 정보입니다. 다시 갱신해 주세요."
	}
	return str(messages.get(error, "명령 처리 실패 · %s" % error))

func _handle_authority_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	if not bool(result.get("ok", false)):
		status_label.text = _authority_error_text(str(result.get("error", "unknown")))
		if march_state != null and not march_state.active:
			state_changed.emit()
		_refresh()
		return
	var event := str(result.get("event", ""))
	match event:
		"claim_season_reward":
			var reward: Dictionary = result.get("reward", {})
			status_label.text = "시즌 보상 · 군량 +%d · 명예 +%d" % [int(reward.get("rations", 0)), int(reward.get("honor", 0))]
		"next_season":
			selected_cell = world_state.army_position
			status_label.text = "새 시즌 시작 · 전쟁 명예는 유지됩니다."
		"exchange_honor":
			status_label.text = "명예 50 교환 · 군량 +200"
		"march_started":
			var plan = result.get("plan", {})
			status_label.text = "출정 시작 · %d칸 · 군량 %d" % [int(plan.get("distance", 0)), int(plan.get("ration_cost", 0))]
		"support_started":
			status_label.text = "지원 행군을 시작했습니다."
		"garrison_registered":
			status_label.text = "수비대가 영토를 지킵니다."
		"rally_started":
			status_label.text = "집결 출정 승인 · %d부대" % int(result.get("participants", 0))
		"return_started":
			status_label.text = "긴급 후퇴 시작" if bool(result.get("forced", false)) else "수도 귀환 시작"
		"march_cancelled":
			status_label.text = "행군 취소 · 군량 %d 환급" % int(result.get("refund", 0))
		"army_rested":
			status_label.text="전선 정비 · 군량 -%d · 피로 -%d · 수비 등록은 해제됨" % [int(result.get("cost",0)),int(result.get("fatigue_drop",0))]
		"stance_changed":
			status_label.text = "출정 전술 · " + WorldCampaignRules.stance_name(world_state.battle_stance)
		"arrival_completed":
			status_label.text = "도착 완료 · 수비 등록" if bool(result.get("registered", false)) else "도착 완료"
		"battle_resolved":
			status_label.text = "공격 승리 · 영토 점령" if bool(result.get("captured", false)) else "공격 실패 · 원 주둔지 복귀"
			var report = result.get("report", {})
			if typeof(report) == TYPE_DICTIONARY and not report.is_empty():
				_show_battle_report(report)
		"rally_resolved":
			status_label.text = "집결 승리 · 영토 점령" if bool(result.get("captured", false)) else "집결 실패 · 전선 복귀"
			var rally_report = result.get("report", {})
			if typeof(rally_report) == TYPE_DICTIONARY and not rally_report.is_empty():
				_show_battle_report(rally_report)
		_:
			status_label.text = "전선 정보를 갱신했습니다."
	state_changed.emit()
	_refresh()

func configure_portrait() -> void:
	_portrait_mode=true
	var toolbar: HBoxContainer=get_node_or_null('WarToolbar')
	if toolbar==null:
		toolbar=HBoxContainer.new()
		toolbar.name='WarToolbar'
		toolbar.add_theme_constant_override('separation',12)
		add_child(toolbar)
		season_button.reparent(toolbar)
		sync_button.reparent(toolbar)
		for button in [season_button,sync_button]:
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			button.custom_minimum_size=Vector2(0,46)
	for item in get_children():
		if item is Control and item.name not in ['WarMetrics','WarMapPanel','WarCommandPanel','WarToolbar'] and item!=_active_modal and not str(item.name).ends_with('Backdrop'):
			item.hide()
	_layout_changed()

func _layout_changed() -> void:
	if _portrait_mode:
		var viewport_size:=get_viewport_rect().size
		var toolbar: Control=get_node_or_null('WarToolbar')
		if toolbar!=null:
			toolbar.position=Vector2(14,140)
			toolbar.size=Vector2(viewport_size.x-28,46)
		var metrics: Control=get_node('WarMetrics')
		metrics.position=Vector2(14,198);metrics.size=Vector2(viewport_size.x-28,68)
		var map_panel: Control=get_node('WarMapPanel')
		map_panel.position=Vector2(14,278)
		var command_height:=480.0 if _command_expanded else 256.0
		map_panel.size=Vector2(viewport_size.x-28,maxf(340,viewport_size.y-124-278-12-command_height))
		var commands: Control=get_node('WarCommandPanel')
		commands.position=Vector2(14,map_panel.position.y+map_panel.size.y+12)
		commands.size=Vector2(viewport_size.x-28,viewport_size.y-124-commands.position.y)
	_layout_modal()

func _layout_modal() -> void:
	if not is_instance_valid(_active_modal): return
	var viewport_size:=get_viewport_rect().size
	var desired: Vector2=_active_modal.get_meta('desired_size',Vector2(720,526))
	_active_modal.size=desired.min(viewport_size-Vector2(32,56))
	_active_modal.position=(viewport_size-_active_modal.size)*.5

func _modal_panel(node_name: String, dimensions: Vector2) -> PanelContainer:
	_preparation_serial += 1
	_preparation_snapshot.clear()
	if is_instance_valid(_active_modal):
		_active_modal.hide()
		_active_modal.name='ClosingWarModal'
		_active_modal.queue_free()
	# CanvasItem z_index only controls drawing. A separate canvas also gives the
	# dimmer input priority over the portrait header/navigation outside this view.
	if not is_instance_valid(_modal_layer):
		_modal_layer=CanvasLayer.new()
		_modal_layer.name='WarModalLayer'
		_modal_layer.layer=120
		add_child(_modal_layer)
	var backdrop:=ColorRect.new()
	backdrop.name=node_name+'Backdrop'
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color=Color('#07101fbb')
	backdrop.mouse_filter=Control.MOUSE_FILTER_STOP
	backdrop.z_index=120
	_modal_layer.add_child(backdrop)
	var popup:=PanelContainer.new()
	popup.name=node_name
	popup.set_meta('desired_size',dimensions)
	popup.z_index=121
	var style:=_style(PANEL,UI.BORDER,18,1)
	if _portrait_mode:
		style.bg_color=PORTRAIT_SKIN.SURFACE
		style.border_color=PORTRAIT_SKIN.EDGE_SOFT
	popup.add_theme_stylebox_override('panel',style)
	_modal_layer.add_child(popup)
	_active_modal=popup
	popup.minimum_size_changed.connect(_layout_modal.call_deferred)
	popup.tree_exited.connect(func():
		if is_instance_valid(backdrop): backdrop.queue_free()
	)
	_layout_modal()
	_layout_modal.call_deferred()
	return popup

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed('ui_cancel') and is_instance_valid(_active_modal):
		_active_modal.queue_free()
		get_viewport().set_input_as_handled()

func _show_season_info() -> void:
	if season_state == null:
		return
	var now := int(client_session.server_now_estimate()) if client_session != null else int(Time.get_unix_time_from_system())
	var enemy_faction := world_state.enemy_faction()
	var popup := _modal_panel("SeasonInfoPopup", Vector2(720, 526))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	popup.add_child(box)
	box.add_child(_label("종의 전쟁 · 시즌 안내", 26, TEXT))
	var scroll := ScrollContainer.new()
	scroll.name = "SeasonInfoScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var season_status := _label(season_state.status_text(now), 17, GOLD)
	season_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(season_status)
	var score := _label("우리 진영 %d점  ·  상대 진영 %d점\n내 시즌 공헌 %d" % [
		season_state.score_for(faction), season_state.score_for(enemy_faction),
		season_state.contribution_for("local_player")], 16, GREEN)
	score.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(score)
	var rules := _label("점령 점수\n일반 5 · 자원 12 · 유적 15 · 요새 30 · 대성 60\n중립 개척은 50%, 적 영토 탈환은 100%를 획득합니다.\n\n영토 생산\n수도 군량 2/분 · 광산 5/분 · 마력숲 8/분 · 유적 명예 1/분\n고립된 영토는 생산량 25% · 접속 종료 보상은 최대 8시간\n\n시즌과 회복\n정산 보상은 한 번 수령할 수 있습니다. 새 시즌에는 영토·군량·피로가 초기화되고 명예는 유지됩니다.\n수도로 돌아오면 부상을 회복하고 피로가 35 줄어듭니다.", 14, MUTED)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(rules)
	var rates:=world_state.logistics_rates(supply_network)
	var production:=_label('현재 생산 · 군량 %.1f/분 · 명예 %.2f/분\n보유 명예 %d · 부대 피로 %d%%'%[rates['rations_per_minute'],rates['honor_per_minute'],world_state.campaign_honor,world_state.army_fatigue],15,GOLD)
	production.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(production)
	var reward := season_state.reward_preview("local_player", faction, now)
	var claim := _button("시즌 보상 수령" + (" 완료" if bool(reward.get("claimed", false)) else ""), Vector2(0, 44), UI.PRIMARY)
	claim.disabled = not bool(reward.get("claimable", false))
	claim.pressed.connect(func():
		_handle_authority_result(client_session.send("claim_season_reward", {}, attacker_squad, party_power))
		popup.queue_free()
	)
	body.add_child(claim)
	var economy_row := HBoxContainer.new()
	economy_row.add_theme_constant_override("separation", 10)
	body.add_child(economy_row)
	var exchange := _button("명예 50 → 군량 200", Vector2(0, 44), UI.SOFT)
	exchange.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exchange.disabled = world_state.campaign_honor < 50
	exchange.pressed.connect(func():
		_handle_authority_result(client_session.send("exchange_honor", {}, attacker_squad, party_power))
		popup.queue_free()
	)
	economy_row.add_child(exchange)
	var next := _button("다음 시즌 시작", Vector2(0, 44), UI.SOFT)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.disabled = season_state.phase != "ended" or bool(reward.get("claimable", false))
	next.pressed.connect(func():
		_handle_authority_result(client_session.send("next_season", {}, attacker_squad, party_power))
		popup.queue_free()
	)
	economy_row.add_child(next)
	var close := _button("전선으로 돌아가기", Vector2(0, 44), UI.SOFT)
	close.name='WarModalClose'
	close.pressed.connect(popup.queue_free)
	box.add_child(close)
	close.grab_focus.call_deferred()

func _show_latest_battle_report() -> void:
	var report := world_state.latest_battle_report() if world_state != null else {}
	if report.is_empty() and conflict_state != null and not conflict_state.campaign_reports.is_empty():
		report = conflict_state.campaign_reports[0]
	if report.is_empty():
		status_label.text = "아직 전투 기록이 없습니다."
		return
	_show_battle_report(report)

func _show_history(index: int) -> void:
	var history: Array=world_state.battle_reports if not world_state.battle_reports.is_empty() else conflict_state.campaign_reports
	if index>=0 and index<history.size(): _show_battle_report(history[index])

func _show_battle_report(report: Dictionary) -> void:
	var popup := _modal_panel("WarBattleReport", Vector2(830, 520))
	var victory := bool(report.get("victory", false))
	var accent := GREEN if victory else RED
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	popup.add_child(box)
	box.add_child(_label("전투 승리" if victory else "전투 패배", 28, accent))
	var title := str(report.get("tile_name", "전선"))
	if report.has("participants_used"):
		title += " · 집결 %d부대" % int(report.get("participants_used", 0))
	var title_label:=_label(title,16,TEXT)
	title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_label)
	var history: Array=world_state.battle_reports if not world_state.battle_reports.is_empty() else conflict_state.campaign_reports
	var history_index:=history.find(report)
	if history_index>=0 and history.size()>1:
		var history_row:=HBoxContainer.new()
		box.add_child(history_row)
		var older:=_button('이전 기록',Vector2(0,44),UI.SOFT)
		older.name='WarOlderReport';older.disabled=history_index>=history.size()-1
		older.pressed.connect(_show_history.bind(history_index+1));history_row.add_child(older)
		var count:=_label('%d / %d'%[history_index+1,history.size()],15,MUTED)
		count.name='WarReportPage';count.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;history_row.add_child(count)
		var newer:=_button('다음 기록',Vector2(0,44),UI.SOFT)
		newer.name='WarNewerReport';newer.disabled=history_index==0
		newer.pressed.connect(_show_history.bind(history_index-1));history_row.add_child(newer)
	var summary_text := ""
	if report.has("defeated_forces"):
		summary_text = "격파 수비대 %d · 남은 수비대 %d\n공격 생존 %d명 · 피로 %d" % [
			int(report.get("defeated_forces", 0)), int(report.get("remaining_defenders", 0)),
			int(report.get("attacker_survivors", 0)), int(report.get("fatigue_after", world_state.army_fatigue))]
	else:
		summary_text = "전투 후 피로 %d" % int(report.get("fatigue_after", world_state.army_fatigue))
	box.add_child(_label(summary_text, 15, GOLD))
	var scroll := ScrollContainer.new()
	scroll.name = "WarBattleReportScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var log_text := ""
	var summaries = report.get("battle_summaries", [])
	if typeof(summaries) == TYPE_ARRAY:
		for summary in summaries:
			if typeof(summary) != TYPE_DICTIONARY:
				continue
			if summary.has('attacker_force_id'):
				log_text += '%s · %s · 격파 %d부대\n'%[str(summary.get('attacker_name','공격대')),'승리' if bool(summary.get('victory',false)) else '저지',int(summary.get('defeated_forces',0))]
				continue
			log_text += "%s · %s · 공격 생존 %d / 수비 생존 %d\n" % [
				str(summary.get("defender_name", "수비대")), "격파" if bool(summary.get("victory", false)) else "저지",
				int(summary.get("attacker_alive", 0)), int(summary.get("defender_alive", 0))]
	var logs = report.get("logs", [])
	if typeof(logs) == TYPE_ARRAY:
		for line in logs:
			log_text += str(line) + "\n"
	if log_text.is_empty():
		log_text = "이번 전투의 추가 기록이 없습니다."
	var log_label := _label(log_text.strip_edges(), 14, MUTED)
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var timeline_box:=VBoxContainer.new()
	timeline_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	timeline_box.add_theme_constant_override('separation',10)
	scroll.add_child(timeline_box)
	var timelines: Array=[]
	if report.get('timeline',[]) is Array and not report.get('timeline',[]).is_empty():timelines.append({'name':'영토 토벌','rounds':report['timeline']})
	for battle in report.get('battle_summaries',[]):
		if not battle is Dictionary:continue
		if battle.get('timeline',[]) is Array and not battle.get('timeline',[]).is_empty():timelines.append({'name':str(battle.get('defender_name','수비대')),'rounds':battle['timeline']})
		for wave in battle.get('battle_summaries',[]):
			if wave is Dictionary and wave.get('timeline',[]) is Array and not wave.get('timeline',[]).is_empty():timelines.append({'name':str(battle.get('attacker_name','집결 부대'))+' → '+str(wave.get('defender_name','수비대')),'rounds':wave['timeline']})
	for battle in timelines:
		timeline_box.add_child(_label(str(battle['name'])+' · 교전 경과',17,GOLD))
		for step in battle['rounds']:
			var line:=_label('%02d턴  ·  아군 HP %d  /  적군 HP %d\n공격 피해 %d · 반격 피해 %d'%[int(step.get('round',0)),int(step.get('attacker_hp',0)),int(step.get('defender_hp',0)),int(step.get('attacker_damage',0)),int(step.get('defender_damage',0))],14,TEXT)
			line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			timeline_box.add_child(line)
	timeline_box.add_child(log_label)
	_campaign_text(timeline_box, "현재 원정대 · 전술 %s · 피로 %d%%\n%s · 주둔 %d/%d" % [WorldCampaignRules.stance_name(world_state.battle_stance), world_state.army_fatigue,
		supply_network.supply_status_text(world_state, world_state.army_position, faction), conflict_state.garrison_count(world_state.army_position), conflict_state.capacity_at(world_state, world_state.army_position)], 15, GOLD)
	_add_frontline_actions(timeline_box)
	_campaign_text(timeline_box, "다음 행동은 과거 보고서 좌표가 아닌 현재 부대 위치에 적용합니다.", 14, MUTED)
	for action: String in ["garrison", "return", "target"]:
		var follow: Button = _button({"garrison": "현재 위치 수비 등록", "return": "수도 귀환", "target": "다음 목표 찾기"}[action], Vector2(0, 44), UI.SOFT)
		follow.name = "WarAfterBattle_" + action
		follow.disabled = march_state.active or (action == "garrison" and not supply_network.can_reinforce(world_state, world_state.army_position, faction))
		follow.pressed.connect(_after_battle_action.bind(action, popup))
		timeline_box.add_child(follow)
	var close := _button("전선으로 돌아가기", Vector2(0, 44), UI.PRIMARY)
	close.name='WarModalClose'
	close.pressed.connect(popup.queue_free)
	box.add_child(close)
	close.grab_focus.call_deferred()

func _has_ready_squad() -> bool:
	for unit in attacker_squad:
		if float(world_state.army_wounds.get(str(unit.get('id','')),1.0))>0.0 and int(unit.get('max_hp',unit.get('hp',0)))>0: return true
	return false

func _refresh_order_guidance(plan: Dictionary, owner: String) -> void:
	var marching: bool=march_state!=null and march_state.active
	if marching:
		order_hint.text='행군 중입니다. 취소 시 군량의 50%를 돌려받습니다.'
		return
	var ready:=_has_ready_squad()
	var reason:=''
	var conquering:=owner!=faction
	if conquering and season_state!=null and season_state.phase!='active': reason='시즌 정산 중 · 시즌 메뉴에서 보상을 확인하세요.'
	elif not ready: reason='출전 가능한 영웅이 없습니다. 수도에서 부상을 회복하세요.'
	elif (owner==world_state.enemy_faction() or world_state.neutral_guard_level(selected_cell)>0) and not world_state.can_launch_combat(): reason='피로 %d%% · 수도 귀환으로 회복하세요.'%world_state.army_fatigue
	elif conquering and not supply_network.is_supply_connected(world_state,world_state.army_position,faction): reason='출발지 보급이 끊겼습니다. 수도로 귀환하세요.'
	elif owner==world_state.enemy_faction() and world_state.is_protected_from_enemy(selected_cell,faction): reason=world_state.protection_text(selected_cell)+' · 공격 불가'
	elif selected_cell==world_state.army_position: reason='현재 주둔지입니다. 수비 등록 또는 다른 영토를 선택하세요.'
	elif plan.is_empty(): reason='아군 영토를 연결해야 이동할 수 있습니다.'
	elif world_state.rations<int(plan.get('ration_cost',0)): reason='군량 %d 부족 · 자동사냥 또는 영토 생산으로 보충하세요.'%(int(plan['ration_cost'])-world_state.rations)
	else: reason='출정 가능 · %d칸 · %.1f초 · 군량 %d'%[int(plan['distance']),float(plan['duration_seconds']),int(plan['ration_cost'])]
	order_hint.text=reason
	if conquering and (not ready or not supply_network.is_supply_connected(world_state,world_state.army_position,faction)):
		action_button.disabled=true;rally_button.disabled=true
	if not ready: support_button.disabled=true
	if owner==faction and selected_cell==world_state.army_position and ready and (season_state==null or season_state.phase=='active'):
		for force in conflict_state.garrisons_at(selected_cell):
			if str(force.get('force_id',''))=='player_local':
				support_button.text='수비대 갱신'
				support_button.disabled=not supply_network.can_reinforce(world_state,selected_cell,faction)

func _map_command(kind: int) -> void:
	match kind:
		-1: map_view.set_zoom(map_view.zoom/1.4)
		1: map_view.set_zoom(map_view.zoom*1.4)
		0:
			map_view.map_filter='all'
			map_view.set_zoom(1.0)
		5,6:
			var next_filter:='resources' if kind==5 else 'forts'
			map_view.map_filter='all' if map_view.map_filter==next_filter else next_filter
			map_view.queue_redraw()
		2: map_view.focus_army()
		3: _recommend_target()
		4:
			map_view.show_supply=not map_view.show_supply
			map_view.queue_redraw()
			get_node('WarMapPanel').find_child('WarMapTool4',true,false).text='보급' if map_view.show_supply else '보급 꺼짐'
	for id in [5,6]:
		var filter_button: Button=find_child('WarMapTool'+str(id),true,false)
		filter_button.text=('자원 ✓' if map_view.map_filter=='resources' else '자원') if id==5 else ('성곽 ✓' if map_view.map_filter=='forts' else '성곽')
	if is_instance_valid(minimap):minimap.queue_redraw()

func _recommend_target(purpose: String = "nearby") -> void:
	if march_state.active:
		_on_tile_selected(march_state.target); map_view.focus_cell(march_state.target)
		return
	if purpose == "nearby" and map_view.map_filter in ["resources", "forts"]:
		purpose = map_view.map_filter
	var recommendation: Dictionary = WorldCampaignRules.recommend(world_state, march_state, supply_network, attacker_squad, purpose, season_state == null or season_state.phase == "active")
	if recommendation.is_empty():
		status_label.text = "현재 출정 조건에 맞는 목표가 없습니다. 부상·군량·보급·보호기간을 확인하세요."
		return
	var cell: Vector2i = recommendation["target"]
	_on_tile_selected(cell); map_view.focus_cell(cell)
	status_label.text = "%s · %d칸 · 군량 %d · 승리 보장이 아니므로 정찰 후 출정하세요." % [recommendation["reason"], recommendation["distance"], recommendation["cost"]]

func _recommend_and_scout(purpose: String) -> void:
	if march_state.active: return
	_recommend_target(purpose)
	if is_instance_valid(_active_modal): _active_modal.queue_free()
	# User remains on the map; selecting a suggestion never spends rations.


func _campaign_text(parent: Node, text_value: String, font_size:=16, color:=TEXT) -> Label:
	var label:=_label(text_value,font_size,color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _show_campaign_preparation() -> void:
	if world_state==null or not world_state.in_bounds(selected_cell):return
	_refresh()
	var cell:=selected_cell
	var intelligence:=WorldCampaignRules.scout(world_state,conflict_state,cell,party_power,attacker_squad)
	var plan:=march_state.plan(world_state,cell)
	var popup:=_modal_panel('WarCampaignPreparation',Vector2(650,820))
	_preparation_snapshot = WorldCampaignRules.preparation_snapshot(world_state, conflict_state, march_state, cell, party_power, attacker_squad)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override('separation',12)
	popup.add_child(box)
	_campaign_text(box,'영토 정찰 · 출정 준비',26,GOLD)
	_campaign_text(box,'%s · %s (%d,%d)'%[world_state.province_name(cell),world_state.tile_display_name(cell),cell.x,cell.y],18,TEXT)
	var scroll:=ScrollContainer.new()
	scroll.name='WarCampaignScroll'
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override('separation',14)
	scroll.add_child(body)
	var risk:=str(intelligence.get('risk','교전 없음'))
	var risk_color:=RED if risk=='위험' else (GOLD if risk=='접전' else GREEN)
	_campaign_text(body,'예상 전황 · '+risk,22,risk_color)
	_campaign_text(body,'우리 전력 %d  /  수비 전력 %d\n수비 %d부대 · 지형 방어 ×%.2f'%[int(intelligence.get('attacker_strength',0)),int(intelligence.get('defender_strength',0)),int(intelligence.get('forces',0)),float(intelligence.get('terrain_defense',1))],16,TEXT)
	_campaign_text(body,'선택 전술·부상·피로·지형을 실전과 같은 계산으로 반영합니다. 전력 합계는 추정치이며 타깃·회복·여러 수비대의 순차 교전으로 결과가 달라집니다.',14,MUTED)
	var guard_level:=int(intelligence.get('guard_level',0))
	if guard_level>0:_campaign_text(body,'Lv.%d 영토 수비대를 격파해야 점령할 수 있습니다.\n실패 시 원 주둔지로 복귀하며 양측 부상은 유지됩니다.'%guard_level,15,GOLD)
	_campaign_text(body,_owner_name(world_state.tile_owner(cell))+' 소유 · '+world_state.tile_resource_text(cell),16,TEXT)
	var protection:=world_state.protection_text(cell)
	if not protection.is_empty():_campaign_text(body,'보호 · '+protection,15,GOLD)
	if plan.is_empty():_campaign_text(body,order_hint.text,15,RED)
	else:
		_campaign_text(body,'행군 %d칸 · 도착 %.1f초\n군량 %d / 보유 %d · 피로 %d%%'%[int(plan['distance']),float(plan['duration_seconds']),int(plan['ration_cost']),world_state.rations,world_state.army_fatigue],17,TEXT)
		_campaign_text(body,order_hint.text,14,MUTED)
	var reserve: Dictionary=WorldFrontlineRules.return_reserve(world_state,march_state,cell)
	if not reserve.is_empty():
		_campaign_text(body,"원위치 왕복 군량 %d · 출정 후 잔여 %d · 귀환분 부족 %d\n현재 경로가 유지되고 점령에 성공했을 때의 예상입니다. 수도 귀환 비용과는 다릅니다." % [int(reserve.outbound)+int(reserve["return"]),reserve.remaining,reserve.shortfall],15,RED if int(reserve.shortfall)>0 else MUTED).name="WarReturnReserve"
	_add_frontline_actions(body)
	_campaign_text(body,'출정 전술',18,GOLD)
	var tactics:=HBoxContainer.new()
	tactics.add_theme_constant_override('separation',8)
	body.add_child(tactics)
	for stance: String in WorldCampaignRules.STANCES:
		var button:=_button(WorldCampaignRules.stance_name(stance)+(' · 선택' if world_state.battle_stance==stance else ''),Vector2(0,46),UI.SOFT)
		button.name='WarStance_'+stance
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.disabled=march_state.active
		button.pressed.connect(_choose_campaign_stance.bind(stance,cell))
		tactics.add_child(button)
	_campaign_text(body,WorldCampaignRules.stance_description(world_state.battle_stance),15,GREEN)
	_campaign_text(body,'출전 편성 · %d명'%attacker_squad.size(),18,GOLD)
	for unit in attacker_squad:
		var wound:=float(world_state.army_wounds.get(str(unit.get('id','')),1.0))
		var row:=PanelContainer.new()
		row.add_theme_stylebox_override('panel',_style(PANEL,UI.BORDER,8,1))
		body.add_child(row)
		_campaign_text(row,'%s · %s / %s\n잔존 HP %d%% · 공격 %d · 방어 %d'%[str(unit.get('name','영웅')),str(unit.get('row','중열')),str(unit.get('role','딜러')),int(round(wound*100)),int(unit.get('attack',0)),int(unit.get('defense',0))],15,RED if wound<=0 else TEXT)
	if attacker_squad.is_empty():_campaign_text(body,'로비에서 출전 영웅을 편성하세요.',16,RED)
	_campaign_text(body, "다른 공략 목표 찾기 · 선택만 하며 자동 출정하지 않음", 16, GOLD)
	for goal: String in ["resources", "supply", "forts"]:
		var target_button: Button = _button({"resources": "자원 확보", "supply": "끊긴 보급 연결", "forts": "요새 공략"}[goal], Vector2(0, 44), UI.SOFT)
		target_button.name = "WarGoal_" + goal
		target_button.disabled = march_state.active
		target_button.pressed.connect(_recommend_and_scout.bind(goal))
		body.add_child(target_button)
	var message:=_campaign_text(box,'출정 후에는 경로를 따라 이동하며, 도착 시 교전합니다.',14,MUTED)
	message.name='WarPreparationMessage'
	var confirm:=_button('출정 확정 · 군량 %d'%int(plan.get('ration_cost',0)),Vector2(0,48),UI.PRIMARY)
	confirm.name='WarConfirmMarch'
	confirm.disabled=action_button.disabled or plan.is_empty() or march_state.active
	confirm.pressed.connect(_confirm_campaign.bind(cell,plan.duplicate(true),_preparation_serial))
	box.add_child(confirm)
	var close:=_button('지도로 돌아가기',Vector2(0,44),UI.SOFT)
	close.name='WarModalClose'
	close.pressed.connect(popup.queue_free)
	box.add_child(close)
	close.grab_focus.call_deferred()

func _choose_campaign_stance(stance: String, cell: Vector2i) -> void:
	if client_session==null or cell!=selected_cell:return
	var result:=client_session.send('set_stance',{'stance':stance},attacker_squad,party_power)
	_handle_authority_result(result)
	if bool(result.get('ok',false)):_show_campaign_preparation()
	elif is_instance_valid(_active_modal):
		var message: Label=_active_modal.find_child('WarPreparationMessage',true,false)
		if message!=null:message.text=status_label.text

func _confirm_campaign(cell: Vector2i, quoted_plan: Dictionary, quote_serial: int = -1) -> void:
	if client_session == null: return
	# A closed/replaced dialog cannot issue a second command after arrival.
	if quote_serial != _preparation_serial or not is_instance_valid(_active_modal) or _active_modal.is_queued_for_deletion() or _active_modal.name != "WarCampaignPreparation": return
	_refresh()
	var check: Dictionary = WorldCampaignRules.march_check(world_state, march_state, supply_network, cell, attacker_squad, season_state == null or season_state.phase == "active")
	var latest_snapshot: Dictionary = WorldCampaignRules.preparation_snapshot(world_state, conflict_state, march_state, cell, party_power, attacker_squad)
	if selected_cell != cell or check["plan"] != quoted_plan or not bool(check["ok"]) or latest_snapshot != _preparation_snapshot:
		_show_campaign_preparation()
		var message: Label = _active_modal.find_child("WarPreparationMessage", true, false)
		message.text = "전술·편성·부상 또는 전선 조건이 바뀌었어요. 다시 확인하세요. " + str(check["reason"])
		return
	_preparation_serial += 1
	_preparation_snapshot.clear()
	_active_modal.queue_free()
	_perform_selected_action()

func _after_battle_action(action: String, popup: PanelContainer) -> void:
	if not is_instance_valid(popup) or popup.is_queued_for_deletion() or popup != _active_modal or march_state.active: return
	popup.queue_free()
	selected_cell = world_state.army_position
	match action:
		"garrison": _start_support_march()
		"return": _return_to_capital()
		"target": _recommend_target()

func _add_frontline_actions(parent: Node) -> void:
	var bases: Array=WorldFrontlineRules.nearby_bases(world_state,march_state,supply_network)
	_campaign_text(parent,"전선 거점 · 이동 전 확인",17,GOLD)
	for base in bases:
		var cell: Vector2i=base["target"]
		var button: Button=_button("%s (%d,%d) · %d칸 · 군량 %d" % [world_state.tile_display_name(cell),cell.x,cell.y,int(base.plan.distance),int(base.plan.ration_cost)],Vector2(0,44),UI.SOFT)
		button.name="WarBase_%d_%d"%[cell.x,cell.y]
		button.disabled=not bool(base.affordable)
		button.pressed.connect(_review_frontline_base.bind(cell))
		parent.add_child(button)
	var rest: Button=_button("현재 거점 재정비",Vector2(0,44),UI.SOFT)
	rest.name="WarRestOpen";rest.disabled=march_state.active
	rest.pressed.connect(_show_frontline_rest)
	parent.add_child(rest)
func _review_frontline_base(cell: Vector2i) -> void:
	if march_state.active or world_state.tile_owner(cell)!=faction or world_state.tile_type(cell) not in ["fort","citadel","capital"]:return
	selected_cell=cell
	_show_campaign_preparation()
func _show_frontline_rest() -> void:
	if march_state.active:return
	_refresh()
	var force: Dictionary=client_session.authority.trusted_force(client_session.player_id,world_state)
	var quote: Dictionary=WorldFrontlineRules.rest_quote(world_state,march_state,supply_network,force.get("squad",[]))
	var popup: PanelContainer=_modal_panel("WarFrontlineRest",Vector2(620,520))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",14);popup.add_child(box)
	_campaign_text(box,"전선 거점 재정비",24,GOLD)
	_campaign_text(box,"보급이 연결된 아군 요새·대성에서 피로를 최대20 줄이고, 출전 영웅의 잔존HP 비율을 최대15%p 회복합니다. 군량을 사용하며 장시간 대기는 없습니다.",17)
	_campaign_text(box,"현재 수비·집결 등록은 해제됩니다. 정비 후 필요하면 다시 등록하세요. 수도 귀환 회복은 기존대로 유지됩니다.",16,MUTED)
	_campaign_text(box,"군량 %d / 보유 %d · 피로 %d 감소 · 회복 대상 %d명"%[quote.cost,world_state.rations,quote.fatigue_drop,quote.wounds.size()],18)
	if not quote.ok:_campaign_text(box,str(quote.reason),17,RED)
	var confirm:=_button("정비 확정 · 군량 %d"%quote.cost,Vector2(0,48),UI.PRIMARY)
	confirm.name="WarRestConfirm";confirm.disabled=not quote.ok
	confirm.pressed.connect(_confirm_frontline_rest.bind(popup,str(quote.key),world_state.army_position))
	box.add_child(confirm)
	var close:=_button("취소",Vector2(0,44),UI.SOFT);close.name="WarModalClose";close.pressed.connect(popup.queue_free);box.add_child(close)
func _confirm_frontline_rest(popup, key: String, cell: Vector2i) -> void:
	if not is_instance_valid(popup) or popup!=_active_modal or popup.is_queued_for_deletion():return
	popup.queue_free()
	var result: Dictionary=client_session.send("rest_army",{"target":[cell.x,cell.y],"quote_key":key},attacker_squad,party_power)
	_handle_authority_result(result)
	if not bool(result.get("ok",false)):status_label.text="정비 조건이 바뀌었거나 부족합니다. 다시 확인하세요."
