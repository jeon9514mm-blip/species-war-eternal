extends Control
## A read-only HUD/view adapter. All buttons delegate to existing v32 commands.
const NAV = preload("res://scripts/NavigationCatalog.gd")
const SKIN := preload('res://scripts/portrait/PortraitSkin.gd')
const ICON := preload('res://scripts/portrait/PortraitIcon.gd')
const REWARD_FEED := preload('res://scripts/portrait/PortraitRewardFeed.gd')
var game: Node
var profile_name: Label
var profile_level: Label
var power_label: Label
var gold_label: Label
var gem_label: Label
var stage_label: Label
var stage_progress: ProgressBar
var enemy_label: Label
var profile_xp: ProgressBar
var quest_label: Label
var options_quest_label: Label
var first_session_action: Button
var compact_guide_layout := false
var status_label: Label
var auto_button: Button
var speed_button: Button
var skill_button: Button
var ultimate_button: Button
var details_button: Button
var offline_button: Button
var bars: Dictionary = {}
var _elapsed := 0.0
var _power_elapsed: float = 999.0
var power_evaluations: int = 0
var refresh_count: int = 0
var slot_row: Control
var _slot_signature := ''
var _layout_rows := 2
var hud_bounds: Array[Rect2] = []
var reward_feed: Control

var options_layer: Control
func build(main: Node) -> void:
	game=main;name='PortraitHud';mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);z_index=90
	var screen: Vector2=game.get_viewport_rect().size
	var w:=screen.x;var h:=screen.y;var margin:=20.0
	var top:=maxf(28,game._safe_margins().y+10)
	SKIN.panel(self,Rect2(margin,top,w-margin*2,80),SKIN.SURFACE,SKIN.EDGE_SOFT,1)
	var face:=SKIN.button('',Callable(game,'_open_hero_menu'));face.name='PortraitProfileButton'
	SKIN.place(self,face,Rect2(margin+8,top+9,60,62))
	if not game.deployed_heroes.is_empty():_add_portrait(face,str(game.deployed_heroes[0].id),Rect2(3,3,54,56))
	profile_name=SKIN.label('나의 원정대',22)
	SKIN.place(self,profile_name,Rect2(margin+82,top+9,w-390,28))
	profile_level=SKIN.label('',16,SKIN.MUTED);SKIN.place(self,profile_level,Rect2(margin+82,top+45,110,26))
	power_label=SKIN.label('',16,SKIN.BLUE);SKIN.place(self,power_label,Rect2(margin+192,top+45,100,26))
	profile_xp=SKIN.gauge(self,Rect2(margin+82,top+75,206,3),SKIN.BLUE)
	gold_label=SKIN.label('',18,SKIN.GOLD);gem_label=SKIN.label('',18,SKIN.BLUE)
	SKIN.place(self,gold_label,Rect2(w-242,top+10,192,27));SKIN.place(self,gem_label,Rect2(w-242,top+42,192,27))
	gold_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;gem_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var stage_y:=top+90
	SKIN.panel(self,Rect2(margin,stage_y,w-margin*2,78),SKIN.SURFACE,SKIN.EDGE_SOFT,1)
	stage_label=SKIN.label('',22);stage_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	SKIN.place(self,stage_label,Rect2(margin+14,stage_y+7,w-184,30))
	enemy_label=SKIN.label('',17,SKIN.MUTED);enemy_label.name='PortraitEnemyCount'
	SKIN.place(self,enemy_label,Rect2(w-140,stage_y+8,98,30))
	stage_progress=SKIN.gauge(self,Rect2(margin+14,stage_y+48,w-margin*2-28,6),SKIN.GOLD)
	var entry_label:=SKIN.label('',15,SKIN.MUTED);entry_label.name='HuntEntryDirection'
	SKIN.place(self,entry_label,Rect2(margin+14,stage_y+56,w-margin*2-28,20))
	var command_y:=h-302
	details_button=SKIN.button('사냥 설정',_toggle_options);details_button.name='PortraitDetailsButton'
	SKIN.place(self,details_button,Rect2(margin,command_y,148,76))
	auto_button=SKIN.button('',_toggle_auto,SKIN.GOLD);auto_button.name='PortraitAutoButton'
	SKIN.place(self,auto_button,Rect2(margin+160,command_y,w-margin*2-262,76))
	speed_button=SKIN.button('×1',_cycle_speed);speed_button.name='PortraitSpeedButton'
	SKIN.place(self,speed_button,Rect2(w-margin-90,command_y,90,76))
	for button in [details_button,auto_button,speed_button]:button.add_theme_font_size_override('font_size',22)
	_layout_rows=1
	var party_scroll:=ScrollContainer.new();party_scroll.name='HuntPartyScroll'
	party_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	party_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;party_scroll.scroll_deadzone=8
	SKIN.place(self,party_scroll,Rect2(margin,h-220,w-margin*2,96))
	slot_row=Control.new();slot_row.name='PortraitPartySlots';slot_row.custom_minimum_size=Vector2(10*108-8,84)
	party_scroll.add_child(slot_row);slot_row.size=slot_row.custom_minimum_size;_build_slots()
	status_label=SKIN.label('',16,SKIN.MUTED);status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(self,status_label,Rect2(margin,h-122,w-margin*2,25))
	reward_feed=REWARD_FEED.new();SKIN.place(self,reward_feed,Rect2(w*.5-185,command_y-100,370,94));reward_feed.build(w)
	navigation(game,self,'combat',h-90,90)
	_build_options(w,h)
	first_session_action=SKIN.button('원정 가이드',Callable(game,'_follow_first_session_guide'),SKIN.GOLD)
	first_session_action.name='FirstSessionGuideAction'
	SKIN.place(self,first_session_action,Rect2(margin,command_y-50,w-margin*2,44))
	hud_bounds=[Rect2(margin,top,w-margin*2,168),Rect2(margin,command_y,w-margin*2,158),Rect2()]
	refresh()

