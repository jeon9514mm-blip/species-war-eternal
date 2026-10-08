extends 'res://tests/support/V83UpgradeTestBase.gd'
func _init() -> void:run.call_deferred()
func snapshot(main: Node,label: String) -> Dictionary:
	var rows: Array=[];var owned: Dictionary={}
	for id: String in main.hero_hp_bars:
		var bar: ProgressBar=main.hero_hp_bars[id];owned[bar.get_instance_id()]=id
		var state: Dictionary=main.hero_battle_state.get(id,{})
		rows.append({'id':id,'value':bar.value,'visible':bar.visible,'in_tree':bar.is_visible_in_tree(),'position':[bar.global_position.x,bar.global_position.y],'size':[bar.size.x,bar.size.y],'fill':(bar.get_theme_stylebox('fill') as StyleBoxFlat).bg_color.to_html(),'background':(bar.get_theme_stylebox('background') as StyleBoxFlat).bg_color.to_html(),'hp':state.get('hp',-1),'max_hp':state.get('max_hp',-1),'stale':state.is_empty()})
	var unowned: Array=[]
	var actor_layer: Node=main.combat_labels.get('actor_layer')
	for bar: ProgressBar in actor_layer.find_children('*','ProgressBar',true,false):
		if not owned.has(bar.get_instance_id()) and bar not in main.enemy_hp_bars:unowned.append({'value':bar.value,'visible':bar.visible,'fill':(bar.get_theme_stylebox('fill') as StyleBoxFlat).bg_color.to_html(),'path':str(bar.get_path())})
	return {'label':label,'bars':rows,'unowned':unowned,'queued_health':main.combat_labels.terrain._health_entries.size()}
func run() -> void:
	var main=await make_main('aurelia',10);root.size=Vector2i(1280,720);await settle()
	main.idle_stage=154;main._build_combat_screen();await settle();main.combat_running=false
	var field=main.combat_labels.terrain;field.set_process(false)
	var report: Array=[]
	main._update_map_hero_motion(0);report.append(snapshot(main,'after-legacy-map-motion'))
	field._process(0);report.append(snapshot(main,'after-field-presentation'))
	var ids: Array=main._deployed_hero_ids();main._open_hero_menu();await settle()
	main._restore_deployed_heroes(ids.slice(0,9));main._advance_auto_hunt(.05)
	main._open_home();await settle();field=main.combat_labels.terrain;field.set_process(false);field._process(0)
	report.append(snapshot(main,'after-background-party-edit'))
	var output: String=OS.get_environment('HUNT_HEALTH_OUTPUT')
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
	print('HUNT_HEALTH_PROBE '+JSON.stringify(report));await dispose(main);quit()
