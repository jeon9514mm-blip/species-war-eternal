extends Control
## A read-only HUD/view adapter. All buttons delegate to existing v32 commands.
const NAV = preload("res://scripts/NavigationCatalog.gd")
const SKIN := preload('res://scripts/portrait/PortraitSkin.gd')
const MINIMAP := preload('res://scripts/portrait/PortraitMinimap.gd')
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

func build(main: Node) -> void:
	game=main
	name='PortraitHud'
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=90
	var screen: Vector2 = game.get_viewport_rect().size
	var w := screen.x
	var h := screen.y
	var safe: Vector4 = game._safe_margins()
	var margin := maxf(12,safe.x)
	var top := maxf(38,safe.y+10)
	# Keep field information in one header, leaving the encounter unobstructed.
	SKIN.panel(self,Rect2(margin,top,304,100),Color('#17343feF'),SKIN.EDGE_SOFT,1,16)
	var face := SKIN.button('',Callable(game,'_open_hero_menu'))
	SKIN.place(self,face,Rect2(margin+5,top+5,74,88))
	face.name='PortraitProfileButton'
	face.add_theme_stylebox_override('normal',SKIN.box(Color('#2b5053'),SKIN.GOLD,12,1))
	if not game.deployed_heroes.is_empty():
		_add_portrait(face,str(game.deployed_heroes[0]['id']),Rect2(3,3,68,80))
	profile_name=SKIN.label('나의 원정대',21)
	SKIN.place(self,profile_name,Rect2(margin+90,top+3,200,28))
	profile_level=SKIN.label('대표 Lv.1',16,Color('#8fc7ff'))
	SKIN.place(self,profile_level,Rect2(margin+90,top+32,190,23))
	profile_xp=SKIN.gauge(self,Rect2(margin+90,top+57,196,8),Color('#4f9dff'))
	power_label=SKIN.label('',17)
	SKIN.place(self,power_label,Rect2(margin+117,top+69,169,25))
	_icon('battle',Rect2(margin+88,top+69,25,25))
	var money_x := maxf(332,w*.47)
	var money_w := (w-money_x-margin-9)/2.0
	SKIN.panel(self,Rect2(money_x,top+3,money_w,42),SKIN.SURFACE,SKIN.EDGE_SOFT,1,14)
	SKIN.panel(self,Rect2(money_x+money_w+9,top+3,money_w,42),SKIN.SURFACE,SKIN.EDGE_SOFT,1,14)
	_icon('gem',Rect2(money_x,top+4,38,38))
	_icon('coin',Rect2(money_x+money_w+10,top+4,38,38))
	gem_label=SKIN.label('',20)
	gold_label=SKIN.label('',20)
	for amount in [gem_label,gold_label]:
		amount.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	SKIN.place(self,gem_label,Rect2(money_x+40,top+4,money_w-46,40))
	SKIN.place(self,gold_label,Rect2(money_x+money_w+49,top+4,money_w-46,40))
	var more := SKIN.button('메뉴',Callable(game,'_show_main_menu'),Color('#305354'))
	more.name='PortraitMoreButton'
	more.add_theme_font_size_override('font_size',17)
	SKIN.place(self,more,Rect2(w-margin-88,top+52,88,48))
	offline_button=SKIN.button('',_open_offline_rewards,Color('#705b38'))
	offline_button.name='PortraitOfflineRewards'
	offline_button.add_theme_font_size_override('font_size',16)
	SKIN.place(self,offline_button,Rect2(money_x,top+52,w-margin-100-money_x,48))
	var formation := SKIN.button('진형',Callable(game,'_open_battle_formation'))
	formation.name='HuntFormation'; formation.add_theme_font_size_override('font_size',16)
	SKIN.place(self,formation,Rect2(w-margin-154,top+102,154,32))
	var stage_y := top+140
	var information_w := w-margin*2-168
	SKIN.panel(self,Rect2(margin,stage_y,information_w,126),Color('#173640ee'),SKIN.EDGE_SOFT,1,16)
	stage_label=SKIN.label('',22,SKIN.GOLD)
	stage_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	SKIN.place(self,stage_label,Rect2(margin+12,stage_y+3,information_w-24,34))
	stage_progress=SKIN.gauge(self,Rect2(margin+13,stage_y+48,information_w-122,12),Color('#fbd839'))
	enemy_label=SKIN.label('',16,Color('#bce4cc'))
	enemy_label.name='PortraitEnemyCount'
	SKIN.place(self,enemy_label,Rect2(margin+information_w-105,stage_y+38,90,32))
	var quest := SKIN.button('',Callable(game,'_open_goal_screen'),Color('#2b5553'))
	quest.name='PortraitQuestButton'
	SKIN.place(self,quest,Rect2(margin+7,stage_y+77,information_w-14,42))
	var qtitle:=SKIN.label('목표',16,SKIN.GOLD)
	SKIN.place(quest,qtitle,Rect2(8,0,40,42))
	quest_label=SKIN.label('',16)
	quest_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	SKIN.place(quest,quest_label,Rect2(49,0,quest.size.x-58,42))
	var map_button := SKIN.button('',Callable(game,'_build_world_map_screen'),Color('#1b3d41e8'))
	map_button.name='PortraitMapButton'
	map_button.tooltip_text='사냥터 지도 열기'
	SKIN.place(self,map_button,Rect2(w-margin-154,stage_y,154,126))
	var map_title:=SKIN.label('사냥터 지도',16,SKIN.MUTED)
	SKIN.place(map_button,map_title,Rect2(10,3,134,25))
	var minimap:=MINIMAP.new()
	minimap.game=game
	SKIN.place(map_button,minimap,Rect2(8,31,138,84))
	_layout_rows=2 if maxi(game._party_slot_cap(),game.deployed_heroes.size())>5 else 1
	var party_height := float(_layout_rows*92-8)
	var party_y := h-134-party_height
	var command_y := party_y-60
	reward_feed=REWARD_FEED.new()
	SKIN.place(self,reward_feed,Rect2((w-minf(370.0,w-28.0))*.5,command_y-154,minf(370.0,w-28.0),94))
	reward_feed.build(w)
	var toggle_width: float=(w-margin*2-8)*.5
	skill_button=SKIN.button('',_toggle_skill_auto,Color('#285f69'))
	skill_button.name='PortraitSkillAuto'
	skill_button.tooltip_text='액티브 스킬 1·2의 자동 사용'
	skill_button.add_theme_font_size_override('font_size',17)
	SKIN.place(self,skill_button,Rect2(margin,command_y-54,toggle_width,48))
	ultimate_button=SKIN.button('',_toggle_ultimate_auto,Color('#605076'))
	ultimate_button.name='PortraitUltimateAuto'
	ultimate_button.tooltip_text='각성기(궁극기)의 자동 사용'
	ultimate_button.add_theme_font_size_override('font_size',17)
	SKIN.place(self,ultimate_button,Rect2(margin+toggle_width+8,command_y-54,toggle_width,48))
	details_button=SKIN.button('사냥 정보',Callable(game,'_toggle_hunt_details'),Color('#315659'))
	details_button.name='PortraitDetailsButton'
	details_button.add_theme_font_size_override('font_size',18)
	SKIN.place(self,details_button,Rect2(margin,command_y,132,48))
	auto_button=SKIN.button('',_toggle_auto,Color('#317962'))
	auto_button.name='PortraitAutoButton'
	SKIN.place(self,auto_button,Rect2(margin+144,command_y,w-margin*2-250,48))
	speed_button=SKIN.button('×1',_cycle_speed,Color('#315659'))
	speed_button.name='PortraitSpeedButton'
	SKIN.place(self,speed_button,Rect2(w-margin-94,command_y,94,48))
	SKIN.panel(self,Rect2(margin-6,party_y-6,w-margin*2+12,party_height+12),Color('#183440f1'),SKIN.EDGE_SOFT,1,16)
	slot_row=Control.new()
	slot_row.name='PortraitPartySlots'
	SKIN.place(self,slot_row,Rect2(margin,party_y,w-margin*2,party_height))
	_build_slots()
	var ribbon:=SKIN.panel(self,Rect2(0,h-126,w,26),Color('#17353ae8'),Color.TRANSPARENT,0)
	status_label=SKIN.label('',16,Color('#f2f6ff'))
	status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(ribbon,status_label,Rect2(16,0,w-32,26))
	navigation(game,self,'combat',h-90,90)
	hud_bounds=[Rect2(margin,top,304,100),Rect2(money_x,top,money_w*2+9,44),slot_row.get_rect(),quest.get_rect(),map_button.get_rect()]
	refresh()

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
	var cell: float=(slot_row.size.x-4*8)/5.0
	var cap: int=game._party_slot_cap()
	for i in 10:
		var slot:=SKIN.button('',Callable(game,'_open_hero_menu'),Color('#264448'))
		slot.name='PortraitSlot%d'%i
		SKIN.place(slot_row,slot,Rect2((i%5)*(cell+8),(i/5)*92,cell,84))
		slot.visible=i<_layout_rows*5
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
		slot.pressed.disconnect(Callable(game,'_open_hero_menu'))
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
	var rows:=2 if maxi(game._party_slot_cap(),game.deployed_heroes.size())>5 else 1
	if rows!=_layout_rows:
		game._portrait_resize()
		return
	if _party_signature()!=_slot_signature: _build_slots()
	refresh_count+=1
	if _power_elapsed>=float(game._presentation_profile()['power_interval']):
		_power_elapsed=0.0;power_evaluations+=1
		power_label.text=game._compact_hud_amount(game._calculate_party_power())
	gold_label.text=game._compact_hud_amount(game.wallet_gold)
	gem_label.text=game._compact_hud_amount(game.wallet_gems)
	var pending_gold: int=game.offline_pending_gold+game.offline_pending_chest_gold
	var pending_xp: int=game.offline_pending_xp+game.offline_pending_chest_xp
	offline_button.disabled=pending_gold<=0 and pending_xp<=0
	offline_button.text='오프라인 보상 없음' if offline_button.disabled else '오프라인 사냥 받기'
	offline_button.tooltip_text='오프라인 골드 %d · 계정 경험치 %d'%[pending_gold,pending_xp]
	skill_button.text='스킬 AUTO  켬' if game.skill_auto else '스킬 AUTO  끔'
	ultimate_button.text='각성기 AUTO  켬' if game.ultimate_auto else '각성기 AUTO  끔'
	skill_button.modulate=Color.WHITE if game.skill_auto else Color('#b4c2c6')
	ultimate_button.modulate=Color.WHITE if game.ultimate_auto else Color('#b4c2c6')
	stage_label.text='%s  %d 스테이지'%[game._current_zone()['name'],game.idle_stage]
	stage_label.tooltip_text=stage_label.text
	stage_progress.value=100.0*game.idle_stage_kills/maxf(1,game.idle_stage_target)
	stage_progress.tooltip_text='스테이지 처치 %d / %d'%[game.idle_stage_kills,game.idle_stage_target]
	enemy_label.text='적 %d'%game._enemy_wave_alive_count()
	quest_label.text=game._tracked_quest_text()
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
	status_label.text='%s  ·  원정대 %d/%d'%[game._hunt_state_text(),game._alive_hero_ids().size(),game.deployed_heroes.size()]
	speed_button.text='×%d'%int(game.battle_speed)
	auto_button.text='영웅 편성하기' if game.deployed_heroes.is_empty() else ('Ⅱ  자동사냥 중' if game.combat_running else '▶  사냥 재개')
	auto_button.tooltip_text='영웅 편성 열기' if game.deployed_heroes.is_empty() else ('자동사냥 일시정지' if game.combat_running else '자동사냥 재개')
	var details: Control=game.combat_labels.get('details_panel')
	details_button.text='정보 닫기' if is_instance_valid(details) and details.visible else '사냥 정보'
	auto_button.modulate=Color.WHITE if game.combat_running else Color('#c5cede')
	if not game.deployed_heroes.is_empty():
		var id:=str(game.deployed_heroes[0]['id'])
		var progress: Dictionary=game._get_hero_progress(id)
		profile_level.text='대표 Lv.%d'%int(progress['level'])
		profile_xp.value=100.0*float(progress['xp'])/maxf(1,game._hero_xp_to_next(int(progress['level'])))
	for id in bars:
		var role: String=str(game._hero_role_group(id))
		var role_name: String={'탱커':'방어','서포터':'지원','컨트롤러':'제어','딜러':'공격'}.get(role,'공격')
		bars[id]['level'].text='%s %sLv.%d'%[role_name,'연습 ' if bool(game.get_meta('practice_active',false)) and str(game.get_meta('practice_level_override',{}).get('mode','actual'))=='matched' else '',game._effective_combat_level(id)]
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
		skill.text='전투불능' if hp.value<=0 else ('궁극 준비' if ult.value>=100 else ('기술 %d초'%ceili(cooldown) if cooldown>0 else '기술 준비'))
		skill.add_theme_color_override('font_color',Color('#ffcf5a') if ult.value>=100 and hp.value>0 else Color('#b3d4ee'))
		bars[id]['slot'].tooltip_text='%s · %s\nHP %d / %d · 궁극기 %d%%'%[str(game._hero_short_name(id)),role,int(state.get('hp',0)),int(state.get('max_hp',1)),int(ult.value)]
		bars[id]['slot'].modulate=Color('#9298a2') if hp.value<=0 else Color.WHITE
