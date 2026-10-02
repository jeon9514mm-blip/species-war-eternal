extends Control
## Raid presentation uses separate flow, action and party areas. Rebuilding this
## view reparents the existing actors without touching their combat state.
const SKIN := preload('res://scripts/portrait/PortraitSkin.gd')
const MENUS := preload('res://scripts/portrait/PortraitMenus.gd')
const HUD := preload('res://scripts/portrait/PortraitHud.gd')
const DESIGN := preload('res://scripts/RaidBossDesign.gd')
const TELEGRAPH := preload('res://scripts/portrait/RaidArenaTelegraph.gd')
const BOSS_MOTION := preload('res://scripts/portrait/RaidBossMotion.gd')
const FIELD := preload('res://scripts/RaidBattlefield.gd')
const BACKGROUNDS := {
	'gray_meadow': 'res://assets/backgrounds/raid-v59/stone-circle.png',
	'forgotten_mine': 'res://assets/backgrounds/raid-v59/crystal-forge.png',
	'moonrest_forest': 'res://assets/backgrounds/raid-v59/eclipse-grove.png',
}
var game: Node
var hp: ProgressBar
var information: Label
var state_label: Label
var state_title: Label
var state_scroll: ScrollContainer
var rewards: Label
var party_summary: Label
var elapsed := 0.0
var start: Button
var formation: Button
var skill_auto_button: Button
var ultimate_auto_button: Button
var skill_cast_button: Button
var ultimate_cast_button: Button
var hero_bars: Dictionary={}
var hero_cards: Dictionary={}
var hero_slots: Dictionary={}
var selected_hero_id := ''
var arena: Control
var battlefield_3d: Control
var stage: Control
var telegraph: Control
var cue: Label
var cast_bar: ProgressBar
var hero_actors: Dictionary={}
var last_hp: Dictionary={}
var last_phase := 1
var phase_flash: ColorRect
var phase_banner: Label
var boss_motion: Node2D
var mechanic_visual: Node2D
var mechanic_tint: ColorRect
var last_enraged := false
var dodge_button: Button
var follow_button: Button
var rally_marker: Node2D
var _dragging := false
var _state_section := ''

func _text(value: String, points: int, color: Color = SKIN.INK) -> Label:
	var result:=SKIN.label(value,points,color)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return result

