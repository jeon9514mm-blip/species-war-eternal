extends "res://scripts/portrait/PortraitRaid.gd"
## A landscape combat-first layout. Inherits all selection, move, dodge, manual
## casting, death/retry and report behavior; only presentation is replaced.
const SCENERY=preload("res://scripts/art/RaidSceneryCatalog.gd")
var battle_hint: Label
var phase_readout: Label
var options_sheet: Control
var arena_body: Control
var header_title: Label
func _new_battlefield() -> Control:
	return preload("res://scripts/art/RaidArenaBattlefield.gd").new()

func _wide_layout(body: Control,summary: Control,status: Control,actions: Control,party: Control,heading: Control,w: float,h: float) -> void:
	for node_name in ["PortraitMenuHeader","PortraitNavigation"]:
		var obsolete: Node=game.content_root.get_node_or_null(node_name)
		if obsolete!=null:obsolete.free()
	arena_body=body
	var profile: Dictionary=SCENERY.profile(str(game.raid_encounter_zone))
	var accent: Color=profile.accent
	SKIN.panel(self,Rect2(0,0,w,80),Color("#111b26"),Color("#394858"),1,0)
	var back:=SKIN.button("‹  레이드",Callable(game,"_build_boss_select_screen"))
	back.name="RaidArenaBack";back.add_theme_font_size_override("font_size",20)
	SKIN.place(self,back,Rect2(14,12,142,56))
	var place_label:=_text(str(profile.title),20,accent)
	place_label.name="RaidArenaLocation";place_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	SKIN.place(self,place_label,Rect2(172,10,w*.23-170,30))
	var note:=_text("저장 없는 시범" if bool(game.get_meta("art_direction_lab",false)) else "보스 레이드",13,SKIN.MUTED)
	SKIN.place(self,note,Rect2(172,41,w*.23-170,24))
	var head_x: float=w*.29
	var head_w: float=w*.48
	header_title=_text(str(game._raid_zone().boss),24,accent)
	header_title.name="RaidBossHeadline";header_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	header_title.autowrap_mode=TextServer.AUTOWRAP_OFF
	SKIN.place(self,header_title,Rect2(head_x,5,head_w,32))
	information.reparent(self,false);information.set_anchors_preset(Control.PRESET_TOP_LEFT)
	information.position=Vector2(head_x,37);information.size=Vector2(head_w,24)
	information.add_theme_font_size_override("font_size",15);information.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	information.autowrap_mode=TextServer.AUTOWRAP_OFF
	hp.reparent(self,false);hp.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hp.position=Vector2(head_x,65);hp.size=Vector2(head_w,8)
	phase_readout=_text("",16,accent);phase_readout.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(self,phase_readout,Rect2(w-284,12,100,56))
	var options:=SKIN.button("공략 · 설정",_open_options)
	options.name="RaidOptionsButton";options.add_theme_font_size_override("font_size",17)
	SKIN.place(self,options,Rect2(w-176,12,162,56))
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
	phase_banner.offset_top=62;phase_banner.offset_bottom=136
	battle_hint=_text("",16,Color("#eee9d9"))
	battle_hint.name="RaidBattleHint";battle_hint.autowrap_mode=TextServer.AUTOWRAP_OFF
	battle_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	battle_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	battle_hint.add_theme_stylebox_override("normal",SKIN.box(Color("#101b28de"),Color("#8192a866"),10,1))
	stage.add_child(battle_hint);battle_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	battle_hint.offset_left=20;battle_hint.offset_right=-20;battle_hint.offset_top=-47;battle_hint.offset_bottom=-10
	var dock:=SKIN.panel(self,Rect2(0,h-190,w,190),Color("#111b26"),Color("#394858"),1,0)
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
		button.size_flags_stretch_ratio=1.0;button.add_theme_font_size_override("font_size",19)
	dodge_button.size_flags_stretch_ratio=1.3;start.size_flags_stretch_ratio=1.2
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
	var close:=SKIN.button("공략 · 설정 닫기",options_sheet.hide)
	close.name="RaidOptionsClose";close.custom_minimum_size.y=56;column.add_child(close)
	summary.reparent(column,false);status.reparent(column,false);status.custom_minimum_size.y=220
	for button in [skill_auto_button,ultimate_auto_button]:
		button.reparent(column,false);button.custom_minimum_size=Vector2(0,56)
	options_sheet.hide()

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
			battle_hint.text="바닥 터치로 원정대 이동   ·   붉은 위험 구역 밖으로 이동하거나 회피"
	elif not game.raid_last_result.is_empty():
		battle_hint.text="레이드 클리어 · 전리품과 기여도는 공략·설정에서 확인" if str(game.raid_outcome)=="victory" else "원정대 전투 종료 · 다시 도전하거나 공략·설정에서 성장 점검"
	else:
		battle_hint.text="권장 전투력 %s  ·  원정대 %s  ·  준비되면 레이드 시작" % [game._compact_hud_amount(int(BALANCE.stats(game._raid_zone()).recommended_power)),game._compact_hud_amount(game.party_power)]
	phase_readout.text="PHASE %d\n%s" % [game.raid_phase,"광폭화" if game.raid_enraged else "전투 준비"]
	if game.raid_running:phase_readout.text="PHASE %d\n%03d초" % [game.raid_phase,maxi(0,ceili(game.RAID_TIME_LIMIT-game.raid_elapsed))]
