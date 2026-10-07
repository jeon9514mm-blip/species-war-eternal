extends Control
## A dismissible drawer over the live screen. Navigation remains owned by Main.
const S=preload('res://scripts/portrait/PortraitSkin.gd')
const UI=preload('res://scripts/ui/GameUiTheme.gd')
const NAV=preload('res://scripts/ui/NavigationCatalog.gd')
const ICON=preload('res://scripts/ui/GameUiIcon.gd')
var game: Node
var pane: Control
var cards: Control
var links: GridContainer
var footer: HBoxContainer
var features: Array[Button]=[]
var return_focus: Control

static func open(main: Node) -> void:
	var previous: Node=main.content_root.get_node_or_null('PortraitActionSheet')
	if previous!=null:
		previous.hide();previous.name='ClosingActionSheet';previous.queue_free()
	var menu: Control=load('res://scripts/ui/LandscapeMainMenu.gd').new()
	menu.name='PortraitActionSheet';main.content_root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.install(main)

func _gradient(parent: Node, colors: PackedColorArray, horizontal: bool) -> void:
	var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0,.55,1]);gradient.colors=colors
	var texture:=GradientTexture2D.new();texture.gradient=gradient
	texture.fill_from=Vector2.ZERO;texture.fill_to=Vector2(1,0) if horizontal else Vector2(0,1)
	var shade:=TextureRect.new();shade.texture=texture;shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _label(parent: Node, text: String, size_px: int, box: Rect2, color: Color=S.INK) -> Label:
	var label:=S.label(text,size_px,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	S.place(parent,label,box);return label

func _icon(parent: Node, kind: String, box: Rect2) -> void:
	var icon:=ICON.new();icon.icon_name=kind;icon.ink=S.INK;S.place(parent,icon,box)

func _button(parent: Node, callback: Callable, node_name: String) -> Button:
	var button:=S.button('',callback);button.name=node_name
	for state: String in ['normal','hover','pressed']:
		button.add_theme_stylebox_override(state,S.box(Color(0,0,0,0) if state=='normal' else Color('#273b4ddd'),Color.TRANSPARENT if state=='normal' else S.GOLD,6,1))
	button.add_theme_stylebox_override('focus',S.box(Color.TRANSPARENT,S.GOLD,6,2))
	parent.add_child(button);return button

func install(main: Node) -> void:
	game=main;z_index=250;mouse_filter=Control.MOUSE_FILTER_STOP
	return_focus=get_viewport().gui_get_focus_owner()
	_gradient(self,PackedColorArray([Color('#09131b25'),Color('#09131bc9'),Color('#09131bf5')]),true)
	var outside:=_button(self,close,'MenuDismissArea');outside.focus_mode=Control.FOCUS_NONE
	for state: String in ['normal','hover','pressed']:outside.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	outside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pane=Control.new();pane.name='PortraitMenuSheet';pane.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(pane)
	var backdrop:=ColorRect.new();backdrop.color=Color('#09131bdd');backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pane.add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label(pane,'메뉴',26,Rect2(20,10,180,42))
	var top:=HBoxContainer.new();top.name='MenuQuickActions';top.add_theme_constant_override('separation',8);pane.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);top.offset_left=-196;top.offset_right=-18;top.offset_top=6;top.offset_bottom=58
	for entry: Array in [['quest','목표 · 업적','_open_goal_screen','MenuQuickQuests'],['gift','보상 센터','_build_bm_screen','MenuQuickRewards'],['close','닫기','','PortraitMenuClose']]:
		var button:=_button(top,close if str(entry[2]).is_empty() else _dispatch.bind(str(entry[2])),str(entry[3]))
		button.tooltip_text=str(entry[1]);button.custom_minimum_size=Vector2(52,52)
		_icon(button,str(entry[0]),Rect2(12,12,28,28))
	var divider:=ColorRect.new();divider.color=Color('#49607566');divider.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pane.add_child(divider);divider.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);divider.offset_left=20;divider.offset_right=-20;divider.offset_top=64;divider.offset_bottom=65
	cards=Control.new();cards.name='MenuFeaturedCards';pane.add_child(cards)
	var routes: Dictionary={}
	for entry: Dictionary in NAV.menu_entries():routes[str(entry.id)]=str(entry.method)
	var definitions: Array=[
		['war','종의 전쟁','진영 전투',''],
		['camp','원정 캠프','모험의 시작','res://assets/ui/v30/expedition-key-art.png'],
		['world','사냥터','지역과 보상',''],
		['summon','소환','영웅과 수호령',''],
		['raid','레이드','보스 토벌',''],
		['growth','성장 · 던전','도전과 성장','']]
	for entry: Array in definitions:
		var route: String=routes.get(str(entry[0]),'_build_boss_select_screen')
		features.append(_feature(str(entry[0]),str(entry[1]),str(entry[2]),str(entry[3]),route))
	links=GridContainer.new();links.name='MenuIconGrid';links.columns=6;links.add_theme_constant_override('h_separation',6);links.add_theme_constant_override('v_separation',6);pane.add_child(links)
	for entry: Array in [
		['inventory','가방','bag','_build_inventory_screen'],['heroes','영웅','heroes','_open_hero_menu'],
		['party','파티 편성','party','_build_hero_select_screen'],['formation','전투 진형','shield',routes.formation],
		['codex','영웅 도감','journal',routes.codex],['training','성장 연구','growth',routes.training],
		['rewards','보상 센터','gift',routes.rewards],['quests','목표 · 업적','quest','_open_goal_screen'],
		['market','거래소','coin','_build_equipment_market'],['faction','진영 선택','war',routes.faction],
		['guide','가이드','compass','_show_portrait_guide'],['settings','설정','settings','_open_presentation_settings']]:
		var node_name: String='PresentationSettingsEntry' if entry[0]=='settings' else ('PortraitOpenGuide' if entry[0]=='guide' else 'PortraitMenu_'+str(entry[0]))
		var button:=_button(links,_dispatch.bind(str(entry[3])),node_name)
		button.custom_minimum_size=Vector2(0,88);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.tooltip_text=str(entry[1])
		var icon:=ICON.new();icon.icon_name=str(entry[2]);icon.ink=S.INK;button.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);icon.offset_left=-17;icon.offset_right=17;icon.offset_top=9;icon.offset_bottom=43
		var caption:=S.label(str(entry[1]),17,S.INK);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;button.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_top=-35;caption.offset_bottom=-5
		if entry[0]=='quests' and game._quest_ready_count()>0:
			var dot:=ColorRect.new();dot.color=S.UI.RED;dot.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(dot)
			dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);dot.offset_left=20;dot.offset_right=26;dot.offset_top=7;dot.offset_bottom=13
	footer=HBoxContainer.new();footer.name='MenuPreferences';footer.add_theme_constant_override('separation',12);pane.add_child(footer)
	var effects:=CheckButton.new();effects.name='PortraitEffectSetting';effects.text='전투 연출';effects.button_pressed=game.combat_effects_enabled;effects.custom_minimum_size=Vector2(0,52)
	effects.add_theme_font_size_override('font_size',17);footer.add_child(effects)
	effects.toggled.connect(func(enabled: bool):game.combat_effects_enabled=enabled;game.combat_fx.enabled=enabled;game._save_ui_preferences())
	var sounds:=CheckButton.new();sounds.name='PortraitSoundSetting';sounds.text='효과음';sounds.button_pressed=game.sound_effects_enabled;sounds.custom_minimum_size=Vector2(0,52)
	sounds.add_theme_font_size_override('font_size',17);footer.add_child(sounds)
	sounds.toggled.connect(func(enabled: bool):
		game.sound_effects_enabled=enabled
		if not enabled and is_instance_valid(game.skill_audio_bus):game.skill_audio_bus.stop()
		game._save_ui_preferences())
	var space:=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(space)
	var title:=S.button('시작 화면',_dispatch.bind(str(routes.title)));title.name='PortraitMenu_title';title.custom_minimum_size=Vector2(124,52);footer.add_child(title)
	resized.connect(_layout);_layout();pane.find_child('PortraitMenuClose',true,false).grab_focus()

