extends Control
## Landscape hero presentation. Existing progression/gear commands own all mutations.
const S=preload('res://scripts/portrait/PortraitSkin.gd')
const HUD=preload('res://scripts/portrait/PortraitHud.gd')
const R=preload('res://scripts/heroes/HeroRosterCatalog.gd')
const VISUALS=preload('res://scripts/heroes/HeroVisualCatalog.gd')
const ART=preload('res://scripts/equipment/EquipmentArtCatalog.gd')
const GEAR=preload('res://scripts/equipment/EquipmentRules.gd')
const SAFETY=preload('res://scripts/persistence/SaveSafety.gd')
const UI=preload('res://scripts/ui/GameUiTheme.gd')
const INK=UI.INK
const MUTED=UI.MUTED
const ACCENT=UI.PRIMARY
const PAPER=UI.SURFACE
const TABS=[['growth','성장'],['skills','스킬'],['equipment','장비'],['ascension','승급 · 돌파']]

class ShowcaseRig:
	extends 'res://scripts/portrait/PortraitHeroSkeletalRig.gd'
	# The showcase uses the original paintings even for the two action-sheet heroes.
	func _has_original_art(hero: HeroSpriteController) -> bool:
		return ResourceLoader.exists('res://assets/heroes/sd-v36/sheets/'+hero.atlas_key+'-pose.png')

var game: Node
var hero_id: String
var tab: String
var hero: Dictionary
var progress_data: Dictionary
var combat_stats: Dictionary
var locked:=false
var party_slot:=-1
var roster_position:=0
var content_position:=0
var right_rect: Rect2
var art_rect: Rect2
var detail: VBoxContainer
var guarded_actions: Array[Dictionary]=[]
var writes_blocked:=false
var live_bindings: Array[Callable]=[]
var live_signature: int=0

static func build(main: Node, selected_id: String, requested_tab: String='') -> void:
	if not main._hero_belongs_to_selected_faction(selected_id):
		main._show_toast('선택한 진영의 영웅만 확인할 수 있습니다.')
		main._build_hero_select_screen()
		return
	var selected_tab:=requested_tab if not requested_tab.is_empty() else str(main.get_meta('hero_showcase_tab','growth'))
	if selected_tab not in ['growth','skills','equipment','ascension']:selected_tab='growth'
	var old_roster: ScrollContainer=main.content_root.find_child('HeroRosterScroll',true,false)
	var roster_offset:=old_roster.scroll_vertical if old_roster!=null else int(main.get_meta('hero_showcase_roster_scroll',0))
	var old_content: ScrollContainer=main.content_root.get_node_or_null('PortraitContentScroll')
	var same_panel: bool=main.active_screen=='hero_detail' and str(main.get_meta('hero_showcase_id',''))==selected_id and str(main.get_meta('hero_showcase_tab',''))==selected_tab
	var content_offset:=old_content.scroll_vertical if old_content!=null and same_panel else 0
	main.set_meta('hero_showcase_id',selected_id);main.set_meta('hero_showcase_tab',selected_tab)
	main.set_meta('hero_showcase_roster_scroll',roster_offset)
	main._clear_screen(true);main.active_screen='hero_detail'
	main.content_root.set_meta('portrait_ready',true);main.content_root.set_meta('portrait_tab','heroes')
	var view=load('res://scripts/heroes/HeroShowcaseView.gd').new()
	view.name='HeroShowcaseView';main.content_root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.roster_position=roster_offset;view.content_position=content_offset
	view.install(main,selected_id,selected_tab)

