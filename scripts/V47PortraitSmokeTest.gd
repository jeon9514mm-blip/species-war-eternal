extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		push_error(label)
func run() -> void:
	root.content_scale_size=Vector2i(720,1280)
	var main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v47-portrait.json'
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction='aurelia'
	main.party_slot_legacy_cap=10
	main.idle_stage=25
	main._offline_checked=true
	main.deployed_heroes=main._hero_roster_for_faction().slice(0,10)
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._build_combat_screen()
	for dims: Vector2i in [Vector2i(720,1280),Vector2i(720,1440),Vector2i(720,1560),Vector2i(810,1440)]:
		root.size=dims
		for f in 5: await process_frame
		var hud: Control=main.portrait_hud
		var slots: Control=hud.slot_row
		check(main._combat_camera_anchor().y<hud.auto_button.position.y-150,'party camera clears bottom controls '+str(dims))
		var frame:=Rect2(Vector2.ZERO,slots.size)
		var used: Array[Rect2]=[]
		for i in 10:
			var slot: Button=slots.get_node('PortraitSlot%d'%i)
			check(frame.encloses(slot.get_rect()),'all ten cards fit the party panel '+str(dims)+' / '+str(i))
			check(slot.size.x>=120 and slot.size.y>=80,'hero card touch area '+str(i))
			for rect in used: check(not rect.intersects(slot.get_rect()),'hero cards do not overlap')
			used.append(slot.get_rect())
		for id in hud.bars:
			var widgets: Dictionary=hud.bars[id]
			check(Rect2(Vector2.ZERO,widgets['slot'].size).encloses(widgets['hp'].get_rect()),'HP gauge contained '+id)
			check(widgets['hp'].size.y<=12,'compact HP preserved '+id)
		var map: Control=hud.find_child('PortraitMinimap',true,false)
		check(map!=null,'live minimap created')
		check(map.map_point(Vector2(32,20)).is_equal_approx(map.size),'minimap shares full world coordinates')
		var controls: Array[Control]=[hud.details_button,hud.auto_button,hud.speed_button,hud.get_node('PortraitQuestButton'),slots,hud.get_node('PortraitMapButton')]
		for i in controls.size():
			check(Rect2(Vector2.ZERO,main.get_viewport_rect().size).encloses(controls[i].get_global_rect()),'HUD inside viewport '+controls[i].name)
			for j in range(i+1,controls.size()): check(not controls[i].get_global_rect().intersects(controls[j].get_global_rect()),'commands have separate touch areas')
	main.portrait_hud._toggle_auto()
	check('재개' in main.portrait_hud.auto_button.text and '일시정지' in main.portrait_hud.status_label.text,'pause has a visible label and resume action')
	main.portrait_hud._toggle_auto()
	check('자동사냥 중' in main.portrait_hud.auto_button.text,'resuming updates the label')
	main.deployed_heroes=main.deployed_heroes.slice(0,3)
	main.portrait_hud.refresh()
	check(main.portrait_hud.bars.size()==3,'party cards refresh after roster change')
	main._build_hero_select_screen()
	await process_frame
	var detail: Button=main.content_root.find_child('RosterDetail_leonhardt',true,false)
	check(detail!=null,'roster portraits expose hero detail')
	detail.pressed.emit()
	await process_frame
	check(main.active_screen=='hero_detail','portrait click opens actual hero detail')
	main.hero_roster_filter='탱커'
	main._build_hero_select_screen()
	await process_frame
	main.content_root.find_child('RosterFilter',true,false).pressed.emit()
	await process_frame
	check(main.hero_roster_filter=='전체','all filter restores every role')
	main._clear_screen()
	main.free()
	print('V47PortraitSmokeTest: ',checks,' checks, ',failures.size(),' failures')
	quit(0 if failures.is_empty() else 1)