func _build_options(w: float,h: float,include_offline: bool = true) -> void:
	options_layer=Control.new();options_layer.name='HuntOptionsSheet';options_layer.z_index=110
	options_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(options_layer)
	var shade:=ColorRect.new();shade.color=Color(0,0,0,.65);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_layer.add_child(shade)
	var panel:=PanelContainer.new();panel.name='HuntOptionsPanel'
	panel.add_theme_stylebox_override('panel',SKIN.elevated(SKIN.SURFACE))
	var rect:=Rect2(w-374,106,354,h-214) if compact_guide_layout else Rect2(20,maxf(20,(h-650)*.5),w-40,minf(650,h-40))
	SKIN.place(options_layer,panel,rect)
	var margin:=MarginContainer.new();panel.add_child(margin)
	for edge in ['left','right','top','bottom']:margin.add_theme_constant_override('margin_'+edge,20)
	var layout:=VBoxContainer.new();layout.add_theme_constant_override('separation',12);margin.add_child(layout)
	var heading:=HBoxContainer.new();layout.add_child(heading)
	var title:=SKIN.label('사냥 조작',22);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
	var close:=SKIN.button('닫기',_toggle_options);close.name='HuntOptionsClose';close.custom_minimum_size=Vector2(76,52);heading.add_child(close)
	var scroll:=ScrollContainer.new();scroll.name='HuntOptionsScroll';SKIN.make_scroll_responsive(scroll)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override('separation',12);scroll.add_child(box)
	options_quest_label=SKIN.label('',18,SKIN.MUTED);options_quest_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(options_quest_label)
	if not is_instance_valid(quest_label):quest_label=options_quest_label
	skill_button=_option(box,'',_toggle_skill_auto,'PortraitSkillAuto')
	ultimate_button=_option(box,'',_toggle_ultimate_auto,'PortraitUltimateAuto')
	_option(box,'전투 진형',Callable(game,'_open_battle_formation'),'HuntFormation')
	_option(box,'사냥 정보 · 피해와 보상',func():options_layer.hide();game._toggle_hunt_details(),'HuntStatistics')
	_option(box,'사냥터 지도',Callable(game,'_build_world_map_screen'),'PortraitMapButton')
	_option(box,'목표 · 업적',Callable(game,'_open_goal_screen'),'PortraitQuestButton')
	if include_offline:offline_button=_option(box,'',_open_offline_rewards,'PortraitOfflineRewards')
	_option(box,'화면 · 소리 · 성능',Callable(game,'_open_presentation_settings'),'HuntSettings')
	options_layer.hide()