func install(main: Node, selected_id: String, selected_tab: String) -> void:
	game=main;hero_id=selected_id;tab=selected_tab
	writes_blocked=_mutation_blocked()
	hero=R.hero(hero_id);progress_data=game._get_hero_progress(hero_id)
	locked=game.idle_stage<int(hero.get('unlock_stage',1))
	party_slot=game._deployed_hero_ids().find(hero_id)
	var hp_mult: float=float(game._calculate_party_synergy().get('hp_multiplier',1.0)) if party_slot>=0 else 1.0
	combat_stats=game._hero_combat_stats(hero_id,maxi(0,party_slot),hp_mult)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var area: Vector2=game.get_viewport_rect().size
	var right_width:=clampf(area.x*.33,380,420)
	right_rect=Rect2(area.x-right_width-24,108,right_width,area.y-218)
	art_rect=Rect2(244,104,right_rect.position.x-268,area.y-214)
	_background(area);_header(area);_roster(area);_tabs(area);_hero_art();_identity();_details()
	HUD.navigation(game,game.content_root,'heroes',area.y-90,90)
	live_signature=_live_state_signature()
	queue_redraw()

func _background(area: Vector2) -> void:
	var sky:=TextureRect.new();sky.name='HeroShowcaseBackdrop'
	sky.texture=load('res://assets/ui/v30/expedition-key-art.png')
	sky.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;sky.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.mouse_filter=Control.MOUSE_FILTER_IGNORE;sky.modulate=Color(.58,.67,.63,.16)
	add_child(sky);sky.size=area
	var roster_panel:=Panel.new();roster_panel.name='HeroRosterPanel';roster_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	roster_panel.add_theme_stylebox_override('panel',UI.panel(UI.SURFACE,UI.BORDER,12))
	_place(self,roster_panel,Rect2(24,108,196,area.y-218))
	var information_panel:=Panel.new();information_panel.name='HeroInformationPanel';information_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	information_panel.add_theme_stylebox_override('panel',UI.panel(UI.SURFACE,UI.BORDER,12))
	_place(self,information_panel,right_rect.grow(12))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),UI.BG)
	if art_rect.size.x<=0:return
	var center:=art_rect.get_center()+Vector2(0,12)
	var radius:=minf(art_rect.size.x*.43,art_rect.size.y*.40)
	draw_arc(center,radius,0,TAU,80,Color(UI.PRIMARY,.09),1.,true)
	draw_line(Vector2(24,88),Vector2(size.x-24,88),Color(UI.BORDER,.72),1.,true)

func _header(area: Vector2) -> void:
	var back:=_button('',func():
		if not game.content_party_context.is_empty():game._build_hero_select_screen()
		else:game._open_home())
	back.name='HeroShowcaseBack';back.tooltip_text='이전 화면';back.add_theme_font_size_override('font_size',30)
	_place(self,back,Rect2(24,22,48,48))
	_place(back,UI.icon('back',Vector2(24,24),UI.INK),Rect2(12,12,24,24))
	_label_at(self,'영웅',Rect2(88,20,160,30),26,INK)
	_label_at(self,'아우렐리아' if game.selected_faction=='aurelia' else '녹스페라',Rect2(88,53,200,22),13,MUTED)
	var formation:=_button('원정대 편성',Callable(game,'_build_hero_select_screen'))
	formation.name='HeroFormationAction';_place(self,formation,Rect2(300,24,150,44))
	var wallet:=HBoxContainer.new();wallet.add_theme_constant_override('separation',12)
	_place(self,wallet,Rect2(area.x-388,23,364,46))
	for entry in [['G',game.wallet_gold],['정수',game.raid_crystals]]:
		var balance:=_panel(wallet,UI.SURFACE,UI.BORDER);balance.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		balance.tooltip_text='골드' if str(entry[0])=='G' else '레이드 정수'
		var row:=HBoxContainer.new();balance.add_child(row)
		var symbol:=UI.icon('coin' if str(entry[0])=='G' else 'gem',Vector2(20,20),UI.PRIMARY if str(entry[0])=='G' else UI.BLUE)
		row.add_child(symbol)
		var amount:=_text(row,game._compact_hud_amount(int(entry[1])),18,INK);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		amount.size_flags_horizontal=Control.SIZE_EXPAND_FILL;amount.tooltip_text=str(entry[1])
		var currency:=str(entry[0])
		amount.name='HeroGoldValue' if currency=='G' else 'HeroCrystalsValue'
		live_bindings.append(func():
			var value: int=game.wallet_gold if currency=='G' else game.raid_crystals
			amount.text=game._compact_hud_amount(value);amount.tooltip_text=str(value))

