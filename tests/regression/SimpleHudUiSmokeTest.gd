extends "res://tests/support/V83UpgradeTestBase.gd"
## Real focus/input and live geometry contracts for the compact presentation.
func _init() -> void:run.call_deferred()

func key(code: Key,shift: bool=false) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true;event.shift_pressed=shift
	root.push_input(event,true);await settle()
	event=InputEventKey.new();event.keycode=code;event.pressed=false;event.shift_pressed=shift
	root.push_input(event,true);await settle()

func run() -> void:
	var main=await make_main("aurelia",10)
	main._build_combat_screen();main.tutorial_completed=true;await settle()
	var hud: Control=main.portrait_hud;hud.refresh()
	var state: Dictionary=main.hero_battle_state.duplicate(true)
	var runtime: Dictionary=main.hero_skill_runtime.duplicate(true)
	var wallet: Vector2i=Vector2i(main.wallet_gold,main.wallet_gems)
	var rng_state: int=main.loot_rng.state
	var header: Control=hud.get_node("HuntCompactHeader")
	check(header.size.y<112,"header leaves more room for battle")
	check(hud.get_node_or_null("LandscapeMenuButton")==null,"full menu uses the persistent dock once")
	for name in ["HuntPartyEdit","PortraitAutoButton","PortraitSpeedButton","PortraitDetailsButton"]:
		var control: Button=hud.find_child(name,true,false)
		check(control.size.y>=44 and control.size.x>=44,"primary touch target stays at least44px "+name)
		check(header.get_global_rect().encloses(control.get_global_rect()),"primary command stays in header "+name)
		check(not control.get_global_rect().intersects(hud.enemy_label.get_global_rect()),"enemy count is separated from command "+name)
		check(not control.get_global_rect().intersects(hud.stage_progress.get_global_rect()),"progress does not cross command "+name)
	for id in hud.bars:
		var row: Dictionary=hud.bars[id]
		check(row.level.get_theme_font_size("font_size")>=13,"level is readable "+id)
		check(row.slot.get_global_rect().encloses(row.skill.get_global_rect()),"skill status fits hero card "+id)
	var dock: Control=hud.get_node("PortraitNavigation")
	for button in dock.get_children():
		for child in button.get_children():
			if child is Label:check(child.get_theme_font_size("font_size")>=14,"dock label is readable")
	hud.details_button.grab_focus();hud._toggle_options();await settle()
	var close: Button=hud.options_layer.find_child("HuntOptionsClose",true,false)
	check(root.gui_get_focus_owner()==close,"opening commands focuses the close control")
	for step in 16:
		await key(KEY_TAB,step%3==0)
		check(hud.options_layer.is_ancestor_of(root.gui_get_focus_owner()),"Tab stays in the open command sheet")
	await key(KEY_ESCAPE)
	check(not hud.options_layer.visible and root.gui_get_focus_owner()==hud.details_button,"Escape closes and restores focus")
	main._open_battle_formation();await settle()
	var formation: Control=main.content_root.get_node('FormationOverlay')
	var formation_panel: Control=formation.get_node('FormationPanel')
	var note: Control=formation.find_child('FormationSafetyNote',true,false)
	check(main.get_viewport_rect().encloses(formation_panel.get_global_rect()),"formation panel stays inside the screen after text wrapping")
	check(formation_panel.get_global_rect().encloses(note.get_global_rect()),"formation information remains visible in the footer")
	check(root.gui_get_focus_owner()==formation.find_child('FormationClose',true,false),"formation opens with accessible close focus")
	await key(KEY_ESCAPE)
	check(main.content_root.get_node_or_null('FormationOverlay')==null,"Escape dismisses formation without navigating away")
	check(root.gui_get_focus_owner()==hud.details_button and main.active_screen=='combat',"formation restores focus and live screen")
	check(main.hero_battle_state==state and main.hero_skill_runtime==runtime,"opening and closing UI preserves combat state")
	check(wallet==Vector2i(main.wallet_gold,main.wallet_gems) and main.loot_rng.state==rng_state,"UI does not spend rewards or roll RNG")
	await dispose(main);done("SIMPLE_HUD_UI")