func _card(parent: Node, named: String) -> VBoxContainer:
	var panel:=PanelContainer.new();panel.name=named
	var style:=SKIN.elevated(SKIN.SURFACE,SKIN.EDGE_SOFT,14)
	style.content_margin_left=14;style.content_margin_right=14
	style.content_margin_top=10;style.content_margin_bottom=10
	panel.add_theme_stylebox_override('panel',style)
	parent.add_child(panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override('separation',4)
	panel.add_child(column)
	return column

func install(main: Node) -> void:
	game=main;name='PortraitRaidView';mouse_filter=Control.MOUSE_FILTER_IGNORE
	var w: float=game.get_viewport_rect().size.x
	var h: float=game.get_viewport_rect().size.y
	size=Vector2(w,h)
	for item: Node in game.content_root.get_children():
		if item is CanvasItem and item!=self and item.z_index<100:item.visible=false
	var zone: Dictionary=game._raid_zone()
	var zone_id: String=str(game.raid_encounter_zone)
	var design: Dictionary=DESIGN.raid(zone_id)
	MENUS.header(game,str(design['type']),'전투 현장에서 영웅과 보스의 움직임을 확인하세요.',Callable(game,'_build_boss_select_screen'))
	var party_y: float=h-304.0
	var actions_y: float=party_y-110.0
	var body:=VBoxContainer.new();body.name='PortraitRaidDetails'
	body.add_theme_constant_override('separation',10)
	SKIN.place(self,body,Rect2(20,144,w-40,actions_y-204))
	var summary:=_card(body,'PortraitRaidSummary')
	var title:=_text(str(zone['boss']),25,SKIN.GOLD)
	title.name='PortraitRaidBossName';title.tooltip_text=title.text
	summary.add_child(title)
	var location:=_text('%s · %s'%[zone['name'],zone['boss_title']],16,SKIN.MUTED)
	summary.add_child(location)
	party_summary=_text('',18,SKIN.BLUE_SOFT);party_summary.name='PortraitRaidPower'
	summary.add_child(party_summary)
	stage=Control.new();stage.name='PortraitRaidArena'
	stage.custom_minimum_size=Vector2(0,208);stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio=3.0;stage.clip_contents=true;stage.mouse_filter=Control.MOUSE_FILTER_STOP
	stage.gui_input.connect(_on_stage_input)
	body.add_child(stage)
	battlefield_3d=preload('res://scripts/maps3d/Battlefield3DView.gd').new()
	battlefield_3d.name='RaidTerrain3D';battlefield_3d.game=game;battlefield_3d.raid_view=self;battlefield_3d.raid_mode=true
	battlefield_3d.configure(zone_id,design['accent'])
	stage.add_child(battlefield_3d);battlefield_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mechanic_tint=ColorRect.new();mechanic_tint.name='PortraitRaidMechanicTint';mechanic_tint.color=Color.TRANSPARENT
	mechanic_tint.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(mechanic_tint)
	mechanic_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame:=Panel.new();frame.name='PortraitRaidArenaFrame';frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override('panel',SKIN.box(Color.TRANSPARENT,Color(design['accent'],.85),16,2))
	stage.add_child(frame);frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena=Control.new();arena.name='PortraitRaidActors';arena.size=Vector2(1280,720)
	arena.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(arena)
	telegraph=TELEGRAPH.new();telegraph.name='PortraitRaidAttackArea';telegraph.size=arena.size
	telegraph.accent=design['accent'];arena.add_child(telegraph)
	boss_motion=BOSS_MOTION.new();boss_motion.name='PortraitRaidBossMotion'
	boss_motion.zone_id=zone_id;boss_motion.accent=design['accent'];arena.add_child(boss_motion)
	mechanic_visual=preload('res://scripts/portrait/RaidMechanicVisual.gd').new()
	mechanic_visual.name='PortraitRaidMechanicVisual';arena.add_child(mechanic_visual);mechanic_visual.bind(game,design['accent'])
	if is_instance_valid(game.raid_boss_sprite):
		game.raid_boss_sprite.reparent(arena,false)
		game.raid_boss_sprite.show()
		boss_motion.actor=game.raid_boss_sprite
		game.raid_boss_sprite.set_world_position(FIELD.ENTRY)
	for i in game.deployed_heroes.size():
		var hero_id: String=str(game.deployed_heroes[i]['id'])
		var actor:=HeroSpriteFactory.create_hero(hero_id,Vector2(.13,.13))
		actor.name='RaidHeroActor_'+hero_id
		actor.position=game.raid_positions.get(hero_id,FIELD.hero_entry(i))
		arena.add_child(actor);actor.play_idle('right')
		hero_actors[hero_id]=actor
		last_hp[hero_id]=float(game.hero_battle_state.get(hero_id,{}).get('hp',0))
	rally_marker=Node2D.new();rally_marker.name='PortraitRaidMoveMarker'
	rally_marker.set_script(preload('res://scripts/portrait/RaidRallyMarker.gd'))
	rally_marker.visible=false;arena.add_child(rally_marker)
	if is_instance_valid(game.skill_fx_layer):
		game.skill_fx_layer.reparent(arena,false)
		game.skill_fx_layer.show()
	phase_flash=ColorRect.new();phase_flash.name='PortraitRaidPhaseFlash';phase_flash.color=Color(design['accent'],0.0)
	phase_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(phase_flash);phase_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_banner=_text('',27,SKIN.GOLD);phase_banner.name='PortraitRaidPhaseBanner'
	phase_banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;phase_banner.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	phase_banner.mouse_filter=Control.MOUSE_FILTER_IGNORE;phase_banner.visible=false
	SKIN.place(stage,phase_banner,Rect2(40,stage.size.y*.34,w-120,72))
	phase_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	phase_banner.offset_left=-260;phase_banner.offset_right=260;phase_banner.offset_top=72;phase_banner.offset_bottom=142
	information=_text('',17)
	information.name='PortraitRaidBossHealth'
	SKIN.place(stage,information,Rect2(14,8,w-68,42))
	information.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	information.offset_left=14;information.offset_right=-14;information.offset_top=8;information.offset_bottom=50
	hp=SKIN.gauge(stage,Rect2(14,56,w-68,10),Color('#f26e79'))
	hp.name='PortraitRaidBossHp'
	hp.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hp.offset_left=14;hp.offset_right=-14;hp.offset_top=56;hp.offset_bottom=66
	cue=_text('',23,Color('#ffdaaa'));cue.name='PortraitRaidWarning'
	cue.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cue.visible=false
	SKIN.place(stage,cue,Rect2(12,83,w-64,38))
	cue.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cue.offset_left=12;cue.offset_right=-12;cue.offset_top=83;cue.offset_bottom=121
	cast_bar=SKIN.gauge(stage,Rect2(16,126,w-72,8),Color('#ff905d'))
	cast_bar.name='PortraitRaidCastGauge';cast_bar.visible=false
	cast_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cast_bar.offset_left=16;cast_bar.offset_right=-16;cast_bar.offset_top=126;cast_bar.offset_bottom=134
	dodge_button=SKIN.button('회피  READY',_on_dodge_pressed,Color('#bd6a48'))
	dodge_button.name='PortraitRaidDodge';dodge_button.tooltip_text='예고된 공격을 피하세요 · 전원 0.5초 무적 · 재사용 5초'
	dodge_button.add_theme_font_size_override('font_size',17)
	SKIN.place(stage,dodge_button,Rect2(0,0,154,43))
	dodge_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	dodge_button.offset_left=-168;dodge_button.offset_right=-14;dodge_button.offset_top=-59;dodge_button.offset_bottom=-16
	follow_button=SKIN.button('자동 추적',_on_follow_pressed,Color('#386968'))
	follow_button.name='PortraitRaidAutoFollow';follow_button.tooltip_text='지정 이동을 취소하고 보스를 자동 추적합니다.'
	follow_button.add_theme_font_size_override('font_size',15)
	SKIN.place(stage,follow_button,Rect2(0,0,120,39))
	follow_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	follow_button.offset_left=14;follow_button.offset_right=134;follow_button.offset_top=-55;follow_button.offset_bottom=-16
	var hint:=_text('바닥 터치 · 이동  /  위험 구역에서 회피',14,Color('#e0e9d8'))
	hint.name='PortraitRaidMoveHint';hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	SKIN.place(stage,hint,Rect2(16,0,w-72,25))
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left=16;hint.offset_right=-16;hint.offset_top=143;hint.offset_bottom=168
	stage.resized.connect(_layout_arena)
	rewards=_text('',17,SKIN.GOLD);rewards.name='PortraitRaidEquipmentRewards'
	body.add_child(rewards)
	var status_column:=_card(body,'PortraitRaidStatePanel')
	var status_panel:=status_column.get_parent() as Control
	status_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	state_title=_text('공략 안내',18,SKIN.BLUE_SOFT)
	status_column.add_child(state_title)
	state_scroll=ScrollContainer.new();state_scroll.name='PortraitRaidStatus'
	state_scroll.custom_minimum_size=Vector2(0,54)
	state_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	SKIN.make_scroll_responsive(state_scroll)
	status_column.add_child(state_scroll)
	state_label=_text('',18)
	state_label.name='PortraitRaidStateText';state_label.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	state_scroll.add_child(state_label)
	var actions:=HBoxContainer.new();actions.name='PortraitRaidActions'
	actions.add_theme_constant_override('separation',10)
	SKIN.place(self,actions,Rect2(20,actions_y,w-40,62))
	var auto_width: float=(w-50)*.5
	skill_auto_button=SKIN.button('',_toggle_skill_auto,Color('#285f69'))
	skill_auto_button.name='PortraitRaidSkillAuto'
	skill_auto_button.tooltip_text='액티브 스킬 1·2의 자동 사용'
	skill_auto_button.add_theme_font_size_override('font_size',17)
	SKIN.place(self,skill_auto_button,Rect2(20,actions_y-50,auto_width,40))
	ultimate_auto_button=SKIN.button('',_toggle_ultimate_auto,Color('#605076'))
	ultimate_auto_button.name='PortraitRaidUltimateAuto'
	ultimate_auto_button.tooltip_text='각성기(궁극기)의 자동 사용'
	ultimate_auto_button.add_theme_font_size_override('font_size',17)
	SKIN.place(self,ultimate_auto_button,Rect2(30+auto_width,actions_y-50,auto_width,40))
	formation=SKIN.button('편성 변경',_open_formation,SKIN.SURFACE_2)
	formation.name='PortraitRaidFormation';formation.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	formation.size_flags_stretch_ratio=.85;actions.add_child(formation)
	skill_cast_button=SKIN.button('스킬 사용',_on_manual_skill,Color('#356e81'))
	skill_cast_button.name='PortraitRaidCastSkill';skill_cast_button.tooltip_text='사용 가능한 영웅의 스킬을 즉시 사용'
	skill_cast_button.add_theme_font_size_override('font_size',16)
	skill_cast_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(skill_cast_button)
	ultimate_cast_button=SKIN.button('각성기 사용',_on_manual_ultimate,Color('#685289'))
	ultimate_cast_button.name='PortraitRaidCastUltimate';ultimate_cast_button.tooltip_text='준비된 영웅의 각성기를 즉시 사용'
	ultimate_cast_button.add_theme_font_size_override('font_size',16)
	ultimate_cast_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(ultimate_cast_button)
	start=SKIN.button('레이드 시작',Callable(game,'_start_raid'),Color('#527965'))
	start.name='PortraitRaidStart';start.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(start)
	game.combat_labels['raid_start']=start
	var report_button=SKIN.button('레이드 분석 · 최근 기록',Callable(game,'_open_raid_report'),SKIN.SURFACE_2)
	report_button.name='RaidContributionOpen'
	report_button.custom_minimum_size=Vector2(0,44)
	summary.add_child(report_button)
	game.combat_labels['raid_report']=report_button
	var party_heading:=_text('출전 원정대 · %d / 10명'%game.deployed_heroes.size(),19,SKIN.MUTED)
	party_heading.name='PortraitRaidPartyHeading'
	SKIN.place(self,party_heading,Rect2(22,party_y-36,w-44,28))
	var row:=Control.new();row.name='PortraitRaidParty'
	SKIN.place(self,row,Rect2(20,party_y,w-40,196))
	var cell: float=(w-40-32)/5.0
	for i in 10:
		var slot:=SKIN.panel(row,Rect2((i%5)*(cell+8),(i/5)*102,cell,94),SKIN.SURFACE,SKIN.EDGE_SOFT,1)
		slot.name='PortraitRaidSlot%d'%i
		if i>=game.deployed_heroes.size():
			var empty:=SKIN.label('대기',17,SKIN.MUTED_DARK)
			empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			SKIN.place(slot,empty,Rect2(4,30,cell-8,30))
			continue
		var id:=str(game.deployed_heroes[i]['id'])
		if selected_hero_id.is_empty():selected_hero_id=id
		slot.mouse_filter=Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_hero_slot_input.bind(id))
		hero_slots[id]=slot
		var art:=TextureRect.new();art.texture=game._combat_portrait_texture(id)
		art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		SKIN.place(slot,art,Rect2(3,2,cell-6,56))
		var caption:=SKIN.label(str(game._hero_short_name(id)),17)
		caption.name='PortraitRaidHeroName_'+id
		caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.tooltip_text=str(game.deployed_heroes[i]['name'])
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		SKIN.place(slot,caption,Rect2(4,59,cell-8,24))
		hero_bars[id]=SKIN.gauge(slot,Rect2(6,85,cell-12,7),SKIN.SUCCESS)
		hero_bars[id].mouse_filter=Control.MOUSE_FILTER_IGNORE
		hero_cards[id]=art
	game.content_root.set_meta('portrait_tab','combat')
	HUD.navigation(game,game.content_root,'combat',h-90,90)
	game.content_root.set_meta('portrait_ready',true)
	if w > h: _wide_layout(body, summary.get_parent(), status_panel, actions, row, party_heading, w, h)
	_settle_stage_layout.call_deferred(body,w,h)
	refresh()