func _roster(area: Vector2) -> void:
	_label_at(self,'영웅 목록',Rect2(38,119,120,26),15,INK)
	var count:=_label_at(self,str(game._hero_roster_for_faction().size()),Rect2(165,119,39,26),13,MUTED)
	count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var scroll:=ScrollContainer.new();scroll.name='HeroRosterScroll';S.make_scroll_responsive(scroll)
	_place(self,scroll,Rect2(34,152,176,area.y-272))
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override('separation',8);scroll.add_child(column)
	for entry: Dictionary in game._hero_roster_for_faction():
		var id:=str(entry.id)
		var button:=_button('',func():build(game,id,tab),id==hero_id)
		button.name='HeroRoster_'+id;button.custom_minimum_size=Vector2(156,76)
		if id==hero_id:_selected_control(button)
		button.mouse_filter=Control.MOUSE_FILTER_PASS
		button.tooltip_text=str(entry.name)+' · '+str(game._hero_role_group(id))
		column.add_child(button)
		var portrait:=TextureRect.new();portrait.texture=game._combat_portrait_texture(id)
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_place(button,portrait,Rect2(6,6,53,64))
		var name_label:=_label_at(button,str(entry.name).get_slice(' ',0),Rect2(68,9,86,26),15,INK)
		name_label.name='HeroRosterName_'+id
		var is_locked: bool=game.idle_stage<int(entry.get('unlock_stage',1))
		if is_locked:portrait.modulate=Color(.5,.6,.63,.65)
		var state:=('잠김 · %d'%int(entry.get('unlock_stage',1))) if is_locked else ('Lv.%d'%int(game._get_hero_progress(id).level))
		var small:=_label_at(button,state,Rect2(68,39,86,24),12,UI.PRIMARY if id==hero_id else MUTED)
		live_bindings.append(func():
			var still_locked: bool=game.idle_stage<int(entry.get('unlock_stage',1))
			small.text=('잠김 · %d'%int(entry.get('unlock_stage',1))) if still_locked else ('Lv.%d'%int(game._get_hero_progress(id).level))
			portrait.modulate=Color(.5,.6,.63,.65) if still_locked else Color.WHITE)
		if game._is_hero_deployed(id):
			var active:=_label_at(button,'●',Rect2(8,7,15,18),10,UI.GREEN);active.tooltip_text='출전 중'
		if id==hero_id:button.set_meta('selected_hero',true)
	scroll.set_deferred('scroll_vertical',roster_position)
	scroll.get_v_scroll_bar().value_changed.connect(func(value: float):game.set_meta('hero_showcase_roster_scroll',int(value)))

func _tabs(_area: Vector2) -> void:
	var tab_width: float=(right_rect.size.x-18)/4.
	for index in TABS.size():
		var entry: Array=TABS[index];var key:=str(entry[0]);var active:=tab==key
		var button:=_button(str(entry[1]),func():build(game,hero_id,key),active)
		button.name='HeroTab_'+key;button.alignment=HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override('font_size',14)
		if active:_selected_control(button)
		_place(self,button,Rect2(right_rect.position.x+index*(tab_width+6),212,tab_width,44))
		button.toggle_mode=true;button.button_pressed=active
	var rank:=_label_at(self,str(game._hero_grade(hero_id)),Rect2(art_rect.position.x+14,119,74,34),22,ACCENT)
	rank.name='HeroGradeValue'
	_label_at(self,str(hero.get('identity',hero.get('role',''))),Rect2(art_rect.position.x+94,122,art_rect.size.x-108,28),14,MUTED)