func _feature(id: String, title: String, subtitle: String, image_path: String, route: String) -> Button:
	var button:=_button(cards,_dispatch.bind(route),'PortraitMenu_'+id);button.clip_contents=true;button.tooltip_text=title+' · '+subtitle
	button.add_theme_stylebox_override('normal',S.box(S.SURFACE,S.EDGE_SOFT,4,1))
	var art:=TextureRect.new();art.texture=load(image_path) if not image_path.is_empty() else null;art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left=2;art.offset_top=2;art.offset_right=-2;art.offset_bottom=-2
	_gradient(art,PackedColorArray([Color('#06101b00'),Color('#06101b10'),Color('#06101bf2')]),false)
	var caption:=S.label(title,22);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(caption);caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_left=6;caption.offset_right=-6;caption.offset_top=-62;caption.offset_bottom=-26
	var description:=S.label(subtitle,14,Color('#d6e1eb'));description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;button.add_child(description)
	description.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);description.offset_top=-27;description.offset_bottom=-7
	return button

func _layout() -> void:
	if not is_instance_valid(pane):return
	var w:=size.x;var h:=size.y;var pane_w:=clampf(w*.58,760,1000)
	pane.position=Vector2(w-pane_w-12,12);pane.size=Vector2(pane_w,h-24)
	cards.position=Vector2(20,80);cards.size=Vector2(pane_w-40,250)
	var narrow:=114.0;var area:=cards.size.x-narrow-10
	features[0].position=Vector2.ZERO;features[0].size=Vector2(narrow,250)
	for i in 2:features[i+1].position=Vector2(narrow+10+i*(area+10)/2,0);features[i+1].size=Vector2((area-10)/2,120)
	for i in 3:features[i+3].position=Vector2(narrow+10+i*(area+10)/3,130);features[i+3].size=Vector2((area-20)/3,120)
	links.position=Vector2(20,350);links.size=Vector2(pane_w-40,182)
	footer.position=Vector2(20,pane.size.y-68);footer.size=Vector2(pane_w-40,52)

func _dispatch(method: String) -> void:
	if not is_instance_valid(game):return
	if method=='_build_meta_hub_screen' and str(game.get_meta('content_meta_tab','daily')) not in ['daily','tower','weekly']:
		game.set_meta('content_meta_tab','daily')
	var host:=game
	close(false)
	host.call(method)

func close(restore_focus: bool=true) -> void:
	hide()
	# Touch emits a mouse release before its real touch release. Keep the old
	# input target in the tree until both have finished, without blocking hits.
	name='ClosingActionSheet'
	if restore_focus and is_instance_valid(return_focus) and return_focus.is_visible_in_tree():return_focus.grab_focus()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed('ui_cancel'):
		get_viewport().set_input_as_handled();close()