func _option(parent: Node,caption: String,callback: Callable,node_name: String) -> Button:
	var button:=SKIN.button(caption,func():
		if node_name not in ['PortraitSkillAuto','PortraitUltimateAuto']:options_layer.hide()
		callback.call())
	button.name=node_name
	button.custom_minimum_size=Vector2(0,52 if compact_guide_layout else 76);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override('font_size',18 if compact_guide_layout else 22)
	button.mouse_filter=Control.MOUSE_FILTER_PASS;parent.add_child(button);return button

func _toggle_options() -> void:options_layer.visible=not options_layer.visible

func show_hunt_reward(gold: int, xp: int, drops: Array[Dictionary], chest: bool) -> void:
	if is_instance_valid(reward_feed):reward_feed.add_reward(gold,xp,drops,chest)

func show_claim(gold: int, xp: int) -> void:
	if is_instance_valid(reward_feed):reward_feed.show_claim(gold,xp)

func _icon(kind: String, rect: Rect2, parent: Node = null) -> Control:
	var icon := ICON.new()
	icon.kind=kind
	SKIN.place(self if parent==null else parent,icon,rect)
	return icon
func _add_portrait(parent: Node, hero_id: String, rect: Rect2) -> TextureRect:
	var portrait:=TextureRect.new()
	portrait.name='Portrait_'+hero_id
	portrait.texture=game._combat_portrait_texture(hero_id)
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	SKIN.place(parent,portrait,rect)
	return portrait
func _party_signature() -> String:
	var ids: Array[String]=[str(game._party_slot_cap())]
	for hero in game.deployed_heroes: ids.append(str(hero['id']))
	return '|'.join(ids)

func _build_slots() -> void:
	for child in slot_row.get_children(): child.free()
	bars.clear()
	var cell:=100.0
	var cap: int=game._party_slot_cap()
	for i in 10:
		var slot:=SKIN.button('',Callable(game,'_build_hero_select_screen'),Color('#264448'))
		slot.name='PortraitSlot%d'%i;slot.mouse_filter=Control.MOUSE_FILTER_PASS
		SKIN.place(slot_row,slot,Rect2(i*(cell+8),0,cell,84))
		slot.visible=true
		slot.add_theme_stylebox_override('normal',SKIN.box(Color('#264448f2'),Color('#799e98'),10,1))
		if i>=game.deployed_heroes.size():
			var caption:=SKIN.label('영웅 추가' if i<cap else '%d 스테이지'%game._party_slot_unlock_stage(i),13,SKIN.MUTED)
			caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			SKIN.place(slot,caption,Rect2(2,52,cell-4,26))
			if i<cap:
				var plus:=SKIN.label('+',30,SKIN.BLUE_SOFT)
				plus.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
				SKIN.place(slot,plus,Rect2(0,3,cell,49))
			else: _icon('lock',Rect2((cell-28)/2,13,28,32),slot)
			continue
		var hero: Dictionary=game.deployed_heroes[i]
		var id:=str(hero['id'])
		slot.tooltip_text=str(hero['name'])+' · 상세'
		slot.pressed.disconnect(Callable(game,'_build_hero_select_screen'))
		slot.pressed.connect(Callable(game,'_build_hero_detail_screen').bind(id))
		var accent: Color=game._hero_grade_color(id)
		slot.add_theme_stylebox_override('normal',SKIN.box(Color('#2a4a4cf5'),Color(accent,.80),10,1))
		var title:=SKIN.label(str(hero['name']).split(' ')[0],15)
		title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		SKIN.place(slot,title,Rect2(7,1,cell-14,25))
		_add_portrait(slot,id,Rect2(4,28,42,48))
		var level:=SKIN.label('',12,SKIN.MUTED)
		level.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		SKIN.place(slot,level,Rect2(49,26,cell-55,19))
		var hp:=SKIN.gauge(slot,Rect2(49,48,cell-56,10),Color('#70d68b'))
		var skill:=SKIN.label('',12,Color('#b3d4ee'))
		skill.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		SKIN.place(slot,skill,Rect2(49,59,cell-55,19))
		var ult:=SKIN.gauge(slot,Rect2(7,78,cell-14,3),Color('#4dc9f0'))
		bars[id]={'hp':hp,'ultimate':ult,'slot':slot,'level':level,'skill':skill,'hp_band':-1}
	_slot_signature=_party_signature()
