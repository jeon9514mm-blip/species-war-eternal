extends "res://scripts/portrait/PortraitRaid.gd"
## A landscape combat-first layout. Inherits all selection, move, dodge, manual
## casting, death/retry and report behavior; only presentation is replaced.
const SCENERY=preload("res://scripts/art/RaidSceneryCatalog.gd")
var battle_hint: Label
var phase_readout: Label
var options_sheet: Control
var arena_body: Control
var header_title: Label
var time_readout: Label
var _action_state := ''
func _new_battlefield() -> Control:
	return preload("res://scripts/art/RaidArenaBattlefield.gd").new()

func _wide_layout(body: Control,summary: Control,status: Control,actions: Control,party: Control,heading: Control,w: float,h: float) -> void:
	for node_name in ["PortraitMenuHeader","PortraitNavigation"]:
		var obsolete: Node=game.content_root.get_node_or_null(node_name)
		if obsolete!=null:obsolete.free()
	arena_body=body
	var profile: Dictionary=SCENERY.profile(str(game.raid_encounter_zone))
	var accent: Color=profile.accent
	SKIN.panel(self,Rect2(0,0,w,80),SKIN.SURFACE,SKIN.EDGE_SOFT,1,0)
	var back:=SKIN.button("‹  콘텐츠",Callable(game,"_build_boss_select_screen"))
	back.name="RaidArenaBack";back.add_theme_font_size_override("font_size",17)
	SKIN.place(self,back,Rect2(14,14,132,52))
	var place_label:=_text(str(profile.title),18,SKIN.INK)
	place_label.name="RaidArenaLocation";place_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	place_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	place_label.tooltip_text=str(profile.title)
	SKIN.place(self,place_label,Rect2(164,15,w*.27-174,29))
	var note:=_text("미리보기 · 저장 없음" if bool(game.get_meta("art_direction_lab",false)) else "레이드",12,SKIN.MUTED)
	SKIN.place(self,note,Rect2(164,44,w*.27-174,20))
	var head_x: float=w*.29
	var head_w: float=w*.46
	header_title=_text(str(game._raid_zone().boss),22,SKIN.INK)
	header_title.name="RaidBossHeadline";header_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	header_title.autowrap_mode=TextServer.AUTOWRAP_OFF
	header_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	SKIN.place(self,header_title,Rect2(head_x,8,head_w,28))
	information.reparent(self,false);information.set_anchors_preset(Control.PRESET_TOP_LEFT)
	information.position=Vector2(head_x,37);information.size=Vector2(head_w,24)
	information.add_theme_font_size_override("font_size",13);information.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	information.autowrap_mode=TextServer.AUTOWRAP_OFF
	hp.reparent(self,false);hp.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hp.position=Vector2(head_x,65);hp.size=Vector2(head_w,7)
	hp.add_theme_stylebox_override('background',SKIN.box(SKIN.DARK,Color.TRANSPARENT,4,0))
	hp.add_theme_stylebox_override('fill',SKIN.box(SKIN.SUCCESS,Color.TRANSPARENT,4,0))
	var clock:=SKIN.panel(self,Rect2(w-290,10,116,60),SKIN.SURFACE_2,SKIN.EDGE_SOFT,1,10)
	clock.name='RaidTimePanel'
	time_readout=_text('',25,SKIN.INK);time_readout.name='RaidTimeRemaining'
	time_readout.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(clock,time_readout,Rect2(4,3,108,32))
	phase_readout=_text('',12,SKIN.MUTED);phase_readout.name='RaidPhaseReadout'
	phase_readout.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(clock,phase_readout,Rect2(4,36,108,20))
	var options:=SKIN.button("공략 · 설정",_open_options)
	options.name="RaidOptionsButton";options.add_theme_font_size_override("font_size",16)
	SKIN.place(self,options,Rect2(w-160,14,146,52))
	# The full-width viewport keeps visual floor, hit FX and input on the same
	# inherited transform. Combat controls live in a separate lower command row.
	_make_options(summary,status)
	rewards.reparent(options_sheet.get_node("RaidOptionsPanel/Margin/Scroll/Column"),false)
	rewards.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.position=Vector2(12,86);body.size=Vector2(w-24,h-282)
	stage.custom_minimum_size=Vector2(0,208)
	for node_name in ["PortraitRaidArenaFrame","PortraitRaidMoveHint"]:
		var obsolete: CanvasItem=stage.get_node_or_null(node_name)
		if obsolete!=null:obsolete.hide()
	cue.add_theme_font_size_override("font_size",22)
	cue.offset_top=8;cue.offset_bottom=46;cue.offset_left=w*.20;cue.offset_right=-w*.20
	cast_bar.offset_top=49;cast_bar.offset_bottom=54;cast_bar.offset_left=w*.25;cast_bar.offset_right=-w*.25
	# Keep transient phase hints away from the party and the central warning strip.
	phase_banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	phase_banner.offset_left=18;phase_banner.offset_right=408
	phase_banner.offset_top=64;phase_banner.offset_bottom=148
	phase_banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	phase_banner.add_theme_font_size_override('font_size',18)
	phase_banner.add_theme_stylebox_override('normal',SKIN.box(Color(SKIN.SURFACE,.90),Color(accent,.55),10,1))
	battle_hint=_text("",15,SKIN.INK)
	battle_hint.name="RaidBattleHint";battle_hint.autowrap_mode=TextServer.AUTOWRAP_OFF
	battle_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	battle_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	battle_hint.add_theme_stylebox_override("normal",SKIN.box(Color(SKIN.SURFACE,.88),Color(SKIN.EDGE_SOFT,.7),10,1))
	stage.add_child(battle_hint);battle_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	battle_hint.offset_left=20;battle_hint.offset_right=-20;battle_hint.offset_top=-47;battle_hint.offset_bottom=-10
	var dock:=SKIN.panel(self,Rect2(0,h-190,w,190),SKIN.SURFACE,SKIN.EDGE_SOFT,1,0)
	move_child(dock,0)
	formation.reparent(options_sheet.get_node("RaidOptionsPanel/Margin/Scroll/Column"),false)
	formation.custom_minimum_size.y=56
	actions.add_theme_constant_override("separation",8)
	actions.position=Vector2(14,h-180);actions.size=Vector2(w-28,62)
	follow_button.reparent(actions,false);follow_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	actions.move_child(follow_button,0)
	dodge_button.reparent(actions,false);dodge_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for button in [follow_button,skill_cast_button,ultimate_cast_button,start,dodge_button]:
		button.custom_minimum_size=Vector2(130,62);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.size_flags_stretch_ratio=1.0;button.add_theme_font_size_override("font_size",18)
	dodge_button.size_flags_stretch_ratio=1.3;start.size_flags_stretch_ratio=1.2
	follow_button.text='추적 복귀'
	_style_command(skill_cast_button,SKIN.SUCCESS,false)
	_style_command(ultimate_cast_button,SKIN.GOLD,false)
	heading.hide()
	_layout_party_strip(party,Vector2(14,h-112),w-28)
	var party_scroll: ScrollContainer=get_node("RaidPartyScroll")
	# Touch/wheel scrolling stays enabled without reserving a scrollbar below
	# the large hero cards. The partially visible final card signals more heroes.
	party_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	party_scroll.size=Vector2(w-28,112)
	# This raid-specific route has a back button instead of the shared 90px dock.
	game.content_root.set_meta("raid_cinematic",true)
	telegraph.accent=Color("#ff7569")