func _layout_arena() -> void:
	if not is_instance_valid(stage) or not is_instance_valid(arena):return
	# Keep the original combat coordinates; all sprite and FX transforms share
	# this one arena so their hits remain aligned at every viewport height.
	battlefield_3d._resize_world()
	arena.scale=Vector2.ONE*battlefield_3d.raid_factor
	arena.position=battlefield_3d.raid_origin()

func _on_stage_input(event: InputEvent) -> void:
	if not game.raid_running:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			_dragging=event.pressed
			if event.pressed:_on_move_input(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_on_move_input(event.position)
	elif event is InputEventScreenTouch:
		_dragging=event.pressed
		if event.pressed:_on_move_input(event.position)
	elif event is InputEventScreenDrag and _dragging:
		_on_move_input(event.position)

func _on_move_input(local_point: Vector2) -> void:
	var world: Vector2=(local_point-arena.position)/maxf(.01,arena.scale.x)
	game._raid_order_move(world)
	rally_marker.position=game.raid_rally_position
	rally_marker.visible=true
	stage.accept_event()

func _on_dodge_pressed() -> void:
	game._raid_dodge()
	refresh()

func _on_manual_skill() -> void:
	if not game._raid_manual_cast(false,selected_hero_id):game._show_toast('선택한 영웅의 스킬이 아직 준비되지 않았어요.')
	refresh()

func _on_manual_ultimate() -> void:
	if not game._raid_manual_cast(true,selected_hero_id):game._show_toast('선택한 영웅의 각성기가 아직 준비되지 않았어요.')
	refresh()

func _on_hero_slot_input(event: InputEvent, hero_id: String) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		selected_hero_id=hero_id;refresh()
	elif event is InputEventScreenTouch and event.pressed:
		selected_hero_id=hero_id;refresh()

func _on_follow_pressed() -> void:
	game.raid_rally_active=false
	rally_marker.visible=false
	refresh()

func start_entry() -> void:
	if not is_instance_valid(stage):return
	last_phase=1;last_enraged=false
	if is_instance_valid(phase_banner):phase_banner.visible=false;phase_banner.modulate.a=0.0
	var left:=ColorRect.new();left.color=Color('#091522');left.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var right:=ColorRect.new();right.color=Color('#091522');right.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(left);stage.add_child(right)
	left.position=Vector2.ZERO;left.size=Vector2(stage.size.x*.5,stage.size.y)
	right.position=Vector2(stage.size.x*.5,0);right.size=left.size
	var title:=_text('던전 진입 · %s'%str(game.raid_boss_name),26,SKIN.GOLD)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	SKIN.place(stage,title,Rect2(0,stage.size.y*.4,stage.size.x,50))
	var transition:=create_tween().set_parallel(true)
	transition.tween_property(left,'position:x',-stage.size.x*.5,.62).set_delay(.15)
	transition.tween_property(right,'position:x',stage.size.x,.62).set_delay(.15)
	transition.tween_property(title,'modulate:a',0.0,.38).set_delay(.34)
	transition.chain().tween_callback(func() -> void:
		left.queue_free();right.queue_free();title.queue_free()
	)

func _open_formation() -> void:
	if game.raid_running:return
	game._open_content_party('raid',str(game.selected_raid_id))

func _show_phase_banner(message: String) -> void:
	if not is_instance_valid(phase_banner):return
	phase_banner.text=message;phase_banner.visible=true;phase_banner.modulate.a=0.0
	var tween:=create_tween();tween.tween_property(phase_banner,'modulate:a',1.0,.16);tween.tween_interval(.72);tween.tween_property(phase_banner,'modulate:a',0.0,.30);tween.tween_callback(func(): phase_banner.visible=false)

func _toggle_skill_auto() -> void:
	game._toggle_skill_auto();refresh()

func _toggle_ultimate_auto() -> void:
	game._toggle_ultimate_auto();refresh()

func play_hero_attack(hero_id: String) -> void:
	var actor: Node2D=hero_actors.get(hero_id)
	if is_instance_valid(actor):actor.play_attack('right')

func show_victory() -> void:
	if not is_instance_valid(stage):return
	telegraph.active=false;telegraph.queue_redraw()
	if is_instance_valid(mechanic_visual):mechanic_visual.play_victory_finish()
	if is_instance_valid(game.raid_boss_sprite):
		game.raid_boss_sprite.play_death('left')
	phase_flash.color=Color(Color('#ffe2a1'), .8)
	create_tween().tween_property(phase_flash,'color:a',0.0,1.1)
	var victory:=_text('레이드 클리어',38,SKIN.GOLD)
	victory.name='PortraitRaidVictory';victory.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(stage,victory,Rect2(0,stage.size.y*.40,stage.size.x,64))
	var animation:=create_tween()
	victory.modulate.a=0.0
	animation.tween_property(victory,'modulate:a',1.0,.35)
	animation.tween_interval(1.1)
	animation.tween_property(victory,'modulate:a',0.0,.35)
	animation.tween_callback(victory.queue_free)

func _process(delta: float) -> void:
	if is_instance_valid(game):
		for id in hero_actors:
			var actor: Node2D=hero_actors[id]
			if is_instance_valid(actor) and game.raid_positions.has(id):
				var destination: Vector2=game.raid_positions[id]
				var moved: Vector2=actor.position.lerp(destination,minf(1.0,delta*18.0))
				if moved.distance_to(actor.position)>1.0 and actor.state=='idle':actor.play_walk(destination-actor.position)
				elif moved.distance_to(actor.position)<=1.0 and actor.state=='walk':actor.play_idle('right')
				actor.position=moved
	elapsed+=delta
	if elapsed>.1:elapsed=0;refresh()

func refresh() -> void:
	if not is_instance_valid(game) or not is_instance_valid(hp):return
	skill_auto_button.text='스킬 AUTO  켬' if game.skill_auto else '스킬 AUTO  끔'
	ultimate_auto_button.text='각성기 AUTO  켬' if game.ultimate_auto else '각성기 AUTO  끔'
	skill_auto_button.modulate=Color.WHITE if game.skill_auto else Color('#b4c2c6')
	ultimate_auto_button.modulate=Color.WHITE if game.ultimate_auto else Color('#b4c2c6')
	var zone: Dictionary=game._raid_zone()
	var clears: int=int(game.raid_clears.get(game.raid_encounter_zone,0))
	var reward_crystals: int=6+6*int(zone['difficulty'])
	rewards.text='전용 세트 1개 확정 · 레이드 정수 기본 %d개 + 기믹 성과 보너스\n%d승 후 전설 세트 보장 · 미보유 부위 우선'%[reward_crystals,5-clears%5]
	party_summary.text='권장 전투력 %s · 원정대 전투력 %s'%[game._compact_hud_amount(int(zone['power'])*3),game._compact_hud_amount(game.party_power)]
	hp.value=100.0*game.raid_boss_hp/maxf(1,game.raid_boss_max_hp) if game.raid_boss_max_hp>0 else 100.0
	dodge_button.disabled=not game.raid_running or game.raid_dodge_cooldown>0.0
	dodge_button.text='회피  %.1f초'%game.raid_dodge_cooldown if game.raid_dodge_cooldown>0.0 else '회피  READY'
	follow_button.disabled=not game.raid_running or not game.raid_rally_active
	skill_cast_button.disabled=not game.raid_running
	ultimate_cast_button.disabled=not game.raid_running
	if not selected_hero_id.is_empty():
		skill_cast_button.text='스킬 · %s'%game._hero_short_name(selected_hero_id)
		ultimate_cast_button.text='각성 · %s'%game._hero_short_name(selected_hero_id)
	boss_motion.casting=game.boss_telegraph_pending or game.raid_second_wave_remaining>0.0
	boss_motion.enraged=game.raid_enraged
	if is_instance_valid(game.raid_boss_sprite):
		var boss_alpha: float=game.raid_boss_sprite.modulate.a
		game.raid_boss_sprite.modulate=Color(1.0,0.62,0.68,boss_alpha) if game.raid_enraged else Color(1.0,1.0,1.0,boss_alpha)
	if is_instance_valid(mechanic_tint):
		if float(game.raid_dps_check_remaining)>0.0:
			var ritual: Dictionary=game._raid_mechanic_profile()
			var ritual_duration: float=maxf(0.1,float(ritual.get('duration',8.0)))
			var urgency: float=1.0-clampf(float(game.raid_dps_check_remaining)/ritual_duration,0.0,1.0)
			mechanic_tint.color=Color(Color('#16091f'), 0.16+urgency*0.16)
		elif game.raid_enraged:
			mechanic_tint.color=Color(Color('#48111c'), 0.10)
		else:
			mechanic_tint.color=Color.TRANSPARENT
	var followup: bool=game.raid_second_wave_remaining>0.0 and game.raid_running
	var casting: bool=(game.boss_telegraph_pending or followup) and game.raid_running
	telegraph.active=casting
	cue.visible=casting;cast_bar.visible=casting
	if casting:
		var pattern: Dictionary=game.raid_second_wave_profile if followup else (game.raid_cast_profile if not game.raid_cast_profile.is_empty() else game._boss_pattern_profile(game.raid_encounter_zone))
		telegraph.kind=str(pattern.get('kind','aoe'))
		telegraph.shape=game.raid_second_wave_shape if followup else game.raid_pattern_shape
		telegraph.progress=clampf(1.0-(game.raid_second_wave_remaining/.42 if followup else game.boss_telegraph_remaining/maxf(.01,float(pattern.get('telegraph',1.0)))),0.0,1.0)
		cue.text='2차 지진' if followup else str(game.boss_telegraph_skill)
		cast_bar.value=telegraph.progress*100.0
	telegraph.queue_redraw()
	if is_instance_valid(mechanic_visual):mechanic_visual.queue_redraw()
	if game.raid_phase>last_phase:
		last_phase=game.raid_phase
		phase_flash.color=Color(DESIGN.raid(game.raid_encounter_zone)['accent'],.5)
		create_tween().tween_property(phase_flash,'color:a',0.0,.6)
		_show_phase_banner('PHASE %d\n%s'%[game.raid_phase,game._raid_phase_hint()])
	if game.raid_enraged and not last_enraged:
		last_enraged=true
		_show_phase_banner('광폭화\n공격력·이동·공격 속도 상승')
	elif not game.raid_running:
		last_enraged=false
	if game.raid_running or not game.raid_last_result.is_empty():
		information.text='보스 HP %s / %s\n경과 %.1f초 · 제한 240초 · %d단계'%[game._compact_hud_amount(game.raid_boss_hp),game._compact_hud_amount(game.raid_boss_max_hp),game.raid_elapsed,game.raid_phase]
	else:
		information.text='보스 HP %s · 시작 전\n180초 광폭화 · 제한 240초'%game._compact_hud_amount(int(zone['power'])*20)
	start.disabled=game.raid_running or game.deployed_heroes.is_empty()
	start.text='레이드 진행 중' if game.raid_running else ('다시 도전' if not game.raid_last_result.is_empty() else '레이드 시작')
	formation.disabled=game.raid_running
	formation.tooltip_text='전투가 끝난 뒤 편성을 변경할 수 있어요.' if game.raid_running else '편성을 저장하면 이 보스의 준비 화면으로 돌아옵니다.'
	var next_text: String
	var next_section: String
	var status_color: Color=SKIN.INK
	if (game.boss_telegraph_pending or followup) and game.raid_running:
		next_section='telegraph'
		state_title.text='보스 스킬 예고'
		var break_percent: int=roundi(100.0*game.raid_break_gauge/maxf(1.0,game.raid_break_gauge_max))
		next_text='%s · %.1f초 후 발동\n%s\n차단 게이지 %d%%'%['2차 지진' if followup else game.boss_telegraph_skill,game.raid_second_wave_remaining if followup else game.boss_telegraph_remaining,'위험 구역 밖으로 이동하거나 회피하세요.' if game.raid_control_immunity>0.0 else '위험 구역에서 이동·회피하거나 제어 스킬로 차단하세요.',break_percent]
		status_color=Color('#ffbd87')
	elif game.raid_running:
		next_section='running'
		state_title.text='전투 진행 · 광폭화' if game.raid_enraged else '전투 진행'
		var next_pattern: Dictionary=game._boss_cast_profile(game.raid_encounter_zone)
		var mechanic_status: Dictionary=game._raid_mechanic_status()
		var mechanic_line: String=str(mechanic_status.get('label',''))
		next_text='%s\n%s%s\n다음 패턴 · %s'%[game.skill_event_text if not game.skill_event_text.is_empty() else '역할별 진형을 유지하며 자동 전투 중입니다.',game.raid_event_text,' · '+mechanic_line if not mechanic_line.is_empty() else '',str(next_pattern.get('name','보스 패턴'))]
	elif not game.raid_last_result.is_empty():
		next_section='result'
		state_title.text='전투 결과'
		next_text=game.raid_last_result
		status_color=SKIN.SUCCESS if str(game.raid_outcome)=='victory' else SKIN.INK
	else:
		next_section='guide'
		state_title.text='공략 안내'
		var pattern: Dictionary=game._boss_pattern_profile(game.raid_encounter_zone)
		var mechanic: Dictionary=game._raid_mechanic_profile(game.raid_encounter_zone,2)
		next_text='%s\n%s\n%s\n기믹 · %s'%[str(zone['boss_skill']),str(pattern.get('counter','수호와 회복으로 원정대를 보호하세요.')),str(pattern.get('phase_hint','패턴 예고를 보고 안전 지대로 이동하세요.')),str(mechanic.get('hint','페이즈 기믹을 해결하면 공격 기회를 얻습니다.'))]
		if game.deployed_heroes.is_empty():next_text='출전할 영웅이 없어요. 편성 변경을 눌러 영웅을 선택하세요.'
	if state_label.text!=next_text:
		state_label.text=next_text
	if _state_section!=next_section:
		_state_section=next_section
		state_scroll.scroll_vertical=0
	state_label.add_theme_color_override('font_color',status_color)
	state_label.tooltip_text=state_label.text
	for id in hero_bars:
		var slot: Panel=hero_slots[id]
		if not slot.has_meta('raid_selected') or bool(slot.get_meta('raid_selected'))!=(id==selected_hero_id):
			slot.set_meta('raid_selected',id==selected_hero_id)
			slot.add_theme_stylebox_override('panel',SKIN.box(SKIN.SURFACE,SKIN.GOLD if id==selected_hero_id else SKIN.EDGE_SOFT,12,2 if id==selected_hero_id else 1))
		var state: Dictionary=game.hero_battle_state.get(id,{})
		var alive: bool=float(state.get('hp',0))>0.0
		hero_bars[id].value=100.0*float(state.get('hp',0))/maxf(1.0,float(state.get('max_hp',1)))
		hero_cards[id].modulate=Color.WHITE if alive else Color('#6a7180')
		var actor: Node2D=hero_actors.get(id)
		if is_instance_valid(actor):
			if float(state.get('hp',0))<float(last_hp.get(id,0)):
				if alive:actor.play_hit('right')
				else:actor.play_death('right')
			last_hp[id]=float(state.get('hp',0))

func _wide_layout(body: Control, summary: Control, status: Control, actions: Control, party: Control, heading: Control, w: float, h: float) -> void:
	var field_w: float = w * .63
	body.position = Vector2(16,144); body.size = Vector2(field_w-28,h-436)
	var info := ScrollContainer.new(); info.name = "LandscapeRaidInfo"
	SKIN.place(self,info,Rect2(field_w+8,144,w-field_w-24,h-480))
	info.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(column); summary.reparent(column); status.reparent(column)
	var toggle_w: float = (w-field_w-32)*.5
	skill_auto_button.position = Vector2(field_w+8,h-332); skill_auto_button.size = Vector2(toggle_w,40)
	ultimate_auto_button.position = Vector2(field_w+16+toggle_w,h-332); ultimate_auto_button.size = Vector2(toggle_w,40)
	actions.position = Vector2(16,h-276); actions.size = Vector2(w-32,52)
	heading.position = Vector2(20,h-218)
	party.position = Vector2(16,h-186); party.size = Vector2(w-32,84)
	var cell: float = (w-32-9*6)/10.0
	for i in party.get_child_count():
		var slot: Control = party.get_child(i)
		slot.position = Vector2(i*(cell+6),0); slot.size = Vector2(cell,84)
		for child in slot.get_children():
			if child is TextureRect: child.size = Vector2(cell-6,46)
			elif child is Label: child.position.y = 48; child.size = Vector2(cell-8,24); child.add_theme_font_size_override("font_size",14)
			elif child is ProgressBar: child.position.y = 75; child.size.x = cell-12

func _settle_stage_layout(body: Control,w: float,h: float) -> void:
	# Container minimum sizes shrink after the information cards are reparented.
	# Apply the requested height after those queued sorts, then frame the camera.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(body):return
	body.size=Vector2(w*.63-28,h-436) if w>h else Vector2(w-40,h-618)
	await get_tree().process_frame
	_layout_arena()