func _process(delta: float) -> void:
	if not is_instance_valid(game) or game._application_suspended:return
	_elapsed+=delta;_power_elapsed+=delta
	if _elapsed>=float(game._presentation_profile()['hud_interval']):
		_elapsed=0
		refresh()
func refresh() -> void:
	if not is_instance_valid(game):return
	if _party_signature()!=_slot_signature: _build_slots()
	refresh_count+=1
	if _power_elapsed>=float(game._presentation_profile()['power_interval']):
		_power_elapsed=0.0;power_evaluations+=1
		power_label.text=('전투력 ' if compact_guide_layout else '')+game._compact_hud_amount(game._calculate_party_power())
	gold_label.text="골드 "+game._compact_hud_amount(game.wallet_gold)
	gem_label.text="젬 "+game._compact_hud_amount(game.wallet_gems)
	var pending_gold: int=game.offline_pending_gold+game.offline_pending_chest_gold
	var pending_xp: int=game.offline_pending_xp+game.offline_pending_chest_xp
	offline_button.disabled=pending_gold<=0 and pending_xp<=0
	if compact_guide_layout:offline_button.visible=not offline_button.disabled
	offline_button.text='오프라인 보상 없음' if offline_button.disabled else '오프라인 사냥 받기'
	offline_button.tooltip_text='오프라인 골드 %d · 계정 경험치 %d'%[pending_gold,pending_xp]
	skill_button.text='스킬 자동 사용 · 켬' if game.skill_auto else '스킬 자동 사용 · 끔'
	ultimate_button.text='궁극기 자동 사용 · 켬' if game.ultimate_auto else '궁극기 자동 사용 · 끔'
	skill_button.modulate=Color.WHITE if game.skill_auto else Color('#b4c2c6')
	ultimate_button.modulate=Color.WHITE if game.ultimate_auto else Color('#b4c2c6')
	stage_label.text='%s  %d 스테이지'%[game._current_zone()['name'],game.idle_stage]
	stage_label.tooltip_text=stage_label.text
	stage_progress.value=100.0*game.idle_stage_kills/maxf(1,game.idle_stage_target)
	stage_progress.tooltip_text='스테이지 처치 %d / %d'%[game.idle_stage_kills,game.idle_stage_target]
	enemy_label.text='적 %d'%game._enemy_wave_alive_count()
	quest_label.text=game._tracked_quest_text()
	if quest_label.text.is_empty():quest_label.text='자동으로 사냥하고 보상을 모아요.'
	var title_text: String=game.GOALS.title_text(game)
	profile_name.text='나의 원정대' if title_text=='칭호 미선택' else title_text
	profile_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	profile_name.clip_text=true
	profile_name.tooltip_text=title_text
	if game.challenge_session != null:
		var challenge: ChallengeBattleSession = game.challenge_session
		stage_label.text='%s · %s'%[challenge.title,challenge.progress_text()]
		stage_label.tooltip_text=stage_label.text
		stage_progress.value=100.0*challenge.progress_ratio()
		stage_progress.tooltip_text='실제 전투 진행 · 남은 시간 %.1f초'%challenge.remaining_seconds()
		quest_label.text=challenge.objective_description
	quest_label.tooltip_text=quest_label.text
	if is_instance_valid(first_session_action):
		first_session_action.visible=not game.tutorial_completed and game.challenge_session==null and not bool(game.get_meta("practice_active",false))
		if first_session_action.visible:
			game._refresh_tutorial_state()
			var guide: Dictionary=preload("res://scripts/FirstSessionGuide.gd").status(game)
			quest_label.text=str(guide.short);quest_label.tooltip_text=str(guide.text)
			first_session_action.text=str(guide.caption);first_session_action.tooltip_text=str(guide.text)
			first_session_action.disabled=preload("res://scripts/SaveSafety.gd").pending(game) or game._save_blocked_for_newer_version
		if not compact_guide_layout and hud_bounds.size()>2:
			hud_bounds[2]=first_session_action.get_rect() if first_session_action.visible else Rect2()
			if is_instance_valid(reward_feed):reward_feed.position.y=game.get_viewport_rect().size.y-302.0-(150.0 if first_session_action.visible else 100.0)
		if compact_guide_layout:
			quest_label.size.x=game.get_viewport_rect().size.x-334.0-(258.0 if first_session_action.visible else 44.0)
	if is_instance_valid(options_quest_label) and options_quest_label!=quest_label:
		options_quest_label.text=quest_label.text;options_quest_label.tooltip_text=quest_label.tooltip_text
	status_label.text='%s  ·  원정대 %d/%d'%[game._hunt_state_text(),game._alive_hero_ids().size(),game.deployed_heroes.size()]
	speed_button.text='×%d'%int(game.battle_speed)
	auto_button.text='영웅 편성하기' if game.deployed_heroes.is_empty() else ('Ⅱ  자동사냥 중' if game.combat_running else '▶  사냥 재개')
	auto_button.tooltip_text='영웅 편성 열기' if game.deployed_heroes.is_empty() else ('자동사냥 일시정지' if game.combat_running else '자동사냥 재개')
	details_button.text='사냥 조작'
	var entry: Label=get_node_or_null('HuntEntryDirection')
	if entry!=null:entry.text=game.hunt_event_text
	auto_button.modulate=Color.WHITE if game.combat_running else Color('#c5cede')
	if not game.deployed_heroes.is_empty():
		var id:=str(game.deployed_heroes[0]['id'])
		var progress: Dictionary=game._get_hero_progress(id)
		profile_level.text='대표 Lv.%d'%int(progress['level'])
		profile_xp.value=100.0*float(progress['xp'])/maxf(1,game._hero_xp_to_next(int(progress['level'])))
	for id in bars:
		var role: String=str(game._hero_role_group(id))
		bars[id]['level'].text='Lv.%d'%game._effective_combat_level(id)
		var state: Dictionary=game.hero_battle_state.get(id,{})
		var hp: ProgressBar=bars[id]['hp']
		var ult: ProgressBar=bars[id]['ultimate']
		hp.value=100.0*float(state.get('hp',0))/maxf(1,float(state.get('max_hp',1)))
		ult.value=float(state.get('ultimate',0))
		var band := 0 if hp.value<=25 else (1 if hp.value<=50 else 2)
		if int(bars[id]['hp_band'])!=band:
			var tint: Color=[Color('#f07777'),Color('#edbf65'),Color('#70d68b')][band]
			hp.add_theme_stylebox_override('fill',SKIN.box(tint,tint.darkened(.25),5,1))
			bars[id]['hp_band']=band
		var runtime: Dictionary=game.hero_skill_runtime.get(id,{})
		var cooldown:=minf(float(runtime.get('remaining',0)),float(runtime.get('secondary_remaining',0)))
		var skill: Label=bars[id]['skill']
		skill.text='전투불능' if hp.value<=0 else ('궁극' if ult.value>=100 else ('%d초'%ceili(cooldown) if cooldown>0 else '준비'))
		skill.add_theme_color_override('font_color',Color('#ffcf5a') if ult.value>=100 and hp.value>0 else Color('#b3d4ee'))
		bars[id]['slot'].tooltip_text='%s · %s\nHP %d / %d · 궁극기 %d%%'%[str(game._hero_short_name(id)),role,int(state.get('hp',0)),int(state.get('max_hp',1)),int(ult.value)]
		bars[id]['slot'].modulate=Color('#9298a2') if hp.value<=0 else Color.WHITE
