extends Control
## One destination per menu entry, grouped by the task the player wants to do.
const S=preload('res://scripts/portrait/PortraitSkin.gd')
const P=preload('res://scripts/portrait/PortraitPages.gd')
const NAV=preload('res://scripts/NavigationCatalog.gd')
const GROUPS=[['battle','사냥 · 도전'],['heroes','영웅 · 장비'],['account','보상 · 설정']]
const ENTRIES=[
	['battle','world','사냥터 변경','지역과 사냥 보상 선택','_open_world_menu'],
	['battle','raid','보스 레이드','보스와 싸우고 장비 획득','_build_boss_select_screen'],
	['battle','growth','던전 도전','일일 던전 · 무한탑 · 주간 원정','_build_meta_hub_screen'],
	['battle','war','종의전쟁','진영 전투와 영토 관리','_open_faction_war_menu'],
	['battle','formation','전투 위치','전열·후열과 진형 배치','_open_battle_formation'],
	['battle','camp','원정대 현황','현재 편성과 사냥 진행 확인','_build_lobby_screen'],
	['heroes','heroes','영웅 성장','영웅별 연구·장비·승급','_open_hero_menu'],
	['heroes','party','영웅 편성','사냥에 출전할 영웅 선택','_build_hero_select_screen'],
	['heroes','inventory','장비 가방','장비 비교·교체·강화','_build_inventory_screen'],
	['heroes','summon','소환','영웅 조각과 수호신 획득','_build_summon_screen'],
	['heroes','codex','영웅 도감','전체 영웅과 해금 조건','_build_codex_screen'],
	['heroes','training','연구 관리','영웅 연구 포인트와 수호신','_build_growth_screen'],
	['heroes','market','장비 거래소','장비 구매와 판매','_build_equipment_market'],
	['account','quests','목표 · 업적','달성한 목표와 보상 확인','_open_goal_screen'],
	['account','rewards','보상 받기','출석·무료 보상 확인','_build_bm_screen'],
	['account','guide','플레이 안내','현재 목표와 다음 행동','_show_portrait_guide'],
	['account','settings','게임 설정','화면·소리·진동·성능','_open_presentation_settings'],
	['account','faction','진영 변경','진영별 영웅과 편성 선택','_build_faction_screen'],
	['account','title','시작 화면','타이틀 화면으로 이동','_build_title_screen']]
var game: Node
var pane: Control
var scroll: ScrollContainer
var pages: Dictionary={}
var tabs: Dictionary={}
var return_focus: Control

static func open(main: Node) -> void:
	var previous: Node=main.content_root.get_node_or_null('PortraitActionSheet')
	if previous!=null:
		previous.hide();previous.name='ClosingActionSheet';previous.queue_free()
	var menu: Control=load('res://scripts/LandscapeMainMenu.gd').new()
	menu.name='PortraitActionSheet';main.content_root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.install(main)