func _make_options(summary: Control,status: Control) -> void:
	options_sheet=Control.new();options_sheet.name="RaidOptionsSheet";options_sheet.z_index=110
	add_child(options_sheet);options_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new();shade.color=Color(0,0,0,.72)
	options_sheet.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent):
		# Touch emulation dispatches mouse and finger events for one gesture.
		# Keep the modal in place until both release events have been consumed.
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			shade.accept_event()
			if not event.pressed:options_sheet.hide.call_deferred()
		elif event is InputEventScreenTouch:
			shade.accept_event()
			if not event.pressed and not event.canceled:options_sheet.hide.call_deferred())
	var panel:=PanelContainer.new();panel.name="RaidOptionsPanel"
	panel.add_theme_stylebox_override("panel",SKIN.elevated(SKIN.SURFACE))
	SKIN.place(options_sheet,panel,Rect2(size.x*.50,20,size.x*.50-20,size.y-40))
	var margin:=MarginContainer.new();margin.name="Margin";panel.add_child(margin)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,18)
	var scroll:=ScrollContainer.new();scroll.name="Scroll";SKIN.make_scroll_responsive(scroll);margin.add_child(scroll)
	var column:=VBoxContainer.new();column.name="Column";column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12);scroll.add_child(column)
	var sheet_heading:=_text('레이드 안내',23,SKIN.INK)
	column.add_child(sheet_heading)
	var close:=SKIN.button("닫기",options_sheet.hide)
	close.name="RaidOptionsClose";close.custom_minimum_size.y=48;column.add_child(close)
	summary.reparent(column,false);status.reparent(column,false);status.custom_minimum_size.y=220
	for button in [skill_auto_button,ultimate_auto_button]:
		button.reparent(column,false);button.custom_minimum_size=Vector2(0,56)
	options_sheet.hide()

