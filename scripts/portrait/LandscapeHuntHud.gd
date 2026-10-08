extends "res://scripts/portrait/PortraitHud.gd"
## Hunt-only, portrait-first dock. All gameplay commands remain in the existing adapter.
const LAYOUT := preload("res://scripts/portrait/LandscapeHuntLayout.gd")
var party_summary: Button
var party_count: Label
func _label_at(value: String, box: Rect2, points: int = 18) -> Label:
	var label: Label = SKIN.label(value, points)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	SKIN.place(self, label, box)
	return label
func _button_at(value: String, action: Callable, box: Rect2, named: String) -> Button:
	var button: Button = SKIN.button(value, action)
	button.name = named; button.add_theme_font_size_override("font_size",16)
	SKIN.place(self, button, box)
	return button
func build(main: Node) -> void:
	game = main; name = "PortraitHud"; z_index = 90; compact_guide_layout = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Vector2 = game.get_viewport_rect().size
	var w: float = screen.x; var h: float = screen.y
	var header: Rect2 = Rect2(12,12,w-24,112)
	var footer: Rect2 = LAYOUT.footer(screen)
	SKIN.panel(self,header,SKIN.DARK,SKIN.EDGE_SOFT,1,14)
	var strip: Panel = SKIN.panel(self,footer,SKIN.DARK,SKIN.EDGE_SOFT,1,10)
	strip.name = "HuntHeroGaugeStrip"
	# Retain the base refresh adapter without displaying the former profile panel.
	profile_name = _label_at("",Rect2()); profile_name.hide()
	profile_level = _label_at("",Rect2()); profile_level.hide()
	power_label = _label_at("",Rect2()); power_label.hide()
	profile_xp = SKIN.gauge(self,Rect2(),SKIN.GOLD); profile_xp.hide()
	stage_label = _label_at("",Rect2(24,18,w-652,34),22)
	gold_label = _label_at("",Rect2(w-614,20,142,30),16)
	gem_label = _label_at("",Rect2(w-466,20,94,30),16)
	_button_at("편성",Callable(game,"_build_hero_select_screen"),Rect2(w-368,18,68,44),"HuntPartyEdit")
	auto_button = _button_at("",_toggle_auto,Rect2(w-292,18,84,44),"PortraitAutoButton")
	speed_button = _button_at("",_cycle_speed,Rect2(w-200,18,56,44),"PortraitSpeedButton")
	speed_button.tooltip_text = "사냥 배속 전환 · ×1 / ×2"
	details_button = _button_at("",_toggle_options,Rect2(w-136,18,48,44),"PortraitDetailsButton")
	details_button.tooltip_text = "사냥 조작 · 자동 각성기 · 보상"
	_add_command_icon(details_button,"settings")
	var menu: Button = _button_at("",Callable(game,"_show_main_menu"),Rect2(w-80,18,56,44),"LandscapeMenuButton")
	menu.tooltip_text = "전체 메뉴"; _add_command_icon(menu,"hamburger")
	stage_progress = SKIN.gauge(self,Rect2(24,62,w-160,8),SKIN.GOLD)
	enemy_label = _label_at("",Rect2(w-118,48,95,30),16)
	quest_label = _label_at("",Rect2(24,82,w-48,30),16)
	first_session_action = _button_at("원정 가이드",Callable(game,"_follow_first_session_guide"),Rect2(w-218,76,194,44),"FirstSessionGuideAction")
	# Keep the base refresh adapter; the always-visible duplicate status line is gone.
	status_label = _label_at("",Rect2(),14)
	status_label.hide()
	_build_party_summary(screen)
	slot_row = Control.new(); slot_row.name = "PortraitPartySlots"
	slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SKIN.place(self,slot_row,LAYOUT.slots_rect(screen)); _build_slots()
	_build_options(w,h,true)
	reward_feed = REWARD_FEED.new()
	var field_box: Rect2 = LAYOUT.field(screen)
	SKIN.place(self,reward_feed,Rect2(24,field_box.end.y-96,320,90)); reward_feed.build(320)
	_build_dock_navigation(screen)
	hud_bounds = [header,footer]
	refresh()
func _add_command_icon(button: Button, icon_name: String) -> void:
	var icon: Control = preload("res://scripts/ui/GameUiIcon.gd").new()
	icon.set("icon_name",icon_name); icon.set("ink",SKIN.INK)
	SKIN.place(button,icon,Rect2((button.size.x-24)/2,10,24,24))
func refresh() -> void:
	if not is_instance_valid(game): return
	super.refresh()
	quest_label.size.x = (first_session_action.position.x-36 if first_session_action.visible else game.get_viewport_rect().size.x-48)
	auto_button.text = "편성" if game.deployed_heroes.is_empty() else ("Ⅱ 사냥" if game.combat_running else "▶ 재개")
	details_button.text = ""
	var alive: int = 0
	for id in bars:
		var row: Dictionary = bars[id]
		var hp: ProgressBar = row["hp"]
		var skill: Label = row["skill"]
		var badge: Panel = row["state_badge"]
		var slot: Button = row["slot"]
		var level: Label = row["level"]
		if hp.value > 0.0: alive += 1
		# Silence only repetitive information. Cooldown, ready ultimate and KO remain visible.
		if skill.text == "궁극": skill.text = "각성"
		if skill.text == "전투불능": skill.text = "쓰러짐"
		badge.visible = skill.text != "준비" and not skill.text.is_empty()
		slot.tooltip_text += "\n" + level.text + " · 눌러서 성장 / 장비 확인"
	if is_instance_valid(party_count):
		party_count.text = "%d/%d" % [alive, bars.size()] if not bars.is_empty() else "+ 편성"
		party_summary.tooltip_text = status_label.text + "\n눌러서 원정대 편성"

