extends "res://scripts/portrait/PortraitHud.gd"
## Wide hunt: unobstructed battlefield and a single row of live hero gauges.
const LAYOUT := preload("res://scripts/portrait/LandscapeHuntLayout.gd")
func _label_at(value: String, box: Rect2, points: int = 18) -> Label:
	var label := SKIN.label(value, points)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	SKIN.place(self, label, box)
	return label
func _button_at(value: String, action: Callable, box: Rect2, named: String) -> Button:
	var button := SKIN.button(value, action)
	button.name = named; button.add_theme_font_size_override("font_size",16)
	SKIN.place(self, button, box)
	return button
func build(main: Node) -> void:
	game = main; name = "PortraitHud"; z_index = 90; compact_guide_layout = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Vector2 = game.get_viewport_rect().size
	var w: float = screen.x; var h: float = screen.y
	var header := Rect2(12,12,w-24,100)
	var footer := LAYOUT.footer(screen)
	var header_panel:=SKIN.panel(self,header,SKIN.SURFACE,SKIN.EDGE_SOFT,1,12)
	header_panel.name="HuntCompactHeader"
	var strip := SKIN.panel(self,footer,SKIN.DARK,SKIN.EDGE_SOFT,1,10)
	strip.name = "HuntHeroGaugeStrip"
	# Retain the base refresh adapter without displaying the former profile panel.
	profile_name = _label_at("",Rect2()); profile_name.hide()
	profile_level = _label_at("",Rect2()); profile_level.hide()
	power_label = _label_at("",Rect2()); power_label.hide()
	profile_xp = SKIN.gauge(self,Rect2(),SKIN.GOLD); profile_xp.hide()
	stage_label = _label_at("",Rect2(28,20,w-600,32),22)
	stage_label.name="HuntStageTitle"
	gold_badge=preload('res://scripts/presentation/CurrencyFeedbackBadge.gd').new();add_child(gold_badge)
	gold_badge.bind(game,'gold',Rect2(w-552,22,128,30),17);gold_label=gold_badge.caption
	gem_badge=preload('res://scripts/presentation/CurrencyFeedbackBadge.gd').new();add_child(gem_badge)
	gem_badge.bind(game,'gem',Rect2(w-412,22,104,30),17);gem_label=gem_badge.caption
	_button_at("편성",Callable(game,"_build_hero_select_screen"),Rect2(w-304,18,64,44),"HuntPartyEdit")
	auto_button = _button_at("",_toggle_auto,Rect2(w-232,18,100,44),"PortraitAutoButton")
	speed_button = _button_at("",_cycle_speed,Rect2(w-128,18,56,44),"PortraitSpeedButton")
	speed_button.tooltip_text = "사냥 배속 전환 · ×1 / ×2"
	details_button = _button_at("",_toggle_options,Rect2(w-64,18,40,44),"PortraitDetailsButton")
	details_button.size.x=44
	details_button.tooltip_text = "사냥 조작 · 자동 각성기 · 보상"
	_add_command_icon(details_button,"settings")
	# The persistent five-tab dock already provides the full menu.
	stage_progress = SKIN.gauge(self,Rect2(28,64,w-56,4),SKIN.GOLD)
	enemy_label = _label_at("",Rect2(w-132,76,104,24),14)
	enemy_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	enemy_label.add_theme_color_override("font_color",SKIN.MUTED)
	quest_label = _label_at("",Rect2(28,76,w-188,24),14)
	quest_label.add_theme_color_override("font_color",SKIN.MUTED)
	first_session_action = _button_at("원정 가이드",Callable(game,"_follow_first_session_guide"),Rect2(w-326,68,184,44),"FirstSessionGuideAction")
	first_session_action.add_theme_font_size_override("font_size",14)
	status_label = _label_at("",Rect2(20,footer.position.y-24,w-40,22),14)
	slot_row = Control.new(); slot_row.name = "PortraitPartySlots"
	slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SKIN.place(self,slot_row,footer); _build_slots()
	_build_options(w,h,true)
	reward_feed = REWARD_FEED.new()
	SKIN.place(self,reward_feed,Rect2(24,LAYOUT.field(screen).end.y-96,320,90)); reward_feed.build(320)
	navigation(game,self,"combat",h-LAYOUT.NAV_HEIGHT,LAYOUT.NAV_HEIGHT)
	hud_bounds = [header,footer]
	refresh()
func _add_command_icon(button: Button, icon_name: String) -> void:
	var icon := preload("res://scripts/ui/GameUiIcon.gd").new()
	icon.icon_name = icon_name; icon.ink = SKIN.INK
	SKIN.place(button,icon,Rect2((button.size.x-24)/2,10,24,24))
func refresh() -> void:
	super.refresh()
	quest_label.size.x = (first_session_action.position.x-42 if first_session_action.visible else game.get_viewport_rect().size.x-188)
	auto_button.text = "편성" if game.deployed_heroes.is_empty() else ("일시정지" if game.combat_running else "사냥 재개")
	details_button.text = ""
	for id in bars:
		if bars[id].skill.text == "궁극": bars[id].skill.text = "각성"
func _build_slots() -> void:
	for child in slot_row.get_children(): child.free()
	bars.clear()
	var count := mini(10,game.deployed_heroes.size())
	var cell_width := minf(180,slot_row.size.x/maxi(1,count))
	var inset:=maxf(0,(slot_row.size.x-count*cell_width)*.5)
	for i in count:
		var hero: Dictionary = game.deployed_heroes[i]; var id: String = str(hero.id)
		var width := cell_width-4
		var face_width:=42.0 if width>=110 else 34.0
		var text_x:=face_width+12
		var slot := SKIN.button("",Callable(game,"_build_hero_detail_screen").bind(id))
		slot.name = "HuntHero_"+id
		SKIN.place(slot_row,slot,Rect2(inset+i*cell_width+2,2,width,60))
		slot.add_theme_stylebox_override("normal",SKIN.UI.card_style())
		_add_portrait(slot,id,Rect2(6,19,face_width,35))
		var title := SKIN.label(game._hero_short_name(id),14)
		SKIN.place(slot,title,Rect2(7,1,width-14,18))
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var level := SKIN.label("",13,SKIN.MUTED); SKIN.place(slot,level,Rect2(text_x,20,width-text_x-5,17))
		var skill := SKIN.label("",12); SKIN.place(slot,skill,Rect2(text_x,37,width-text_x-5,16))
		skill.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		var hp_label := SKIN.label("HP",10,SKIN.MUTED)
		hp_label.hide();slot.add_child(hp_label)
		var ult_label := SKIN.label("각성",10,SKIN.GOLD)
		ult_label.hide();slot.add_child(ult_label)
		var hp := SKIN.gauge(slot,Rect2(6,54,width-12,3),SKIN.SUCCESS)
		var ult := SKIN.gauge(slot,Rect2(6,58,width-12,2),SKIN.GOLD)
		bars[id] = {"hp":hp,"ultimate":ult,"slot":slot,"level":level,"skill":skill,"hp_band":-1}
	if count == 0:
		var edit := SKIN.button("영웅을 편성해 사냥 시작",Callable(game,"_build_hero_select_screen"))
		edit.name = "HuntEmptyPartyEdit"; SKIN.place(slot_row,edit,Rect2(6,6,260,52))
	_slot_signature = _party_signature()