func _toggle_auto() -> void:
	# An empty expedition needs the roster, not a resume action that does nothing.
	if game.deployed_heroes.is_empty():
		game._open_hero_menu()
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
		var top: float=-8.0 if is_battle else 5.0
		var button_height: float=height+2.0 if is_battle else height-10.0
		var fill: Color=Color('#224654') if selected else Color('#0d223000')
		var edge: Color=SKIN.GOLD if selected else Color('#35556600')
		var btn:=SKIN.button('',Callable(main,str(e['method'])),fill)
		btn.name='PortraitNav_'+str(e['id']);btn.tooltip_text=str(e['label'])
		btn.add_theme_stylebox_override('normal',SKIN.box(fill,edge,16 if is_battle else 12,2 if selected else 0))
		btn.add_theme_stylebox_override('hover',SKIN.box(Color('#1b3b49'),Color(SKIN.BLUE_SOFT,.55),16 if is_battle else 12,1))
		btn.add_theme_stylebox_override('pressed',SKIN.box(Color('#18323e'),SKIN.GOLD,16 if is_battle else 12,2))
		SKIN.place(panel,btn,Rect2(i*bw+4,top,bw-8,button_height))
		var icon:=ICON.new();icon.kind=str(e['portrait_icon'])
		var icon_size:=46.0 if is_battle else 33.0
		SKIN.place(btn,icon,Rect2((bw-icon_size)/2,7,icon_size,icon_size))
		if selected:
			var marker:=ColorRect.new();marker.color=SKIN.GOLD;marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
			SKIN.place(btn,marker,Rect2((bw-28)/2,2,28,3))
		var text:=SKIN.label(str(e['label']),13 if not is_battle else 14,SKIN.GOLD if selected else SKIN.MUTED_DARK)
		text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		SKIN.place(btn,text,Rect2(0,45,bw-8,24))
	return panel