func _hero_art() -> void:
	var frame:=Control.new();frame.name='HeroShowcaseArt';frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.clip_contents=true
	_place(self,frame,art_rect)
	var actor:=HeroSpriteFactory.create_hero(hero_id)
	actor.name='HeroShowcaseActor';actor.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(actor)
	var height:=minf(art_rect.size.y-116,art_rect.size.x*.99)
	actor.scale=Vector2.ONE*(height/maxf(1.,actor.native_visual_height))
	actor.position=Vector2(art_rect.size.x*.5,art_rect.size.y-49)
	var rig:=ShowcaseRig.new()
	if not rig.install(actor):rig.queue_free()
	actor.play_idle('down')
	var shadow:=Polygon2D.new();shadow.color=Color(0.,0.,0.,.36)
	var points:=PackedVector2Array()
	for index in 40:
		var angle:=float(index)*TAU/40.;points.append(Vector2(cos(angle)*height*.27,sin(angle)*12))
	shadow.polygon=points;shadow.position=actor.position;shadow.z_index=-1;frame.add_child(shadow)
	if locked:actor.modulate=Color(.62,.72,.77,.70)
	var state: String='스테이지 %d에서 합류'%int(hero.get('unlock_stage',1)) if locked else ('출전 · '+str(game._party_slot_name(party_slot)) if party_slot>=0 else '미편성')
	var state_label:=_label_at(frame,state,Rect2(0,art_rect.size.y-30,art_rect.size.x,28),16,MUTED)
	state_label.name='HeroDeploymentState';state_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	live_bindings.append(func():
		actor.modulate=Color(.62,.72,.77,.70) if locked else Color.WHITE
		state_label.text='스테이지 %d에서 합류'%int(hero.get('unlock_stage',1)) if locked else ('출전 · '+str(game._party_slot_name(party_slot)) if party_slot>=0 else '미편성'))

func _identity() -> void:
	var name_label:=_label_at(self,str(hero.name),Rect2(right_rect.position.x,108,right_rect.size.x,40),28,INK)
	name_label.name='HeroIdentityName';name_label.max_lines_visible=1;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_label_at(self,'%s · %s · %s'%[hero.get('race',''),hero.get('class',''),game._hero_role_group(hero_id)],Rect2(right_rect.position.x,151,right_rect.size.x,24),13,MUTED)
	var level:=_label_at(self,'LEVEL  %d / %d'%[int(progress_data.level),game.MAX_HERO_LEVEL],Rect2(right_rect.position.x,178,right_rect.size.x,28),17,ACCENT)
	level.name='HeroLevelValue'
	live_bindings.append(func():level.text='LEVEL  %d / %d'%[int(progress_data.level),game.MAX_HERO_LEVEL])
	var values:=_text(self,'현재 전투 능력치 · HP %s · 공격 %s · 방어 %s'%[game._compact_hud_amount(int(combat_stats.max_hp)),game._compact_hud_amount(int(combat_stats.attack)),game._compact_hud_amount(int(combat_stats.defense))],13,MUTED)
	values.name='HeroCombatStats';values.visible=false;values.set_meta('combat_stats',combat_stats.duplicate(true))
	live_bindings.append(func():values.set_meta('combat_stats',combat_stats.duplicate(true)))
	var scroll:=ScrollContainer.new();scroll.name='PortraitContentScroll';S.make_scroll_responsive(scroll)
	# This direct-child path is the equipment workshop's return-scroll contract.
	game.content_root.add_child(scroll)
	scroll.position=Vector2(right_rect.position.x,270);scroll.size=Vector2(right_rect.size.x,game.get_viewport_rect().size.y-440)
	detail=VBoxContainer.new();detail.name='HeroShowcaseDetailContent';detail.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;detail.add_theme_constant_override('separation',10);scroll.add_child(detail)
	detail.custom_minimum_size.x=right_rect.size.x-18
	scroll.set_deferred('scroll_vertical',content_position)
	var deploy_text: String='스테이지 %d에서 합류'%int(hero.get('unlock_stage',1)) if locked else ('배치 해제' if party_slot>=0 else '원정대에 배치')
	var deploy:=_button(deploy_text,_deploy,party_slot<0);deploy.name='HeroDeployAction'
	_guard_action(deploy,func():return locked or (party_slot<0 and game.deployed_heroes.size()>=game._party_slot_cap()))
	if not locked and party_slot<0 and game.deployed_heroes.size()>=game._party_slot_cap():deploy.tooltip_text='원정대가 가득 찼습니다. 편성에서 자리를 선택해 교체하세요.'
	_place(self,deploy,Rect2(right_rect.position.x,game.get_viewport_rect().size.y-160,right_rect.size.x,48))
	live_bindings.append(func():deploy.text='스테이지 %d에서 합류'%int(hero.get('unlock_stage',1)) if locked else ('배치 해제' if party_slot>=0 else '원정대에 배치'))