func _toggle_auto() -> void:
	# An empty expedition needs the roster, not a resume action that does nothing.
	if game.deployed_heroes.is_empty():
		game._build_hero_select_screen()
		return
	var original: Button=game.combat_labels.get('toggle')
	if is_instance_valid(original):game._toggle_combat(original)
	refresh()
func _cycle_speed() -> void:
	game._cycle_battle_speed(speed_button)
	refresh()

func _open_offline_rewards() -> void:
	game._show_offline_reward_popup()
	refresh()
func _toggle_skill_auto() -> void:
	game._toggle_skill_auto()
	refresh()
func _toggle_ultimate_auto() -> void:
	game._toggle_ultimate_auto()
	refresh()

static func navigation(main: Node, parent: Node, active: String, y: float, height: float = 90) -> Control:
	var w: float=main.get_viewport_rect().size.x
	var panel:=SKIN.panel(parent,Rect2(0,y-6,w,height+6),Color('#0d2230fa'),Color('#315667'),1,18)
	panel.name='PortraitNavigation'
	panel.z_index=95
	# Keep the bottom dock to five high-frequency destinations. Secondary systems stay
	# one tap away in the menu sheet instead of competing for seven tiny hit targets.
	var entries: Array = NAV.dock_entries()
	var bw: float = w / float(entries.size())
	var selected_tab: String = NAV.active_tab(active)
	for i in entries.size():
		var e: Dictionary=entries[i]
		var selected: bool = str(e['id']) == selected_tab
		var is_battle: bool=e['id']=='battle'
		var slim_dock := height <= 56
		var top:=4.0 if slim_dock else 5.0
		var button_height:=height-8.0 if slim_dock else height-10.0
		var fill: Color=Color('#224654') if selected else Color('#0d223000')
		var edge: Color=SKIN.GOLD if selected else Color('#35556600')
		var btn:=SKIN.button('',Callable(main,str(e['method'])),fill)
		btn.name='PortraitNav_'+str(e['id']);btn.tooltip_text=str(e['label'])
		btn.add_theme_stylebox_override('normal',SKIN.box(fill,edge,16 if is_battle else 12,2 if selected else 0))
		btn.add_theme_stylebox_override('hover',SKIN.box(Color('#1b3b49'),Color(SKIN.BLUE_SOFT,.55),16 if is_battle else 12,1))
		btn.add_theme_stylebox_override('pressed',SKIN.box(Color('#18323e'),SKIN.GOLD,16 if is_battle else 12,2))
		SKIN.place(panel,btn,Rect2(i*bw+4,top,bw-8,button_height))
		var compact_dock := height < 80
		var icon_size:=20.0 if slim_dock else (24.0 if compact_dock else 30.0)
		var icon:=SKIN.UI.icon(str(e['portrait_icon']),Vector2.ONE*icon_size,SKIN.GOLD if selected else SKIN.MUTED)
		SKIN.place(btn,icon,Rect2((bw-icon_size)/2,3 if slim_dock else (5 if compact_dock else 7),icon_size,icon_size))
		if selected:
			var marker:=ColorRect.new();marker.color=SKIN.GOLD;marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
			SKIN.place(btn,marker,Rect2((bw-28)/2,2,28,3))
		var text:=SKIN.label(str(e['label']),12 if slim_dock else (13 if compact_dock else 16),SKIN.GOLD if selected else SKIN.MUTED_DARK)
		text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		SKIN.place(btn,text,Rect2(0,25 if slim_dock else (31 if compact_dock else 45),bw-8,16 if slim_dock else (18 if compact_dock else 24)))
	return panel