func _build_party_summary(screen: Vector2) -> void:
	var party_box: Rect2 = LAYOUT.party_rect(screen)
	var summary_box: Rect2 = Rect2(party_box.position,Vector2(LAYOUT.PARTY_SUMMARY_WIDTH,LAYOUT.HERO_HEIGHT))
	party_summary = _button_at("",Callable(game,"_build_hero_select_screen"),summary_box,"HuntPartySummary")
	var caption: Label = SKIN.label("원정대",14,SKIN.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(party_summary,caption,Rect2(0,5,LAYOUT.PARTY_SUMMARY_WIDTH,23))
	party_count = SKIN.label("",16,SKIN.INK)
	party_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SKIN.place(party_summary,party_count,Rect2(0,28,LAYOUT.PARTY_SUMMARY_WIDTH,25))

func _build_dock_navigation(screen: Vector2) -> void:
	# Do not change PortraitHud.navigation(): all other game screens keep their layout.
	var nav: Control = Control.new()
	nav.name = "PortraitNavigation"
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.z_index = 95
	SKIN.place(self,nav,LAYOUT.navigation_rect(screen))
	var entries: Array = NAV.dock_entries()
	var selected_tab: String = NAV.active_tab("combat")
	var cell: float = nav.size.x / float(maxi(1,entries.size()))
	var compact: bool = nav.size.y < LAYOUT.HERO_HEIGHT
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var selected: bool = str(entry["id"]) == selected_tab
		var button: Button = SKIN.button("",Callable(game,str(entry["method"])),SKIN.DARK)
		button.name = "PortraitNav_" + str(entry["id"])
		button.tooltip_text = str(entry["label"])
		button.add_theme_stylebox_override("normal",SKIN.box(SKIN.SURFACE_2 if selected else Color.TRANSPARENT,SKIN.GOLD if selected else Color.TRANSPARENT,10,1 if selected else 0))
		SKIN.place(nav,button,Rect2(i*cell+2.0,0,cell-4.0,nav.size.y))
		var ink: Color = SKIN.GOLD if selected else SKIN.INK
		var icon: Control = SKIN.UI.icon(str(entry["portrait_icon"]),Vector2(22,22),ink)
		var icon_y: float = 3.0 if compact else 5.0
		SKIN.place(button,icon,Rect2((button.size.x-22.0)*0.5,icon_y,22,22))
		var caption: Label = SKIN.label(str(entry["label"]),15,ink)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		SKIN.place(button,caption,Rect2(2,25 if compact else 32,button.size.x-4.0,21))

func _build_slots() -> void:
	for child in slot_row.get_children(): child.free()
	bars.clear()
	var count: int = mini(10,game.deployed_heroes.size())
	var cell_width: float = minf(LAYOUT.HERO_CELL_MAX,slot_row.size.x/float(maxi(1,count)))
	for i in count:
		var hero: Dictionary = game.deployed_heroes[i]
		var id: String = str(hero["id"])
		var width: float = cell_width-4.0
		var slot: Button = SKIN.button("",Callable(game,"_build_hero_detail_screen").bind(id))
		slot.name = "HuntHero_"+id
		SKIN.place(slot_row,slot,Rect2(i*cell_width+2.0,0,width,LAYOUT.HERO_HEIGHT))
		# A larger original portrait replaces three cramped lines of permanent text.
		_add_portrait(slot,id,Rect2((width-44.0)*0.5,4,44,44))
		var level: Label = SKIN.label("",11)
		level.hide()
		slot.add_child(level)
		var badge: Panel = SKIN.panel(slot,Rect2(3,29,width-6.0,19),SKIN.DARK,SKIN.EDGE_SOFT,1,4)
		badge.name = "HuntHeroStateBadge"
		var skill: Label = SKIN.label("",12,SKIN.GOLD)
		skill.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		SKIN.place(badge,skill,Rect2(1,0,width-8.0,19))
		badge.hide()
		var hp: ProgressBar = SKIN.gauge(slot,Rect2(4,51,width-8.0,4),SKIN.SUCCESS)
		var ult: ProgressBar = SKIN.gauge(slot,Rect2(4,56,width-8.0,3),SKIN.GOLD)
		bars[id] = {"hp":hp,"ultimate":ult,"slot":slot,"level":level,"skill":skill,"hp_band":-1,"state_badge":badge}
	if count == 0:
		var edit: Button = SKIN.button("영웅을 편성해 사냥 시작",Callable(game,"_build_hero_select_screen"))
		edit.name = "HuntEmptyPartyEdit"
		SKIN.place(slot_row,edit,Rect2(4,4,minf(260.0,slot_row.size.x-8.0),52))
	_slot_signature = _party_signature()
