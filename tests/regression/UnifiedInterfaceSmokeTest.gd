extends "res://tests/support/V83UpgradeTestBase.gd"
const UI=preload('res://scripts/ui/GameUiTheme.gd')
const SKIN=preload('res://scripts/portrait/PortraitSkin.gd')
const LANDSCAPE_HUD=preload('res://scripts/portrait/LandscapeHuntHud.gd')
func _init() -> void:_run.call_deferred()
func click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;root.push_input(event,true)
func press(main: Node, named: String) -> void:
	var target: Button=main.content_root.find_child(named,true,false)
	check(target!=null,'button exists '+named)
	if target==null:return
	if not target.is_visible_in_tree() and target.is_inside_tree():
		var hud: Node=main.portrait_hud
		if is_instance_valid(hud) and is_instance_valid(hud.options_layer):hud.options_layer.show()
	var ancestor: Node=target.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(target)
		ancestor=ancestor.get_parent()
	await settle()
	check(not target.disabled and target.is_visible_in_tree(),'action available '+named)
	check(main.get_viewport_rect().encloses(target.get_global_rect()),'action fits viewport '+named)
	click(target.get_global_rect().get_center());await settle()
func _run() -> void:
	check(UI.SURFACE==SKIN.SURFACE and UI.INK==SKIN.INK and UI.GOLD==SKIN.GOLD,'one palette across all presenters')
	var main=await make_main('aurelia',10)
	root.size=Vector2i(1280,720);root.gui_embed_subwindows=true;await settle()
	main._build_combat_screen();await settle();main.combat_running=false
	var hud=main.portrait_hud
	var snapshot: Dictionary={'hp':main.hero_battle_state.duplicate(true),'enemies':main.enemy_wave.duplicate(true),'clock':main.invasion.clock,'gold':main.wallet_gold}
	check(hud.get_script()==LANDSCAPE_HUD,'hunting uses the dedicated landscape presenter')
	check(main.get_viewport_rect().size.x>main.get_viewport_rect().size.y,'logical battle viewport remains landscape')
	check(main.combat_field_rect.size.x>main.combat_field_rect.size.y and main.get_viewport_rect().encloses(main.combat_field_rect),'wide battlefield fits beside the party controls')
	check(hud.slot_row.get_child_count()==10,'landscape party panel retains all ten heroes')
	check(hud.slot_row.get_child(0).position.x<hud.slot_row.get_child(1).position.x and hud.slot_row.get_child(0).position.y==hud.slot_row.get_child(1).position.y,'party starts with two side-by-side heroes')
	for index in hud.slot_row.get_child_count():
		var slot: Control=hud.slot_row.get_child(index)
		check(hud.slot_row.get_global_rect().encloses(slot.get_global_rect()),'party member fits in landscape panel '+str(index))
		check(not main.combat_field_rect.intersects(slot.get_global_rect()),'party member does not obscure battlefield '+str(index))
		for other in range(index+1,hud.slot_row.get_child_count()):
			check(not slot.get_global_rect().intersects(hud.slot_row.get_child(other).get_global_rect()),'party targets do not overlap')
	var auto: bool=main.skill_auto
	await press(main,'PortraitSkillAuto')
	check(main.skill_auto!=auto and main.active_screen=='combat','skill auto toggle operates directly from the landscape sidebar')
	await press(main,'PortraitSkillAuto')
	await press(main,'HuntFormation')
	check(main.content_root.has_node('FormationOverlay'),'formation opens above the battlefield')
	await press(main,'FormationClose')
	check(not main.content_root.has_node('FormationOverlay'),'formation close returns to the same combat screen')
	await press(main,'HuntSettings')
	check(main.content_root.has_node('PresentationSettingsOverlay'),'landscape settings open from the visible sidebar')
	check(main.content_root.find_child('PresentationLandscapeNotice',true,false)!=null and main.content_root.find_child('Presentation_orientation',true,false)==null,'settings show fixed landscape mode without orientation switching')
	main._unhandled_key_input(_back_key());await settle()
	check(not main.content_root.has_node('PresentationSettingsOverlay') and main.active_screen=='combat','back dismisses presentation settings before navigation')
	await press(main,'PortraitDetailsButton')
	await press(main,'HuntStatistics')
	check(main.combat_labels['details_panel'].visible,'hunt details are accessible from the sidebar')
	main._unhandled_key_input(_back_key());await settle()
	check(not main.combat_labels['details_panel'].visible and main.active_screen=='combat','back dismisses hunt details before navigation')
	var previous_hud_id: int=hud.get_instance_id()
	root.size=Vector2i(1560,720);await settle();hud=main.portrait_hud
	check(hud.get_instance_id()!=previous_hud_id and hud.get_script()==LANDSCAPE_HUD,'wide-window resize rebuilds the landscape HUD')
	check(main.get_viewport_rect().encloses(main.combat_field_rect) and main.combat_field_rect.size.x>main.combat_field_rect.size.y,'resized battlefield remains wide and on-screen')
	check(main.hero_battle_state==snapshot.hp and main.enemy_wave==snapshot.enemies and main.invasion.clock==snapshot.clock and main.wallet_gold==snapshot.gold,'UI controls and resizing preserve battle and wallet')
	main._build_lobby_screen();await settle();main._show_main_menu();await settle()
	for entry in preload('res://scripts/ui/NavigationCatalog.gd').menu_entries():
		check(main.content_root.find_child('PortraitMenu_'+str(entry.id),true,false)!=null,'grouped menu retains '+str(entry.id))
	main._build_hero_select_screen();await settle()
	var confirm: Button=main.content_root.find_child('RosterConfirm',true,false)
	check(confirm.get_theme_stylebox('normal').bg_color==UI.GOLD,'formation confirmation uses primary action style')
	main._build_raid_screen();await settle()
	var raid=main.content_root.get_node('PortraitRaidView')
	var information: ScrollContainer=raid.get_node_or_null('LandscapeRaidInfo')
	check(information!=null and main.get_viewport_rect().encloses(information.get_global_rect()),'raid exposes its information in the landscape sidebar')
	check(raid.stage.size.x>raid.stage.size.y and main.get_viewport_rect().encloses(raid.stage.get_global_rect()),'raid battlefield remains wide and on-screen')
	check(not raid.stage.get_global_rect().intersects(information.get_global_rect()),'raid information stays beside the battlefield')
	check(raid.battlefield_3d.size==raid.stage.size,'raid 3D viewport fills the available stage')
	var raid_auto: bool=main.skill_auto
	check(raid.skill_auto_button.is_visible_in_tree() and main.get_viewport_rect().encloses(raid.skill_auto_button.get_global_rect()),'raid strategy control remains visible in landscape')
	click(raid.skill_auto_button.get_global_rect().get_center());await settle()
	check(main.skill_auto!=raid_auto and main.active_screen=='raid','raid auto toggle changes only the selected setting')
	click(raid.skill_auto_button.get_global_rect().get_center());await settle()
	check(main.skill_auto==raid_auto,'raid auto setting restores through the same control')
	await dispose(main);done('unified_interface')
func _back_key() -> InputEventKey:
	var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;return key
