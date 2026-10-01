extends SceneTree
## v78 convenience UI regression. Keeps legacy node names used by earlier UI tests
## while checking the new summary, presets and navigation hierarchy.
var main: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error('V78 convenience UI: '+message)

func settle() -> void:
	for frame in 6:
		await process_frame

func node(named: String) -> Node:
	return main.content_root.find_child(named,true,false)

func run() -> void:
	root.content_scale_size=Vector2i(720,1280)
	root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v78-convenience-ui.json'
	root.add_child(main)
	await settle()
	main.set_physics_process(false)
	main.set_process(false)
	main._offline_checked=true
	main.combat_effects_enabled=false
	main.selected_faction='aurelia'
	main.idle_stage=25
	main.party_slot_legacy_cap=10
	main._restore_deployed_heroes(['leonhardt','seraphina','aelion'])
	main._build_inventory_screen()
	await settle()
	check(node('GearBagSummary')!=null,'bag exposes at-a-glance capacity summary')
	check(node('GearRecommendEquip')!=null,'recommend equip is a primary bag action')
	check(node('GearSettingsToggle')!=null,'bag keeps collapsible management tools')
	check(node('GearQuickFilters')!=null,'bag exposes grouped quick filters')
	var nav: Node=node('PortraitNavigation')
	check(nav!=null and nav.get_child_count()==5,'bottom dock keeps five high-frequency destinations')
	for key in ['home','heroes','battle','bag','more']:
		check(nav.get_node_or_null('PortraitNav_'+key)!=null,'bottom dock exposes '+key)
	check(node('GearFilter_rarity')!=null,'bag exposes a direct rarity filter')
	main._show_main_menu()
	await settle()
	for key in ['growth','world','summon','war']:
		check(node('PortraitMenu_'+key)!=null,'secondary destination remains available in menu: '+key)
	main.content_root.get_node_or_null('PortraitActionSheet').queue_free()
	main._build_hero_select_screen()
	await settle()
	check(node('RosterPartyGrid')!=null and node('RosterPartyGrid').get_child_count()==10,'formation preserves all ten slots')
	check((node('RosterHeroGrid') as GridContainer).columns==4,'formation uses a compact four-column hero roster')
	check(node('RosterPresetBar')!=null,'formation exposes preset bar')
	for index in range(1,4):
		check(node('RosterPreset%d'%index)!=null,'formation preset P%d is available'%index)
	check(node('RosterPresetSave')!=null,'current formation can be saved from the same screen')
	check(node('RosterActionDock')!=null,'formation actions are grouped in a dedicated bottom dock')
	print('v78_convenience_ui checks=%d failures=%d'%[checks,failures.size()])
	main.free()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
	quit(0 if failures.is_empty() else 1)