func _details() -> void:
	if locked:
		_text(detail,'미합류 영웅 · 스테이지 %d 해금'%int(hero.get('unlock_stage',1)),16,ACCENT).name='HeroLockedHint'
	match tab:
		'growth':_growth()
		'skills':_skills()
		'equipment':_equipment()
		'ascension':_ascension()

func _stats() -> void:
	var grid:=HBoxContainer.new();grid.name='HeroStatGrid';grid.add_theme_constant_override('separation',8);detail.add_child(grid)
	for entry in [['attack','공격력'],['defense','방어력'],['max_hp','체력']]:
		var key:=str(entry[0]);var row:=_panel(grid,UI.SOFT,Color.TRANSPARENT,10)
		var line:=VBoxContainer.new();line.add_theme_constant_override('separation',4);row.add_child(line)
		_text(line,str(entry[1]),12,MUTED)
		var value:=_text(line,game._compact_hud_amount(int(combat_stats[key])),19,INK)
		value.name='HeroStat_'+('hp' if key=='max_hp' else key);value.set_meta('combat_value',int(combat_stats[key]))
		value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		value.tooltip_text=str(combat_stats[key])
		live_bindings.append(func():
			value.text=game._compact_hud_amount(int(combat_stats[key]));value.tooltip_text=str(combat_stats[key])
			value.set_meta('combat_value',int(combat_stats[key])))
	var note:=_text(detail,'장비·연구·진형'+('·시너지 반영' if party_slot>=0 else ' 반영'),12,MUTED)
	note.name='HeroStatBasis'

func _growth() -> void:
	_stats()
	var maximum: bool=int(progress_data.level)>=game.MAX_HERO_LEVEL
	var required: int=int(game._hero_xp_to_next(int(progress_data.level)))
	var experience:=_text(detail,'최대 레벨 달성' if maximum else 'EXP  %d / %d · 전투로 성장'%[int(progress_data.xp),required],14,MUTED);experience.name='HeroExperienceValue'
	var bar:=ProgressBar.new();bar.custom_minimum_size=Vector2(0,7);bar.show_percentage=false
	bar.max_value=required;bar.value=required if maximum else int(progress_data.xp)
	bar.name='HeroExperienceBar'
	live_bindings.append(func():
		var next_xp: int=game._hero_xp_to_next(int(progress_data.level))
		var at_max: bool=int(progress_data.level)>=game.MAX_HERO_LEVEL
		experience.text='최대 레벨 달성' if at_max else 'EXP  %d / %d · 전투로 성장'%[int(progress_data.xp),next_xp]
		bar.max_value=next_xp;bar.value=next_xp if at_max else int(progress_data.xp))
	bar.add_theme_stylebox_override('background',UI.panel(UI.BG,Color.TRANSPARENT,3,0))
	bar.add_theme_stylebox_override('fill',UI.panel(UI.GREEN,Color.TRANSPARENT,3,0));detail.add_child(bar)
	var points: int=game._skill_tree_available_points(hero_id)
	var research_points:=_text(detail,'성장 연구     %d P 남음'%points,18,INK);research_points.name='HeroResearchPoints'
	live_bindings.append(func():research_points.text='성장 연구     %d P 남음'%game._skill_tree_available_points(hero_id))
	var tree: Dictionary=game._get_skill_tree(hero_id)
	for entry in [['offense','공격'],['survival','생존'],['utility','기능']]:
		var branch:=str(entry[0]);var rank:=int(tree.get(branch,0))
		var button:=_button('%s  %d / 10     + 1 P'%[entry[1],rank],func():_research(branch))
		button.name='HeroResearch_'+branch;button.custom_minimum_size=Vector2(0,44);button.mouse_filter=Control.MOUSE_FILTER_PASS
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.tooltip_text=game._skill_tree_branch_text(branch,rank)
		_guard_action(button,func():return locked or game._skill_tree_available_points(hero_id)<=0 or int(game._get_skill_tree(hero_id).get(branch,0))>=10);detail.add_child(button)
	var reset:=_button('연구 재배분',Callable(game,'_open_research_allocation').bind(hero_id));reset.name='HeroResearchAllocation';reset.custom_minimum_size.y=44
	_guard_action(reset,func():return locked);detail.add_child(reset)
	var hint:=_text(detail,'영웅 레벨이 3 오를 때마다 연구 포인트를 얻어요.',14,MUTED);hint.visible=points<=0
	live_bindings.append(func():hint.visible=game._skill_tree_available_points(hero_id)<=0)