func install(main: Node) -> void:
	game=main;z_index=250;mouse_filter=Control.MOUSE_FILTER_STOP
	return_focus=get_viewport().gui_get_focus_owner()
	var outside:=S.button('',close);outside.name='MenuDismissArea';outside.focus_mode=Control.FOCUS_NONE
	for state: String in ['normal','hover','pressed']:outside.add_theme_stylebox_override(state,S.box(Color('#07101bb0'),Color.TRANSPARENT,0,0))
	add_child(outside);outside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=PanelContainer.new();panel.name='PortraitMenuSheet';pane=panel;add_child(panel)
	var style:=S.box(S.DARK_2,S.EDGE_SOFT,16,1);style.set_content_margin_all(20)
	panel.add_theme_stylebox_override('panel',style)
	var column:=P.stack(panel,12)
	var heading:=HBoxContainer.new();column.add_child(heading)
	P.text(heading,'메뉴',26).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var dismiss:=S.button('닫기',close);dismiss.name='PortraitMenuClose';dismiss.custom_minimum_size=Vector2(92,52);heading.add_child(dismiss)
	P.text(column,'하고 싶은 일을 선택하세요.',17,S.MUTED)
	var tab_row:=HBoxContainer.new();tab_row.add_theme_constant_override('separation',8);column.add_child(tab_row)
	for group: Array in GROUPS:
		var key:=str(group[0]);var tab:=S.button(str(group[1]),_select_group.bind(key))
		tab.name='MenuGroup_'+key;tab.custom_minimum_size.y=52;tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tab.toggle_mode=true;tab_row.add_child(tab);tabs[key]=tab
	scroll=ScrollContainer.new();scroll.name='MenuDestinationScroll';S.make_scroll_responsive(scroll)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	var contents:=P.stack(scroll,12)
	for group: Array in GROUPS:
		var page:=P.stack(contents,12);page.name='MenuPage_'+str(group[0]);pages[str(group[0])]=page
		var destinations:=P.grid(page,2)
		for entry: Array in ENTRIES:
			if entry[0]!=group[0]:continue
			var method:=str(entry[4]);var button:=S.button('',_dispatch.bind(method))
			button.name='PresentationSettingsEntry' if entry[1]=='settings' else ('PortraitOpenGuide' if entry[1]=='guide' else 'PortraitMenu_'+str(entry[1]))
			button.set_meta('menu_group',str(entry[0]));button.custom_minimum_size=Vector2(0,78)
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.mouse_filter=Control.MOUSE_FILTER_PASS
			button.tooltip_text=str(entry[2])+' · '+str(entry[3]);destinations.add_child(button)
			var title:=S.label(str(entry[2]),21);title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			button.add_child(title);title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			title.offset_left=16;title.offset_right=-16;title.offset_top=9;title.offset_bottom=39
			var hint:=S.label(str(entry[3]),15,S.MUTED);hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			button.add_child(hint);hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			hint.offset_left=16;hint.offset_right=-16;hint.offset_top=-33;hint.offset_bottom=-9
			if entry[1]=='quests' and game._quest_ready_count()>0:title.text+=' · 보상 있음'
		if group[0]=='account':_preferences(page)
	var selected:=str(game.get_meta('simple_menu_group','battle'))
	_select_group(selected if pages.has(selected) else 'battle')
	resized.connect(_layout);_layout();dismiss.grab_focus()

func _preferences(parent: Node) -> void:
	var row:=HBoxContainer.new();row.add_theme_constant_override('separation',20);parent.add_child(row)
	var effects:=CheckButton.new();effects.name='PortraitEffectSetting';effects.text='전투 효과';effects.button_pressed=game.combat_effects_enabled
	effects.custom_minimum_size.y=52;effects.set_meta('menu_group','account');row.add_child(effects)
	effects.toggled.connect(func(enabled: bool):game.combat_effects_enabled=enabled;game.combat_fx.enabled=enabled;game._save_ui_preferences())
	var sounds:=CheckButton.new();sounds.name='PortraitSoundSetting';sounds.text='효과음';sounds.button_pressed=game.sound_effects_enabled
	sounds.custom_minimum_size.y=52;sounds.set_meta('menu_group','account');row.add_child(sounds)
	sounds.toggled.connect(func(enabled: bool):
		game.sound_effects_enabled=enabled
		if not enabled and is_instance_valid(game.skill_audio_bus):game.skill_audio_bus.stop()
		game._save_ui_preferences())

func _select_group(key: String) -> void:
	if not pages.has(key):return
	for id in pages:
		pages[id].visible=id==key;tabs[id].set_pressed_no_signal(id==key)
	game.set_meta('simple_menu_group',key);scroll.scroll_vertical=0

func _layout() -> void:
	if not is_instance_valid(pane):return
	var pane_w:=minf(size.x-24,clampf(size.x*.55,660,820))
	pane.position=Vector2(size.x-pane_w-12,12);pane.size=Vector2(pane_w,size.y-24)

func _dispatch(method: String) -> void:
	if not is_instance_valid(game):return
	if method=='_build_meta_hub_screen' and str(game.get_meta('content_meta_tab','daily')) not in ['daily','tower','weekly']:
		game.set_meta('content_meta_tab','daily')
	var host:=game;close(false);host.call(method)

func close(restore_focus: bool=true) -> void:
	hide();name='ClosingActionSheet'
	# Keep the release target alive through both emulated mouse and touch release.
	if restore_focus and is_instance_valid(return_focus) and return_focus.is_visible_in_tree():return_focus.grab_focus()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed('ui_cancel'):
		get_viewport().set_input_as_handled();close()
