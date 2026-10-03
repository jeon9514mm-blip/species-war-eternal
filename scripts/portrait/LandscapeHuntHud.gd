extends "res://scripts/portrait/PortraitHud.gd"
## Same commands and refresh code as portrait, with a dedicated wide layout.
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
	game = main; name = "PortraitHud"; z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Vector2 = game.get_viewport_rect().size
	var w: float = screen.x; var h: float = screen.y
	var side: float = w - 334.0
	SKIN.panel(self,Rect2(side,12,322,h-106),SKIN.DARK,SKIN.EDGE_SOFT,1,14)
	SKIN.panel(self,Rect2(12,12,side-24,112),SKIN.DARK,SKIN.EDGE_SOFT,1,14)
	profile_name = _label_at("원정대",Rect2(side+12,18,180,28))
	profile_level = _label_at("",Rect2(side+12,46,148,26),16)
	power_label = _label_at("",Rect2(side+170,46,80,26),18)
	var menu:=_button_at("",Callable(game,"_show_main_menu"),Rect2(w-68,18,44,44),"LandscapeMenuButton")
	menu.tooltip_text="전체 메뉴"
	var menu_icon:=preload("res://scripts/GameUiIcon.gd").new();menu_icon.icon_name="hamburger";menu_icon.ink=SKIN.INK
	SKIN.place(menu,menu_icon,Rect2(10,10,24,24))
	profile_xp = SKIN.gauge(self,Rect2(side+12,78,294,6),SKIN.GOLD)
	stage_label = _label_at("",Rect2(24,18,side-310,34),22)
	gold_label = _label_at("",Rect2(side-250,20,112,30)); gem_label = _label_at("",Rect2(side-126,20,102,30))
	stage_progress = SKIN.gauge(self,Rect2(24,62,side-160,8),SKIN.GOLD)
	enemy_label = _label_at("",Rect2(side-118,48,95,30))
	quest_label = _label_at("",Rect2(24,82,side-44,30),16)
	status_label = _label_at("",Rect2(20,h-128,side-40,30),16)
	_layout_rows = 2 if maxi(game._party_slot_cap(),game.deployed_heroes.size()) > 5 else 1
	slot_row = Control.new(); slot_row.name = "PortraitPartySlots"
	SKIN.place(self,slot_row,Rect2(side+10,92,302,320)); _build_slots()
	var y: float = h-290
	_button_at("전투 진형",Callable(game,"_open_battle_formation"),Rect2(side+10,y,146,42),"HuntFormation")
	_button_at("설정",Callable(game,"_open_presentation_settings"),Rect2(side+164,y,146,42),"HuntSettings")
	skill_button = _button_at("",_toggle_skill_auto,Rect2(side+10,y+46,146,42),"PortraitSkillAuto")
	ultimate_button = _button_at("",_toggle_ultimate_auto,Rect2(side+164,y+46,146,42),"PortraitUltimateAuto")
	auto_button = _button_at("",_toggle_auto,Rect2(side+10,y+92,224,42),"PortraitAutoButton")
	speed_button = _button_at("",_cycle_speed,Rect2(side+242,y+92,68,42),"PortraitSpeedButton")
	details_button = _button_at("",Callable(game,"_toggle_hunt_details"),Rect2(side+10,y+138,146,42),"PortraitDetailsButton")
	offline_button = _button_at("",_open_offline_rewards,Rect2(side+164,y+138,146,42),"PortraitOfflineRewards")
	reward_feed = REWARD_FEED.new(); SKIN.place(self,reward_feed,Rect2(24,h-235,320,90)); reward_feed.build(320)
	navigation(game,self,"combat",h-90,90)
	hud_bounds = [Rect2(side,12,322,h-106),Rect2(12,12,side-24,112)]
	refresh()
func _build_slots() -> void:
	for child in slot_row.get_children(): child.free()
	bars.clear()
	for i in mini(10,game.deployed_heroes.size()):
		var hero: Dictionary = game.deployed_heroes[i]; var id: String = str(hero.id)
		var slot := SKIN.button("",Callable(game,"_build_hero_detail_screen").bind(id))
		SKIN.place(slot_row,slot,Rect2((i%2)*154,(i/2)*62,148,58))
		var title := SKIN.label(game._hero_short_name(id),14); SKIN.place(slot,title,Rect2(6,0,136,20))
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var level := SKIN.label("",12); SKIN.place(slot,level,Rect2(6,19,74,18))
		var skill := SKIN.label("",11); SKIN.place(slot,skill,Rect2(80,19,64,18))
		var hp := SKIN.gauge(slot,Rect2(6,39,136,7),SKIN.SUCCESS)
		var ult := SKIN.gauge(slot,Rect2(6,50,136,3),SKIN.GOLD)
		bars[id] = {"hp":hp,"ultimate":ult,"slot":slot,"level":level,"skill":skill,"hp_band":-1}
	_slot_signature = _party_signature()