func _style_command(button: Button,accent: Color,primary: bool) -> void:
	# A restrained semantic tint distinguishes casts without adding full-screen FX.
	var fill: Color=accent if primary else SKIN.SURFACE_2.lerp(accent,.12)
	for state: String in ['normal','hover','pressed']:
		var shade: Color=fill.lightened(.06) if state=='hover' else (fill.darkened(.08) if state=='pressed' else fill)
		var style:=SKIN.box(SKIN.SURFACE,accent if primary else Color(accent,.45),10,1)
		style.bg_color=shade
		style.content_margin_left=12;style.content_margin_right=12
		button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override('font_'+('color' if state=='normal' else state+'_color'),SKIN.DARK if primary else SKIN.INK)
	button.add_theme_color_override('font_focus_color',SKIN.DARK if primary else SKIN.INK)

func _open_options() -> void:
	options_sheet.show()

func _settle_stage_layout(body: Control,w: float,h: float) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(body):return
	body.size=Vector2(w-24,h-282)
	await get_tree().process_frame
	_layout_arena()

func refresh() -> void:
	super.refresh()
	if not is_instance_valid(battle_hint):return
	if game.raid_running:
		var mechanic: Dictionary=game._raid_mechanic_status()
		battle_hint.text=str(mechanic.get("label",""))
		if game.boss_telegraph_pending or game.raid_second_wave_remaining>0.0:
			var pattern: Dictionary=game.raid_second_wave_profile if game.raid_second_wave_remaining>0.0 else game.raid_cast_profile
			battle_hint.text=str(pattern.get("counter","위험 구역 밖으로 이동하거나 회피하세요."))
		if battle_hint.text.is_empty():
			battle_hint.text="바닥 터치 · 이동     붉은 구역 · 회피"
	elif not game.raid_last_result.is_empty():
		battle_hint.text="클리어 · 공략·설정에서 보상과 기록 확인" if str(game.raid_outcome)=="victory" else "전투 종료 · 다시 도전하거나 성장 점검"
	else:
		battle_hint.text="권장 %s  ·  원정대 %s  ·  레이드 시작" % [game._compact_hud_amount(int(BALANCE.stats(game._raid_zone()).recommended_power)),game._compact_hud_amount(game.party_power)]
	var encounter_started: bool=game.raid_running or not game.raid_last_result.is_empty()
	var health: int=int(game.raid_boss_hp) if encounter_started else int(BALANCE.stats(game._raid_zone()).max_hp)
	var max_health: int=int(game.raid_boss_max_hp) if encounter_started else health
	information.text='HP %s  /  %s    ·    %d%%'%[game._compact_hud_amount(health),game._compact_hud_amount(max_health),roundi(hp.value)]
	var remaining: int=maxi(0,ceili(game.RAID_TIME_LIMIT-game.raid_elapsed))
	time_readout.text='%02d:%02d'%[remaining/60,remaining%60]
	time_readout.add_theme_color_override('font_color',SKIN.GOLD if game.raid_running and remaining<=30 else SKIN.INK)
	phase_readout.text='%d단계 · %s'%[game.raid_phase,'광폭화' if game.raid_enraged else ('진행 중' if game.raid_running else '준비')]
	if not game.raid_last_result.is_empty() and not game.raid_running:phase_readout.text='클리어' if str(game.raid_outcome)=='victory' else '전투 종료'
	# Preparation has one start action. During combat the available width belongs
	# to movement and casts; rebuilding no game state is necessary for this change.
	start.visible=not game.raid_running
	var action_state: String='%s:%s'%[str(game.raid_running),str(not ultimate_cast_button.disabled)]
	if action_state!=_action_state:
		_action_state=action_state
		_style_command(ultimate_cast_button,SKIN.GOLD,game.raid_running and not ultimate_cast_button.disabled)
