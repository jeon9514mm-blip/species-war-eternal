extends "res://scripts/V83UpgradeTestBase.gd"
const UI=preload('res://scripts/GameUiTheme.gd')
const SKIN=preload('res://scripts/portrait/PortraitSkin.gd')
func _init() -> void:_run.call_deferred()
func _run() -> void:
	check(UI.SURFACE==SKIN.SURFACE and UI.INK==SKIN.INK and UI.GOLD==SKIN.GOLD,'one palette across all presenters')
	var main=await make_main('aurelia',10)
	main._build_combat_screen();await settle();main.combat_running=false
	var hud=main.portrait_hud
	var snapshot: Dictionary={'hp':main.hero_battle_state.duplicate(true),'enemies':main.enemy_wave.duplicate(true),'clock':main.invasion.clock,'gold':main.wallet_gold}
	check(not hud.options_layer.visible,'secondary hunting controls collapsed by default')
	check(main.combat_field_rect.size.y>=700,'portrait dedicates most height to the battlefield')
	check(hud.slot_row.get_child_count()==10 and hud.slot_row.size.y==84,'ten heroes use one party strip')
	check(hud.slot_row.get_parent() is ScrollContainer,'party strip is swipeable')
	hud._toggle_options();await settle()
	check(hud.options_layer.visible,'hunting settings accessible')
	var auto: bool=main.skill_auto;hud.skill_button.pressed.emit()
	check(main.skill_auto!=auto and hud.options_layer.visible,'toggle works without closing settings')
	hud.skill_button.pressed.emit()
	var formation: Button=hud.find_child('HuntFormation',true,false);formation.pressed.emit();await settle()
	check(not hud.options_layer.visible and main.content_root.has_node('FormationOverlay'),'external dialog replaces settings instead of being hidden behind it')
	main.content_root.get_node('FormationOverlay').free()
	hud._toggle_options();main._unhandled_key_input(_back_key());await settle()
	check(not hud.options_layer.visible and main.active_screen=='combat','back dismisses settings before navigation')
	hud._toggle_options();var previous_hud_id: int=hud.get_instance_id()
	main._apply_portrait_resize();await settle();hud=main.portrait_hud
	check(hud.get_instance_id()!=previous_hud_id and not hud.options_layer.visible,'resize rebuilds the HUD even when settings were open')
	check(main.hero_battle_state==snapshot.hp and main.enemy_wave==snapshot.enemies and main.invasion.clock==snapshot.clock and main.wallet_gold==snapshot.gold,'UI controls preserve battle and wallet')
	main._build_lobby_screen();await settle();main._show_main_menu();await settle()
	for entry in preload('res://scripts/NavigationCatalog.gd').menu_entries():
		check(main.content_root.find_child('PortraitMenu_'+str(entry.id),true,false)!=null,'grouped menu retains '+str(entry.id))
	main._build_hero_select_screen();await settle()
	var confirm: Button=main.content_root.find_child('RosterConfirm',true,false)
	check(confirm.get_theme_stylebox('normal').bg_color==UI.GOLD,'formation confirmation uses primary action style')
	main._build_raid_screen();await settle()
	var raid=main.content_root.get_node('PortraitRaidView')
	var button: Button=raid.find_child('RaidOptionsButton',true,false);button.pressed.emit();await settle()
	check(raid.get_node('RaidOptionsSheet').visible,'raid strategy and settings accessible')
	main._unhandled_key_input(_back_key());await settle()
	check(not raid.get_node('RaidOptionsSheet').visible and main.active_screen=='raid','back closes raid options without cancelling battle')
	check(raid.stage.size.y>600 and raid.battlefield_3d.size==raid.stage.size,'raid viewport fills expanded stage')
	await dispose(main);done('unified_interface')
func _back_key() -> InputEventKey:
	var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;return key