func _skills() -> void:
	_text(detail,'전투 기술 · 4종',16,INK)
	for kit: Dictionary in hero.get('skills',[]):
		var ultimate: bool=str(kit.slot)=='ultimate'
		var box:=_section(ultimate);box.get_parent().name='HeroSkill_'+str(kit.slot)
		var line:=HBoxContainer.new();line.add_theme_constant_override('separation',10);box.add_child(line)
		var icon:=TextureRect.new();icon.texture=VISUALS.skill_texture(hero_id,str(kit.slot));icon.custom_minimum_size=Vector2(52,52)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(icon)
		var titles:=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;titles.add_theme_constant_override('separation',2);line.add_child(titles)
		_text(titles,str(kit.skill),18,UI.PRIMARY if ultimate else INK)
		var slot_name: String={'a1':'액티브 1','a2':'액티브 2','passive':'패시브','ultimate':'궁극기'}.get(str(kit.slot),'기술')
		_text(titles,slot_name+(' · 게이지 100' if ultimate else ' · %.1f초'%float(kit.get('cooldown',0))),12,MUTED)
		_text(box,str(kit.get('effect','')),14,INK)
	var profile: Dictionary=game.hero_identity_catalog.profile(hero_id)
	_text(detail,'전투 성향 · '+game.hero_identity_catalog.ai_style_name(str(profile.get('ai_style','balanced'))),17,INK)
	_text(detail,str(profile.get('trait','')),15,MUTED)

func _equipment() -> void:
	_text(detail,'장착 중인 장비',19,INK)
	for slot: String in ['weapon','armor','accessory']:
		var item: Dictionary=game._gear_item('',hero_id,slot)
		var button:=_button('',func():game._build_equipment_detail(str(item.get('id','')),hero_id,slot,'info'))
		button.name='HeroGear_'+slot;button.custom_minimum_size=Vector2(0,88);button.mouse_filter=Control.MOUSE_FILTER_PASS;button.disabled=locked or item.is_empty();detail.add_child(button)
		var texture:=TextureRect.new();texture.texture=ART.texture_for(item);texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(button,texture,Rect2(8,9,66,66))
		_label_at(button,game._equipment_slot_name(slot)+' · '+str(item.get('rarity','일반')),Rect2(84,7,right_rect.size.x-122,22),13,MUTED)
		var label:=_label_at(button,str(item.get('name','미장착')),Rect2(84,29,right_rect.size.x-122,25),17,INK)
		label.max_lines_visible=1;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.tooltip_text=str(item.get('name',''))
		_label_at(button,'+%d   ·   전투력 %d'%[int(item.get('level',0)),game._item_power(item)],Rect2(84,57,right_rect.size.x-122,23),14,ACCENT)
	var profile: Dictionary=game._equipment_set_profile(hero_id)
	_text(detail,str(profile.get('summary','세트 장비를 모으면 추가 효과가 활성화됩니다.')),14,MUTED)
	var bag:=_button('장비 가방에서 비교 · 교체',func():game.set_meta('gear_equip_hero_id',hero_id);game._build_inventory_screen(),true)
	bag.name='HeroEquipmentBag';bag.custom_minimum_size.y=48;bag.disabled=locked;detail.add_child(bag)

func _ascension() -> void:
	var requirement: Dictionary=game._ascension_requirement(hero_id)
	var capped: bool=game._hero_grade(hero_id)=='UR'
	var box:=_section();_text(box,'등급 승급',22,INK)
	_text(box,'현재 '+str(game._hero_grade(hero_id))+(' · 최고 등급' if capped else ' → '+str(['R','SR','SSR','UR'][mini(3,game._hero_base_grade_index(hero_id)+game._hero_ascension_rank(hero_id)+1)])),18,ACCENT)
	_text(box,'모든 등급 승급을 완료했습니다.' if capped else '필요 Lv.%d · 골드 %s'%[int(requirement.level),game._compact_hud_amount(int(requirement.gold))],15,MUTED)
	var ascend:=_button('최고 등급 UR' if capped else '승급 · %s G'%game._compact_hud_amount(int(requirement.gold)),func():
		if _mutation_blocked() or locked:return
		if game._try_ascend_hero(hero_id):build(game,hero_id,'ascension'),true)
	ascend.name='HeroAscendAction';ascend.custom_minimum_size.y=48
	_guard_action(ascend,func():return locked or capped or int(progress_data.level)<int(requirement.level) or game.wallet_gold<int(requirement.gold));box.add_child(ascend)
	var rank: int=game._hero_breakthrough_rank(hero_id);var amount: int=game._hero_shard_count(hero_id);var cost: int=game._breakthrough_cost(rank)
	var shards:=_section();_text(shards,'조각 돌파',22,INK)
	var shard_balance:=_text(shards,'돌파 %d / 5   ·   조각 %d개 보유'%[rank,amount],17,ACCENT)
	shard_balance.name='HeroShardBalance'
	live_bindings.append(func():shard_balance.text='돌파 %d / 5   ·   조각 %d개 보유'%[game._hero_breakthrough_rank(hero_id),game._hero_shard_count(hero_id)])
	_text(shards,'돌파를 완료하면 영웅 전투력이 증가합니다.' if rank<5 else '모든 돌파 단계를 완료했습니다.',15,MUTED)
	var breakthrough:=_button('최대 돌파' if rank>=5 else '돌파 · 조각 %d개'%cost,func():
		if _mutation_blocked() or locked:return
		if game._try_breakthrough(hero_id):build(game,hero_id,'ascension'),true)
	breakthrough.name='HeroBreakthroughAction';breakthrough.custom_minimum_size.y=48
	_guard_action(breakthrough,func():return locked or rank>=5 or game._hero_shard_count(hero_id)<cost);shards.add_child(breakthrough)
	var summon:=_button('소환 · 조각 획득',func():game.set_meta('summon_mode','hero');game.set_meta('summon_hero_id',hero_id);game._build_summon_screen())
	summon.name='HeroShardSource';summon.custom_minimum_size.y=46;detail.add_child(summon)

func _mutation_blocked() -> bool:
	return game._save_blocked_for_newer_version or bool(game.get_meta('practice_active',false)) or SAFETY.pending(game)

func _guard_action(button: Button, unavailable: Callable) -> void:
	guarded_actions.append({'button':button,'unavailable':unavailable})
	button.disabled=_mutation_blocked() or bool(unavailable.call())

func _live_state_signature() -> int:
	return hash([game.wallet_gold,game.raid_crystals,game.idle_stage,game.hero_progress,game.hero_skill_tree,game.hero_shards,game.hero_breakthrough,game.hero_ascension,game.hero_equipment_items,game._deployed_hero_ids()])

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or game.active_screen!='hero_detail':return
	var blocked:=_mutation_blocked()
	var signature:=_live_state_signature()
	if blocked==writes_blocked and signature==live_signature:return
	writes_blocked=blocked;live_signature=signature
	progress_data=game._get_hero_progress(hero_id)
	locked=game.idle_stage<int(hero.get('unlock_stage',1))
	party_slot=game._deployed_hero_ids().find(hero_id)
	var hp_mult: float=float(game._calculate_party_synergy().get('hp_multiplier',1.0)) if party_slot>=0 else 1.0
	combat_stats=game._hero_combat_stats(hero_id,maxi(0,party_slot),hp_mult)
	for refresh: Callable in live_bindings:refresh.call()
	# Update existing controls so a hunt reward cannot interrupt a touch,
	# change the selected tab, move a scroll, or take keyboard focus.
	for action: Dictionary in guarded_actions:
		var button: Button=action.button
		if is_instance_valid(button):button.disabled=blocked or bool(action.unavailable.call())

func _deploy() -> void:
	if locked or _mutation_blocked():return
	var host:=game;var selected:=hero_id;var selected_tab:=tab
	var entry:=hero.duplicate(true);entry['color']=Color(str(entry.get('color','#79aeea')))
	host._deploy_hero(entry);build(host,selected,selected_tab)

func _research(branch: String) -> void:
	if locked or _mutation_blocked():return
	var host:=game;var selected:=hero_id
	host.set_meta('growth_hero_id',selected)
	host._upgrade_skill_tree(selected,branch)
	build(host,selected,'growth')

func _section(important: bool=false) -> VBoxContainer:
	var panel:=_panel(detail,UI.SOFT,Color(UI.PRIMARY,.5) if important else UI.BORDER,12)
	var box:=VBoxContainer.new();box.add_theme_constant_override('separation',10);panel.add_child(box);return box

static func _style(fill: Color, edge: Color=Color.TRANSPARENT, radius: int=8) -> StyleBoxFlat:
	var style:=UI.panel(fill,edge,radius,1 if edge.a>.01 else 0)
	style.bg_color=fill
	style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=6;style.content_margin_bottom=6
	return style

static func _panel(parent: Node, fill: Color, edge: Color, padding: int=8) -> PanelContainer:
	var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style:=_style(fill,edge);style.set_content_margin_all(padding);panel.add_theme_stylebox_override('panel',style);parent.add_child(panel);return panel

static func _button(caption: String, callback: Callable, primary: bool=false) -> Button:
	var button:=UI.button(caption,Vector2.ZERO,UI.PRIMARY if primary else UI.SOFT);button.tooltip_text=caption
	button.add_theme_font_override('font',S.bold_font());button.add_theme_font_size_override('font_size',17)
	button.clip_text=true;button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	if callback.is_valid():button.pressed.connect(callback)
	return button

static func _selected_control(button: Button) -> void:
	button.add_theme_stylebox_override('normal',_style(UI.SURFACE.lerp(UI.PRIMARY,.12),UI.PRIMARY))
	button.add_theme_stylebox_override('hover',_style(UI.SOFT.lerp(UI.PRIMARY,.15),UI.PRIMARY))
	button.add_theme_stylebox_override('pressed',_style(UI.SURFACE.lerp(UI.PRIMARY,.16),UI.PRIMARY))
	button.add_theme_color_override('font_color',UI.INK)
	button.add_theme_color_override('font_pressed_color',UI.INK)
	button.add_theme_color_override('font_hover_color',UI.INK)
	button.add_theme_color_override('font_focus_color',UI.INK)

static func _text(parent: Node, value: String, points: int=17, color: Color=INK) -> Label:
	var label:=Label.new();label.text=value;label.add_theme_font_override('font',S.bold_font() if points>=19 else S.font())
	label.add_theme_font_size_override('font_size',points);label.add_theme_color_override('font_color',color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;parent.add_child(label);return label

static func _label_at(parent: Node, value: String, rect: Rect2, points: int=17, color: Color=INK) -> Label:
	# Absolute labels must not calculate wrapped minimum heights at zero width.
	var label:=Label.new();label.text=value;label.tooltip_text=value
	label.add_theme_font_override('font',S.bold_font() if points>=19 else S.font())
	label.add_theme_font_size_override('font_size',points);label.add_theme_color_override('font_color',color)
	label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.clip_text=true;label.max_lines_visible=1
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_place(parent,label,rect);return label

static func _place(parent: Node, control: Control, rect: Rect2) -> void:
	parent.add_child(control);control.position=rect.position;control.size=rect.size
